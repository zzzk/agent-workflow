# Vorgehen: Kleine-Schritte-Implementierung mit Orchestrator + Test-Agent

Generische, wiederverwendbare Methode, um ein Software-Vorhaben durch ein
günstiges/kleines Modell selbständig umsetzen zu lassen, ohne dass Qualität
oder Kontrollierbarkeit leiden. Ursprünglich entwickelt für das
Encrypted-Backup-Tool-Projekt (siehe dort `IMPLEMENTATION_PLAN.md` /
`PROGRESS.md` als konkretes Anwendungsbeispiel).

## Wann anwenden

- Das Vorhaben lässt sich in klar abgrenzbare, unabhängig testbare Schritte
  zerlegen (z.B. Module/Funktionen mit klarem Ein-/Ausgabeverhalten).
- Es soll ein kleines/günstiges Modell verwendet werden (begrenztes
  Kontextfenster, geringere Zuverlässigkeit bei grossen Aufgaben am Stück).
- Es gibt bereits klare funktionale Anforderungen (ein separates
  Requirements-Dokument), auf die sich die Schritte stützen können.

## Grundprinzip

Drei Rollen, jede mit eigenem, bewusst begrenztem Kontext:

1. **Orchestrator** – hat den Überblick über den Gesamtfortschritt, startet
   pro Schritt frische Sub-Agents, aktualisiert die Übergabe-Datei
   (`PROGRESS.md`). Braucht selbst kein grosses Kontextfenster, da er nur
   Kurzstände liest/schreibt statt Implementierungsdetails.
2. **Implementer-Agent** – setzt **genau einen** Schritt um, nichts darüber
   hinaus. Kennt weder vorherige noch zukünftige Schritte im Detail.
3. **Test-Agent** – unabhängig vom Implementer-Agent, kennt nur die
   **Akzeptanzkriterien** des Schrittes (nicht die Implementierungs-
   Begründung), schreibt/ergänzt Tests dagegen und führt sie aus. Diese
   Unabhängigkeit ist bewusst: sie verhindert, dass Tests einfach das
   nachvollziehen, was sich der Implementer gedacht hat, statt echt gegen
   die Spezifikation zu prüfen.

Implementer- und Test-Agent interagieren **nie direkt** miteinander – jede
Übergabe läuft über den Orchestrator (bzw. über `PROGRESS.md`, falls der
Orchestrator selbst neu gestartet wird).

## Benötigte Dateien (pro Projekt)

- **`REQUIREMENTS.md`** (projektspezifisch, existiert vermutlich schon):
  funktionale Anforderungen, ändert sich während der Umsetzung nicht.
- **`IMPLEMENTATION_PLAN.md`**: die in kleine Schritte zerlegte Bauanleitung
  (siehe Vorlage unten).
- **`PROGRESS.md`**: die Übergabe-/State-Datei zwischen den Schritten (siehe
  Vorlage unten).
- **`AGENTS.md`**: die Orchestrator-Rolle als Anweisung (tool-unabhängige
  Konvention, u.a. unterstützt von Codex CLI, Cursor u.a.). Für Claude Code
  zusätzlich ein `CLAUDE.md` anlegen, das nur `@AGENTS.md` importiert – so
  wird derselbe Inhalt von beiden Konventionen automatisch geladen, ohne
  Duplikation.
- **`MEMORY.md`** (optional, aber empfohlen): projektspezifische Notizen/
  Kontext direkt im Repo statt im user-globalen Claude-Code-Memory-System.
  Der user-globale Memory-Pfad ist an das lokale Benutzerkonto gebunden und
  reist nicht mit, wenn das Projekt kopiert/geklont wird (z.B. auf einen
  anderen Rechner) – `MEMORY.md` im Repo dagegen schon. Aus `AGENTS.md`
  per `@MEMORY.md` importieren, damit es automatisch geladen wird.
- **`tests/README.md`**: wie die Tests ausgeführt werden (nicht was sie
  prüfen) – Voraussetzungen, ganze Suite vs. einzelne Datei/einzelner Test,
  erwartetes Ergebnis. Tests sind Teil des Ergebnisses, nicht nur ein
  Implementierungsdetail, und brauchen deshalb genau wie das Tool selbst
  eine Nutzungs-Doku.
- **`tests/TEST_OVERVIEW.md`**: strukturierte Zusammenfassung **aller**
  Tests – pro Testdatei: welches Modul/welcher Schritt, Anzahl, Kernszenarien
  (Round-Trips, Negativ-/Fehlerfälle, Edge-Cases). Wird spätestens in
  Schritt 11 (oder direkt nach dem letzten Schritt) aus den in `PROGRESS.md`
  gesammelten Testbeschreibungen pro Schritt zusammengeführt – dort steht
  die Rohinformation bereits, hier wird sie themenweise statt
  chronologisch aufbereitet.

## Vorbereitung (einmalig, vor Schritt 0)

- **Berechtigungen im Voraus klären statt pro Aktion nachfragen.** Wenn der
  Orchestrator und die Sub-Agents bei praktisch jedem Dateizugriff/Bash-Befehl
  einzeln um Erlaubnis fragen müssen, ist "selbständig durchlaufen lassen"
  nicht möglich – der Nutzer muss ständig eingreifen. Deshalb zu Beginn (vor
  Schritt 0) einmal explizit klären/einrichten, in welchem Modus gearbeitet
  wird (z.B. Auto-Accept-Modus für Edits im Projektordner, bzw. eine
  Allowlist für die wiederkehrenden Bash-Befehle wie `pip`, `pytest`, `git`,
  siehe Skill `fewer-permission-prompts`) – in einem für den Nutzer noch
  vertretbaren, aber ausreichend breiten Umfang, damit der gesamte Plan ohne
  wiederholte Rückfragen durchlaufen kann. Sub-Agents erben denselben
  Berechtigungsmodus vom Orchestrator (keine strengere Einstellung für
  Sub-Agents), sonst blockieren sie an derselben Stelle erneut.
- **Lokales Git für nachvollziehbare Zwischenstände.** Vor Schritt 0 prüfen,
  ob im Projektordner bereits ein Git-Repo existiert:
  - Falls nein: `git init` und einen initialen Commit (leeres Grundgerüst
    bzw. die vorhandenen Planungsdateien) erstellen.
  - Falls ja: **beim Nutzer nachfragen**, ob auf dem bestehenden Branch
    weitergearbeitet oder ein neuer Branch für diesen Durchlauf erstellt
    werden soll – nicht automatisch in einen bestehenden Verlauf
    hineincommitten.

## Regeln für die Schrittgrösse

- Ein Schritt betrifft max. 1–2 Dateien/Module.
- Ein Schritt muss ohne Kenntnis späterer Schritte umsetzbar sein (keine
  Vorgriffe auf noch nicht spezifizierte Interfaces).
- Jeder Schritt hat konkrete, prüfbare Akzeptanzkriterien (keine vagen
  Beschreibungen wie "funktioniert gut", sondern harte Bedingungen:
  Round-Trips, Fehlerfälle, Negativ-Tests).
- Abhängigkeiten von externer Hardware/Diensten werden für die Kernschritte
  vermieden bzw. gemockt; Hardware-/Sonderfälle werden als spätere,
  eigenständige Schritte behandelt statt die Kernlogik zu verkomplizieren.

## Ablauf pro Schritt

1. Orchestrator liest `PROGRESS.md` → nächster offener Schritt N.
2. Orchestrator startet Implementer-Sub-Agent: "Setze Schritt N aus
   `IMPLEMENTATION_PLAN.md` um. Kontext: `REQUIREMENTS.md`, `PROGRESS.md`,
   bestehender Code."
3. Orchestrator startet Test-Sub-Agent: "Prüfe Schritt N anhand der
   Akzeptanzkriterien in `IMPLEMENTATION_PLAN.md`. Schreibe/ergänze Tests,
   führe sie aus."
4. Orchestrator aktualisiert `PROGRESS.md` (Status, Testergebnis, Notizen
   für folgende Schritte).
5. Bei Fehlschlag: zurück zu 2, mit den fehlgeschlagenen Tests als
   zusätzlichem Kontext im Auftrag an den Implementer.
6. Bei Erfolg: **Git-Commit** für diesen Schritt (z.B. `Schritt N: <Titel>`
   als Commit-Message), inkl. der aktualisierten `PROGRESS.md`. Erst danach
   nächster Schritt (zurück zu 1). Kein Schritt beginnt, solange der
   vorherige nicht vollständig grün UND committet ist – so bleibt jeder
   Zwischenstand einzeln nachvollziehbar und bei Bedarf einzeln rücksetzbar.
7. Nach dem letzten Schritt: `tests/README.md` und `tests/TEST_OVERVIEW.md`
   erstellen bzw. aus den Testbeschreibungen in `PROGRESS.md` zusammenführen
   (siehe "Benötigte Dateien"), eigener Commit dafür.

## Vorlage: `IMPLEMENTATION_PLAN.md`

```markdown
# Implementation Plan

Keine funktionale Anforderung (siehe dafür `REQUIREMENTS.md`), sondern die
Bauanleitung für den Agenten.

## Rollen & Workflow
[... Beschreibung wie oben, projektspezifisch anpassen ...]

## Schritte

### Schritt 0 – <Titel>
- **Deliverable**: <konkrete Datei(en)/Funktionen>
- **Akzeptanzkriterien**:
  - <prüfbare Bedingung 1>
  - <prüfbare Bedingung 2>

### Schritt 1 – <Titel>
...
```

## Vorlage: `PROGRESS.md`

```markdown
# Progress

> Wird vom Orchestrator nach jedem Schritt aktualisiert. Neue Sub-Agents
> lesen nur diese Datei + REQUIREMENTS.md + IMPLEMENTATION_PLAN.md (den
> jeweiligen Schritt) + bestehenden Code – nicht die volle Historie.

## Aktueller Stand

- Nächster offener Schritt: <N> – <Titel>
- Status: offen | in Arbeit

## Verlauf

### Schritt N – <Titel>
- Status: done | failed
- Implementer-Ergebnis: welche Dateien erstellt/geändert
- Test-Ergebnis: grün/rot, ggf. welche Tests
- Notizen für folgende Schritte: Annahmen, offene Punkte, Abweichungen vom
  Plan (falls welche nötig waren und warum)
```

## Lessons Learned

### Aus Projekt 1: Encrypted-Backup-Tool (abgeschlossen)

1. **Berechtigungen waren der grösste Bremsklotz für "selbständig
   durchlaufen lassen".** Ohne vorherige Klärung des Berechtigungsmodus
   musste laufend bestätigt werden, dass der Agent (und seine Sub-Agents)
   bestimmte Aktionen ausführen dürfen – das widerspricht dem Ziel, den
   Agenten unbeaufsichtigt mehrere Schritte durchlaufen zu lassen. Deshalb
   jetzt als fester Vorbereitungs-Schritt aufgenommen (siehe
   "Vorbereitung"): Berechtigungsumfang vor Schritt 0 einmal explizit und in
   sinnvollem, aber ausreichend breitem Rahmen festlegen – und sicherstellen,
   dass Sub-Agents denselben Berechtigungsmodus erben, statt selbst wieder
   bei jeder Aktion anzustehen.
2. **Ohne Versionskontrolle gab es keine nachvollziehbaren Zwischenstände.**
   Am Ende war nur der Endzustand + die Notizen in `PROGRESS.md` vorhanden,
   aber kein Weg, einzelne fertige Schritte zu vergleichen, zurückzuverfolgen
   oder bei Bedarf gezielt einen einzelnen Schritt zurückzurollen. Deshalb
   jetzt fest im Ablauf verankert: lokales Git-Repo vor Schritt 0 (neu
   anlegen oder – falls schon vorhanden – Branch-Entscheidung mit dem Nutzer
   klären), und ein Commit pro vollständig getestetem Schritt.
3. **Tests hatten keine eigene Doku und waren dadurch schwer zu überblicken.**
   Am Ende gab es 146 Tests über 10 Dateien, aber nur verstreute Notizen in
   `PROGRESS.md` (chronologisch nach Bau-Schritt, nicht nach Thema
   aufbereitet) – kein einziger Ort, um sich einen Überblick zu verschaffen
   oder Tests einfach auszuführen. Tests sind essentiell und verdienen
   dieselbe Sorgfalt wie das Tool selbst. Deshalb jetzt Pflichtbestandteil
   (siehe "Benötigte Dateien"): `tests/README.md` (wie ausführen) und
   `tests/TEST_OVERVIEW.md` (was wird geprüft, thematisch strukturiert,
   nicht nur chronologisch). Beide werden am Ende erstellt/aktualisiert
   (spätestens nach dem letzten Schritt), `tests/README.md` verweist dabei
   auf `tests/TEST_OVERVIEW.md`.
