# Projekt-Notizen

Wird von Claude Code automatisch geladen (siehe `AGENTS.md`, Import über
`.agent/agents/orchestrator.md`). Anders als das user-globale
Memory-System liegt diese Datei im Repo selbst und reist mit, wenn das
Projekt kopiert/geklont wird (z.B. auf einen anderen Rechner).

## Agent-Workflow-Muster für dieses Projekt

Wiederverwendbare Methodik liegt (ausserhalb dieses Repos) unter
`tools/agent-workflow/AGENT_WORKFLOW.md`: fünf Rollen (Orchestrator,
Planner, Implementer, Tester, Reviewer, je eigene Datei unter
`.agent/agents/`), Arbeit in kleine, unabhängig testbare Tasks unter
`.agent/tasks/` zerlegt (1–2 Dateien je Task). Implementer und Tester
kommunizieren nie direkt; der Orchestrator bzw. die Task-Datei selbst
trägt den Zustand zwischen frischen, kontextfreien Sub-Agent-Aufrufen
weiter, um Tokens zu sparen.

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
