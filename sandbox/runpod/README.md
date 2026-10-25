# Agent-Sandbox auf runpod (oder einem anderen gemieteten GPU-Container)

Ein runpod-Pod ist selbst ein Container – Docker und damit
`run-sandbox.sh` gibt es dort nicht. `setup.sh` bildet die Sandbox mit
Unix-Usern nach und folgt demselben Commit-Flow wie die Docker-Sandbox
(`../README.md`, "Commit-Flow"):

| User | darf | darf nicht |
|---|---|---|
| `agent` | Claude Code / opencode ausführen, im eigenen Klon arbeiten und **committen** | pushen (keine Zugangsdaten), root-Dateien lesen |
| `root` | pushen – mit einem Schlüssel **mit Passphrase**, über `agent-push` | Git im Klon des Agenten aufrufen (dort könnten Hooks des Agenten liegen, die dann als root liefen) |

## Einrichten

```bash
# als root im Pod
REPO=git@github.com:<owner>/<projekt>.git SETUP_CMD="npm ci" bash setup.sh
```

Das Skript fragt zweimal nach: Passphrase für den Push-Schlüssel, und ob
der ausgegebene öffentliche Schlüssel als **Deploy-Key mit Schreibrecht**
(nur für dieses Repo) auf GitHub eingetragen ist.

Danach:

```bash
su - agent
tmux new -s orch        # Session überlebt einen Verbindungsabbruch
claude
```

## Pushen

```bash
# als root, jederzeit – auch während der Agent arbeitet
agent-push agent/<slug>
```

`agent-push` holt den Branch per `git fetch` aus dem Klon des Agenten in
einen root-eigenen Klon und pusht von dort; die Passphrase wird jedes Mal
abgefragt. Keinen `ssh-agent` laufen lassen, dessen Socket der User
`agent` erreichen könnte – sonst kann er den entsperrten Schlüssel
benutzen.

## Stolpersteine (aus den Experimenten exp2/exp3)

- **Network Volume erlaubt kein `chmod`/`chown`** und ist für viele kleine
  Dateien langsam: Modelle und Repo auf die Container-Disk (`VOL`,
  Default `/opt/agent`). Die Container-Disk ist nach dem Löschen des Pods
  weg – also regelmässig pushen.
- **`apt-get` hängt an Rückfragen** ohne `DEBIAN_FRONTEND=noninteractive`
  (setzt das Skript).
- **Der runpod-SSH-Proxy (`ssh.runpod.io`) kann kein `scp`/`sftp`** und
  keine Befehle ausführen: Dateien mit `runpodctl send` / `runpodctl
  receive` übertragen. Direktes `git fetch` vom eigenen Rechner aus geht
  nur mit "SSH over exposed TCP" (öffentliche IP).
- **Kontextlänge und GPU-Anteil** vor dem ersten Lauf prüfen
  (`.agent/vorflug.sh` im Projekt): Auf einer RTX 3090 (24 GB) passten
  131k/262k Kontext nicht vollständig in den Grafikspeicher – das Modell
  lief teilweise auf der CPU. `OLLAMA_CONTEXT_LENGTH` im Template setzen.
- **Unbeaufsichtigt**: Session in `tmux`; Benachrichtigung aufs Handy über
  `NTFY_TOPIC` (siehe `USERMANUAL.md`, "Unbeaufsichtigte Läufe").
