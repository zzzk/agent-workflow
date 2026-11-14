# Nächste Schritte (temporär, Stand 2026-11-13)

Arbeitsliste zum Abhaken. Wenn alles erledigt ist: Datei löschen.

## A. Auf dem Host, in deiner Arbeitskopie

- [ ] **A1 Bericht verschieben**
  ```bash
  mv 2026-09-30-bericht-teil-a-workflow.md input/
  ```
- [ ] **A2 Prüfen, was committet wird**
  ```bash
  git status
  git diff --stat
  ```
  Erwartet:
  - geändert: `AGENT_WORKFLOW.md`, `DECISIONS.md`, `README.md`,
    `TODO.md`, `USERMANUAL.md`, `sandbox/README.md`,
    `sandbox/SANDBOX_BOOTSTRAP_PATTERN.md`, `sandbox/run-sandbox.sh`,
    `project-template/.agent/agents/orchestrator.md`,
    `project-template/.agent/state/MEMORY.md`,
    `project-template/.opencode/agent/orchestrator.md`
  - neu: `sandbox/agent-remote.sh`, `sandbox/review-branch.sh`,
    `input/AGENT_WORKFLOW_NEU.md`,
    `input/2026-11-02-git-workflow-uebergabe.md`,
    `input/2026-09-30-bericht-teil-a-workflow.md`,
    `input/NAECHSTE_SCHRITTE.md` (diese Datei)
- [ ] **A3 Committen und pushen**
  ```bash
  git add -A
  git commit -m "sandbox: Klon des Agenten im Volume statt geteiltem Ordner; review-branch.sh; Material fuer neues AGENT_WORKFLOW"
  git push
  ```
- [ ] **A4 Image neu bauen** (falls seit dem letzten Build etwas am
  Dockerfile geändert wurde; schadet sonst auch nicht)
  ```bash
  cd sandbox && docker build -t agent-sandbox:latest . && cd ..
  ```
- [ ] **A5 Neue Sandbox starten** – der alte Container bleibt stehen
  ```bash
  ./sandbox/run-sandbox.sh --new .
  ```
  Erwartet: Meldung "Volume 'agent-<projekt>-1-work': schiebe Branch
  'hardened_multi_model' hinein", danach eine Shell im Container. In
  deinem Repo gibt es jetzt das Remote `agent-1`
  (`git remote -v` zeigt es).

## B. Im neuen Container

- [ ] **B1 Selbstcheck** (`sandbox/README.md`, Schritte 3–5), insbesondere:
  ```bash
  git -C /work log --oneline -1     # neuster Commit aus A3
  git -C /work remote -v            # muss leer sein
  touch /work/.git/.p && rm /work/.git/.p && echo "git: beschreibbar"
  ls ~/.ssh 2>&1                    # muss fehlschlagen
  ```
- [ ] **B2 bypassPermissions setzen** (`sandbox/README.md`, Schritt 4),
  dann `claude` starten und anmelden.
- [ ] **B3 Einstieg für Claude:** "lies input/NAECHSTE_SCHRITTE.md und
  input/AGENT_WORKFLOW_NEU.md"

## C. Test mit echtem Docker (TODO 8)

Zusammen mit Claude; die Host-Befehle machst du.

- [x] **C1** Claude committet im Container etwas Kleines auf einem
  Branch `agent/test`.
- [x] **C2** Host: `git fetch agent-1` → `agent-1/test` erscheint, keine
  Docker-Meldungen im Git-Protokoll.
- [x] **C3** Host: `sandbox/review-branch.sh agent-1/test` läuft.
- [x] **C4** Host: `git push agent-1 HEAD:nutzer/inbox` → im Container
  sichtbar mit `git branch --list 'nutzer/*'`.
- [x] **C5** VS Code: Fetch-Knopf holt ebenfalls von `agent-1`. (weggelassen, Kommandozeile genügt)
- [x] **C6** Container verlassen (`exit`), dann Host: `git fetch agent-1`
  geht trotzdem (Sandbox gestoppt).
- [x] **C7** Ergebnis in TODO.md Nr. 8 eintragen, Test-Branches
  aufräumen.

## D. Neufassung AGENT_WORKFLOW

- [ ] **D1** Zwei offene Fragen entscheiden (`input/AGENT_WORKFLOW_NEU.md`,
  "Offene Fragen an den Nutzer"): eine Datei oder zwei? Was passiert
  danach mit dem Bericht?
- [ ] **D2** Claude schreibt die Neufassung auf `agent/<slug>` und
  committet.
- [ ] **D3** Host: `git fetch agent-1`, `review-branch.sh`, lesen, pushen
  (`git push origin agent-1/<slug>:refs/heads/agent/<slug>`), PR.

## E. Projekt wiki-assistent

- [ ] **E1 Sofort, bis zum Umstieg:** vor dem Öffnen in VS Code im
  Projektordner prüfen, ohne Git:
  ```bash
  find .git/hooks -type f ! -name '*.sample'
  cat .git/config
  ls .git/commondir .git/modules 2>/dev/null
  find . -mindepth 2 -name .git -not -path './.git/*'
  ```
  Alles ausser `cat` muss leer sein; in der Config kein `core.*`,
  `alias`, `filter`, `include` ausser den Standardzeilen.
- [ ] **E2 Umstieg:** dortigen Stand committen, alten Container
  entfernen (`docker rm agent-<name>`), `run-sandbox.sh <ordner>` ohne
  Option. Die Abweichung "kein eigener Klon" in dessen
  `.agent/state/MEMORY.md` streichen.
- [ ] **E3** Framework-Stand (Rollen-Dateien, Sandbox) dort übernehmen.

## F. Später, an einem echten Lauf

- [ ] **F1** TODO.md Nr. 6: Prüfung auf abgelehnte Berechtigungen sucht
  im ganzen Log.
- [ ] **F2** TODO.md Nr. 7: Lesesperre für fremde Task-Dateien.

## G. Aufräumen am Schluss

- [ ] Alten Container entfernen, wenn nicht mehr gebraucht:
  `docker rm agent-<projekt>` (das ist die bisherige Session).
- [ ] Diese Datei löschen; `input/` aufräumen (was ist verarbeitet?).
