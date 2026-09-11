# Projekt-Notizen

Wird von Claude Code automatisch geladen (siehe `AGENTS.md`, Import über
`.agent/agents/orchestrator.md`). Anders als das user-globale
Memory-System liegt diese Datei im Repo selbst und reist mit, wenn das
Projekt kopiert/geklont wird (z.B. auf einen anderen Rechner).

## Agent-Workflow-Muster für dieses Projekt

Wiederverwendbare Methodik liegt (ausserhalb dieses Repos) unter
`tools/agent-workflow/AGENT_WORKFLOW.md`: sechs Rollen (Orchestrator,
Planner, Architekt, Implementer, Tester, Reviewer, je eigene Datei unter
`.agent/agents/`), die der Orchestrator je nach Ausgangslage zu einem
**Modus** zusammensetzt – es gibt keine feste Pipeline. Arbeit wird in
kleine, unabhängig testbare Tasks unter `.agent/tasks/` zerlegt (1–2
Dateien je Task); Tests entstehen **vor** der Implementierung und sind
danach eingefroren.

Implementer und Tester kommunizieren nie direkt; die Task-Datei trägt den
Zustand zwischen frischen, kontextfreien Aufrufen weiter – das spart
Tokens und ist gleichzeitig das Protokoll, falls eine Rolle in einem
anderen Harness läuft. Jede Rolle meldet mit einem Verdict zurück
(`PASS` / `PASS_WITH_NOTES` / `CHANGES_NEEDED` / `BLOCKED`).

## Rollen-Dateien sind generiert

`.agent/agents/<rolle>.md` (Body) + `<rolle>.meta.yml` (Absicht) +
`_tiers.yml` (Stufe → Modell) sind die Quelle. Daraus erzeugt
`python3 .agent/sync-agents.py` die harness-spezifischen Adapter unter
`.claude/agents/` und `.opencode/agent/` – **diese nie von Hand
editieren**. Welche Rolle auf welchem (auch lokalem) Modell läuft, wird
ausschliesslich in `_tiers.yml` umgestellt.

## Sandbox

Implementierung läuft (falls verfügbar) in der Agent-Sandbox aus
`tools/agent-workflow/sandbox/` (Docker, `bypassPermissions` user-scoped,
`.git` read-only gemountet). Details/Selbstcheck-Schritte: siehe
`tools/agent-workflow/sandbox/README.md` und
`tools/agent-workflow/sandbox/SANDBOX_BOOTSTRAP_PATTERN.md`.

<!--
Ab hier projektspezifische Notizen ergänzen, sobald es welche gibt (z.B.
Lessons Learned aus konkreten Tasks, überraschende Umgebungs-Eigenheiten,
bewusste Abweichungen vom Standardmuster). Nicht vorab spekulativ befüllen.
-->
