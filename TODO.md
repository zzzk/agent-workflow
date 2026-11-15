# Offene Punkte an der Methodik

Gefundene Schwächen, die noch nicht in `AGENT_WORKFLOW.md`,
`project-template/` oder den Rollen-Dateien behoben sind. Anders als
`DECISIONS.md` (das begründet, warum etwas **so ist**) sammelt diese Datei,
was noch **anders werden sollte**.

Format je Eintrag: was, wo, warum es stört, mögliche Lösung, wann/wo
aufgefallen.

---

## 1. Test-Freeze-Prüfung ist auf `tests/` fest verdrahtet

**Wo**
- `project-template/.agent/agents/orchestrator.md` (Abschnitt
  "Task-Schleife", Schritt 5)
- `project-template/.agent/agents/implementer.md` (Abschnitt
  "Testdateien sind eingefroren")

Beide nennen den Prüfbefehl wörtlich:

```bash
git diff <freeze-commit> --name-only -- tests/
git status --porcelain -- tests/
```

**Warum das stört**

Die eigentliche Quelle für die Testablage sind `implementer.meta.yml`
(`path_denies`) und `tester.meta.yml` (`path_allows`) – genau dafür sind
die Felder da, und `sync-agents.py` interpoliert sie auch korrekt in den
generierten Schreibverbot-Block im Header der Adapter-Dateien. Der
**Fliesstext der Rollen-Dateien** wird dagegen unverändert durchgereicht.
Dadurch gibt es zwei Wahrheiten, die auseinanderlaufen, sobald ein Projekt
seine Tests nicht unter `tests/` ablegt.

Konkrete Folge: der Test-Freeze ist laut `AGENT_WORKFLOW.md` die einzige
**mechanisch** geprüfte harte Regel – der Rest ist Instruktion. Genau
diese eine mechanische Prüfung greift dann ins Leere und meldet
stillschweigend "kein Verstoss", obwohl der Implementer Tests geändert
haben kann. Eine Prüfung, die immer leer ausgeht, ist schlimmer als keine,
weil der Orchestrator sie als bestanden verbucht.

**Betroffen sind alle Projekte, die Tests nicht unter `tests/` ablegen**,
also u.a.:
- TypeScript/JS mit Tests neben dem Code (`**/*.test.ts`, `__tests__/`)
- Go (`**/*_test.go` liegt immer neben dem Produktcode)
- Java/Kotlin (`src/test/java/**`)

**Mögliche Lösung**

Die Muster aus der jeweiligen `.meta.yml` auch in die Prosa interpolieren,
statt sie dort zu wiederholen. Z.B. in `sync-agents.py` einen Platzhalter
im Body ersetzen:

```
git diff <freeze-commit> --name-only -- {{TEST_PATHS}}
```

→ ersetzt durch die `path_denies` des Implementers, als `git`-Pathspecs
(`-- '**/*.test.ts' 'tests/**'`; Glob-Muster in Anführungszeichen, damit
die Shell sie nicht vorher auflöst, und ggf. `:(glob)`-Magic, da `git`
Pathspecs `**` nur mit `:(glob)` wie erwartet behandelt).

Alternative, falls die Interpolation zu viel Mechanik ist: in beiden
Rollen-Dateien den Befehl durch einen Verweis ersetzen ("die Muster aus
`implementer.meta.yml` → `path_denies` als Pathspec einsetzen") – dann ist
wenigstens nur noch eine Quelle normativ, auch wenn die Ausführung beim
Agenten liegt.

**Aufgefallen**

12.09.2026 beim Anlegen des Projekts `pwd-transform` (Browser-Extension,
TypeScript) aus `project-template/`. Dort wurden `path_denies`/
`path_allows` auf `**/*.test.ts`, `src/**/__tests__/**`, `e2e/**` usw.
gesetzt – der hart verdrahtete `-- tests/`-Befehl in der Prosa hätte davon
nichts erfasst.


aus dem weiterentwickeln vom projekt pwd-hash:

# Verbesserungsnotizen für `tools/agent-workflow`

> Nicht Teil der Produkt-Spezifikation dieses Repos – eine Notiz für den
> Nutzer, um sie später manuell ins externe Framework
> (`tools/agent-workflow/AGENT_WORKFLOW.md` und die Rollen-Quellen unter
> `.agent/agents/*.meta.yml`) einfliessen zu lassen. Entstanden während
> der Initiative "Extension erstmals bauen" (Auftrag vom 2026-09-22).

## 1. Ziel-/Ausgabesprache: sollte früh und explizit geklärt werden

**Beobachtung**: In diesem Projekt lief die gesamte Klärung, Spezifikation
und Planung auf Deutsch. Erst mitten in der `PLAN`-Phase (Task-Zerlegung
für die Umsetzung) fiel auf, dass `Requirements.md` die Sprache der
Oberflächentexte gar nicht festlegt. Die Rückfrage dazu ergab zunächst
"Englisch nur für UI-Texte" (R7 in `Architecture.md`), wenig später –
nachdem der Planner mangels Vorgabe für `README.md`/`USERMANUAL.md`
"Deutsch" angenommen hatte – eine Korrektur auf "Englisch durchgängig ab
Architecture.md, inklusive Doku, Kommentare, Tests". Das kostete zwei
Nachbesserungsrunden an bereits geschriebenen Artefakten
(`Architecture.md`, eine Task-Datei).

**Vorschlag**: Der Baustein `AUFTRAGSKLAERUNG` (Orchestrator, Schritt 2
in `orchestrator.md`) sollte **immer** – nicht nur bei Bedarf – eine
knappe Sprachfrage stellen, sobald ein Auftrag Artefakte erzeugt, die
über das Workflow-interne `.agent/`-Verzeichnis hinausgehen (Code,
Kommentare, Tests, README/USERMANUAL, ausgelieferte Texte). Vorschlag für
die Frage samt Default:

> "In welcher Sprache sollen Code, Kommentare, Tests und
> nutzerseitige Dokumentation (README, Handbuch, UI-Texte) sein? Die
> interne Workflow-Sprache (Requirements/AUFTRAG/Task-Dateien) bleibt
> davon unabhängig [Sprache X, aus dem bisherigen Repo-Zustand
> abgeleitet]. Vorschlag: dieselbe Sprache wie die Spezifikation."

Das gehört in den Baustein `AUFTRAGSKLAERUNG` selbst (nicht erst in
`KLAERUNG`/`PLAN`), weil die Antwort **alle** nachgelagerten Bausteine
betrifft und sonst wie hier nachträglich durchgezogen werden muss.

## 2. Auftragstyp `REQUIREMENTS`: dieselbe Frage am Einstieg

**Beobachtung**: Der Nutzer wünscht sich ausdrücklich, dass auch beim
Start einer `REQUIREMENTS`-Klärungsschleife (Abschnitt 3a in
`orchestrator.md`) nach der Zielsprache gefragt wird – nicht erst, wenn
später (in einer `FEATURE`-Initiative) Code/Doku daraus entsteht.

**Vorschlag**: Ergänzung in Abschnitt 3a, Schritt 1 (oder als
vorgelagerter Schritt 0): bevor die erste Klärungsrunde mit `KLAERUNG`
(a) startet, fragt der Orchestrator einmalig nach der Zielsprache für
künftige Artefakte (siehe Vorschlagstext oben) und trägt die Antwort in
`AUFTRAG.md` ein, damit sie über `../history/` archiviert und von einer
späteren `FEATURE`-Initiative zum selben Produkt wiederverwendet werden
kann (z.B. als Feld in `Requirements.md`s Kopf-Hinweis oder als eigener,
dauerhafter Vermerk – zu klären, wo das am sinnvollsten dauerhaft
festgehalten wird, damit es nicht wie hier pro Initiative neu verhandelt
werden muss).

## 3. Kleinere Beobachtung: Ort für "später wiederaufzugreifen"-Notizen

> **Erledigt (Rückfluss 2026-10, umgezogen 2026-11):** Bewusst vertagte
> Findings, notierte Aufträge und fremde Probleme stehen in
> `state/BACKLOG.md` (der Orchestrator nennt sie bei der nächsten
> Auftragsklärung); bewusst akzeptierte Abweichungen in
> `spec/architecture/abweichungen.md`. Text unten nur noch als Herkunft.

**Beobachtung**: Für "Entfernung von `pwdHash.html` in einer späteren
Iteration" gab es keinen offensichtlichen dauerhaften Ablageort ausser
`Architecture.md` → "Bekannte Abweichungen/Schulden". Das hat gut
funktioniert, ist aber zweckentfremdet (dort stehen laut Vorlage
eigentlich *unerwünschte* Abweichungen vom Wunschzustand, nicht bewusst
vertagte Folgearbeit). Eventuell lohnt sich ein eigener, kurzer
Abschnitt/eine eigene Datei-Konvention für "vorgemerkt, aber nicht
Teil dieser Initiative" – aktuell landet das je nach Fall in
`Architecture.md`, in `AUFTRAG.md`s "Draussen" oder gar nicht.

## 4. Token-/Nutzungslimit: Verhalten bei Annäherung sollte am Sessionstart geklärt werden

**Beobachtung**: Während dieser Initiative lief die Session in ein
Rate-Limit ("session limit"), mitten in einem laufenden Subagenten-Lauf
(Task-Datei-Korrektur), der dadurch abgebrochen wurde und einen
inkonsistenten Zwischenstand hinterliess (teilweise durchgeführte
Umbenennung), den der Orchestrator manuell nachziehen musste.

**Vorschlag**: Der Orchestrator sollte **am Anfang jeder Session**
(Vorbereitung, vor dem ersten Baustein) abfragen, wie mit einer
absehbaren Annäherung an das Nutzungs-/Tokenlimit umgegangen werden soll
– z.B. "bei 90% Verbrauch sauber an einer Baustein-Grenze pausieren" vs.
"bis 100% weiterlaufen und das Risiko eines harten Abbruchs mitten in
einem Lauf in Kauf nehmen". Ergänzend: nach einem harten Abbruch sollte
der Orchestrator grundsätzlich (nicht nur wenn der Nutzer danach fragt)
prüfen, ob der unterbrochene Baustein einen unvollständigen
Zwischenstand hinterlassen hat, bevor weitergemacht wird.

## 5. Sandbox-Uhrzeit ist falsch (2 Stunden verschoben)

**Beobachtung**: Die Systemzeit in dieser Sandbox-Session weicht von der
tatsächlichen Zeit um **2 Stunden** ab. Das betrifft alles, was sich auf
"jetzt" verlässt (Zeitstempel in Historie/Progress-Einträgen,
"heutiges Datum" in Klärungsrunden, o.ä.).

**Vorschlag**: Sandbox-Umgebung so konfigurieren, dass die Systemzeit
mit der tatsächlichen Zeit übereinstimmt (z.B. NTP/Zeitzonen-Konfiguration
des Containers prüfen), oder – falls das nicht praktikabel ist – den
Orchestrator anweisen, sich für Datumsangaben nicht auf die Sandbox-Uhr
zu verlassen, sondern die Zeit explizit vom Nutzer/einer externen Quelle
zu erfragen.

---

## 6. `auto-rejecting`-Prüfung sucht noch im ganzen Log

**Wo**: `project-template/.agent/run-role.sh`, Abschnitt "Mechanische
Pruefung der beiden stillen Fehlerbilder".

**Warum das stört**: Die Prüfung greppt das gesamte Log. Dort steht auch,
was das Modell nur zitiert – in Nacht 1 (pwd-transform) zeigte der
Implementer per `git diff` eine PROGRESS-Zeile mit genau diesem Wort, und
die Prüfung schlug fälschlich an. Die Verdict-Prüfung ist bereits auf die
letzte Antwort des Modells beschränkt (über `opencode export`); für
`auto-rejecting` fehlt noch der Nachweis, wo opencode diese Meldung
ausgibt (stderr? eigenes Log-Format? als Tool-Fehler in der Sitzung?).

**Mögliche Lösung**: An einem echten Lauf mit abgelehnter Berechtigung
prüfen, ob die Meldung nur auf stderr kommt (dann stderr getrennt
mitschreiben und nur dort suchen) oder in der Sitzung als Tool-Fehler
steht (dann über `opencode export`).

**Aufgefallen**: Rückfluss pwd-transform, 2026-10-14; Umsetzung
2026-10-24 ohne erreichbares Modell, daher offen.

---

## 7. Lesesperre für fremde Task-Dateien noch nicht scharf

**Wo**: `project-template/.agent/agents/implementer.meta.yml`
(`read_denies`, auskommentiert), `run-role.sh` (`AGENT_ATTACH_TASK`).

**Warum offen**: OpenCode kennt `read`-Regeln mit Mustern (verifiziert
per `opencode debug agent`). Mit der Sperre kann der Implementer aber
auch die eigene Task-Datei nicht per Read-Tool öffnen; sie muss per `-f`
angehängt werden. Ob ein Anhang trotz Sperre gelesen wird, ist an einem
echten Lauf zu prüfen.

**Vorgehen**: Einen Lauf mit `read_denies` und `AGENT_ATTACH_TASK=1`
fahren; liest der Implementer die Task und versucht ein Read auf einen
fremden Task, muss dieser abgelehnt werden. Dann Default umstellen.

**Aufgefallen**: TASK-0066 V1 (pwd-transform) las fünf fremde Task-Dateien.

---

## 8. Sandbox ohne geteilten Ordner: an echtem Docker prüfen

**Wo**: `sandbox/run-sandbox.sh`, `sandbox/agent-remote.sh`.

**Warum offen**: Gebaut und getestet am 2026-11-02 ohne Docker, mit einem
Stellvertreter, der Volumes als Ordner nachbildet; der Git-Teil (Remote,
Fetch und Push über eigenes `uploadpack`/`receivepack`, idempotenter
Erststart) lief mit echtem Git. Nicht geprüft ist, was nur Docker zeigt.

**Vorgehen** (einmal auf dem Mac, Docker Desktop):
- Erststart auf einem Test-Repo: Volume angelegt, `chown` nötig oder
  nicht, Branch im Container ausgecheckt.
- `git fetch agent` und `git push agent HEAD:nutzer/inbox` über
  `docker run -i` ohne `-t`: Protokoll binär sauber, keine
  Docker-Meldungen auf stdout.
- Fetch-Knopf in VS Code (erwartet: nutzt die Remote-Config).
- Fetch bei gestoppter Sandbox; `docker rm` + Neustart auf
  bestehendem Volume; `--new`.
- Alter Container ohne Label wird als "früherer Betrieb" erkannt
  (`<no value>` wird bereits wie leer behandelt).

**Aufgefallen**: Umbau auf Klon im Volume (DECISIONS, Lehre 20).

> **Teilweise geprüft (2026-11-14, Mac, Docker Desktop):** Erststart mit
> `--new` neben einem stehenden alten Container (Volume angelegt, Branch
> hineingeschoben, Remote `agent-1`); `git fetch agent-1` und
> `git push agent-1 HEAD:nutzer/inbox` über `docker run -i`, ohne
> Docker-Meldungen im Protokoll; `review-branch.sh`; Fetch eines neuen
> Commits bei gestoppter Sandbox. Bewusst weggelassen: Fetch-Knopf in
> VS Code (ruft dieselbe Git-CLI auf; die Kommandozeile genügt).
> **Noch offen:** `docker rm` + Neustart auf bestehendem Volume; Erkennung
> eines alten Containers ohne Label; Push nach `nutzer/inbox` mit neuen
> Objekten (getestet nur das Anlegen des Branches auf einen vorhandenen
> Commit; die Objektübertragung in der Gegenrichtung lief).
> **Nebenbefunde:** Im Image fehlte `less`; Git nahm `more` (util-linux
> 2.38), das am Ende kurzer Ausgaben wartet – `git branch` schien zu
> hängen. Behoben im Dockerfile. – Ein Agent-Branch entstand auf einem
> Test-Branch statt auf der Basis, weil im Container zwischendurch von
> Hand umgeschaltet wurde; der Testcommit kam per Fast-Forward mit. Lehre:
> vor `git switch -c` den aktuellen Branch prüfen (Agent), vor dem Merge
> `git log --oneline <basis>..<agent-branch>` lesen (Nutzer).

---

## 9. Agent pusht selbst (Remote-Hosts) – zurückgestellt

**Wo**: `sandbox/`, Git-Abschnitt in `AGENT_WORKFLOW_REFERENZ.md`.

**Warum offen**: Anforderung 4 aus der Git-Übergabe (2026-11-02): Läuft
der Agent auf einem entfernten Rechner (runpod o.ä.), soll er evtl.
selbst pushen, damit Resultate ohne Umweg ankommen. Sicher geht das nur,
wenn der Server `main` schützt und der Agent nur `agent/*` pushen darf.
GitHub setzt Branch-Schutz und Rulesets bei privaten Repos im Free-Plan
nicht durch; GitLab (Protected Branches auch im Free-Tier) oder ein
bezahlter GitHub-Plan schon.

**Mögliche Lösung**: je Projekt ein Deploy-Key bzw. Token mit Schreibrecht
nur auf `agent/*`, serverseitig erzwungen; bis dahin Push nur durch den
Menschen. Ebenfalls zurückgestellt (Empfehlung: nein): ein optionaler
"Prüfpunkt"-Modus, in dem der Agent vor Commits in Klärungsbausteinen
anhält.

**Aufgefallen**: Git-Übergabe aus dem Projekt wiki-assistent,
Entwurf B' (2026-11-02).

---

## 10. E2E-Tests und Screenshots für UI-Projekte – zurückgestellt

**Wo**: neuer Baustein oder Teil von `VERIFIKATION`/`REVIEW`; Tester bzw.
Reviewer.

**Warum offen**: Journey Hero hat dafür eine eigene Phase: ein Agent
schreibt Tests über ganze Abläufe und nimmt je geändertem Bildschirm
einen Screenshot auf, die Doku verweist darauf. Bei uns prüfen Tests
das Verhalten je Task; ob die Oberfläche als Ganzes stimmt, sieht erst
der Mensch beim manuellen Test (`TRIAGE`).

**Mögliche Lösung**: am ersten UI-Projekt entscheiden – etwa ein
optionaler Baustein nach der Task-Schleife, aktiviert, wenn der Diff
Bildschirme ändert, mit Screenshots unter `.agent/reports/`. Nicht
vorab bauen: Werkzeug (Emulator, Browser) und Nutzen hängen stark vom
Projekt ab.

**Aufgefallen**: Abgleich mit Journey Hero, J9 (2026-11-15).

---

## 11. Pfad-Sperren in Claude Code per Hook – entschieden: nicht bauen

> **Entschieden (2026-11-15, Nutzer):** wird nicht gebaut. Es bleibt bei
> der Regel im Prompt plus der Diff-Prüfung des Orchestrators. Text unten
> als Beleg, falls die Frage wiederkommt.

**Wo**: `project-template/.agent/sync-agents.py` (Claude-Adapter),
`project-template/.claude/settings.json`, `HARNESS.md`.

**Warum offen**: In Claude Code sind Schreibrechte je Rolle (Implementer:
keine Tests; Reviewer, Architekt: nur eigene Dateien) nur eine Regel im
Prompt plus die Diff-Prüfung des Orchestrators – die grösste Lücke der
Härtung gegenüber OpenCode. Geprüft am 2026-11-15 (Claude Code 2.1.281,
Wegwerf-Projekt, Subagent schreibt in einen gesperrten Ordner):

- `hooks:` im **Frontmatter des Subagenten** (`PreToolUse`, Matcher
  `Write|Edit|…`): greift **nicht** – der Hook lief nie, auch nicht mit
  absolutem Pfad zum Skript; die Datei wurde geschrieben.
- Derselbe Hook in **`.claude/settings.json`**: greift, auch für
  Subagenten. Die Eingabe des Hooks enthält `tool_input.file_path` und
  bei Subagenten `agent_type` (= `name:` der Rolle); in der Hauptsitzung
  (Orchestrator) fehlt `agent_type`. Exit 2 blockiert den Aufruf, die
  Meldung auf stderr geht an den Subagenten zurück – auch mit
  `--dangerously-skip-permissions`.

**Mögliche Lösung**: `sync-agents.py` erzeugt aus `path_allows`/
`path_denies` aller Rollen ein Skript `.agent/pfad-sperre.py`, das
`agent_type` und Pfad liest und gegen die Muster der Rolle prüft;
`.claude/settings.json` ruft es als `PreToolUse`-Hook für
`Write|Edit|MultiEdit|NotebookEdit` auf. Ohne `agent_type` (Orchestrator)
lässt es alles durch. Offene Fragen vor dem Bau: Schreiben über `Bash`
(`echo > tests/x`) fängt ein solcher Hook nicht – nur mit einem
zusätzlichen, unscharfen `Bash`-Matcher; und die Diff-Prüfung des
Orchestrators bleibt ohnehin nötig. Entscheid beim Nutzer.

**Aufgefallen**: Abgleich mit Journey Hero, J7 (2026-11-15).
