#!/usr/bin/env bash
# Startet die Agent-Sandbox für ein Projektverzeichnis.
# Sicherheits-Hintergrund: SANDBOX_BOOTSTRAP_PATTERN.md in diesem Ordner.
#
# Usage: ./run-sandbox.sh [--new] /pfad/zum/projekt [image-name]
#
# Wichtig (siehe Pattern-Doku Schritt 1+2):
# - bypassPermissions wird NICHT hier gesetzt, sondern muss der Agent selbst
#   user-scoped (~/.claude/settings.json IM Container) anlegen, sobald er
#   drin ist und Schritt 0 (Selbstcheck) bestanden hat.
# - .git wird zusätzlich read-only gemountet (spezifischerer Mount NACH dem
#   allgemeinen Projekt-Mount, damit er darüberliegt).
# - Bewusst KEIN --rm: Container bleiben nach `exit` erhalten (nur gestoppt,
#   nicht gelöscht), damit sich im Nachhinein nachvollziehen lässt, was in
#   der Sandbox passiert ist (`docker logs`, `docker diff`). Aufräumen ist
#   ein bewusster, separater Schritt (`docker rm <name>`), keine Automatik.
#
# Container-Name: agent-<projektordnername>. Default: existierenden
# Container wiederverwenden (laufend -> exec rein, gestoppt -> `docker
# start -ai`), um eine unterbrochene Session fortzusetzen. Gehört der
# vorhandene Container zu einem ANDEREN Projektpfad (gleicher Ordnername,
# anderer Ort) -> Abbruch statt falscher Wiederverwendung. Mit `--new` wird
# immer ein zusätzlicher Container mit fortlaufender Nummer angelegt
# (agent-<projekt>-1, -2, ...), der/die bestehenden bleiben unangetastet.

set -euo pipefail

NEW_CONTAINER=0
if [ "${1:-}" = "--new" ]; then
  NEW_CONTAINER=1
  shift
fi

PROJECT_DIR="${1:?Usage: run-sandbox.sh [--new] /pfad/zum/projekt [image-name]}"
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

mount_source_of() {
  docker inspect -f '{{range .Mounts}}{{if eq .Destination "/work"}}{{.Source}}{{end}}{{end}}' "$1" 2>/dev/null
}

if [ ! -d "$PROJECT_DIR/.git" ]; then
  echo "Warnung: '$PROJECT_DIR/.git' nicht gefunden — Sandbox startet ohne" >&2
  echo "read-only Git-Mount. Falls das Projekt ein Git-Repo ist, prüfen." >&2
  GIT_MOUNT_ARGS=()
else
  GIT_MOUNT_ARGS=(-v "$PROJECT_DIR/.git:/work/.git:ro")
fi

if [ "$NEW_CONTAINER" = 1 ]; then
  N=1
  while docker container inspect "${BASE_NAME}-${N}" >/dev/null 2>&1; do
    N=$((N + 1))
  done
  CONTAINER_NAME="${BASE_NAME}-${N}"
  echo "Neuer Container: $CONTAINER_NAME (spaeter: docker logs/diff $CONTAINER_NAME)" >&2
  exec docker run -it \
    --name "$CONTAINER_NAME" \
    -v "$PROJECT_DIR:/work" \
    "${GIT_MOUNT_ARGS[@]}" \
    "$IMAGE_NAME" \
    bash
fi

if docker container inspect "$BASE_NAME" >/dev/null 2>&1; then
  EXISTING_SOURCE="$(mount_source_of "$BASE_NAME")"
  if [ "$EXISTING_SOURCE" != "$ABS_PROJECT_DIR" ]; then
    echo "Fehler: Container '$BASE_NAME' existiert bereits, aber fuer ein" >&2
    echo "anderes Projektverzeichnis ('$EXISTING_SOURCE' statt '$ABS_PROJECT_DIR')." >&2
    echo "Mit --new einen zusaetzlichen Container anlegen, oder erst" >&2
    echo "'docker rm $BASE_NAME' aufraeumen." >&2
    exit 1
  fi

  IS_RUNNING="$(docker inspect -f '{{.State.Running}}' "$BASE_NAME")"
  if [ "$IS_RUNNING" = "true" ]; then
    echo "Container '$BASE_NAME' läuft bereits — steige per exec ein." >&2
    exec docker exec -it "$BASE_NAME" bash
  else
    echo "Container '$BASE_NAME' existiert (gestoppt) — setze Session fort." >&2
    exec docker start -ai "$BASE_NAME"
  fi
fi

echo "Neuer Container: $BASE_NAME (spaeter: docker logs/diff/start -ai $BASE_NAME)" >&2

exec docker run -it \
  --name "$BASE_NAME" \
  -v "$PROJECT_DIR:/work" \
  "${GIT_MOUNT_ARGS[@]}" \
  "$IMAGE_NAME" \
  bash
