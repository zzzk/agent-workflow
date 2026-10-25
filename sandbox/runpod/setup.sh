#!/bin/bash
# Einrichtung eines runpod-Pods (oder eines anderen gemieteten GPU-
# Containers) als Agent-Sandbox. Pods sind selbst Container - Docker fuer
# sandbox/run-sandbox.sh gibt es dort nicht. Die Trennung wird deshalb mit
# Unix-Usern nachgebildet:
#   agent  fuehrt Claude Code / opencode aus, besitzt den Klon samt .git
#          (committet je Task), hat KEINE Zugangsdaten zum Remote;
#   root   haelt den Push-Schluessel (mit Passphrase) und pusht - per
#          "agent-push", das den Branch erst in einen root-eigenen Klon
#          holt. Git im Klon des Agenten ruft root nie auf: der Agent
#          koennte dort Hooks ablegen, die dann als root liefen.
# Ollama kommt aus dem runpod-Template (Env-Variablen im Pod setzen, z.B.
# OLLAMA_CONTEXT_LENGTH), nicht von hier.
#
# Aufruf als root:
#   REPO=git@github.com:<owner>/<projekt>.git bash setup.sh
# Optional: BRANCH (Default main), MODEL (Default qwen3.8:27b), MODEL_DIGEST
# (Warnung bei Abweichung - fuer vergleichbare Messreihen), VOL (Default
# /opt/agent), SETUP_CMD (Projekt-Abhaengigkeiten als agent, z.B. "npm ci"),
# OPENCODE_VERSION, CLAUDE_VERSION (Default: die zuletzt erprobten).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive   # sonst bleibt apt an Rueckfragen haengen

: "${REPO:?REPO setzen, z.B. git@github.com:<owner>/<projekt>.git}"
BRANCH="${BRANCH:-main}"
MODEL="${MODEL:-qwen3.8:27b}"
MODEL_DIGEST="${MODEL_DIGEST:-}"
# Container-Disk, nicht das Network Volume: dort gibt es kein chmod/chown,
# und es ist fuer viele kleine Dateien zu langsam.
VOL="${VOL:-/opt/agent}"
OPENCODE_VERSION="${OPENCODE_VERSION:-1.18.32}"
CLAUDE_VERSION="${CLAUDE_VERSION:-2.1.281}"
NAME="$(basename "$REPO" .git)"
DIR="$VOL/$NAME"            # Klon des Agenten
PUSHDIR="/root/push/$NAME"  # root-eigener Klon, nur zum Pushen
KEY=/root/.ssh/agent-push

step() { echo; echo "=== $*"; }

step "1/8 Systempakete"
apt-get update -qq
apt-get install -y -qq git openssh-client curl ca-certificates tmux procps sudo >/dev/null

step "2/8 Node 22"
if ! node --version 2>/dev/null | grep -q '^v22'; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null
  apt-get install -y -qq nodejs >/dev/null
fi
node --version

step "3/8 opencode $OPENCODE_VERSION, Claude Code $CLAUDE_VERSION"
npm install -g --silent "opencode-ai@$OPENCODE_VERSION" "@anthropic-ai/claude-code@$CLAUDE_VERSION"

step "4/8 Ollama (Template) pruefen"
curl -fsS --max-time 5 http://127.0.0.1:11434/api/version || { echo "Ollama laeuft nicht"; exit 1; }
for p in $(pgrep -f "ollama serve"); do tr '\0' '\n' < "/proc/$p/environ" | grep ^OLLAMA; done | sort -u
ollama list | grep -q "^$MODEL" || ollama pull "$MODEL"
if [ -n "$MODEL_DIGEST" ]; then
  got="$(curl -fsS http://127.0.0.1:11434/api/tags | grep -o "\"name\":\"$MODEL\"[^}]*\"digest\":\"[0-9a-f]*" | grep -o '[0-9a-f]\{64\}' || true)"
  [ "$got" = "$MODEL_DIGEST" ] && echo "Modell-Digest wie erwartet" || echo "WARNUNG: Digest '$got' weicht ab"
fi

step "5/8 User agent"
id agent >/dev/null 2>&1 || useradd -m -s /bin/bash agent

step "6/8 Push-Schluessel fuer root (MIT Passphrase)"
mkdir -p /root/.ssh; chmod 700 /root/.ssh
if [ ! -f "$KEY" ]; then
  echo ">>> Jetzt eine Passphrase vergeben - ohne sie koennte jeder Prozess"
  echo ">>> mit Lesezugriff den Schluessel benutzen."
  ssh-keygen -q -t ed25519 -f "$KEY" -C "agent-push $NAME"
fi
echo ">>> Diesen Key auf GitHub als Deploy-Key MIT Schreibrecht eintragen"
echo ">>> (nur fuer dieses Repo - begrenzt den Schaden, falls er abfliesst):"
cat "$KEY.pub"
read -r -p ">>> Eingetragen? Enter druecken ... " _
export GIT_SSH_COMMAND="ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

step "7/8 Klone: $PUSHDIR (root, zum Pushen) und $DIR (agent, Arbeitsbaum + .git)"
mkdir -p "$(dirname "$PUSHDIR")" "$VOL"
[ -d "$PUSHDIR/.git" ] || git clone --branch "$BRANCH" "$REPO" "$PUSHDIR"
git -C "$PUSHDIR" config core.sshCommand "$GIT_SSH_COMMAND"
# Der Agent bekommt einen Klon OHNE Remote-Zugang: geklont wird aus dem
# root-Klon, danach zeigt origin auf das echte Repo (nur fuer Anzeige/
# Vergleich - pushen kann er mangels Schluessel nicht).
[ -d "$DIR/.git" ] || git clone --branch "$BRANCH" "$PUSHDIR" "$DIR"
git -C "$DIR" remote set-url origin "$REPO"
git -C "$DIR" config user.name  "Agent ($NAME)"
git -C "$DIR" config user.email "agent@noreply.invalid"
chown -R agent:agent "$DIR"
if [ -n "${SETUP_CMD:-}" ]; then
  sudo -u agent bash -c "cd '$DIR' && $SETUP_CMD"
fi

cat > /usr/local/bin/agent-push <<PUSH
#!/bin/bash
# agent-push <branch>: Branch des Agenten holen und als root pushen.
# Holt per fetch in den root-eigenen Klon - Git im Klon des Agenten wird
# nicht aufgerufen (dort koennten Hooks des Agenten liegen).
set -euo pipefail
B="\${1:?Usage: agent-push <branch>, z.B. agent/<slug>}"
cd "$PUSHDIR"
git -c safe.directory="$DIR" fetch "file://$DIR" "\$B:\$B"
git log --oneline -5 "\$B"
git push origin "\$B"
PUSH
chmod 700 /usr/local/bin/agent-push

step "8/8 Umgebung agent"
grep -q OLLAMA_BASE_URL /home/agent/.bashrc 2>/dev/null || cat >> /home/agent/.bashrc <<ENV
export OLLAMA_BASE_URL=http://127.0.0.1:11434/v1
cd $DIR
ENV
mkdir -p /home/agent/.claude
[ -f /home/agent/.claude/settings.json ] || cat > /home/agent/.claude/settings.json <<'SET'
{ "permissions": { "defaultMode": "bypassPermissions" }, "skipDangerousModePermissionPrompt": true }
SET
chown -R agent:agent /home/agent/.claude

echo; echo "=== Kontrolle"
sudo -u agent bash -c "cd '$DIR' && touch .git/.rw-probe && rm .git/.rw-probe && echo 'agent kann committen: ok'"
sudo -u agent bash -c "ls ~/.ssh 2>/dev/null | grep -q . && echo 'FEHLER: agent hat ~/.ssh' || echo 'agent ohne Schluessel: ok'"
sudo -u agent bash -c "test -r $KEY && echo 'FEHLER: agent kann den Push-Schluessel lesen' || echo 'Push-Schluessel fuer agent unlesbar: ok'"
ssh-keygen -y -P "" -f "$KEY" >/dev/null 2>&1 && echo "WARNUNG: Push-Schluessel ohne Passphrase" || echo "Push-Schluessel mit Passphrase: ok"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader || true
echo "Weiter: su - agent ; tmux new -s orch ; claude"
echo "Pushen (als root): agent-push agent/<slug>"
