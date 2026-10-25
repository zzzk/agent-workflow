#!/usr/bin/env bash
# Momentaufnahme aller Mess- und Verlaufsdaten fuer spaetere Auswertung.
#
#   .agent/export.sh          (aus dem Projekt-Root)
#
# Ergebnis: .agent/runs/export-<UTC-Zeitstempel>/
#   raw/   Gespraechsprotokolle (Claude Code, inkl. Subagenten) + opencode-DB
#   repo/  Kopie der Messdaten (metrics.jsonl, PROGRESS.md, AUFTRAG.md)
#   SHA256SUMS
#
# Wann: vor jedem Compact einer langen Session und beim Abschluss jeder
# Initiative (orchestrator.md, Schritt 9). .agent/runs/ ist nicht
# versioniert und die Gespraechsprotokolle liegen ausserhalb des Repos -
# ohne Export sind die Rohdaten einer Messreihe nach dem naechsten Compact
# bzw. Container-Neustart weg. Wiederholbar: jeder Aufruf legt einen neuen
# Ordner an, nichts wird ueberschrieben.
set -euo pipefail
cd "$(dirname "$0")/.."

TS=$(date -u +%Y-%m-%dT%H%MZ)
OUT=.agent/runs/export-$TS
mkdir -p "$OUT/raw/claude" "$OUT/repo"

# Claude Code legt die Protokolle unter ~/.claude/projects/<Pfad> ab, wobei
# "/" und "." im Projektpfad zu "-" werden (/work -> -work).
PROJ_KEY="$(pwd | sed 's#[/.]#-#g')"
CLAUDE_DIR="$HOME/.claude/projects/$PROJ_KEY"
if [ -d "$CLAUDE_DIR" ]; then
  cp "$CLAUDE_DIR"/*.jsonl "$OUT/raw/claude/" 2>/dev/null || true
  for d in "$CLAUDE_DIR"/*/; do
    [ -d "$d/subagents" ] || continue
    mkdir -p "$OUT/raw/claude/$(basename "$d")"
    cp -r "$d/subagents" "$OUT/raw/claude/$(basename "$d")/"
  done
else
  echo "Hinweis: keine Claude-Protokolle unter $CLAUDE_DIR" >&2
fi

# opencode-Datenbank konsistent sichern (eine laufende Sitzung darf
# weiterschreiben - deshalb sqlite-Backup statt cp).
DB="$HOME/.local/share/opencode/opencode.db"
if [ -f "$DB" ]; then
  python3 -c "import sqlite3,sys; s=sqlite3.connect(sys.argv[1]); d=sqlite3.connect(sys.argv[2]); s.backup(d); d.close()" \
    "$DB" "$OUT/raw/opencode.db"
fi

for f in .agent/runs/metrics.jsonl .agent/state/PROGRESS.md .agent/state/AUFTRAG.md; do
  [ -f "$f" ] && cp "$f" "$OUT/repo/"
done
( cd "$OUT" && find . -type f ! -name SHA256SUMS -exec sha256sum {} + | sort -k2 > SHA256SUMS )
echo "Export: $OUT"
du -sh "$OUT/raw" "$OUT/repo"
