# Architektur: <Projektname>

> Dauerhaftes Produktwissen. Keine Historie: veraltete Abschnitte werden
> ersetzt, nicht als "Nachtrag" angehängt.

**Diese Datei ist der Index.** Sie bleibt klein und wird von jeder Rolle
gelesen, die Architektur braucht; danach liest eine Rolle nur die
Kapiteldateien, die ihr Auftrag berührt.

Die Architektur hat zwei Teile mit verschiedenen Besitzern:

| Kapitel | Sicht | Inhalt | Wer schreibt |
|---|---|---|---|
| [`ziel.md`](ziel.md) | **top-down, Soll** | Systemkontext, Bausteine/Schichten, Architekturregeln, Entscheidungen, Qualitätsziele | Architekt schlägt vor (Baustein `ZIELARCHITEKTUR`), der **Nutzer entscheidet**; alle anderen Rollen lesen nur |
| [`ist.md`](ist.md) | **bottom-up, Ist** | Komponenten, wie sie heute im Code sind: Zuständigkeit, Schnittstelle, Abhängigkeiten, Invarianten | Reviewer (Baustein `MAP`), danach der Implementer je Task |
| [`abweichungen.md`](abweichungen.md) | Lücke Soll ↔ Ist | bewusst akzeptierte Abweichungen/Schulden mit Beleg | nur nach Nutzerentscheid: Orchestrator (Kandidaten aus Reports) bzw. Architekt (`ZIELARCHITEKTUR` b) |

Wie die Teile zusammenspielen: Das `ARCHITEKTUR_GATE` prüft einen Plan
gegen `ziel.md`; der `REVIEW` prüft das Ist gegen das Soll – jede
Abweichung ist ein Finding, ausser sie steht in `abweichungen.md`.

## Ausgelagerte Kapitel

<!--
Wird ein Kapitel grösser als etwa 30 KB, wird sein grösster
eigenständiger Teil ausgelagert (z.B. eine Komponente nach
`komponenten/<name>.md`) und hier eingetragen, je ein Satz:

- [`komponenten/sync.md`](komponenten/sync.md) – Synchronisations-Komponente (aus ist.md)
-->
