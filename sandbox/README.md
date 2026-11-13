# Agent-Sandbox: Build & Betrieb

Projektunabhängige Docker-Sandbox für Coding-Agents (z.B. Claude Code) im
"volle Freiheit"-Modus (`bypassPermissions`), ohne Host-Risiko. Der
Sicherheits-Hintergrund und die Begründung jedes Schritts stehen in
[`SANDBOX_BOOTSTRAP_PATTERN.md`](./SANDBOX_BOOTSTRAP_PATTERN.md) — dieses
README ist nur die praktische Kurzanleitung Build+Start+Selbstcheck.

## 1. Image bauen

```bash
cd tools/agent-workflow/sandbox
docker build -t agent-sandbox:latest .
```

Enthält: Node 22, beide Agent-CLIs (`claude` und `opencode`), Python 3 +
venv/pip, JDK 25 (Eclipse Temurin) + Maven 3.9, git, curl, jq/bc (für die
Statuszeile), sudo.

OpenCode ist auch dann nötig, wenn der Mensch nur `claude` startet: der
Orchestrator ruft einzelne Rollen per `opencode run --agent <rolle> --auto`
als Unterprozess auf, sobald deren Task `runtime: opencode` trägt (siehe
`../HARNESS.md`).

Bewusst **ein gemeinsames Polyglott-Image** statt mehrerer abgeleiteter:
Layer werden von allen Containern geteilt, der Platz wird also einmal
bezahlt und nicht je Container; zur Laufzeit kostet die Grösse nichts, weil
Layer gemountet statt kopiert werden — ein ungenutztes JDK belegt weder RAM
noch CPU und verlängert den Container-Start nicht.

Java-/Maven-Versionen sind als `ARG` gepinnt und beim Build überschreibbar:

```bash
docker build --build-arg TEMURIN_MAJOR=21 -t agent-sandbox:latest .
```

Zwei Details, falls das jemand anpasst: Das JDK kommt aus dem
Adoptium-Repo, weil Debian bookworm per apt nur JDK 17 liefert. Maven kommt
als Apache-Tarball (checksum-verifiziert) statt per `apt install maven`,
weil das Debian-Paket `default-jre-headless` nachzieht und damit ein
zweites, älteres JDK neben Temurin installieren würde.

Projektspezifisches Setup darüber hinaus (z.B. `.venv-backup-tool`,
`requirements.txt`, `npx playwright install --with-deps`) macht der Agent
selbst beim Start gemäss dem jeweiligen Projekt-`AGENTS.md` — dieses Image
bleibt ansonsten generisch/projektunabhängig.

Läuft als Non-Root-User `agent` (mit passwortlosem `sudo` innerhalb des
Containers) statt als root: Claude Code verweigert `bypassPermissions`
(`--dangerously-skip-permissions` bzw. `defaultMode: "bypassPermissions"`)
für root/sudo-Prozesse. `apt-get`/Paketinstallationen funktionieren über
`sudo apt-get ...` weiterhin ohne Rückfrage.

## 2. Sandbox starten

```bash
./run-sandbox.sh /pfad/zum/projekt
```

Das Projekt muss ein Git-Repo mit mindestens einem Commit sein. Der
Agent arbeitet **nicht** in deinem Ordner, sondern in einem eigenen Klon,
der nur in einem Docker-Volume liegt (`agent-<projekt>-work`, im
Container `/work`). Beim ersten Start schiebt das Skript deinen aktuell
ausgecheckten Branch hinein – nur Committetes – und trägt in deinem Repo
das Remote `agent` ein. Resultate kommen ausschliesslich über Git zu dir;
wie, zeigt der Abschnitt [Commit-Flow](#commit-flow-der-agent-committet-nur-du-pushst).
Landet in einer interaktiven `bash`-Shell im Container.

Der Container heisst `agent-<projektordnername>` und läuft bewusst
**ohne `--rm`**: nach `exit` bleibt er (gestoppt) erhalten. Ruft man
`run-sandbox.sh` für dasselbe Projekt erneut auf, wird **derselbe**
Container wiederverwendet (laufend → Skript steigt per `docker exec` ein,
gestoppt → `docker start -ai` setzt die Session fort) — praktisch, um eine
unterbrochene Session weiterzuführen, ohne aus Versehen eine zweite,
parallele Sandbox fürs gleiche Projekt zu starten.

Zeigen zwei Projekte mit demselben Ordnernamen an unterschiedlichen Orten
(z.B. `.../kunde-a/backend` und `.../kunde-b/backend`) auf denselben
Containernamen, bricht das Skript mit einer Fehlermeldung ab, statt
versehentlich die falsche Session zu öffnen — dann `--new` verwenden.

Soll bewusst ein **zusätzlicher, frischer** Container neben dem/den
bestehenden entstehen, bekommt er eine fortlaufende Nummer, ein eigenes
Volume und ein eigenes Remote (`agent-<projekt>-1`, Volume
`agent-<projekt>-1-work`, Remote `agent-1`):

```bash
./run-sandbox.sh --new /pfad/zum/projekt
```

**Container und Volume haben verschiedene Lebensdauern.** Der Container
ist austauschbar: Für ein neu gebautes Image `docker rm agent-<projekt>`
und neu starten – der neue Container setzt auf demselben Volume, also
demselben Klon, auf. Die Arbeit des Agenten ist erst mit
`docker volume rm agent-<projekt>-work` weg; vorher `git fetch agent`.

Nützliche Befehle:

```bash
docker ps -a --filter name=agent-<projekt>      # Container für dieses Projekt
docker volume ls --filter name=agent-<projekt>  # zugehörige Volumes
docker logs <name>                                # Terminal-Ausgabe der Session
docker rm <name>                                  # Container weg, Volume bleibt
```

**Früherer Betrieb mit geteiltem Ordner (`--shared`):** Projektordner als
Bind-Mount, `.git` read-only. Der Agent kann dann nicht committen – der
Orchestrator stoppt in diesem Fall – und schreibt live in deinen Ordner
(siehe [Warum kein geteilter Ordner](#warum-kein-geteilter-ordner)). Nur
noch, um alte Container weiterzuführen oder für Arbeit ganz ohne Commits.

## Dienste auf dem Host erreichen (Ollama, Postgres, …)

Im Container ist `localhost` der **Container selbst**. Dienste, die auf dem
Host laufen, erreicht man unter dem DNS-Namen `host.docker.internal`, den
Docker Desktop (macOS/Windows) automatisch anlegt:

```bash
curl http://host.docker.internal:11434/api/version     # Ollama auf dem Host
# jdbc:postgresql://host.docker.internal:5432/…        # Postgres auf dem Host
```

Auf Docker Desktop ist dafür kein Flag nötig; unter nativer Docker Engine
(Linux) schon. `run-sandbox.sh` setzt `--add-host=host.docker.internal:host-gateway`
deshalb immer — auf Docker Desktop ist es wirkungslos, unter Linux nötig.

**Ollama laeuft bewusst auf dem Host, nicht im Container** — im Container
gaebe es keinen GPU-Durchgriff (unter macOS grundsaetzlich nicht, unter
Linux nur mit `--gpus`, das dieses Skript nicht setzt). Ollama ist deshalb
auch nicht im Image enthalten.

Damit der Container es erreicht, muss es **an `0.0.0.0` gebunden** sein —
per Default bindet es nur an `127.0.0.1` und ist dann trotz
`host.docker.internal` nicht erreichbar:

```bash
OLLAMA_HOST=0.0.0.0 ollama serve       # auf dem Host, VOR dem Sandbox-Start
```

Das Image setzt passend dazu `OLLAMA_BASE_URL=http://host.docker.internal:11434/v1`,
worauf die `opencode.json` des Projekt-Templates verweist.

In der Sandbox zeigt die Anwendungskonfiguration also auf
`host.docker.internal` statt auf `localhost`. Was **nicht** geht: eine
Docker-Compose-Stack aus der Sandbox heraus *starten* — im Container gibt
es bewusst keinen Docker-Socket (siehe Selbstcheck unten). Auf eine vom
Host gestartete Stack *zugreifen* geht dagegen wie oben beschrieben.

## 3. Vor dem Bootstrap: Selbstcheck (Pattern-Doku Schritt 0)

**Vor** dem Aktivieren von `bypassPermissions` innerhalb der Sandbox
ausführen, um zu verifizieren, dass es wirklich eine nicht-privilegierte
Sandbox ist:

```bash
grep -i cap /proc/self/status        # keine CAP_SYS_ADMIN/PTRACE/MODULE/NET_ADMIN
grep -i seccomp /proc/self/status    # sollte "2" (SECCOMP_MODE_FILTER) sein
ls -la /var/run/docker.sock 2>&1     # muss fehlschlagen (kein Docker-Socket im Container)
ls -la /work | wc -l                 # Grösse sollte zum Projekt passen, nicht zum ganzen Host
ls /work/Users /work/Windows 2>&1    # muss in beiden Fällen fehlschlagen
```

Referenzwerte und Details: siehe `SANDBOX_BOOTSTRAP_PATTERN.md` Schritt 0.
Bei Abweichung: **nicht fortfahren**, Nutzer informieren.

## 4. bypassPermissions user-scoped setzen (Pattern-Doku Schritt 1)

Innerhalb der Sandbox, **nicht** im gemounteten `/work`:

```bash
mkdir -p ~/.claude
cat > ~/.claude/settings.json <<'EOF'
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
EOF
```

(Falls bereits eine `~/.claude/settings.json` existiert: mergen statt
überschreiben.)

## 5. Selbstcheck nach dem Bootstrap (Pattern-Doku Schritt 3)

```bash
cat ~/.claude/settings.json | grep -A2 permissions
ls /work/.claude/settings*.json 2>&1   # falls vorhanden: sicherstellen, dass dort KEIN bypassPermissions steht
git -C /work log --oneline -3          # der hineingeschobene Stand
git -C /work remote -v                 # muss leer sein: Klon im Volume, kein origin
touch /work/.git/.rw-probe && rm /work/.git/.rw-probe && echo "git: beschreibbar"
ls ~/.ssh 2>&1; env | grep -i -e token -e github   # muss leer sein: keine Push-Zugangsdaten
```

## 6. Agent starten

```bash
cd /work
claude
```

## Ohne Docker: runpod und ähnliche GPU-Container

Gemietete GPU-Pods sind selbst Container; dort bildet
`runpod/setup.sh` dieselbe Trennung mit Unix-Usern nach – Anleitung und
Stolpersteine in `runpod/README.md`.

## Commit-Flow: der Agent committet, nur du pushst

Das ist das **einzige Interface** zwischen dir und der Sandbox: Es gibt
keinen geteilten Ordner, Resultate kommen nur als Git-Commits zu dir, und
Material für den Agenten geht nur als Git-Commit zu ihm.

```
 DEIN RECHNER (Host)                                  DOCKER
 ═══════════════════════════════════════              ═══════════════════════════════════════

 ~/code/<projekt>/        ◀── nur du                  Sandbox-Container  agent-<projekt>
 ├── .git/                    (VS Code, Terminal)     ┌───────────────────────────────────┐
 │   ├── config                                       │  Claude Code / opencode            │
 │   │    remote "origin" → GitHub                    │  keine Zugangsdaten                │
 │   │    remote "agent"  → /work                     │                                    │
 │   │      uploadpack  = agent-remote.sh …           │  /work ◀── Volume                  │
 │   │      receivepack = agent-remote.sh …           │  │        agent-<projekt>-work     │
 │   ├── hooks/  (deine)                              │  ├── .git/  gehört dem Agenten:    │
 │   └── refs/remotes/agent/<slug>  ◀──┐              │  │          Hooks, Config – egal,  │
 ├── .agent/ …                         │              │  │          läuft nie bei dir      │
 └── (dein Arbeitsstand)               │              │  └── Code, Tests, .agent/ …        │
                                       │              │                                    │
        │ (4) push                     │ (1) fetch    │  Branches:                         │
        ▼                              │              │   agent/<slug>  ← der Agent        │
  ┌────────────┐                       │              │   nutzer/inbox  ← von dir          │
  │   GitHub   │                       │              └───────────────────────────────────┘
  │  (origin)  │                       │                          ▲
  └────────────┘                 Wegwerf-Container auf demselben Volume,
        ▲                        ohne Netz: git-upload-pack (1) bzw.
        │                        git-receive-pack (3) läuft DORT
        │                                                         │
        └── nur du, nach (2)   (2) review-branch.sh,       (3) push nutzer/inbox
                                   VS Code: Compare, Graph
```

| Ort | Was | Wer schreibt | Wer liest |
|---|---|---|---|
| `~/code/<projekt>` (Host) | dein Repo, dein Arbeitsstand, deine Hooks | nur du (und `fetch`) | du, VS Code |
| Volume `agent-<projekt>-work` | Klon des Agenten mit eigenem `.git` | nur der Agent | nur Container |
| Sandbox-Container | Claude Code, opencode; keine Zugangsdaten | – | – |
| GitHub | `origin` | nur du | alle |

### Die vier Abläufe (in deinem Ordner)

```bash
# (1) Holen – auch der Fetch-Knopf in VS Code; geht auch bei gestoppter Sandbox
git fetch agent                       # agent/<slug> des Agenten erscheint als agent/<slug>

# (2) Ansehen und prüfen – ohne auszuchecken
git log --oneline main..agent/<slug>
git diff main...agent/<slug>          # oder VS Code: Graph, "Compare with Branch…"
<pfad>/sandbox/review-branch.sh agent/<slug>

# (3) Material zum Agenten: hier committen, dann hinüberschieben
git push agent HEAD:nutzer/inbox      # der Agent übernimmt es von dort
git push agent main                   # neuer Basisstand, falls main bei dir weiter ist

# (4) Sichern und veröffentlichen – nur du, Merge per PR
git push origin agent/<slug>:refs/heads/agent/<slug>
```

Das volle Ziel `refs/heads/…` ist nötig: `agent/<slug>` ist bei dir ein
geholter Stand (Remote-Tracking-Branch), kein eigener Branch, und Git
rät das Ziel dafür nicht.

Der Agent committet nach jedem Baustein, der etwas geändert hat, und nach
jedem verifizierten Task. Nach einem `fetch` siehst du also jeden
abgeschlossenen Schritt – auch mitten in einer Klärung. Was er gerade
erst schreibt, siehst du nicht; für einen Blick mittendrin:
`docker exec agent-<projekt> git -C /work diff` (läuft im Container).

### Warum das sicher ist

- **Dein Git liest keine Datei aus dem `.git` des Agenten.** `fetch` und
  `push` sprechen nur das Git-Protokoll mit einem `git-upload-pack` bzw.
  `git-receive-pack`, das `agent-remote.sh` in einem Wegwerf-Container
  ohne Netz auf dem Volume startet. Hooks und Config des Agenten-Repos
  werden nur dort ausgewertet. Für deinen Rechner ist der Agent ein
  fremdes Remote wie jedes andere.
- **Der Agent kann nicht pushen** – der Container hat keine
  Zugangsdaten.
- **Was er dir unterschieben könnte, kommt nur als Commit**: Dateien wie
  `.vscode/tasks.json`, Skripte, `.gitmodules`, `.envrc`, Manifeste. Sie
  werden erst aktiv, wenn du den Branch **auscheckst** oder mergst.
  Deshalb vorher `review-branch.sh` (siehe unten) und den Agent-Branch
  nie ungeprüft auschecken.

### Warum kein geteilter Ordner

Früher lag dein Projektordner per Bind-Mount in der Sandbox, `.git`
read-only. Getestet (2026-11-02): Auch so kann der Agent Code auf deinem
Rechner zur Ausführung bringen, ohne `.git` anzufassen – etwa über ein
verschachteltes Repo `irgendwas/.git/config` mit `core.fsmonitor`, das
VS Code von selbst öffnet, oder über `.vscode/tasks.json` und `.envrc`,
und zwar sofort, ohne Commit. Mit beschreibbarem `.git` kommen weitere
Wege dazu (`.git/commondir`, Submodule), und jede gesperrte Stelle zieht
die nächste nach sich. Ohne geteilten Ordner entfällt die ganze Klasse:
Es gibt nur noch eine Tür, und an der prüfst du. Hintergrund:
`DECISIONS.md`, Lehre 20.

### Vor dem Push prüfen: `review-branch.sh`

Der Agent kann nicht pushen – was er gelöscht oder angerichtet hat,
erreicht GitHub erst mit deinem Push. `review-branch.sh` liest nur
Git-Objekte (kein Checkout, nichts aus dem Branch wird ausgeführt) und
warnt bei:

- gelöschten, geleerten oder stark gekürzten Dateien, Tests markiert,
- Dateien, die beim Build, in der CI oder beim Installieren laufen
  (Workflows, Skripte, Makefile, Manifeste mit Install-Skripten),
- Dateien, die den Agenten selbst steuern (`AGENTS.md`, `.claude/`,
  `.opencode/`, `.agent/agents/`, die Skripte unter `.agent/`),
- neuem Ausführbar-Bit, Symlinks, Submodulen, Binär- und grossen Dateien,
- Schlüsseln und Tokens sowie Mustern wie `curl … | sh` in neuen Zeilen
  (ausgegeben werden Datei und Art, nie die Zeile selbst).

Exit 1 heisst nicht "kaputt", sondern "diese Stellen im Diff lesen".
Eine Warnung zu `.agent/agents/` ist z.B. immer ein Grund zum Hinschauen:
Im normalen Ablauf ändert keine Rolle ihre eigenen Regeln.

Meldet `git fetch agent` einen `forced update`, hat der Agent schon
abgeholte Commits umgeschrieben. Der alte Stand ist bei dir noch im
Reflog (`git reflog show agent/<slug>`); vergleichen, bevor du pushst.

### Was nicht über Git läuft

Nicht versionierte Daten – Lauf-Logs und Messdaten unter `.agent/runs/` –
liegen nur im Volume. Holen mit `export.sh` im Container und danach auf
dem Host:

```bash
docker cp agent-<projekt>:/work/.agent/runs ./runs-<datum>
```

### Restrisiko

Commits seit deinem letzten `fetch` liegen nur im Volume. Ein
`docker volume rm` – oder ein Agent, der sein `.git` zerstört – nimmt sie
mit. Abhilfe ist der Rhythmus: nach jedem Auftrag bzw. jedem Nachtlauf
holen und pushen.
