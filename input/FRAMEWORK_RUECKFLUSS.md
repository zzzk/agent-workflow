# Rückfluss ins Framework (`tools/agent-workflow/`)

Was in diesem Projekt an Rollen, Vorlagen und Regeln angepasst wurde und am
Schluss der Initiative in das wiederverwendbare Framework zurückfliessen
soll (Nutzerwunsch 2026-10-02). Hier nur sammeln, nicht im Framework selbst
ändern (`tools/agent-workflow/` liegt ausserhalb der Sandbox). Details und
Belege: `PROGRESS.md` (Retro-Punkte), `AUFTRAG.md` (Runden).

## Grundsatz (für alle Rollen vormerken)

**Grundregel ohne Zusatzaufwand, bei Problemen genauer hinschauen.** Die
erhöhte Prüftiefe wird nicht immer bezahlt, sondern erst ausgelöst, wenn ein
Lauf gescheitert ist. Die Information darüber reist als Abschnitt
"Vorgeschichte" in der Task-Datei (Schnittstelle zwischen kontextfreien
Aufrufen). Bisher nur beim Tester umgesetzt; für andere Rollen prüfen, wo
dieselbe Eskalation passt (z.B. Architekt bei wiederholtem Scheitern am
selben Gate-Punkt, Planner beim Neuschnitt).

## Rollen und Vorlagen – geändert

| # | Datei | Änderung | Datum, Anlass |
|---|---|---|---|
| R1 | `.agent/agents/tester.md` | Abschnitt "Grün-Probe – nur bei Vorgeschichte": Erfüllbarkeit der Tests per Wegwerf-Implementierung unter `/tmp` nachweisen, Code nicht weitergeben; unerfüllbarer eingefrorener Test → `BLOCKED` | 2026-10-02, TASK-0014.1 (unerfüllbarer Test 7 kostete einen 90-min-Lauf und einen Neuschnitt) |
| R2 | `.agent/agents/orchestrator.md` | Schritt 8.7: Vorgeschichte nach gescheitertem Lauf in die Task-Datei (auch in Teil-Tasks); nach Timeout zuerst Grün-Probe, dann Neuschnitt | 2026-10-02, wie R1 |
| R2a | `.agent/agents/orchestrator.md` | Schritt 8.7 präzisiert: nach Timeout + Grün-Probe nur schneiden, wenn nötig – inhaltliches Problem (unerfüllbarer Test, Widerspruch zu Vorgabe) → Nutzerentscheid, dann derselbe Task mit nächstem Versuch; Neuschnitt nur bei erfüllbaren Tests (Task zu gross) | 2026-10-03, TASK-0014.4 (Test 1 widersprach Gate-Vorgabe; rückblickend auch TASK-0014.1 kein Schnitt nötig) |
| R3 | `.agent/tasks/TEMPLATE.md` | Abschnitt "Vorgeschichte" | 2026-10-02, wie R1 |
| R4 | `.agent/tasks/TEMPLATE.md` | Status `superseded` + `superseded_by` | 2026-09-29, Neuschnitt TASK-0010 (Retro-Punkt 16) |
| R6 | `.agent/agents/planner.md` | Task-Niveau "Auftrag für normalen Entwickler": keine Fakten inline, kein vorgekauter Code/Text; `Architecture.md` als Landkarte, Code nur ausnahmsweise; Bedarf an Code-Lesen zum Finden = Doku-Befund | 2026-10-12, Nutzerentscheid nach Durchsicht TASK-0034/0039/0043/0061/0067 |
| R5 | `.agent/agents/orchestrator.md` | Vorflug-Check, Wrapper `run-role.sh`, HALTED-Regel, runtime/model_tier (Mischbetrieb lokal/Cloud) | 2026-09-25, Commit f9e3fa3 – Rückfluss-Status unklar, prüfen |

## Regeln und Praxis – noch nicht in Rollen-Dateien

- **Neuschnitt-Muster** (Teil-Tasks `.N`, eingefrorene Tests wörtlich aus `.agent/tasks/reference/` verteilen, per `diff` belegt; Architecture-Eintrag als eigener Teil-Task). TASK-0010, -0012, -0013..0017, -0014.1.
- **Stehende Regel lokaler Timeout → Neuschnitt** (AUFTRAG Runde 10), ergänzt um Grün-Probe davor (R2) und "nur schneiden, wenn nötig" (R2a).
- **Task-Zuschnitt für lokale Modelle:** nicht nur Dateizahl (1 Produkt + 1 Test), sondern eine Verhaltensfacette pro Task; Schnittstellen inline; "lies nur …".
- **`not ok` zählt als Fehlschlag**, auch bei `# fail 0` (Retro 14).
- **Verdict-Zeile:** lokale Läufe liefern sie oft nicht; Regel "fehlt → zurück an dieselbe Rolle" vs. Praxis (Wertung über Dateien/Tests + unabhängige VERIFIKATION) klären.
- **Vorflug-Check um `context_length` aus `/api/ps` ergänzen** (zweimal verfehlt: TASK-0003, Lauf 2026-09-30 21:29Z nach OS-Update); doppelter Ollama-Server (App vs. Terminal).
- **Freeze ohne Commits** (Sandbox, `.git` read-only): sha256-Snapshots aller Dateien unter `tests/` und `extension/` per `find` (nicht per Glob – manifest.json fehlte einmal).
- **Wackelige Tests:** asynchrone Ergebnisse bedingt abwarten (`waitUntil`), keine festen Ticks (TASK-0028/0029).
- **Messdaten-Export** (`.agent/runs/export.sh`) vor jedem Compact und am Ende.
- **Monitor-Skript** gehört als Werkzeug ins Framework (Retro 7).
- **Exit-3-Tabelle** (welche Ursache → Stopp/Rückfrage vs. Neuschnitt).

## Begriffe und Lücken – als Fix fürs Framework vorgemerkt (Nutzer, 2026-10-03)

Nicht an der laufenden Initiative ändern; erst beim Rückfluss umsetzen.

- **"Modus" → "Auftragstyp"**, dazu **"Ablauf"** für die Bausteinfolge je Typ (Begriffe: Auftrag – Auftragstyp – Ablauf – Baustein – Verdict). Betrifft `orchestrator.md` (Schritt 3 u.a.), `planner.md`, `AGENT_WORKFLOW.md`, `MEMORY.md`. Im Bericht bereits so verwendet.
- **Einschub-Tasks innerhalb eines Auftrags** ausdrücklich erlauben (mit Protokoll in `AUFTRAG.md`/`PROGRESS.md`), statt jeden kleinen Einschub als eigenen Auftrag zu führen. Anlass: TASK-0028/0029/0030 wurden als "EINZELAUFTRAG" bezeichnet, aber in den laufenden FEATURE-Auftrag eingeschoben – entgegen "notieren, nicht anhängen" (orchestrator.md Schritt 3).
- **Neuer Reviewer-Baustein `SPEC_REVIEW` (Anforderungsprüfung)** im Ablauf von `FEATURE` und `REQUIREMENTS`: `KLAERUNG` → `SPEC_REVIEW` → (Befunde → `KLAERUNG`-Fragerunde) → `PLAN`. Einmal pro Initiative. Der Reviewer prüft `Requirements.md` auf Vollständigkeit, Widerspruchsfreiheit und Prüfbarkeit (u.a.: jede Anforderung mit prüfbarem Kriterium, alle sichtbaren Texte festgelegt, Fehlerverhalten je Aktion festgelegt, kein Widerspruch zu Architektur/R-Regeln) und liefert **Befunde, keine Fragen**; die Fragen formuliert der Planner mit Vorschlag als Default. Begründung: unabhängiges Auge statt Selbstprüfung ("Selbstauskunft wird nicht geglaubt"). Anlass: AUFTRAG Runden 8, 11, 12 – Anforderungslücken, die erst Tester/Architekt/Planner-Neuschnitt während der Umsetzung fanden. Im Bericht (Teil A) als Vorschlag gezeigt, getrennt vom heutigen Ablauf.
- **Planner-Bezeichnung**: Rolle bleibt "Planner", in Dokumentation/Bild als "Planner (Anforderungen und Planung)" bezeichnen – beide Bausteine `KLAERUNG` und `PLAN` bleiben in einer Rolle.
- **Dokumentations-Tasks: Fakten inline mitgeben.** Bei Architektur-/Doku-Einträgen trägt der Planner die nötigen Fakten aus dem Code (Exporte, Importzeilen, Verwendungsstellen mit Zeilen, Einfügeanker) direkt in die Task-Datei ein. Beleg: TASK-0015.3 V1 sammelte ~70 min selbst und lief in den Timeout; nach Neuschnitt mit Fakten inline schrieb TASK-0015.3.1 den Eintrag nach ~15 min (1227 s gesamt). Ähnlich TASK-0014.6 (4262 s, ~30 min Denkphase am Stück).
  - **ENTSCHIEDEN 2026-10-12 (Nutzer): keine Fakten inline mehr.** Tasks
    werden auf das Niveau "Auftrag für einen normalen Entwickler"
    zurückgebracht: Ziel, Akzeptanzkriterien mit konkreten Werten, bindende
    Schnittstellenvorgaben, Quellenverweise; Wegweiser nur auf
    Komponentenebene, abgeleitet aus `Architecture.md`. Kein fertiger Code,
    keine Ersetzungszeilen, keine vorformulierte Doku. Muss der Planner zum
    Finden der zuständigen Stelle in den Code schauen, ist das ein Befund
    über `Architecture.md`/Dateinamen. Begründung (Nutzer): mit Fakten
    inline leistet der Planner die Arbeit vorab; das verfälscht die
    Messung für die Hardwarebeschaffung, und das Modell soll die Umsetzung
    selbst erarbeiten. Umgesetzt in `.agent/agents/planner.md` (Abschnitte
    "Was du liest" 4–5, "Regeln für Tasks" → Niveau), siehe R6. Anlass:
    Durchsicht von 5 Beispiel-Tasks aus TASK-0034..0070.
    Folgerung (Orchestrator, mit Nutzer abgestimmt): Drift in
    `Architecture.md`, die den *heutigen* Code falsch beschreibt, wird vor
    den Code-Tasks korrigiert, weil die Landkarte sonst nicht trägt; das
    ARCHITEKTUR_GATE gibt nur Schnittstellen/Verantwortungen vor, keine
    Umsetzungsdetails (noch nicht in `architect.md`, vorgemerkt).
  - *Historisch* – **OFFEN – Nutzer entscheidet noch (2026-10-04, später nachfragen):** Variante A = Planner ergänzt kurz vor Taskstart Fakten aus dem aktuellen Code (nur Kontext-Abschnitt, Datei:Zeile, bei Doku keine fertigen Sätze; Tester prüft jede Aussage gegen Code). Variante B (Nutzer: "erscheint mir grundsätzlich sinnvoller") = stärkeres Implementer-Modell, Arbeit nur einmal, kein zusätzlicher Planner-Aufruf. Hintergrund: Tasks wurden zu Beginn ohne Code geschnitten, Fakten konnten damals nicht drinstehen. Vergleichsdaten: Doku-Tasks 0017.5–0020 im Original.
- **Vorflug um GPU-Anteil ergänzen:** nach dem Laden `/api/ps` prüfen, dass `size_vram == size` (100 % GPU) – sonst liegt ein Teil der Schichten auf der CPU und Läufe werden stark verlangsamt. Wert je Lauf protokollieren (Messdaten). Anlass: Nutzerfrage 2026-10-04; Momentaufnahme 14:05Z 100 % bei num_ctx 65536 (17.8 GB), frühere Läufe nicht einzeln belegt. Apple Silicon: GPU darf ab Werk nur ~2/3 des RAM fest belegen (`iogpu.wired_limit_mb`).
- **Timeout-Regel ergänzen (Fall "fast fertig"):** Zeigt die Grün-Probe nach Timeout, dass der Teilstand nahezu vollständig ist (nur wenige, klar benannte Kriterien offen, Tester schätzt Task nicht zu gross), dann Versuch 2 **auf dem Teilstand** mit gezielter Korrekturliste statt Neuschnitt. Anlass: TASK-0020.1 V1 (Timeout, 15/17 Kriterien erfüllt), Nutzerentscheid 2026-10-04. Vorbild Korrekturlauf: TASK-0019.2 V2 (517 s).
  - Sonderfall "Teilstand vollständig": Zeigt die Grün-Probe nach Timeout, dass **alle** Kriterien bereits erfüllt sind (nur npm test/Verdict fehlten), gilt die Grün-Probe als VERIFIKATION und der Task ist done – kein Versuch 2. Anlass: TASK-0020.2 V1 (Timeout 5400 s, Diagramm kurz vor Ende geschrieben, Grün-Probe 19/19 PASS).

## Änderungen und Erkenntnisse 2026-10-11/12 (Initiativen "Requirements v1/v2" und "Stufe 1")

Vom Orchestrator gesammelt auf Wunsch des Nutzers ("alles zurückfliessen
lassen"). Geänderte Rollen-Dateien stehen zusätzlich oben in der Tabelle
(R6). Alles Übrige ist **noch nicht** in `tools/agent-workflow/` bzw. den
Rollen-Dateien umgesetzt.

### Geändert im Projekt (zurückzuführen)

| # | Datei | Änderung | Anlass |
|---|---|---|---|
| K1 | `.agent/agents/planner.md` | = R6: Task-Niveau "Auftrag für normalen Entwickler", `Architecture.md` als Landkarte, Code nur ausnahmsweise, Code-Lesen zum Finden = Doku-Befund | Nutzer nach Durchsicht von 5 Tasks, 2026-10-12 |
| K2 | `.agent/spec/Architecture.md` (Projekt) | R4 um Namenskonvention der Testdateien ergänzen (`tests/<component>[-<aspect>].test.js`, Querschnitts-Wächter nach Zusicherung benannt; Komponenten-Einträge listen keine Testdateien) – als TASK-0037.1 | Landkarten-Befund des Planners beim Neuschnitt; Architekt riet gegen Testlisten je Komponente (veralten), für eine Konvention. **Für das Framework:** Architecture-Vorlage soll eine Test-Namenskonvention verlangen |
| K3 | `.agent/spec/Requirements.md` (Projekt) | Kennzeichnung jedes Abschnitts mit "Stufe 1 / Stufe 2" + Übersicht am Anfang | Nutzerentscheid: Umsetzung in zwei getrennten Aufträgen (erst v1 in Produktion, dann v2). **Für das Framework:** Requirements, die über mehrere Umsetzungsaufträge verteilt werden, tragen eine Stufen-Kennzeichnung, damit der Planner ohne Auslegung abgrenzen kann |
| K4 | `.agent/state/EXPERIMENTE-hardware-lokales-modell.md` | Abschnitt "Fortsetzung 2026-10-12": Testmaterial = neu geschnittene Stufe-1-Tasks, Branch-Plan, Gleichhaltungs-Regeln, offene Entscheidungen, Host-Befehle | Nutzer: keine alten Tasks nachstellen |

### Rollen – vorgemerkt, noch nicht geändert

- **`architect.md`: Gate-Vorgaben nur Schnittstellen und Verantwortungen.**
  Erlaubt: welches Modul wofür zuständig ist, welche Funktion es geben
  muss und ihr Vertrag (Ein-/Ausgabe, Fehlerverhalten), Invarianten,
  betroffene Aufrufer. Nicht: Zeilen-/Reihenfolgeangaben, Code,
  Hilfsfunktions-/Strukturvorschläge. Anlass: erster Gate-Lauf Stufe 1
  (2026-10-12) gab teils Umsetzungsdetails vor; zweiter Lauf mit dieser
  Vorgabe im Auftrag hielt sie ein. Gehört als Regel in die Rolle.
- **`architect.md`: Akzeptanzkriterien auf Wirksamkeit prüfen.** Der
  zweite Gate-Lauf fand ein Kriterium (TASK-0050), das auch ohne
  Code-Änderung grün geworden wäre. Prüffrage ins Gate aufnehmen: "Würde
  der Test ohne die verlangte Änderung rot?"
- **Fragenzahl je Runde vereinheitlichen:** `orchestrator.md` (Schritt 2:
  höchstens **fünf** Fragen) vs. `planner.md` (KLAERUNG (a): höchstens
  **sieben**). Der Planner bezog sich in Runde 3/4 auf "sieben"; der
  Orchestrator gab im Auftrag "fünf" vor. Eine Zahl festlegen.
- **`reviewer.md` (TRIAGE): Referenz ausführen statt nachbauen.** Eine
  Nachbau-Analyse des Prototyps kam zu einer falschen Aussage ("mit Schema
  anders als ohne" war richtig, aber die Zuordnung der Nutzerwerte
  falsch); erst das Ausführen der echten `pwdHash.html` in jsdom klärte
  es. Regel: Bei Abweichungen gegen eine Referenzimplementierung diese
  ausführen, nicht nachbauen.

### Regeln und Praxis – noch nicht in Rollen-Dateien

- **Testvektoren aus dem produktiven Original vor dem Bauen.** Wird ein
  bestehendes Werkzeug abgelöst, gehören echte Ausgabewerte des
  *produktiv genutzten* Originals als Testvektoren in die Spezifikation,
  bevor gebaut wird. Anlass: Die Extension wurde nach einer veralteten
  Kopie von `pwdHash.html` spezifiziert (`paddString` als leerer
  Platzhalter); die Abweichung fiel erst im Browser auf (TRIAGE
  2026-10-11).
- **Drift der Landkarte vor den Code-Tasks korrigieren.** Wenn der
  Planner sich auf `Architecture.md` stützt, muss Drift, die den
  *heutigen* Code falsch beschreibt, zuerst behoben werden (hier
  TASK-0034..0037, 0037.1); was neue Änderungen beschreibt, bleibt nach
  den Code-Tasks.
- **Neuschnitt unbegonnener Tasks in place.** Noch nicht begonnene Tasks
  dürfen direkt überarbeitet und neu nummeriert werden, ohne
  `superseded`-Markierung (Git-Historie genügt). `superseded` bleibt für
  begonnene/teilweise bearbeitete Tasks.
- **Teil-Task-IDs zum Einschieben in die Reihenfolge** (`TASK-0037.1`),
  weil "niedrigste ID zuerst" sonst einen nachträglich angelegten Task
  hinter unabhängige spätere Tasks reiht.
- **Gate-Empfehlung zu `depends_on`:** Der Architekt darf `depends_on`
  nicht ändern; der Orchestrator hat eine Empfehlung (TASK-0046 im ersten
  Schnitt) selbst nachgetragen und vermerkt. Klären, ob das Orchestrator-
  oder Planner-Aufgabe ist.
- **Subagent-Schrittlimit:** Der Planner erreichte beim ersten Schnitt
  (37 Tasks) das Limit von 60 Schritten und wurde per Nachricht
  fortgesetzt. Bei grossen PLAN-Aufträgen mit Fortsetzung rechnen bzw.
  den Auftrag effizient formulieren.
- **Zurückgestellte Review-Findings** werden nicht verworfen, sondern im
  nächsten Umsetzungsauftrag wieder aufgenommen (hier F1–F7, H1–H12 →
  Stufe 1); F1 floss zusätzlich als Anforderung in die Requirements.
- **Klärungsschleife REQUIREMENTS:** lief genau die erlaubten fünf Runden;
  hilfreich waren gebündelte "Kleinentscheide A–H" zum pauschalen
  Bestätigen, nachgerechnete Beispiele mit klar gekennzeichneten
  Beispiel-Geheimnissen, und eine Erklärungsrunde vor den Fragen, wenn der
  Nutzer Verständnisfragen gestellt hat.
- **Experimente/Parallelität:** Für parallele Tasks (Track A) gelten
  eigene Regeln, die "strikt sequentiell" für diesen Branch ersetzen
  müssten: Tasks mit `tests/`-Änderungen in eine Bahn (gemeinsame
  Testsuite und Freeze-Prüfung), gleiche Datei → gleiche Bahn, Doku erst
  nach Übernahme der Code-Tasks, eigenes Arbeitsverzeichnis je Bahn,
  `HALTED` gilt für beide Bahnen. Siehe
  `EXPERIMENTE-hardware-lokales-modell.md`.

## Erkenntnisse Nachtläufe 2026-10-12/13/14 (Experiment 0, Stufe 1)

### Verdict-Zeile des lokalen Implementers (Nutzer, 2026-10-14: vormerken)

Befund aus 14 lokalen Läufen: 12 mit Verdict, aber **nie** als erste
Zeile und in wechselnder Form (`**PASS**`, `## Verdict: PASS`,
`Verdict: **PASS**`, `## PASS`, einmal am Schluss); TASK-0047 lieferte
Selbst-Check/Dateiliste/Annahmen vollständig, aber ohne Verdict;
TASK-0037 V2 endete ganz ohne Schlussmeldung (anderes Fehlerbild). Auch
ein Claude-Tester vergass es einmal, bis der Auftrag es ausdrücklich
verlangte. Die Regel in `implementer.md` ("Erste Zeile: das Verdict.")
ist eindeutig, aber schwach gesetzt: ganz am Ende eines ~100-Zeilen-
Prompts, ohne wörtliches Muster, "erste Zeile" ohne Bezug, keine
mechanische Prüfung.

Vorgemerkt (erst **nach** den Experimenten umsetzen – sonst ändert sich
die Messbedingung mitten in der Messung):
1. `implementer.md` (und sinngemäss alle Rollen): wörtliches Muster für
   den Anfang der **Schlussnachricht**, z.B. `Verdict: PASS`, plus "Ohne
   diese Zeile gilt der Lauf als nicht abgeschlossen."
2. Orchestrator: den Hinweis zusätzlich in den Auftragstext beim Aufruf
   (`run-role.sh … "Setze … um. Schlussnachricht beginnt mit 'Verdict: …'"`)
   – steht damit am Ende des Kontexts statt nur im Rollen-Prompt.
3. `run-role.sh`: mechanische Prüfung, die **nur die letzte Assistenten-
   Nachricht** nach `^Verdict: (PASS|PASS_WITH_NOTES|CHANGES_NEEDED|BLOCKED)`
   durchsucht und ein Fehlen meldet. Bewusst nicht das ganze Log: die
   bestehende `auto-rejecting`-Prüfung auf das ganze Log hat in Nacht 1
   einen Fehlalarm ausgelöst (der Implementer zeigte per `git diff` eine
   PROGRESS-Zeile mit dem Suchbegriff) – dieselbe Einschränkung auch für
   diese Prüfung vormerken.

Übergangsregel für die Experimente (Nutzerentscheid 2026-10-14): fehlt
die Verdict-Zeile, das Deliverable aber nicht, entscheidet die
VERIFIKATION; in der Auswertung getrennt gezählt als "ohne Verdict-Zeile".

### Weitere Befunde (zur späteren Entscheidung)

- **Keine Commits je Task in der Sandbox** (`.git` read-only): `git diff`
  zeigt dem lokalen Modell die Änderungen aller Vortasks; bei TASK-0037
  verwirrte das seinen Selbst-Check. Orchestrator arbeitet mit Snapshots
  im Scratchpad. Lösung offen (z.B. Commit-Schritt auf dem Host je Task,
  oder schreibbares `.git` für den Orchestrator). **Nutzer, 2026-10-14:
  als Frage ins Framework-Update aufnehmen** – Commit pro Task in der
  Sandbox: wer, wie, und gilt die Freeze-Prüfung per Commit oder per
  Snapshot?
- **Implementer pflegt `Architecture.md` bei jeder Vertragsänderung**
  (Regel aus `implementer.md`) und greift damit geplanten Doku-Tasks vor
  (0061–0066). Planner-Regel prüfen: Doku-Nachzug-Tasks nur für das
  planen, was der Implementer laut Rolle *nicht* ohnehin nachzieht.
  **Präzisiert 2026-10-14 (Nacht 3, TASK-0048):** echter Widerspruch
  zwischen drei Regeln: (1) `implementer.md` Vorgehen 3 verlangt den
  Architecture-Nachzug *im selben Task*; (2) `planner.md` verlangt
  `files:` "so eng wie möglich" und nimmt `Architecture.md` nie auf;
  (3) der Orchestrator prüft den Diff gegen `files:`. Folge: jeder
  regelkonforme Implementer-Lauf verletzt formal `files:`, der
  Orchestrator duldet es stillschweigend. Lösungsrichtung: entweder
  Planner nimmt `Architecture.md` in `files:` auf, wenn sich Vertrag/
  Verantwortung ändert (und plant dafür keine separaten Doku-Tasks),
  oder Implementer-Regel 3 entfällt und Doku-Nachzug ist immer eigener
  Task. Bis zum Update: Orchestrator akzeptiert den Absatz, VERIFIKATION
  prüft ihn sachlich.
- **Übersetzungs-Tasks: Umlaut-grep als Kriterium reicht nicht** (Nacht 4,
  2026-10-15, TASK-0056..0059). Drei von vier Tester-Ausführungen brauchten
  einen zweiten Versuch, weil deutsche Wörter ohne Umlaute übersehen wurden
  (ASCII-Umschrift, eingestreute Fachwörter wie "frist", Zitate wie
  "Optionsseite"). Die unabhängige VERIFIKATION hat alle gefunden – das
  Vier-Augen-Prinzip hat getragen. Vorschlag: Planner nimmt in solche Tasks
  eine Wortliste/Prüfregel auf ("auch ASCII-Umschrift und Einzelwörter,
  keine Ausnahme wegen Verwendung in anderen Dateien") und plant den
  Restbestand projektweit (hier: "frist" in 7 weiteren Testdateien offen).
- **Commit-Recht für Agenten mit Wächter statt Verbot** (Nutzer, 2026-10-16,
  aus exp3: Commit-Punkte kosten auf runpod Leerlauf, und ein Tester hat
  bei schreibbarem `.git` selbst committet). Muster, erprobt im Setup für
  exp2 (`runpod-setup-exp2.sh`): `.git` gehört einem eigenen User
  `gitops`; Agenten haben kein Schreibrecht, dürfen aber per `sudo -u gitops
  commit-cp <n>` genau ein root-eigenes Skript aufrufen. Es lehnt ab bei:
  falschem Branch, Task des Commit-Punkts nicht `done`, CP schon committet,
  Pfaden ausserhalb `.agent/ extension/ tests/`, gelöschten oder geleerten
  Dateien, Secret-Mustern, rotem `npm test`, gesunkener Testanzahl; pusht
  nie mit `--force`. Ergänzend: GitHub-Branch-Schutz (kein Force-Push, kein
  Löschen). Für die Sandbox (Docker) übertragbar als Host-seitiger
  Commit-Dienst. Offene Frage fürs Framework: Commit pro Task über denselben
  Wächter – ändert die Sicht des Implementers auf `git diff` (siehe oben).
  **Nachtrag 2026-10-17 (exp2):** Ein Commit-Punkt direkt nach einem
  TEST_FIRST (hier CP1 nach TEST_FIRST von TASK-0038) hat absichtlich rote
  Tests – ein starres "npm test grün" im Wächter blockiert ihn. Lösung:
  rote Tests nur in den Testdateien des betreffenden Tasks (`files:`)
  zulassen, alle anderen müssen grün sein. Allgemeiner fürs Framework:
  Commit-Punkte nicht zwischen TEST_FIRST und UMSETZUNG legen, oder der
  Wächter kennt den Task-Zustand.

## Erkenntnisse 2026-10-15…18 (Experiment 0 Abschluss, exp2/exp3 runpod)

- **Doku-Tasks an grossen Spec-Dateien sind die Schwachstelle des lokalen
  Modells** (64k Kontext). Alle fünf Claude-Fallbacks in Exp 0 (TASK-0060,
  0065, 0066, 0067, 0073) waren Doku-Tasks; Code-Tasks brauchten keinen.
  Muster: das Modell liest Requirements.md (~130 KB) / Architecture.md
  (~75 KB) abschnittsweise, plant korrekt (Todo-Liste vollständig, z.B.
  TASK-0073 V2) und läuft dann in den Timeout, bevor es schreibt.
  Vorschlag Planner: bei Doku-Tasks die betroffenen Abschnitte mit
  Überschrift/Zeilenbereich im Kontext nennen und den Task auf eine
  Datei-Stelle begrenzen; zu prüfen gegen Variante A/B oben (Zeile ~72).
  Zahlen: siehe Bericht über alle Experimente.
- **Still gescheiterte Läufe mechanisch erkennen.** Zwei Fehlerbilder ohne
  Fehlermeldung des Wrappers: (a) exit 0, keine Änderung, keine
  Schlussmeldung – Log endet mitten in der Recherche (TASK-0073 V1, 3068 s);
  (b) exit 1 mit opencode "no user query found in messages" (TASK-0052,
  0063 – Deliverable trotzdem da; früher TASK-0013 bei zu kleinem
  Ollama-Kontext). Vorschlag `run-role.sh`: nach dem Lauf "kein Diff in
  `files:` UND keine Verdict-Zeile" als eigenen Status melden, und
  "no user query" als bekanntes Fehlerbild ausweisen (Hinweis auf
  Kontextlänge prüfen).
- **Implementer liest fremde Task-Dateien** (TASK-0066 V1: las 0037,
  0041–0045), entgegen seiner Rolle. Kein Schaden festgestellt, kostet aber
  Kontext. Regel in `implementer.md` sichtbarer machen oder Lesezugriff
  per opencode-Berechtigung auf die eigene Task-Datei beschränken.
- **Vorflug-Check muss die Kontextlänge prüfen**, nicht nur Erreichbarkeit
  und Modell: `/api/ps` → `context_length` und `size_vram == size`
  (100 % GPU). Auf der RTX 3090 passten 262144/131072 nicht in 24 GB
  (teilweise CPU) – die Angabe "geladen" allein sagt nichts. Für
  LM-Studio-/OpenAI-Endpunkte (Firmen-Server) braucht der Check eine
  zweite Variante (`GET /v1/models` mit API-Key).
- **Betrieb unbeaufsichtigter Läufe:** Session in `tmux` (Mac zusätzlich
  `caffeinate`), und eine **Benachrichtigung aufs Handy**, wenn eine
  Entscheidung ansteht (Commit-Punkt, `BLOCKED`/`HALTED`, Rückfrage) –
  hat dem Nutzer gefehlt. Optionen: Claude-Code-Hook `Notification`/`Stop`
  → `curl` an ntfy (ohne Inhalte, zufälliger Topic-Name); Remote Control
  (Session in der Claude-App, auch antworten); das PushNotification-Tool
  pusht nur bei verbundenem Remote Control und inaktivem Terminal, und nur
  auf ein Handy mit demselben Claude-Konto (hier Firmenkonto – geht beim
  Nutzer aktuell nicht) → kontounabhängig nur der Hook-Weg (ntfy o.ä.).
- **runpod-Setup als Framework-Baustein:** Pods sind Container (kein
  Docker für die Sandbox) → Sandbox nachgebildet mit Usern `agent`/
  `gitops` + `commit-cp` (siehe oben). Stolpersteine: Network Volume
  erlaubt kein `chmod` (Modelle/Repo auf Container-Disk), apt braucht
  `DEBIAN_FRONTEND=noninteractive`, Proxy-SSH ohne scp → `runpodctl
  send/receive`. Skript: `runpod-setup-exp2.sh` (Nutzer verschiebt nach
  `tools/`).
- **Messbetrieb-Block** in `orchestrator.md` (Fallback Versuch 3) nach den
  Experimenten entfernen – oder bewusst als optionalen Betriebsmodus
  ("lokal mit Cloud-Fallback") ins Framework übernehmen; Nutzer entscheidet.
- **Nachtrag Übersetzungs-Tasks (FIX 2026-10-18, TASK-0075/0076):** Auch
  mit Wortliste rutschen Reste durch – Singular statt Plural
  ("Akzeptanzkriterium"), kurze Wörter ("Teil 1"), Workflow-Begriffe
  ("VERIFIKATION" als vermeintlicher Eigenname). Die Wort-für-Wort-
  Durchsicht ist der eigentliche Test, grep nur Hilfe; Wortstämme ohne
  Wortgrenzen statt ganzer Wörter. Die zweite unabhängige VERIFIKATION
  hat jeden Rest gefunden.
