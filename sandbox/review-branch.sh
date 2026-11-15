#!/usr/bin/env bash
# Prueft einen abgeholten Agent-Branch, bevor du ihn pushst.
#
#   review-branch.sh <branch> [basis]          (Basis-Default: origin/HEAD,
#                                               sonst main, sonst master)
#
# In DEINEM Repo aufrufen, nachdem du den Stand des Agenten geholt hast:
#   git fetch agent                      (Remote von run-sandbox.sh)
#   .../sandbox/review-branch.sh agent/<slug>
#
# Der Agent kann nicht pushen; was er geloescht oder angerichtet hat,
# erreicht das Remote erst mit deinem Push. Dieses Skript sagt, wo du im
# Diff genau hinschauen musst - es ersetzt das Lesen nicht.
#
# Liest nur Git-Objekte (log, diff, cat-file): kein checkout, nichts aus
# dem Branch wird ausgefuehrt, externe Diff-Treiber und textconv sind aus.
#
# Exit 0: keine Warnung - 1: mindestens eine WARNUNG - 2: Aufruffehler.

set -uo pipefail

BR="${1:-}"
[ -n "$BR" ] || { echo "Usage: review-branch.sh <branch> [basis]" >&2; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "kein Git-Repo" >&2; exit 2; }
git rev-parse --verify -q "$BR^{commit}" >/dev/null || { echo "Branch $BR nicht gefunden" >&2; exit 2; }

BASE="${2:-}"
if [ -z "$BASE" ]; then
  for c in origin/HEAD main master; do
    git rev-parse --verify -q "$c^{commit}" >/dev/null && { BASE="$c"; break; }
  done
fi
[ -n "$BASE" ] || { echo "keine Basis gefunden - als zweites Argument angeben" >&2; exit 2; }

G() { git -c core.quotepath=off "$@"; }
D() { G diff --no-ext-diff --no-textconv "$@" "$BASE...$BR"; }

WARN=0
warn() { echo "  WARNUNG  $*"; WARN=$((WARN+1)); }
info() { echo "  hinweis  $*"; }
head_() { echo; echo "== $*"; }

MB="$(git merge-base "$BASE" "$BR" 2>/dev/null)" \
  || { echo "$BR und $BASE haben keinen gemeinsamen Vorfahren" >&2; exit 2; }
echo "Branch $BR gegen $BASE (gemeinsamer Stand $(git rev-parse --short "$MB"))"
D --shortstat | sed 's/^/  /'

# --- Commits ---------------------------------------------------------------
head_ "Commits"
G log --no-merges --format='  %h %<(28,trunc)%an %s' "$BASE..$BR"
MERGES="$(G log --merges --format='%h %s' "$BASE..$BR")"
[ -z "$MERGES" ] || while read -r l; do
  warn "Merge-Commit im Agent-Branch (zieht fremde Staende herein): $l"
done <<< "$MERGES"
# Der Autor ist nur ein Hinweis: der Agent kann jeden Namen eintragen.
OTHER="$(G log --format='%ae' "$BASE..$BR" | sort -u | grep -v -x "${AGENT_EMAIL:-agent@noreply.invalid}")"
[ -z "$OTHER" ] || info "Commits mit anderer Autor-Adresse als ${AGENT_EMAIL:-agent@noreply.invalid}: $(echo $OTHER)"

# --- Geloescht, umbenannt, gekuerzt ----------------------------------------
head_ "Geloeschte, umbenannte und stark gekuerzte Dateien"
TESTPAT='(^|/)(tests?|__tests__)/|[._-](test|spec)\.[a-z]+$|(^|/)test_[^/]+$'
istest() { printf '%s' "$1" | grep -Eq "$TESTPAT" && echo " (Test)"; }
N=0
while IFS=$'\t' read -r st a b; do
  case "$st" in
    D)  warn "geloescht: $a$(istest "$a")"; N=1 ;;
    R*) info "umbenannt (${st#R}% gleich): $a -> $b"; N=1 ;;
  esac
done < <(D -M --name-status)
# numstat: hinzugefuegte und entfernte Zeilen je Datei; Binaerdateien "-".
while IFS=$'\t' read -r add del p; do
  [ "$add" = "-" ] && continue
  case "$p" in *" => "*|*"{"*) continue ;; esac   # Umbenennungen oben
  if git cat-file -e "$BR:$p" 2>/dev/null && [ "$(git cat-file -s "$BR:$p")" = 0 ]; then
    warn "geleert: $p$(istest "$p")"; N=1
  elif [ "$del" -ge 20 ] && [ "$del" -gt $((add * 2)) ]; then
    warn "stark gekuerzt (+$add -$del): $p$(istest "$p")"; N=1
  fi
done < <(D -M --numstat --diff-filter=M)
[ "$N" = 1 ] || echo "  keine"

# --- Dateien, die etwas ausfuehren oder den Agenten steuern ----------------
head_ "Dateien, die beim Build/CI/Installieren laufen oder den Agenten steuern"
EXEC='^\.github/|^\.gitlab-ci|^\.circleci/|Jenkinsfile|azure-pipelines|(^|/)\.(husky|githooks)/|\.pre-commit-config|(^|/)\.git(attributes|modules)$|(^|/)(Makefile|Dockerfile|docker-compose[^/]*|justfile|Taskfile[^/]*)$|\.(sh|bash|zsh|ps1|bat|cmd)$|(^|/)(package\.json|pyproject\.toml|setup\.py|setup\.cfg|requirements[^/]*\.txt|go\.mod|Cargo\.toml|Gemfile|pom\.xml|build\.gradle[^/]*)$|(^|/)\.(envrc|env)$|(^|/)\.vscode/|(^|/)\.idea/'
# .agent/<datei>.sh|py trifft auch .agent/pruefungen.sh: sie legt fest, was als
# gruen gilt - eine Aenderung daran schwaecht womoeglich die Pruefung.
STEER='^(AGENTS|CLAUDE)\.md$|(^|/)\.claude/|(^|/)\.opencode/|^opencode\.json$|^\.agent/agents/|^\.agent/[^/]+\.(sh|py)$'
N=0
while read -r p; do
  if printf '%s' "$p" | grep -Eq "$STEER"; then
    warn "steuert den Agenten (Regeln, Rechte, Werkzeuge): $p"; N=1
  elif printf '%s' "$p" | grep -Eq "$EXEC"; then
    warn "wird ausgefuehrt bzw. installiert: $p"; N=1
  fi
done < <(D --name-only --diff-filter=d)
[ "$N" = 1 ] || echo "  keine"

# --- Rechte, Symlinks, Submodule, Binaerdateien ----------------------------
head_ "Ausfuehrbar-Bit, Symlinks, Submodule, Binaer- und grosse Dateien"
N=0
while read -r l; do
  case "$l" in
    *"mode change"*"=> 100755"*) warn "neu ausfuehrbar: ${l##* }"; N=1 ;;
    *"create mode 100755"*)      info "neue ausfuehrbare Datei: ${l##* }"; N=1 ;;
    *"mode 120000"*)             p="${l##* }"
                                 warn "Symlink: $p -> $(git cat-file -p "$BR:$p" 2>/dev/null)"; N=1 ;;
    *"mode 160000"*)             warn "Submodul: ${l##* }"; N=1 ;;
  esac
done < <(D --summary --no-renames)
while IFS=$'\t' read -r add del p; do
  [ "$add" = "-" ] && { warn "Binaerdatei geaendert/neu: $p"; N=1; continue; }
  s="$(git cat-file -s "$BR:$p" 2>/dev/null || echo 0)"
  [ "$s" -gt 1048576 ] && { warn "gross ($((s / 1024)) KB): $p"; N=1; }
done < <(D --numstat --no-renames --diff-filter=d)
[ "$N" = 1 ] || echo "  keine"

# --- Verdaechtige Inhalte in hinzugefuegten Zeilen -------------------------
# Ausgegeben werden Datei und Art des Treffers, nie die Zeile selbst - ein
# echter Schluessel soll nicht zusaetzlich im Terminal-Verlauf landen.
head_ "Geheimnisse und gefaehrliche Befehle in neuen Zeilen"
# Je neue Zeile "datei<TAB>inhalt"; die Muster prueft grep -E, weil nicht
# jedes awk Wiederholungen wie {16} kennt (mawk, Debian/Ubuntu-Default).
# Eintrag: Gross/klein egal (i) oder nicht (-) | Name | Muster. Ohne die
# Wortgrenze vor "sk-" schluege jeder lange Task-Name ("task-0001-...") an.
ADDED="$(D -U0 --no-color --no-renames | awk '
  /^\+\+\+ b\// { f = substr($0, 7); next }
  /^\+/ { print f "\t " substr($0, 2) }')"   # Leerzeichen: Wortgrenze auch am Zeilenanfang
PATTERNS=(
  "-|privater Schluessel|-----BEGIN [A-Z ]*PRIVATE KEY-----"
  "-|AWS-Zugangsschluessel|AKIA[0-9A-Z]{16}"
  "-|GitHub-Token|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{20,}"
  "-|API-Schluessel (sk-...)|[^A-Za-z0-9]sk-[A-Za-z0-9_-]{20,}"
  "-|Slack-Token|xox[abprs]-[A-Za-z0-9-]{10,}"
  "i|Zugangsdaten-Zuweisung|(password|passwd|secret|token|api[_-]?key)[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"' ]{8,}"
  "i|Download direkt in die Shell|(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh"
  "-|rm -r auf / oder Home|rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*[[:space:]]+(/|~|\\\$HOME)([[:space:];]|$)"
  "-|Git-Push oder -Hooks|git[[:space:]]+push|\.git/hooks|core\.(fsmonitor|hooksPath|sshCommand)"
)
HITS=""
if [ -n "$ADDED" ]; then
  for e in "${PATTERNS[@]}"; do
    flag="${e%%|*}"; e="${e#*|}"; name="${e%%|*}"; re="${e#*|}"
    CI=(); [ "$flag" = i ] && CI=(-i)
    HITS+="$(printf '%s\n' "$ADDED" | grep -E ${CI[@]+"${CI[@]}"} -- "^[^	]*	.*($re)" | cut -f1 | sort | uniq -c \
      | awk -v t="$name" '{ c = $1; sub(/^ *[0-9]+ /, ""); printf "%s: %s (%d Zeile%s)\n", $0, t, c, (c > 1 ? "n" : "") }')"$'\n'
  done
fi
HITS="$(printf '%s' "$HITS" | sed '/^$/d' | sort)"
if [ -n "$HITS" ]; then
  while read -r l; do warn "$l"; done <<< "$HITS"
else
  echo "  keine"
fi

# --- Ergebnis --------------------------------------------------------------
echo
if [ "$WARN" = 0 ]; then
  echo "Keine Warnung. Den Diff trotzdem lesen: git diff $BASE...$BR"
  exit 0
fi
echo "$WARN Warnung(en). Ansehen mit: git diff $BASE...$BR -- <datei>"
echo "Ist etwas nicht gewollt: nicht pushen, dem Agenten als Auftrag zurueckgeben"
echo "oder den Commit in deiner Kopie mit 'git revert' rueckgaengig machen."
exit 1
