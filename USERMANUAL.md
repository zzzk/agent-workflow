# Benutzerhandbuch: Agent-Workflow einrichten und betreiben

Für den **Menschen**, der ein Projekt mit dieser Methodik bearbeiten will.
Es beantwortet drei Fragen: was muss ich einmalig entscheiden, wo trage ich
das ein, und wie starte ich ein Projekt – neu oder bestehend.

Die Methodik selbst (warum es so aufgebaut ist, welche Rolle was tut) steht
in `AGENT_WORKFLOW.md`. Dieses Handbuch setzt sie voraus und bleibt
praktisch.

---

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
| OpenCode | Nötig, sobald einzelne Rollen auf anderen/lokalen Modellen laufen sollen (Installation: `opencode.ai/docs`) | optional |
| Ollama / LM Studio | Lokale Modelle bereitstellen | nur bei lokalem Betrieb |
| Docker | Die Sandbox aus `sandbox/` | optional, empfohlen |

---

## Teil 1 – Was du entscheiden musst, und wo

Das ist der Kern dieses Handbuchs. Alles andere ergibt sich daraus.

| # | Entscheidung | Datei | Wann | Pflicht? |
|---|---|---|---|---|
| 1 | **Wo liegen die Tests?** | `.agent/agents/implementer.meta.yml` + `tester.meta.yml` | einmal pro Projekt | **ja** |
| 2 | **Welche Rolle auf welchem Modell?** | `.agent/agents/_tiers.yml` | einmal, dann bei Bedarf | nein (Standard funktioniert) |
| 3 | **Lokale Modelle verfügbar machen** | `opencode.json` im Projekt-Root | nur bei lokalem Betrieb | nein |
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
  strong: anthropic/claude-opus-5
  standard: anthropic/claude-sonnet-5
  cheap: ollama/qwen2.5-coder:14b
```

Welche Rolle welche Stufe hat, steht in `<rolle>.meta.yml`. Standard:

| Stufe | Rollen | Warum |
|---|---|---|
| `strong` | Planner, Architekt, Reviewer | Denkarbeit: zerlegen, beurteilen, Drift erkennen |
| `standard` | Orchestrator, Implementer, Tester | Ausführung entlang einer engen, vollständigen Auftragsdatei |

Willst du günstiger oder lokaler fahren, ändere die **Zuordnung**, nicht
die Rollen: `standard: ollama/qwen2.5-coder:14b`. Der Implementer ist der
beste Kandidat dafür – sein Auftrag ist eng, seine Arbeit wird von einem
unabhängigen Tester geprüft, und Fehler kosten nur einen weiteren Durchlauf.

### 3. Lokale Modelle: nur über OpenCode

**Claude Code kann das nicht.** Es akzeptiert pro Rolle ausschliesslich
Anthropic-Modelle, und eine Umleitung auf einen anderen Anbieter
(`ANTHROPIC_BASE_URL`, Bedrock, Vertex) wirkt immer für die **gesamte**
Session. Ein Mischbetrieb – Planner in der Cloud, Implementer lokal – ist
dort strukturell nicht möglich, nicht bloss unkonfiguriert.

Mit OpenCode definierst du den Provider einmal im Projekt-Root:

```jsonc
// opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (lokal)",
      "options": { "baseURL": "http://localhost:11434/v1" },
      "models": { "qwen2.5-coder:14b": { "name": "Qwen2.5 Coder 14B" } }
    }
  }
}
```

Danach ist `ollama/qwen2.5-coder:14b` in `_tiers.yml` verwendbar. Das
Modell vorher laden: `ollama pull qwen2.5-coder:14b`.

> Wenn Tool-Aufrufe mit einem lokalen Modell unzuverlässig sind, ist das
> Kontextfenster meist zu klein – bei Ollama `num_ctx` auf 16k–32k
> anheben. Rollen dieser Methodik sind bewusst kontextarm, aber nicht
> kontextfrei.

### 4. Requirements

`.agent/spec/Requirements.md` beschreibt, was das Produkt können soll. Du
musst es nicht vorab perfekt ausfüllen: der Planner erarbeitet es im
Baustein `KLAERUNG` mit dir – er stellt höchstens sieben Fragen, jede mit
Begründung und einem Vorschlag, den du nur bestätigen musst. Existiert
bereits eine Beschreibung (README, Tickets), gib sie ihm als Ausgangspunkt.

### 5. Berechtigungen

Muss der Agent bei jedem Dateizugriff einzeln fragen, ist "selbständig
durchlaufen lassen" nicht möglich. Kläre das **vor** dem ersten Task:

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
6. **Sagen, was du willst.** Da noch keine Requirements existieren, wählt
   er den Modus `FEATURE` und startet mit der Klärung.

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
3. **Requirements erfassen**: aus README/Tickets ableiten und bestätigen
   lassen – nicht aus dem Code raten.
4. **Baustein `MAP` laufen lassen**: der Reviewer liest den bestehenden
   Code und schreibt `.agent/spec/Architecture.md` daraus. Das ist der
   Bootstrap-Schritt; ohne ihn planen alle nachfolgenden Rollen blind.
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

Du sagst dem Orchestrator, was ansteht; er ordnet es einem Modus zu. Du
musst die Modi nicht auswendig können – es hilft nur zu wissen, was
passieren wird:

| Du sagst … | Modus | Was läuft |
|---|---|---|
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

### Was du im Verlauf liest

- `.agent/state/PROGRESS.md` – chronologisch, was passiert ist, inklusive
  übersprungener Bausteine samt Begründung.
- `.agent/tasks/TASK-*.md` – Status, Akzeptanzkriterien, Test-Notizen.
- `.agent/reports/<datum>-*.md` – Review- und Triage-Ergebnisse, nie
  überschrieben.
- `.agent/runs/*.log` – Rohprotokolle fremder Harness-Läufe (nicht
  versioniert; Protokoll für dich, nicht Entscheidungsgrundlage des
  Orchestrators).

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
| Agent plant mehrere Tasks gleichzeitig | Protokollverstoss | Abbrechen; Modell/Harness-Kombination prüfen (siehe `AGENT_WORKFLOW.md`, Lessons Learned Nr. 7) |
| Tests schlagen nach `TEST_FIRST` **nicht** fehl | Verhalten existiert bereits, oder der Test prüft nichts | Der Tester meldet das als `CHANGES_NEEDED` – Task überprüfen, nicht den Test abschwächen |
| Lokales Modell ruft keine Tools auf | Kontextfenster zu klein | Bei Ollama `num_ctx` auf 16k–32k anheben |

---

## Anhang – Alle Konfigurationsdateien auf einen Blick

```
mein-projekt/
  AGENTS.md                          # importiert MEMORY.md + orchestrator.md
  CLAUDE.md                          # importiert AGENTS.md
  opencode.json                      # nur bei lokalen/fremden Modellen  ← DU
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
