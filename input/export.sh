#!/bin/bash
# Momentaufnahme aller Mess- und Verlaufsdaten fuer spaetere Analyse/Berichte.
# Aufruf aus dem Repo-Root: .agent/runs/export.sh
# Ergebnis: .agent/runs/export-<UTC-Zeitstempel>/
#   raw/   Gespraechsprotokolle (Claude Code, inkl. Subagenten) + opencode-DB  -> gitignored
#   repo/  Kopie der Repo-Messdaten (metrics.jsonl, PROGRESS, AUFTRAG)        -> versioniert
# Wiederholbar: jeder Aufruf erzeugt einen neuen Ordner, nichts wird ueberschrieben.
set -euo pipefail
cd "$(dirname "$0")/../.."
TS=$(date -u +%Y-%m-%dT%H%MZ)
OUT=.agent/runs/export-$TS
mkdir -p "$OUT/raw/claude" "$OUT/repo"

# Claude-Code-Gespraechsprotokolle dieses Projekts (Hauptsitzung(en) + Subagenten)
cp -r ~/.claude/projects/-work/*.jsonl "$OUT/raw/claude/" 2>/dev/null || true
for d in ~/.claude/projects/-work/*/; do
  [ -d "$d/subagents" ] && mkdir -p "$OUT/raw/claude/$(basename "$d")" \
    && cp -r "$d/subagents" "$OUT/raw/claude/$(basename "$d")/"
done

# opencode-Datenbank konsistent sichern (laufende Sitzung darf weiterschreiben)
DB=~/.local/share/opencode/opencode.db
if [ -f "$DB" ]; then
  python3 -c "import sqlite3,sys; s=sqlite3.connect(sys.argv[1]); d=sqlite3.connect(sys.argv[2]); s.backup(d); d.close()" \
    "$DB" "$OUT/raw/opencode.db"
fi

cp .agent/runs/metrics.jsonl .agent/state/PROGRESS.md .agent/state/AUFTRAG.md "$OUT/repo/"
( cd "$OUT" && find . -type f -exec sha256sum {} + | sort -k2 > SHA256SUMS )
echo "Export: $OUT"; du -sh "$OUT"/raw "$OUT"/repo
