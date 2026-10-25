# Zielarchitektur (Soll, top-down)

> Teil von `README.md` (Index). Beschreibt, wie das System aufgebaut sein
> **soll** – unabhängig davon, wie weit der Code schon ist. Ändert sich nur
> durch einen bewussten Entscheid des Nutzers: der Architekt schlägt vor
> (Baustein `ZIELARCHITEKTUR`, oder als markierter Vorschlag im
> `ARCHITEKTUR_GATE`), der Nutzer entscheidet. Implementer, Tester und
> Planner lesen diese Datei nur.

> Noch nicht ausgefüllt.

## 1. Systemkontext

<Was ist das System, wer/was liegt ausserhalb (Nutzer, Fremdsysteme,
Laufzeitumgebung), welche Schnittstellen gehen nach aussen?>

## 2. Bausteine und Schichten

<Die grossen Teile und ihre Verantwortung, und welche Richtung
Abhängigkeiten zwischen ihnen haben dürfen. Keine Implementierungsdetails.>

## 3. Architekturregeln

<!--
Nummerierte Regeln, auf die sich Gate, Review und Tasks beziehen können
("verletzt R3"). Eine Regel ist prüfbar formuliert.

Pflicht in jedem Projekt (Vorlage, an das Projekt anpassen):

- **R1 Namenskonvention der Testdateien:**
  `tests/<komponente>[-<aspekt>].test.<ext>`; Tests, die eine
  komponentenübergreifende Zusicherung bewachen, heissen nach dieser
  Zusicherung. Die Komponenten-Einträge in `ist.md` listen **keine**
  Testdateien (solche Listen veralten) – die Konvention macht sie
  auffindbar.

Weitere Beispiele: "Domänenlogik importiert nichts aus ui/", "Jede
Fehlermeldung an den Nutzer kommt aus messages.<ext>".
-->

## 4. Entscheidungen

<!--
Eine Entscheidung je Eintrag, mit Begründung und verworfenen
Alternativen – kurz:

### E1 <Titel> (<Datum>)
- Entscheid: <…>
- Begründung: <…>
- Verworfen: <…, weil …>
-->

## 5. Qualitätsziele

<Die zwei bis fünf Eigenschaften, die bei Zielkonflikten Vorrang haben
(z.B. Sicherheit vor Bequemlichkeit), möglichst mit prüfbarer Grösse.>
