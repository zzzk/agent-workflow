# Abgleich mit Journey Hero (`input/architect.md`, `input/feature.md`)

Stand 2026-11-15. Grundsatz (Nutzer): Struktur des Frameworks bleibt; nur
einzelne Punkte übernehmen. Je Punkt ein Vorschlag, der Nutzer entscheidet.
Aus den Entscheiden entsteht der Umsetzungsplan (unten).

Legende Vorschlag: **übernehmen** · **prüfen** (erst klären, ob/wie es
technisch geht) · **zurückstellen** (TODO) · **bestätigen** (heutiger
Stand bleibt bewusst) · **verwerfen**.

## A. Neu – Vorschlag übernehmen

| Nr. | Punkt | Journey Hero | Heute bei uns | Vorschlag | Entscheid |
|---|---|---|---|---|---|
| J1 | Performance-Prüfung vor dem Code | Architekt prüft, ob die Spec ein Performance-Problem anlegt (N+1-Aufrufe, unbegrenzte Listen, blockierende Arbeit) | Gate prüft "Form der Lösung" (Rundreisen, doppelte Zuständigkeit), nichts zu Performance | **übernehmen**: ein Prüfpunkt "Performance-Form" im `ARCHITEKTUR_GATE` (allgemein formuliert), dazu eine vierte Prüf-Linse *Performance* im `REVIEW` || **übernehmen** (2026-11-15) |
| J2 | Offene Punkte als harte Sperre | `> OPEN:`-Markierung in der Spec; keine Spec mit Markierung erreicht die Reviews | Planner (b) formuliert aus; was über 7 Fragen hinausgeht, steht unter "Offene Punkte" in `AUFTRAG.md` – nicht mechanisch geprüft | **übernehmen**: fester Marker für Ungeklärtes in `spec/requirements/`; Orchestrator prüft per `grep` vor `PLAN` (wie `SKIPPED`-Checks) und stoppt || **übernehmen** (2026-11-15) |
| J3 | Zustände und Texte je Anforderung | eigener UX-Agent vor dem Code: jeder Zustand (Leerlauf, Laden, Erfolg, jeder Fehler), Darstellung, genauer Text | `SPEC_REVIEW` prüft "sichtbare Texte festgelegt, Fehlerverhalten je Aktion" | **übernehmen, ohne neue Rolle**: Vollständigkeitsprüfung im `SPEC_REVIEW` um "jeder Zustand mit Darstellung" erweitern (nur bei UI/CLI) || **übernehmen** (2026-11-15) |
| J4 | Umfangsprüfung im Review | Agent `business`: passt das Ergebnis zu Ziel und Umfang? | `REVIEW` prüft Kriterien gegen Code; ob etwas gebaut wurde, das laut `AUFTRAG.md` "draussen" ist, prüft niemand ausdrücklich | **übernehmen**: fester Prüfpunkt im `REVIEW` "nichts ausserhalb des Umfangs, nichts Ausgeschlossenes gebaut" || **übernehmen** (2026-11-15) |
| J5 | Nutzerdoku im selben Task | eigene Phase: Doku-Agent schreibt die App-Doku auf den aktuellen Stand | Implementer "ggf. minimale Doku"; `REVIEW` prüft Doku gegen Code – Abweichung fällt erst hinterher auf | **übernehmen**: Planner nimmt die Nutzerdoku ins `files:` jedes Tasks, der sichtbares Verhalten ändert (analog `ist.md`), keine separaten Doku-Tasks || **übernehmen** (2026-11-15) |
| J6 | Stabile Namen für Anforderungen | `Requirement:`/`Scenario:`-Namen sind die Einheit für Testabdeckung, zitiert in Tests, Tasks und Review | Kapitel und Abschnitte; Tasks verweisen per `source_ref`, Kriterien frei formuliert | **übernehmen (leicht)**: Anforderungen bekommen eine stabile ID (z.B. `R-<bereich>-<n>`); Tasks nennen sie, `REVIEW` prüft "Anforderung ohne Task/Test". Kein Wechsel auf OpenSpec || **übernehmen** (2026-11-15) |

## B. Neu – erst prüfen

| Nr. | Punkt | Journey Hero | Heute bei uns | Vorschlag | Entscheid |
|---|---|---|---|---|---|
| J7 | Pfad-Sperren per Hook in Claude Code | `PreToolUse`-Hook begrenzt, was der Spec-Writer schreiben darf | in Claude Code nur Regel im Prompt + Diff-Prüfung (`HARNESS.md`: Pfade "nur über Hook nachbaubar") | **prüfen**: `sync-agents.py` erzeugt aus `path_allows` einen Hook je Subagent (Implementer: kein `tests/**`; Reviewer/Architekt: nur eigene Dateien). Schliesst die grösste Lücke der Härtung – vorher testen, ob Hooks im Subagent-Frontmatter greifen || **übernehmen** (2026-11-15) |
| J8 | Projektspezifische Pflicht-Checks | `check-string-parity.sh` vor jedem Review; schlägt er fehl, zuerst zurück an den Implementer | Tester führt die Suite aus; Lint/Format/Build nur, wenn Teil der Suite | **prüfen**: optionale Liste von Prüfbefehlen je Projekt (z.B. in `MEMORY.md` oder eigener Datei), die der Tester in `VERIFIKATION` mitläuft || **übernehmen** (2026-11-15) |

## C. Neu – zurückstellen

| Nr. | Punkt | Journey Hero | Vorschlag | Entscheid |
|---|---|---|---|---|
| J9 | E2E-Tests und Screenshots | eigene Phase mit Agent, ein Screenshot je geändertem Bildschirm | **zurückstellen** (TODO): nur für UI-Projekte sinnvoll; erst am ersten solchen Projekt entscheiden || **zurückstellen** (2026-11-15) |

## D. Bestehendes – bestätigen

| Nr. | Punkt | Journey Hero | Bei uns, bleibt | Begründung | Entscheid |
|---|---|---|---|---|---|
| J10 | Strikt sequentiell | Reviews und Gates parallel | genau ein Baustein aktiv | Grundregel, `DECISIONS.md` Lehre 7; parallele Bahnen erprobt, nicht übernommen || **bestätigt** |
| J11 | Ein Reviewer mit Linsen | fünf spezialisierte Reviewer | ein Reviewer, Linsen per Diff | wenige Rollen-Dateien, mechanische Aktivierung; neue Linsen statt neuer Rollen (J1) || **bestätigt** |
| J12 | Planner schneidet | Orchestrator schreibt Slice-Plan und `design.md` selbst | Planner (`PLAN`), Gate-Vorgaben in der Task-Datei | Orchestrator plant nicht; Task-Datei bleibt in sich geschlossen || **bestätigt** |
| J13 | Implementer committet nicht | Implementer committet je Slice | Orchestrator committet nach `VERIFIKATION` | Freeze-Prüfung gegen den Arbeitsbaum, Verwerfen ohne Revert || **bestätigt** |
| J14 | Push nur durch den Menschen | Agent pusht, eröffnet PR, schaltet CI frei | kein Push, keine Zugangsdaten | Sicherheitsentscheid (Bild 6); Agent-Push als TODO 9 || **bestätigt** |
| J15 | Requirements direkt in `spec/` | OpenSpec: Delta je Änderung, beim Archivieren in die Wahrheitsschicht übernommen | Planner schreibt direkt nach `spec/requirements/`, Git ist die Historie | Delta-Mechanik ist für kleine Modelle zu schwer; Nutzen gering ohne parallele Änderungen || **bestätigt** – kein OpenSpec |
| J16 | Vorgeschichte, Grün-Probe, Versuchsgrenze, `HALTED` | gibt es nicht ("nie denselben Auftrag erneut starten", sonst Ermessen) | feste Regeln | aus Läufen mit lokalen Modellen entstanden (Lehren 15, 18) || **bestätigt** |
| J17 | Zurückgestellte Findings in `MEMORY.md` | Backlog-Register: eine Datei je offenem Punkt, mechanisch geprüft | Liste in `MEMORY.md`, `abweichungen.md` | genügt bisher; Register erst bei Bedarf || **geändert** (2026-11-15): Variante b) – eigene Datei `state/BACKLOG.md` für alles "später" (zurückgestellte Findings, notierte Aufträge, fremde Probleme); `MEMORY.md` nur noch Projektnotizen |
| J18 | Abschluss-Rückmeldung | PR-Beschreibung ist die dauerhafte Geschichte (alle Verdicts, SKIPPED mit Grund, Runden) | Zusammenfassung an den Nutzer, `history/`, `PROGRESS.md` | bleibt; kleine Ergänzung möglich: Zusammenfassung so formulieren, dass sie als PR-Beschreibung taugt || **ergänzt** (2026-11-15): Zusammenfassung zusätzlich als `history/<datum>-<slug>-zusammenfassung.md`, als PR-Beschreibung verwendbar; Push/PR weiter durch den Menschen |


## E. Ergänzung des Nutzers

| Nr. | Punkt | Entscheid |
|---|---|---|
| J19 | Workflow-Punkte getrennt vom Projekt-Backlog | **übernehmen** (2026-11-15): `BACKLOG.md` nur für das Projekt. Was am Workflow selbst auffällt (Regel unklar oder widersprüchlich, Werkzeug fehlt, Harness-Eigenheit), bekommt einen eigenen Ort `state/FRAMEWORK_RUECKFLUSS.md` (Name wie im Projekt pwd-transform) und fliesst von dort in dieses Repo zurück (`input/`). |

## Umsetzungsplan

Auf einem Branch `agent/journey-hero-abgleich`, je Paket ein Commit.
Normativ sind die Rollen-Dateien: zuerst sie ändern, danach
`python3 .agent/sync-agents.py` (Adapter unter `.claude/agents/`,
`.opencode/agent/` neu erzeugen, nie von Hand), zuletzt die Doku.

### Paket 1 – Backlog, Rückfluss, Zusammenfassung (J17, J18, J19)

- Neu `project-template/.agent/state/BACKLOG.md` (Vorlage): eine Zeile je
  Punkt, `- <Art> <Kurztitel> – <Quelle>`; Arten: `finding`
  (zurückgestellt, mit `reports/<datei>#<anker>`), `auftrag` (notiert,
  nicht angehängt), `problem` (fremdes Problem aus einem Task).
- `orchestrator.md`: Schritt 1 liest `BACKLOG.md` statt des
  `MEMORY.md`-Abschnitts; jedes "notieren" (Grundregel, Schritt 3,
  Einschub, Harte Regeln) nennt `BACKLOG.md` als Ort; Notizen aus
  Rückmeldungen (Implementer "fremdes Problem", Planner "ausserhalb des
  Umfangs") überträgt der Orchestrator dorthin; Schritt 7 (aufgeschobene
  Abweichung) und Schritt 9.2 auf `BACKLOG.md`.
- `orchestrator.md` Schritt 9: vor dem Archivieren
  `history/<datum>-<slug>-zusammenfassung.md` schreiben – Inhalt wie
  "Rückmeldung an den Nutzer", als PR-Beschreibung formuliert (Auftrag
  und Erfolgskriterium, Ergebnis, Tasks, Verdicts je Baustein mit
  Runden, `SKIPPED` mit Bedingung, Testergebnis, neue Backlog-Einträge).
- `planner.md` (Ausgangslage B, Punkt 3): "zurückgestelltes Finding in
  `BACKLOG.md`".
- `state/MEMORY.md` (Vorlage): Abschnitt "Zurückgestellte Findings"
  entfernen, Verweis auf `BACKLOG.md`.
- Übergang für bestehende Projekte: Hinweis in `USERMANUAL.md`
  (Abschnitt aus `MEMORY.md` nach `BACKLOG.md` verschieben).

- J19: Neu `project-template/.agent/state/FRAMEWORK_RUECKFLUSS.md`
  (Vorlage). Alle Rollen: Workflow-Auffälligkeiten als Zeile
  `Workflow: …` in der Rückmeldung; der Orchestrator überträgt sie (und
  eigene) mit Datum, Rolle, Beleg. Beim Abschluss nennt er neue Einträge
  (ersetzt den heutigen Hinweis "falls AGENT_WORKFLOW.md ergänzt werden
  sollte"). Rückweg: Nutzer legt die Datei hier unter `input/` ab
  (`USERMANUAL.md`).

### Paket 2 – Anforderungen schärfen (J2, J3, J6)

- J6 IDs: `requirements/README.md` (Vorlage) erklärt das Format
  `R-<bereich>-<n>` (fortlaufend je Kapitel, nie wiederverwendet;
  entfernte bleiben als "entfällt" stehen). `planner.md` (b) vergibt
  IDs; `PLAN` trägt sie je Task ein. `tasks/TEMPLATE.md`: neues Feld
  `anforderungen: []`. `tester.md` (`TEST_FIRST`): ID im Testnamen oder
  in einem Kommentar am Test. `reviewer.md` (`REVIEW`): Anforderung im
  Umfang ohne Task bzw. ohne Test → Finding (per `grep` belegbar).
- J2 Marker: `planner.md` (b) schreibt Ungeklärtes als
  `> OFFEN: <Frage> – Vorschlag: <Default>` an die Stelle in
  `spec/requirements/`; `reviewer.md` (`SPEC_REVIEW`): jeder Marker ist
  ein Befund. `orchestrator.md`: Check
  `grep -rn '^> OFFEN:' .agent/spec/requirements/` vor `PLAN` (Ablauf
  `FEATURE`) und am Ende von `REQUIREMENTS`; Treffer → Klärungsrunde zu
  genau diesen Punkten bzw. Stopp und Rückfrage.
- J3 Zustände: `reviewer.md` (`SPEC_REVIEW`, Vollständigkeit): "für
  jede Aktion mit sichtbarem Ergebnis alle Zustände – Warten, Erfolg,
  jeder unterscheidbare Fehler – mit Darstellung und Text" (nur bei
  UI/CLI).

### Paket 3 – Gate, Review, Doku (J1, J4, J5)

- J1: `architect.md` (`ARCHITEKTUR_GATE`): Prüfpunkt "Performance-Form"
  (vervielfachte Aufrufe je Nutzeraktion, unbegrenzte Datenmengen ohne
  Begrenzung/Paging, blockierende Arbeit auf dem kritischen Pfad, Daten
  übers Netz, die lokal schon vorliegen). `reviewer.md`: vierte Linse
  *Performance*; `orchestrator.md` Schritt 4: wann sie aktiv ist.
- J4: `reviewer.md` (`REVIEW`): liest `state/AUFTRAG.md` (Umfang,
  "draussen"); Prüfpunkt "nichts ausserhalb des Umfangs gebaut".
- J5: `planner.md` (Regeln für Tasks): Ändert ein Task sichtbares
  Verhalten, gehört die betroffene Nutzerdoku in `files:` (analog
  `ist.md`, keine Doku-Nachzug-Tasks). `implementer.md` Schritt 3
  entsprechend ergänzen.

### Paket 4 – Projekt-Prüfbefehle (J8)

- Vorschlag (beim Umsetzen bestätigen): optionale Datei
  `.agent/pruefungen.sh` im Projekt (Vorlage mit Kommentar, leer =
  nichts). `tester.md`: in `VERIFIKATION` und `GRUEN_PROBE` ausführen,
  falls vorhanden; Exit ≠ 0 heisst nicht grün. `ARCHITEKTUR_GATE` bzw.
  Planner legen fest, was hineingehört (Lint, Format, Build,
  Paritätschecks). `review-branch.sh` warnt bei Änderungen daran (Datei
  steuert die Prüfung).

### Paket 5 – Pfad-Sperren per Hook (J7)

1. **Prüfen** in der Sandbox: Greift ein `PreToolUse`-Hook im
   Frontmatter eines Subagenten (`hooks:`), und bekommt er den Pfad des
   Edit/Write-Aufrufs? Test mit einer Wegwerf-Rolle, die in einen
   gesperrten Pfad schreiben soll.
2. Greift er: `sync-agents.py` erzeugt aus `path_allows`/`path_denies`
   der `meta.yml` einen Hook (kleines Skript unter `.agent/`), für
   Implementer (`tests/**` gesperrt), Reviewer, Architekt.
3. Greift er nicht: Ergebnis dem Nutzer vorlegen (Alternativen: Hook in
   `.claude/settings.json` mit Erkennung der Rolle, oder bei Prompt +
   Diff-Prüfung bleiben) – nicht auf Verdacht bauen.
4. `HARNESS.md` (Matrix), Schranken-Tabelle in `AGENT_WORKFLOW.md`.

### Paket 6 – Doku, Begründungen, Abschluss

- `AGENT_WORKFLOW.md`: Bild 3 / "Wo was liegt" (`BACKLOG.md`), Bild 2a
  Schritt (2)/(3) (Marker, Zustände), Schranken (Offen-Sperre, Hook,
  Prüfbefehle), Rollen-Tabelle falls nötig.
- `AGENT_WORKFLOW_REFERENZ.md`: Baustein-Katalog, Prüf-Linsen (vier),
  Abläufe (Offen-Check), Abschluss (Zusammenfassung, Backlog),
  Dateistruktur, Task-Format (`anforderungen:`), Grössenregeln (Doku in
  `files:`).
- `DECISIONS.md`: Abschnitt "Aus dem Abgleich mit Journey Hero
  (2026-11)" – was übernommen, was bewusst nicht (J10–J16 mit Grund).
- `TODO.md`: J9 (E2E/Screenshots für UI-Projekte) als neuer Eintrag.
- `README.md`, `USERMANUAL.md`: Dateilisten nachführen.
- Konsistenz: `grep` nach `MEMORY.md`/"Zurückgestellte Findings"/drei
  Linsen; `sync-agents.py` ausführen und generierte Diffs prüfen;
  unabhängiges Review gegen die Rollen-Dateien.
- Danach `input/architect.md`, `input/feature.md` und diese Datei
  entfernen (Inhalt steht in `DECISIONS.md`).
