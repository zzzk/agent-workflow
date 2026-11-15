#!/usr/bin/env bash
# Projekt-Pruefbefehle: was jeder Task ausser der Testsuite bestehen muss
# (Lint, Format, Typpruefung, Build, Paritaetschecks wie "jede Meldung in
# allen Sprachen vorhanden").
#
# Der Tester fuehrt die Datei in VERIFIKATION und GRUEN_PROBE nach der
# Testsuite aus, der Reviewer im REVIEW. Exit != 0 heisst: nicht gruen -
# genau wie ein roter Test.
#
# Was hier steht, entscheidet der Nutzer: der Architekt schlaegt es in
# ZIELARCHITEKTUR vor und traegt es nach dem Entscheid ein (Regel in
# ziel.md, Abschnitt 3). Implementer und Tester aendern die Datei nie.
#
# Nur Kommentare = keine zusaetzlichen Pruefungen.

set -euo pipefail
cd "$(dirname "$0")/.."

# Beispiele (je Zeile ein Befehl; der erste, der scheitert, beendet die Datei):
# ruff check .
# npx prettier --check src/
# ./scripts/check-string-parity.sh
