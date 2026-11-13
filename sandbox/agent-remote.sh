#!/usr/bin/env bash
# Git-Gegenstelle fuer das Remote "agent" in DEINEM Repo: laesst
# git-upload-pack (fuer fetch) bzw. git-receive-pack (fuer push) in einem
# Wegwerf-Container auf dem Volume des Agenten laufen.
#
# Nicht von Hand aufrufen. run-sandbox.sh traegt es in die Config deines
# Repos ein, Git ruft es auf:
#   remote.agent.uploadpack  = .../agent-remote.sh <volume> <image> upload-pack
#   remote.agent.receivepack = .../agent-remote.sh <volume> <image> receive-pack
# Git haengt den Pfad der Remote-URL an (/work); er wird ignoriert - im
# Container liegt das Repo immer unter /work.
#
# Warum das sicher ist: Hooks und Config des Agenten-Repos werden nur im
# Container ausgewertet. Das Git auf deinem Rechner liest keine Datei aus
# dem .git des Agenten, es spricht nur das Git-Protokoll ueber
# stdin/stdout - wie mit jedem fremden Remote.
#
# Warum ein Wegwerf-Container statt "docker exec" in die Sandbox: Er geht
# auch, wenn die Sandbox gestoppt ist, und laeuft ohne Netz.

set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash unter Windows: Pfade nicht umschreiben

VOLUME="${1:?Usage: agent-remote.sh <volume> <image> upload-pack|receive-pack}"
IMAGE="${2:?}"
SERVICE="${3:?}"
case "$SERVICE" in
  upload-pack|receive-pack) ;;
  *) echo "agent-remote.sh: nur upload-pack oder receive-pack" >&2; exit 2 ;;
esac

if ! docker volume inspect "$VOLUME" >/dev/null 2>&1; then
  echo "agent-remote.sh: Docker-Volume '$VOLUME' fehlt - Sandbox mit run-sandbox.sh anlegen." >&2
  exit 1
fi

exec docker run --rm -i --network none -v "$VOLUME:/work" "$IMAGE" "git-$SERVICE" /work
