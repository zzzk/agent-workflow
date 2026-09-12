# Auftrag – aktuell laufendes Anliegen

> Workflow-Zustand (siehe `tools/agent-workflow/AGENT_WORKFLOW.md`,
> Abschnitt "Dateistruktur"), **kein** dauerhaftes Produktwissen – dafür
> siehe `../spec/Requirements.md` (was das Produkt insgesamt können soll).
> Faustregel: `Requirements.md` beschreibt das Produkt, diese Datei das
> Teilstück, das der Nutzer *jetzt* braucht.
>
> Vom Orchestrator im Baustein `AUFTRAGSKLAERUNG` gemeinsam mit dem Nutzer
> befüllt, **bevor** irgendein anderer Baustein startet. Alle nachfolgenden
> Rollen lesen diese Datei statt der Gesprächshistorie – was hier nicht
> steht, existiert für sie nicht.
>
> Enthält nur den **einen** Auftrag, der gerade läuft. Nach Abschluss nach
> `../history/<datum>-<slug>-auftrag.md` verschieben und diese Datei auf
> die Vorlage zurücksetzen.

> Noch kein Auftrag aktiv.

## Anliegen

<Was der Nutzer will, in seinen Worten. Nicht umgedeutet, nicht schon
gelöst.>

## Art der Arbeit

<Genau ein Modus: REQUIREMENTS | FEATURE | FIX | AUDIT | MANUELLER-TEST |
EINZELAUFTRAG | BOOTSTRAP – plus ein Satz, warum dieser und nicht ein
naheliegender anderer.>

## Umfang

- **Drin**: <was zu diesem Auftrag gehört>
- **Draussen**: <was ausdrücklich nicht dazugehört, obwohl es naheliegt>

## Erfolgskriterium

<Woran der Nutzer erkennt, dass der Auftrag erledigt ist. Prüfbar – nie
"funktioniert gut".>

## Ausgangsmaterial

<Worauf aufgesetzt wird: Abschnitt in `../spec/Requirements.md`, Report
unter `../reports/`, Material in `../inbox/`, ein Ticket – oder
ausdrücklich "nichts".>

## Klärungsprotokoll

<!--
Nur befüllt, wenn tatsächlich gefragt werden musste. Eine Runde pro Block,
damit ein frisch gestarteter Subagent den Stand aus dieser Datei
rekonstruieren kann statt aus der Gesprächshistorie (die er nie sieht):

### Runde 1 – <Thema>
- **F**: <Frage, mit einem Satz beantwortbar>
  **Warum**: <was je nach Antwort anders geplant würde>
  **Vorschlag**: <Default, den der Nutzer nur bestätigen muss>
  **A**: <Antwort des Nutzers – vom Orchestrator nachgetragen>
-->

## Offene Punkte

<Was bewusst offen bleibt, und bis wann es spätestens entschieden sein
muss. Leer heisst leer.>
