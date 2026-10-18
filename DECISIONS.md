# Entscheidungen und Lehren

Warum der Agent-Workflow so aussieht, wie er aussieht: die Vorfälle, aus
denen die harten Regeln entstanden sind, und die Entwicklungsstufen mit
ihren Begründungen.

> Wer den Workflow **verstehen oder erklären** will, ist in
> `AGENT_WORKFLOW.md` richtig – diese Datei setzt ihn voraus. Sie ist für
> zwei Fälle da: du willst eine Regel ändern und musst wissen, was sie
> verhindert, oder du willst etwas vorschlagen, das schon einmal verworfen
> wurde.

---

## Die Lehren – Belege für die harten Regeln

Jede harte Regel in den Rollen-Dateien geht auf einen konkreten Vorfall
zurück. Das ist kein Schmuck: ein reales Gegenbeispiel steigert bei
schwächeren Modellen die Befolgungsrate spürbar gegenüber einer abstrakten
Anweisung – und beim Erklären gegenüber Menschen ebenso.

| Regel im Workflow | Beleg |
|---|---|
| Berechtigungen vor dem ersten Task klären | Nr. 1 |
| Ein Commit pro verifiziertem Task | Nr. 2 |
| `tests/README.md` + `TEST_OVERVIEW.md` pflegen | Nr. 3 |
| Unabhängiger `REVIEW` nach Abschluss einer Initiative | Nr. 4 |
| Akzeptanzkriterien müssen maschinell prüfbar sein | Nr. 5 |
| `spec/Architecture.md` statt wachsender Plan-Historie | Nr. 6 |
| Strikt sequentiell, nie parallel; mechanische Härtung statt Prosa | Nr. 7 |
| `AUFTRAGSKLAERUNG`, `state/AUFTRAG.md`, Modus `REQUIREMENTS` | Nr. 8 |

Die Gruppierung darunter nennt die Herkunft, nicht die Wichtigkeit.


### Aus Projekt 1: Encrypted-Backup-Tool (v1, abgeschlossen)

1. **Berechtigungen waren der grösste Bremsklotz für "selbständig
   durchlaufen lassen".** Deshalb ein fester Vorbereitungs-Schritt
   (`USERMANUAL.md`, Teil 1): Berechtigungsumfang vor dem ersten Task klären, Sub-Agenten erben
   denselben Modus.
2. **Ohne Versionskontrolle gab es keine nachvollziehbaren
   Zwischenstände.** Deshalb: lokales Git-Repo vor dem ersten Task, ein
   Commit pro vollständig verifiziertem Task.
3. **Tests hatten keine eigene Doku und waren dadurch schwer zu
   überblicken.** `tests/README.md` (wie ausführen) und
   `tests/TEST_OVERVIEW.md` (was wird geprüft, thematisch) bleiben
   Pflichtbestandteil, spätestens nach der letzten Initiative aktualisiert.

### Aus dem Review-Durchlauf nach Projekt 1 (→ v2)

4. **Ein als "done" markierter Schritt war es nicht immer wirklich.** Ein
   nachträgliches Review deckte auf: zwei Schritte fehlten komplett im
   Fortschritts-Log obwohl umgesetzt, ein anderer war als "done" markiert
   obwohl die zugehörigen Tests gar nicht existierten (Exclude-Scan), und
   ein sicherheitsrelevantes Akzeptanzkriterium (Chunk-Reihenfolge über
   AEAD Associated Data) war weder implementiert noch getestet. Ursache:
   kein unabhängiger Prüf-Durchlauf *nach* Abschluss aller Schritte, nur
   der Test-Agent pro Einzelschritt (der naturgemäss nur den je aktuellen
   Schritt kennt, nicht das Gesamtbild). Deshalb die Reviewer-Rolle als
   Pflicht-Bestandteil.
5. **Doku und CLI liefen auseinander, ohne dass es auffiel.** `README.md`
   dokumentierte Befehle/Flags, die die CLI gar nicht kannte. Das
   zugehörige Akzeptanzkriterium ("jede in der Doku erwähnte Option
   existiert in der CLI") wurde nie automatisiert geprüft. Lehre:
   Akzeptanzkriterien, die Doku-Code-Konsistenz verlangen, brauchen einen
   Test, der das tatsächlich vergleicht – nicht nur eine manuelle
   Behauptung im Fortschritts-Log.
6. **Ein einzelnes, ewig wachsendes `IMPLEMENTATION_PLAN.md` behindert
   spätere Wartung.** Für die Kernfrage "was macht Komponente X" musste
   die ganze Bauhistorie durchsucht werden. → `spec/Architecture.md`.

### Aus einem Ausführungs-Versuch mit gpt-oss:120b unter Claude Code (v2)

7. **Gute Planung schützt nicht vor einer Ausführung, die ihr eigenes
   Protokoll ignoriert.** Planner-Output (10 Tasks aus einem Review-Report)
   war exzellent: klein, in sich geschlossen, mit exakten Zeilen-Referenzen
   und prüfbaren Akzeptanzkriterien. Trotzdem landete am Ende ein einziger,
   nicht committeter Diff, der Änderungen aus vier verschiedenen Tasks
   vermischte – kein Task war je auf `in_progress`/`done` gesetzt,
   `state/PROGRESS.md` blieb leer. Vermutliche Ursache: die eingesetzte
   Modell/Harness-Kombination (nicht-Anthropic-Modell unter dem
   Claude-Code-Agenten-Harness) hat die Sub-Agent-Delegation (auf
   Anthropic-Modelle zugeschnitten) nie tatsächlich genutzt, sondern direkt
   im laufenden Kontext editiert – still, ohne die Verletzung des
   Protokolls zu erkennen. Eine der so vermischten Änderungen **löschte**
   dabei bestehende Funktionalität (mtime-Wiederherstellung) ersatzlos,
   statt sie – wie vom Task verlangt – nur zu verschieben; das fiel erst
   beim nächsten Testlauf auf.
   **Konsequenzen (in v3 vollständig umgesetzt):**
   - Für einen Nicht-Anthropic-Unterbau einen providerunabhängigen Harness
     verwenden statt ein auf Claude zugeschnittenes Tooling
     zweckzuentfremden. In v3 verifiziert und schärfer: Claude Code kann
     eine **einzelne** Rolle strukturell nicht auf ein fremdes/lokales
     Modell routen (`HARNESS.md`) – für dieses Ziel ist es nicht suboptimal,
     sondern ungeeignet.
   - Die Regel "strikt sequentiell, nie parallel" steht mit konkretem
     Anti-Beispiel in `orchestrator.md` und `implementer.md`. Ein reales
     Gegenbeispiel steigert bei schwächeren Modellen die Befolgungsrate
     spürbar gegenüber rein abstrakten Anweisungen.
   - `implementer.md` hat einen End-of-Turn-Selbstcheck, der aktiv
     bestätigt werden muss ("nur dieser eine Task, nichts committet, nichts
     ersatzlos gelöscht").
   - **Wo der Harness mechanisch erzwingen kann, wird nicht auf
     Instruktionsbefolgung vertraut** – aus dieser Erkenntnis ist Teil D
     (Mechanische Härtung) in `AGENT_WORKFLOW.md` entstanden: Werkzeug-Allowlists, Pfad-Denies,
     Schritt-Obergrenzen, Diff-basierte Prüfung statt Selbstauskunft.

### Aus dem Betrieb von v3 (→ v3.1)

8. **Ein Versprechen, das die Rollenarchitektur nicht einlösen kann, fällt
   erst im Betrieb auf.** Die Requirements-Vorlage kündigte an, die
   Anforderungen würden "gemeinsam mit dem Nutzer interaktiv erarbeitet
   (siehe `planner.md`)" – der Planner läuft aber als Subagent: ein Prompt
   rein, eine Antwort raus, kein Nutzerkontakt, kein Gedächtnis zwischen
   zwei Aufrufen. Der Versuch endete entweder damit, dass der Orchestrator
   die Klärung stillschweigend selbst übernahm (Rollenbruch, und niemand
   sah es), oder in `BLOCKED`-Ping-Pong, bei dem jede Runde den Kontext der
   vorherigen verlor. Lehre, allgemein: **prüfe jede "interaktive" Zusage
   gegen die Runtime der Rolle, die sie einlösen soll.** Wo ein
   kontextfreier Subagent beteiligt ist, muss der Zustand in einer Datei
   liegen und die Runden vom Orchestrator getaktet werden – die Rolle
   selbst wird nicht gesprächsfähig. Daraus entstanden `AUFTRAGSKLAERUNG`,
   `state/AUFTRAG.md` und der Modus `REQUIREMENTS` (v3.1).

---

## Entwicklungsstufen

Ursprünglich entwickelt für das Encrypted-Backup-Tool-Projekt
(Requirements → Plan → Implementierung), danach in drei Stufen gewachsen:

- **v1** – drei Rollen (Orchestrator/Implementer/Test-Agent), als Prosa
  innerhalb einer einzigen `AGENTS.md` beschrieben.
- **v2** – fünf Rollen mit je eigener Datei, eigener Reviewer-Rolle, und
  Trennung zwischen dauerhaftem Produktwissen (`spec/`) und vergänglichem
  Workflow-Zustand (`state/`).
- **v3** – Drei Änderungen, Begründung unter "Warum v3":
  1. Der feste Ablauf wird durch einen **Baustein-Katalog** ersetzt, aus
     dem der Orchestrator je nach Ausgangslage einen Modus zusammensetzt.
  2. Alle Rollen bekommen einen einheitlichen **Rollen-Vertrag** mit
     maschinell auswertbaren **Verdicts** statt Prosa-Rückmeldung.
  3. Rolle und **Runtime/Modell** werden entkoppelt: eine Rolle kann in
     einem anderen Harness und auf einem anderen (auch lokalen) Modell
     laufen als der Orchestrator.
- **v3.1** – dieser Stand. Zwei Änderungen, Begründung unter "Warum v3.1":
  1. Jede Initiative beginnt mit dem Baustein **`AUFTRAGSKLAERUNG`** beim
     Orchestrator; sein Ergebnis ist die Datei `state/AUFTRAG.md`, aus der
     der Modus abgeleitet wird – nicht mehr aus Dateizustand plus
     Gesprächshistorie.
  2. Das Erarbeiten von Anforderungen wird ein eigener Modus
     **`REQUIREMENTS`** mit rundenbasierter `KLAERUNG`, statt eines
     Vorspiels von `FEATURE`.

---

## Warum v3.1

v3 hat den festen Ablauf durch Bausteine ersetzt – aber der **Einstieg**
blieb der alte. Drei Löcher, die erst im Betrieb sichtbar wurden:

1. **Es gab keinen Schritt "was ist überhaupt der Auftrag".** Der Modus
   wurde aus dem Dateizustand plus einer Chat-Antwort gewählt. War
   `Requirements.md` leer, landete man in `FEATURE` – auch wenn der Nutzer
   gar keine Umsetzung wollte, sondern nur einen Review oder überhaupt
   erst die Anforderungen. `AUDIT` gab es zwar, aber der Einstiegspfad
   führte nicht dorthin.
2. **Alles vor `PLAN` lebte nur in der Gesprächshistorie.** Das
   widerspricht dem Kernprinzip aus Teil A der Methodik ("eine Rolle liest nie die
   volle Gesprächshistorie"): der Planner bekam das Anliegen als Prosa
   gereicht, und bei einem Sessionabbruch war es weg. Mit
   `state/AUFTRAG.md` gilt dieselbe Regel jetzt auch für den Einstieg –
   der Auftrag ist ein Artefakt, kein Chatverlauf.
3. **"Requirements interaktiv erarbeiten" war unmöglich, stand aber als
   Versprechen in der Vorlage.** `Requirements.md` kündigte eine
   thematisch fortschreitende Klärung an, `planner.md` beschrieb eine
   einmalige Fragerunde mit anschliessendem `BLOCKED` – und der Planner
   ist als Subagent strukturell weder gesprächsfähig noch erinnerungsfähig.
   Der Modus `REQUIREMENTS` löst das nicht, indem die Rolle interaktiv
   gemacht wird (das kann sie nicht), sondern indem der Zustand in
   `AUFTRAG.md` liegt und der Orchestrator die Runden taktet.

## Warum v3

v2 war als Struktur richtig, hatte aber drei Schwächen, die erst im
Betrieb sichtbar wurden:

1. **Der Ablauf war implizit eine Pipeline.** Beschrieben war eine
   Hauptschleife für "Anforderung → Tasks → Umsetzung", mit Review als
   Anhängsel. Tatsächlich anfallende Arbeit sieht oft anders aus: ein
   einzelner Bugfix, ein reines Audit, das Auswerten manueller Tests. Der
   Baustein-Katalog (Teil B der Methodik) macht die Zusammensetzung explizit, statt
   jeden Sonderfall als Abweichung von der einen Schleife zu behandeln.
2. **Rückmeldungen waren Prosa.** Der Orchestrator musste interpretieren,
   ob eine Rolle zufrieden war – eine Fehlerquelle genau bei den kleinen
   Modellen, für die die Methodik gedacht ist. Verdicts (Teil A) machen
   die Verzweigung greppbar.
3. **Rolle und Modell waren faktisch gekoppelt.** v2 empfahl zwar "für den
   Planner ein stärkeres Modell", ohne Mechanismus dafür. `HARNESS.md` trennt
   die neutrale Rollen-Definition von der harness-spezifischen Zuordnung
   und beschreibt den Aufruf fremder Runtimes.

Zusätzlich neu: die **Architekt**-Rolle (prüft den Plan, bevor Code
entsteht – bis dahin prüfte nur der Reviewer, also erst hinterher), der
**Test-Freeze** (Teil D) und das explizite Überspringen von Bausteinen mit
protokollierter Begründung.

Die Anregung zu Architekt-Rolle, Verdict-Vokabular, einheitlicher
Rollen-Gliederung, Test-Freeze und mechanischer Baustein-Auswahl stammt aus
einem Feature-Workflow-Template eines Kollegen (fixe Phasen-Pipeline für
Android/OpenSpec). Übernommen wurden die Rollen-Verträge und die
mechanischen Ideen; die feste Phasenfolge bewusst nicht.

### Warum die Trennung spec/ ↔ state/ (aus v2, weiterhin gültig)

1. **`IMPLEMENTATION_PLAN.md` als Dauer-Rückgrat funktioniert nur
   Greenfield.** Der Plan ist naturgemäss temporal (Schritt 0, 1, 2, ...)
   und damit fürs *aktuelle* Verständnis eines bestehenden Systems
   ungeeignet – ein neuer (insb. kleiner/lokaler) Agent müsste die ganze
   Baugeschichte lesen, nur um zu erfahren, welche Datei heute wofür
   zuständig ist. `spec/Architecture.md` beantwortet genau das als
   lebendige Momentaufnahme. `state/IMPLEMENTATION_PLAN.md` trägt dadurch
   nur noch die *aktuell laufende* Initiative und wird danach archiviert.
2. **Rollen nur als Prosa in `AGENTS.md` verwischen Zuständigkeiten**,
   sobald mehr als "bauen" ansteht. Jede Rolle hat eine eigene Datei, und
   ein **Task** (nicht ein Plan-Schritt) ist die einheitliche
   Ausführungseinheit – egal ob er aus einer Anforderung oder einem
   Review-Finding stammt.
