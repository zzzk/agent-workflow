#!/usr/bin/env bash
# Push-Nachricht aufs Handy, wenn der Agent auf dich wartet.
#
# Ausgeloest von den Claude-Code-Hooks "Notification" (Agent braucht eine
# Eingabe/Freigabe) und "Stop" (Agent ist fertig mit seiner Antwort - im
# Orchestrator-Betrieb heisst das: Rueckfrage, BLOCKED, HALTED oder Ende).
# Siehe .claude/settings.json.
#
# Nur aktiv, wenn NTFY_TOPIC gesetzt ist - sonst tut das Skript nichts.
# Einrichtung (USERMANUAL.md, "Unbeaufsichtigte Laeufe"):
#   1. ntfy-App aufs Handy, einen zufaelligen Topic-Namen abonnieren, z.B.
#      agent-$(openssl rand -hex 8)  - der Name ist das einzige Geheimnis.
#   2. Vor dem Start: export NTFY_TOPIC=<name>  (in der Sandbox: im Container)
#
# Verschickt wird bewusst KEIN Inhalt (kein Auftrag, kein Code, keine
# Rueckfrage) - nur Projektname und Ereignis. ntfy.sh ist ein oeffentlicher
# Dienst; wer den Topic-Namen kennt, liest mit.
[ -n "${NTFY_TOPIC:-}" ] || exit 0
EVENT="${1:-Ereignis}"
PROJECT="$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")"
curl -fsS --max-time 5 \
  -H "Title: Agent wartet ($PROJECT)" \
  -d "$EVENT – bitte nachsehen" \
  "${NTFY_SERVER:-https://ntfy.sh}/$NTFY_TOPIC" >/dev/null 2>&1 || true
exit 0
