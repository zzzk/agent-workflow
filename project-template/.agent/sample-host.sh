#!/usr/bin/env bash
# Ressourcen-Zeitreihe des Modell-Servers - laeuft auf dem HOST, nicht in
# der Sandbox.
#
#   .agent/sample-host.sh [intervall-sekunden] > .agent/runs/host.csv
#
# Warum getrennt von run-role.sh: Im Mischbetrieb liegt die Last dort, wo
# das Modell laeuft - auf dem Host bei Ollama (wegen der Grafikkarte). Der
# opencode-Prozess in der Sandbox ist ein duenner HTTP-Client; seine CPU-
# und RAM-Zahlen beantworten die Beschaffungsfrage NICHT. Aus dem Container
# heraus ist der Host-Prozess aber nicht sichtbar. Deshalb zwei Quellen:
#
#   run-role.sh      Ereignisse (ein Datensatz je Lauf, mit Zeitstempel)
#   sample-host.sh   Zeitreihe (Auslastung, fortlaufend)
#
# Zusammengefuehrt wird ueber die Zeit - .agent/metrics-report.py macht das.
# Vor dem Lauf starten, waehrend der ganzen Sitzung laufen lassen, danach
# mit Ctrl-C beenden.
#
# ACHTUNG beim Anpassen des Prozess-Filters: Ollama besteht aus MEHREREN
# Prozessen. Der Server ("ollama") ist duenn - ~15 MB. Die eigentliche
# Inferenz laeuft in einem separaten Runner, der je nach Installation
# "llama-server", "ollama runner" oder "ollama_llama_server" heisst und das
# Modell haelt (gemessen: 19.7 GB). Wer nur auf "ollama" filtert, misst den
# falschen Prozess und bekommt plausible, aber voellig unbrauchbare Zahlen -
# genau so geschehen in der ersten Fassung dieses Skripts.

set -uo pipefail
INTERVAL="${1:-5}"
OLLAMA_URL="${OLLAMA_SAMPLE_URL:-http://127.0.0.1:11434}"

# Python bewusst in einer eigenen Datei statt inline: verschachtelte
# Anfuehrungszeichen in einem "python3 -c" innerhalb eines Shell-Skripts
# haben in der ersten Fassung einen SyntaxError erzeugt, der von try/except
# NICHT gefangen wird (er entsteht beim Kompilieren) - das Skript lieferte
# still 0 statt zu scheitern.
PARSER="$(mktemp)"
trap 'rm -f "$PARSER"' EXIT
cat > "$PARSER" <<'PY'
import sys, json
try:
    models = json.load(sys.stdin).get("models", [])
    vram = sum(m.get("size_vram", 0) for m in models) / 1048576
    print("%d,%.0f" % (len(models), vram))
except Exception:
    print("0,0")
PY

echo "ts,ollama_cpu_pct,ollama_rss_mb,loaded_models,vram_mb"
while true; do
  TS="$(date -u +%FT%TZ)"
  read -r CPU RSS <<< "$(ps -Ao pcpu,rss,comm \
    | awk 'tolower($3) ~ /ollama|llama-server|llama_server/ {c+=$1; r+=$2}
           END {printf "%.1f %.0f", c, r/1024}')"
  STATS="$(curl -fsS --max-time 3 "$OLLAMA_URL/api/ps" 2>/dev/null \
    | python3 "$PARSER" 2>/dev/null || echo "0,0")"
  echo "$TS,${CPU:-0},${RSS:-0},$STATS"
  sleep "$INTERVAL"
done
