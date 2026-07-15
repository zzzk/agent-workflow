# Implementation Plan (Anweisung für den Bau-Agenten)

Dieses Dokument ist **keine funktionale Anforderung** (siehe dafür
`Requirements.md`, im selben `.agent/`-Ordner), sondern die Bauanleitung für
den Agenten, der das Tool implementiert. Ziel: ein günstiges/kleines Modell
kann die Umsetzung vollständig selbständig durchführen, weil jeder Schritt
klein, klar abgegrenzt und unabhängig testbar ist.

> Das zugrundeliegende Vorgehen (Orchestrator + Implementer-Agent +
> unabhängiger Test-Agent, kleine Schritte, `PROGRESS.md` als
> Übergabe-Datei) ist als generische, projektunabhängige Vorlage abgelegt
> unter `tools/agent-workflow/AGENT_WORKFLOW.md`. Nach Abschluss dieses
> Projekts sollen dort Lessons Learned ergänzt werden.

## Orchestrierung & Token-Sparen

Damit nicht bei jedem Schritt die komplette bisherige Historie erneut
mitgegeben werden muss (unnötiger Tokenverbrauch), läuft die Umsetzung über
eine dritte Rolle:

- **Orchestrator**: die Instanz, die pro Schritt jeweils einen frischen
  Implementer-Sub-Agenten und danach einen frischen Test-Sub-Agenten
  startet. Der Orchestrator selbst braucht kein grosses Kontextfenster – er
  liest nur `PROGRESS.md`, ermittelt daraus den nächsten offenen Schritt,
  und startet die Sub-Agents mit einem knappen, gezielten Auftrag.

- **`PROGRESS.md`** ist die Übergabe-Datei zwischen den Schritten: aktueller
  Schritt, Status (offen/erledigt/fehlgeschlagen), was der
  Implementer-Agent gebaut hat, ob die Tests grün waren, sowie kurze
  Notizen für die nachfolgenden Schritte (z.B. Annahmen oder kleine,
  begründete Abweichungen vom Plan). Jeder neue Sub-Agent liest **nur**:
  1. `Requirements.md` (funktionale Anforderungen, ändert sich nicht),
  2. `IMPLEMENTATION_PLAN.md`, aber nur den Abschnitt des aktuellen
     Schrittes,
  3. `PROGRESS.md` (Kurzstand + Notizen aus vorherigen Schritten),
  4. den bereits vorhandenen Code selbst (statt einer Beschreibung davon).

  Damit trägt kein Sub-Agent die volle Konversation von Schritt 0 mit sich
  herum – der nötige Kontext steht kompakt in `PROGRESS.md` und im Code
  selbst.

## Rollen & Workflow

Zwei Rollen pro Schritt, unabhängig voneinander:

1. **Implementer-Agent**: setzt genau einen Schritt aus der Liste unten um
   (Code + ggf. minimale Doku), nichts darüber hinaus.
2. **Test-Agent**: unabhängige Session/Kontext, kennt nur die
   **Akzeptanzkriterien** des Schrittes (nicht den Implementierungs-Code im
   Detail), schreibt dazu Tests und führt sie aus.

Ablauf pro Schritt:

1. Implementer-Agent setzt den Schritt um.
2. Test-Agent schreibt/ergänzt Tests gemäss Akzeptanzkriterien und führt die
   gesamte Testsuite aus.
3. Schlagen Tests fehl → zurück an Implementer-Agent mit den
   fehlgeschlagenen Tests als Kontext, Korrektur, erneut testen.
4. Erst wenn alle Tests eines Schrittes grün sind, wird der nächste Schritt
   begonnen. Kein Schritt darf begonnen werden, solange der vorherige nicht
   vollständig grün ist.

Regeln für beide Rollen:

- Ein Schritt betrifft **maximal 1–2 Dateien/Module**. Ist ein Schritt
  grösser, wird er weiter unterteilt statt in einem Rutsch umgesetzt.
- Jeder Schritt muss **ohne Kenntnis späterer Schritte** umsetzbar sein
  (keine Vorgriffe auf noch nicht spezifizierte Interfaces).
- Beide Rollen arbeiten ausschliesslich innerhalb der projektlokalen
  virtuellen Umgebung/dem projektlokalen Toolchain-Setup (siehe Schritt 0).
  Neue/aktualisierte Abhängigkeiten werden vom Implementer-Agenten sofort
  installiert – der Test-Agent muss nichts manuell nachinstallieren.

## Schritte

### Schritt 0 – Projekt-Grundgerüst
- **Deliverable**: <Sprache/Framework wählen, Package-/Projektstruktur,
  Dependency-Management, Test-Runner eingerichtet, virtuelle
  Umgebung/Toolchain angelegt und Abhängigkeiten installiert.>
- **Akzeptanzkriterien**:
  - <Testlauf funktioniert (auch mit 0 echten Tests).>
  - <Minimaler Programm-/CLI-Aufruf funktioniert.>

<!-- Weitere Schritte hier ergänzen, jeweils mit Deliverable + Akzeptanzkriterien,
     nach demselben Muster wie Schritt 0. -->

## Hinweis zu Nachträgen

Werden während der Umsetzung neue Anforderungen entdeckt (z.B. reale
Nutzung deckt ein bisher unbedachtes Problem auf), werden sie zuerst in
`Requirements.md` nachgetragen (mit Begründung) und dann hier als neue,
nummerierte Schritte ergänzt – nicht stillschweigend in einen bestehenden
Schritt gemischt.
