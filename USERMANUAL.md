# Benutzerhandbuch: Agent-Workflow einrichten und betreiben

Für den **Menschen**, der ein Projekt mit dieser Methodik bearbeiten will.
Es beantwortet drei Fragen: was muss ich einmalig entscheiden, wo trage ich
das ein, und wie starte ich ein Projekt – neu oder bestehend.

Die Methodik selbst (warum es so aufgebaut ist, welche Rolle was tut) steht
in `AGENT_WORKFLOW.md`. Dieses Handbuch setzt sie voraus und bleibt
praktisch.

---

> **Andere Fragen, andere Datei:** wie der Workflow funktioniert und warum
> – `AGENT_WORKFLOW.md` (mit Diagrammen); welcher Harness was kann und wie
> Rollen auf anderen/lokalen Modellen laufen – `HARNESS.md`; warum eine
> Regel existiert – `DECISIONS.md`.

## In 60 Sekunden

Du kopierst `project-template/` in dein Projekt, füllst zwei Dateien aus
(**Testpfade** und **Modellwahl**), führst einmal ein Python-Skript aus,
startest den Agenten und sagst ihm, was du willst. Ab da fragt er dich nur
noch bei Entscheidungen, die wirklich dir gehören.

```bash
cp -r /pfad/zu/tools/agent-workflow/project-template/. /pfad/zu/meinem-projekt/
cd /pfad/zu/meinem-projekt
$EDITOR .agent/agents/implementer.meta.yml   # Testpfade anpassen (Pflicht)
$EDITOR .agent/agents/tester.meta.yml        # dieselben Pfade spiegeln
$EDITOR .agent/agents/_tiers.yml             # Modelle je Stufe (optional)
python3 .agent/sync-agents.py                # Adapter erzeugen
git init && git add -A && git commit -m "Agent-Workflow eingerichtet"
claude                                       # oder: opencode
```

---

## Voraussetzungen

| Was | Wofür | Pflicht? |
|---|---|---|
| Git | Ein Commit pro verifiziertem Task; der Orchestrator prüft Diffs | ja |
| Python 3 (≥ 3.8) | Der Generator `sync-agents.py` (keine Pakete nötig) | ja |
| Claude Code | Der Orchestrator und die Rollen im Anthropic-Ökosystem | eines von beiden |
| OpenCode | Nötig, sobald einzelne Rollen auf anderen/lokalen Modellen laufen sollen (`npm i -g opencode-ai`; im Sandbox-Image enthalten) | optional |
| Ollama / LM Studio | Lokale Modelle bereitstellen. Läuft auf dem **Host**, nie in der Sandbox (GPU) – und muss dafuer mit `OLLAMA_HOST=0.0.0.0` starten | nur bei lokalem Betrieb |
| Docker | Die Sandbox aus `sandbox/` | optional, empfohlen |

---

## Teil 1 – Was du entscheiden musst, und wo

Das ist der Kern dieses Handbuchs. Alles andere ergibt sich daraus.

| # | Entscheidung | Datei | Wann | Pflicht? |
|---|---|---|---|---|
| 1 | **Wo liegen die Tests?** | `.agent/agents/implementer.meta.yml` + `tester.meta.yml` | einmal pro Projekt | **ja** |
| 2 | **Welche Rolle auf welchem Modell?** | `.agent/agents/_tiers.yml` | einmal, dann bei Bedarf | nein (Standard funktioniert) |
| 3 | **Lokale Modelle verfügbar machen** | `$OLLAMA_BASE_URL` (Datei `opencode.json` liegt bereit) | nur bei lokalem Betrieb | nein |
| 4 | **Was soll das Produkt können?** | `.agent/spec/Requirements.md` | vor der ersten Initiative | ja (notfalls im Dialog) |
| 5 | **Berechtigungsmodus** | `.claude/settings.json` bzw. OpenCode-`permission` | einmal, vor dem ersten Task | faktisch ja |
| 6 | Schreibrechte / Schritt-Limit einer Rolle | `.agent/agents/<rolle>.meta.yml` | selten | nein |
| 7 | Welcher Runtime für **einen** Task | `runtime:` im Task-Frontmatter | pro Task | nein |

### 1. Testpfade – die einzige echte Pflichtanpassung

Der **Test-Freeze** ist das schärfste Qualitätsinstrument der Methodik:
Tests entstehen vor der Implementierung, und der Implementer darf sie nicht
anfassen. Das funktioniert nur, wenn beide Rollen wissen, welche Dateien
Tests sind. Die Vorgabe im Template ist geraten und passt fast nie exakt.

```yaml
# .agent/agents/implementer.meta.yml   → was er NICHT ändern darf
path_denies: ["tests/**", "**/test_*.py"]

# .agent/agents/tester.meta.yml        → was er ALS EINZIGES ändern darf
path_allows: ["tests/**", "**/test_*.py", ".agent/tasks/**"]
```

Die beiden Listen sind **Spiegelbilder**. Vergisst du das, greift der
Freeze ins Leere – ohne Fehlermeldung. Beispiele: Android
`app/src/test/**`, `app/src/androidTest/**` · JS/TS `**/*.spec.ts`,
`**/*.test.tsx`, `__tests__/**` · Go `**/*_test.go` · Java/Kotlin
`src/test/**`.

> `.agent/tasks/**` bleibt beim Tester immer in `path_allows` – er trägt
> seine Test-Notizen in die Task-Datei ein.

### 2. Modellwahl – genau eine Datei

`.agent/agents/_tiers.yml` ist der **einzige** Ort, an dem steht, welche
Stufe auf welchem konkreten Modell landet. Die Rollen-Dateien nennen nur
`strong`, `standard` oder `cheap` und bleiben dadurch anbieterneutral.

```yaml
claude:                    # Claude Code: nur Anthropic-Modelle möglich
  strong: opus
  standard: sonnet
  cheap: haiku

opencode:                  # OpenCode: beliebig, auch lokal, auch gemischt
  strong: anthropic/claude-opus-5      # Notausgang, braucht API-Key
  standard: ollama/qwen3.8:27b         # Implementer, Tester – lokal
  cheap: ollama/qwen3.5:latest
```

Welche Rolle welche Stufe hat, steht in `<rolle>.meta.yml`. Standard:

| Stufe | Rollen | Warum |
|---|---|---|
| `strong` | Planner, Architekt, Reviewer | Denkarbeit: zerlegen, beurteilen, Drift erkennen |
| `standard` | Orchestrator, Implementer, Tester | Ausführung entlang einer engen, vollständigen Auftragsdatei |

Willst du günstiger oder lokaler fahren, ändere die **Zuordnung**, nicht
die Rollen: `standard: ollama/qwen3.8:27b`. Der Implementer ist der
beste Kandidat dafür – sein Auftrag ist eng, seine Arbeit wird von einem
unabhängigen Tester geprüft, und Fehler kosten nur einen weiteren Durchlauf.

### 3. Lokale Modelle: nur über OpenCode

**Claude Code kann das nicht.** Es akzeptiert pro Rolle ausschliesslich
Anthropic-Modelle, und eine Umleitung auf einen anderen Anbieter
(`ANTHROPIC_BASE_URL`, Bedrock, Vertex) wirkt immer für die **gesamte**
Session. Ein Mischbetrieb – Planner in der Cloud, Implementer lokal – ist
dort strukturell nicht möglich, nicht bloss unkonfiguriert.

Der Provider wird einmal im Projekt-Root definiert. `opencode.json` liegt
fertig im Template – Ollama, `qwen3.8:27b`, `num_ctx` bereits auf 32k.
Anpassen musst du daran im Normalfall nichts, **eine** Umgebungs-
variable aber schon:

```bash
export OLLAMA_BASE_URL=http://localhost:11434/v1        # Ollama auf dem Host
```

Die Datei liest den Endpunkt über `{env:OLLAMA_BASE_URL}` statt ihn fest zu
verdrahten, weil er nicht überall derselbe ist: **in der Sandbox ist
`localhost` der Container**, nicht dein Rechner. Das Sandbox-Image setzt
die Variable deshalb selbst auf `http://host.docker.internal:11434/v1` –
dort musst du nichts tun. Nur auf dem Host exportierst du sie selbst.

> Ist die Variable nicht gesetzt, ersetzt OpenCode sie durch einen leeren
> String und der erste Aufruf scheitert mit einer wenig sprechenden
> Verbindungsmeldung. Das ist die erste Stelle zum Nachsehen.

> **Ollama muss mit `OLLAMA_HOST=0.0.0.0` gestartet werden.** Per Default
> bindet es nur an `127.0.0.1` und ist damit aus dem Container **nicht**
> erreichbar – auch nicht über `host.docker.internal`, entgegen einer
> verbreiteten Annahme über Docker Desktop. Ein blosses `ollama serve`
> genügt nicht. Das ist der Schritt, der am ehesten vergessen wird, weil
> er ausserhalb der Sandbox und ausserhalb dieses Repos passiert.

```bash
ollama pull qwen3.8:27b
OLLAMA_HOST=0.0.0.0 ollama serve        # NICHT nur `ollama serve`
```

Läuft Ollama bereits ohne die Variable, muss es **neu gestartet** werden –
sie wird beim Start gelesen. Gegenprobe aus dem Container:

```bash
curl http://host.docker.internal:11434/api/version
```

Danach ist `ollama/qwen3.8:27b` in `_tiers.yml` verwendbar – und ist
dort für die Stufen `standard` und `cheap` bereits eingetragen.

> Wenn Tool-Aufrufe mit einem lokalen Modell unzuverlässig sind, ist das
> Kontextfenster meist zu klein – bei Ollama `num_ctx` auf 16k–32k
> anheben. Rollen dieser Methodik sind bewusst kontextarm, aber nicht
> kontextfrei.

> Die zweite Ursache für unzuverlässige Tool-Aufrufe ist zu **starke
> Quantisierung**. Sie degradiert ein Modell nicht gleichmässig: Faktenwissen
> überlebt, die Entschlusskraft stirbt zuerst – das Modell zählt dann
> Alternativen auf, statt ein Werkzeug aufzurufen. Genau davon hängt der
> Implementer ab. Unter Q4_K_M deshalb nicht gehen; lieber ein kleineres
> Modell in hoher Quant als ein grosses in niedriger.

### 3a. Mischbetrieb: Claude Code denkt, OpenCode arbeitet lokal

Der praktisch wichtigste Aufbau, weil er das Claude-Abo nutzt, **ohne**
dass die Fliessarbeit über die API abgerechnet wird:

| Rolle | Harness | Modell | Kosten |
|---|---|---|---|
| Orchestrator, Planner, Architekt, Reviewer | Claude Code | Abo | im Abo enthalten |
| Implementer, Tester (per `runtime: opencode`) | OpenCode | Ollama, lokal | keine |

Das Claude-Abo lässt sich **nicht** über OpenCode nutzen – Anthropic
untersagt das ausdrücklich, und OpenCode hat das entsprechende Plugin mit
1.3.0 wieder entfernt. Die Trennung oben ist deshalb keine Sparvariante,
sondern der einzige saubere Weg: Das Abo bleibt dort, wo es hingehört
(Claude Code), und alles, was über OpenCode läuft, läuft lokal.

Genau darauf ist die Voreinstellung in `_tiers.yml` ausgelegt: `standard`
und `cheap` zeigen unter `opencode:` auf Ollama. `runtime: opencode` im
Task-Frontmatter heisst damit schlicht "diese eine Ausführung läuft lokal".
Stünde dort `anthropic/…`, landete derselbe Task auf der API-Abrechnung –
also genau dem, was der Mischbetrieb vermeiden soll.

Der Ablauf, einmalig:

```bash
OLLAMA_HOST=0.0.0.0 ollama serve &            # 1. auf dem HOST (GPU), 0.0.0.0 ist Pflicht
ollama pull qwen3.8:27b
$EDITOR .agent/agents/_tiers.yml              # 2. nur falls anderes Modell gewuenscht
python3 .agent/sync-agents.py                 # 3. Adapter neu erzeugen
claude                                        # 4. Orchestrator starten
```

Danach ruft der Orchestrator den Implementer bei Bedarf als Unterprozess
auf (`opencode run --agent implementer --dir . --auto`) und beurteilt das
Ergebnis wie jeden eigenen Lauf: aus `git diff` und der Task-Datei, nicht
aus dem Log. Beide CLIs sind im Sandbox-Image enthalten.

### 3b. Messung: was ein Lauf wirklich kostet

Wer entscheiden soll, ob lokale Modelle eine Beschaffung wert sind,
braucht Zahlen statt Eindrücke. Die Messung ist deshalb **standardmässig
ein**:

```bash
AGENT_METRICS=0                    # nur falls man sie wirklich abschalten will
```

Der Default ist bewusst so herum. Die Messung kostet praktisch nichts – ein
`/proc`-Lesen alle zwei Sekunden, eine angehängte Zeile je Lauf, zwei kurze
`curl`s – und `.agent/runs/` ist ohnehin nicht versioniert, es entsteht also
kein Rauschen im Repo. Wer sie abschaltet, hat im Fehlerfall keine Historie,
und der Fehlerfall ist genau der Moment, in dem man sie gebraucht hätte.
Der Schalter existiert trotzdem: für Umgebungen, in denen selbst eine lokale
Laufzeit-Datei erklärungsbedürftig ist.

Sie hängt an `.agent/run-role.sh` – dem einzigen Weg, über den der
Orchestrator eine fremde Rolle aufruft. Das ist Absicht: Ein Zweig im
Rollen-Prompt ("falls Messung aktiv, tue X") wäre eine Compliance-Frage,
und Compliance ist das, was unter Last zuerst nachlässt. Hier entscheidet
das Skript, der Aufruf bleibt in beiden Fällen identisch.

Zwei Quellen, weil eine nicht reicht:

| Quelle | Läuft wo | Liefert |
|---|---|---|
| `.agent/run-role.sh` | in der Sandbox, bei jedem Lauf | Dauer, Exit, Versuch, Verdict, geänderte Dateien, Kaltstart, Peak-RAM des Containers |
| `.agent/sample-host.sh` | **auf dem Host**, die ganze Sitzung | CPU- und VRAM-Zeitreihe von Ollama |

Der Grund für die Trennung ist derselbe wie beim GPU-Zugriff: Im
Mischbetrieb liegt die Last dort, wo das Modell läuft – auf dem Host. Der
`opencode`-Prozess in der Sandbox ist ein dünner HTTP-Client, seine
CPU-Zahlen beantworten die Beschaffungsfrage **nicht**. Aus dem Container
heraus ist der Host-Prozess aber unsichtbar. Deshalb Ereignisse hier,
Zeitreihe dort, zusammengeführt über die Uhrzeit.

```bash
# Auf dem Host, vor der Sitzung:
.agent/sample-host.sh 5 > .agent/runs/host.csv &

# Nach der Sitzung, irgendwo:
python3 .agent/metrics-report.py          # Tabelle
python3 .agent/metrics-report.py --csv    # für Tabellenkalkulation/Folien
```

Der Report verdichtet je Rolle auf Median, Maximum, Summe und
**Wiederholungsquote**. Die letzte ist die Zahl, auf die es ankommt: Ein
Modell, das jeden zweiten Task zweimal braucht, ist nicht billiger,
sondern teurer. Ohne sie vergleicht man Laufzeiten von Läufen, die
unterschiedlich viel geleistet haben.

Der Report zeigt je Task die **Kette**, nicht einzelne Zeilen:

```
TASK-0002
  |- tester       #1    240s  PASS             2 Datei(en)
  |- implementer  #1    410s  CHANGES_NEEDED   3 Datei(en)
  |- planner      #1     95s  PASS             1 Datei(en)
  `- implementer  #2    505s  PASS             4 Datei(en)
```

Das ist nicht Kosmetik. Eine Wiederholung ist ohne ihren Vorlauf nicht
deutbar: „Implementer Versuch 2" heisst etwas anderes, je nachdem ob davor
nur der Implementer stand (**Modell zu schwach**) oder eine vorgelagerte
Rolle nachgebessert hat (**Task war schlecht geschnitten**). Für eine
Beschaffungsentscheidung dürfen diese beiden Fälle nicht in derselben Zahl
landen – sonst schreibt man dem lokalen Modell Fehler des Planners zu.

Läufe, die der Wrapper als unbrauchbar erkannt hat (Rolle nicht
ausgeführt, Berechtigung abgelehnt), weist der Report **separat** aus
statt sie stillschweigend mitzumitteln. Dasselbe gilt für Tasks, die an
der Versuchs-Obergrenze abgebrochen sind – sie erscheinen als
`[NICHT ABGESCHLOSSEN]`, auch wenn ein früherer Lauf `PASS` ergab.

**Abbruchkriterium:** Ab dem vierten Versuch einer Rolle am selben Task
verweigert `run-role.sh` den Lauf (`AGENT_MAX_ATTEMPTS`, Default 3). Ohne
diese Grenze ist die `CHANGES_NEEDED`-Schleife unbegrenzt – zwei Rollen
können sich eine ganze Nacht lang gegenseitig zurückschicken.

**Der Abbruch hält die ganze Initiative an, nicht nur den Task.** Er legt
`.agent/state/HALTED` an; jeder weitere `run-role.sh`-Aufruf bricht danach
mit Exit 5 ab – auch für eine andere Rolle und einen anderen Task. Tasks
bauen in der Regel aufeinander auf, und nach einem gescheiterten Task
weiterzubauen heisst, alles Folgende auf ein Fundament zu setzen, von dem
man weiss, dass es nicht trägt. Weitergehen ist ein bewusster
menschlicher Akt:

```bash
cat .agent/state/HALTED      # Grund und Logpfade
rm .agent/state/HALTED       # erst nach deinem Entscheid
```

> **Grenze dieser Absicherung, damit du dich nicht auf mehr verlässt als
> da ist:** Sie greift mechanisch für alles, was durch `run-role.sh`
> läuft – also jeden `runtime: opencode`-Baustein. Bausteine mit
> `runtime: subagent` ruft der Orchestrator in seinem eigenen Harness
> auf, an der Datei vorbei; dort bleibt es eine Prompt-Regel (sie steht
> in `orchestrator.md`). Wer das auch hart will, braucht einen
> `PreToolUse`-Hook in `.claude/settings.json`, der bei vorhandener
> HALTED-Datei den Sub-Agenten-Aufruf ablehnt.

**Den Schritt `OLLAMA_HOST=0.0.0.0` musst du dir nicht merken.** Vor dem
ersten `runtime: opencode`-Lauf einer Session führt der Orchestrator einen
**Vorflug-Check** aus (`.agent/agents/orchestrator.md`, Schritt 5): Ist
OpenCode installiert, ist `$OLLAMA_BASE_URL` gesetzt, antwortet der
Endpunkt, ist das Modell aus `_tiers.yml` überhaupt geladen? Fehlt etwas,
**stoppt er und nennt dir den konkreten Befehl** – er repariert es nicht
selbst (der Modell-Server liegt ausserhalb der Sandbox) und weicht auch
nicht still auf `runtime: subagent` aus, weil das eine Kostenentscheidung
wäre, die dir gehört.

### 4. Requirements

`.agent/spec/Requirements.md` beschreibt, was das Produkt können soll. Du
musst es nicht vorab ausfüllen: sag dem Orchestrator, dass du die
Anforderungen erarbeiten willst – das wird ein eigener Auftrag im Modus
`REQUIREMENTS`. Er klärt dann Thema für Thema mit dir: je Runde höchstens
sieben Fragen, jede mit Begründung und einem Vorschlag, den du nur
bestätigen musst; danach formuliert der Planner das geklärte Thema aus und
sagt, ob noch eines offen ist. Am Ende steht die fertige
`Requirements.md` – noch kein Code. Existiert bereits eine Beschreibung
(README, Tickets), nenne sie: sie wird zum Ausgangsmaterial im Auftrag.

### 5. Berechtigungen und Git

Zwei Dinge gehören **vor** den ersten Task geklärt, sonst bremsen sie
jeden Lauf.

**Git**: kein Repo → `git init` plus initialer Commit. Bestehendes Repo →
der Orchestrator fragt, ob auf dem aktuellen Branch weitergearbeitet oder
ein eigener Branch für die Initiative angelegt wird. Ohne Repo gibt es
keine nachvollziehbaren Zwischenstände – ein Commit pro verifiziertem Task
ist Teil der Methodik.

**Berechtigungen**: Muss der Agent bei jedem Dateizugriff einzeln fragen,
ist "selbständig durchlaufen lassen" nicht möglich.

- **Claude Code**: `/permissions` bzw. `.claude/settings.json`; der Skill
  `fewer-permission-prompts` erzeugt eine passende Allowlist aus deiner
  bisherigen Nutzung. Sub-Agenten erben deinen Modus.
- **Sandbox** (empfohlen für volle Freiheit): `sandbox/run-sandbox.sh`,
  danach die Selbstcheck-Schritte aus `sandbox/README.md`. Achtung: dort
  ist `.git` read-only gemountet – der Orchestrator bereitet dann Diffs
  statt Commits vor.
- **OpenCode headless**: `opencode run` **fragt nicht** – ohne `--auto`
  wird jede Berechtigungsanfrage still **abgelehnt** und der Lauf geht
  weiter. Ergebnis wäre ein "erfolgreicher" Lauf, der nichts geschrieben
  hat. Deshalb ruft der Orchestrator immer mit `--auto` auf und prüft das
  Log auf `auto-rejecting`.

---

## Teil 2 – Neues Projekt (Greenfield)

```bash
mkdir ~/projekte/mein-tool && cd ~/projekte/mein-tool
cp -r /pfad/zu/tools/agent-workflow/project-template/. .
git init
```

1. **Testpfade setzen** in `implementer.meta.yml` und `tester.meta.yml`
   (Entscheidung 1). Bei Greenfield: die Konvention, die du *verwenden
   wirst*.
2. **Modelle prüfen** in `_tiers.yml` (Entscheidung 2). Der Standard läuft
   sofort, wenn du Claude Code nutzt.
3. **Generieren**: `python3 .agent/sync-agents.py`
4. **Erster Commit**: `git add -A && git commit -m "Agent-Workflow eingerichtet"`
5. **Agent starten**: `claude` im Projektordner. Er lädt über
   `CLAUDE.md` → `AGENTS.md` die Orchestrator-Rolle.
6. **Sagen, was du willst.** Er klärt zuerst den Auftrag mit dir und hält
   ihn in `.agent/state/AUFTRAG.md` fest. Bei einem leeren Projekt ist der
   erste Auftrag meist `REQUIREMENTS` (Anforderungen erarbeiten), danach
   als zweiter Auftrag `FEATURE` (umsetzen).

Den Baustein `MAP` brauchst du hier nicht – `Architecture.md` füllt sich
schrittweise durch die Implementer.

---

## Teil 3 – Bestehendes Projekt (Brownfield)

Produktcode bleibt unangetastet; es kommen nur die Workflow-Dateien dazu.

```bash
cd /pfad/zu/bestehendem-projekt
cp -r /pfad/zu/tools/agent-workflow/project-template/.agent .
cp /pfad/zu/tools/agent-workflow/project-template/AGENTS.md .
cp /pfad/zu/tools/agent-workflow/project-template/CLAUDE.md .
cp /pfad/zu/tools/agent-workflow/project-template/.gitattributes .   # falls noch keine
```

> Hast du bereits eine `AGENTS.md` oder `CLAUDE.md`: **nicht überschreiben**,
> sondern die beiden Import-Zeilen aus der Template-Version an deine
> bestehende anhängen.

1. **Testpfade setzen** – hier kein Raten: schau nach, wo die Tests
   tatsächlich liegen, und trage genau das ein.
2. **Modelle prüfen**, dann `python3 .agent/sync-agents.py`.
3. **Baustein `MAP` laufen lassen**: der Reviewer liest den bestehenden
   Code und schreibt `.agent/spec/Architecture.md` daraus. Das ist der
   Bootstrap-Schritt; ohne ihn planen alle nachfolgenden Rollen blind.
4. **Requirements erfassen**: Auftrag im Modus `REQUIREMENTS`, aus
   README/Tickets abgeleitet und von dir bestätigt – nicht aus dem Code
   geraten.
5. **Erste Initiative ist meist ein `AUDIT`** – der Ist-Zustand gegen die
   frisch erfassten Requirements. Aus dem Report macht der Planner Tasks.

---

## Teil 4 – Wann muss ich `sync-agents.py` ausführen?

Immer dann, wenn du eine **Quelle** geändert hast:

| Geändert | Neu generieren? |
|---|---|
| `.agent/agents/_tiers.yml` (Modellwahl) | **ja** |
| `.agent/agents/<rolle>.meta.yml` (Rechte, Stufe, Limits) | **ja** |
| `.agent/agents/<rolle>.md` (Rollentext) | **ja** |
| Neue Rolle ergänzt (Body + `meta.yml`) | **ja** |
| `Requirements.md`, `Architecture.md`, Tasks, Reports | nein |
| Produktcode | nein |

```bash
python3 .agent/sync-agents.py           # erzeugen/aktualisieren
python3 .agent/sync-agents.py --check   # nur prüfen, Exit 1 bei Drift
```

Vergessen ist der häufigste Anfängerfehler, und er fällt nicht auf: der
Agent läuft weiter, nur mit den alten Einstellungen. Deshalb der
`--check`-Modus – als Pre-Commit-Hook:

```bash
printf '#!/bin/sh\nexec python3 .agent/sync-agents.py --check\n' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### Die generierten Dateien gehören ins Repo

`.claude/agents/*.md` und `.opencode/agent/*.md` werden **eingecheckt**,
nicht ignoriert. Beide Harnesses entdecken Rollen daran, dass die Dateien
vorhanden sind – es gibt keinen Installationsschritt. Ohne sie hätte ein
frischer Clone still keine Rollen, und das Fehlerbild wäre kein Fehler,
sondern stille Degradierung. Ausserdem stehen dort sicherheitsrelevante
Einstellungen (`permission: deny`, Modellwahl), die man im Review-Diff
sehen will.

Die `.gitattributes` markiert sie als generiert, damit sie in Diffs
eingeklappt werden. **Editiere sie nie von Hand** – der nächste Lauf
überschreibt sie kommentarlos.

---

## Teil 5 – Betrieb im Alltag

### Arbeit anstossen

Du sagst dem Orchestrator, was ansteht. Sein **erster** Schritt ist immer
die Auftragsklärung: er hält in `.agent/state/AUFTRAG.md` fest, was du
willst, was dazugehört (und was nicht) und woran man erkennt, dass es
erledigt ist. Nur wenn das nicht eindeutig ist, fragt er nach – höchstens
fünf Fragen mit Vorschlägen zum Bestätigen; bei "änder in Datei X das Y"
fragt er gar nicht. Aus diesem Auftrag ergibt sich der Modus. Du musst die
Modi nicht auswendig können – es hilft nur zu wissen, was passieren wird:

| Du sagst … | Modus | Was läuft |
|---|---|---|
| "Lass uns die Anforderungen erarbeiten" | `REQUIREMENTS` | Klärung Thema für Thema → `spec/Requirements.md`, kein Code |
| "Bau Feature X" | `FEATURE` | Klärung → Plan → Architektur-Gate → Task-Schleife → Review |
| "Behebe die Findings aus dem Report" | `FIX` | Plan → Task-Schleife → Review |
| "Prüf mal den Stand" | `AUDIT` | nur Reviewer, keine Änderung |
| "Ich hab manuell getestet, schau in die Inbox" | `MANUELLER-TEST` | Triage → dann Fix |
| "Änder in Datei Y die Z" | `EINZELAUFTRAG` | Umsetzung → Verifikation, ohne Planner |

### Manuell getestet? Material in die Inbox

Lege alles, was beim Testen anfällt, unstrukturiert in `.agent/inbox/` –
Screenshots, Terminal-Auszüge, Notizen. Der Reviewer verknüpft im
Triage-Modus jedes Fundstück mit einer Codestelle und macht daraus einen
Report; verarbeitetes Material wandert nach `.agent/inbox/processed/<datum>/`.
Du musst nichts vorformulieren – genau dafür ist die Inbox da.

Das Ergebnis eines Auftrags ist immer genau ein Modus. Willst du danach
etwas anderes – z.B. die frisch erarbeiteten Requirements umsetzen – ist
das ein **neuer** Auftrag, und die Klärung beginnt von vorn. Der alte
wandert nach `.agent/history/<datum>-<slug>-auftrag.md`.

### Was du im Verlauf liest

- `.agent/state/AUFTRAG.md` – was gerade geklärt wurde und läuft,
  inklusive der gestellten Fragen und deiner Antworten.
- `.agent/state/PROGRESS.md` – chronologisch, was passiert ist, inklusive
  übersprungener Bausteine samt Begründung.
- `.agent/tasks/TASK-*.md` – Status, Akzeptanzkriterien, Test-Notizen.
- `.agent/reports/<datum>-*.md` – Review- und Triage-Ergebnisse, nie
  überschrieben.
- `.agent/runs/*.log` – Rohprotokolle fremder Harness-Läufe (nicht
  versioniert; Protokoll für dich, nicht Entscheidungsgrundlage des
  Orchestrators).

### Vom Review zum Fix

Der übliche Zyklus, wenn du den Stand prüfen lässt:

1. `REVIEW` (oder `TRIAGE`) schreibt einen datierten Report unter
   `.agent/reports/` – Findings, keine Änderungen am Code.
2. Neuer Auftrag im Modus `FIX`: der Planner macht aus jedem Finding einen
   Task (weiter unterteilt, falls ein Finding mehrere Dateien betrifft).
3. Normale Task-Schleife.
4. Danach ein erneuter `REVIEW` zur Bestätigung – als **neuer**, datierter
   Report. Alte Reports werden nie überschrieben, damit sich der Zustand
   über die Zeit nachvollziehen lässt.

### Wenn ein Limit erreicht wird

Der Orchestrator stoppt sauber, lässt den laufenden Task auf
`in_progress`, notiert den Reset-Zeitpunkt in `PROGRESS.md` und setzt
– falls verfügbar – einen Wakeup. Eine neue Nachricht nach dem Reset
genügt zum Fortsetzen; es geht nichts verloren, weil der Zustand in den
Task-Dateien steht.

---

## Teil 6 – Was du nie anfasst

| Datei | Warum |
|---|---|
| `.claude/agents/*.md`, `.opencode/agent/*.md` | generiert; Änderungen gehen beim nächsten Lauf verloren |
| `.agent/tasks/*.md` während ein Task läuft | der Orchestrator führt darüber Buch |
| `.agent/reports/*` (ältere) | sie sind der Verlauf, nicht der aktuelle Stand |

Gegenstück: Was **du** pflegst, sind `Requirements.md`, `_tiers.yml`, die
`*.meta.yml` und die Inbox.

---

## Teil 7 – Wenn etwas nicht stimmt

| Symptom | Ursache | Lösung |
|---|---|---|
| Rolle wird nicht gefunden / falsches Modell | Generator nicht gelaufen | `python3 .agent/sync-agents.py` |
| Implementer hat Testdateien geändert | Testpfade in `meta.yml` passen nicht zum Projekt | Pfade korrigieren, neu generieren; der Orchestrator fängt es zusätzlich per `git diff` |
| Fremder Lauf "erfolgreich", aber nichts geändert | Berechtigung still abgelehnt | Log auf `auto-rejecting` prüfen, `--auto` bzw. `permission: allow` setzen |
| Fehler `unbekannter model_tier '<x>'` | Stufe in einer `meta.yml` hat keinen Eintrag in `_tiers.yml` | Stufe dort ergänzen (oder Tippfehler korrigieren) |
| Agent plant mehrere Tasks gleichzeitig | Protokollverstoss | Abbrechen; Modell/Harness-Kombination prüfen (siehe `DECISIONS.md`, Lehre Nr. 7) |
| Tests schlagen nach `TEST_FIRST` **nicht** fehl | Verhalten existiert bereits, oder der Test prüft nichts | Der Tester meldet das als `CHANGES_NEEDED` – Task überprüfen, nicht den Test abschwächen |
| Lokales Modell ruft keine Tools auf | Kontextfenster zu klein | Bei Ollama `num_ctx` auf 16k–32k anheben |
| Lokales Modell nicht erreichbar (Verbindungsfehler) | `$OLLAMA_BASE_URL` nicht gesetzt (OpenCode ersetzt sie dann durch einen leeren String), oder Ollama lauscht nur auf `127.0.0.1` | Host: `export OLLAMA_BASE_URL=http://localhost:11434/v1`; Sandbox: setzt das Image selbst. Ollama mit `OLLAMA_HOST=0.0.0.0` starten |

---

## Anhang – Alle Konfigurationsdateien auf einen Blick

```
mein-projekt/
  AGENTS.md                          # importiert MEMORY.md + orchestrator.md
  CLAUDE.md                          # importiert AGENTS.md
  opencode.json                      # Provider-Definition fuer lokale Modelle
  .gitattributes                     # markiert generierte Dateien

  .agent/
    sync-agents.py                   # der Generator
    agents/
      _tiers.yml                     # Stufe → Modell                    ← DU
      <rolle>.md                     # Rollentext (selten anfassen)
      <rolle>.meta.yml               # Rechte, Stufe, Pfade, Limits      ← DU
    spec/
      Requirements.md                # was das Produkt können soll       ← DU
      Architecture.md                # gepflegt von MAP/Implementer
    state/                           # PROGRESS, PLAN, MEMORY – gepflegt vom Agenten
    tasks/                           # die Warteschlange – gepflegt vom Agenten
    reports/                         # Review-/Triage-Ergebnisse
    inbox/                           # dein Rohmaterial aus manuellem Testen ← DU
    runs/                            # Logs fremder Läufe (nicht versioniert)
    history/                         # archivierte Pläne

  .claude/agents/*.md                # GENERIERT – nie von Hand editieren
  .opencode/agent/*.md               # GENERIERT – nie von Hand editieren
```

`← DU` markiert die Dateien, in denen du Entscheidungen triffst. Es sind
vier, und nur die erste ist wirklich Pflicht.
