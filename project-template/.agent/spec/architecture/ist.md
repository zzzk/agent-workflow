# Ist-Architektur (bottom-up)

> Teil von `README.md` (Index). Beschreibt, **welche Komponente heute
> wofür zuständig ist** – wie der Code tatsächlich ist, nicht wie er sein
> soll (das steht in `ziel.md`) und nicht wie er entstanden ist.

> Noch nicht ausgefüllt.
>
> - **Greenfield**: bleibt zunächst leer und wird vom Implementer als Teil
>   jedes Tasks ergänzt, sobald eine Komponente entsteht oder sich ihre
>   Verantwortung/Schnittstelle ändert (siehe `.agent/agents/implementer.md`).
> - **Brownfield**: wird einmalig vom Reviewer im Baustein **`MAP`** aus
>   dem bestehenden Code erzeugt (siehe `.agent/agents/reviewer.md` und
>   `USERMANUAL.md`, Teil 3), danach wie Greenfield weitergepflegt.

## Komponentenübersicht

<!--
Pro Komponente/Modul ein kurzer Eintrag (keine Testdateien auflisten –
dafür gibt es die Namenskonvention in ziel.md):

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
