# Agent-Workflow: Von neuem (oder bestehendem) Projekt bis fertig implementiert

Projektunabhängige Tooling-Sammlung für einen wiederholbaren Ablauf: ein
Projekt anlegen (oder ein bestehendes übernehmen), Anforderungen und
Architektur mit Agenten erarbeiten/erfassen, und die Arbeit danach
selbständig über sechs spezialisierte Agenten-Rollen abarbeiten lassen —
optional in einer isolierten Sandbox mit voller Handlungsfreiheit, und
optional mit lokalen Modellen für einzelne Rollen.

> **Zum Einrichten eines Projekts: `USERMANUAL.md`.** Dort steht Schritt
> für Schritt, welche vier Dateien du anfassen musst (und welche nie),
> wie du Modelle je Rolle festlegst und wann der Generator laufen muss.
> Diese README erklärt, *warum* die Struktur so ist.

## Bestandteile

- **`USERMANUAL.md`** – das Benutzerhandbuch: Projekt anlegen oder
  übernehmen, Entscheidungen und ihre Dateien, Modellwahl (auch lokal),
  Betrieb im Alltag, Fehlerbilder.
- **`AGENT_WORKFLOW.md`** – die Methodik selbst: sechs Rollen
  (Orchestrator, Planner, Architekt, Implementer, Tester, Reviewer), ein
  Baustein-Katalog, aus dem der Orchestrator je nach geklärtem Auftrag
  einen Modus zusammensetzt (statt einer festen Pipeline), eine
  Task-Warteschlange als Übergabe-Format zwischen kontextfreien Läufen,
  sowie Greenfield- und Brownfield-Einstieg.
- **`sandbox/`** – Docker-Sandbox, in der ein Agent im
  "volle Freiheit"-Modus (`bypassPermissions`) arbeiten kann, ohne
  Host-Risiko (Details/Sicherheitsbegründung:
  `sandbox/SANDBOX_BOOTSTRAP_PATTERN.md`, Build/Start: `sandbox/README.md`).
- **`project-template/`** – wird 1:1 in jedes neue (oder bestehende)
  Projekt kopiert: `AGENTS.md`/`CLAUDE.md` im Root (Claude Code lädt diese
  automatisch) plus `.agent/` mit den Rollen-Dateien, dem Generator für die
  harness-spezifischen Adapter und leeren Gerüsten für
  Spec/State/Tasks/Reports/History.

## Struktur von `.agent/` – und warum

```
.agent/
  spec/       Requirements.md, Architecture.md   – dauerhaftes Produktwissen
  state/      AUFTRAG.md, IMPLEMENTATION_PLAN.md, PROGRESS.md, MEMORY.md
                                                 – Workflow-Zustand
  agents/     <rolle>.md + <rolle>.meta.yml, _tiers.yml – eine Rolle je Paar
  sync-agents.py                                 – erzeugt die Harness-Adapter
  tasks/      TASK-####-<slug>.md                 – die planbare Warteschlange
  reports/    <datum>-review.md                   – Reviewer-Ausgaben
  inbox/      Rohmaterial aus manuellem Testen    – wird per TRIAGE ausgewertet
  runs/       Logs fremder Harness-Läufe          – Inhalt nicht versioniert
  history/    <datum>-<slug>-auftrag.md, -plan.md – abgeschlossen, archiviert
```

Requirements/Plan/Progress/Memory/Reports/Tasks/Agenten sind
Tooling-Artefakte, kein Teil des eigentlichen Produktcodes – deshalb
gebündelt unter `.agent/` (kein `.gitignore`-Sonderfall, Punkt-Ordner
werden von Git normal getrackt, das ist reine Übersichtlichkeit). Nur
`AGENTS.md`/`CLAUDE.md` bleiben im Projekt-Root, weil Claude Code diese
dort automatisch beim Start lädt (OpenCode bevorzugt `AGENTS.md`).

Innerhalb von `.agent/` ist die Aufteilung bewusst zweigeteilt:

- **`spec/`** beschreibt *die Software* – bliebe relevant, selbst wenn man
  morgen aufhört, mit Agenten zu arbeiten. `Requirements.md` (was soll das
  Tool tun) ändert sich selten; `Architecture.md` (welche Komponente macht
  was) wird laufend aktuell gehalten, ist aber immer eine Momentaufnahme,
  keine Historie.
- **`state/`** beschreibt *den aktuellen Arbeitsstand an der Software* –
  nur für dieses Workflow-Tooling relevant. `AUFTRAG.md` hält das
  Teilstück fest, das der Nutzer gerade braucht (Anliegen, Umfang,
  Erfolgskriterium, Klärungsprotokoll) – es ist die erste Datei, die in
  einer Initiative entsteht, und die Quelle, aus der der Modus abgeleitet
  wird. `IMPLEMENTATION_PLAN.md` ist bewusst auf die **aktuell laufende
  Initiative** beschränkt (nicht die ganze Projekt-Geschichte); beide
  werden nach Abschluss nach `history/` archiviert – siehe `AGENT_WORKFLOW.md`, Abschnitt "Warum die Trennung
  spec/ ↔ state/", das war ein konkretes Problem im ersten Projekt.

Die Gross-/Kleinschreibung der Dateinamen ist ein bewusstes Signal:
`PascalCase` (spec/) = kuratiertes Referenzdokument, `SCREAMING_SNAKE`
(state/) = einzelner mutierbarer Zustand, `lowercase` (agents/, tasks/,
reports/, history/) = viele gleichartige Instanzen.

## Rollen-Dateien und Modellwahl

Die Rollen-Dateien unter `.agent/agents/` sind **harness-neutral**: der
Body enthält nur die Rolle selbst, kein Frontmatter. Daneben liegt je
Rolle eine `*.meta.yml` mit der *Absicht* (Modell-Stufe, Schreibrechte,
Pfad-Grenzen, Schritt-Obergrenze), und `_tiers.yml` bildet die Stufen auf
konkrete Modelle ab.

```bash
python3 .agent/sync-agents.py           # Adapter erzeugen/aktualisieren
python3 .agent/sync-agents.py --check   # nur prüfen (Exit 1 bei Drift)
```

Daraus entstehen `.claude/agents/*.md` und `.opencode/agent/*.md` –
**generiert, nie von Hand editieren**. Der Grund für den Umweg: das
`.md`-Format ist zwischen Harnesses nicht kompatibel (OpenCode liest
`.claude/agents/` nicht), und Claude-Code-Rollen lösen keine
`@datei.md`-Imports auf, ein Adapter kann den Body also nicht einbinden.

**Wenn einzelne Rollen auf lokalen Modellen laufen sollen:** das geht nur
über OpenCode. Claude Code akzeptiert pro Rolle ausschliesslich
Anthropic-Modelle, und die Umleitung auf einen anderen Anbieter wirkt
immer für die gesamte Session – ein Mischbetrieb (Planner in der Cloud,
Implementer lokal) ist dort strukturell nicht möglich. In `_tiers.yml`
stellt man das um, nicht in den Rollen-Dateien. Details und die
verifizierte Harness-Matrix: `AGENT_WORKFLOW.md`, Teil D.

## Ablauf für ein neues (Greenfield) Projekt

### 1. Projekt anlegen
```bash
mkdir /pfad/zum/neuen-projekt
cp -r tools/agent-workflow/project-template/. /pfad/zum/neuen-projekt/
cd /pfad/zum/neuen-projekt
git init
python3 .agent/sync-agents.py
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
`.agent/agents/orchestrator.md`, automatisch geladen über
`AGENTS.md`/`CLAUDE.md`). Sein erster Baustein ist immer die
**Auftragsklärung**: was ansteht, in welchem Umfang, woran man den
Abschluss erkennt – festgehalten in `.agent/state/AUFTRAG.md`, woraus sich
der Modus ergibt. Bei einem leeren Projekt ist das meist `REQUIREMENTS`
(Anforderungen Thema für Thema erarbeiten, Ergebnis `Requirements.md`),
danach als eigener Auftrag `FEATURE`: Klärung → Plan → Architektur-Gate →
pro Task die Schleife aus `TEST_FIRST` → `UMSETZUNG` → `VERIFIKATION` →
abschliessender Review. Details: `AGENT_WORKFLOW.md`, Teil C.

## Ablauf für ein bestehendes (Brownfield) Projekt

### 1. Struktur übernehmen
```bash
cp -r tools/agent-workflow/project-template/AGENTS.md /pfad/zum/projekt/
cp -r tools/agent-workflow/project-template/CLAUDE.md /pfad/zum/projekt/
cp -r tools/agent-workflow/project-template/.agent /pfad/zum/projekt/
cd /pfad/zum/projekt && python3 .agent/sync-agents.py
```
Produktcode bleibt unangetastet – nur die `.agent/`-Struktur und die
Root-Dateien kommen dazu. In `implementer.meta.yml`/`tester.meta.yml` die
Pfadmuster an die Testablage des Projekts anpassen, dann neu generieren.

### 2. Architektur erfassen (statt Plan-Historie)
Baustein `MAP` laufen lassen (Reviewer): liest den bestehenden Code und
erzeugt `spec/Architecture.md` direkt daraus. Keine Rekonstruktion einer
Bauhistorie nötig – nur der aktuelle Stand zählt.

### 3. Requirements erfassen
Eigener Auftrag im Modus `REQUIREMENTS`: der Orchestrator klärt Thema für
Thema mit dem Nutzer, der Planner formuliert `spec/Requirements.md` daraus
aus. Falls bereits eine funktionale Beschreibung existiert (README,
Tickets), wird sie zum Ausgangsmaterial – ableiten und bestätigen lassen
statt aus dem Code zu raten.

### 4. Erste Initiative: meist ein Review
Baustein `REVIEW` prüft den Ist-Zustand gegen die frisch erarbeiteten
Requirements/Architecture und schreibt einen datierten Report unter
`.agent/reports/`. Der Planner wandelt die Findings in Tasks um, danach
die normale Task-Schleife. Details: `AGENT_WORKFLOW.md`, Abschnitte
"Brownfield-Einstieg" und "Review-zu-Fix-Zyklus".

## Geplante Erweiterungen

- **Pfad-Beschränkung in Claude Code mechanisch erzwingen.** Der Test-
  Freeze (Implementer darf Testdateien nicht ändern) ist dort aktuell nur
  eine Regel im System-Prompt plus die Diff-Prüfung des Orchestrators; ein
  `PreToolUse`-Hook könnte ihn wie in OpenCode hart durchsetzen.
- **Prüf-Linsen ausbauen.** Sicherheits-, Abhängigkeits- und
  UI-Perspektiven laufen als Linsen innerhalb des Reviewer-Audit-Modus.
  Falls eine davon regelmässig eigenständiges Gewicht bekommt, nach
  demselben Muster eine eigene Rolle ergänzen: Body + `meta.yml`, der
  Generator erzeugt die Adapter automatisch mit.
