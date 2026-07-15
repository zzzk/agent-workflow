#!/usr/bin/env bash
# Startet die Agent-Sandbox für ein Projektverzeichnis.
# Sicherheits-Hintergrund: SANDBOX_BOOTSTRAP_PATTERN.md in diesem Ordner.
#
# Usage: ./run-sandbox.sh /pfad/zum/projekt [image-name]
#
# Wichtig (siehe Pattern-Doku Schritt 1+2):
# - bypassPermissions wird NICHT hier gesetzt, sondern muss der Agent selbst
#   user-scoped (~/.claude/settings.json IM Container) anlegen, sobald er
#   drin ist und Schritt 0 (Selbstcheck) bestanden hat.
# - .git wird zusätzlich read-only gemountet (spezifischerer Mount NACH dem
#   allgemeinen Projekt-Mount, damit er darüberliegt).

set -euo pipefail

IMAGE_NAME="${2:-agent-sandbox:latest}"
PROJECT_DIR="${1:?Usage: run-sandbox.sh /pfad/zum/projekt [image-name]}"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Fehler: Projektverzeichnis '$PROJECT_DIR' existiert nicht." >&2
  exit 1
fi

if [ ! -d "$PROJECT_DIR/.git" ]; then
  echo "Warnung: '$PROJECT_DIR/.git' nicht gefunden — Sandbox startet ohne" >&2
  echo "read-only Git-Mount. Falls das Projekt ein Git-Repo ist, prüfen." >&2
  GIT_MOUNT_ARGS=()
else
  GIT_MOUNT_ARGS=(-v "$PROJECT_DIR/.git:/work/.git:ro")
fi

docker run -it --rm \
  -v "$PROJECT_DIR:/work" \
  "${GIT_MOUNT_ARGS[@]}" \
  "$IMAGE_NAME" \
  bash
