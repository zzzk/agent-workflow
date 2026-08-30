# Vorgehen: Orchestrator + Planner + Implementer/Test/Reviewer-Agenten

Generische, wiederverwendbare Methode, um ein Software-Vorhaben durch
günstige/kleine Modelle (auch lokal, geringe Fähigkeiten) selbständig
umsetzen zu lassen, ohne dass Qualität oder Kontrollierbarkeit leiden.
Ursprünglich entwickelt für das Encrypted-Backup-Tool-Projekt (Requirements
→ Plan → Implementierung). Nach Abschluss dieses ersten Projekts und einem
anschliessenden Review-Durchlauf (Code entsprach an mehreren Stellen nicht
mehr dem Plan) auf **v2** erweitert: fünf statt drei Rollen, ein
Review-Agent, und eine klare Trennung zwischen dauerhaftem Produktwissen und
vergänglichem Workflow-Zustand (siehe "Warum v2" unten).

## Wann anwenden

- Das Vorhaben lässt sich in klar abgrenzbare, unabhängig testbare
  Arbeitspakete zerlegen (z.B. Module/Funktionen mit klarem
  Ein-/Ausgabeverhalten).
- Es soll ein kleines/günstiges (ggf. lokales) Modell verwendet werden
  (begrenztes Kontextfenster, geringere Zuverlässigkeit bei grossen
  Aufgaben am Stück).
- Gilt sowohl für **Greenfield** (neues Projekt, Requirements + Plan werden
  von Null erarbeitet) als auch für **Brownfield** (bestehender Code ohne
  – oder mit veralteter – Doku; siehe "Brownfield-Einstieg" unten).

## Grundprinzip: fünf Rollen, je eine eigene Datei

Jede Rolle hat einen bewusst engen, für sich lauffähigen Kontext und eine
eigene Datei unter `.agent/agents/` (siehe "Dateistruktur"). Eine Rolle
liest **nie** die volle bisherige Gesprächshistorie – nur das, was ihre
Auftragsdatei (ein Task, ein Report, o.ä.) tatsächlich braucht.

1. **Orchestrator** (`agents/orchestrator.md`) – dünne Schleife, kein
   grosses Kontextfenster nötig. Fragt den Nutzer zu Beginn, was zu tun ist
   (falls keine offene Arbeit vorliegt), wählt danach wiederholt den
   nächsten offenen Task aus `.agent/tasks/`, startet dafür frische
   Implementer-/Test-Sub-Agenten, pflegt Task-Status + `state/PROGRESS.md`,
   committet. Schreibt selbst keinen Code und plant selbst keine Schritte.
2. **Planner** (`agents/planner.md`) – die "Denkarbeit": zerlegt eine
   Quelle (neue Anforderung, oder Findings aus einem Review-Report) in
   kleine, unabhängige `.agent/tasks/TASK-*.md`-Dateien. Braucht mehr
   Kontext/Fähigkeit als die Ausführungsrollen – hier lohnt sich ein
   stärkeres Modell, falls unterschiedliche Modelle je Rolle möglich sind.
3. **Implementer** (`agents/implementer.md`) – setzt **genau einen** Task
   um (Code + ggf. minimale Doku/Architecture-Update), nichts darüber
   hinaus. Kennt weder vorherige noch zukünftige Tasks im Detail.
4. **Tester** (`agents/tester.md`) – unabhängig vom Implementer, kennt nur
   die **Akzeptanzkriterien** des Tasks (nicht die Implementierungs-
   Begründung), schreibt/ergänzt Tests dagegen und führt die gesamte Suite
   aus. Diese Unabhängigkeit ist bewusst: sie verhindert, dass Tests
   einfach nachvollziehen, was sich der Implementer gedacht hat, statt
   echt gegen die Spezifikation zu prüfen.
5. **Reviewer** (`agents/reviewer.md`) – read-only Auditor, editiert nie
   Produktcode/Tests. Zwei Modi: **Map-Modus** (Bestandsaufnahme eines
   bestehenden Codebestands → `spec/Architecture.md`) und **Audit-Modus**
   (Code + Tests gegen `spec/Requirements.md`/`spec/Architecture.md`
   prüfen, Ergebnis als datierter Report unter `.agent/reports/`
   ablegen). Erzeugt selbst keine Tasks – das macht der Planner aus dem
   Report.

Implementer und Tester interagieren **nie direkt** miteinander – jede
Übergabe läuft über den Orchestrator bzw. über die Task-Datei selbst.

## Dateistruktur (pro Projekt, unter `.agent/`)

```
AGENTS.md                        # Projekt-Root, @-importiert agents/orchestrator.md
CLAUDE.md                        # Projekt-Root, @-importiert AGENTS.md

.agent/
  spec/                          # dauerhaftes Produktwissen (PascalCase –
                                  # relevant unabhängig von diesem Workflow)
    Requirements.md               # funktionale Anforderungen, ändert sich selten
    Architecture.md               # aktuelle Komponenten/Verantwortlichkeiten,
                                   # lebendig gehalten, keine Historie

  state/                         # veränderlicher Workflow-Zustand (SCREAMING_SNAKE)
    IMPLEMENTATION_PLAN.md        # NUR die aktiv laufende Initiative; leer,
                                   # wenn gerade nichts läuft
    PROGRESS.md                   # Append-only chronologisches Log
    MEMORY.md                     # projektspezifische Notizen über Sessions hinweg

  agents/                        # eine Datei pro Rolle (lowercase)
    orchestrator.md
    planner.md
    implementer.md
    tester.md
    reviewer.md

  tasks/                         # die atomare, planbare Warteschlange (lowercase)
    TEMPLATE.md
    TASK-0001-<slug>.md
    ...

  reports/                       # datierte, read-only Review-Ausgaben (lowercase)
    2026-08-30-review.md

  history/                       # Archiv abgeschlossener Pläne (lowercase)
    2026-08-15-initial-build-plan.md
```

Die Drei-Stufen-Schreibweise ist bewusst: `PascalCase` = kuratiertes
Referenzdokument über die Software selbst, `SCREAMING_SNAKE` = einzelner,
mutierbarer Zustand, `lowercase` = viele gleichartige Instanzen
(Rollen/Tasks/Reports). Wer eine Datei sieht, weiss am Namen, in welche
Kategorie sie gehört.

## Warum diese Trennung (v2 gegenüber v1)

Im ersten Projekt lagen Requirements/Plan/Progress/Memory alle flach unter
`.agent/`, und die drei Rollen (Orchestrator/Implementer/Test-Agent) waren
nur als Prosa **innerhalb** von `AGENTS.md` beschrieben statt als eigene
Dateien. Das funktionierte für den reinen Greenfield-Bau, zeigte aber zwei
Probleme, sobald ein nachträgliches Review lief:

1. **`IMPLEMENTATION_PLAN.md` als Dauer-Rückgrat funktioniert nur
   Greenfield.** Der Plan ist naturgemäss temporal (Schritt 0, 1, 2, ...)
   und damit fürs *aktuelle* Verständnis eines bestehenden Systems
   ungeeignet – ein neuer (insb. kleiner/lokaler) Agent müsste die ganze
   Baugeschichte lesen, nur um zu erfahren, welche Datei heute wofür
   zuständig ist. `spec/Architecture.md` beantwortet genau das als
   lebendige Momentaufnahme, unabhängig davon, wie der Code entstanden ist.
   `state/IMPLEMENTATION_PLAN.md` wird dadurch entlastet: nur noch die
   *aktuell laufende* Initiative, danach nach `history/` archiviert statt
   endlos zu wachsen.
2. **Rollen nur als Prosa in `AGENTS.md` verwischen Zuständigkeiten**,
   sobald mehr als "bauen" ansteht (Review, gezielte Bugfixes). Jetzt hat
   jede Rolle eine eigene Datei unter `agents/`, und ein **Task** (nicht
   ein Plan-Schritt) ist die einheitliche Ausführungseinheit – egal ob er
   aus einer neuen Anforderung oder einem Review-Finding stammt.

## Task-Datei-Format (`.agent/tasks/TASK-####-<slug>.md`)

Die Task-Datei ist die einzige Information, die ein Implementer- oder
Test-Sub-Agent zusätzlich zum bestehenden Code braucht – sie muss deshalb
**vollständig in sich geschlossen** sein.

```markdown
---
id: TASK-0023
title: <kurzer, imperativer Titel>
status: open            # open | in_progress | done | failed | blocked
source: plan-step       # plan-step | review-finding
source_ref: state/IMPLEMENTATION_PLAN.md#schritt-6   (oder: reports/2026-08-30-review.md#Schritt-9)
agent: implementer
depends_on: []           # andere Task-IDs, die vorher done sein müssen
files: [pfad/zur/datei.py]
---

## Deliverable
<konkret: max. 1-2 Dateien/Module>

## Akzeptanzkriterien
- <prüfbare Bedingung 1>
- <prüfbare Bedingung 2>

## Kontext
<nur was nötig ist: exakte Zeilen-/Snippet-Referenzen, der Finding-Text,
Verweis auf den relevanten Architecture.md-Abschnitt – nicht die ganze
Datei, nicht die Konversationshistorie>

## Test-Notizen
<vom Tester nach Prüfung ausgefüllt: welche Tests ergänzt/ausgeführt, Ergebnis>
```

## Regeln für die Task-Grösse

- Ein Task betrifft max. 1–2 Dateien/Module. Ist ein Task grösser, wird er
  vom Planner weiter unterteilt statt in einem Rutsch vergeben.
- Ein Task muss ohne Kenntnis anderer Tasks umsetzbar sein (keine
  Vorgriffe auf noch nicht spezifizierte Interfaces) – Ausnahme:
  `depends_on` macht eine Reihenfolge explizit, wo sie unvermeidbar ist.
- Jeder Task hat konkrete, prüfbare Akzeptanzkriterien (keine vagen
  Beschreibungen wie "funktioniert gut").
- Abhängigkeiten von externer Hardware/Diensten werden vermieden bzw.
  gemockt; Hardware-/Sonderfälle werden als eigene, spätere Tasks
  behandelt statt die Kernlogik zu verkomplizieren.

## Vorbereitung (einmalig, vor dem ersten Task)

- **Berechtigungen im Voraus klären statt pro Aktion nachfragen.** Wenn
  Orchestrator und Sub-Agents bei praktisch jedem Dateizugriff/Bash-Befehl
  einzeln um Erlaubnis fragen müssen, ist "selbständig durchlaufen lassen"
  nicht möglich. Vor dem ersten Task einmal explizit klären/einrichten, in
  welchem Modus gearbeitet wird (Auto-Accept-Modus bzw. Allowlist, siehe
  Skill `fewer-permission-prompts`). Sub-Agents erben denselben
  Berechtigungsmodus wie der Orchestrator, sonst blockieren sie an
  derselben Stelle erneut.
- **Lokales Git für nachvollziehbare Zwischenstände.** Existiert noch kein
  Repo: `git init` + initialer Commit. Existiert bereits eines: beim
  Nutzer nachfragen, ob auf dem bestehenden Branch weitergearbeitet oder
  ein neuer Branch für diese Initiative erstellt werden soll.

## Ablauf: Orchestrator-Hauptschleife

1. **Startzustand prüfen**: Existiert `spec/Architecture.md` nicht (leer
   oder fehlt), aber es gibt bereits Code? → zuerst Reviewer im
   **Map-Modus** laufen lassen (siehe "Brownfield-Einstieg"), bevor
   irgendetwas geplant wird.
2. **Offene Arbeit prüfen**: Liegen offene Tasks unter `.agent/tasks/`
   vor? Falls ja: Nutzer fragen, ob die Warteschlange fortgesetzt oder
   etwas Neues begonnen werden soll (ausser bei explizit autonomem
   Auftrag). Falls nein: Nutzer fragen, was er umsetzen möchte, und daraus
   die Initiative einordnen:
   - **Neue Anforderung/Feature** → Planner mit `spec/Requirements.md` (+
     ggf. Klärungsbedarf mit dem Nutzer) und `spec/Architecture.md`
     beauftragen → `state/IMPLEMENTATION_PLAN.md` + `tasks/*.md`.
   - **Findings aus einem Review beheben** → Planner mit dem jüngsten
     Report unter `.agent/reports/` beauftragen → `tasks/*.md` (kein
     Plan-Dokument nötig für reine Bugfix-Initiativen, siehe
     `planner.md`).
   - **Neuer Review-Durchlauf gewünscht** → Reviewer im Audit-Modus
     starten, kein Planner nötig.
3. **Pro Task** (wiederholen bis keine offenen Tasks der aktiven
   Initiative mehr vorliegen):
   1. Nächsten offenen Task ermitteln (Status `open`, alle `depends_on`
      bereits `done`).
   2. Implementer-Sub-Agent starten: Auftrag = genau dieser Task
      (vollständiger Inhalt der Task-Datei). Status auf `in_progress`
      setzen.
   3. Unabhängigen Tester-Sub-Agenten starten: Auftrag = nur die
      Akzeptanzkriterien desselben Tasks (nicht der Implementer-Kontext).
   4. Bei Fehlschlag: neuer Implementer-Sub-Agent für denselben Task, mit
      den fehlgeschlagenen Tests als zusätzlichem Kontext. Zurück zu 3.
      Kein neuer Task beginnt, solange dieser nicht grün ist.
   5. Bei Erfolg: Task-Status auf `done`, eine Zeile an `state/PROGRESS.md`
      anhängen, **Git-Commit** (Task-ID + Titel als Commit-Message).
4. **Initiative abgeschlossen** (keine offenen Tasks mehr): aktuelles
   `state/IMPLEMENTATION_PLAN.md` (falls vorhanden) nach
   `history/<datum>-<slug>-plan.md` verschieben und zurücksetzen, kurze
   Zusammenfassung an den Nutzer, zurück zu Schritt 2.

## Brownfield-Einstieg

Für ein bestehendes Projekt ohne (oder mit veralteter) `.agent/`-Struktur:
keine historische Plan-Rekonstruktion nötig. Stattdessen:

1. `project-template/` in das bestehende Repo kopieren (nur die
   `.agent/`-Struktur + Root `AGENTS.md`/`CLAUDE.md`, Produktcode bleibt
   unverändert).
2. `spec/Requirements.md` ausfüllen – falls eine funktionale Beschreibung
   bereits anderswo existiert (README, Ticket-System), daraus ableiten und
   mit dem Nutzer bestätigen statt aus dem Code zu raten.
3. Reviewer im **Map-Modus** laufen lassen: liest den bestehenden Code und
   erzeugt `spec/Architecture.md` direkt daraus – keine Bauhistorie nötig.
4. Ab hier normaler Ablauf (siehe oben) – die erste Initiative ist häufig
   ein Reviewer-Audit-Durchlauf, um den Ist-Zustand gegen die frisch
   erarbeiteten Requirements zu prüfen.

## Review-zu-Fix-Zyklus

1. Reviewer (Audit-Modus) liest Code + führt Tests aus, schreibt
   `reports/<datum>-review.md` (Findings, keine Änderungen am Code).
2. Planner liest den Report, erzeugt einen Task pro Finding (ggf. weiter
   unterteilt, falls ein Finding mehrere Dateien/Module betrifft) unter
   `tasks/`.
3. Normale Orchestrator-Hauptschleife (Implementer/Tester pro Task).
4. Nach Abschluss aller Fix-Tasks: erneuter Reviewer-Durchlauf (neuer,
   datierter Report) zur Bestätigung – alte Reports bleiben als Verlauf
   erhalten (kein Überschreiben), damit sich der Zustand über Zeit
   nachvollziehen lässt.

## Umgang mit Nutzungs-/Rate-Limits

Falls während der Arbeit ein Nutzungslimit erreicht wird und die Session
deshalb abbrechen würde:

1. Sauber stoppen – keinen Task "halb" hinterlassen. Ist ein Sub-Agent
   mitten in einem Task, dessen Status in der Task-Datei als `in_progress`
   festhalten statt als `done`.
2. Den Reset-Zeitpunkt notieren (Statuszeile der Umgebung), in
   `state/PROGRESS.md` vermerken.
3. Falls verfügbar: `ScheduleWakeup` auf den Reset-Zeitpunkt legen, Prompt
   "Lies `.agent/tasks/` und mache als Orchestrator weiter."
4. Sonst: sauber stoppen, Nutzer kurz informieren, bei welchem Task
   pausiert wurde – eine neue Nachricht nach Reset genügt zum Fortsetzen,
   dank der Task-Dateien geht kein Fortschritt verloren.

## Lessons Learned

### Aus Projekt 1: Encrypted-Backup-Tool (v1, abgeschlossen)

1. **Berechtigungen waren der grösste Bremsklotz für "selbständig
   durchlaufen lassen".** Deshalb jetzt fester Vorbereitungs-Schritt (siehe
   oben): Berechtigungsumfang vor dem ersten Task einmal explizit klären,
   Sub-Agents erben denselben Modus.
2. **Ohne Versionskontrolle gab es keine nachvollziehbaren
   Zwischenstände.** Deshalb jetzt fest verankert: lokales Git-Repo vor dem
   ersten Task, ein Commit pro vollständig getestetem Task.
3. **Tests hatten keine eigene Doku und waren dadurch schwer zu
   überblicken.** `tests/README.md` (wie ausführen) und
   `tests/TEST_OVERVIEW.md` (was wird geprüft, thematisch) bleiben
   Pflichtbestandteil, spätestens nach der letzten Initiative aktualisiert.

### Aus dem Review-Durchlauf nach Projekt 1 (→ v2 dieser Methodik)

4. **Ein als "done" markierter Schritt war es nicht immer wirklich.** Ein
   nachträgliches Review deckte auf: zwei Schritte fehlten komplett im
   Fortschritts-Log obwohl umgesetzt, ein anderer war als "done" markiert
   obwohl die zugehörigen Tests gar nicht existierten (Exclude-Scan), und
   ein sicherheitsrelevantes Akzeptanzkriterium (Chunk-Reihenfolge über
   AEAD Associated Data) war weder implementiert noch getestet. Ursache:
   Kein unabhängiger Prüf-Durchlauf *nach* Abschluss aller Schritte, nur
   der Test-Agent pro Einzelschritt (der naturgemäss nur den je aktuellen
   Schritt kennt, nicht das Gesamtbild). Deshalb jetzt eigene Reviewer-
   Rolle als Pflicht-Bestandteil, nicht nur optionale Erweiterung.
5. **Doku und CLI liefen auseinander, ohne dass es auffiel.** `README.md`
   dokumentierte Befehle/Flags, die die CLI gar nicht kannte. Das
   zugehörige Akzeptanzkriterium ("jede in der Doku erwähnte Option
   existiert in der CLI") wurde nie automatisiert geprüft. Lehre:
   Akzeptanzkriterien, die Doku-Code-Konsistenz verlangen, brauchen einen
   Test, der das tatsächlich vergleicht – nicht nur eine manuelle
   Behauptung im Fortschritts-Log.
6. **Ein einzelnes, ewig wachsendes `IMPLEMENTATION_PLAN.md` behindert
   spätere Wartung.** Für die Kernfrage "was macht Komponente X" musste
   die ganze Bauhistorie durchsucht werden. → `spec/Architecture.md`
   eingeführt (siehe "Warum diese Trennung" oben).
