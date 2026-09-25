#!/usr/bin/env python3
"""Wertet .agent/runs/metrics.jsonl aus - fuer Menschen und fuer Beschaffung.

    python3 .agent/metrics-report.py [--csv]

Fuehrt zwei Quellen zusammen (siehe .agent/sample-host.sh):
    metrics.jsonl   Ereignisse: ein Datensatz je Lauf, plus Verdicts
    host.csv        Zeitreihe der Host-Auslastung (optional)
Der Join laeuft ueber das Zeitfenster jedes Laufs.

Abhaengigkeitsfrei (nur Standardbibliothek), wie sync-agents.py.
"""

import csv
import json
import sys
from datetime import datetime, timedelta
from pathlib import Path

RUNS = Path(".agent/runs")
METRICS = RUNS / "metrics.jsonl"
HOST = RUNS / "host.csv"


def parse_ts(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ")


def load():
    if not METRICS.is_file():
        sys.exit("Keine Messdaten: {} fehlt.\n"
                 "Messung einschalten mit AGENT_METRICS=1 (siehe run-role.sh).".format(METRICS))
    runs, verdicts, aborts = [], {}, []
    for line in METRICS.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue                      # eine kaputte Zeile kippt nicht den Report
        if rec.get("type") == "run":
            runs.append(rec)
        elif rec.get("type") == "verdict":
            verdicts[(rec["task"], rec["role"], rec["attempt"])] = rec["verdict"]
        elif rec.get("type") == "aborted":
            aborts.append(rec)
    for r in runs:
        r["verdict"] = verdicts.get((r["task"], r["role"], r["attempt"]), "-")
    return runs, aborts


def load_host():
    if not HOST.is_file():
        return []
    out = []
    with HOST.open(encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            try:
                out.append((parse_ts(row["ts"]), float(row["ollama_cpu_pct"]),
                            float(row["vram_mb"])))
            except (ValueError, KeyError):
                continue
    return out


def host_window(samples, start, dur):
    """Auslastung waehrend eines Laufs. Leer, wenn kein Sampler lief."""
    end = start + timedelta(seconds=dur)
    inside = [(c, v) for ts, c, v in samples if start <= ts <= end]
    if not inside:
        return None, None
    return max(c for c, _ in inside), max(v for _, v in inside)


def main():
    runs, aborts = load()
    samples = load_host()
    as_csv = "--csv" in sys.argv

    rows = []
    for r in runs:
        cpu, vram = host_window(samples, parse_ts(r["ts_start"]), r["duration_s"])
        cold = (r.get("vram_before") in (0, None)) and bool(r.get("vram_after"))
        rows.append({
            "task": r["task"], "rolle": r["role"], "versuch": r["attempt"],
            "modell": r["model"], "dauer_s": r["duration_s"],
            "kaltstart": "ja" if cold else "nein",
            "verdict": r["verdict"], "dateien": r.get("files_changed", 0),
            "rss_mb": round(r.get("peak_rss_kb", 0) / 1024),
            "host_cpu_max": "" if cpu is None else round(cpu),
            "host_vram_mb": "" if vram is None else round(vram),
        })

    if as_csv:
        w = csv.DictWriter(sys.stdout, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
        return

    # Kette je Task statt flacher Zeilen. Der Grund: eine Wiederholung ist
    # ohne ihren Vorlauf nicht deutbar. "implementer Versuch 2" heisst etwas
    # anderes, je nachdem ob davor nur der Implementer stand (Modell zu
    # schwach) oder ob eine vorgelagerte Rolle nachgebessert hat (Task war
    # schlecht geschnitten). Fuer die Beschaffungsfrage duerfen diese beiden
    # Faelle nicht in derselben Zahl landen.
    by_task = {}
    for r, row in zip(runs, rows):
        by_task.setdefault(r["task"], []).append((r, row))

    for task in sorted(by_task):
        chain = sorted(by_task[task], key=lambda x: x[0]["ts_start"])
        final = chain[-1][0]["verdict"]
        # Ein Abbruch macht den Task offen, auch wenn ein frueherer Lauf
        # PASS ergab: die Obergrenze wurde erreicht, ein Mensch muss ran.
        aborted_here = any(a["task"] == task for a in aborts)
        offen = aborted_here or final not in ("PASS", "PASS_WITH_NOTES")
        print("\n{}{}".format(task, "   [NICHT ABGESCHLOSSEN]" if offen else ""))
        for i, (r, row) in enumerate(chain):
            last = i == len(chain) - 1
            print("  {} {:<12} #{}  {:>5}s  {:<16} {} Datei(en){}".format(
                "`-" if last else "|-", row["rolle"], row["versuch"],
                row["dauer_s"], row["verdict"], row["dateien"],
                "  [Kaltstart]" if row["kaltstart"] == "ja" else ""))
        for a in aborts:
            if a["task"] == task:
                print("  ** ABGEBROCHEN: {} Versuche erreicht die Grenze von {} "
                      "- Entscheid des Nutzers noetig".format(a["attempt"], a["limit"]))

    # --- Verdichtung je Rolle --------------------------------------------
    print("\nJe Rolle:")
    by_role = {}
    for r in runs:
        by_role.setdefault(r["role"], []).append(r)
    print("  {:<14} {:>5} {:>9} {:>9} {:>9} {:>10}".format(
        "Rolle", "Laeufe", "Median s", "Max s", "Summe s", "Wdh.-Quote"))
    for role, rs in sorted(by_role.items()):
        ds = sorted(x["duration_s"] for x in rs)
        med = ds[len(ds) // 2]
        # Wiederholungsquote: Anteil der Laeufe, die ein zweiter oder
        # spaeterer Versuch am selben Task waren. Das ist die Zahl, die
        # sagt, ob ein billigeres Modell wirklich billiger ist.
        retries = sum(1 for x in rs if x["attempt"] > 1)
        print("  {:<14} {:>5} {:>9} {:>9} {:>9} {:>9}%".format(
            role, len(rs), med, max(ds), sum(ds), round(100 * retries / len(rs))))

    bad = [r for r in runs if r.get("fallback") or r.get("auto_rejected")]
    if bad:
        print("\nUNVERWERTBARE LAEUFE (Rolle nicht ausgefuehrt bzw. Berechtigung "
              "abgelehnt) - diese Zeilen NICHT in eine Auswertung uebernehmen:")
        for r in bad:
            print("  {} / {} Versuch {}: {}".format(
                r["task"], r["role"], r["attempt"], r["log"]))

    if not samples:
        print("\nHinweis: keine host.csv - CPU/VRAM-Spalten leer. Fuer die "
              "Beschaffungsfrage .agent/sample-host.sh auf dem Host mitlaufen "
              "lassen; der opencode-Prozess in der Sandbox zeigt die Last nicht.")


if __name__ == "__main__":
    main()
