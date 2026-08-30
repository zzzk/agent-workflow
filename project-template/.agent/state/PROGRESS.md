# Progress

> Workflow-Zustand (siehe `tools/agent-workflow/AGENT_WORKFLOW.md`).
> Append-only, chronologisches Log, vom Orchestrator nach jedem
> abgeschlossenen Task ergänzt. Der massgebliche Status eines einzelnen
> Tasks steht in dessen Frontmatter unter `../tasks/TASK-####-<slug>.md`
> (Feld `status`) – dieses Log ist nur die lesbare Zusammenfassung über
> alle Tasks hinweg, keine Quelle der Wahrheit für "was ist als Nächstes
> offen" (das ermittelt der Orchestrator direkt aus `../tasks/`).

## Verlauf

<!--
Ein Eintrag pro abgeschlossenem (oder fehlgeschlagenem) Task, kurz:

### TASK-0001 – <Titel>
- Status: done | failed
- Ergebnis: welche Dateien geändert, Testergebnis
- Notizen: Annahmen/Abweichungen, falls welche nötig waren und warum
-->
