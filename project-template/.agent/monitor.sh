#!/usr/bin/env bash
# Beobachtet den laufenden run-role.sh-Lauf und meldet sich, wenn er endet.
#
#   .agent/monitor.sh [--wait] [--replace] [intervall-sekunden]   (Default 30)
#
# Fuer ein zweites Terminal oder als Skript fuer das Monitor-Werkzeug von
# Claude Code: eine Zeile je Intervall, am Ende eine Schlusszeile, dann
# Exit. Ohne laufenden Lauf endet es sofort - mit --wait wartet es auf den
# naechsten.
#
# Zwei Fehler des frueheren Behelfs (Retro 7, pwd-transform) sind hier
# ausgeschlossen:
#   - Keine Prozesssuche per Muster: "pgrep -f run-role" fand sich selbst,
#     weil das Muster in der eigenen Kommandozeile stand. run-role.sh
#     schreibt stattdessen .agent/runs/current.json (PID, Rolle, Task, ...),
#     und hier wird nur diese PID mit "kill -0" geprueft.
#   - Nur eine Instanz: alte Monitore liefen weiter und meldeten doppelt.
#     Eine Sperrdatei verhindert das; --replace beendet den alten.

set -uo pipefail

RUNS=".agent/runs"
CURRENT="$RUNS/current.json"
LOCK="$RUNS/monitor.lock"
METRICS="$RUNS/metrics.jsonl"
WAIT=0; REPLACE=0; INTERVAL=30
for a in "$@"; do
  case "$a" in
    --wait) WAIT=1 ;;
    --replace) REPLACE=1 ;;
    ''|*[!0-9]*) echo "Usage: monitor.sh [--wait] [--replace] [intervall]" >&2; exit 2 ;;
    *) INTERVAL="$a" ;;
  esac
done
mkdir -p "$RUNS"

if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  OLD="$(cat "$LOCK")"
  if [ "$REPLACE" = 1 ]; then
    kill "$OLD" 2>/dev/null; sleep 1
    echo "alter Monitor (PID $OLD) beendet"
  else
    echo "Monitor laeuft bereits (PID $OLD) - mit --replace ersetzen." >&2
    exit 1
  fi
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

field() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2],""))' "$CURRENT" "$1" 2>/dev/null; }

vram() {
  [ -n "${OLLAMA_BASE_URL:-}" ] || return 0
  curl -fsS --max-time 3 "${OLLAMA_BASE_URL%/v1}/api/ps" 2>/dev/null | python3 -c 'import json,sys
try:
    ms=json.load(sys.stdin).get("models",[])
    print(" | VRAM %.1f GB" % (sum(m.get("size_vram",0) for m in ms)/1e9))
except Exception: pass' 2>/dev/null
}

# Auf einen Lauf warten (nur mit --wait).
while [ ! -f "$CURRENT" ]; do
  [ "$WAIT" = 1 ] || { echo "kein Lauf aktiv ($CURRENT fehlt)"; exit 0; }
  sleep "$INTERVAL"
done

PID="$(field pid)"; ROLE="$(field role)"; TASK="$(field task)"; ATT="$(field attempt)"
START_S="$(field start_s)"; TIMEOUT="$(field timeout_s)"; LOGF="$(field log)"
echo "Lauf: $ROLE / $TASK (Versuch $ATT), Modell $(field model), Log $LOGF"

LAST_SIZE=-1; LAST_CHANGE=$(date +%s)
while kill -0 "$PID" 2>/dev/null; do
  NOW=$(date +%s)
  SIZE=$(wc -c < "$LOGF" 2>/dev/null || echo 0)
  if [ "$SIZE" != "$LAST_SIZE" ]; then LAST_SIZE=$SIZE; LAST_CHANGE=$NOW; fi
  STILL=$(( (NOW - LAST_CHANGE) / 60 ))
  NOTE=""; [ "$STILL" -ge 5 ] && NOTE=" | Log seit ${STILL} min unveraendert (lange Denkphase oder haengt?)"
  printf '%s  %s/%s #%s  %ss / %ss  Log %s B%s%s\n' "$(date +%H:%M)" "$ROLE" "$TASK" "$ATT" \
    "$(( NOW - START_S ))" "$TIMEOUT" "$SIZE" "$NOTE" "$(vram)"
  sleep "$INTERVAL"
done

# Schlusszeile aus den Messdaten (run-role.sh schreibt sie am Laufende).
sleep 2
python3 - "$METRICS" "$TASK" "$ROLE" "$ATT" <<'PY' 2>/dev/null || echo "Lauf beendet (keine Messzeile gefunden)"
import json,sys
p,task,role,att=sys.argv[1:]
last=None
for l in open(p):
    try: d=json.loads(l)
    except Exception: continue
    if d.get("type")=="run" and d.get("task")==task and d.get("role")==role and str(d.get("attempt"))==att:
        last=d
if not last: raise SystemExit(1)
v="ja" if last.get("verdict_line") else "FEHLT"
print("Lauf beendet: run-role exit=%s, %ss, Verdict-Zeile %s, %s Datei(en) geaendert%s" % (
    last.get("wrapper_exit", last.get("exit")), last.get("duration_s"), v,
    last.get("files_changed"),
    (" - ABBRUCH: " + last["problem"]) if last.get("problem") else ""))
PY
