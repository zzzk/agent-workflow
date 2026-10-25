# Entscheide zum Rückfluss (Quelle: `FRAMEWORK_RUECKFLUSS.md`)

Durchsprache mit dem Nutzer ab 2026-10-18. Umsetzung erst nach allen
Blöcken, je Block ein Commit (Commit auf dem Host – `.git` ist in der
Sandbox read-only).

## Block A – Begriffe & Ablauf (entschieden 2026-10-18)

- **A1 Begriffe:** "Modus" → **Auftragstyp**; Kette Auftrag → Auftragstyp →
  Ablauf (Bausteinfolge) → Baustein → Verdict; Glossar in
  `AGENT_WORKFLOW.md`. Reviewer-"Modi" heissen nach ihrem Baustein
  (`MAP`/`REVIEW`/`TRIAGE`). "Berechtigungsmodus" und die
  `run-role.sh`-Kommentare bleiben.
  Betrifft: orchestrator.md, reviewer.md, *.meta.yml, AGENT_WORKFLOW.md,
  MEMORY.md, AUFTRAG.md, README.md, USERMANUAL.md (+ generierte Kopien via
  sync-agents.py).
- **A2 Einschub-Tasks:** erlaubt, wenn gleiche Quelle/gleiches Ziel wie der
  laufende Auftrag, höchstens Einzelauftrag-Grösse, keine neue fachliche
  Klärung nötig. Teil-Task-ID `.N`, Zeile "Einschub: …, Grund" in
  `AUFTRAG.md` und `PROGRESS.md`. Sonst weiterhin "notieren, eigener
  Auftrag".
- **A3 `SPEC_REVIEW`:** neuer Reviewer-Baustein. REQUIREMENTS: am Ende der
  Klärungsschleife; FEATURE: nach `KLAERUNG`, vor `PLAN` – entfällt, wenn
  die Requirements frisch aus einem REQUIREMENTS-Auftrag mit SPEC_REVIEW
  kommen und unverändert sind. Prüft Vollständigkeit, Widerspruchsfreiheit,
  Prüfbarkeit (prüfbares Kriterium je Anforderung, sichtbare Texte
  festgelegt, Fehlerverhalten je Aktion, kein Widerspruch zu
  Architecture.md). Liefert Befunde, keine Fragen; Planner formuliert die
  Fragen mit Default (zusätzliche KLAERUNG-Runde). Einmal pro Initiative.
- **A4 Bezeichnung:** "Planner (Anforderungen und Planung)" nur in
  Doku/Diagramm; Rolle/Datei bleibt `planner`.
- **A5 Fragenzahlen:** bleiben (Auftragsklärung 5 Fragen, KLAERUNG-Runde 7
  Fragen, Klärungsschleife 5 Runden); jede Stelle sagt, wofür die Zahl
  gilt; orchestrator.md 3a: "Fragenzahl im KLAERUNG-Auftrag nicht vorgeben
  – steht in planner.md".

## Block H – Git/Commits (Grundsatzentscheid 2026-10-20)

Vorgezogen, weil er B und C beeinflusst. Verworfen: Wächter-Container,
Host-Wächterskript, GitHub-Rulesets (private Repos im persönlichen
Free-Account werden nicht durchgesetzt), Fork, git daemon.

- **H1 Agent hat lokal volles Git, pusht nie.** Er arbeitet in einem
  eigenen Klon des Projekts (`git clone` nach z.B.
  `~/agent-work/<projekt>`), dessen `.git` in der Sandbox beschreibbar
  gemountet wird. Keine Push-Zugangsdaten im Container (kein `~/.ssh`,
  kein Token) – das Remote bleibt damit geschützt. Pushen tut nur der
  Nutzer.
- **H2 Commit pro Task** auf einem Branch je Auftrag (`agent/<slug>`):
  Freeze-Commit nach `TEST_FIRST`, Commit bei `done`. Ersetzt die
  sha256-Snapshots als Freeze-Nachweis; `git diff` zeigt dem Implementer
  nur noch den eigenen Task. Merge nach master durch den Nutzer (Squash
  oder Merge, nach Wahl).
- **H3 Push durch den Nutzer = Sicherung und Übergabe** (präzisiert
  2026-10-20). Der Nutzer pusht jederzeit vom Host aus dem Klon des
  Agenten (`git -C ~/agent-work/<projekt> push origin agent/<slug>`), auch
  während der Agent arbeitet, und zieht den Branch auf sein Gerät zum
  Testen. Das Repo ist damit der Kanal fürs parallele Arbeiten/Testen –
  auch wenn der Agent auf runpod o.ä. läuft.
- **H4 Backup** = dieser Push. Restrisiko: Commits seit dem letzten Push.
  Vorgemerkt als spätere Option: automatischer append-only Abruf durch
  `run-sandbox.sh` (`git fetch` ohne `+`, ohne `--prune`).
- **H3a Sicherheitskorrektur (bei der Umsetzung 2026-10-24 gefunden):**
  Nie Git im Klon des Agenten auf dem Host aufrufen (auch nicht push) –
  der Agent kann dort Hooks/`core.fsmonitor` ablegen, die mit den Rechten
  des Nutzers liefen. Stattdessen aus der eigenen Kopie `git fetch
  <klon> agent/<slug>:agent/<slug>`, dann von dort pushen. Gilt
  sinngemäss auf runpod: root holt per fetch in einen root-eigenen Klon.
- **H5 Remote-Rechner (runpod o.ä.):** Push-Schlüssel dort nur mit
  Passphrase; kein laufender `ssh-agent`, dessen Socket der Agenten-User
  erreicht; nach Möglichkeit ein Deploy-Key nur für dieses Repo statt des
  persönlichen Schlüssels (begrenzt den Schaden, falls er abfliesst).
  Alternative ohne Schlüssel auf dem Pod: vom eigenen Gerät per SSH
  holen (geht nur mit direktem TCP-SSH, nicht über den runpod-Proxy).
- **Umsetzung Framework:** `run-sandbox.sh` Schalter `--git-rw` (Default
  bleibt read-only); `sandbox/README.md` Anleitung (eigener Klon,
  user.name/email lokal setzen, kein Schlüssel im Container);
  `orchestrator.md` Branch je Auftrag, Commit je Task, Freeze per Commit;
  sha256-Snapshot-Regel entfällt. Offene Frage aus dem Rückfluss
  ("Commit pro Task: wer, wie, Freeze per Commit oder Snapshot?") damit
  beantwortet; `commit-cp`/gitops-Wächter (runpod) wird nicht ins
  Framework übernommen, ausser für runpod selbst (→ Block G).

## Block B – Task-Lebenszyklus (entschieden 2026-10-20)

- **B1 "Vorgeschichte":** neuer Abschnitt in `TEMPLATE.md` zwischen
  "Kontext" und "Vorgaben aus dem Architektur-Gate"; normalerweise leer;
  Orchestrator trägt nach gescheitertem Lauf ein: Versuch, Rolle,
  Ausgang, was erreicht/offen, Log-Verweis. Teil-Tasks erben die
  Vorgeschichte des Eltern-Tasks. (Auslöser → Block C.)
- **B2 `superseded` + `superseded_by: [..]`** nur für begonnene Tasks;
  unbegonnene Tasks dürfen in place überarbeitet/neu nummeriert werden
  (lokaler Commit = Beleg). `depends_on` auf einen superseded-Task gilt
  als erfüllt, wenn alle `superseded_by` done sind.
- **B3 Teil-IDs `.N`** für Neuschnitt-Teile und nachträglich in die
  Reihenfolge eingeschobene Tasks (inkl. A2-Einschübe); Sortierung
  numerisch je Stufe (0037 < 0037.1 < 0037.2 < 0038), weitere Stufe
  erlaubt. Unabhängige neue Tasks weiterhin "höchste + 1".
- **B4 Neuschnitt-Muster** (planner.md, Verweis aus orchestrator.md):
  Teil-IDs nach B3, Eltern-Task superseded nach B2, eingefrorene Tests
  wörtlich übernommen, Beleg per `git diff <freeze-commit> -- tests/`
  (keine Referenzkopien unter `tasks/reference/`), eine Verhaltensfacette
  pro Teil-Task. Teilpunkt "Architecture-Eintrag als eigener Teil-Task"
  → D3.
- **B5 Zurückgestellte Findings:** bei Initiative-Abschluss (Schritt 9)
  als Liste in `MEMORY.md`; Orchestrator nennt sie bei der nächsten
  Auftragsklärung, die zu einer Umsetzung führt, und fragt – nicht
  automatisch anhängen.

## Block C – Scheitern & Timeout (entschieden 2026-10-20)

- **C1 Grundsatz:** erhöhte Prüftiefe nur, wenn die Task-Datei eine
  Vorgeschichte hat. Prinzip in `AGENT_WORKFLOW.md`; konkret: Tester →
  Grün-Probe (C2); Planner → schneidet beim Neuschnitt entlang der
  Fehlschlag-Stelle; Architekt → prüft eine Gate-Vorgabe erneut, wenn die
  Vorgeschichte einen Fehlschlag daran zeigt.
- **C2 Grün-Probe (tester.md, nur bei Vorgeschichte)** = Diagnose +
  zusätzliche Verifikation des Teilstands:
  1. Erfüllbarkeit der eingefrorenen Tests per Wegwerf-Implementierung
     ausserhalb des Repos (Scratch/`/tmp`), Code nicht weitergeben.
  2. Teilstand prüfen: Liste je Akzeptanzkriterium erfüllt/nicht erfüllt
     mit Beleg, gesamte Testsuite auf dem Teilstand.
  3. Grösse beurteilen aus: eigener Wegwerf-Lösung (Umfang, Zahl
     unabhängiger Verhaltensfacetten, nötiger Lesestoff), Teilstand
     (geordnet-unvollständig vs. wirr), Vorgeschichte/Log-Hinweisen
     (Dauer, Lese- vs. Schreibphase, Überlauf-Anzeichen: Dateien mehrfach
     gelesen, Todo-Liste wiederholt).
  4. Feste Zeile `Befund: VOLLSTAENDIG | FAST_FERTIG | TEST_UNERFUELLBAR |
     ZU_GROSS | ZU_VIEL_LESESTOFF`, mit offenen Kriterien bzw. Begründung
     bzw. Schnitt-Hinweis. Keine Zahlengrenze für FAST_FERTIG/ZU_GROSS –
     Urteil des Testers, aber konkret benannt.
- **C3 Entscheidungsregel (orchestrator.md Schritt 8)** – Tester urteilt,
  Orchestrator ordnet nur zu und prüft mechanisch auf Plausibilität
  (VOLLSTAENDIG ↔ grüne Suite in den Test-Notizen; FAST_FERTIG ↔ Liste
  offener Kriterien nicht leer; sonst zurück an Tester):
  - VOLLSTAENDIG → done, Grün-Probe zählt als VERIFIKATION.
  - TEST_UNERFUELLBAR → BLOCKED, Nutzerentscheid, dann derselbe Task mit
    korrigiertem Test (TEST_FIRST), nächste Versuchsnummer.
  - FAST_FERTIG → nächster Versuch auf dem Teilstand mit Korrekturliste.
  - ZU_GROSS → Neuschnitt durch Planner (B4).
  - ZU_VIEL_LESESTOFF → (1) derselbe Task mit Abschnitts-Wegweiser (nur
    falls Block D das erlaubt, sonst direkt 2); (2) bei erneutem
    Fehlschlag: Task-Override `model:`/`runtime:` (grösserer Kontext bzw.
    Cloud), in der Messung als Fallback gezählt; (3) immer beim ersten
    Auftreten: Strukturbefund notieren (z.B. Spec-Datei aufteilen) als
    Vorschlag für eigenen Auftrag. Wahl folgt der Regel, nicht dem
    Ermessen des Orchestrators.
  - Neuschnitt nur vor Erreichen der Versuchsgrenze; nach HALTED
    entscheidet der Mensch. Teil-Tasks beginnen bei Versuch 1.
  - Die Einzelregel "lokaler Timeout → Neuschnitt" entfällt.
- **C4 Abbruchgründe-Tabelle (orchestrator.md beim Aufruf):**
  - Exit 2 Konfigurationsfehler → Stopp, Setup reparieren, kein Versuch.
  - Exit 3 Timeout → Grün-Probe → C3.
  - Exit 3 "is a subagent" → Änderungen verwerfen, Stopp, Konfiguration
    prüfen, kein Versuch.
  - Exit 3 "auto-rejecting" → Log prüfen: legitim → Berechtigung mit
    Nutzer klären; unzulässig → Fehlversuch, Vorgeschichte, nächster
    Versuch.
  - Exit 4/5 → unverändert (Mensch entscheidet). Exit 6 → nativ aufrufen.
  - Noch nicht erkannt, kommt mit Block F: opencode-Exit 1 "no user
    query", Exit 0 "still gescheitert" (→ wie Timeout).
  - Hinweis: "Tatsächlich gelaufen" (Modell) wird angezeigt, aber nicht
    geprüft – ggf. in Block F/G.
- **Vorgemerkt für Block G:** Kontextauslastung/Token je Lauf messen,
  falls opencode/Ollama das hergeben (macht "Überlauf" belegbar).

## Block D – Wie der Planner Tasks schreibt (entschieden 2026-10-23)

- **D1 Task-Niveau "Auftrag für normalen Entwickler"** (R6 ins Framework):
  Ziel, Akzeptanzkriterien mit konkreten Werten, bindende
  Schnittstellenvorgaben, Quellenverweise, Wegweiser nur auf
  Komponentenebene aus `Architecture.md`. Kein fertiger Code, keine
  Ersetzungszeilen, keine vorformulierte Doku, keine Zeilennummern.
  Code-Lesen zum Finden der Stelle = Befund über `Architecture.md`.
  Betrifft planner.md ("Was du liest" 5, "Regeln für Tasks") und
  TEMPLATE.md (Kontext-Abschnitt).
- **D2 Landkarte zuerst:** Drift, die den heutigen Code falsch beschreibt,
  wird als Task(s) vor den Code-Tasks korrigiert.
- **D3 Variante (a):** Planner nimmt `Architecture.md` in `files:` auf,
  wenn sich Vertrag/Verantwortung ändert; keine separaten
  Doku-Nachzug-Tasks. Implementer-Regel "im selben Task nachziehen" bleibt.
  B4-Teilpunkt "Architecture-Eintrag als eigener Teil-Task" entfällt
  (ausser Drift-Korrektur nach D2).
- **D4 Abschnitts-Wegweiser erlaubt:** Abschnittsüberschrift (bzw.
  Kapiteldatei, siehe D7) der betroffenen Stelle; keine Zeilenbereiche,
  kein Inhalt, kein vorformulierter Text. Variante A/B vom 2026-10-04
  damit erledigt (A durch R6 verworfen, B = geregelter Fallback in C3).
- **D5 Vollständigkeits-Tasks** ("überall X ersetzen", z.B. Übersetzung):
  grep nie alleiniges Akzeptanzkriterium; Planner nennt Prüfregel
  (Wortstämme, keine Ausnahme "anderswo verwendet") und plant den
  Restbestand projektweit; Tester: Wort-für-Wort-Durchsicht ist der Test,
  grep nur Hilfe.
- **D6 Zuschnitt:** zusätzlich zu "max. 1–2 Dateien" gilt "eine
  Verhaltensfacette pro Task" (alle Modelle).
- **D7 Zielarchitektur (top-down) neben Ist-Architektur (bottom-up)**
  (Nutzer-Ergänzung, entschieden 2026-10-23):
  - Ziel: Systemkontext, Bausteine/Schichten + Verantwortung,
    Architekturregeln, Entscheidungen mit Begründung, Qualitätsziele.
    Architekt schlägt vor, **Nutzer entscheidet immer** (gebündelt als
    Vorschlagsliste mit Default). Implementer liest nur.
  - Ist: Komponenten wie heute im Code; Implementer (D3) und Reviewer
    (`MAP`) pflegen.
  - ARCHITEKTUR_GATE prüft den Plan gegen das Ziel; REVIEW prüft Ist gegen
    Soll (Abweichung = Finding); "Bekannte Abweichungen" = bewusst
    akzeptierte Lücke.
  - Neuer Architekten-Baustein `ZIELARCHITEKTUR`: Greenfield nach den
    Requirements vor dem ersten PLAN; Brownfield nach MAP (Vorschlag aus
    Ist + Requirements); im FEATURE-Ablauf, wenn noch keine existiert
    oder die Requirements sie berühren.
- **D8 Aufteilen grosser Spec-Dateien** (entschieden 2026-10-23), gilt für
  Architektur **und** Requirements:
  - Ordner statt Datei: `spec/architecture/` mit `README.md` (Index, 1–2
    Sätze je Kapitel, immer klein), `ziel.md`, `ist.md`,
    `abweichungen.md`, bei Bedarf `komponenten/<x>.md`.
    `spec/requirements/` mit Index + Kapiteldateien je Bereich.
  - Ziel/Ist von Anfang an getrennt (verschiedene Besitzer); weiteres
    Auslagern erst bei Überschreiten der Schwelle (~30 KB je Datei, ≈ ¼
    von 64k Kontext): grösster eigenständiger Teil in eigene Kapiteldatei,
    Index nachführen.
  - Orchestrator prüft mechanisch (`wc -c`) bei Initiative-Abschluss;
    Überschreitung → eigener Auftrag (wie Strukturbefund C3).
  - D4-Wegweiser nennt dann die Kapiteldatei.
  - Folgeänderungen: alle Verweise auf `spec/Architecture.md` /
    `spec/Requirements.md` in Rollen, Template, Doku, sync-agents.

## Block E – Einzelregeln (entschieden 2026-10-23)

- **E1 architect.md:** Gate-Vorgaben nur Schnittstellen/Verantwortungen.
  Erlaubt: Zuständigkeit je Modul, nötige Funktionen + Vertrag
  (Ein-/Ausgabe, Fehlerverhalten), Invarianten, betroffene Aufrufer.
  Nicht: Code, Zeilen-/Reihenfolgeangaben, Hilfsfunktions-/
  Strukturvorschläge.
- **E2 architect.md:** Prüffrage im Gate: "Würde ein Test für dieses
  Kriterium ohne die verlangte Änderung fehlschlagen?" (TEST_FIRST bleibt
  Rückfallnetz).
- **E3 depends_on aus dem Gate:** zusätzliche Abhängigkeit darf der
  Orchestrator selbst eintragen (+ Zeile in PROGRESS.md); Entfernen/
  Umbauen der Reihenfolge → Planner.
- **E4 (Referenz ausführen statt nachbauen): verworfen.**
- **E5 (Testvektoren aus produktivem Original): verworfen.**
- **E6 Test-Namenskonvention** als Pflicht-Architekturregel in der
  Vorlage `ziel.md`; Komponenten-Einträge listen keine Testdateien.
- **E7 Stufen-Kennzeichnung:** bei Requirements über mehrere
  Umsetzungsaufträge trägt jedes Kapitel die Stufe, Index mit Übersicht.
- **E8 tester.md:** grün nur ohne jede einzelne Fehler-/`not ok`-Zeile;
  Summenzeile allein genügt nicht.
- **E9 tester.md:** asynchrone Ergebnisse bedingt abwarten (`waitUntil`
  o.ä. mit Timeout), keine festen Ticks/Millisekunden.

## Block F – Verdict-Zeile & Wrapper-Prüfungen (entschieden 2026-10-23)

- **F1 alle Rollen:** wörtliches Muster "Deine Schlussnachricht beginnt
  mit der Zeile `Verdict: PASS` (bzw. PASS_WITH_NOTES, CHANGES_NEEDED,
  BLOCKED), ohne Formatierung. Ohne diese Zeile gilt der Lauf als nicht
  abgeschlossen." Planner zusätzlich seine Schlusszeile.
- **F2 orchestrator.md:** denselben Satz an jeden run-role.sh-Auftrag
  anhängen.
- **F3 run-role.sh:** Verdict-Prüfung nur in der letzten
  Assistenten-Nachricht (`^Verdict: (PASS|PASS_WITH_NOTES|CHANGES_NEEDED|BLOCKED)`);
  Fehlen melden + in Messdaten. `auto-rejecting`-Prüfung ebenso auf
  opencode-eigene Meldungen beschränken (Trennung Modelltext/opencode an
  echtem Log klären, Text- vs. `--format json`).
- **F4 Verdict fehlt:** mit Änderung in `files:` → VERIFIKATION
  entscheidet (gezählt als "ohne Verdict-Zeile"); ohne Änderung → F5.
  Ersetzt "fehlt → zurück an dieselbe Rolle". Änderung = Diff seit
  Commit vor dem Lauf (Block H).
- **F5 "still gescheitert":** exit 0 + keine Änderung in `files:` + keine
  Verdict-Zeile → eigener Abbruchgrund (Exit 3) → wie Timeout
  (Grün-Probe, C3).
- **F6 "no user query found in messages":** bekanntes Fehlerbild, Exit 3
  mit Hinweis "Kontextlänge prüfen (Vorflug)"; danach Grün-Probe.
- **F7 Modell-Gegenprobe:** tatsächlich gelaufenes Modell ≠ erwartet →
  Setup-Fehler (Exit 3, Stopp, kein Versuch verbraucht).
- **F8 implementer.md:** "nur die eigene Task-Datei lesen" nach oben in
  "Was du liest"; prüfen, ob opencode-Berechtigungen das Lesen anderer
  `.agent/tasks/*` sperren können – wenn ja, einbauen.

## Block G – Vorflug, Messung, Betrieb (entschieden 2026-10-23)

- **G1 Vorflug Ollama:** Modell kurz laden, dann `/api/ps`:
  `context_length` ≥ `num_ctx` aus opencode.json, sonst Stopp;
  `size_vram == size` (100 % GPU), sonst Stopp mit Hinweis (Kontext
  verkleinern / `iogpu.wired_limit_mb`). Beide Werte je Lauf in die
  Messdaten.
- **G2 Vorflug OpenAI-kompatibel** (LM Studio, Firmen-Server):
  `GET /v1/models` mit API-Key; Kontext/GPU-Anteil, wo nicht abfragbar,
  ausdrücklich "nicht prüfbar" melden.
- **G3 USERMANUAL Fehlertabelle:** doppelter Ollama-Server (App +
  `ollama serve`), Apple-Silicon-GPU-Limit (~2/3 RAM).
- **G4 Messung:** Kontextauslastung/Token je Lauf in `metrics.jsonl`,
  sofern opencode/Ollama sie liefern (bei Umsetzung klären).
- **G5 Messdaten-Export:** `export.sh` ins Framework; Orchestrator ruft
  ihn bei Initiative-Abschluss und vor Compact. **Skript fehlt – Nutzer
  liefert.**
- **G6 USERMANUAL:** unbeaufsichtigte Läufe in `tmux` (+ `caffeinate` auf
  dem Mac).
- **G7 Handy-Benachrichtigung:** `.claude/notify.sh` via Hooks
  `Notification`/`Stop` → `curl` an ntfy, ohne Inhalte; nur aktiv mit
  gesetztem `NTFY_TOPIC` (zufälliger Name), sonst No-op.
- **G8 Monitor-Skript neu** (`.agent/monitor.sh`; Original war nur ein
  Session-Behelf, Retro 7: pgrep fand sich selbst, alte Monitore liefen
  weiter): run-role.sh schreibt `.agent/runs/current.json` (PID, Rolle,
  Task, Versuch, Start, Timeout, Log) und löscht sie am Ende; Monitor
  liest nur diese Datei + `kill -0`, kein pgrep; Sperrdatei (eine
  Instanz); Zeile alle N s: Rolle/Task/Versuch, Zeit/Timeout, Loggrösse +
  "seit X min nicht gewachsen", VRAM; beendet sich mit Exit-Code/Grund.
  Für zweites Terminal und Claude-Code-Monitor-Werkzeug.
- **G9 Messbetrieb** als optionaler Betriebsmodus "lokal mit
  Cloud-Fallback": Schalter in `AUFTRAG.md`, Default aus; letzter
  erlaubter Versuch einer lokalen Rolle über Cloud, in Messdaten als
  Fallback gezählt.
- **G10 runpod:** `runpod-setup-exp2.sh` nach `sandbox/runpod/` + README
  (Network Volume ohne chmod, `DEBIAN_FRONTEND=noninteractive`,
  Proxy-SSH ohne scp → `runpodctl`); an Block H angepasst (Agent lokal
  volles Git, Nutzer pusht mit Passphrase-Key; `gitops`/`commit-cp`
  entfallen). **Skript fehlt – Nutzer liefert.**

## Block I – Parallelität (entschieden 2026-10-23)

- **I1 Variante (a):** Grundregel "strikt sequentiell" bleibt. Bahnen-Regeln
  aus Track A (tests/-Tasks in eine Bahn, gleiche Datei → gleiche Bahn,
  Doku nach Übernahme der Code-Tasks, eigenes Arbeitsverzeichnis je Bahn,
  HALTED gilt für alle) nur als Vermerk "erprobt, später prüfen" in
  `AGENT_WORKFLOW.md`. Neu bewerten nach Auswertung der Experimente
  (dann ggf. optionaler Modus mit worktree/Klon + Branch je Bahn).

## Offen – vom Nutzer zu liefern

- `.agent/runs/export.sh` (G5) – geliefert: `input/export.sh`
- `runpod-setup-exp2.sh` (G10) – geliefert: `input/runpod-setup-exp2.sh`
→ nach `input/` legen.

## Nachtrag aus PROGRESS.md-Retro des Projekts (entschieden 2026-10-23)

- **R8** Subagenten-Rollen verweisen auf
  `tools/agent-workflow/AGENT_WORKFLOW.md` (in der Sandbox nicht
  vorhanden) → Verweis in Subagenten-Rollen streichen (Rollen in sich
  vollständig); Orchestrator behält ihn mit "falls vorhanden".
- **R10** Ablauf-Hinweis "Deliverable schreiben → Tests → Architecture →
  Verdict, keine ausgedehnten Vorab-Überlegungen" in den Standard-Auftrag
  (F2) – Hilfe, keine Garantie.
- **R12** opencode `headerTimeout`/`chunkTimeout` für den lokalen
  Anbieter in `opencode.json` erhöhen + Handbuch-Zeile (zu Block G).
- **R9/R11** (lange Denk-Steps, 64k knapp bei UI-Tasks): durch D6, D8,
  F8, G4 abgedeckt; nur Vermerk.
