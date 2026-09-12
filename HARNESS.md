# Referenz: Runtime, Modelle, Adapter

Harness-spezifisches Faktenwissen zum Agent-Workflow: welcher Harness was
kann, wie die Rollen-Adapter generiert werden und wie eine Rolle in einem
fremden Harness aufgerufen wird.

> **Diese Datei altert.** Die Eigenschaftsmatrix hat ein Stand-Datum und
> beschreibt Software, die sich weiterentwickelt – vor grösseren Umbauten
> nachprüfen. Die Methodik selbst (`AGENT_WORKFLOW.md`) ist davon
> unabhängig: sie sagt, *dass* Rolle und Runtime entkoppelt sind, nicht
> welche Flags heute gelten.
>
> Zum Verstehen des Workflows: `AGENT_WORKFLOW.md`. Zum Einrichten und
> Bedienen: `USERMANUAL.md`. Zu den Begründungen: `DECISIONS.md`.

---

## Der Grundsatz

**Eine Rolle ist nicht an den Harness gebunden, in dem der Orchestrator
läuft.** Das ist die Voraussetzung dafür, teure Denkarbeit
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
Diff-Prüfung des Orchestrators (`AGENT_WORKFLOW.md`, Teil D). In OpenCode
wird dieselbe Absicht
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
