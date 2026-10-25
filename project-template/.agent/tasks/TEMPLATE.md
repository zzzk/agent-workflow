---
id: TASK-0000
title: <kurzer, imperativer Titel>
status: open              # open | in_progress | done | failed | blocked | superseded
superseded_by: []         # nur bei status: superseded – die Task-IDs, die diesen
                          # begonnenen Task ersetzen (Neuschnitt)
source: plan-step         # plan-step | review-finding | triage-finding | auftrag
source_ref: <state/IMPLEMENTATION_PLAN.md#initiative-<slug>, reports/<datum>-review.md#<finding>
                          # oder state/AUFTRAG.md bei einem EINZELAUFTRAG>
depends_on: []            # andere Task-IDs, die vorher done sein müssen; ein
                          # superseded-Task gilt als done, sobald alle seine
                          # superseded_by done sind
files: []                 # Dateien, die dieser Task berühren darf – so eng wie möglich,
                          # der Orchestrator prüft den Diff dagegen

# Beide Felder sind ÜBERSCHREIBUNGEN für Sonderfälle und normalerweise LEER.
# Wer eine Rolle ausführt und womit, steht bei der Rolle selbst
# (.agent/agents/<rolle>.meta.yml: runtime + model_tier). Hier nur eintragen,
# wenn GENAU DIESER Task davon abweichen soll – z.B. ein besonders heikler
# Task, der einmalig auf ein stärkeres Modell soll.
runtime:                  # leer = Rolle entscheidet | subagent | opencode
model:                    # leer = Rolle entscheidet | z.B. ollama/qwen3.8:27b
test_first: true          # false nur mit Begründung im Kontext-Abschnitt
---

## Deliverable

<konkret: max. 1-2 Dateien/Module, was danach existieren muss>

## Akzeptanzkriterien

- <prüfbare Bedingung 1>
- <prüfbare Bedingung 2>

## Kontext

<Niveau: Auftrag für einen normalen Entwickler. Quellen (Requirements-
Kapitel, Finding-Text aus dem Report), bindende Schnittstellenvorgaben,
Wegweiser auf Komponentenebene aus spec/architecture/ist.md bzw. auf die
Kapiteldatei/Abschnittsüberschrift einer grossen Spec-Datei. KEIN fertiger
Code, keine Ersetzungszeilen, keine vorformulierte Doku, keine
Zeilennummern, nicht die Konversationshistorie.>

## Vorgeschichte

<normalerweise leer. Nach einem gescheiterten Lauf vom Orchestrator
ergänzt, je Lauf ein Eintrag – das Gedächtnis zwischen kontextfreien
Aufrufen:

### Versuch <n> – <Rolle>, <Datum>
- Ausgang: <Timeout nach …s | CHANGES_NEEDED | still gescheitert | …>
- Erreicht: <was danach vorlag, z.B. "Kriterien 1–4 erfüllt">
- Offen: <was fehlte>
- Log: .agent/runs/<datei>.log

Teil-Tasks eines Neuschnitts übernehmen die Vorgeschichte ihres
Eltern-Tasks.>

## Vorgaben aus dem Architektur-Gate

<vom Architekten befüllt, falls der Baustein lief: welche bestehende
Abstraktion zu nutzen ist, welche Benennung sich einfügt, welche Grenze
nicht überschritten werden darf. Für den Implementer bindend.>

## Test-Notizen

<vom Tester befüllt: welche Tests geschrieben/ausgeführt, Ergebnis,
Freeze-Commit-Hash>
