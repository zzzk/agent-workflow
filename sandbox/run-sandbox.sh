#!/usr/bin/env bash
# Startet die Agent-Sandbox für ein Projekt.
# Sicherheits-Hintergrund: SANDBOX_BOOTSTRAP_PATTERN.md; Ablauf mit Bild:
# README.md, Abschnitt "Commit-Flow".
#
# Usage: ./run-sandbox.sh [--new] [--shared] /pfad/zum/projekt [image-name]
#
# Normalfall (ohne --shared): Der Agent arbeitet in einem eigenen Klon,
# der nur in einem Docker-Volume liegt (agent-<projekt>-work, im Container
# /work). Zwischen Host und Sandbox gibt es KEINEN geteilten Ordner; das
# einzige Interface ist Git:
#   - Beim ersten Start schiebt das Skript den aktuellen Branch deines
#     Repos in das Volume (nur Committetes). Der Container braucht dafuer
#     weder Netz zu GitHub noch Zugangsdaten.
#   - Es traegt in DEINEM Repo das Remote "agent" ein: "git fetch agent"
#     holt die Branches agent/* des Agenten, "git push agent ..." liefert
#     ihm etwas zu. Die Gegenstelle laeuft in einem Wegwerf-Container
#     (agent-remote.sh); dein Git liest keine Datei aus dem .git des
#     Agenten, dessen Hooks und Config laufen nie auf deinem Rechner.
#   Der Agent committet frei; pushen kann er nicht (keine Zugangsdaten).
#
# --shared: frueherer Betrieb - Projektordner als Bind-Mount, .git
#   read-only. Der Agent kann nicht committen (der Orchestrator stoppt
#   dann), schreibt aber live in deinen Ordner. Nur fuer Arbeit ohne
#   Commits und um alte Container weiterzufuehren; siehe README.md,
#   "Warum kein geteilter Ordner".
#
# Bewusst KEIN --rm: Container bleiben nach `exit` erhalten (gestoppt),
# damit sich nachvollziehen laesst, was in der Sandbox passiert ist
# (`docker logs`, `docker diff`). Aufraeumen ist ein bewusster Schritt.
# Das Volume ueberlebt auch `docker rm` des Containers (z.B. fuer ein neues
# Image): der naechste Start legt einen neuen Container auf demselben
# Volume an. Weg ist die Arbeit des Agenten erst mit `docker volume rm` -
# vorher holen (git fetch agent).
#
# Container-Name: agent-<projektordnername>. Ein bestehender Container wird
# wiederverwendet (laufend -> exec rein, gestoppt -> `docker start -ai`).
# Gehoert er zu einem ANDEREN Projektpfad -> Abbruch. Mit `--new` entsteht
# ein zusaetzlicher Container agent-<projekt>-N mit eigenem Volume und
# eigenem Remote agent-N; die bestehenden bleiben unangetastet.

set -euo pipefail

# Git Bash (MSYS) unter Windows uebersetzt Pfad-Argumente wie "/c/Users/..."
# automatisch, bevor sie an nicht-MSYS-Programme wie docker.exe uebergeben
# werden. Bei den "-v host:container"-Argumenten hier fuehrt das zu
# kaputten/vermischten Pfaden (beobachtet: ein Fantom-Verzeichnis wurde im
# echten Projektordner angelegt). MSYS_NO_PATHCONV=1 schaltet diese
# Übersetzung ab; auf Linux/macOS ist die Variable wirkungslos, daher hier
# unbedingt und nicht optional gesetzt.
export MSYS_NO_PATHCONV=1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USAGE="Usage: run-sandbox.sh [--new] [--shared] /pfad/zum/projekt [image-name]"

NEW_CONTAINER=0
SHARED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --new)    NEW_CONTAINER=1; shift ;;
    --shared) SHARED=1; shift ;;
    --git-rw)
      echo "Fehler: --git-rw gibt es nicht mehr. Der Agent committet jetzt im" >&2
      echo "Normalfall (ohne Option) in einem eigenen Volume - siehe README.md," >&2
      echo "Abschnitt \"Commit-Flow\"." >&2
      exit 1 ;;
    --*)      echo "Fehler: unbekannte Option '$1'." >&2; exit 1 ;;
    *)        break ;;
  esac
done

PROJECT_DIR="${1:?$USAGE}"
IMAGE_NAME="${2:-agent-sandbox:latest}"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Fehler: Projektverzeichnis '$PROJECT_DIR' existiert nicht." >&2
  exit 1
fi
ABS_PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Projektname aus dem Verzeichnisnamen ableiten, auf Docker-taugliche Zeichen
# beschränken (Docker-Namen: [a-zA-Z0-9][a-zA-Z0-9_.-]*).
PROJECT_SLUG="$(basename "$ABS_PROJECT_DIR" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_.-]+/-/g; s/^-+|-+$//g')"
if [ -z "$PROJECT_SLUG" ]; then
  PROJECT_SLUG="project"
fi
BASE_NAME="agent-${PROJECT_SLUG}"

# Lokale Modelle (Ollama) laufen auf dem HOST. Docker Desktop (macOS/Windows)
# legt "host.docker.internal" von selbst an; die native Docker Engine unter
# Linux nicht. Das Flag ist auf Docker Desktop wirkungslos und macht den
# Start damit plattformunabhaengig. Siehe README.md, Abschnitt "Dienste auf
# dem Host erreichen".
HOST_GATEWAY_ARGS=(--add-host=host.docker.internal:host-gateway)

LABEL_MODE="agent-workflow.mode"
LABEL_PROJECT="agent-workflow.project"

# Fehlendes Label: leer (je nach Docker-Version sonst "<no value>").
label_of() {
  docker inspect -f "{{index .Config.Labels \"$2\"}}" "$1" 2>/dev/null | sed 's/^<no value>$//' || true
}
volume_label_of() {
  docker volume inspect -f "{{index .Labels \"$2\"}}" "$1" 2>/dev/null | sed 's/^<no value>$//' || true
}
mount_source_of() {
  docker inspect -f '{{range .Mounts}}{{if eq .Destination "/work"}}{{.Source}}{{end}}{{end}}' "$1" 2>/dev/null
}
# Git-Modus eines Containers aus dem frueheren Betrieb: "false" = eigener
# read-only Mount auf /work/.git, leer = beschreibbar (frueheres --git-rw).
git_mode_of() {
  docker inspect -f '{{range .Mounts}}{{if eq .Destination "/work/.git"}}{{.RW}}{{end}}{{end}}' "$1" 2>/dev/null
}
exists_container() { docker container inspect "$1" >/dev/null 2>&1; }
exists_volume()    { docker volume inspect "$1" >/dev/null 2>&1; }

# Bestehenden Container fortsetzen (laufend -> exec, gestoppt -> start -ai).
resume() {
  if [ "$(docker inspect -f '{{.State.Running}}' "$1")" = "true" ]; then
    echo "Container '$1' läuft bereits — steige per exec ein." >&2
    exec docker exec -it "$1" bash
  fi
  echo "Container '$1' existiert (gestoppt) — setze Session fort." >&2
  exec docker start -ai "$1"
}

# --- Namen: Container, Volume, Remote ---------------------------------------
if [ "$NEW_CONTAINER" = 1 ]; then
  N=1
  while exists_container "${BASE_NAME}-${N}" || exists_volume "${BASE_NAME}-${N}-work"; do
    N=$((N + 1))
  done
  NAME="${BASE_NAME}-${N}"
  REMOTE="agent-${N}"
else
  NAME="$BASE_NAME"
  REMOTE="agent"
fi
VOLUME="${NAME}-work"

# --- Frueherer Betrieb: geteilter Ordner, .git read-only ---------------------
if [ "$SHARED" = 1 ]; then
  if exists_container "$NAME"; then
    if [ "$(label_of "$NAME" "$LABEL_MODE")" = "volume" ]; then
      echo "Fehler: Container '$NAME' arbeitet mit eigenem Volume, nicht mit" >&2
      echo "geteiltem Ordner. Ohne --shared starten." >&2
      exit 1
    fi
    EXISTING_SOURCE="$(mount_source_of "$NAME")"
    if [ "$EXISTING_SOURCE" != "$ABS_PROJECT_DIR" ]; then
      echo "Fehler: Container '$NAME' gehoert zu einem anderen Projektverzeichnis" >&2
      echo "('$EXISTING_SOURCE' statt '$ABS_PROJECT_DIR'). Mit --new einen" >&2
      echo "zusaetzlichen Container anlegen, oder erst 'docker rm $NAME'." >&2
      exit 1
    fi
    if [ -d "$ABS_PROJECT_DIR/.git" ] && [ -z "$(git_mode_of "$NAME")" ]; then
      echo "Fehler: Container '$NAME' hat .git beschreibbar (frueheres --git-rw)." >&2
      echo "Das gibt es nicht mehr: 'docker rm $NAME' und ohne --shared neu starten." >&2
      exit 1
    fi
    resume "$NAME"
  fi
  GIT_MOUNT_ARGS=()
  if [ -d "$ABS_PROJECT_DIR/.git" ]; then
    GIT_MOUNT_ARGS=(-v "$ABS_PROJECT_DIR/.git:/work/.git:ro")
  fi
  echo "Geteilter Ordner (--shared): .git read-only, der Agent schreibt live in" >&2
  echo "'$ABS_PROJECT_DIR'. Neuer Container: $NAME" >&2
  exec docker run -it \
    --name "$NAME" \
    --label "$LABEL_MODE=shared" \
    --label "$LABEL_PROJECT=$ABS_PROJECT_DIR" \
    -v "$ABS_PROJECT_DIR:/work" \
    ${GIT_MOUNT_ARGS[@]+"${GIT_MOUNT_ARGS[@]}"} \
    "${HOST_GATEWAY_ARGS[@]}" \
    "$IMAGE_NAME" \
    bash
fi

# --- Normalfall: eigener Klon im Volume ---------------------------------------
if exists_container "$NAME"; then
  if [ "$(label_of "$NAME" "$LABEL_MODE")" != "volume" ]; then
    echo "Fehler: Container '$NAME' stammt aus dem frueheren Betrieb (geteilter" >&2
    echo "Ordner). Weiterfuehren mit --shared, oder 'docker rm $NAME' und neu" >&2
    echo "starten (dein Projektordner bleibt dabei unberuehrt)." >&2
    exit 1
  fi
  EXISTING_PROJECT="$(label_of "$NAME" "$LABEL_PROJECT")"
  if [ "$EXISTING_PROJECT" != "$ABS_PROJECT_DIR" ]; then
    echo "Fehler: Container '$NAME' gehoert zu einem anderen Projektverzeichnis" >&2
    echo "('$EXISTING_PROJECT' statt '$ABS_PROJECT_DIR'). Mit --new einen" >&2
    echo "zusaetzlichen Container anlegen." >&2
    exit 1
  fi
  resume "$NAME"
fi

G() { git -C "$ABS_PROJECT_DIR" "$@"; }

G rev-parse --git-dir >/dev/null 2>&1 || {
  echo "Fehler: '$ABS_PROJECT_DIR' ist kein Git-Repo. Die Sandbox tauscht Arbeit" >&2
  echo "nur ueber Git aus: erst 'git init' und einen ersten Commit." >&2
  exit 1
}

# Ein gleichnamiges Remote, das nicht von der Sandbox stammt, wird nicht
# ueberschrieben - geprueft, bevor irgendetwas angelegt wird.
if G config --get "remote.$REMOTE.url" >/dev/null 2>&1 &&
   ! G config --get "remote.$REMOTE.uploadpack" 2>/dev/null | grep -q 'agent-remote\.sh'; then
  echo "Fehler: Dein Repo hat schon ein Remote '$REMOTE', das nicht von der" >&2
  echo "Sandbox stammt. Umbenennen (git remote rename $REMOTE ...) und neu starten." >&2
  exit 1
fi

# Remote in DEINEM Repo eintragen.
register_remote() {
  local q_script q_vol q_img
  q_script="$(printf '%q' "$SCRIPT_DIR/agent-remote.sh")"
  q_vol="$(printf '%q' "$VOLUME")"
  q_img="$(printf '%q' "$IMAGE_NAME")"
  G config --get "remote.$REMOTE.url" >/dev/null 2>&1 || G remote add "$REMOTE" /work
  G config "remote.$REMOTE.url" /work
  # Ueber "bash" statt direkt: haengt nicht am Ausfuehrbar-Bit (Windows,
  # Kopie ohne Rechte).
  G config "remote.$REMOTE.uploadpack"  "bash $q_script $q_vol $q_img upload-pack"
  G config "remote.$REMOTE.receivepack" "bash $q_script $q_vol $q_img receive-pack"
  # Nur die Arbeitsbranches des Agenten holen: agent/<slug> erscheint bei
  # dir als $REMOTE/<slug>. Keine Tags (fremde Tags haben hier nichts zu
  # suchen).
  G config --replace-all "remote.$REMOTE.fetch" "+refs/heads/agent/*:refs/remotes/$REMOTE/*"
  G config "remote.$REMOTE.tagOpt" --no-tags
}

in_volume() {   # Befehl im Wegwerf-Container auf dem Volume, ohne Netz
  docker run --rm --network none -v "$VOLUME:/work" "$IMAGE_NAME" "$@"
}

# Jeder Schritt prueft, ob er schon erledigt ist: Bricht ein erster Start
# ab, setzt der naechste dort fort, statt ein halbes Volume zu hinterlassen.
if exists_volume "$VOLUME"; then
  VOL_PROJECT="$(volume_label_of "$VOLUME" "$LABEL_PROJECT")"
  if [ "$VOL_PROJECT" != "$ABS_PROJECT_DIR" ]; then
    echo "Fehler: Volume '$VOLUME' gehoert zu '$VOL_PROJECT', nicht zu" >&2
    echo "'$ABS_PROJECT_DIR'. Mit --new ein eigenes anlegen." >&2
    exit 1
  fi
else
  docker volume create --label "$LABEL_PROJECT=$ABS_PROJECT_DIR" "$VOLUME" >/dev/null
  # Ein frisches Volume uebernimmt den Besitzer von /work aus dem Image -
  # je nach Docker-Version root. Der Agent laeuft als "agent".
  docker run --rm --network none -u root -v "$VOLUME:/work" "$IMAGE_NAME" chown agent:agent /work
fi

if ! in_volume test -d /work/.git; then
  # Leeres Repo mit Platzhalter-HEAD: Git nimmt keinen Push auf den
  # ausgecheckten Branch an, also darf der hineingeschobene es nicht sein.
  in_volume sh -c 'git init -q -b _leer /work &&
    git -C /work config user.name "$1" &&
    git -C /work config user.email agent@noreply.invalid' sh "Agent ($PROJECT_SLUG)"
fi

register_remote

if in_volume git -C /work rev-parse --verify -q HEAD >/dev/null 2>&1; then
  echo "Volume '$VOLUME' vorhanden - neuer Container auf dem bisherigen Klon." >&2
else
  BRANCH="$(G symbolic-ref --quiet --short HEAD)" || {
    echo "Fehler: In deinem Repo ist kein Branch ausgecheckt (detached HEAD)." >&2
    exit 1
  }
  G rev-parse --verify -q HEAD >/dev/null || {
    echo "Fehler: Branch '$BRANCH' hat noch keinen Commit." >&2
    exit 1
  }
  echo "Volume '$VOLUME': schiebe Branch '$BRANCH' hinein (nur Committetes -" >&2
  echo "uncommittete Aenderungen bleiben bei dir)." >&2
  # --no-verify: interne Uebergabe, keine Veroeffentlichung - deine
  # pre-push-Hooks (Tests, Lint) sind dafuer nicht gemeint.
  G push --quiet --no-verify "$REMOTE" "refs/heads/$BRANCH:refs/heads/$BRANCH"
  in_volume git -C /work checkout -q "$BRANCH"
fi

echo "Remote '$REMOTE' in deinem Repo: 'git fetch $REMOTE' holt agent/<slug> als" >&2
echo "$REMOTE/<slug>; vor Auschecken und Push: review-branch.sh $REMOTE/<slug>." >&2
echo "Neuer Container: $NAME (Volume $VOLUME)" >&2

exec docker run -it \
  --name "$NAME" \
  --label "$LABEL_MODE=volume" \
  --label "$LABEL_PROJECT=$ABS_PROJECT_DIR" \
  -v "$VOLUME:/work" \
  "${HOST_GATEWAY_ARGS[@]}" \
  "$IMAGE_NAME" \
  bash
