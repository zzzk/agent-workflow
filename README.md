# Agent-Workflow: Von neuem (oder bestehendem) Projekt bis fertig implementiert

Projektunabhängige Tooling-Sammlung für einen wiederholbaren Ablauf: ein
Projekt anlegen (oder ein bestehendes übernehmen), Anforderungen und
Architektur mit Agenten erarbeiten/erfassen, und die Arbeit danach
selbständig über fünf spezialisierte Agenten-Rollen abarbeiten lassen —
optional in einer isolierten Sandbox mit voller Handlungsfreiheit.

## Bestandteile

- **`AGENT_WORKFLOW.md`** – die Methodik selbst: fünf Rollen
  (Orchestrator, Planner, Implementer, Tester, Reviewer), eine
  Task-Warteschlange als Übergabe-Format zwischen kontextfreien
  Sub-Agent-Läufen, sowie Greenfield- und Brownfield-Einstieg.
- **`sandbox/`** – Docker-Sandbox, in der ein Agent im
  "volle Freiheit"-Modus (`bypassPermissions`) arbeiten kann, ohne
  Host-Risiko (Details/Sicherheitsbegründung:
  `sandbox/SANDBOX_BOOTSTRAP_PATTERN.md`, Build/Start: `sandbox/README.md`).
- **`project-template/`** – wird 1:1 in jedes neue (oder bestehende)
  Projekt kopiert: `AGENTS.md`/`CLAUDE.md` im Root (Claude Code lädt diese
  automatisch) plus `.agent/` mit den fünf Rollen-Dateien und leeren
  Gerüsten für Spec/State/Tasks/Reports/History (siehe Struktur unten).

## Struktur von `.agent/` – und warum

```
.agent/
  spec/       Requirements.md, Architecture.md   – dauerhaftes Produktwissen
  state/      IMPLEMENTATION_PLAN.md, PROGRESS.md, MEMORY.md – Workflow-Zustand
  agents/     orchestrator.md, planner.md, implementer.md,
              tester.md, reviewer.md              – eine Datei pro Rolle
  tasks/      TASK-####-<slug>.md                 – die planbare Warteschlange
  reports/    <datum>-review.md                   – Reviewer-Ausgaben
  history/    <datum>-<slug>-plan.md              – archivierte, abgeschlossene Pläne
```

Requirements/Plan/Progress/Memory/Reports/Tasks/Agenten sind
Tooling-Artefakte, kein Teil des eigentlichen Produktcodes – deshalb
gebündelt unter `.agent/` (kein `.gitignore`-Sonderfall, Punkt-Ordner
werden von Git normal getrackt, das ist reine Übersichtlichkeit). Nur
`AGENTS.md`/`CLAUDE.md` bleiben im Projekt-Root, weil Claude Code diese
dort automatisch beim Start lädt.

Innerhalb von `.agent/` ist die Aufteilung bewusst zweigeteilt:

- **`spec/`** beschreibt *die Software* – bliebe relevant, selbst wenn man
  morgen aufhört, mit Agenten zu arbeiten. `Requirements.md` (was soll das
  Tool tun) ändert sich selten; `Architecture.md` (welche Komponente macht
  was) wird laufend aktuell gehalten, ist aber immer eine Momentaufnahme,
  keine Historie.
- **`state/`** beschreibt *den aktuellen Arbeitsstand an der Software* –
  nur für dieses Workflow-Tooling relevant. `IMPLEMENTATION_PLAN.md` ist
  bewusst auf die **aktuell laufende Initiative** beschränkt (nicht die
  ganze Projekt-Geschichte) und wird nach Abschluss nach `history/`
  archiviert – siehe `AGENT_WORKFLOW.md`, Abschnitt "Warum diese Trennung",
  das war ein konkretes Problem im ersten Projekt (History mit einem
  bestehenden Codebestand zu verwechseln, sobald Requirements/Plan/Progress
  alle undifferenziert nebeneinanderlagen).

Die Gross-/Kleinschreibung der Dateinamen ist ein bewusstes Signal:
`PascalCase` (spec/) = kuratiertes Referenzdokument, `SCREAMING_SNAKE`
(state/) = einzelner mutierbarer Zustand, `lowercase` (agents/, tasks/,
reports/, history/) = viele gleichartige Instanzen.

## Ablauf für ein neues (Greenfield) Projekt

### 1. Projekt anlegen
```bash
mkdir /pfad/zum/neuen-projekt
cp -r tools/agent-workflow/project-template/. /pfad/zum/neuen-projekt/
cd /pfad/zum/neuen-projekt
git init
```

### 2. Sandbox starten (optional, empfohlen für "volle Freiheit" ohne Rückfragen)
```bash
tools/agent-workflow/sandbox/run-sandbox.sh /pfad/zum/neuen-projekt
```
Danach innerhalb der Sandbox die Selbstcheck-/Bootstrap-Schritte aus
`sandbox/README.md` durchgehen (Schritt 0–5), bevor der eigentliche Agent
gestartet wird. Ohne Sandbox: normal `claude` im Projektordner starten,
läuft dann im üblichen, rückfragenden Berechtigungsmodus.

### 3. Orchestrator starten
Ab jetzt arbeitet der Agent als Orchestrator (Rolle in
`.agent/agents/orchestrator.md` definiert, automatisch geladen über
`AGENTS.md`/`CLAUDE.md`). Da noch keine Requirements vorliegen, fragt der
Orchestrator zuerst, was gebaut werden soll, und übergibt an den Planner
(`.agent/agents/planner.md`), der `spec/Requirements.md` interaktiv mit dem
Nutzer erarbeitet, danach `state/IMPLEMENTATION_PLAN.md` sowie die ersten
`tasks/*.md` erstellt. Danach läuft die normale Hauptschleife: pro Task ein
frischer Implementer-Sub-Agent, danach ein frischer, unabhängiger
Tester-Sub-Agent, Fortschritt in `state/PROGRESS.md` und den Task-Dateien
selbst. Details: `AGENT_WORKFLOW.md`, Abschnitt "Ablauf: Orchestrator-
Hauptschleife".

## Ablauf für ein bestehendes (Brownfield) Projekt

### 1. Struktur übernehmen
```bash
cp -r tools/agent-workflow/project-template/AGENTS.md /pfad/zum/projekt/
cp -r tools/agent-workflow/project-template/CLAUDE.md /pfad/zum/projekt/
cp -r tools/agent-workflow/project-template/.agent /pfad/zum/projekt/
```
Produktcode bleibt unangetastet – nur die `.agent/`-Struktur und die
Root-Dateien kommen dazu.

### 2. Requirements erfassen
Mit dem Orchestrator/Planner `spec/Requirements.md` ausfüllen – falls
bereits eine funktionale Beschreibung existiert (README, Tickets), daraus
ableiten und mit dem Nutzer bestätigen statt aus dem Code zu raten.

### 3. Architektur erfassen (statt Plan-Historie)
Reviewer im **Map-Modus** laufen lassen: liest den bestehenden Code und
erzeugt `spec/Architecture.md` direkt daraus. Keine Rekonstruktion einer
Bauhistorie nötig – nur der aktuelle Stand zählt.

### 4. Erste Initiative: meist ein Review
Reviewer im **Audit-Modus** prüft den Ist-Zustand gegen die frisch
erarbeiteten Requirements/Architecture, schreibt einen datierten Report
unter `.agent/reports/`. Planner wandelt die Findings in Tasks um, danach
normale Hauptschleife. Details: `AGENT_WORKFLOW.md`, Abschnitte
"Brownfield-Einstieg" und "Review-zu-Fix-Zyklus".

## Geplante Erweiterungen

Security-Review- und Architektur-Review-Perspektiven laufen aktuell als
zusätzliche Prüf-Dimensionen innerhalb des Reviewer-Audit-Modus. Bei Bedarf
eigene, spezialisierte Reviewer-Varianten (z.B. `agents/security-reviewer.md`)
nach demselben Grundmuster ergänzen: klar abgegrenzte Rolle, eigener
Kontext, Ergebnis als datierter Report unter `.agent/reports/`.
