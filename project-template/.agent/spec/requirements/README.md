# Requirements: <Projektname>

> Dauerhaftes Produktwissen (siehe `tools/agent-workflow/AGENT_WORKFLOW.md`,
> Teil E "Dateistruktur") – beschreibt nur die funktionalen Anforderungen,
> keine Bauanleitung und keinen Workflow-Zustand. Für die aktuell laufende
> Initiative siehe `../../state/IMPLEMENTATION_PLAN.md`, für das Teilstück,
> das der Nutzer gerade braucht, `../../state/AUFTRAG.md`, für die
> Architektur `../architecture/README.md`.

> Noch nicht ausgefüllt. Wird in einem Auftrag vom Typ `REQUIREMENTS`
> erarbeitet: der Orchestrator führt das Gespräch mit dem Nutzer, der
> Planner (Baustein `KLAERUNG`) liefert je Runde die Fragen und formuliert
> die Antworten aus – ein Thema nach dem anderen, Protokoll in
> `../../state/AUFTRAG.md`. NICHT vom Agenten allein vorwegnehmen und
> nicht aus dem Code raten.

**Diese Datei ist der Index.** Sie bleibt klein und wird von jeder Rolle
gelesen, die Anforderungen braucht; die Anforderungen selbst stehen in
Kapiteldateien daneben (`<bereich>.md`, z.B. `bedienung.md`,
`datenformat.md`). Eine Rolle liest den Index und danach nur die Kapitel,
die ihr Auftrag berührt.

Wird eine Kapiteldatei grösser als etwa 30 KB, wird ihr grösster
eigenständiger Teil in eine eigene Kapiteldatei ausgelagert und hier
eingetragen (der Orchestrator prüft das beim Abschluss jeder Initiative).

## 1. Kontext & Ziel

<Was soll das Tool/Projekt lösen, für wen, warum? Zwei bis fünf Sätze.>

## 2. Nicht-Ziele (bewusst ausgeklammert)

<Was bewusst NICHT gebaut wird – inkl. "später möglich"-Vermerke mit
Begründung, falls relevant.>

## 3. Stufen

<!--
Nur nötig, wenn die Anforderungen über mehrere Umsetzungsaufträge verteilt
werden (z.B. erst Stufe 1 in Produktion, dann Stufe 2). Dann trägt jedes
Kapitel – oder jeder Abschnitt darin – seine Stufe, damit der Planner ohne
Auslegung abgrenzen kann, was in den aktuellen Auftrag gehört.

| Stufe | Inhalt in einem Satz | Kapitel |
|---|---|---|
| 1 | <…> | bedienung.md, datenformat.md |
| 2 | <…> | bedienung.md (Abschnitt 4), export.md |
-->

## 4. Kapitel

<!--
Ein Eintrag je Kapiteldatei, je ein bis zwei Sätze, was darin steht:

- [`bedienung.md`](bedienung.md) – <Inhalt in einem Satz> (Stufe 1)
- [`datenformat.md`](datenformat.md) – <Inhalt in einem Satz> (Stufe 1)
-->
