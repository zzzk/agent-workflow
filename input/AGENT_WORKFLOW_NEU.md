# Neues AGENT_WORKFLOW.md auf Basis des Berichts – Arbeitsstand

Stand 2026-11-01. Ergebnis eines Vergleichs von
`2026-09-30-bericht-teil-a-workflow.md` (Bericht, Teil A aus
pwd-transform, Stand 2026-10-03) mit `AGENT_WORKFLOW.md` (Stand nach dem
Framework-Rückfluss, Blöcke A–I). Noch nicht umgesetzt; zwei Fragen an
den Nutzer offen (unten).

Zum Weitermachen lesen: diese Datei, den Bericht, `AGENT_WORKFLOW.md`,
`input/FRAMEWORK_RUECKFLUSS_ENTSCHEIDE.md`.

## Befund: Darstellung vom Bericht, Inhalt vom Framework

Der Bericht ist die bessere **Darstellung**, aber inhaltlich älter als der
Rückfluss. Referenz für den Inhalt bleibt das Framework, normativ gelten
ohnehin die Rollen-Dateien unter `project-template/.agent/agents/`.

### Im Bericht veraltet

| Bericht | Heute |
|---|---|
| `SPEC_REVIEW` als "Vorschlag, noch nicht Teil des Ablaufs" | fester Baustein in `REQUIREMENTS` und `FEATURE` |
| `spec/Requirements.md`, `spec/Architecture.md` | Ordner mit Index; `architecture/ziel.md`, `ist.md`, `abweichungen.md` |
| Architekt nur `ARCHITEKTUR_GATE` | dazu `ZIELARCHITEKTUR` (a Vorschlag, b Übernahme; Nutzer entscheidet) |
| Grün-Probe: zwei Ausgänge | `GRUEN_PROBE` mit fünf Befunden: `VOLLSTAENDIG`, `FAST_FERTIG`, `TEST_UNERFUELLBAR`, `ZU_GROSS`, `ZU_VIEL_LESESTOFF` |
| Freeze per Prüfsummen | Freeze-Commit; Prüfung `git diff <freeze> -- tests/` + `git status --porcelain -- tests/` |
| `done` = "bereit zum Commit" | Commit nach jedem Baustein mit Änderungen und je Task auf `agent/<slug>`, Push nur durch den Nutzer |
| "heisst heute noch *Modus*" | Umbenennung erledigt |
| Bild 3: Implementer schreibt `Architecture.md` | Reviewer (`MAP`) und Implementer schreiben `ist.md`, `ziel.md` entscheidet der Nutzer |
| fehlt | Einschub-Tasks, wörtliche `Verdict:`-Zeile, Vorflug (`vorflug.sh`), still gescheiterte Läufe, Betriebsmodus lokal-mit-cloud-fallback |

### Im Bericht projektspezifisch (verallgemeinern oder weglassen)

Konkrete Modelle (qwen3.8:27b, Opus, Sonnet), `extension/`,
`tests/*.test.js`, die `node:test`-Lehre ("not ok zählt"), Timeout
90 Minuten (Framework-Default: 2700 s = 45 Minuten, `AGENT_ROLE_TIMEOUT`),
`state/FRAMEWORK_RUECKFLUSS.md`, die Beispiele aus pwd-transform.
Die `node:test`-Lehre allgemein formulieren: "Testergebnis aus den
Einzelzeilen, nicht aus der Summe".

### Was der Bericht besser macht (übernehmen)

- Linearer Einstieg: Bild 1 Beispielablauf mit Tabelle "wer – was entsteht".
- Nummerierte Pfeile mit Erklärtabelle je Bild, Legende zur Schreibweise.
- Bild 3: Matrix Rollen × Artefakte (schreibt / liest / Lebensdauer) –
  fehlt in AGENT_WORKFLOW ganz.
- Bild 4: Lebenszyklus eines Tasks als Zustandsdiagramm.
- Bild 5: alle Ausnahmen an einem Ort, als Bild und Tabelle.
- Rollen-Tabelle mit Spalte "Darf nicht", Schranken-Tabelle mit "Warum".
- "Die Idee in fünf Sätzen" (enthält Test-First und strikt sequentiell).
- Begriffe: acht statt fünf (dazu Rolle, Artefakt, Task).

### Was nur AGENT_WORKFLOW hat (darf nicht verloren gehen)

Baustein-Katalog mit Aktivierung; mechanische Aktivierung und
`SKIPPED`-Protokoll; Prüf-Linsen; Auftragsklärung vs. `KLAERUNG`
(Filter, kein Interview; max. 5 Fragen); `REQUIREMENTS`-Schleife
(max. 7 Fragen je Runde, 5 Runden); Begründung `SPEC_REVIEW` und
Ziel-/Ist-Architektur; Start jeder Session; Delta-fokussierte
Wiederholungen; Git-Abschnitt; Scheitern-Grundsatz; Härtungstabelle
(womit erzwungen); Rollen-Vertrag; Verdict-Tabelle mit Reaktion des
Orchestrators; Task-Datei-Format; Grössenregeln; Lebenszyklus-Details
(superseded, Teil-IDs, Neuschnitt, zurückgestellte Findings);
Dateibaum mit Namenskonvention; 30-KB-Regel für `spec/`; parallele
Bahnen (erprobt, nicht Methodik); "Wann anwenden".

### Widerspruch in AGENT_WORKFLOW selbst (beim Umbau beheben)

Bild 2 führt `EINZELAUFTRAG` über die Task-Schleife zu `REVIEW`; Teil C
sagt `UMSETZUNG → VERIFIKATION` (kein `TEST_FIRST`, kein `REVIEW`).

## Vorgeschlagene Gliederung

**Teil 1 – Der Workflow** (Form des Berichts, Inhalt von heute,
allgemein formuliert)

1. Die Idee in fünf Sätzen
2. Bild 1 Beispielablauf `FEATURE` – neu mit `SPEC_REVIEW` und
   (optional) `ZIELARCHITEKTUR`
3. Begriffe (acht)
4. Auftragstypen als Tabelle mit den Abläufen von heute
5. Bild 2a Ablauf `FEATURE`, nummerierte Pfeile, neue Bausteine
   (`ZIELARCHITEKTUR` gestrichelt: nur wenn `ziel.md` leer)
6. Bild 2b Task-Schleife mit Freeze-Commit und Commit bei `PASS`
7. Bild 3 Rollen und Artefakte mit `spec/requirements/`, `ziel.md`,
   `ist.md`, `abweichungen.md`; Modelle nur als Beispiel aus `_tiers.yml`
8. Bild 4 Lebenszyklus (`done` = verifiziert und committet)
9. Bild 5 Ausnahmen, Grün-Probe mit fünf Befunden; Tabelle ergänzt um
   fehlende Verdict-Zeile / still gescheitert, Umgebung fehlt → Vorflug
10. **Neu: Bild 6 Git-Fluss** – nach Entwurf B' (Abschnitt unten):
    Agenten-Klon nur im Volume der Sandbox, `fetch`/`push` über
    `docker exec`, `review-branch.sh`, Push nur durch den Nutzer.
11. Rollen-Tabelle mit "Darf nicht"
12. Schranken: Spalten Schranke / Warum / mechanisch erzwungen durch
    (ersetzt Teil D)
13. Wo was liegt

**Teil 2 – Referenz** (aus dem heutigen AGENT_WORKFLOW, gekürzt um das,
was Teil 1 zeigt)

- Baustein-Katalog, Aktivierung, Prüf-Linsen
- Auftragsklärung vs. `KLAERUNG`, `REQUIREMENTS`-Schleife,
  Begründung `SPEC_REVIEW`, Ziel-/Ist-Architektur
- Start jeder Session, Delta-Wiederholungen, Scheitern-Grundsatz,
  parallele Bahnen
- Rollen-Vertrag, Verdict-Vertrag, Task-Datei-Format, Grössenregeln,
  Lebenszyklus-Details, Dateibaum

**Entfällt:** heutiges Bild 1 (Aussage "keine Pfeile zwischen Rollen"
steckt in Bild 3 und einem Satz), heutiges Bild 3 (Sequenzdiagramm, geht
in Bild 2b auf).

**Nicht empfohlen:** den Bericht selbst zur Referenz machen. Er ist ein
datierter Stand; der Bericht verweist danach auf das neue
AGENT_WORKFLOW und behält nur das Projektspezifische.

## Git-Workflow (Übergabe 2026-11-02, Entwurf B')

Quelle: `input/2026-11-02-git-workflow-uebergabe.md` (aus dem Projekt
wiki-assistent). Sie ersetzt den bisherigen Stand, wo der Nutzer
entscheidet; bis dahin ist der Abschnitt Material.

Anforderungen des Nutzers, in seiner Reihenfolge: (1) Agent kann das
Remote nicht zerstören; (2) Diffs bei Bedarf in VS Code sehen, z.B. in
der Klärung; (3) Agent committet möglichst viel, Push beim Menschen;
(4) zweite Priorität: auf Remote-Hosts pusht evtl. der Agent; (5)
einfach für Menschen – kein zweiter Checkout von Hand.

Vorschlag aus der Übergabe: ein Ordner, `--git-rw`, dazu `.git/hooks`
als leeres Verzeichnis read-only, `.git/config` read-only, `.vscode/`
gesperrt; Git-Identität per Umgebungsvariablen.

**Geprüft (Git 2.39, Scratch-Repos, Marker-Datei als Beweis):**

| Weg | Ergebnis | Gegenmittel |
|---|---|---|
| `core.fsmonitor` in `.git/config` | läuft bei `git status` | `config` read-only (Vorschlag) |
| `.git/commondir` → fremdes Verzeichnis mit eigener `config` | **läuft** trotz unveränderter `config` | Datei `.git/commondir` mit Inhalt `.` read-only mounten (Verzeichnis oder leere Datei: Git bricht ganz ab) |
| Gitlink (Submodul) im Index + verschachteltes Repo mit `fsmonitor` | **läuft** bei `git status` und `git diff` des Menschen | Host: `git config --global diff.ignoreSubmodules all` (getestet: wirkt) – oder Gitlinks ganz verbieten |
| verschachteltes, nicht registriertes Repo (`sub/.git`) | Git selbst: läuft nicht; **VS Code** öffnet aber Repos in Unterordnern (`git.autoRepositoryDetection`, Tiefe 1) und ruft dort Git auf | Host-Benutzereinstellung, nicht Workspace: `"git.repositoryScanMaxDepth": 0` bzw. `autoRepositoryDetection` – zu prüfen |
| `.git/info/attributes` ohne Treiber in einer Config | läuft nicht | – (Treiber aus der globalen Host-Config, z.B. LFS, bleiben zu bewerten) |
| `git fetch` aus einem präparierten Agent-Repo (`fsmonitor`, `uploadpack.packObjectsHook`, `core.hooksPath`, Hooks) | läuft nicht; auch danach `diff`/`checkout` mit Gitlink nicht | – (bestätigt Abschnitt 5 der Übergabe) |

Folgerung: Der Vorschlag 4.1 ist **nicht vollständig**; mindestens
`commondir` und Submodule umgehen ihn. Beide lassen sich schliessen, aber
das Verfahren bleibt eine Sperrliste – Vollständigkeit ist nicht
beweisbar, und eine neue Git-Version kann neue Wege bringen. Der Weg über
verschachtelte Repos und VS Code betrifft **jede** Variante, in der der
Agent in den Ordner schreibt, den der Mensch in VS Code öffnet – auch den
heutigen mit read-only `.git`.

Weitere Befunde:
- **Remote-Schutz (4.3/4.5):** Branch-Schutz und Rulesets setzt GitHub
  bei privaten Repos im Free-Plan nicht durch (früher festgestellt). Auf
  diesem Weg ist weder "main serverseitig schützen" noch "Agent pusht nur
  `agent/*`" machbar; GitLab (Protected Branches auch im Free-Tier) oder
  ein bezahlter GitHub-Plan schon. Git-Host im Projekt wiki-assistent
  offen.
- **Identität bei read-only `config`:** `GIT_AUTHOR_NAME`,
  `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL` per
  `docker run -e` aus `run-sandbox.sh`, oder `~/.gitconfig` im Image.
  Kein Git-Befehl im normalen Ablauf (`switch -c`, `add`, `commit`,
  `diff`, `log`) schreibt in `config`; Upstream setzen, `remote add`,
  `submodule init` scheitern dann – gewollt.
- **Selbstcheck in der Sandbox:** `touch .git/hooks/x` und
  `git config --local foo.bar 1` scheitern, `cat .git/commondir` ergibt
  `.`, `git commit` geht.
- **Datei-Mount auf Docker Desktop (Mac):** bindet die Inode; schreibt
  der Mensch auf dem Host `config` per Umbenennen neu, sieht der
  Container den alten Stand. Kein Sicherheitsproblem, aber zu wissen.

**Varianten und Entscheid (Nutzer, 2026-11-02):**
- **A – ein Ordner, gehärtet: verworfen.** Grund: Es taucht immer
  wieder ein neuer Weg auf; eine Sperrliste wird nie fertig.
- **B – getrennter Klon auf dem Host, vom Werkzeug verwaltet:**
  weiterentwickelt zu B'.
- **C – Klon von Hand (bisheriger Stand):** wird durch B' ersetzt.
- **B' – Klon nur in der Sandbox: gewählt, als Entwurf.** Unten.

### Entwurf B': der Agenten-Klon lebt nur in der Sandbox

> **Gebaut 2026-11-02** (`sandbox/run-sandbox.sh`, `sandbox/agent-remote.sh`,
> README "Commit-Flow" mit Grafik, DECISIONS Lehre 20, TODO 8 für den
> Test an echtem Docker). Abweichungen vom Entwurf unten: Die Gegenstelle
> läuft nicht per `docker exec` in der Sandbox, sondern in einem
> **Wegwerf-Container ohne Netz auf dem Volume** – geht auch bei
> gestoppter Sandbox. Geholt werden nur `agent/*`, sie erscheinen beim
> Nutzer als `agent/<slug>` (nicht `agent/agent-<slug>`). Der frühere
> Betrieb bleibt als `run-sandbox.sh --shared` (ohne Commits); `--git-rw`
> ist entfallen. Push nach origin aus dem geholten Stand:
> `git push origin agent/<slug>:refs/heads/agent/<slug>`.

Grundidee: Zwischen Host und Sandbox gibt es **keinen geteilten
Ordner** mehr, nur noch das Git-Protokoll über `docker exec`. Das ist
das einzige Interface für Resultate; was der Agent liefert, kommt als
Commit an und wird geprüft, bevor es irgendwo aktiv wird.

```
 DEIN RECHNER (Host)                                 DOCKER (Sandbox)
 ════════════════════════════════════                ══════════════════════════════════════

 ~/code/<projekt>/        ◀── nur du                 Container  agent-<projekt>
 ├── .git/                    (VS Code,              ┌──────────────────────────────────┐
 │   ├── config               Terminal)              │  Claude Code / opencode           │
 │   │    remote "origin" → GitHub                   │  keine Zugangsdaten               │
 │   │    remote "agent"  → /work                    │                                   │
 │   │      uploadpack  = docker exec … upload-pack  │  /work  ◀── Volume                │
 │   │      receivepack = docker exec … receive-pack │  │         agent-<projekt>-work   │
 │   ├── hooks/  (deine)                             │  ├── .git/   (gehört dem Agenten:  │
 │   └── refs/remotes/agent/agent-<slug>  ◀─┐        │  │           Hooks, Config, alles  │
 ├── .agent/ …                              │        │  │           egal – bleibt hier)  │
 └── (dein Arbeitsstand)                    │        │  ├── .agent/ …                     │
                                            │        │  └── Code, Tests                   │
         │ (4) push                         │        │                                   │
         ▼                                  │        │  Branches:                        │
  ┌────────────┐               (1) fetch    │        │   agent/<slug>  ← committet       │
  │   GitHub   │      ════════════════════════════════   nutzer/inbox  ← von dir         │
  │  (origin)  │       Git-Protokoll über   │        └──────────────────────────────────┘
  └────────────┘       docker exec, upload- │                    ▲
                       pack läuft IM        │                    │ (3) push nutzer/inbox
         ▲             Container            │                    │     receive-pack läuft
         │                                  │                    │     IM Container
         └── nur du, nach (2)        (2) review-branch.sh ───────┘
                                         VS Code: Compare, Graph
```

| Ort | Was | Wer schreibt | Wer liest |
|---|---|---|---|
| `~/code/<projekt>` (Host) | Repo, Arbeitsstand und Hooks des Nutzers | nur der Nutzer (und `fetch`) | Nutzer, VS Code |
| Volume `agent-<projekt>-work` → `/work` | Klon des Agenten mit eigenem `.git` | nur der Agent | nur der Container |
| Container | Claude Code, opencode; keine Zugangsdaten | – | – |
| GitHub | `origin` | nur der Nutzer | alle |

**Abläufe**
1. **Holen:** `git fetch agent` im Ordner des Nutzers (auch Fetch-Knopf
   in VS Code). `git-upload-pack` läuft im Container; das Git des Hosts
   liest keine Datei aus dem `.git` des Agenten. Getestet mit einem
   Stellvertreter für `docker exec` (Pfad `/work` muss auf dem Host
   nicht existieren; aus dem präparierten Repo lief nichts).
2. **Ansehen:** VS Code "Compare with Branch" / Graph,
   `git diff main...agent/agent-<slug>`, `review-branch.sh` – ohne
   auszuchecken.
3. **Material zum Agenten:** im eigenen Ordner committen,
   `git push agent HEAD:nutzer/inbox`. `git-receive-pack` und damit die
   Hooks des Agenten-Repos laufen im Container. Auf den ausgecheckten
   Branch nimmt Git keinen Push an (`receive.denyCurrentBranch`).
4. **Sichern, veröffentlichen:** `git push origin agent/<slug>`, Merge
   per PR. Nur der Nutzer pusht.

**Erster Start (macht `run-sandbox.sh`)**
- Volume anlegen, darin ein leeres Repo; Identität des Agenten in
  dessen eigener Config (gehört ohnehin ihm).
- Im Repo des Nutzers das Remote `agent` mit `uploadpack`/`receivepack`
  eintragen (oder die Befehle ausgeben, falls der Nutzer das selbst
  will).
- Ausgangsstand per `git push agent <basis-branch>` hineinschieben –
  der Container braucht weder Netz zu GitHub noch Zugangsdaten.
- Statt des festen Containernamens ein kleines Host-Skript als
  `uploadpack`/`receivepack` (z.B. `sandbox/agent-remote.sh <projekt>
  upload-pack`): findet den Container, startet ihn bei Bedarf, meldet
  verständlich, wenn er fehlt.

**Was man in Kauf nimmt**

| Punkt | Lösung |
|---|---|
| Noch nicht geholte Commits liegen nur im Volume | benanntes Volume überlebt `docker rm` und Image-Neubau; weg nur mit `docker volume rm`. Rest: Commits seit dem letzten Fetch |
| Fetch nur bei laufendem Container | Host-Skript startet ihn |
| Nicht versionierte Daten (`.agent/runs/`, Logs, Messdaten) | `export.sh` im Container + `docker cp`, oder nur `.agent/runs/` als eigenen Ordner nach aussen mounten (ohne Git darin) |
| Uncommittete Zwischenstände unsichtbar | Agent committet nach jedem Baustein; Blick mittendrin per `docker exec agent-<projekt> git -C /work diff` (läuft im Container) |

**Was bleibt (Restrisiko)**
- Committete Dateien, die erst beim Auschecken/Mergen aktiv werden
  (`.vscode/`, Skripte, `.gitmodules`, `.envrc`, Manifeste): vor dem
  Auschecken und vor dem Push `review-branch.sh`. Den Agent-Branch nie
  ungeprüft auschecken.
- Das Git des Hosts verarbeitet Packs aus einer nicht vertrauenswürdigen
  Quelle – derselbe Fall wie bei jedem fremden Remote.

**Folgen für Regeln und Doku**
- `sandbox/README.md`: Commit-Flow neu, **mit der Grafik oben** – Wunsch
  des Nutzers: das ist das einzige Interface für Resultate und nicht
  alltäglich, also muss es im README auf einen Blick verständlich sein.
- `run-sandbox.sh`: Volume statt Bind-Mount von `/work`, Remote
  einrichten; `--git-rw` und der read-only-Mount von `.git` entfallen.
- `orchestrator.md`, Vorbereitung: statt "Ist `.git` read-only?" prüfen,
  dass `/work` kein Host-Mount ist und Commits gehen.
- Regel "im Klon des Agenten nie Git" entfällt – auf dem Host gibt es
  keinen. Neu: "Agent-Branch erst nach `review-branch.sh` auschecken".
- `review-branch.sh`: Branch-Namen der Form `agent/agent-<slug>`
  (Remote-Tracking) in Doku und Beispielen.
- USERMANUAL, MEMORY-Vorlage, AGENT_WORKFLOW (Bild 6), DECISIONS (neue
  Lehre: Sperrliste vs. kein geteilter Ordner, mit den Testbefunden).
- Projekt wiki-assistent: Abweichung "kein eigener Klon" wird
  gegenstandslos; Umstieg dort nach dem Bau.

**Zu prüfen beim Bau**
- `docker exec -i` (ohne `-t`) überträgt das Git-Protokoll binär sauber,
  auch auf Docker Desktop (Mac).
- VS Code nutzt beim Fetch die Remote-Config (`uploadpack`) – erwartet
  ja, da es die Git-CLI aufruft.
- Verhalten bei gestopptem/fehlendem Container, bei `--new`.
- Selbstcheck in der Sandbox: `/work` ist ein Volume (kein Host-Pfad),
  keine Zugangsdaten (`~/.ssh`, Tokens in `env`), `git commit` geht.

Offen ausserdem: optionaler "Prüfpunkt"-Modus vor Commits in
Klärungsbausteinen (Übergabe, Frage 6; Empfehlung: nein). Agent pusht
selbst (Anforderung 4): zurückgestellt – bei GitHub Free (privat) ohne
serverseitigen Branch-Schutz nicht sicher machbar.

## Offene Fragen an den Nutzer

1. **Eine Datei oder zwei?** Beide Teile zusammen etwa 45 KB. Empfehlung:
   eine Datei (Leser sind Menschen). Alternative: `AGENT_WORKFLOW.md` +
   `REFERENZ.md`.
2. **Wohin mit dem Bericht?** Liegt im Repo-Root
   (`2026-09-30-bericht-teil-a-workflow.md`). Vorschlag: nach `input/`
   als Vorlage, nach dem Umbau entfernen.

## Randbedingungen

- Grundsatz aus dem heutigen Dokument bleibt: keine Regel in
  abweichendem Wortlaut wiederholen; im Zweifel gilt die Rollen-Datei.
  Beim Schreiben jede Regel gegen `project-template/.agent/agents/*.md`
  prüfen.
- Verweise anderer Dateien auf Abschnitte von AGENT_WORKFLOW
  (`grep -rn 'AGENT_WORKFLOW' --include=*.md`) nach dem Umbau
  nachziehen (Teil A–E, "Scheitern: erst diagnostizieren" usw.).
- Mermaid wie im Bericht; Artefakte als Zylinder mit
  `classDef artefakt`.
