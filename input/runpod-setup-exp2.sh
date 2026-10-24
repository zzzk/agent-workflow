#!/bin/bash
# Einrichtung runpod-Pod fuer exp2 (RTX 3090), Stand nach exp3.
# Ollama kommt aus dem Template (Env-Variablen im Pod gesetzt), nicht von hier.
#
# Neu gegenueber exp3: Commit-Waechter. Kein Agent kann direkt committen;
# .git gehoert dem User "gitops". Der Orchestrator (User "agent") darf nur
#   sudo -u gitops /usr/local/bin/commit-cp <CP-Nr>
# aufrufen. Das Skript prueft Branch, Commit-Punkt, erlaubte Pfade, keine
# geloeschten Dateien, keine Secrets, Testanzahl nicht gesunken, npm test gruen –
# erst dann commit + push (nie --force).
#
# Aufruf als root:
#   REPO=git@github.com:zzzk/pwd-transform.git BRANCH=exp2-runpod-rtx3090 bash runpod-setup-exp2.sh
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

: "${REPO:?REPO setzen}"
: "${BRANCH:?BRANCH setzen}"
VOL="${VOL:-/opt/exp}"   # Container-Disk; Network Volume ist zu langsam/kein chmod
DIR="$VOL/pwd-transform"
MODEL="qwen3.8:27b"
MODEL_DIGEST="aaee06c39dcf2437cde036998d960e1fc1494b8191be7cc9657d01e509097813"
OPENCODE_VERSION="1.18.32"
CLAUDE_VERSION="2.1.281"

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
for p in $(pgrep -f "ollama serve"); do tr '\0' '\n' < /proc/$p/environ | grep ^OLLAMA; done | sort -u
ollama list | grep -q "^$MODEL" || ollama pull "$MODEL"
got="$(curl -fsS http://127.0.0.1:11434/api/tags | grep -o "\"name\":\"$MODEL\"[^}]*\"digest\":\"[0-9a-f]*" | grep -o '[0-9a-f]\{64\}' || true)"
[ "$got" = "$MODEL_DIGEST" ] && echo "Modell-Digest identisch mit Exp 0" || echo "WARNUNG: Digest '$got' weicht ab"

step "5/8 User agent (Agenten) und gitops (nur Commits)"
id agent  >/dev/null 2>&1 || useradd -m -s /bin/bash agent
id gitops >/dev/null 2>&1 || useradd -m -s /bin/bash gitops

step "6/8 Deploy-Key fuer gitops"
if [ ! -f /home/gitops/.ssh/id_ed25519 ]; then
  sudo -u gitops mkdir -p /home/gitops/.ssh
  sudo -u gitops ssh-keygen -q -t ed25519 -N "" -f /home/gitops/.ssh/id_ed25519 -C "runpod-exp2-gitops"
fi
echo ">>> Diesen Key auf GitHub als Deploy-Key MIT Schreibrecht eintragen:"
cat /home/gitops/.ssh/id_ed25519.pub
read -r -p ">>> Eingetragen? Enter druecken ... " _
sudo -u gitops ssh -o StrictHostKeyChecking=accept-new -T git@github.com || true

step "7/8 Repo $BRANCH: Arbeitsbaum = agent, .git = gitops"
mkdir -p "$DIR"; chown gitops:gitops "$DIR"
[ -d "$DIR/.git" ] || sudo -u gitops git clone --branch "$BRANCH" "$REPO" "$DIR"
chown -R agent:agent "$DIR"
chown -R gitops:gitops "$DIR/.git"
chmod -R a+rX,go-w "$DIR/.git"
sudo -u agent  git config --global --add safe.directory "$DIR"
sudo -u gitops git config --global --add safe.directory "$DIR"
sudo -u gitops git -C "$DIR" config user.name  "Orchestrator exp2"
sudo -u gitops git -C "$DIR" config user.email "s.stoeckli@gmail.com"
sudo -u agent bash -c "cd '$DIR' && npm ci --silent && (cd .opencode && npm ci --silent)"

cat > /usr/local/bin/commit-cp <<EOF
#!/bin/bash
# Commit-Waechter: nur an Commit-Punkten, nichts loeschen, nie force-push.
set -euo pipefail
DIR="$DIR"; BRANCH="$BRANCH"
EOF
cat >> /usr/local/bin/commit-cp <<'EOF'
fail() { echo "ABGELEHNT: $*" >&2; exit 1; }
CP="${1:-}"
case "$CP" in
  1) TASK=TASK-0037.1 ;; 2) TASK=TASK-0047 ;; 3) TASK=TASK-0051 ;; 4) TASK=TASK-0055 ;;
  5) TASK=TASK-0059 ;; 6) TASK=TASK-0068 ;; 7) TASK=TASK-0073 ;;
  *) fail "Aufruf: commit-cp <1..7>" ;;
esac
cd "$DIR"
[ "$(git branch --show-current)" = "$BRANCH" ] || fail "falscher Branch"
grep -q '^status: done' .agent/tasks/$TASK-*.md || fail "$TASK ist nicht done – kein Commit-Punkt"
git log --format=%s | grep -q "^exp2 CP$CP " && fail "CP$CP ist schon committet"
# nur erlaubte Pfade
bad="$(git status --porcelain --untracked-files=all | cut -c4- | grep -v -E '^(\.agent/|extension/|tests/|README\.md$|USERMANUAL\.md$|ACCEPTANCE\.md$)' || true)"
[ -z "$bad" ] || fail "Aenderungen ausserhalb der erlaubten Pfade:
$bad"
# nichts geloescht
del="$(git ls-files --deleted)"
[ -z "$del" ] || fail "geloeschte Dateien:
$del"
# keine leer gemachten Dateien, keine Secrets
for f in $(git diff --name-only); do [ -s "$f" ] || fail "Datei geleert: $f"; done
git status --porcelain --untracked-files=all | cut -c4- | xargs -r grep -l -E 'BEGIN [A-Z ]*PRIVATE KEY|ssh-ed25519 AAAA' 2>/dev/null \
  && fail "moegliches Secret in obigen Dateien"
# Tests: Anzahl gesamt nicht gesunken
out="$(npm test 2>&1 | grep -E '^# (tests|fail) ')" || true
n="$(echo "$out" | awk '/^# tests/ {print $3}')"; f="$(echo "$out" | awk '/^# fail/ {print $3}')"
prev="$(cat .git/cp-testcount 2>/dev/null || echo 0)"
[ "${n:-0}" -ge "$prev" ] || fail "Testanzahl gesunken: $prev -> $n"
if [ "$CP" = 1 ]; then
  # CP1 liegt nach TEST_FIRST von TASK-0038: dessen Tests sind absichtlich rot.
  # Gruen sein muss alles ausser den Testdateien aus TASK-0038 files:.
  red="$(sed -n '/^files:/,/^[a-z_]*:/p' .agent/tasks/TASK-0038-*.md | grep -o 'tests/[^ ]*\.test\.js' || true)"
  [ -n "$red" ] || fail "TASK-0038 nennt keine Testdateien"
  for t in $red; do [ -s "$t" ] || fail "TEST_FIRST-Datei fehlt: $t"; done
  rest="$(find tests -name '*.test.js' | sort | grep -v -x -F "$red")"
  out2="$(node --test $rest 2>&1 | grep -E '^# fail ')" || true
  f2="$(echo "$out2" | awk '{print $3}')"
  [ "${f2:-1}" = "0" ] || fail "Tests ausserhalb von TASK-0038 nicht gruen ($out2)"
  echo "CP1: $f rote Tests nur in TASK-0038 (TEST_FIRST), Rest gruen"
else
  [ "${f:-1}" = "0" ] || fail "npm test nicht gruen ($out)"
fi
git add -A -- .agent extension tests $(ls README.md USERMANUAL.md ACCEPTANCE.md 2>/dev/null)
[ -z "$(git diff --cached --diff-filter=D --name-only)" ] || fail "Loeschung im Index"
git commit -q -m "exp2 CP$CP ($TASK done) – $(date -u +%Y-%m-%dT%H:%MZ)"
echo "$n" > .git/cp-testcount
git push -q origin "$BRANCH"
echo "OK: $(git log --oneline -1) gepusht, Tests $n"
EOF
chown root:root /usr/local/bin/commit-cp; chmod 755 /usr/local/bin/commit-cp
echo 'agent ALL=(gitops) NOPASSWD: /usr/local/bin/commit-cp' > /etc/sudoers.d/commit-cp
chmod 440 /etc/sudoers.d/commit-cp; visudo -cf /etc/sudoers.d/commit-cp

step "8/8 Umgebung agent"
grep -q OLLAMA_BASE_URL /home/agent/.bashrc 2>/dev/null || cat >> /home/agent/.bashrc <<EOF
export OLLAMA_BASE_URL=http://127.0.0.1:11434/v1
cd $DIR
EOF
mkdir -p /home/agent/.claude
[ -f /home/agent/.claude/settings.json ] || cat > /home/agent/.claude/settings.json <<'EOF'
{ "permissions": { "defaultMode": "bypassPermissions" }, "skipDangerousModePermissionPrompt": true }
EOF
chown -R agent:agent /home/agent/.claude

echo; echo "=== Kontrolle"
sudo -u agent bash -c "cd '$DIR' && touch .git/x 2>/dev/null && echo 'FEHLER: .git fuer agent schreibbar' || echo '.git fuer agent read-only: ok'"
sudo -u agent sudo -n -u gitops /usr/local/bin/commit-cp 9 2>&1 | head -1 || true   # erwartet: ABGELEHNT
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader || true
echo "Weiter: su - agent ; tmux new -s orch ; claude"
