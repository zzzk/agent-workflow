# Sandbox-Bootstrap-Pattern: freie Agent-Ausführung ohne Host-Risiko

> Projektunabhängiges Pattern. Entstanden während der Arbeit am
> `backup_tool`-Projekt (siehe `PROGRESS.md`/`AGENTS.md` in diesem Repo),
> aber nicht spezifisch dafür — gehört eigentlich neben
> `AGENT_WORKFLOW.md` in die allgemeine Tools-Sammlung
> (`C:\Users\sevi\Documents\tools\agent-workflow\`), nicht in dieses
> Projekt-Repo. Bitte dorthin verschieben/kopieren.

## Ausgangslage

Ein Coding-Agent (z.B. Claude Code) läuft in einer isolierten Sandbox
(Docker-Container, hier zusätzlich unter WSL2 auf Windows), damit er mit
möglichst wenig Rückfragen (inkl. Paketinstallationen, `apt-get`, `pip`
etc.) arbeiten kann. Das Projektverzeichnis wird per Bind-Mount vom Host in
die Sandbox gereicht (in diesem Fall als `/work`).

**Kernproblem:** Ein Bind-Mount ist eine echte Brücke zum Host-Dateisystem.
Jede Einstellung, die *innerhalb* des gemounteten Verzeichnisses landet
(z.B. `.claude/settings.local.json` im Projektordner), liegt physisch auch
auf dem Host — und würde greifen, falls derselbe Ordner später *ausserhalb*
der Sandbox (direkt auf dem Host) geöffnet wird. Ausserdem hat ein Agent im
"volle Freiheit"-Modus (`bypassPermissions`) keine technische Bremse mehr
gegen destruktive Aktionen wie `git push --force` oder `rm -rf` — die
einzig verbleibende Bremse wäre das eigene Urteilsvermögen des Modells,
kein hartes Gate.

Dieses Pattern löst beide Probleme, ohne auf die Freiheit (keine
Rückfragen bei Installationen etc.) zu verzichten:

1. **Bypass-Konfiguration user-scoped statt project-scoped setzen**
   (bleibt in der Sandbox, kann nicht auf den Host durchsickern).
2. **Git-Historie read-only in die Sandbox mounten** (Agent kann lesen,
   aber nichts zerstören/committen/pushen — das bleibt ein
   Host-only-Schritt).

---

## Schritt 0: Vor dem Bootstrap verifizieren, dass es wirklich eine isolierte Sandbox ist

Nicht blind vertrauen — kurz nachsehen, ob die Umgebung tatsächlich einer
nicht-privilegierten Docker-Sandbox entspricht, bevor `bypassPermissions`
aktiviert wird:

```bash
# Capabilities: sollte GENAU das Docker-Standard-Set sein (siehe unten),
# insbesondere OHNE CAP_SYS_ADMIN, CAP_SYS_PTRACE, CAP_SYS_MODULE, CAP_NET_ADMIN
grep -i cap /proc/self/status

# Seccomp-Filter sollte aktiv sein (Wert "2" = SECCOMP_MODE_FILTER)
grep -i seccomp /proc/self/status

# docker.sock darf NICHT im Container erreichbar sein (sonst trivialer
# Docker-in-Docker-Ausbruch möglich)
ls -la /var/run/docker.sock 2>&1   # sollte "No such file or directory" liefern

# Mount-Scope prüfen: das gemountete Projektverzeichnis muss eng
# begrenzt sein, NICHT das ganze Host-Laufwerk
ls -la /work | wc -l   # Anzahl sollte zur erwarteten Projektgrösse passen
ls /work/Users /work/Windows 2>&1   # sollte in beiden Fällen fehlschlagen
```

**Referenzwert Capabilities** (beobachtet in dieser Sandbox,
`CapEff: 00000000a80425fb`), dekodiert zu genau den 14 Docker-Standard-Caps:
`CAP_CHOWN`, `CAP_DAC_OVERRIDE`, `CAP_FOWNER`, `CAP_FSETID`, `CAP_KILL`,
`CAP_SETGID`, `CAP_SETUID`, `CAP_SETPCAP`, `CAP_NET_BIND_SERVICE`,
`CAP_NET_RAW`, `CAP_SYS_CHROOT`, `CAP_MKNOD`, `CAP_AUDIT_WRITE`,
`CAP_SETFCAP`. Falls zusätzlich `CAP_SYS_ADMIN`/`CAP_SYS_PTRACE`/
`CAP_SYS_MODULE`/`CAP_NET_ADMIN` gesetzt sind (oder `id` einen privilegierten
Modus andeutet) → **nicht fortfahren**, das ist keine Standard-Sandbox mehr.

Zusätzlich empfehlenswert: kurz testen, ob unautorisierter Netzwerk-Egress
tatsächlich blockiert ist (z.B. `timeout 3 bash -c "cat < /dev/tcp/8.8.8.8/53"`
sollte fehlschlagen/"connection refused" liefern, nicht durchgehen).

---

## Schritt 1: `bypassPermissions` NUR user-scoped setzen

**Voraussetzung: Non-Root-User.** Claude Code verweigert `bypassPermissions`
(egal ob per `--dangerously-skip-permissions`-Flag oder per `defaultMode` in
`settings.json`) mit der Fehlermeldung "`--dangerously-skip-permissions`
cannot be used with root/sudo privileges", sobald der Prozess als root läuft.
Das Sandbox-Image (`Dockerfile`) legt deshalb einen User `agent` an
(`USER agent`) mit passwortlosem `sudo` für Paketinstallationen — `claude`
läuft als `agent`, nicht als root. `~/.claude/settings.json` liegt dann unter
`/home/agent/.claude/settings.json`.

**Falsch** (leakt auf den Host, weil `/work` ein Bind-Mount ist):
```
/work/.claude/settings.json           # NICHT hierhin
/work/.claude/settings.local.json     # NICHT hierhin
```

**Richtig** (bleibt in der Sandbox, existiert nur im Container-Home,
das NICHT gemountet ist):
```
~/.claude/settings.json   # z.B. /root/.claude/settings.json
```

Bestehende Datei lesen, mergen (nicht überschreiben), Ergebnis z.B.:

```json
{
  "theme": "dark",
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
```

**Warum user-scoped und nicht project-scoped:** Öffnet man denselben
Projektordner später direkt auf dem Host (ausserhalb der Sandbox), nutzt
Claude Code dort das separate, unangetastete Host-`~/.claude/settings.json`
— die Bypass-Einstellung wandert nicht mit.

**Bekannte Restrisiken von `bypassPermissions`** (nicht verschweigen):
- Es gibt KEINE technische Unterscheidung mehr zwischen harmlos und
  destruktiv — auch `rm -rf`, `git push --force` etc. liefen ohne
  Rückfrage, wären `.git` nicht separat abgesichert (siehe Schritt 2).
- Ob explizite `permissions.deny`-Regeln unter `bypassPermissions`
  überhaupt noch greifen, ist nicht abschliessend verifiziert — lieber
  nicht darauf verlassen.
- Ein Agent mit Schreibzugriff auf `/work` könnte theoretisch selbst eine
  projekt-lokale `settings.json` mit permissiven Regeln anlegen, die dann
  (weil `/work` gemountet ist) mit dem Repo wandert. Vor dem Committen
  von `.claude/settings.json`/`.claude/settings.local.json`-Änderungen
  aus einer Sandbox-Session daher kurz gegenprüfen.

---

## Schritt 2: Git-Isolation — `.git` read-only in die Sandbox mounten

**Gewähltes Pattern** (von den drei geprüften Optionen): dasselbe, einzelne
Repo bleibt bestehen (kein zweites/verschachteltes "Git-in-Git"), aber
`.git` wird beim Sandbox-Start zusätzlich **read-only** über den normalen
Mount gelegt.

Beispiel (Docker-CLI-Syntax, Reihenfolge der `-v`-Flags wichtig — der
spezifischere Pfad muss NACH dem allgemeinen Mount kommen, damit er
darüberliegt):

```bash
docker run \
  -v "C:\Users\sevi\...\backup-tool:/work" \
  -v "C:\Users\sevi\...\backup-tool\.git:/work/.git:ro" \
  ...
```

**Auswirkung innerhalb der Sandbox:**
- `git status`, `git log`, `git diff`, `git show`, `git blame` etc.
  funktionieren normal (nur Lesezugriff nötig).
- `git commit`, `git push`, `git checkout -b`, `git reset --hard`,
  `rm -rf .git` etc. schlagen mit einem Read-only-Filesystem-Fehler fehl —
  das ist beabsichtigt, keine Fehlkonfiguration.

**Konsequenz für den Orchestrator-Workflow** (siehe `AGENTS.md` in diesem
Repo, Abschnitt "Git-Commit nach jedem vollständig grünen Schritt"): Diese
Anweisung muss angepasst werden, solange `.git` read-only gemountet ist.
Zwei Optionen:
- Der Agent in der Sandbox bereitet den fertigen, getesteten Diff vor und
  vermerkt in `PROGRESS.md` "bereit zum Commit: \<Commit-Message-Entwurf>";
  ein Mensch oder ein Host-seitiger äusserer Agent (mit Schreibzugriff auf
  das echte `.git`) führt den eigentlichen `git add`/`git commit`/`git push`
  ausserhalb der Sandbox aus, nachdem er den Diff gesichtet hat.
- Alternativ: `.git` nur für die reine Coding-Phase read-only lassen, und
  für die kurze Commit-Phase gezielt (ausserhalb dieses Bootstrap-Patterns,
  bewusst und manuell) neu mit Schreibzugriff mounten.

**Warum nicht die zuerst angedachte Variante ("`.git` komplett aus dem
Mount auslagern, gar kein Git in der Sandbox")**: technisch gleichwertig
sicher, aber der Agent verliert dabei auch die Lesbarkeit von Historie/Diff
innerhalb der Sandbox (nützlich fürs Debugging/Nachvollziehen). Read-only
ist der bessere Mittelweg: maximale Transparenz für den Agenten, null
Schreibrisiko für die Historie.

---

## Schritt 3: Selbstcheck nach dem Bootstrap

```bash
# Bypass-Setting sitzt wirklich user-scoped, nicht im Projekt-Mount
cat ~/.claude/settings.json | grep -A2 permissions
ls /work/.claude/settings*.json 2>&1   # falls vorhanden: prüfen, dass dort KEIN bypassPermissions steht

# .git ist tatsächlich read-only
touch /work/.git/test_readonly 2>&1   # muss fehlschlagen ("Read-only file system")
git -C /work log --oneline -3         # muss trotzdem funktionieren
```

---

## Schritt 4: Token-/Kontext-Verbrauch auch im Sandbox-Agenten sichtbar machen

Der äussere Agent (Host-seitige Claude-Code-Instanz) zeigt laufend
Tokenverbrauch/Kontextgrösse an. Das soll für Sandbox-Agenten genauso
verfügbar sein, damit man auch dort erkennt, wie voll der Kontext ist,
bevor es zu einer Auto-Compaction kommt.

**Hinweis von innen (Sandbox-Agent) an den äusseren Agenten:** ich kann von
hier aus nicht sehen, welche Einstellungen genau auf dem Host aktiv sind,
die diese Anzeige beim äusseren Agenten erzeugen — das muss der äussere
Agent selbst in seiner eigenen `~/.claude/settings.json` (Host-Seite)
nachsehen und dieselben Werte in die Sandbox übernehmen. Relevante
Kandidaten-Felder, die dafür in Frage kommen (in derselben user-scoped
`~/.claude/settings.json` **innerhalb** der Sandbox setzen, analog zu
Schritt 1 — NICHT projekt-scoped):

- **`"tui": "fullscreen"`** — voller Alt-Screen-Renderer mit Statusleiste
  (in dieser Sandbox bereits vorkonfiguriert vorgefunden, siehe
  `~/.claude/settings.json`). Falls eine neue Sandbox das nicht bereits
  gesetzt hat: ergänzen und prüfen, ob die Kontextanzeige danach sichtbar
  wird.
- **`"statusLine"`** — falls der äussere Agent eine eigene, skriptbasierte
  Statuszeile konfiguriert hat (die z.B. Tokenverbrauch/Kosten anzeigt),
  dieselbe Konfiguration 1:1 in die Sandbox übernehmen (Schema:
  `{"type": "command", "command": "..."}`, siehe Settings-Referenz).
- **`"totalTokensReminder"`** — Alternative/Ergänzung, die einen
  `<total_tokens>N tokens left</total_tokens>`-Block direkt in den Kontext
  einblendet (Werte: `"off"` (Default), `"infinite"`, `"fixed"`,
  `"countdown"`, `"padded-countdown"`). Nützlich zusätzlich zur reinen
  UI-Anzeige, v.a. wenn ein Sandbox-Agent ohne sichtbares Terminal
  (Hintergrund-/Batch-Betrieb) läuft und die Info sonst gar nicht ankäme.

**Vorgehen für den äusseren Agenten:** eigene `~/.claude/settings.json`
auslesen, prüfen welche der obigen Felder dort gesetzt sind (und mit
welchen Werten), dieselben Werte beim Bootstrap jeder neuen Sandbox in
deren user-scoped `~/.claude/settings.json` übernehmen — im selben Zug wie
`permissions.defaultMode: "bypassPermissions"` aus Schritt 1. Danach
visuell verifizieren (eine Sandbox-Session starten, prüfen ob die
Kontext-/Tokenanzeige tatsächlich erscheint), da ich von innen nicht
zweifelsfrei bestätigen kann, welches Feld ursächlich für die Anzeige beim
äusseren Agenten ist.

---

## Kurzfassung für einen frisch gestarteten Agenten in einer neuen Sandbox

1. Schritt 0 (Verifikation) ausführen — bei Abweichung vom erwarteten
   Capability-/Seccomp-/Mount-Profil **nicht** fortfahren, Nutzer
   informieren.
2. `~/.claude/settings.json` (NICHT `/work/.claude/...`) um
   `permissions.defaultMode: "bypassPermissions"` ergänzen (mergen, nicht
   überschreiben).
3. Prüfen, ob `.git` bereits read-only gemountet ist (Schritt 3,
   `touch`-Test). Falls nicht und der Host-seitige Mount-Befehl anpassbar
   ist: dem Nutzer den `-v ...:/work/.git:ro`-Zusatz vorschlagen (kann vom
   Agenten selbst nicht von innen umgesetzt werden — das ist ein
   Host-seitiger Docker-Start-Parameter).
4. Commit/Push bleiben, solange `.git` read-only ist, ein bewusster,
   separater Schritt ausserhalb der Sandbox (siehe Schritt 2, Konsequenz
   für Orchestrator-Workflow).
5. Eigene Host-`~/.claude/settings.json` auf `tui`/`statusLine`/
   `totalTokensReminder` prüfen und dieselben Werte in die user-scoped
   `~/.claude/settings.json` der Sandbox übernehmen (Schritt 4), damit
   Tokenverbrauch/Kontextgrösse auch im Sandbox-Agenten sichtbar sind.
   Danach visuell verifizieren.
