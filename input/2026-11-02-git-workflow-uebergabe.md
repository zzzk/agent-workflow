# Git-Workflow mit Agent-Sandbox – Übergabe an den Framework-Agenten

> Entstanden am 2026-11-02 in der Orchestrator-Session des Projekts
> `wiki-assistent` (Auftrag `wiki-assistent-mvp`), auf Wunsch des Nutzers.
> Zweck: Ausgangslage für die Diskussion mit dem Framework-Agenten
> (`tools/agent-workflow/`). Das Ergebnis dort wird später in dieses
> Projekt zurückgespielt (`.agent/state/MEMORY.md`, Rollen-Dateien,
> Sandbox-Start). Nichts hier ist entschieden – es ist Material.

## 1. Anforderungen des Nutzers (sinngemäss, Reihenfolge wie genannt)

1. **Sicherheit**: Der Agent darf das Remote-Repository nicht zerstören
   können – höchstens sein lokales.
2. **Diffs sehen in VS Code** – nicht immer, nur bei Bedarf, z.B. in der
   Klärungsphase (Requirements-Änderungen nachvollziehen).
3. **Der Agent committet möglichst viel**; Pushen bleibt beim Menschen
   (Klarheit im Prozess, und dort sitzt die Sicherheit). Erwogen, falls
   es den Workflow vereinfacht: nur manuell committen.
4. **Zweite Priorität**: auf Remote-Hosts evtl. doch vom Agenten pushen
   lassen.
5. **Einfach für Menschen**: Die Regel "zweiter lokaler Checkout nur für
   den Agenten" ist bei der Übergabe des Frameworks an andere Menschen
   schon eine Komplexität, die man lieber vermeidet.

Wörtlich zum Diff-Bedürfnis: "wenn nicht committed wird, dann kann ich
dies anschauen und am schluss den commit-befehl geben. es hängt aber auch
mit dem workflow mit dem menschen zusammen. aktuell ist empfohlen, wegen
git-hooks, dass der mensch nicht im agent-ordner git-befehle ausführt.
wenn ich das dann tun würde, beispielsweise zwei commits vergleichen, dann
passiert ja dann genau das."

## 2. Ist-Zustand in diesem Projekt

- Standardmuster laut Framework: eigener Klon nur für den Agenten,
  Sandbox mit `--git-rw`, Agent committet auf `agent/<slug>`, pusht nie;
  der Nutzer holt per `git fetch` in seine eigene Kopie und pusht von dort.
- **Abweichung hier** (`.agent/state/MEMORY.md`, "Abweichungen",
  Entscheid 2026-11-01): kein eigener Klon, `--git-rw` direkt auf dem
  Werkzeug-Ordner. Begründung: Kundendaten liegen ausserhalb; im Ordner
  nur Test-/anonymisiertes Material. Wiederherstellung über das Remote.
  Regeln: Nutzer-Material nur unter `.agent/inbox/`; während eines
  Bausteins kein Branchwechsel und keine Dateiänderung durch den Nutzer.
- Orchestrator-Regel (`orchestrator.md`, Schritt 8, letzter Absatz): nach
  **jedem** Baustein mit Dateiänderungen committen (auch `KLAERUNG`,
  `SPEC_REVIEW` usw.), nicht nur nach Tasks – jeder Commit ist ein
  Wiederherstellungspunkt. Das war dem Nutzer nicht präsent; er hatte
  "commit nur nach Tasks" erwartet und sah die Änderungen deshalb nicht
  mehr als uncommitteten Diff.
- Beobachtet in dieser Session: Im Container war **keine Git-Identität**
  gesetzt (`Author identity unknown`). Gelöst mit repo-lokalem
  `git config user.name/user.email` – das schreibt in `.git/config`
  (relevant für Abschnitt 4: bei read-only `config` geht das nicht mehr).

## 3. Der Widerspruch

- Die Sandbox schreibt mit `--git-rw` in genau den Ordner, in dem der
  Mensch arbeitet.
- Empfehlung des Frameworks: Der Mensch führt dort keine Git-Befehle aus
  (Hooks-/Config-Risiko).
- Praktisch nicht einhaltbar:
  - **Pushen** macht nur der Mensch – ohne eigenen Klon geht das nur aus
    diesem Ordner.
  - **VS Code** ruft beim Öffnen des Ordners selbst laufend Git auf
    (`git status`, `git log`, `git diff` …), auch ohne Klick. Diffs
    anschauen ist damit nicht harmloser als committen.
- Der Grund für die Regel: Der Agent kann `.git/hooks/*` oder Einträge in
  `.git/config` anlegen, die beim nächsten Git-Aufruf **auf dem Host**,
  ausserhalb der Sandbox, Code ausführen. Beispiel: `core.fsmonitor`
  startet bei jedem `git status` ein Programm.

## 4. Vorschlag aus der Session: ein Ordner, Gefahrenstellen gesperrt

Ziel: Anforderung 5 (kein zweiter Checkout) erfüllen, ohne Anforderung 1
aufzugeben.

### 4.1 Sandbox-Mounts

- Werkzeug-Ordner wie heute beschreibbar, `.git` beschreibbar (Agent
  committet).
- **Zusätzlich** gezielt überlagern (Docker erlaubt Mounts auf Unterpfade
  eines bereits gemounteten Verzeichnisses):
  - `.git/hooks/` → **leeres Verzeichnis, read-only** gemountet.
    **Idee des Nutzers**: Die Sandbox braucht nichts aus `hooks/`; ein
    leeres Verzeichnis ist einfacher und klarer als ein read-only Mount
    des echten Inhalts. Folge: Im Container laufen keine Hooks (auch
    keine, die der Nutzer auf dem Host absichtlich hat); auf dem Host
    sieht der Nutzer seine echten Hooks, der Agent kann dort nichts
    hineinschreiben.
  - `.git/config` → **read-only**.
  - `.vscode/` → read-only (oder ebenfalls leer überlagert), siehe 4.3.
- Folge für die Git-Identität: nicht mehr per `git config` im Repo,
  sondern per Umgebungsvariablen im Image/Startskript
  (`GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`,
  `GIT_COMMITTER_EMAIL`) oder über eine `~/.gitconfig` im Container.
- Zu prüfen: Welche Git-Befehle, die der Agent braucht, schreiben in
  `.git/config` und scheitern dann? Kandidaten: `git branch
  --set-upstream-to`, `git remote add`, `git config` selbst, `git
  switch -c --track`, `git worktree add`, `git submodule init`. `git
  switch -c <branch>` und `git commit` schreiben nicht in `config`.
- Zu prüfen: Lässt Docker Desktop auf dem Mac einen Datei-Bind-Mount
  (`.git/config`) über einen Verzeichnis-Bind-Mount zuverlässig zu?
  Git ersetzt Dateien teils per "neu schreiben + umbenennen" (Lockfile
  `config.lock`) – bei einer read-only gemounteten Einzeldatei scheitert
  das wie gewünscht, aber die Fehlermeldung sollte verständlich sein.

### 4.2 Weitere Wege, über `.git` oder das Arbeitsverzeichnis Code auf dem Host auszuführen

Vollständigkeit vor der Festlegung prüfen – das ist die eigentliche
Sicherheitsarbeit. Gesammelt in der Session, ohne Anspruch auf
Vollständigkeit:

- **`.git/config`** (durch read-only Mount abgedeckt): `core.fsmonitor`,
  `core.hooksPath`, `core.sshCommand`, `core.pager`, `core.editor`,
  `core.askPass`, `diff.external`, `diff.<treiber>.textconv`,
  `filter.<treiber>.clean/smudge/process`, `merge.<treiber>.driver`,
  `gpg.program`, `credential.helper`, `alias.*` (mit `!`),
  `include.path`/`includeIf` (zieht weitere Dateien nach – auch aus dem
  beschreibbaren Arbeitsbaum!), `core.worktree`, `remote.<name>.url`
  mit `ext::`-Protokoll, `uploadpack.*`/`receive.*`.
- **`.git/hooks/`** (durch leeres Verzeichnis abgedeckt).
- **`.git/modules/`**: Submodule haben eigene `config` und `hooks` –
  falls Submodule je vorkommen, gleich behandeln oder ausschliessen.
- **`.git/info/attributes`** und **`.gitattributes`** im Arbeitsbaum:
  aktivieren Filter-/Diff-Treiber per Name. Ohne passende Definition in
  einer Config wirkungslos – **aber** Treiber aus der **globalen**
  Host-Config (z.B. Git LFS) greifen. Bewerten.
- **`.gitmodules`** im Arbeitsbaum: URLs mit gefährlichen Protokollen,
  relevant bei `git submodule update` auf dem Host.
- **Host-seitige Werkzeuge, die Dateien aus dem Arbeitsbaum ausführen**:
  - `pre-commit` (`.pre-commit-config.yaml`), falls der Nutzer es
    global/über `core.hooksPath` aktiv hat → Agent bestimmt, was beim
    Commit des Nutzers läuft.
  - `direnv` (`.envrc`), falls auf dem Host aktiv.
  - Paketmanager-Skripte (`package.json` scripts, `Makefile`), falls der
    Nutzer sie auf dem Host startet.
  - `.devcontainer/`.
- **`.vscode/`**: `tasks.json` (inkl. `"runOn": "folderOpen"`),
  `settings.json`, `launch.json`, `extensions.json` (Empfehlungen).
  VS Code führt Tasks und viele Einstellungen nur in einem
  **vertrauenswürdigen Workspace** (Workspace Trust) aus. Zu prüfen:
  welche Workspace-Einstellungen trotzdem wirken, und ob einzelne
  Einstellungen (z.B. Pfade zu Werkzeugen) workspace-seitig gesetzt
  werden können. Optionen: `.vscode/` in der Sandbox read-only bzw. leer
  überlagern, oder den Ordner auf dem Host bewusst **nicht** als
  vertrauenswürdig markieren (kostet Komfort).

### 4.3 Remote-Schutz – die eigentliche Garantie für Anforderung 1

- Im Container gibt es **keine Zugangsdaten** → Agent kann nicht pushen
  (heute schon so).
- **Serverseitig** `main` schützen: kein Force-Push, kein Löschen,
  Änderungen nur per Merge/PR (je nach Host: Branch Protection bzw.
  Rulesets). Dann zerstört auch ein Push des Menschen, der kaputte lokale
  Historie enthält, das Remote nicht.
- Der Mensch pusht `agent/<slug>`-Branches; gemergt wird über das Remote.
- Offen: welcher Git-Host (GitHub, GitLab, Bitbucket, …) – davon hängt
  ab, wie genau der Schutz eingerichtet wird.

### 4.4 Commits und Diffs (Anforderungen 2 und 3)

- Empfehlung aus der Session: **Agent committet weiter nach jedem
  Baustein** (Wiederherstellungspunkte bleiben). Diffs in VS Code trotz
  Commits:
  - Source-Control-Graph (seit VS Code 1.93 eingebaut): Commit anklicken
    → Änderungen je Datei.
  - Timeline-Ansicht einer Datei: Änderungen über die Commits.
  - Ganzer Auftrag: "Compare with Branch… → main" bzw.
    `git diff main..agent/<slug>`.
- Voraussetzung: Git-Aufrufe des Menschen/VS Code im Ordner sind sicher
  (Abschnitt 4.1/4.2). Ohne das bleibt jede Diff-Ansicht im Ordner ein
  Risiko – committet oder nicht.
- Alternative "nur manuell committen" bzw. "Agent lässt uncommittet
  liegen, Mensch gibt Commit-Befehl": in der Session **nicht**
  empfohlen – kostet Wiederherstellungspunkte und die Freeze-Grenze der
  Tests (`TEST_FIRST`-Commit), bringt bei sicherer Diff-Ansicht keinen
  Vorteil. Mögliche Zwischenform zur Diskussion: ein optionaler
  "Prüfpunkt"-Modus nur für Klärungsbausteine, in dem der Orchestrator
  vor dem Commit auf ein Okay wartet.
- Nebenbei vom Nutzer gewünscht (bereits als Arbeitsweise übernommen):
  Rückfragen, Annahmen und Zwischenstände stehen immer in Dateien im
  Repo (z.B. `AUFTRAG.md`), nicht nur in der Konsole.

### 4.5 Agent pusht selbst (Anforderung 4, zweite Priorität)

- Denkbar mit einem Schlüssel/Token, der nur auf `agent/*`-Branches
  schreiben darf; die Einschränkung muss **serverseitig** greifen
  (Rulesets/Branch-Regeln), nicht im Agenten.
- Zu prüfen je Host: Deploy-Keys sind meist repo-weit (nicht
  branch-genau); Branch-Beschränkung kommt dann aus den Regeln für
  `main`. Zugangsdaten im Container widersprechen der heutigen Regel
  "keine Zugangsdaten, suchst du auch nicht" – bewusst neu entscheiden.

## 5. Alternative zum Vergleich: getrennter Klon (heutiger Standard)

- Agent arbeitet in eigenem Klon; der Mensch holt per
  `git fetch <pfad-zum-agenten-klon> agent/<slug>` in seine Kopie und
  schaut dort Diffs an bzw. pusht.
- Vorteil: Hooks/Config des Agenten-Klons laufen beim Fetch nicht
  (zu verifizieren: lokales Fetch startet `git-upload-pack` im
  Quell-Repo; sicherheitsrelevante Einstellungen wie
  `uploadpack.packObjectsHook` werden aus Repo-Config ignoriert – mit
  aktueller Git-Version bestätigen). Nichts aus dem Agenten-Arbeitsbaum
  wird im Menschen-Ordner ausgeführt, solange nur gefetcht wird.
- Nachteil: zweiter Checkout, zusätzlicher Fetch-Schritt – genau die
  Komplexität aus Anforderung 5.

## 6. Offene Fragen für den Framework-Agenten

1. Ist "ein Ordner, `.git/hooks` leer + `.git/config` read-only +
   `.vscode` gesperrt" vollständig genug, oder bleiben Wege aus 4.2
   offen, die einen getrennten Klon doch nötig machen?
2. Wie wird die Git-Identität im Container gesetzt, wenn `config`
   read-only ist (Image, Startskript, Umgebungsvariablen)?
3. Welche Rollen-/Orchestrator-Regeln ändern sich (z.B. "Mensch macht im
   Agent-Ordner kein Git" streichen; MEMORY-Abweichung "kein eigener
   Klon" wird zum Standard)?
4. Selbstcheck in der Sandbox (analog zur Schreibprobe auf `.git`): z.B.
   `touch .git/hooks/x` und `git config --local foo.bar 1` müssen
   scheitern, `git commit` muss gehen.
5. Branch-Schutz je Git-Host dokumentieren (Host des Nutzers noch offen).
6. Optionaler "Prüfpunkt"-Modus vor Commits in Klärungsbausteinen – ja
   oder nein?
