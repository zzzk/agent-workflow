# Vorgehen: Rollen-Agenten mit flexibel zusammengesetzten Bausteinen

Generische, wiederverwendbare Methode, um ein Software-Vorhaben durch
mehrere spezialisierte Agenten selbständig umsetzen zu lassen, ohne dass
Qualität oder Kontrollierbarkeit leiden – auch (und gerade) wenn einzelne
Rollen auf günstigen oder lokalen Modellen mit begrenztem Kontextfenster
laufen.

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

## Wann anwenden

- Das Vorhaben lässt sich in klar abgrenzbare, unabhängig testbare
  Arbeitspakete zerlegen (z.B. Module/Funktionen mit klarem
  Ein-/Ausgabeverhalten).
- Es sollen kleine/günstige (ggf. lokale) Modelle verwendet werden
  (begrenztes Kontextfenster, geringere Zuverlässigkeit bei grossen
  Aufgaben am Stück).
- Gilt sowohl für **Greenfield** (neues Projekt, Requirements + Plan werden
  von Null erarbeitet) als auch für **Brownfield** (bestehender Code ohne
  – oder mit veralteter – Doku; siehe "Brownfield-Einstieg" unten).

---

## Teil A – Die Rollen

Jede Rolle hat einen bewusst engen, für sich lauffähigen Kontext und eine
eigene Datei unter `.agent/agents/`. Eine Rolle liest **nie** die volle
bisherige Gesprächshistorie – nur das, was ihre Auftragsdatei (ein Task,
ein Report, o.ä.) tatsächlich braucht.

1. **Orchestrator** (`orchestrator.md`) – dünne Schleife, kein grosses
   Kontextfenster nötig. Ermittelt die Ausgangslage, **klärt den Auftrag
   mit dem Nutzer** (Baustein `AUFTRAGSKLAERUNG` → `state/AUFTRAG.md`),
   leitet daraus den **Modus** ab (Teil C), ruft die Bausteine in der
   dafür festgelegten Reihenfolge auf, wertet deren **Verdict** aus,
   pflegt Task-Status und `state/PROGRESS.md`, committet. Schreibt selbst
   keinen Code und plant selbst keine Schritte. Er ist die **einzige**
   Rolle mit Nutzerkontakt.
2. **Planner** (`planner.md`) – die "Denkarbeit": schärft eine unklare
   Anforderung (Baustein `KLAERUNG`, rundenbasiert über das
   Klärungsprotokoll in `state/AUFTRAG.md`) und zerlegt eine Quelle (neue
   Anforderung oder Findings aus einem Report) in kleine, unabhängige
   `.agent/tasks/TASK-*.md`-Dateien (Baustein `PLAN`). Braucht mehr
   Kontext/Fähigkeit als die Ausführungsrollen – hier lohnt das stärkste
   verfügbare Modell.
3. **Architekt** (`architect.md`) – *neu in v3.* Read-only Gutachter, der
   den **Plan** gegen `spec/Architecture.md` prüft, **bevor** Code
   entsteht: passt das Vorhaben in eine bestehende Abstraktion oder
   braucht es wirklich eine neue? Werden Schichtgrenzen verletzt? Kommt
   eine Abhängigkeit dazu, die es schon gibt? Fängt Architektur-Drift
   dann ab, wenn sie noch nichts kostet.
4. **Implementer** (`implementer.md`) – setzt **genau einen** Task um
   (Code + ggf. minimale Doku/Architecture-Update), nichts darüber hinaus.
   Kennt weder vorherige noch zukünftige Tasks im Detail.
5. **Tester** (`tester.md`) – unabhängig vom Implementer, kennt nur die
   **Akzeptanzkriterien** des Tasks (nicht die Implementierungs-
   Begründung). Läuft in zwei Bausteinen: `TEST_FIRST` (schreibt die Tests,
   bevor implementiert wird) und `VERIFIKATION` (führt die gesamte Suite
   aus, nachdem implementiert wurde). Diese Unabhängigkeit ist bewusst:
   sie verhindert, dass Tests nachvollziehen, was sich der Implementer
   gedacht hat, statt echt gegen die Spezifikation zu prüfen.
6. **Reviewer** (`reviewer.md`) – read-only Auditor, editiert nie
   Produktcode/Tests. Drei Modi: **Map** (Bestandsaufnahme eines
   bestehenden Codebestands → `spec/Architecture.md`), **Audit** (Code +
   Tests gegen `spec/` prüfen → datierter Report) und **Triage**
   (Rohmaterial aus manuellem Testen in `.agent/inbox/` → Report).
   Erzeugt selbst keine Tasks – das macht der Planner aus dem Report.

Implementer und Tester interagieren **nie direkt** miteinander – jede
Übergabe läuft über den Orchestrator bzw. über die Task-Datei selbst.
Dasselbe gilt für Architekt und Implementer.

### Rollen-Vertrag: einheitlicher Aufbau jeder Rollen-Datei

Jede Datei unter `.agent/agents/` folgt derselben Gliederung. Der Wert
liegt nicht in der Ästhetik, sondern darin, dass eine Rolle beim Lesen
sofort weiss, welcher Abschnitt sie bindet – besonders bei schwächeren
Modellen, die lange Fliesstexte ungleichmässig gewichten.

```markdown
# Rolle: <Name>

<Ein Satz: wer du bist, was dein Ergebnis ist, und was du NICHT tust.>

## Was du liest
<Abschliessende Liste. Alles andere ist ausserhalb deines Auftrags.>

## Vorgehen
<Nummeriert, jeder Punkt eine Handlung – keine Absichtserklärungen.>

## Harte Regeln
<Was du unter keinen Umständen tust. Wo möglich mit konkretem
Anti-Beispiel aus einem realen Vorfall statt abstrakter Regel.>

## Rückmeldung
<Exaktes Ausgabeformat: Verdict-Zeile zuerst, dann die Pflichtangaben.>
```

Der Body enthält **kein** Frontmatter – er ist harness-neutral (siehe
Teil D). Die harness-spezifischen Felder liegen daneben in
`<rolle>.meta.yml`.

### Verdicts: das gemeinsame Rückgabe-Vokabular

Jeder Baustein endet mit **genau einer** Verdict-Zeile als erster Zeile
der Rückmeldung. Der Orchestrator verzweigt danach mechanisch (greppbar),
statt Fliesstext zu interpretieren.

| Verdict | Bedeutung | Was der Orchestrator tut |
|---|---|---|
| `PASS` | Auftrag erfüllt, nichts anzumerken | Nächster Baustein des Modus |
| `PASS_WITH_NOTES` | Erfüllt, aber mit Hinweisen für nachfolgende Rollen | Weiter; Notizen in die Task-Datei bzw. den Plan übernehmen |
| `CHANGES_NEEDED` | Nicht erfüllt; die Begründung benennt konkret was fehlt | Zurück an die vorgelagerte Rolle, mit der Begründung als zusätzlichem Kontext |
| `BLOCKED` | Kann nicht entscheiden – Information fehlt oder es ist eine Produktentscheidung | Stopp; Rückfrage an den Nutzer, kein Weitermachen auf Verdacht |

Pflicht in jeder Rückmeldung, unabhängig vom Verdict: geänderte Dateien,
und jede bewusst getroffene Annahme oder Abweichung vom Auftrag (mit
Begründung). `CHANGES_NEEDED` und `BLOCKED` ohne konkrete, überprüfbare
Begründung sind selbst ein Fehler und gehen an dieselbe Rolle zurück.

---

## Teil B – Der Baustein-Katalog

Ein **Baustein** ist ein Aufruf genau einer Rolle mit genau einem Auftrag.
Bausteine sind unabhängig voneinander definiert; ein Modus (Teil C) ist
nur eine Reihenfolge daraus. Das ersetzt den festen Ablauf aus v1/v2:
nicht jede Arbeit ist "Anforderung bis Auslieferung", und Bausteine, die
nichts zu tun hätten, werden gar nicht erst gestartet.

| Baustein | Rolle | Aktivierung | Input | Ergebnis |
|---|---|---|---|---|
| `AUFTRAGSKLAERUNG` | Orchestrator | **immer**, als erster Baustein jeder Initiative | Nutzer-Anliegen, Lage im Repo | `state/AUFTRAG.md` + der daraus abgeleitete Modus |
| `MAP` | Reviewer (Map) | `spec/Architecture.md` fehlt/leer, aber Code existiert | vorhandener Code | `spec/Architecture.md` |
| `KLAERUNG` | Planner (Klärung) | Anforderung unklar oder `spec/Requirements.md` lückenhaft | `state/AUFTRAG.md`, `spec/` | Fragerunde im Klärungsprotokoll **oder** ausformulierte Anforderung in `Requirements.md` |
| `PLAN` | Planner | immer, ausser bei Einzelauftrag | Anforderung oder Report | `tasks/TASK-*.md` (+ ggf. `state/IMPLEMENTATION_PLAN.md`) |
| `ARCHITEKTUR_GATE` | Architekt | Plan führt neue Komponente/Schnittstelle/Abhängigkeit ein | Task-Set, `spec/Architecture.md` | Verdict + Vorgaben für Implementer |
| `TEST_FIRST` | Tester | pro Task, sofern nicht abgewählt | nur Akzeptanzkriterien des Tasks | fehlschlagende Tests + Commit (Freeze-Grenze) |
| `UMSETZUNG` | Implementer | pro Task | vollständige Task-Datei | Code-Änderung |
| `VERIFIKATION` | Tester | pro Task, nach `UMSETZUNG` | Akzeptanzkriterien + Testlauf | Verdict + Test-Notizen in der Task-Datei |
| `REVIEW` | Reviewer (Audit) | nach Abschluss einer Initiative, oder auf Wunsch | `spec/`, Code, Testlauf | `reports/<datum>-review.md` |
| `TRIAGE` | Reviewer (Triage) | `.agent/inbox/` enthält Material | Inbox-Rohmaterial + Code | `reports/<datum>-triage.md` |

### Auftragsklärung: der einzige Baustein mit Nutzerkontakt

Alle Rollen ausser dem Orchestrator sind Subagenten: einmal gestartet,
eine Rückmeldung, danach weg – sie können den Nutzer weder fragen noch auf
eine Antwort warten. Deshalb liegt das Klären des Auftrags beim
Orchestrator, und sein Ergebnis ist eine **Datei** (`state/AUFTRAG.md`)
statt eines Gesprächsverlaufs:

- Der Modus wird aus dem geklärten Auftrag abgeleitet, nicht aus dem
  Dateizustand plus einer Chat-Antwort. "Requirements sind leer" heisst
  eben nicht automatisch "bau ein Feature".
- Nachfolgende Rollen lesen den Auftrag, statt ihn als Prosa gereicht zu
  bekommen – konsistent mit "eine Rolle liest nie die Gesprächshistorie".
- Eine unterbrochene Session (Rate-Limit, Absturz, anderer Rechner) kann
  den Auftrag wieder aufnehmen, weil er auf der Platte steht.

Der Baustein ist ein **Filter, kein Interview**: gefragt wird nur, wenn
der Modus nicht eindeutig ableitbar ist, ein prüfbares Erfolgskriterium
fehlt, der Umfang offen ist oder der Auftrag etwas Bestehendem
widerspricht – dann höchstens fünf Fragen, jede mit Default-Vorschlag.
Fachlich entworfen wird hier nicht; das ist Sache von `KLAERUNG`.

Die beiden Klärungen sind bewusst getrennt:

| Baustein | Rolle | Klärt | Ergebnis |
|---|---|---|---|
| `AUFTRAGSKLAERUNG` | Orchestrator (im Dialog) | *Was für Arbeit, welcher Umfang?* | `state/AUFTRAG.md` + Modus |
| `KLAERUNG` | Planner (Subagent, je Runde ein Aufruf) | *Ist diese Anforderung planbar?* | Fragen bzw. Anforderung in `spec/Requirements.md` |

### Aktivierung: mechanisch, wo es geht

Ein Baustein wird nicht nach Gefühl gestartet, sondern nach einer
überprüfbaren Bedingung. Wo eine Bedingung mechanisch prüfbar ist, prüft
der Orchestrator sie per Kommando statt sie einzuschätzen:

```bash
# Liegt Rohmaterial zum Triagieren vor?
ls -A .agent/inbox/ | grep -v -e '^processed$' -e '^\.gitkeep$'

# Wurde eine Abhängigkeits-Manifestdatei angefasst?  → ARCHITEKTUR_GATE
git diff --name-only -- pyproject.toml requirements.txt package.json go.mod

# Welche Prüf-Linsen braucht der Review überhaupt?
git diff --name-only origin/main...HEAD
```

**Kein Baustein wird gestartet, dessen Ergebnis absehbar "nichts zu tun"
wäre.** Ein übersprungener Baustein wird aber in `state/PROGRESS.md`
protokolliert – mit der Bedingung, die zum Überspringen führte, damit
später nachvollziehbar ist, dass er nicht vergessen wurde:

```
SKIPPED ARCHITEKTUR_GATE – keine neue Komponente/Abhängigkeit im Plan
(mechanisch geprüft: kein Manifest im Diff)
```

### Prüf-Linsen statt Spezial-Reviewer

Statt eigener Agenten für Sicherheit, Abhängigkeiten, UI usw. bekommt der
eine Reviewer **Linsen**, die der Orchestrator anhand des Diffs aktiviert
(z.B. Sicherheits-Linse bei Krypto-/Auth-/Eingabe-Validierungs-Code,
Abhängigkeits-Linse bei geänderten Manifesten). Das hält die Zahl der
Rollen-Dateien klein und die Aktivierungsentscheidung mechanisch.

---

## Teil C – Modi: Bausteine zusammensetzen

Der Orchestrator ermittelt zu Beginn jeder Session die Ausgangslage, klärt
den Auftrag und leitet daraus den Modus ab. Ein Modus ist nichts weiter
als eine Reihenfolge von Bausteinen – nicht mehr die eine feste Pipeline
aus v1/v2.

Jede Initiative beginnt mit `AUFTRAGSKLAERUNG`; der Modus ist das Ergebnis
dieses Bausteins und steht in `state/AUFTRAG.md`. Ein Auftrag ergibt genau
einen Modus – fällt unterwegs etwas an, das einen anderen bräuchte, wird
das ein eigener Auftrag, kein Anhängsel.

```
BOOTSTRAP (Brownfield, erstmalig)
  MAP → danach neue AUFTRAGSKLAERUNG (meist REQUIREMENTS oder AUDIT)

REQUIREMENTS (Anforderungen erarbeiten – Deliverable ist spec/Requirements.md)
  je Thema: KLAERUNG(a: Fragerunde) → Nutzer antwortet (Orchestrator)
          → KLAERUNG(b: Ausformulierung)
  bis der Planner "keine offenen Themen" meldet
  (kein PLAN, keine Tasks, kein Code – die Umsetzung ist ein neuer Auftrag)

FEATURE (neue Anforderung umsetzen)
  KLAERUNG → PLAN → ARCHITEKTUR_GATE
           → [ TEST_FIRST → UMSETZUNG → VERIFIKATION ] pro Task
           → REVIEW

FIX (Findings aus einem Report beheben)
  PLAN → [ TEST_FIRST → UMSETZUNG → VERIFIKATION ] pro Task
       → REVIEW
  (kein KLAERUNG, kein Plan-Dokument – der Report ist die Quelle)

AUDIT (Zustand prüfen, nichts ändern)
  REVIEW

MANUELLER-TEST (Nutzer hat getestet, Material liegt in der Inbox)
  TRIAGE → danach FIX

EINZELAUFTRAG (kleine, klar umrissene Änderung)
  UMSETZUNG → VERIFIKATION
  (kein Planner; der Orchestrator legt die Task-Datei selbst an.
   Zulässig nur, wenn der Auftrag 1–2 Dateien betrifft und prüfbare
   Akzeptanzkriterien hat – sonst ist es ein FIX oder FEATURE.)
```

### Die Klärungsschleife des Modus `REQUIREMENTS`

Der Planner kann den Nutzer nicht fragen und erinnert sich zwischen zwei
Aufrufen an nichts. Trotzdem ist ein mehrrundiges, thematisch geordnetes
Erarbeiten von Anforderungen möglich – weil der Orchestrator das Gespräch
führt und der **Zustand in der Datei liegt**, nicht im Kontext eines
Agenten:

1. `KLAERUNG` (a): Planner wählt **ein** Thema und schreibt höchstens
   sieben Fragen – je mit Begründung und Default-Vorschlag – als neue
   Runde ins Klärungsprotokoll von `state/AUFTRAG.md`.
2. Der Orchestrator stellt sie dem Nutzer wörtlich und trägt die Antworten
   in dieselbe Runde ein.
3. `KLAERUNG` (b): ein **frischer** Planner liest das Protokoll,
   formuliert das Thema in `spec/Requirements.md` aus und meldet als
   letzte Zeile `nächstes Thema: <…>` oder `keine offenen Themen`.
4. Der Orchestrator verzweigt daran: weitere Runde oder fertig. Nach fünf
   Runden ohne Abschluss stoppt er und fragt den Nutzer – eine Klärung,
   die nicht konvergiert, ist ein zu gross geschnittener Auftrag.

Dasselbe Muster trägt überall dort, wo ein kontextfreier Subagent etwas
"Interaktives" beitragen soll: nicht die Rolle interaktiv machen, sondern
den Zustand aus dem Agenten in eine Datei verlagern und den Orchestrator
die Runden takten lassen.

### Nicht verhandelbare Grundregel: strikt sequentiell, nie parallel

Unabhängig vom Modus gilt: Zu jedem Zeitpunkt ist genau **ein** Baustein
aktiv und genau **ein** Task "in Arbeit". Der nächste Task wird nicht
einmal geplant, solange der aktuelle nicht verifiziert und auf `done`
gesetzt ist. Jeder Baustein geht an einen **frischen Agenten** (echter
Aufruf, nicht "im Kontext weiterdenken"); der Orchestrator wartet auf die
vollständige Rückmeldung, bevor irgendetwas anderes passiert.

Begründung und der reale Vorfall, der zu dieser Regel führte: siehe
Lessons Learned Nr. 7.

### Start jeder Session

1. **Lage ermitteln** – mechanisch, nicht aus dem Gedächtnis:
   `spec/Architecture.md` (leer, aber Code vorhanden?), `.agent/tasks/*.md`
   nach `status: open`/`in_progress`, `.agent/inbox/` auf Material,
   `state/AUFTRAG.md` auf einen unterbrochenen Lauf.
   - Offene Tasks → dem Nutzer melden (Anzahl, Titel), fragen ob
     fortgesetzt werden soll oder etwas Neues Vorrang hat.
   - Material in der Inbox (auch zusätzlich zu offenen Tasks) → melden,
     fragen ob jetzt triagiert werden soll.
   - Gefülltes `AUFTRAG.md` mit unerledigter Arbeit → dort weitermachen
     statt neu zu klären.
2. **`AUFTRAGSKLAERUNG`** – immer, auch wenn der Nutzer schon gesagt hat,
   was er will. Ergebnis: `state/AUFTRAG.md`.
3. **Modus ableiten** aus `state/AUFTRAG.md`, Bausteine der Reihe nach
   abarbeiten, nach jedem Baustein das Verdict auswerten.
4. **Abschluss**: `state/AUFTRAG.md` (und, falls befüllt,
   `state/IMPLEMENTATION_PLAN.md`) nach `history/` archivieren und auf die
   leere Vorlage zurücksetzen.

### Task-Schleife im Detail

1. Nächsten Task ermitteln: `status: open`, alle Einträge in `depends_on`
   bereits `done`. Bei mehreren wählbaren Tasks: niedrigste ID zuerst.
2. Status auf `in_progress` setzen.
3. `TEST_FIRST` → `UMSETZUNG` → `VERIFIKATION` (siehe Test-Freeze unten).
4. Bei `CHANGES_NEEDED` aus der Verifikation: erneut `UMSETZUNG` für
   denselben Task, mit den fehlgeschlagenen Tests/Fehlermeldungen als
   zusätzlichem Kontext. Zurück zu `VERIFIKATION`. **Kein neuer Task
   beginnt, solange dieser nicht grün ist.**
5. Bei `PASS`: Status auf `done`, Test-Notizen in der Task-Datei, eine
   Zeile an `state/PROGRESS.md`, Git-Commit (Task-ID + Titel).
6. Keine offenen Tasks der Initiative mehr: `state/IMPLEMENTATION_PLAN.md`
   (falls befüllt) nach `history/<datum>-<slug>-plan.md` archivieren und
   zurücksetzen, Zusammenfassung an den Nutzer.

### Delta-fokussierte Wiederholungen

Wird ein Baustein nach einer Korrektur erneut gestartet, bekommt er den
Commit-Hash seines vorherigen Verdicts mit und prüft **nur die Commits
seither** – nicht den gesamten Stand von vorn. Das hält wiederholte
Review-Runden bezahlbar und den Kontext klein genug für kleine Modelle.

---

## Teil D – Runtime und Modell pro Rolle

Der Kern von v3: **eine Rolle ist nicht an den Harness gebunden, in dem
der Orchestrator läuft.** Das ist die Voraussetzung dafür, teure Denkarbeit
(Planner, Architekt, Reviewer) und billige Fliessarbeit (Implementer,
Tester) auf unterschiedlichen – auch lokalen – Modellen laufen zu lassen.

### Verifizierte Harness-Eigenschaften (Stand 2026-09-11)

Diese Fakten altern; vor grösseren Umbauten neu prüfen.

| Eigenschaft | Claude Code | OpenCode |
|---|---|---|
| Rollen-Dateien | `.claude/agents/*.md`, `name:` im Frontmatter | `.opencode/{agent,agents}/**/*.md`, **Dateiname = Agent-Name** |
| Modell pro Rolle | `model:` – **nur Anthropic** (Aliase oder Claude-IDs) | `model: provider/model-id`, **frei** |
| Lokales Modell pro Rolle | **nicht möglich** – Umleitung (`ANTHROPIC_BASE_URL`, Bedrock, Vertex) ist immer session-global | **ja** – Provider einmal in `opencode.json` (`@ai-sdk/openai-compatible` + `baseURL`), dann z.B. `model: ollama/<modell>` |
| Mischbetrieb (Rolle A Cloud, Rolle B lokal) | nein | ja, explizit vorgesehen |
| Werkzeug-Beschränkung | `tools:` / `disallowedTools:` (Listen) – **mechanisch erzwungen** | `permission:` (Map, `allow`/`ask`/`deny`) – **mechanisch erzwungen** |
| Pfad-Granularität | **nicht ausdrückbar** – nur über einen `PreToolUse`-Hook nachbaubar | **direkt**: `edit: { "*": allow, "tests/**": deny }`; letzte passende Regel gewinnt |
| Frischer Kontext je Aufruf | garantiert | garantiert (eigene Child-Session) |
| Schritt-Obergrenze | `maxTurns:` | `steps:` |
| Liest `AGENTS.md` | ja (via `CLAUDE.md`-Import) | ja, bevorzugt; `CLAUDE.md` nur als Fallback |
| Liest die Rollen-Dateien des anderen | – | **nein**, `.claude/agents/` wird nicht gescannt |

Weitere Claude-Code-Frontmatter-Felder: `permissionMode`, `memory`,
`background`, `skills`, `mcpServers`, `hooks`, `isolation: worktree`.
Weitere OpenCode-Felder: `mode: primary|subagent|all`, `variant`,
`temperature`, `top_p`, `disable`, `hidden`, `color`, `options`
(`tools:` ist dort zugunsten von `permission:` veraltet).

**Konsequenz:** Wer Rollen auf lokalen Modellen fahren will, kann das mit
Claude Code allein nicht – nicht als Einschränkung der Konfiguration,
sondern strukturell. Das bestätigt die bereits in v2 notierte Vermutung
(Lessons Learned Nr. 7) in schärferer Form.

### Eine Quelle, zwei Adapter

Das Dateiformat ist **nicht** harness-übergreifend kompatibel. Portabel ist
nur der Body; Frontmatter und Durchsetzung sind harness-spezifisch. Der
Body von Claude-Code-Rollen löst ausserdem **keine `@datei.md`-Imports**
auf (anders als `CLAUDE.md`-Memory) – ein Adapter kann den neutralen Body
also nicht importieren, er muss ihn enthalten.

Deshalb: neutrale Quelle plus generierte Adapter.

```
.agent/agents/implementer.md         # Quelle: reiner Rollen-Body, kein Frontmatter
.agent/agents/implementer.meta.yml   # Absicht, nicht Harness-Syntax
   role: implementer
   kind: subagent                    # subagent | primary
   description: ...                  # beide Harnesses brauchen sie
   model_tier: standard              # strong | standard | cheap
   write_access: full                # none | limited | full
   path_denies: ["tests/**"]         # bei full: Ausnahmen
   path_allows: []                   # bei limited: die einzigen erlaubten Pfade
   max_steps: 80

.agent/agents/_tiers.yml             # Stufe → konkretes Modell, je Harness
.agent/sync-agents.py                # Generator (abhängigkeitsfrei, Python 3)

→ generiert (nie von Hand editieren):
.claude/agents/implementer.md        # name/description/model/maxTurns/tools
.opencode/agent/implementer.md       # description/mode/model/steps/permission
```

`meta.yml` beschreibt **Absicht** (`write_access: full`, `path_denies`),
nicht Harness-Syntax. `_tiers.yml` ist der **einzige** Ort, an dem steht,
welche Stufe auf welchem konkreten Modell landet – dort stellt man eine
Rolle auf ein lokales Modell um, nicht in der Rollen-Datei. Ein dritter
Harness ist ein neues Generator-Template, keine Überarbeitung sämtlicher
Rollen-Dateien.

```bash
python3 .agent/sync-agents.py           # Adapter neu erzeugen
python3 .agent/sync-agents.py --check   # nur prüfen (Exit 1 bei Drift, für CI)
```

Was der Generator **nicht** heilen kann: Claude Code kennt keine
pfadbeschränkten Schreibrechte. Wo die Absicht eine braucht (Implementer
darf `tests/**` nicht anfassen), schreibt der Generator die Regel dort als
Text in den System-Prompt und verlässt sich zusätzlich auf die
Diff-Prüfung des Orchestrators (Teil E). In OpenCode wird dieselbe Absicht
zu einer echten `permission`-Regel.

### Aufruf einer Rolle in einem fremden Harness

Die Task-Datei entscheidet, wer ausführt:

```yaml
runtime: opencode              # subagent | opencode
model: ollama/<modell>         # optional, überschreibt meta.yml
```

Der Orchestrator ruft den fremden Harness als **Unterprozess** auf und
wartet auf dessen Ende:

```bash
timeout 900 opencode run \
  --agent implementer --dir . --auto \
  "Setze .agent/tasks/TASK-0007-<slug>.md um." \
  > .agent/runs/TASK-0007-umsetzung.log 2>&1
```

**Nicht** über zwei unabhängig pollende Schleifen. Der Grund ist nicht
Bequemlichkeit: zwei Prozesse, die dieselbe Task-Datei lesen und schreiben,
brauchen ein Lock-Protokoll, einen Heartbeat gegen hängengebliebene Läufe
und eine Regel, wer bei Uneinigkeit entscheidet – alles Protokoll, das per
Konvention eingehalten werden müsste. Der Unterprozess-Aufruf macht
dasselbe mechanisch: nur einer schreibt, Abbruch per `timeout`, kein
zweiter Entscheider.

Bekannte Eigenschaften von `opencode run` (Stand 2026-09-11), die den
Aufruf prägen:

- Relevante Flags: `--agent`, `--model provider/model`, `--dir` (nicht
  `--cwd`), `--format default|json`, `--session`/`--continue`, `--auto`.
- **Kein Timeout-Flag** – Gesamtlaufzeit von aussen begrenzen (`timeout`)
  oder im Server-Modus per `POST /session/:id/abort`.
- **Exit-Code ist kein dokumentierter Vertrag** – als Zusatzsignal
  brauchbar, nicht als alleinige Grundlage.
- `--format json` liefert undokumentierte Roh-Events und kann enden, bevor
  das finale Event geschrieben ist (offener Bug) – nicht auf das letzte
  Event als Abschlussmarker bauen.
- **Ohne `--auto` werden Berechtigungsanfragen headless nicht abgefragt,
  sondern still abgelehnt** (Warnzeile auf stderr), der Lauf geht weiter.
  Ergebnis wäre ein "erfolgreicher" Lauf, der nichts geschrieben hat. Das
  Log deshalb immer auf `auto-rejecting` prüfen.

Für viele Aufrufe hintereinander gibt es alternativ den Server-Modus
(`opencode serve`, Default `127.0.0.1:4096`, `POST /session` +
`POST /session/:id/message`, OpenAPI unter `/doc`, JS/TS-SDK
`@opencode-ai/sdk`). Achtung: dort führen `ask`-Berechtigungen zu einer
hängenden Session, weil es keine Oberfläche für die Rückfrage gibt –
Berechtigungen müssen vorab auf `allow` stehen oder über die
Permission-API beantwortet werden.

### Die Wahrheit steht in den Dateien, nicht im Log

Entscheidend, und der Grund, warum die obigen Schwächen nicht durchschlagen:
**der Orchestrator zieht sein Urteil nie aus der Ausgabe des
Unterprozesses.** Er prüft nach jedem fremden Lauf denselben Satz Quellen
wie bei einem eigenen:

```bash
git diff --name-only          # wurde etwas geändert – und nur, was `files:` erlaubt?
git status --porcelain        # unerwartete/ungetrackte Artefakte?
grep -l auto-rejecting .agent/runs/TASK-0007-*.log   # still an einer Berechtigung gescheitert?
```

plus die Task-Datei selbst (hat die Rolle ihren Abschnitt gefüllt?). Das
Log ist Protokoll für den Menschen, nicht Entscheidungsgrundlage für die
Maschine. Damit ist der Handoff harness-unabhängig: **die Task-Datei ist
das Protokoll zwischen den Runtimes**, genau wie sie es schon zwischen
frischen Sub-Agenten war.

---

## Teil E – Mechanische Härtung

Leitsatz: **Eine Prosa-Regel ist die letzte Wahl, nicht die erste.** Wo der
Harness oder ein Kommando dieselbe Zusage erzwingen kann, wird sie so
erzwungen. Bei kleinen/lokalen Modellen ist das kein Feinschliff, sondern
der Unterschied zwischen "hält" und "hält meistens".

| Zusage | Mechanisch durch | Prosa nur als Ergänzung |
|---|---|---|
| Reviewer/Architekt ändern nichts | `tools:`-Allowlist bzw. `permission: { edit: deny }` | "du editierst nie" |
| Implementer fasst keine Tests an | OpenCode `edit: { "tests/**": deny }`; Claude Code `PreToolUse`-Hook; zusätzlich Diff-Prüfung (unten) | "du editierst nie Testcode" |
| Frischer Kontext je Baustein | eigener Agenten-/Session-Aufruf | "lies nicht die Historie" |
| Kein Endlos-Lauf | `max_steps` / `steps` / `maxTurns`, `timeout` um den Unterprozess | – |
| Baustein nur wenn nötig | `git diff --name-only`-Bedingung | – |
| Task wirklich erledigt | Diff + Task-Datei prüfen, nicht der Selbstauskunft glauben | Selbst-Check-Liste in der Rollen-Datei |

### Test-Freeze

Die Tests eines Tasks entstehen **vor** seiner Implementierung und werden
danach eingefroren:

1. `TEST_FIRST`: Der Tester schreibt aus den Akzeptanzkriterien Tests, die
   **fehlschlagen müssen** (schlägt keiner fehl, prüft der Test entweder
   nichts oder das Verhalten existiert schon → `CHANGES_NEEDED` bzw.
   `BLOCKED`). Eigener Commit; dessen Hash ist die Freeze-Grenze.
2. `UMSETZUNG`: Der Implementer macht sie grün, ohne Testdateien
   anzufassen.
3. Der Orchestrator prüft das mechanisch:
   ```bash
   git diff <freeze-commit>..HEAD --name-only -- tests/
   ```
   Gibt das etwas aus, werden diese Änderungen verworfen und der
   Implementer bekommt den Verstoss als Kontext zurück.
4. `VERIFIKATION`: Der Tester führt die **gesamte** Suite aus – ein Task ist
   erst grün, wenn nichts anderes kaputtgegangen ist.

Das ist strikt stärker als "unabhängiger Tester im Anschluss": ein Tester,
der den fertigen Code vor sich hat, kann unbewusst gegen die
Implementierung statt gegen die Spezifikation prüfen.

**Ausnahme**, in der Task-Datei explizit zu markieren (`test_first: false`
plus Begründung): Tasks ohne prüfbares Verhalten – reine Doku-Änderungen,
Umbenennungen ohne Verhaltensänderung, Build-/Konfigurationsarbeit. Wer
die Ausnahme wählt, begründet sie in der Task-Datei; stillschweigend
weggelassen wird sie nie.

---

## Teil F – Dateistruktur (pro Projekt)

```
AGENTS.md                        # Projekt-Root, @-importiert agents/orchestrator.md
CLAUDE.md                        # Projekt-Root, @-importiert AGENTS.md

.agent/
  spec/                          # dauerhaftes Produktwissen (PascalCase –
                                 # relevant unabhängig von diesem Workflow)
    Requirements.md              # funktionale Anforderungen, ändert sich selten
    Architecture.md              # aktuelle Komponenten/Verantwortlichkeiten,
                                 # lebendig gehalten, keine Historie

  state/                         # veränderlicher Workflow-Zustand (SCREAMING_SNAKE)
    AUFTRAG.md                   # NUR das aktuell geklärte Anliegen samt
                                 # Klärungsprotokoll; leer, wenn nichts läuft
    IMPLEMENTATION_PLAN.md       # NUR die aktiv laufende Initiative; leer,
                                 # wenn gerade nichts läuft
    PROGRESS.md                  # Append-only chronologisches Log
    MEMORY.md                    # projektspezifische Notizen über Sessions hinweg

  sync-agents.py                 # Generator: neutrale Quelle → Adapter

  agents/                        # eine Datei pro Rolle (lowercase), harness-neutral
    _tiers.yml                   # model_tier → konkretes Modell, je Harness
    orchestrator.md / orchestrator.meta.yml
    planner.md / planner.meta.yml
    architect.md / architect.meta.yml
    implementer.md / implementer.meta.yml
    tester.md / tester.meta.yml
    reviewer.md / reviewer.meta.yml

  tasks/                         # die atomare, planbare Warteschlange (lowercase)
    TEMPLATE.md
    TASK-0001-<slug>.md

  reports/                       # datierte, read-only Review-Ausgaben
    2026-08-30-review.md

  inbox/                         # unstrukturiertes Rohmaterial aus manuellem Testen
    processed/<datum>/           # nach der Triage hierhin verschoben

  runs/                          # Logs fremder Harness-Läufe (nicht committen)
    TASK-0007-umsetzung.log

  history/                       # Archiv abgeschlossener Aufträge/Pläne
    2026-08-15-initial-build-auftrag.md
    2026-08-15-initial-build-plan.md

.claude/agents/                  # generierte Adapter – nicht von Hand editieren
.opencode/agent/                 # generierte Adapter – nicht von Hand editieren
```

Die Drei-Stufen-Schreibweise ist bewusst: `PascalCase` = kuratiertes
Referenzdokument über die Software selbst, `SCREAMING_SNAKE` = einzelner,
mutierbarer Zustand, `lowercase` = viele gleichartige Instanzen
(Rollen/Tasks/Reports). Wer eine Datei sieht, weiss am Namen, in welche
Kategorie sie gehört.

### Task-Datei-Format (`.agent/tasks/TASK-####-<slug>.md`)

Die Task-Datei ist die einzige Information, die eine ausführende Rolle
zusätzlich zum bestehenden Code braucht – und gleichzeitig das Protokoll
zwischen Runtimes. Sie muss deshalb **vollständig in sich geschlossen**
sein.

```markdown
---
id: TASK-0023
title: <kurzer, imperativer Titel>
status: open            # open | in_progress | done | failed | blocked
source: plan-step       # plan-step | review-finding | triage-finding | auftrag
source_ref: state/IMPLEMENTATION_PLAN.md#schritt-6
depends_on: []          # andere Task-IDs, die vorher done sein müssen
files: [pfad/zur/datei.py]

runtime: subagent       # subagent | opencode   – wer führt aus
model:                  # optional; überschreibt den model_tier der Rolle
test_first: true        # false nur mit Begründung im Kontext-Abschnitt
---

## Deliverable
<konkret: max. 1-2 Dateien/Module>

## Akzeptanzkriterien
- <prüfbare Bedingung 1>
- <prüfbare Bedingung 2>

## Kontext
<nur was nötig ist: exakte Zeilen-/Snippet-Referenzen, der Finding-Text,
Verweis auf den relevanten Architecture.md-Abschnitt – nicht die ganze
Datei, nicht die Konversationshistorie>

## Vorgaben aus dem Architektur-Gate
<vom Architekten befüllt, falls der Baustein lief: welche bestehende
Abstraktion zu nutzen ist, welche Grenzen gelten>

## Test-Notizen
<vom Tester befüllt: welche Tests geschrieben/ausgeführt, Ergebnis,
Freeze-Commit-Hash>
```

### Regeln für die Task-Grösse

- Ein Task betrifft max. 1–2 Dateien/Module. Ist er grösser, wird er vom
  Planner weiter unterteilt statt in einem Rutsch vergeben.
- Ein Task muss ohne Kenntnis anderer Tasks umsetzbar sein – Ausnahme:
  `depends_on` macht eine unvermeidbare Reihenfolge explizit.
- Jeder Task hat konkrete, prüfbare Akzeptanzkriterien (keine vagen
  Beschreibungen wie "funktioniert gut").
- Jeder Task lässt das Repo lauffähig und grün zurück.
- Läuft eine Rolle deutlich länger als erwartet oder meldet, der Task sei
  zu gross: **stoppen und neu schneiden**, nicht denselben Auftrag erneut
  starten und hoffen.
- Abhängigkeiten von externer Hardware/Diensten werden vermieden bzw.
  gemockt; Sonderfälle werden eigene, spätere Tasks.

---

## Teil G – Vorbereitung, Einstieg, Betrieb

### Vorbereitung (einmalig, vor dem ersten Task)

- **Berechtigungen im Voraus klären statt pro Aktion nachfragen.** Wenn
  bei praktisch jedem Dateizugriff einzeln um Erlaubnis gefragt wird, ist
  "selbständig durchlaufen lassen" nicht möglich. Vor dem ersten Task
  einmal explizit klären, in welchem Modus gearbeitet wird (Auto-Accept
  bzw. Allowlist, siehe Skill `fewer-permission-prompts`). Sub-Agenten
  erben denselben Modus. Bei fremden Runtimes zusätzlich beachten, dass
  eine ausbleibende Genehmigung dort still zur Ablehnung führen kann
  (siehe Teil D).
- **Lokales Git für nachvollziehbare Zwischenstände.** Kein Repo:
  `git init` + initialer Commit. Bestehendes Repo: nachfragen, ob auf dem
  aktuellen Branch weitergearbeitet oder ein eigener Branch für die
  Initiative angelegt wird.
- **Sandbox-Kontext prüfen.** Läuft die Session in der Agent-Sandbox
  (`tools/agent-workflow/sandbox/`), ist `.git` in der Regel read-only
  gemountet – kein `git commit`/`push` von dort. Stattdessen den fertigen,
  getesteten Diff vorbereiten und in `state/PROGRESS.md` vermerken:
  "bereit zum Commit: <Commit-Message-Entwurf>". Die Sandbox gewinnt an
  Bedeutung, sobald Rollen auf lokalen Modellen mit Auto-Approve laufen.

### Brownfield-Einstieg

Für ein bestehendes Projekt ohne (oder mit veralteter) `.agent/`-Struktur:
keine historische Plan-Rekonstruktion nötig.

1. `project-template/` in das bestehende Repo kopieren (nur die
   `.agent/`-Struktur + Root `AGENTS.md`/`CLAUDE.md`, Produktcode bleibt
   unverändert), Adapter generieren.
2. Baustein `MAP` laufen lassen: erzeugt `spec/Architecture.md` direkt aus
   dem Code – keine Bauhistorie nötig.
3. `spec/Requirements.md` füllen – als eigener Auftrag im Modus
   `REQUIREMENTS`. Falls eine funktionale Beschreibung bereits anderswo
   existiert (README, Ticket-System), gehört sie als Ausgangsmaterial in
   `state/AUFTRAG.md`: daraus ableiten und bestätigen lassen, statt aus dem
   Code zu raten.
4. Ab hier normaler Betrieb. Die erste Initiative ist häufig ein `AUDIT`,
   um den Ist-Zustand gegen die frisch erarbeiteten Requirements zu prüfen.

### Review-zu-Fix-Zyklus

1. `REVIEW` (oder `TRIAGE`) schreibt einen datierten Report unter
   `reports/` – Findings, keine Änderungen am Code.
2. `PLAN` liest den Report und erzeugt einen Task pro Finding (weiter
   unterteilt, falls ein Finding mehrere Dateien/Module betrifft).
3. Normale Task-Schleife.
4. Nach Abschluss aller Fix-Tasks: erneuter `REVIEW`-Durchlauf (neuer,
   datierter Report) zur Bestätigung – alte Reports bleiben erhalten (kein
   Überschreiben), damit sich der Zustand über Zeit nachvollziehen lässt.

### Umgang mit Nutzungs-/Rate-Limits

1. Sauber stoppen – keinen Task "halb" hinterlassen. Ist eine Rolle mitten
   im Task, dessen Status als `in_progress` (nicht `done`) belassen.
2. Reset-Zeitpunkt (Statuszeile der Umgebung) in `state/PROGRESS.md`
   notieren.
3. Falls `ScheduleWakeup` o.ä. verfügbar: Wakeup auf den Reset-Zeitpunkt,
   Prompt "Lies `.agent/tasks/` und mache als Orchestrator weiter."
4. Sonst: stoppen, Nutzer informieren, bei welchem Task pausiert wurde –
   dank der Task-Dateien geht kein Fortschritt verloren.

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
   widerspricht dem Kernprinzip aus Teil A ("eine Rolle liest nie die
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
   Baustein-Katalog (Teil B) macht die Zusammensetzung explizit, statt
   jeden Sonderfall als Abweichung von der einen Schleife zu behandeln.
2. **Rückmeldungen waren Prosa.** Der Orchestrator musste interpretieren,
   ob eine Rolle zufrieden war – eine Fehlerquelle genau bei den kleinen
   Modellen, für die die Methodik gedacht ist. Verdicts (Teil A) machen
   die Verzweigung greppbar.
3. **Rolle und Modell waren faktisch gekoppelt.** v2 empfahl zwar "für den
   Planner ein stärkeres Modell", ohne Mechanismus dafür. Teil D trennt
   die neutrale Rollen-Definition von der harness-spezifischen Zuordnung
   und beschreibt den Aufruf fremder Runtimes.

Zusätzlich neu: die **Architekt**-Rolle (prüft den Plan, bevor Code
entsteht – bis dahin prüfte nur der Reviewer, also erst hinterher), der
**Test-Freeze** (Teil E) und das explizite Überspringen von Bausteinen mit
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

---

## Lessons Learned

### Aus Projekt 1: Encrypted-Backup-Tool (v1, abgeschlossen)

1. **Berechtigungen waren der grösste Bremsklotz für "selbständig
   durchlaufen lassen".** Deshalb fester Vorbereitungs-Schritt (Teil G):
   Berechtigungsumfang vor dem ersten Task klären, Sub-Agenten erben
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
     Modell routen (Teil D) – für dieses Ziel ist es nicht suboptimal,
     sondern ungeeignet.
   - Die Regel "strikt sequentiell, nie parallel" steht mit konkretem
     Anti-Beispiel in `orchestrator.md` und `implementer.md`. Ein reales
     Gegenbeispiel steigert bei schwächeren Modellen die Befolgungsrate
     spürbar gegenüber rein abstrakten Anweisungen.
   - `implementer.md` hat einen End-of-Turn-Selbstcheck, der aktiv
     bestätigt werden muss ("nur dieser eine Task, nichts committet, nichts
     ersatzlos gelöscht").
   - **Wo der Harness mechanisch erzwingen kann, wird nicht auf
     Instruktionsbefolgung vertraut** – aus dieser Erkenntnis ist Teil E
     (Mechanische Härtung) entstanden: Werkzeug-Allowlists, Pfad-Denies,
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
