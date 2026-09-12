# Architecture: <Projektname>

> Dauerhaftes Produktwissen (siehe `tools/agent-workflow/AGENT_WORKFLOW.md`,
> Abschnitt "Dateistruktur") – beschreibt, **welche Komponente heute wofür
> zuständig ist**, nicht wie/wann sie entstanden ist. Anders als
> `../state/IMPLEMENTATION_PLAN.md` gibt es hier keine Historie: veraltete
> Abschnitte werden ersetzt, nicht als "Nachtrag" angehängt.

> Noch nicht ausgefüllt.
>
> - **Greenfield**: bleibt zunächst leer und wird vom Implementer als Teil
>   jedes Tasks ergänzt, sobald eine Komponente entsteht oder sich ihre
>   Verantwortung/Schnittstelle ändert (siehe `.agent/agents/implementer.md`).
> - **Brownfield**: wird einmalig vom Reviewer im **Map-Modus** aus dem
>   bestehenden Code erzeugt (siehe `.agent/agents/reviewer.md` und
>   `USERMANUAL.md`, Teil 3), danach wie
>   Greenfield weitergepflegt.

## Komponentenübersicht

<!--
Pro Komponente/Modul ein kurzer Eintrag:

### <Modul/Datei>
- Zuständigkeit: <ein bis zwei Sätze, was diese Komponente tut>
- Schnittstelle: <was andere Komponenten von hier aufrufen/erwarten>
- Abhängigkeiten: <welche anderen Komponenten werden genutzt>
- Invarianten: <was immer gelten muss, damit andere Komponenten sich
  darauf verlassen können, z.B. Datenformat-Garantien>
-->

## Datenformate/Schnittstellen (falls relevant)

<!-- z.B. Dateiformate, Wire-Formate, Konfigurationsschema – nur wenn es
     projektübergreifend genutzt wird und nicht offensichtlich aus einer
     einzelnen Komponente hervorgeht. -->

## Bekannte Abweichungen/Schulden

<!-- Stellen, an denen der Code bewusst (oder nachweislich) vom
     wünschenswerten Zustand abweicht, mit Verweis auf den Report/Task,
     der das dokumentiert hat – kein Ort für neue, unbestätigte Vermutungen. -->
