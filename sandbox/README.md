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

Enthält: Node 22 (für die `claude` CLI), Python 3 + venv/pip, git, curl.
Projektspezifisches Setup (z.B. `.venv-backup-tool`, `requirements.txt`)
macht der Agent selbst beim Start gemäss dem jeweiligen Projekt-`AGENTS.md`
— dieses Image bleibt bewusst generisch/projektunabhängig.

## 2. Sandbox starten

```bash
./run-sandbox.sh /pfad/zum/projekt
```

Mountet das Projektverzeichnis nach `/work`, plus `/work/.git` zusätzlich
**read-only** (verhindert Commit/Push/`reset --hard`/etc. aus der Sandbox
heraus — siehe Pattern-Doku Schritt 2). Landet in einer interaktiven
`bash`-Shell im Container.

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
touch /work/.git/test_readonly 2>&1    # muss fehlschlagen ("Read-only file system")
git -C /work log --oneline -3          # muss trotzdem funktionieren
```

## 6. Agent starten

```bash
cd /work
claude
```

## Commit-Flow (Entscheidung für dieses Projekt)

Solange `.git` read-only gemountet ist, committet/pusht der Sandbox-Agent
**nicht selbst**. Er bereitet den fertigen, getesteten Diff vor und
vermerkt in `PROGRESS.md` (des jeweiligen Projekts) "bereit zum Commit:
\<Commit-Message-Entwurf>". Der Host-seitige Agent bzw. der Nutzer sichtet
den Diff und committet danach ausserhalb der Sandbox.
