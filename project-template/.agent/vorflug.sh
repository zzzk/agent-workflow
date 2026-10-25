#!/usr/bin/env bash
# Vorflug-Check vor dem ERSTEN runtime: opencode-Lauf einer Session.
#
#   .agent/vorflug.sh [rolle] [task-id]      (Default-Rolle: implementer)
#
# Prueft, ob der Modell-Server bereit ist - und zwar so, wie die Rolle ihn
# gleich braucht, nicht nur "erreichbar". Zwei Fehlerbilder sind im Betrieb
# mehrfach durchgerutscht, weil "Modell geladen" allein nichts sagt:
#   - zu kleine Kontextlaenge (TASK-0003; nach einem OS-Update erneut):
#     Ollama schneidet still den Anfang ab, das Modell "vergisst" die
#     Task-Datei, oder opencode meldet "no user query found in messages";
#   - Modell nur teilweise auf der GPU (RTX 3090 mit 131k/262k Kontext):
#     ein Teil der Schichten laeuft auf der CPU, Laeufe dauern ein
#     Vielfaches.
#
# Ausgabe: je Pruefung eine Zeile OK / FEHLT / HINWEIS. Exit 1, sobald
# eine Zeile FEHLT lautet - dann nicht starten (orchestrator.md, Schritt 5).

set -uo pipefail

ROLE="${1:-implementer}"
TASK="${2:-}"
FAIL=0
ok()   { echo "OK      $*"; }
fehlt(){ echo "FEHLT   $*"; FAIL=1; }
hint() { echo "HINWEIS $*"; }

RESOLVED=".agent/agents/_resolved.tsv"
[ -f "$RESOLVED" ] || { fehlt "$RESOLVED fehlt - erst 'python3 .agent/sync-agents.py'"; exit 1; }
MODEL="$(awk -F'\t' -v r="$ROLE" '$1==r {print $3}' "$RESOLVED")"
if [ -n "$TASK" ]; then
  TF="$(ls .agent/tasks/${TASK}-*.md 2>/dev/null | head -1)"
  if [ -n "$TF" ]; then
    T_MODEL="$(awk '/^model:/ {sub(/^model:/,""); sub(/#.*/,""); gsub(/^[ \t]+|[ \t]+$/,""); print; exit}' "$TF")"
    [ -n "$T_MODEL" ] && MODEL="$T_MODEL"
  fi
fi
[ -n "$MODEL" ] || { fehlt "kein Modell fuer Rolle '$ROLE' aufloesbar"; exit 1; }
echo "Rolle $ROLE -> Modell $MODEL"

command -v opencode >/dev/null && ok "opencode installiert" \
  || fehlt "opencode nicht installiert"

# Erwartete Kontextlaenge: num_ctx des Modells in opencode.json.
expected_ctx() {
  python3 - "$1" "$2" <<'PY' 2>/dev/null
import json,sys
try:
    d=json.load(open("opencode.json"))
    m=d["provider"][sys.argv[1]]["models"][sys.argv[2]]
    print(m.get("options",{}).get("num_ctx",""))
except Exception:
    print("")
PY
}

PROVIDER="${MODEL%%/*}"
NAME="${MODEL#*/}"

case "$PROVIDER" in
  ollama)
    # Bewusst eine Kette: die Ursachen bauen aufeinander auf. Ist die
    # Variable leer, sind "nicht erreichbar" und "Modell fehlt" nur
    # Folgemeldungen und verdecken den Grund.
    BASE="${OLLAMA_BASE_URL:-}"; BASE="${BASE%/v1}"
    if [ -z "$BASE" ]; then
      fehlt "\$OLLAMA_BASE_URL ist leer"
    elif ! curl -fsS --max-time 5 "$BASE/api/version" >/dev/null 2>&1; then
      fehlt "$BASE nicht erreichbar"
    elif ! curl -fsS --max-time 5 "$BASE/api/tags" 2>/dev/null | grep -q "\"$NAME\""; then
      fehlt "Modell $NAME nicht vorhanden (ollama pull $NAME)"
    else
      ok "Ollama erreichbar, Modell $NAME vorhanden"
      # Laden, wie es der erste Lauf auch taete: ohne eigene Optionen, also
      # mit den Server-Einstellungen (OLLAMA_CONTEXT_LENGTH). Genau die
      # bekommt opencode ueber die OpenAI-kompatible Schnittstelle.
      curl -fsS --max-time 600 "$BASE/api/generate" \
        -d "{\"model\":\"$NAME\",\"prompt\":\"\",\"keep_alive\":\"30m\"}" >/dev/null 2>&1 \
        || hint "Modell liess sich nicht vorab laden - Pruefung unten evtl. unvollstaendig"
      PS="$(curl -fsS --max-time 5 "$BASE/api/ps" 2>/dev/null)"
      read -r CTX SIZE VRAM <<< "$(printf '%s' "$PS" | python3 -c 'import json,sys
n=sys.argv[1]
try:
    ms=[m for m in json.load(sys.stdin).get("models",[]) if m.get("name")==n or m.get("model")==n]
    m=ms[0] if ms else {}
    # "-" statt Leerstring: read verschluckt leere Felder, dann rutschten
    # die Werte eine Spalte nach links.
    print(m.get("context_length","-"), m.get("size","-"), m.get("size_vram","-"))
except Exception: print("- - -")' "$NAME")"
      EXP="$(expected_ctx ollama "$NAME")"
      if [ "$CTX" = "-" ]; then
        hint "context_length nicht in /api/ps (aeltere Ollama-Version?) - nicht pruefbar"
      elif [ -n "$EXP" ] && [ "$CTX" -lt "$EXP" ]; then
        fehlt "Kontextlaenge $CTX < num_ctx $EXP aus opencode.json - Ollama mit OLLAMA_CONTEXT_LENGTH=$EXP neu starten (laeuft womoeglich ein zweiter Server, z.B. App und Terminal?)"
      else
        ok "Kontextlaenge $CTX${EXP:+ (erwartet >= $EXP)}"
      fi
      if [ "$SIZE" = "-" ] || [ "$VRAM" = "-" ] || [ "$SIZE" = "0" ]; then
        hint "GPU-Anteil nicht feststellbar"
      elif [ "$VRAM" != "$SIZE" ]; then
        PCT=$(( VRAM * 100 / SIZE ))
        fehlt "Modell nur zu ${PCT}% auf der GPU (size_vram $VRAM von $SIZE) - Kontext verkleinern; Apple Silicon: sudo sysctl iogpu.wired_limit_mb=<MB>"
      else
        ok "Modell zu 100% auf der GPU ($SIZE Bytes)"
      fi
    fi
    ;;
  lmstudio|openai-compat)
    # OpenAI-kompatible Server (LM Studio, Firmen-Server): nur /v1/models
    # ist verlaesslich vorhanden. Kontext und GPU-Anteil lassen sich dort
    # meist nicht abfragen - das wird ausdruecklich gesagt, statt still als
    # bestanden zu gelten.
    BASE="${OPENAI_COMPAT_BASE_URL:-${OLLAMA_BASE_URL:-}}"; BASE="${BASE%/}"
    AUTH=(); [ -n "${OPENAI_COMPAT_API_KEY:-}" ] && AUTH=(-H "Authorization: Bearer $OPENAI_COMPAT_API_KEY")
    if [ -z "$BASE" ]; then
      fehlt "\$OPENAI_COMPAT_BASE_URL ist leer"
    elif ! LIST="$(curl -fsS --max-time 10 ${AUTH[@]+"${AUTH[@]}"} "$BASE/models" 2>/dev/null)"; then
      fehlt "$BASE/models nicht erreichbar (API-Key in \$OPENAI_COMPAT_API_KEY?)"
    elif ! printf '%s' "$LIST" | grep -q "\"$NAME\""; then
      fehlt "Modell $NAME nicht in $BASE/models"
    else
      ok "Server erreichbar, Modell $NAME gelistet"
      hint "Kontextlaenge und GPU-Anteil an diesem Server nicht pruefbar - auf dem Server selbst kontrollieren"
    fi
    ;;
  *)
    ok "Cloud-Anbieter '$PROVIDER' - kein lokaler Server zu pruefen"
    ;;
esac

exit "$FAIL"
