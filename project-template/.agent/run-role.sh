#!/usr/bin/env bash
# Der EINZIGE Weg, eine Rolle in einem fremden Harness aufzurufen.
#
#   .agent/run-role.sh <rolle> <task-id> <versuch> <auftrag>
#   .agent/run-role.sh --verdict <task-id> <rolle> <versuch> <VERDICT>
#
# Warum ein Wrapper und nicht der nackte "opencode run"-Aufruf:
#
# 1. Zwei bekannte Fehlerbilder scheitern STILL und mit Exit-Code 0 - der
#    Lauf sieht im Log erfolgreich aus, hat aber nicht getan, was er sollte:
#      - "is a subagent, not a primary agent": OpenCode faellt auf den
#        Default-Agenten zurueck, ohne Rollen-Prompt und ohne permission-
#        Regeln (siehe HARNESS.md).
#      - "auto-rejecting": eine Berechtigung wurde still abgelehnt, der Lauf
#        lief weiter und hat nichts geschrieben.
#    Beide werden hier mechanisch geprueft. Eine Anweisung im Prompt
#    ("pruefe das Log auf ...") ist genau die Art Regel, die unter Last als
#    erstes uebersprungen wird.
#
# 2. Messung (Dauer, Ressourcen, Versuche) braucht einen Ort, der bei JEDEM
#    Lauf durchlaufen wird. Ein "falls Messung aktiv, tue X"-Zweig im
#    Rollen-Prompt waere wieder eine Compliance-Frage. Hier entscheidet das
#    Skript, nicht das Modell: der Aufruf ist immer derselbe.
#
# Schalter (Umgebungsvariablen):
#   AGENT_METRICS=0        Messung ABschalten. Default ist EIN - sie kostet
#                          praktisch nichts (ein /proc-Lesen alle 2 s, eine
#                          angehaengte JSONL-Zeile je Lauf, zwei kurze curls)
#                          und .agent/runs/ ist ohnehin nicht versioniert.
#                          Wer sie abschaltet, hat im Fehlerfall keine
#                          Historie - und der Fehlerfall ist genau der
#                          Moment, in dem man sie gebraucht haette.
#   AGENT_MAX_ATTEMPTS     Obergrenze der Versuche je Rolle und Task,
#                          Default 3. Darueber bricht dieses Skript ab,
#                          statt weiterzulaufen (siehe unten).
#   AGENT_ROLE_TIMEOUT     Sekunden, Default 2700 (siehe orchestrator.md)
#   OLLAMA_BASE_URL        fuer die VRAM-Abfrage; ohne sie entfaellt nur dieses Feld

set -uo pipefail

RUNS_DIR=".agent/runs"
METRICS="$RUNS_DIR/metrics.jsonl"
HALT=".agent/state/HALTED"
mkdir -p "$RUNS_DIR" .agent/state

# --- Not-Aus ---------------------------------------------------------------
# Liegt die HALT-Datei, laeuft GAR NICHTS mehr - keine andere Rolle, kein
# anderer Task. Tasks bauen in aller Regel aufeinander auf; nach einem
# gescheiterten Task weiterzumachen heisst, alles Folgende auf ein Fundament
# zu setzen, von dem man weiss, dass es nicht traegt.
#
# Warum als Datei und nicht als Anweisung im Prompt: Der Abbruch faellt nach
# vier gescheiterten Versuchen an - langer Kontext, starker Zug Richtung
# "irgendwie weiterkommen". Das ist die Stelle, an der Anweisungstreue am
# schwaechsten ist. Und der Fehler ist asymmetrisch: faelschlich anhalten
# kostet eine Rueckfrage, faelschlich weiterlaufen kostet alle Folge-Tasks.
#
# Aufheben ist bewusst ein menschlicher Akt: rm .agent/state/HALTED
if [ -f "$HALT" ]; then
  echo "GESTOPPT: Diese Initiative ist angehalten." >&2
  sed 's/^/  /' "$HALT" >&2
  echo "Es wird kein weiterer Baustein ausgefuehrt - auch nicht fuer einen" >&2
  echo "anderen Task. Der Nutzer entscheidet, wie es weitergeht; erst danach" >&2
  echo "'rm $HALT'." >&2
  exit 5
fi

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }

# --- Modus: Verdict nachtragen -------------------------------------------
# Das Verdict kennt nur der Orchestrator, nachdem er die Rueckmeldung
# gelesen hat. Es kommt deshalb als zweite Zeile dazu; der Report joint
# ueber (task, rolle, versuch).
if [ "${1:-}" = "--verdict" ]; then
  [ "${AGENT_METRICS:-1}" != "0" ] || exit 0
  printf '{"type":"verdict","task":%s,"role":%s,"attempt":%s,"verdict":%s,"ts":%s}\n' \
    "$(json_escape "${2:?task}")" "$(json_escape "${3:?rolle}")" "${4:?versuch}" \
    "$(json_escape "${5:?verdict}")" "$(json_escape "$(date -u +%FT%TZ)")" >> "$METRICS"
  exit 0
fi

# --- Modus: nur aufloesen, nichts ausfuehren ------------------------------
# Damit der Orchestrator VOR dem Aufruf weiss, ob eine Rolle in seinen
# eigenen Harness gehoert oder hierher - ohne raten zu muessen.
if [ "${1:-}" = "--resolve" ]; then
  R="${2:?rolle fehlt}"; T="${3:-}"
  awk -F'\t' -v r="$R" '$1==r {printf "runtime=%s modell=%s (Quelle: Rolle)\n", $2, $3}' \
    .agent/agents/_resolved.tsv
  [ -n "$T" ] || exit 0
  TF="$(ls .agent/tasks/${T}-*.md 2>/dev/null | head -1)"
  [ -n "$TF" ] && grep -E '^(runtime|model):[[:space:]]*[^[:space:]#]' "$TF" \
    | sed 's/^/Task-Override: /'
  exit 0
fi

ROLE="${1:?Usage: run-role.sh <rolle> <task-id> <versuch> <auftrag>}"
TASK="${2:?task-id fehlt}"
ATTEMPT="${3:?versuch fehlt (1 beim ersten Lauf)}"
PROMPT="${4:?auftrag fehlt}"
TIMEOUT="${AGENT_ROLE_TIMEOUT:-2700}"
LOG="$RUNS_DIR/${TASK}-${ROLE}-a${ATTEMPT}.log"

# --- Abbruchkriterium -----------------------------------------------------
# Ohne Obergrenze ist die CHANGES_NEEDED-Schleife (orchestrator.md, Schritt
# 8.7) unbegrenzt: Implementer und vorgelagerte Rolle koennen sich beliebig
# lange gegenseitig zurueckschicken. Ueber Nacht verbrennt das eine ganze
# Sitzung, ohne dass jemand es merkt. Die Grenze steht hier und nicht im
# Prompt, weil "hoere nach drei Versuchen auf" genau die Art Regel ist, die
# ein Modell im Eifer uebergeht - zumal es sich dabei selbst beschraenken
# muesste.
MAX_ATTEMPTS="${AGENT_MAX_ATTEMPTS:-3}"
if [ "$ATTEMPT" -gt "$MAX_ATTEMPTS" ]; then
  echo "ABBRUCH: Versuch $ATTEMPT fuer $ROLE / $TASK ueberschreitet die" >&2
  echo "Obergrenze von $MAX_ATTEMPTS. Der Task kommt aus eigener Kraft nicht" >&2
  echo "durch - das ist ein BLOCKED-Fall fuer den Nutzer, keine weitere Runde." >&2
  echo "Vorgehen: Task-Datei und die Logs der bisherigen Versuche vorlegen" >&2
  echo "($RUNS_DIR/${TASK}-${ROLE}-a*.log), Entscheid des Nutzers abwarten." >&2
  {
    echo "Angehalten: $(date -u +%FT%TZ)"
    echo "Grund: $ROLE hat $TASK nach $MAX_ATTEMPTS Versuchen nicht durchgebracht."
    echo "Logs:  $RUNS_DIR/${TASK}-${ROLE}-a*.log"
    echo "Weiter erst nach Entscheid des Nutzers, dann: rm $HALT"
  } > "$HALT"
  echo "Not-Aus gesetzt: $HALT - die Initiative ist damit angehalten." >&2
  if [ "${AGENT_METRICS:-1}" != "0" ]; then
    printf '{"type":"aborted","task":%s,"role":%s,"attempt":%s,"reason":"max_attempts","limit":%s,"ts":%s}\n' \
      "$(json_escape "$TASK")" "$(json_escape "$ROLE")" "$ATTEMPT" "$MAX_ATTEMPTS" \
      "$(json_escape "$(date -u +%FT%TZ)")" >> "$METRICS"
  fi
  exit 4
fi

# --- Aufloesung: Rolle bestimmt, Task darf ueberschreiben -----------------
# Harness und Modell sind Eigenschaften der ROLLE (<rolle>.meta.yml). Die
# Task-Datei ist der Sonderfall, nicht die Regel: sie ueberschreibt nur,
# wenn sie ein nicht-leeres runtime:/model: traegt. Aufgeloest wird hier
# und nicht im Prompt - sonst muesste der Orchestrator bei jedem Aufruf
# zwei Dateien im Kopf zusammenfuehren, und genau dort entstehen stille
# Fehler.
RESOLVED_FILE=".agent/agents/_resolved.tsv"
[ -f "$RESOLVED_FILE" ] || { echo "FEHLER: $RESOLVED_FILE fehlt - erst 'python3 .agent/sync-agents.py'." >&2; exit 2; }

read -r RUNTIME MODEL <<< "$(awk -F'\t' -v r="$ROLE" '$1==r {print $2, $3}' "$RESOLVED_FILE")"
[ -n "$RUNTIME" ] || { echo "FEHLER: Rolle '$ROLE' steht nicht in $RESOLVED_FILE." >&2; exit 2; }
SOURCE="Rolle"

# Task-Datei ueber die ID finden (Konvention: .agent/tasks/<ID>-<slug>.md).
TASK_FILE="$(ls .agent/tasks/${TASK}-*.md 2>/dev/null | head -1)"
if [ -n "$TASK_FILE" ]; then
  T_RUNTIME="$(awk -F: '/^runtime:/ {sub(/#.*/,"",$2); gsub(/[ \t]/,"",$2); print $2; exit}' "$TASK_FILE")"
  T_MODEL="$(awk '/^model:/ {sub(/^model:/,""); sub(/#.*/,""); gsub(/^[ \t]+|[ \t]+$/,""); print; exit}' "$TASK_FILE")"
  [ -n "$T_RUNTIME" ] && { RUNTIME="$T_RUNTIME"; SOURCE="Task-Datei"; }
  [ -n "$T_MODEL" ]   && { MODEL="$T_MODEL";   SOURCE="Task-Datei"; }
fi

# Dieser Wrapper fuehrt nur fremde Harnesses aus. Loest die Rolle auf
# "subagent" auf, gehoert der Aufruf in den eigenen Harness des
# Orchestrators - dort gibt es keinen Unterprozess, den man messen koennte.
if [ "$RUNTIME" != "opencode" ]; then
  echo "Rolle '$ROLE' laeuft als '$RUNTIME' (Quelle: $SOURCE), nicht ueber diesen" >&2
  echo "Wrapper. Rufe sie als nativen Sub-Agenten deines eigenen Harness auf." >&2
  exit 6
fi
[ -n "$MODEL" ] || { echo "FEHLER: kein Modell fuer Rolle '$ROLE' aufloesbar." >&2; exit 2; }

# VRAM vor dem Lauf: zeigt, ob das Modell kalt startet (erklaert Ausreisser
# in der Dauer, ohne die man die Zahlen falsch liest).
vram_now() {
  [ -n "${OLLAMA_BASE_URL:-}" ] || { echo "null"; return; }
  curl -fsS --max-time 3 "${OLLAMA_BASE_URL%/v1}/api/ps" 2>/dev/null \
    | python3 -c 'import sys,json
try:
    ms=json.load(sys.stdin).get("models",[])
    print(sum(m.get("size_vram",0) for m in ms) or 0)
except Exception: print("null")' 2>/dev/null || echo "null"
}
VRAM_BEFORE="$(vram_now)"

# Ressourcen des opencode-Prozesses mitschreiben. Bewusst nur Peak-RSS und
# CPU-Zeit: der Prozess ist im Mischbetrieb ein duenner HTTP-Client, die
# eigentliche Last liegt bei Ollama auf dem Host (dafuer .agent/sample-host.sh).
# Diese Zahlen beantworten "braucht die Sandbox mehr RAM?", nicht "was kostet
# die Inferenz?".
SAMPLE="$(mktemp)"
sample_loop() {
  # Bewusst ueber /proc und nicht ueber "ps": das schlanke Basis-Image hat
  # kein procps, und der Lauf faellt sonst still auf 0 zurueck (so passiert,
  # 2026-09-24). Summiert wird der GESAMTE Container, nicht ein einzelner
  # PID - opencode startet Kindprozesse, und die Frage lautet ohnehin
  # "wieviel RAM braucht die Sandbox", nicht "wieviel braucht ein Prozess".
  local pid=$1 peak=0 sum
  while kill -0 "$pid" 2>/dev/null; do
    sum=$(awk '/^VmRSS:/ {t+=$2} END {print t+0}' /proc/[0-9]*/status 2>/dev/null)
    [ -n "$sum" ] && [ "$sum" -gt "$peak" ] 2>/dev/null && peak=$sum
    sleep 2
  done
  echo "$peak" > "$SAMPLE"
}

START_TS="$(date -u +%FT%TZ)"
START_S=$(date +%s)

# --model nur bei einem Task-Override: ohne das Flag gilt die model-Zeile
# der generierten Rollen-Datei, und genau die ist der Normalfall.
MODEL_ARGS=()
[ "$SOURCE" = "Task-Datei" ] && MODEL_ARGS=(--model "$MODEL")

timeout "$TIMEOUT" opencode run \
  --agent "$ROLE" --dir . --auto "${MODEL_ARGS[@]}" "$PROMPT" > "$LOG" 2>&1 &
RUN_PID=$!
sample_loop "$RUN_PID" &
SAMPLE_PID=$!
wait "$RUN_PID"; EXIT=$?
wait "$SAMPLE_PID" 2>/dev/null
PEAK_RSS_KB="$(cat "$SAMPLE" 2>/dev/null || echo 0)"; rm -f "$SAMPLE"

DURATION=$(( $(date +%s) - START_S ))
VRAM_AFTER="$(vram_now)"

# --- Mechanische Pruefung der beiden stillen Fehlerbilder -----------------
FALLBACK=false; REJECTED=false; PROBLEM=""
grep -q "not a primary agent" "$LOG" 2>/dev/null && { FALLBACK=true
  PROBLEM="Rolle wurde NICHT ausgefuehrt (Fallback auf Default-Agent)"; }
grep -q "auto-rejecting" "$LOG" 2>/dev/null && { REJECTED=true
  PROBLEM="${PROBLEM:+$PROBLEM; }Berechtigung still abgelehnt"; }
[ "$EXIT" = "124" ] && PROBLEM="${PROBLEM:+$PROBLEM; }Timeout nach ${TIMEOUT}s"

# Gegenprobe aus der Ausgabe: welche Rolle und welches Modell liefen wirklich?
ACTUAL="$(grep -m1 '^>' "$LOG" 2>/dev/null | sed 's/^> *//')"

if [ "${AGENT_METRICS:-1}" != "0" ]; then
  CHANGED=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  printf '{"type":"run","task":%s,"role":%s,"attempt":%s,"model":%s,"actual":%s,"ts_start":%s,"duration_s":%s,"exit":%s,"peak_rss_kb":%s,"vram_before":%s,"vram_after":%s,"files_changed":%s,"fallback":%s,"auto_rejected":%s,"log":%s}\n' \
    "$(json_escape "$TASK")" "$(json_escape "$ROLE")" "$ATTEMPT" \
    "$(json_escape "$MODEL")" "$(json_escape "$ACTUAL")" "$(json_escape "$START_TS")" \
    "$DURATION" "$EXIT" "${PEAK_RSS_KB:-0}" "$VRAM_BEFORE" "$VRAM_AFTER" \
    "${CHANGED:-0}" "$FALLBACK" "$REJECTED" "$(json_escape "$LOG")" >> "$METRICS"
fi

echo "Lauf: $ROLE / $TASK (Versuch $ATTEMPT) – ${DURATION}s, exit=$EXIT"
echo "Tatsaechlich gelaufen: ${ACTUAL:-(keine >-Zeile im Log)}"
echo "Log: $LOG"

if [ -n "$PROBLEM" ]; then
  echo "ABBRUCH: $PROBLEM" >&2
  echo "Das Ergebnis dieses Laufs ist NICHT verwertbar - nicht weiterarbeiten." >&2
  exit 3
fi
exit "$EXIT"
