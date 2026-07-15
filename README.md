# Agent-Workflow: Von neuem Projekt bis fertig implementiert

Projektunabhängige Tooling-Sammlung für einen wiederholbaren Ablauf: ein
neues Projekt anlegen, Anforderungen mit einem Agenten erarbeiten, einen
Umsetzungsplan erstellen und ihn dann selbständig (mit Implementer-/
Test-Sub-Agenten) durchimplementieren lassen — optional in einer isolierten
Sandbox mit voller Handlungsfreiheit für den Agenten.

## Bestandteile

- **`AGENT_WORKFLOW.md`** – die Methodik selbst: Orchestrator +
  Implementer-Agent + Test-Agent, kleine unabhängig testbare Schritte,
  `PROGRESS.md` als Übergabe-Datei zwischen kontextfreien Sub-Agent-Läufen.
- **`sandbox/`** – Docker-Sandbox, in der ein Agent im
  "volle Freiheit"-Modus (`bypassPermissions`) arbeiten kann, ohne
  Host-Risiko (Details/Sicherheitsbegründung:
  `sandbox/SANDBOX_BOOTSTRAP_PATTERN.md`, Build/Start: `sandbox/README.md`).
- **`project-template/`** – wird 1:1 in jedes neue Projekt kopiert:
  `AGENTS.md`/`CLAUDE.md` im Root (Claude Code lädt diese automatisch) plus
  `.agent/` mit leeren Gerüsten für `Requirements.md`,
  `IMPLEMENTATION_PLAN.md`, `PROGRESS.md`, `MEMORY.md`.

## Warum `.agent/` statt Dateien im Projekt-Root

Requirements/Plan/Progress/Memory sind Tooling-Artefakte, kein Teil des
eigentlichen Produktcodes. Sie liegen deshalb gebündelt in einem
Unterordner `.agent/` (kein `.gitignore`-Sonderfall — Punkt-Ordner werden
von Git normal getrackt, das ist reine Übersichtlichkeit beim Durchsehen
des Projekts). Nur `AGENTS.md`/`CLAUDE.md` bleiben im Root, weil Claude Code
diese dort automatisch beim Start lädt.

## Ablauf für ein neues Projekt

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

### 3. Requirements erarbeiten
Mit dem Agenten interaktiv die funktionalen Anforderungen durchgehen
(Rückfragen, Annahmen explizit machen) — siehe `AGENTS.md` im Projekt,
Abschnitt "Vorbereitung". Ergebnis: `.agent/Requirements.md` ausgefüllt.
**Nicht überspringen**, auch wenn der Agent versucht sein könnte, direkt
loszuimplementieren.

### 4. Plan erstellen
Auf Basis der fertigen Requirements gemeinsam `.agent/IMPLEMENTATION_PLAN.md`
erarbeiten: kleine, unabhängig testbare Schritte mit Deliverable +
Akzeptanzkriterien (siehe `AGENT_WORKFLOW.md` für die Kriterien guter
Schritte).

### 5. Orchestrator starten
Ab jetzt arbeitet der Agent als Orchestrator (Rolle ist in `AGENTS.md`
bereits definiert): pro Schritt ein frischer Implementer-Sub-Agent, danach
ein frischer, unabhängiger Test-Sub-Agent, Fortschritt in
`.agent/PROGRESS.md`. Läuft in der Sandbox: `.git` ist read-only, der
Orchestrator bereitet fertige Diffs vor statt selbst zu committen (siehe
`AGENTS.md`-Abschnitt "Vorbereitung" im Projekt-Template).

## Geplante Erweiterungen

Aktuell deckt dieser Workflow Requirements → Plan → Implementierung ab.
Später vorgesehen (noch nicht gebaut): weitere Agent-Rollen wie
Security-Review-Agent, Architektur-Review-Agent — als zusätzliche,
optionale Schritte nach abgeschlossener Implementierung, nach demselben
Grundmuster (klar abgegrenzte Rolle, eigener Kontext, Ergebnis in
`.agent/PROGRESS.md` oder einer eigenen Datei vermerkt).
