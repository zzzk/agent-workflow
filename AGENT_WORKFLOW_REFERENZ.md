# Agent-Workflow – Referenz

Zum Nachschlagen: was genau im Fall X gilt. Wie der Workflow als Ganzes
abläuft (Bilder, Begriffe, Rollen, Schranken), zeigt `AGENT_WORKFLOW.md`
– diese Datei setzt sie voraus.

> Normativ sind die Rollen-Dateien unter
> `project-template/.agent/agents/*.md`. Diese Referenz fasst sie zusammen
> und nennt die Begründungen; im Zweifel gilt die Rollen-Datei.

**Inhalt**
1. [Verträge](#1-verträge): Rollen-Datei, Verdict
2. [Baustein-Katalog](#2-baustein-katalog): Bausteine, Klärungen, Spec-Review, Ziel- und Ist-Architektur, Aktivierung, Prüf-Linsen
3. [Abläufe im Detail](#3-abläufe-im-detail): Auftragstypen, Einschübe, Klärungsschleife, Grundregel, Session-Start, Task-Schleife, Abschluss
4. [Test-Freeze](#4-test-freeze)
5. [Git](#5-git)
6. [Scheitern: erst diagnostizieren, dann reagieren](#6-scheitern-erst-diagnostizieren-dann-reagieren)
7. [Dateistruktur](#7-dateistruktur)
8. [Tasks](#8-tasks): Format, Grösse, Lebenszyklus

---

## 1. Verträge

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
<Exaktes Ausgabeformat: die Schlussnachricht beginnt wörtlich mit
"Verdict: <WERT>", ohne Formatierung; danach die Pflichtangaben; am
Ende je Beobachtung zum Workflow selbst eine Zeile "Workflow: …".>
```

Der Body enthält **kein** Frontmatter – er ist harness-neutral (siehe
`HARNESS.md`). Die harness-spezifischen Felder (`runtime`, `model_tier`,
Werkzeuge, Schreibrechte) liegen daneben in `<rolle>.meta.yml`;
`sync-agents.py` erzeugt daraus die Adapter unter `.claude/agents/` und
`.opencode/agent/`.

### Verdict-Vertrag

Jeder Baustein endet mit **genau einer** Verdict-Zeile: Die
Schlussnachricht beginnt wörtlich mit `Verdict: PASS` (bzw.
`PASS_WITH_NOTES`, `CHANGES_NEEDED`, `BLOCKED`), ohne Formatierung. Der
Orchestrator verzweigt danach mechanisch, statt Fliesstext zu
interpretieren.

Das wörtliche Muster ist nötig: Lokale Modelle lieferten das Verdict in
14 Läufen nie als erste Zeile und in wechselnder Form (`**PASS**`,
`## Verdict: PASS`, …). Deshalb steht der Satz in jeder Rolle **und** am
Ende jedes Auftrags des Orchestrators (dort hat ihn ein kleines Modell
zuletzt gesehen), und `run-role.sh` sucht die Zeile nur in der letzten
Antwort – nicht im ganzen Log, wo auch Zitiertes stehen kann.

| Verdict | Bedeutung | Was der Orchestrator tut |
|---|---|---|
| `PASS` | Auftrag erfüllt, nichts anzumerken | nächster Baustein des Ablaufs |
| `PASS_WITH_NOTES` | erfüllt, aber mit Hinweisen für nachfolgende Rollen | weiter; Notizen in die Task-Datei bzw. den Plan übernehmen. Eine **zusätzliche** Abhängigkeit aus dem Gate trägt er selbst in `depends_on` ein (mit Vermerk in `PROGRESS.md`); jede andere Änderung der Reihenfolge geht an den Planner |
| `CHANGES_NEEDED` | nicht erfüllt; die Begründung benennt konkret, was fehlt | zurück an die vorgelagerte Rolle, mit der Begründung als zusätzlichem Kontext |
| `BLOCKED` | kann nicht entscheiden – Information fehlt oder es ist eine Produktentscheidung | Stopp; Rückfrage an den Menschen, kein Weitermachen auf Verdacht |

Pflicht in jeder Rückmeldung, unabhängig vom Verdict: geänderte Dateien
und jede bewusst getroffene Annahme oder Abweichung vom Auftrag, mit
Begründung. `CHANGES_NEEDED` und `BLOCKED` ohne konkrete, überprüfbare
Begründung sind selbst ein Fehler und gehen an dieselbe Rolle zurück.

**Fehlt die Verdict-Zeile:** Liegt das Deliverable vor, entscheidet die
`VERIFIKATION` – geprüft wird das Ergebnis, nicht die Form der Meldung;
`PROGRESS.md` vermerkt "ohne Verdict-Zeile". Hat der Lauf nichts
geändert, ist er still gescheitert (Abschnitt 6).

---

## 2. Baustein-Katalog

Ein **Baustein** ist ein Aufruf genau einer Rolle mit genau einem
Auftrag. Bausteine sind unabhängig voneinander definiert; ein Ablauf ist
nur eine Reihenfolge daraus. Es gibt bewusst **keine feste Pipeline**:
Nicht jede Arbeit ist "Anforderung bis Auslieferung", und Bausteine, die
nichts zu tun hätten, werden gar nicht erst gestartet.

| Baustein | Rolle | Aktivierung | Input | Ergebnis |
|---|---|---|---|---|
| `AUFTRAGSKLAERUNG` | Orchestrator | **immer**, als erster Baustein jeder Initiative | Anliegen, Lage im Repo | `state/AUFTRAG.md` + der daraus abgeleitete Auftragstyp |
| `MAP` | Reviewer | Ist-Architektur leer, aber Code existiert | vorhandener Code | `spec/architecture/ist.md` |
| `KLAERUNG` | Planner | Anforderung unklar oder Requirements lückenhaft, oder Befunde aus `SPEC_REVIEW` | `state/AUFTRAG.md`, `spec/`, ggf. Spec-Review-Report | (a) Fragerunde im Klärungsprotokoll **oder** (b) ausformuliertes Thema unter `spec/requirements/`, je Anforderung eine ID, Ungeklärtes als `> OFFEN:`-Zeile |
| `SPEC_REVIEW` | Reviewer | einmal pro Initiative, nach der letzten `KLAERUNG` (Abläufe `REQUIREMENTS` und `FEATURE`; Ausnahme in Abschnitt 3) | `spec/requirements/`, `spec/architecture/ziel.md` | `reports/<datum>-spec-review.md` mit Befunden – keine Fragen |
| `ZIELARCHITEKTUR` | Architekt | nach `MAP`; im Ablauf `FEATURE` vor `PLAN`, wenn `ziel.md` leer ist | Requirements, Ist-Architektur, Code | (a) Vorschlagsrunde im Klärungsprotokoll, (b) nach Entscheid des Menschen `spec/architecture/ziel.md` |
| `PLAN` | Planner | immer, ausser bei `EINZELAUFTRAG`; im Ablauf `FEATURE` erst, wenn keine `> OFFEN:`-Zeile mehr steht | Anforderung oder Report | `tasks/TASK-*.md` mit `anforderungen:` (+ bei einer neuen Anforderung `state/IMPLEMENTATION_PLAN.md`) |
| `ARCHITEKTUR_GATE` | Architekt | Plan führt neue Komponente, Schnittstelle oder Abhängigkeit ein | Task-Set, `spec/architecture/` (Ziel und Ist) | Verdict + Vorgaben in den Task-Dateien – nur Schnittstellen und Verantwortungen, nie Code oder Zeilen |
| `TEST_FIRST` | Tester | pro Task, ausser `test_first: false` | nur die Akzeptanzkriterien des Tasks | fehlschlagende Tests + Commit (Freeze-Grenze) |
| `UMSETZUNG` | Implementer | pro Task | die vollständige Task-Datei | Code-Änderung, uncommittet |
| `VERIFIKATION` | Tester | pro Task, nach `UMSETZUNG` | Akzeptanzkriterien + Testlauf + `.agent/pruefungen.sh` | Verdict + Test-Notizen in der Task-Datei |
| `GRUEN_PROBE` | Tester | nur nach einem gescheiterten Lauf (Task hat eine Vorgeschichte) | Task-Datei mit Vorgeschichte, Teilstand, Tests | Diagnose + genau eine `Befund:`-Zeile |
| `REVIEW` | Reviewer | nach Abschluss einer Initiative, oder auf Wunsch | `spec/`, `state/AUFTRAG.md` (Umfang), Code, Testlauf, `.agent/pruefungen.sh` | `reports/<datum>-review.md` |
| `TRIAGE` | Reviewer | `.agent/inbox/` enthält Material | Inbox-Rohmaterial + Code | `reports/<datum>-triage.md`; Material nach `inbox/processed/<datum>/` |

### Auftragsklärung und `KLAERUNG`: zwei verschiedene Klärungen

Alle Rollen ausser dem Orchestrator sind Subagenten: einmal gestartet,
eine Rückmeldung, danach weg – sie können den Menschen weder fragen noch
auf eine Antwort warten. Deshalb liegt das Klären des Auftrags beim
Orchestrator, und sein Ergebnis ist eine **Datei** statt eines
Gesprächsverlaufs:

- Der Auftragstyp wird aus dem geklärten Auftrag abgeleitet, nicht aus
  dem Dateizustand plus einer Chat-Antwort.
- Nachfolgende Rollen lesen den Auftrag, statt ihn als Prosa gereicht zu
  bekommen – konsistent mit "eine Rolle liest nie die Gesprächshistorie".
- Eine unterbrochene Session (Rate-Limit, Absturz, anderer Rechner) kann
  den Auftrag wieder aufnehmen, weil er auf der Platte steht.

Die Auftragsklärung ist ein **Filter, kein Interview**: Gefragt wird nur,
wenn der Auftragstyp nicht eindeutig ableitbar ist, ein prüfbares
Erfolgskriterium fehlt, der Umfang offen ist oder das Anliegen etwas
Bestehendem widerspricht – dann höchstens fünf Fragen, jede mit einem
Vorschlag. Sonst schreibt der Orchestrator `AUFTRAG.md` direkt und nennt
in einem Satz, wovon er ausgeht. Fachlich entworfen wird hier nicht.

| Baustein | Rolle | Klärt | Grenze | Ergebnis |
|---|---|---|---|---|
| `AUFTRAGSKLAERUNG` | Orchestrator (im Dialog) | *Was für Arbeit, welcher Umfang?* | höchstens 5 Fragen | `state/AUFTRAG.md` + Auftragstyp |
| `KLAERUNG` | Planner (Subagent, je Runde ein Aufruf) | *Ist diese Anforderung planbar?* | höchstens 7 Fragen je Runde, ein Thema; höchstens 5 Runden | Fragen bzw. Anforderung unter `spec/requirements/` |

### `SPEC_REVIEW`: ein unabhängiges Auge auf die Anforderungen

Lücken in den Anforderungen fallen sonst erst während der Umsetzung auf –
beim Tester, beim Architekten oder als Neuschnitt durch den Planner, also
dann, wenn sie am teuersten sind (`DECISIONS.md`, Lehre 9). Der Planner
hat die Anforderungen selbst ausformuliert; seine Prüfung wäre eine
Selbstauskunft. Deshalb prüft der Reviewer sie einmal pro Initiative auf:

- **Prüfbarkeit**: jede Anforderung hat ein Kriterium, gegen das ein Test
  grün oder rot werden kann,
- **Vollständigkeit**: alle sichtbaren Texte sind festgelegt, das
  Fehlerverhalten ist für jede Aktion festgelegt; bei einer Oberfläche
  (UI oder CLI) für jede Aktion mit sichtbarem Ergebnis **alle
  Zustände** – Warten, Erfolg, jeder unterscheidbare Fehler – mit
  Darstellung und Text; jede neue oder geänderte Anforderung hat eine ID,
- **Widerspruchsfreiheit**: untereinander und gegenüber der
  Zielarchitektur (`spec/architecture/ziel.md`),
- **offene Marker**: jede Zeile `> OFFEN: …` ist ein Befund.

Er liefert **Befunde, keine Fragen**. Daraus formuliert der Planner in
einer zusätzlichen `KLAERUNG`-Runde die Fragen an den Menschen, je mit
Vorschlag – der Reviewer kennt den Menschen nicht, der Planner kennt das
Klärungsprotokoll. Nach dieser Runde folgt kein zweiter `SPEC_REVIEW`;
die Schleife ist begrenzt.

### Anforderungs-IDs und offene Punkte

Zwei Markierungen in `spec/requirements/` machen mechanisch prüfbar, was
sonst Ermessen wäre:

- **IDs** `R-<bereich>-<n>` (Bereich = Kapiteldatei, `n` fortlaufend je
  Kapitel, nie wiederverwendet; eine entfernte Anforderung bleibt als
  "entfällt" stehen). Der Planner vergibt sie in `KLAERUNG` (b) und trägt
  sie in `PLAN` je Task unter `anforderungen:` ein; der Tester zitiert sie
  am Test; der Reviewer belegt im `REVIEW` per `grep`, dass jede
  Anforderung im Prüfumfang einen Task und einen Test hat.
- **`> OFFEN: <Frage> – Vorschlag: <Default>`** an der Stelle, die die
  Antworten nicht entschieden haben. Der Planner rät nicht, er markiert.
  Vor `PLAN` und am Ende von `REQUIREMENTS` prüft der Orchestrator
  `grep -rn '^> OFFEN:' .agent/spec/requirements/`; Treffer führen zu
  einer Klärungsrunde genau dazu, bleiben danach welche, entscheidet der
  Mensch.

Übernommen aus dem Abgleich mit Journey Hero (`DECISIONS.md`); bewusst
ohne die Delta-Mechanik von OpenSpec.

### Projekt-Prüfbefehle (`.agent/pruefungen.sh`)

Was jeder Task ausser der Testsuite bestehen muss – Lint, Format,
Typprüfung, Build, Paritätschecks –, steht als Befehlsliste in
`.agent/pruefungen.sh`. Der Architekt schlägt die Liste in
`ZIELARCHITEKTUR` (a) vor, der Mensch entscheidet, (b) trägt sie ein und
nennt sie als Regel in `ziel.md`. Der Implementer führt sie vor der
Abgabe aus, der Tester in `VERIFIKATION` und `GRUEN_PROBE`, der Reviewer
im `REVIEW`; Exit ≠ 0 heisst nicht grün. Weil die Datei mitbestimmt, was
grün ist, gehört sie zum Test-Freeze (Abschnitt 4), und
`review-branch.sh` warnt bei jeder Änderung. Enthält sie nur Kommentare,
gibt es keine zusätzlichen Prüfungen.

### Zielarchitektur und Ist-Architektur

Die Architektur hat zwei Sichten mit verschiedenen Besitzern:

| | Zielarchitektur (top-down, `ziel.md`) | Ist-Architektur (bottom-up, `ist.md`) |
|---|---|---|
| Inhalt | Systemkontext, Bausteine/Schichten, Architekturregeln, Entscheidungen, Qualitätsziele | Komponenten wie heute im Code: Zuständigkeit, Schnittstelle, Abhängigkeiten, Invarianten |
| Wer schreibt | Architekt schlägt vor, der **Mensch entscheidet** | Reviewer (`MAP`), danach der Implementer je Task |
| ändert sich | nur durch bewussten Entscheid; Vorschläge aus dem Gate gehen über `ZIELARCHITEKTUR` (b) | mit jedem Task, der einen Vertrag ändert |

Das `ARCHITEKTUR_GATE` misst einen Plan am Soll, der `REVIEW` das Ist am
Soll; jede Abweichung ist ein Finding, ausser sie steht als bewusst
akzeptierte Lücke in `abweichungen.md`. Ohne Zielarchitektur gäbe es nur
die Beschreibung dessen, was zufällig entstanden ist – Gate und Review
hätten keinen Massstab (`DECISIONS.md`, Lehre 11).

### Aktivierung: mechanisch, wo es geht

Ein Baustein wird nicht nach Gefühl gestartet, sondern nach einer
überprüfbaren Bedingung. Wo eine Bedingung mechanisch prüfbar ist, prüft
der Orchestrator sie per Kommando statt sie einzuschätzen, z.B.:

```bash
# Liegt Rohmaterial zum Triagieren vor?
ls -A .agent/inbox/ | grep -v -e '^processed$' -e '^\.gitkeep$'

# Wurde eine Abhängigkeits-Manifestdatei angefasst?  → ARCHITEKTUR_GATE
git diff --name-only -- pyproject.toml requirements.txt package.json go.mod

# Welche Prüf-Linsen braucht der Review?
git diff --name-only
```

Die vollständigen Lage-Checks (leere Ist- bzw. Zielarchitektur, offene
Tasks, laufender Auftrag, Einträge im Backlog) stehen in
`orchestrator.md`, Schritt 1.

**Kein Baustein wird gestartet, dessen Ergebnis absehbar "nichts zu tun"
wäre.** Ein übersprungener Baustein wird aber in `state/PROGRESS.md`
protokolliert – mit der Bedingung, damit später nachvollziehbar ist, dass
er nicht vergessen wurde:

```
SKIPPED ARCHITEKTUR_GATE – keine neue Komponente/Abhängigkeit im Plan
(mechanisch geprüft: kein Manifest im Diff)
```

### Prüf-Linsen statt Spezial-Reviewer

Statt eigener Agenten für Sicherheit, Abhängigkeiten, UI usw. bekommt der
eine Reviewer **Linsen**, die der Orchestrator anhand des Diffs aktiviert:
*Sicherheit* bei Krypto-, Auth-, Eingabevalidierungs-, Dateisystem- oder
Netzwerk-Code, *Abhängigkeiten* bei geänderten Manifesten,
*Nutzeroberfläche* bei UI- und CLI-Änderungen, *Performance* bei Code,
der Daten lädt oder über sie iteriert (Datenbank, Netz, Dateien), oder
wenn das Gate dazu eine Vorgabe gemacht hat (Prüffragen in
`reviewer.md`, Tabelle in `orchestrator.md`, Schritt 4). Das hält die
Zahl der Rollen-Dateien klein und die Aktivierungsentscheidung
mechanisch.

Unabhängig von den Linsen prüft jeder `REVIEW` nach einer Initiative den
**Umfang**: gehört jede Änderung auf dem Auftrags-Branch zu einem Task,
und ist nichts gebaut, was laut `AUFTRAG.md` "draussen" ist? Das
Gegenstück vor dem Code ist der Gate-Prüfpunkt **Performance-Form**: ein
Aufruf je Element statt einer für alle, unbegrenzte Datenmengen,
langsame Arbeit auf dem Pfad, auf den der Nutzer wartet – was die Form
des Plans schon festlegt, ist im Gate billiger zu ändern als im Review.

---

## 3. Abläufe im Detail

Jede Initiative beginnt mit `AUFTRAGSKLAERUNG`; der Auftragstyp ist das
Ergebnis dieses Bausteins und steht in `state/AUFTRAG.md`. Ein Auftrag
ergibt genau einen Auftragstyp – fällt unterwegs etwas an, das einen
anderen bräuchte, wird das ein eigener Auftrag, kein Anhängsel
(`DECISIONS.md`, Lehre 10).

```
BOOTSTRAP (Brownfield, erstmalig)
  MAP → ZIELARCHITEKTUR(a: Vorschlag) → Mensch entscheidet
      → ZIELARCHITEKTUR(b: in ziel.md übernehmen)
  → danach neue AUFTRAGSKLAERUNG (meist REQUIREMENTS oder AUDIT)

REQUIREMENTS (Anforderungen erarbeiten – Deliverable ist spec/requirements/)
  je Thema: KLAERUNG(a: Fragerunde) → Mensch antwortet (über den Orchestrator)
          → KLAERUNG(b: Ausformulierung)
  bis der Planner "keine offenen Themen" meldet
  → SPEC_REVIEW → bei Befunden: eine KLAERUNG-Runde (a + b) dazu
  → Check auf "> OFFEN:"-Zeilen
  (kein PLAN, keine Tasks, kein Code – die Umsetzung ist ein neuer Auftrag)

FEATURE (neue Anforderung umsetzen)
  KLAERUNG → SPEC_REVIEW → bei Befunden: eine KLAERUNG-Runde dazu
           → ZIELARCHITEKTUR (a, b) – nur wenn ziel.md noch leer ist
           → Check auf "> OFFEN:"-Zeilen (Treffer: KLAERUNG-Runde dazu)
           → PLAN → ARCHITEKTUR_GATE
           → [ TEST_FIRST → UMSETZUNG → VERIFIKATION ] pro Task
           → REVIEW
  (SPEC_REVIEW entfällt, wenn die Requirements unverändert aus einem
   REQUIREMENTS-Auftrag mit SPEC_REVIEW stammen – siehe unten)

FIX (Findings aus einem Report beheben)
  PLAN → [ TEST_FIRST → UMSETZUNG → VERIFIKATION ] pro Task
       → REVIEW
  (kein KLAERUNG, kein Plan-Dokument – der Report ist die Quelle)

AUDIT (Zustand prüfen, nichts ändern)
  REVIEW

MANUELLER-TEST (der Mensch hat getestet, Material liegt in der Inbox)
  TRIAGE → danach FIX

EINZELAUFTRAG (kleine, klar umrissene Änderung)
  UMSETZUNG → VERIFIKATION
  (kein Planner, kein REVIEW; der Orchestrator legt die Task-Datei selbst
   an. Zulässig nur, wenn der Auftrag 1–2 Dateien betrifft und prüfbare
   Akzeptanzkriterien hat – sonst ist es ein FIX oder FEATURE.)
```

**`SPEC_REVIEW` im `FEATURE` überspringen:** Am Ende eines
`REQUIREMENTS`-Auftrags mit `SPEC_REVIEW` hält der Orchestrator den
Requirements-Stand in `PROGRESS.md` fest
(`REQUIREMENTS abgeschlossen mit SPEC_REVIEW – Requirements-Stand <commit>`).
Im folgenden `FEATURE` prüft er mechanisch
`git diff --quiet <commit> -- .agent/spec/requirements/`; nur wenn das
leer ist, entfällt der Baustein (protokolliert als `SKIPPED`).

**Ausnahme: Einschub-Tasks.** Ein kleiner Task darf in den laufenden
Auftrag eingeschoben werden, wenn **alle drei** Bedingungen gelten: Er hat
dieselbe Quelle bzw. dasselbe Ziel wie der laufende Auftrag, er ist
höchstens so gross wie ein `EINZELAUFTRAG`, und er braucht keine neue
fachliche Klärung. Er bekommt eine Teil-Task-ID an der passenden Stelle
der Reihenfolge und je eine Zeile `Einschub: <Task-ID>, <Grund>` in
`state/AUFTRAG.md` (Abschnitt "Einschübe") und `state/PROGRESS.md`.
Alles andere wird weiterhin in `state/BACKLOG.md` notiert und ein
eigener Auftrag.

### Die Klärungsschleife (`REQUIREMENTS`, auch `ZIELARCHITEKTUR`)

Der Planner kann den Menschen nicht fragen und erinnert sich zwischen
zwei Aufrufen an nichts. Trotzdem ist ein mehrrundiges, thematisch
geordnetes Erarbeiten von Anforderungen möglich – weil der Orchestrator
das Gespräch führt und der **Zustand in der Datei liegt**, nicht im
Kontext eines Agenten:

1. `KLAERUNG` (a): Der Planner wählt **ein** Thema – dasjenige, ohne das
   am wenigsten planbar ist – und schreibt höchstens sieben Fragen, je
   mit Begründung ("was ich je nach Antwort anders planen würde") und
   Vorschlag als Default, als neue Runde ins Klärungsprotokoll von
   `state/AUFTRAG.md`. Die Grenze steht in `planner.md`; der Orchestrator
   gibt keine eigene Fragenzahl vor. Mehr als sieben Fragen zu einem
   Thema heissen: Der Auftrag ist zu gross geschnitten.
2. Der Orchestrator stellt sie dem Menschen wörtlich und trägt die
   Antworten in dieselbe Runde ein.
3. `KLAERUNG` (b): ein **frischer** Planner liest das Protokoll,
   formuliert das Thema unter `spec/requirements/` aus (als Anforderung,
   nicht als Frage-Antwort-Protokoll) und meldet als letzte Zeile
   `nächstes Thema: <…>` oder `keine offenen Themen`. Jede Anforderung
   bekommt dabei ihre ID; was die Antworten nicht entscheiden, markiert
   er als `> OFFEN:`-Zeile, statt es zu raten.
4. Der Orchestrator verzweigt daran: weitere Runde oder fertig. Nach fünf
   Runden ohne Abschluss stoppt er und fragt den Menschen – eine Klärung,
   die nicht konvergiert, ist ein zu gross geschnittener Auftrag.
5. Meldet der Planner "keine offenen Themen": `SPEC_REVIEW`. Liefert er
   Befunde, folgt genau eine weitere Runde (a) + (b), in der der Planner
   die Befunde zu Fragen macht (höchstens sieben, die gewichtigsten; der
   Rest kommt unter "Offene Punkte"); danach ist die Schleife fertig.
6. Zum Schluss prüft der Orchestrator per `grep`, dass keine
   `> OFFEN:`-Zeile mehr steht (Abschnitt 2, "Anforderungs-IDs und
   offene Punkte"). Treffer: eine Klärungsrunde (a) + (b) genau zu diesen
   Markern; bleiben danach welche, stoppt er und fragt den Menschen. Erst
   mit leerer Ausgabe hält er den Requirements-Stand für das Überspringen
   von `SPEC_REVIEW` fest.

`ZIELARCHITEKTUR` läuft nach demselben Muster: (a) der Architekt schreibt
je Punkt Vorschlag, Begründung und verworfene Alternative als Runde ins
Klärungsprotokoll, der Mensch bestätigt alles oder entscheidet einzelne
Punkte anders, (b) ein frischer Architekt übernimmt genau das nach
`ziel.md`.

Dasselbe Muster trägt überall dort, wo ein kontextfreier Subagent etwas
"Interaktives" beitragen soll: nicht die Rolle interaktiv machen, sondern
den Zustand aus dem Agenten in eine Datei verlagern und den Orchestrator
die Runden takten lassen.

### Nicht verhandelbare Grundregel: strikt sequentiell, nie parallel

Unabhängig vom Auftragstyp gilt: Zu jedem Zeitpunkt ist genau **ein**
Baustein aktiv und genau **ein** Task "in Arbeit". Der nächste Task wird
nicht einmal geplant, solange der aktuelle nicht verifiziert und auf
`done` gesetzt ist. Jeder Baustein geht an einen **frischen Agenten**
(echter Aufruf, nicht "im Kontext weiterdenken"); der Orchestrator wartet
auf die vollständige Rückmeldung, bevor irgendetwas anderes passiert.
Begründung und der reale Vorfall dazu: `DECISIONS.md`, Lehre 7.

**Erprobt, aber (noch) nicht Teil der Methodik: parallele Bahnen.** In
Messexperimenten (pwd-transform, 2026-10) liefen Tasks testweise in zwei
Bahnen parallel, mit eigenen Regeln: Tasks mit Änderungen unter `tests/`
in eine Bahn (gemeinsame Suite und Freeze-Prüfung), gleiche Datei →
gleiche Bahn, Doku erst nach Übernahme der Code-Tasks, eigenes
Arbeitsverzeichnis je Bahn, `HALTED` gilt für alle Bahnen. Die
Grundregel bleibt bis zur Auswertung bestehen; erst wenn sich zeigt, dass
Bahnen netto mehr bringen, als Zusammenführen und Prüfen kosten, kommen
sie als optionaler Betriebsmodus dazu (dann je Bahn ein eigener Klon bzw.
`git worktree` mit eigenem Branch).

### Start jeder Session

1. **Lage ermitteln** – mechanisch, nicht aus dem Gedächtnis: leere
   Ist-Architektur bei vorhandenem Code, leere Zielarchitektur, Tasks mit
   `status: open`/`in_progress`, Material in `.agent/inbox/`, ein
   unterbrochener Auftrag in `state/AUFTRAG.md`, Einträge in
   `state/BACKLOG.md`; in der Sandbox zusätzlich neue Lieferungen
   (`git branch --list 'nutzer/*'`, neuer Basisstand).
   - Offene Tasks → dem Menschen melden (Anzahl, Titel), fragen, ob
     fortgesetzt werden soll oder etwas Neues Vorrang hat.
   - Material in der Inbox → melden, fragen, ob jetzt triagiert wird.
   - Einträge im Backlog → nennen (ohne eigenes Anliegen des Menschen
     alle, sonst die passenden) und fragen, ob sie mitkommen; nicht von
     sich aus anhängen. Was mitkommt, wird im Backlog gestrichen.
   - Gefülltes `AUFTRAG.md` mit unerledigter Arbeit → dort weitermachen
     statt neu zu klären.
2. **`AUFTRAGSKLAERUNG`** – immer, auch wenn der Mensch schon gesagt hat,
   was er will. Ergebnis: `state/AUFTRAG.md`.
3. **Auftragstyp ableiten** aus `state/AUFTRAG.md`, die Bausteine seines
   Ablaufs der Reihe nach abarbeiten, nach jedem Baustein das Verdict
   auswerten und das Ergebnis aus Dateien und Git prüfen – nicht aus der
   Ausgabe der Rolle.

### Task-Schleife im Detail

1. Nächsten Task ermitteln: `status: open`, alle Einträge in
   `depends_on` bereits `done` (ein `superseded`-Task zählt als `done`,
   sobald alle seine Nachfolger `done` sind). Bei mehreren wählbaren:
   niedrigste ID zuerst, numerisch je Stufe verglichen.
2. Status auf `in_progress` setzen.
3. `TEST_FIRST` → `UMSETZUNG` → Freeze-Prüfung → `VERIFIKATION`
   (Abschnitt 4).
4. Bei `CHANGES_NEEDED` aus der Verifikation: erneut `UMSETZUNG` für
   denselben Task, mit den fehlgeschlagenen Tests als zusätzlichem
   Kontext und **erhöhter Versuchsnummer**. Kommt `CHANGES_NEEDED` von der
   Rolle selbst (der Task trägt nicht), geht es an die **vorgelagerte**
   Rolle. **Kein neuer Task beginnt, solange dieser nicht grün ist.**
5. Bei `PASS`: Status `done`, Test-Notizen in der Task-Datei, eine Zeile
   an `state/PROGRESS.md`, Commit `<TASK-ID>: <Titel>` auf dem Branch des
   Auftrags.

Jedes Verdict – auch ausserhalb der Task-Schleife – hält der
Orchestrator als Zeile `VERDICT <Baustein> [<Task-ID>] Runde|Versuch
<n>: <Verdict>` in `PROGRESS.md` fest; daraus entsteht beim Abschluss
die Zusammenfassung. Notizen aus Rückmeldungen überträgt er ebenfalls:
fremde Probleme und Sinnvolles ausserhalb des Umfangs nach
`state/BACKLOG.md`, Zeilen `Workflow: …` nach
`state/FRAMEWORK_RUECKFLUSS.md` (mit Datum, Rolle, Beleg).

Die Versuchsgrenze, `HALTED` und der Umgang mit gescheiterten Läufen
stehen in Abschnitt 6.

**Delta-fokussierte Wiederholungen:** Wird ein Baustein nach einer
Korrektur erneut gestartet, bekommt er den Commit-Hash seines vorherigen
Verdicts mit und prüft **nur die Commits seither** – nicht den gesamten
Stand von vorn. Das hält wiederholte Review-Runden bezahlbar und den
Kontext klein genug für kleine Modelle.

### Initiative abschliessen

Keine offenen Tasks mehr (bzw. bei `REQUIREMENTS`/`AUDIT`: das
Deliverable steht):

1. **Grösse der Spec-Dateien** mechanisch prüfen
   (`find .agent/spec -name '*.md' -size +30k`); ist eine zu gross,
   Aufteilen als eigenen Auftrag vorschlagen (Abschnitt 7).
2. **Zurückgestellte Findings** – bewusst nicht behobene Findings aus den
   Reports dieser Initiative – als `- finding …` in `state/BACKLOG.md`
   eintragen. Bewusst **akzeptierte** Abweichungen von der
   Zielarchitektur kommen dagegen nach Entscheid des Menschen in
   `architecture/abweichungen.md`.
3. **Zusammenfassung** nach `history/<datum>-<slug>-zusammenfassung.md`
   schreiben, so formuliert, dass sie unverändert als Beschreibung eines
   Pull Requests taugt: Auftrag und Erfolgskriterium (erfüllt?),
   Ergebnis, Tasks mit Versuchen, Verdicts je Baustein mit Runden,
   übersprungene Bausteine mit Bedingung, Testergebnis, neue Einträge in
   Backlog und Rückfluss. Zusammengetragen aus Dateien, nicht aus dem
   Gedächtnis; Push und Pull Request bleiben beim Menschen.
4. **Messdaten sichern** mit `.agent/export.sh` (dasselbe vor jedem
   Compact einer langen Session).
5. `state/AUFTRAG.md` und, falls befüllt, `state/IMPLEMENTATION_PLAN.md`
   nach `history/<datum>-<slug>-auftrag.md` bzw. `-plan.md` archivieren
   und auf die leere Vorlage zurücksetzen; Rückmeldung an den Menschen
   mit dem Pfad der Zusammenfassung und den neuen Einträgen in
   `BACKLOG.md` und `FRAMEWORK_RUECKFLUSS.md`. Den Rückfluss legt der
   Mensch im Repo `agent-workflow` unter `input/` ab.

**Nutzungslimit:** sauber stoppen, keinen Task halb hinterlassen (ein
laufender Task bleibt `in_progress`), Reset-Zeitpunkt in `PROGRESS.md`
notieren und – falls der Harness es kann – zu diesem Zeitpunkt
weitermachen.

---

## 4. Test-Freeze

Die Tests eines Tasks entstehen **vor** seiner Implementierung und werden
danach eingefroren:

1. `TEST_FIRST`: Der Tester schreibt aus den Akzeptanzkriterien Tests,
   die **fehlschlagen müssen** – aus dem richtigen Grund (das Verhalten
   fehlt, nicht ein Import). Schlägt keiner fehl, prüft der Test nichts
   oder das Verhalten existiert schon → nachbessern bzw.
   `CHANGES_NEEDED`. Er committet nur diese Testdateien
   (`<TASK-ID>: Tests (TEST_FIRST)`); der Hash ist die **Freeze-Grenze**.
2. `UMSETZUNG`: Der Implementer macht sie grün, ohne Testdateien
   anzufassen, und committet nicht.
3. Der Orchestrator prüft das mechanisch – gegen den Arbeitsbaum, weil
   der Implementer nicht committet:
   ```bash
   git diff <freeze-commit> --name-only -- tests/
   git status --porcelain -- tests/        # neu angelegte Testdateien
   git diff <freeze-commit> --name-only -- .agent/pruefungen.sh
   ```
   Gibt das etwas aus, werden diese Änderungen verworfen
   (`git checkout <freeze-commit> -- tests/ .agent/pruefungen.sh`, neue
   Dateien entfernen), und der Implementer bekommt den Verstoss als
   Kontext zurück.
4. `VERIFIKATION`: Der Tester führt die **gesamte** Suite aus – ein Task
   ist erst grün, wenn nichts anderes kaputtgegangen ist. Grün heisst:
   keine einzige Fehlerzeile, nicht nur eine grüne Summenzeile, und – wo
   es sie gibt – die Projekt-Prüfbefehle (`.agent/pruefungen.sh`) mit
   Exit 0.

**Teil-Task aus einem Neuschnitt:** Sind seine Tests wörtlich vom
Eltern-Task übernommen, schreibt der Tester keine neuen, sondern belegt
per `git diff <freeze-commit> -- <testdateien>`, dass sie unverändert
sind; Freeze-Grenze ist der Freeze-Commit des Eltern-Tasks.

**Ausnahme**, in der Task-Datei explizit zu markieren
(`test_first: false` plus Begründung im Kontext): Tasks ohne prüfbares
Verhalten – reine Doku-Änderungen, Umbenennungen ohne
Verhaltensänderung, Build- und Konfigurationsarbeit. Dann committet der
Orchestrator den Stand vor der Umsetzung selbst, damit der Lauf einen
sauberen Ausgangspunkt hat. Stillschweigend weggelassen wird `TEST_FIRST`
nie.

Der Freeze ist im Workflow fest auf `tests/` verdrahtet; eine abweichende
Testablage ist offen (`TODO.md`, Nr. 1).

---

## 5. Git

- **Branch je Auftrag:** Jeder Auftrag, der Dateien ändert, läuft auf
  `agent/<slug>` (Slug wie in `history/`), abgezweigt vom aktuellen
  Hauptbranch; bei einem unterbrochenen Lauf weiter auf dem bestehenden.
- **Commits:** nach jedem Baustein, der Dateien geändert hat
  (`<Baustein>: <kurz was>`), nach jedem verifizierten Task
  (`<TASK-ID>: <Titel>`) und vom Tester für die Freeze-Grenze. Das hat
  drei Gründe: Die Freeze-Grenze ist ein echter Commit statt eines
  Datei-Snapshots; geht ein Lauf schief, ist höchstens ein Baustein
  verloren; und `git diff` zeigt einer Rolle nur, was seit dem letzten
  Baustein passiert ist – nicht die Änderungen aller Vortasks, die ein
  kleines Modell beim Selbst-Check verwirren.
- **Gepusht wird nie vom Agenten.** Er bekommt keine Zugangsdaten und
  sucht auch keine.
- **Ohne Commits kein Betrieb:** Kann der Orchestrator nicht committen
  (früherer Sandbox-Betrieb mit geteiltem Ordner, `--shared`), stoppt er
  und schlägt einen Neustart ohne `--shared` vor. Ohne Commits fehlen
  Freeze-Grenze und Wiederherstellungspunkte; einen Ersatzbetrieb gibt
  es bewusst nicht.
- **Lieferungen des Menschen** kommen in der Sandbox als Branch
  `nutzer/<name>` oder als neuer Basisstand; der Orchestrator nennt sie
  vor der Auftragsklärung und klärt, ob sie dazugehören.

Der Weg der Commits zum Menschen (Volume, Wegwerf-Container, `fetch`,
`review-branch.sh`, Push) ist in `AGENT_WORKFLOW.md`, Bild 6,
zusammengefasst; Bedienung und Sicherheitsbegründung in
`sandbox/README.md`, "Commit-Flow".

---

## 6. Scheitern: erst diagnostizieren, dann reagieren

**Grundsatz: gründlich prüfen erst, wenn etwas schiefging.** Im
Normalfall wird nicht mehr geprüft als nötig. Hat eine Task-Datei aber
eine Vorgeschichte, schauen die Rollen genauer hin: der Tester mit der
Grün-Probe, der Planner schneidet beim Neuschnitt entlang der Stelle, an
der es scheiterte, und der Architekt prüft eine Gate-Vorgabe erneut, an
der ein Lauf gescheitert ist. So zahlt nur der problematische Task die
Kosten der Diagnose (`DECISIONS.md`, Lehre 15).

### Abbruchgründe des Wrappers

Fremde Läufe (`runtime: opencode`) startet der Orchestrator nur über
`run-role.sh`. Endet der nicht mit 0, entscheidet der Exit-Code (bei 3 der
Grund in der `ABBRUCH`-Zeile), was passiert. Grob:

| Art | Beispiele | Reaktion |
|---|---|---|
| Setup | Konfigurationsfehler (Exit 2), falsche Rolle gestartet, falsches Modell gelaufen | reparieren, dann **derselbe** Versuch erneut – es zählt kein Versuch |
| Task | Timeout, still gescheitert (keine Änderung und keine Verdict-Zeile), unerklärter Exit | Vorgeschichte, `GRUEN_PROBE`, Entscheidungsregel unten |
| Setup oder Task | `no user query found` (Vorflug wiederholen, sonst wie Timeout), Berechtigung still abgelehnt (legitim → klären und wiederholen; unzulässig → Fehlversuch) | je nach Ursache |
| Schranke | Versuchsgrenze überschritten (Exit 4), `HALTED` existiert (Exit 5) | Stopp, der Mensch entscheidet |

Mehrere Gründe zugleich: Setup geht vor – ein Timeout mit falschem Modell
sagt nichts über den Task. Die vollständige Tabelle steht in
`orchestrator.md`, Schritt 5. Vor dem ersten fremden Lauf einer Session
prüft `vorflug.sh`, ob Modell-Server, Kontextlänge und GPU-Anteil
stimmen; bei `FEHLT` stoppt der Orchestrator und nennt dem Menschen den
nötigen Befehl, statt still auf die Cloud auszuweichen.

### Grün-Probe und Entscheidungsregel

Ein Timeout kann ganz verschiedene Ursachen haben: Der Code war schon
fertig, nur die Schlussmeldung fehlte; er war fast fertig; ein Test war
gar nicht erfüllbar; der Task war zu gross; oder schon das Finden der
Stelle sprengte den Kontext. Wer nicht unterscheidet, schneidet unnötig
neu oder wiederholt stur denselben Lauf. Deshalb:

1. **Vorgeschichte schreiben**: Versuch, Rolle, Ausgang (Grund, Dauer),
   was im Diff vorliegt, Log-Pfad, und was im Log auffällt (ging die Zeit
   ins Lesen oder ins Schreiben?).
2. **`GRUEN_PROBE`**: Der Tester prüft per Wegwerf-Implementierung
   ausserhalb des Repos, ob die eingefrorenen Tests erfüllbar sind (die
   Lösung gibt er nicht weiter), und beurteilt den Teilstand Kriterium für
   Kriterium.
3. **Plausibilität mechanisch prüfen**: Bei `VOLLSTAENDIG` müssen die
   Test-Notizen eine grüne Suite zeigen, bei `FAST_FERTIG` muss die Liste
   offener Kriterien da und nicht leer sein – sonst zurück an den Tester.
4. **Reaktion nach der Befund-Zeile** – die Regel entscheidet, nicht das
   Ermessen des Orchestrators:

| Befund | Reaktion |
|---|---|
| `VOLLSTAENDIG` | Grün-Probe zählt als `VERIFIKATION`, Task `done` |
| `FAST_FERTIG` | nächster `UMSETZUNG`-Versuch **auf dem Teilstand**, mit der Liste offener Kriterien als Korrekturliste |
| `TEST_UNERFUELLBAR` | `BLOCKED` an den Menschen; nach seinem Entscheid derselbe Task mit nächster Versuchsnummer, den Test korrigiert ein neues `TEST_FIRST`. Ist eine Gate-Vorgabe die Ursache: vorher `ARCHITEKTUR_GATE` für diesen Task erneut |
| `ZU_GROSS` | Neuschnitt per `PLAN`; die Teil-Tasks beginnen bei Versuch 1 |
| `ZU_VIEL_LESESTOFF` | (1) `PLAN` "Wegweiser ergänzen" (Kapitel bzw. Abschnittsüberschriften, keine Zeilen), dann derselbe Task; scheitert auch das: (2) Task-Override auf ein Modell mit grösserem Kontext bzw. die Cloud (zählt als Fallback). Immer beim ersten Auftreten: (3) Strukturbefund an den Menschen ("Datei X in Kapitel aufteilen?") |

Eine feste Zahlengrenze zwischen "fast fertig" und "zu gross" gibt es
bewusst nicht – ein einziges offenes Kriterium kann riesig sein.

### Versuchsgrenze und `HALTED`

Ab dem vierten Versuch einer Rolle am selben Task verweigert
`run-role.sh` den Lauf (`AGENT_MAX_ATTEMPTS`, Default 3) und legt
`.agent/state/HALTED` an. Damit ist die **ganze Initiative** angehalten,
nicht nur dieser Task: Tasks bauen in der Regel aufeinander auf, und auf
ein Fundament weiterzubauen, von dem man weiss, dass es nicht trägt,
lohnt nicht. Für native Aufrufe (`runtime: subagent`), die nicht durch
den Wrapper gehen, prüft der Orchestrator die Datei vor jedem Baustein
selbst.

In diesem Zustand legt der Orchestrator dem Menschen Task-Datei und Logs
vor und wartet. Er schwächt keine Kriterien ab, schneidet nicht neu,
wechselt nicht das Modell oder den Task und entfernt `HALTED` nie selbst
– Neuschnitt und Modellwechsel nach der Entscheidungsregel gibt es nur
**vor** der Grenze.

**Betriebsmodus `lokal-mit-cloud-fallback`** (in `AUFTRAG.md`, Default
`normal`): Der letzte erlaubte Versuch einer lokal laufenden Rolle geht
an die Cloud (Task-Override `runtime: subagent`, Vermerk in der
Vorgeschichte, `run-role.sh --cloud-fallback` für die Messdaten). Die
Entscheidungsregel gilt vorher wie immer.

---

## 7. Dateistruktur

```
AGENTS.md                        # Projekt-Root, @-importiert agents/orchestrator.md
CLAUDE.md                        # Projekt-Root, @-importiert AGENTS.md

.agent/
  spec/                          # dauerhaftes Produktwissen – relevant
                                 # unabhängig von diesem Workflow
    requirements/                # funktionale Anforderungen, ändern sich selten
      README.md                  # Index: Kontext, Nicht-Ziele, Stufen, Kapitelliste
      <bereich>.md               # je Bereich ein Kapitel
    architecture/
      README.md                  # Index: welche Sicht steht wo
      ziel.md                    # Soll (top-down), der Mensch entscheidet
      ist.md                     # Ist (bottom-up), je Task nachgeführt
      abweichungen.md            # bewusst akzeptierte Lücke Soll ↔ Ist
      komponenten/<name>.md      # ausgelagerte Kapitel, erst bei Bedarf

  state/                         # veränderlicher Workflow-Zustand (SCREAMING_SNAKE)
    AUFTRAG.md                   # NUR das aktuell geklärte Anliegen samt
                                 # Klärungsprotokoll; leer, wenn nichts läuft
    IMPLEMENTATION_PLAN.md       # NUR die aktiv laufende Initiative
    PROGRESS.md                  # append-only chronologisches Log, auch je
                                 # Verdict und SKIPPED eine Zeile
    BACKLOG.md                   # für später: zurückgestellte Findings,
                                 # notierte Aufträge, fremde Probleme
    FRAMEWORK_RUECKFLUSS.md      # Beobachtungen zum Workflow selbst – geht
                                 # an das Repo agent-workflow (input/) zurück
    MEMORY.md                    # dauerhafte Projektnotizen über Sessions hinweg
    HALTED                       # nur nach überschrittener Versuchsgrenze

  pruefungen.sh                  # Projekt-Prüfbefehle (Lint, Build …), optional

  sync-agents.py                 # Generator: neutrale Quelle → Adapter
  run-role.sh                    # einziger Weg, eine Rolle in OpenCode zu starten
  vorflug.sh                     # Modell-Server bereit? (Kontext, GPU-Anteil)
  monitor.sh                     # laufenden Baustein beobachten
  export.sh                      # Messdaten sichern (vor Compact, bei Abschluss)

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
    TASK-0007-implementer-a1.log # <task>-<rolle>-a<versuch>.log
    metrics.jsonl                # Messdaten je Lauf

  history/                       # Archiv abgeschlossener Aufträge/Pläne
    2026-08-15-initial-build-auftrag.md
    2026-08-15-initial-build-plan.md
    2026-08-15-initial-build-zusammenfassung.md   # taugt als PR-Beschreibung

.claude/agents/                  # generierte Adapter – nicht von Hand editieren
.opencode/agent/                 # generierte Adapter – nicht von Hand editieren
```

Die Schreibweise ist bewusst: `SCREAMING_SNAKE` = einzelner, mutierbarer
Zustand, `lowercase` = viele gleichartige Instanzen (Rollen, Tasks,
Reports, Spec-Kapitel). Wer eine Datei sieht, weiss am Namen, in welche
Kategorie sie gehört.

**Warum `spec/` aus Ordnern mit Index besteht:** Eine Rolle mit kleinem
Kontext liest den Index und genau die Kapitel, die ihr Auftrag berührt –
nicht eine 130-KB-Datei (`DECISIONS.md`, Lehre 12). Wird ein Kapitel
grösser als etwa 30 KB (rund ein Viertel eines 64k-Kontexts), wird sein
grösster eigenständiger Teil ausgelagert und im Index eingetragen. Der
Orchestrator prüft das beim Abschluss jeder Initiative mechanisch und
schlägt das Aufteilen als eigenen Auftrag vor.

---

## 8. Tasks

### Task-Datei-Format (`.agent/tasks/TASK-####-<slug>.md`)

Die Task-Datei ist die einzige Information, die eine ausführende Rolle
zusätzlich zum bestehenden Code braucht – und gleichzeitig das Protokoll
zwischen Runtimes. Sie muss deshalb **vollständig in sich geschlossen**
sein. Massgeblich ist die Vorlage
`project-template/.agent/tasks/TEMPLATE.md`; in Kurzform:

```markdown
---
id: TASK-0023
title: <kurzer, imperativer Titel>
status: open            # open | in_progress | done | failed | blocked | superseded
superseded_by: []       # nur bei superseded: die ersetzenden Task-IDs
source: plan-step       # plan-step | review-finding | triage-finding | auftrag
source_ref: state/IMPLEMENTATION_PLAN.md#schritt-6
anforderungen: [R-bedienung-3]   # IDs aus spec/requirements/, die der Task umsetzt
depends_on: []          # andere Task-IDs, die vorher done sein müssen
files: [pfad/zur/datei.py]   # so eng wie möglich, der Diff wird dagegen geprüft
runtime:                # leer = Rolle entscheidet; Überschreibung für Sonderfälle
model:                  # leer = Rolle entscheidet; Überschreibung für Sonderfälle
test_first: true        # false nur mit Begründung im Kontext-Abschnitt
---

## Deliverable
<konkret: max. 1-2 Dateien/Module>

## Akzeptanzkriterien
- <prüfbare Bedingung mit konkreten Werten>

## Kontext
<Niveau "Auftrag für einen normalen Entwickler": Quellen, bindende
Schnittstellen, Wegweiser auf Komponenten (aus ist.md) bzw. auf Kapitel
und Abschnitte grosser Spec-Dateien – kein fertiger Code, keine
Zeilennummern, nicht die Konversationshistorie>

## Vorgeschichte
<normalerweise leer; nach einem gescheiterten Lauf vom Orchestrator
ergänzt: Versuch, Rolle, Ausgang, was erreicht/offen war, Log-Verweis>

## Vorgaben aus dem Architektur-Gate
<vom Architekten befüllt, falls der Baustein lief>

## Test-Notizen
<vom Tester befüllt: welche Tests geschrieben/ausgeführt, Ergebnis,
Freeze-Commit-Hash>
```

### Regeln für die Task-Grösse

- Ein Task betrifft max. 1–2 Dateien/Module und **eine
  Verhaltensfacette** – auch eine einzige Datei kann drei unabhängige
  Verhaltensänderungen enthalten. Ist er grösser, unterteilt ihn der
  Planner weiter.
- **Niveau: ein Auftrag für einen normalen Entwickler** – Ziel,
  Akzeptanzkriterien mit konkreten Werten, bindende Schnittstellen,
  Quellen, Wegweiser auf Komponentenebene. Kein fertiger Code, keine
  Ersetzungszeilen, keine vorformulierte Doku: Wer die Arbeit in die
  Task-Datei schreibt, leistet sie vorab und verfälscht, was die
  ausführende Rolle (und ein Modellvergleich) eigentlich zeigen soll
  (`DECISIONS.md`, Lehre 16).
- **Die Ist-Architektur ist die Landkarte.** Muss der Planner in den Code
  schauen, um die zuständige Stelle überhaupt zu finden, ist das ein
  Befund über `ist.md`, kein Anlass für Zeilennummern. Beschreibt `ist.md`
  den heutigen Code falsch, wird das vor den Code-Tasks korrigiert.
- Ändert ein Task einen Vertrag, steht `ist.md` in seinem `files:`; der
  Implementer zieht den Eintrag im selben Task nach – separate
  Doku-Nachzug-Tasks gibt es dafür nicht. Dasselbe gilt für die
  Nutzerdoku (README, Hilfe-Text, Handbuch), wenn ein Task sichtbares
  Verhalten ändert.
- Jeder Task nennt unter `anforderungen:` die IDs der Anforderungen, die
  er umsetzt; jede Anforderung im Umfang steht in mindestens einem Task.
- "Überall X ersetzen"-Tasks haben nie grep als einziges
  Akzeptanzkriterium; der eigentliche Test ist die Durchsicht Wort für
  Wort, im ganzen Projekt.
- Ein Task muss ohne Kenntnis anderer Tasks umsetzbar sein – Ausnahme:
  `depends_on` macht eine unvermeidbare Reihenfolge explizit.
- Jeder Task hat konkrete, prüfbare Akzeptanzkriterien (nie
  "funktioniert gut") und lässt das Repo lauffähig und grün zurück.
- Abhängigkeiten von externer Hardware oder Diensten werden vermieden
  bzw. gemockt; Sonderfälle werden eigene, spätere Tasks.
- IDs fortlaufend über alle Initiativen hinweg (höchste bestehende + 1,
  keine Wiederverwendung) – ausser Teil-IDs, siehe unten.

### Lebenszyklus einer Task-Datei, wenn es nicht glatt läuft

- **Vorgeschichte**: Jede Rolle startet ohne Gedächtnis. Scheitert ein
  Lauf, trägt der Orchestrator in der Task-Datei ein, was passiert ist –
  der nächste Versuch (und jede Diagnose) liest es dort.
- **`superseded`**: Wird ein bereits begonnener Task neu geschnitten,
  bleibt seine Datei als Beleg liegen, mit `status: superseded` und
  `superseded_by` auf die Nachfolger, die seine Vorgeschichte übernehmen.
  Ein `depends_on` auf ihn gilt als erfüllt, sobald alle Nachfolger
  `done` sind – sonst blockierte ein Neuschnitt alle Folgetasks. Noch nie
  begonnene Tasks werden dagegen einfach überarbeitet; der Commit ist
  Beleg genug.
- **Teil-IDs** `TASK-####.N`: für die Teile eines Neuschnitts und für
  Tasks, die nachträglich an einer bestimmten Stelle der Reihenfolge
  stehen müssen (auch Einschub-Tasks). Sortiert wird numerisch je Stufe:
  `0037` < `0037.1` < `0037.2` < `0038`; eine weitere Stufe
  (`0037.1.1`) ist erlaubt.
- **Neuschnitt**: eine Verhaltensfacette pro Teil-Task, geschnitten
  entlang der Stelle, an der der Lauf scheiterte; bereits eingefrorene
  Tests werden wörtlich auf die Teile verteilt und per
  `git diff <freeze-commit>` als unverändert belegt (Abschnitt 4).
- **Zurückgestellte Findings**: Was aus einem Report bewusst nicht
  behoben wurde, landet beim Abschluss der Initiative in
  `state/BACKLOG.md`; der Orchestrator nennt es bei der nächsten
  Auftragsklärung und fragt, ob es mitkommt.
