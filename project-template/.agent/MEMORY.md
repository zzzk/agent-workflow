# Projekt-Notizen

Wird von Claude Code automatisch geladen (siehe `AGENTS.md`, Import
`@.agent/MEMORY.md`). Anders als das user-globale Memory-System liegt diese
Datei im Repo selbst und reist mit, wenn das Projekt kopiert/geklont wird
(z.B. auf einen anderen Rechner).

## Agent-Workflow-Muster fürs Bauen dieses Projekts

Wiederverwendbare Methodik liegt (ausserhalb dieses Repos) unter
`tools/agent-workflow/AGENT_WORKFLOW.md`: für Software-Aufgaben, die
selbständig durch ein günstiges/kleines Modell umgesetzt werden sollen,
Arbeit in kleine, unabhängig testbare Schritte zerlegen (1–2 Dateien
jeweils) und drei getrennte Rollen nutzen — Orchestrator, Implementer-Agent,
Test-Agent (kennt nur Akzeptanzkriterien, nicht die Implementierungs-
Begründung, damit Tests ehrlich bleiben). Implementer- und Test-Agent
kommunizieren nie direkt; der Orchestrator (bzw. `PROGRESS.md` als
Übergabe-Datei) trägt den Zustand zwischen frischen, kontextfreien
Sub-Agent-Aufrufen weiter, um Tokens zu sparen.

## Sandbox

Implementierung läuft (falls verfügbar) in der Agent-Sandbox aus
`tools/agent-workflow/sandbox/` (Docker, `bypassPermissions` user-scoped,
`.git` read-only gemountet). Details/Selbstcheck-Schritte: siehe
`tools/agent-workflow/sandbox/README.md` und
`tools/agent-workflow/sandbox/SANDBOX_BOOTSTRAP_PATTERN.md`.

<!--
Ab hier projektspezifische Notizen ergänzen, sobald es welche gibt (z.B.
Lessons Learned aus konkreten Schritten, überraschende Umgebungs-Eigenheiten,
bewusste Abweichungen vom Standardmuster). Nicht vorab spekulativ befüllen.
-->
