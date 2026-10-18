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
git diff <freeze-commit>..HEAD --name-only -- tests/
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
git diff <freeze-commit>..HEAD --name-only -- {{TEST_PATHS}}
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

## 2. Modus `REQUIREMENTS`: dieselbe Frage am Einstieg

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

