#!/usr/bin/env python3
"""Erzeugt harness-spezifische Rollen-Dateien aus den neutralen Quellen.

Quellen (die einzige Wahrheit, hier wird editiert):
    .agent/agents/<rolle>.md          reiner Rollen-Body, kein Frontmatter
    .agent/agents/<rolle>.meta.yml    Absicht, nicht Harness-Syntax
    .agent/agents/_tiers.yml          model_tier -> konkretes Modell je Harness

Ziele (generiert, werden bei jedem Lauf vollstaendig ueberschrieben):
    .claude/agents/<rolle>.md
    .opencode/agent/<rolle>.md

Aufruf aus dem Projekt-Root:  python3 .agent/sync-agents.py [--check]

--check schreibt nichts und meldet per Exit-Code 1, ob die generierten
Dateien vom aktuellen Stand der Quellen abweichen (fuer CI/Pre-Commit).

Hintergrund: Das .md-Format ist zwischen Harnesses NICHT kompatibel.
Portabel ist nur der Body; Frontmatter und die mechanische Durchsetzung
sind harness-spezifisch. Siehe tools/agent-workflow/HARNESS.md.
"""

import sys
from pathlib import Path

AGENTS_DIR = Path(".agent/agents")
CLAUDE_DIR = Path(".claude/agents")
OPENCODE_DIR = Path(".opencode/agent")

BANNER = "# GENERIERT von .agent/sync-agents.py - nicht von Hand editieren."
SOURCE_NOTE = "# Quelle: .agent/agents/{role}.md + {role}.meta.yml"


# --------------------------------------------------------------------------
# Minimaler YAML-Parser
#
# Bewusst nur die flache Teilmenge, die unsere Metadaten verwenden:
# "key: wert", "key: [a, b]" und eine Verschachtelungsebene. Das haelt das
# Skript abhaengigkeitsfrei (PyYAML ist nicht ueberall installiert).
# --------------------------------------------------------------------------

def _strip_comment(line):
    out = []
    for i, ch in enumerate(line):
        if ch == "#" and (i == 0 or line[i - 1].isspace()):
            break
        out.append(ch)
    return "".join(out).rstrip()


def _parse_value(raw):
    raw = raw.strip()
    if raw.startswith("[") and raw.endswith("]"):
        inner = raw[1:-1].strip()
        if not inner:
            return []
        return [item.strip().strip('"').strip("'") for item in inner.split(",")]
    if raw in ("true", "false"):
        return raw == "true"
    if raw.isdigit():
        return int(raw)
    return raw.strip('"').strip("'")


def parse_yaml_subset(text):
    root = {}
    current_key = None
    for raw_line in text.splitlines():
        line = _strip_comment(raw_line)
        if not line.strip():
            continue
        indented = line[0].isspace()
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()
        if indented:
            if current_key is None:
                continue
            if not isinstance(root.get(current_key), dict):
                root[current_key] = {}
            root[current_key][key] = _parse_value(value)
        elif value == "":
            root[key] = {}
            current_key = key
        else:
            root[key] = _parse_value(value)
            current_key = key
    return root


# --------------------------------------------------------------------------
# Adapter: Absicht -> Harness-Syntax
# --------------------------------------------------------------------------

def claude_adapter(meta, tiers, body):
    """Claude Code: tools-Allowlist, nur Anthropic-Modelle, keine Pfad-Granularitaet."""
    role = meta["role"]
    lines = [
        "---",
        BANNER,
        SOURCE_NOTE.format(role=role),
        "name: {}".format(role),
        "description: {}".format(meta["description"]),
        "model: {}".format(tiers["claude"][meta["model_tier"]]),
        "maxTurns: {}".format(meta.get("max_steps", 60)),
    ]

    write_access = meta.get("write_access", "full")
    allows = meta.get("path_allows", []) or []
    denies = meta.get("path_denies", []) or []

    if write_access == "none":
        lines.append("tools: Read, Grep, Glob, Bash")

    lines.append("---")
    lines.append("")

    # Claude Code kennt keine pfadbeschraenkten Tool-Erlaubnisse. Wo die
    # Absicht eine braucht, wird sie hier als Regel in den System-Prompt
    # geschrieben - schwaecher als eine Durchsetzung, aber besser als
    # nichts. Mechanisch abgesichert wird sie zusaetzlich durch die
    # Diff-Pruefung des Orchestrators (AGENT_WORKFLOW.md, Teil D).
    if write_access == "limited" and allows:
        lines.append("> **Schreibrechte:** Du darfst ausschliesslich unter diesen Pfaden")
        lines.append("> schreiben: `{}`. Alles andere liest du nur.".format("`, `".join(allows)))
        lines.append("> (In diesem Harness nicht mechanisch erzwungen - der Orchestrator")
        lines.append("> prueft es nach deinem Lauf per `git diff`.)")
        lines.append("")
    elif write_access == "full" and denies:
        lines.append("> **Schreibverbot:** Du aenderst unter keinen Umstaenden Dateien")
        lines.append("> unter `{}`.".format("`, `".join(denies)))
        lines.append("> (In diesem Harness nicht mechanisch erzwungen - der Orchestrator")
        lines.append("> prueft es nach deinem Lauf per `git diff`.)")
        lines.append("")

    return "\n".join(lines) + "\n" + body


def opencode_adapter(meta, tiers, body):
    """OpenCode: permission-Map mit Glob-Mustern, freie Modellwahl."""
    role = meta["role"]
    lines = [
        "---",
        BANNER,
        SOURCE_NOTE.format(role=role),
        "description: {}".format(meta["description"]),
        "mode: {}".format("primary" if meta.get("kind") == "primary" else "subagent"),
        "model: {}".format(tiers["opencode"][meta["model_tier"]]),
        "steps: {}".format(meta.get("max_steps", 60)),
        "permission:",
    ]

    write_access = meta.get("write_access", "full")
    allows = meta.get("path_allows", []) or []
    denies = meta.get("path_denies", []) or []

    # Reihenfolge zaehlt: die letzte passende Regel gewinnt, also "*" zuerst.
    if write_access == "none":
        lines.append("  edit: deny")
    elif write_access == "limited":
        lines.append("  edit:")
        lines.append('    "*": deny')
        for pattern in allows:
            lines.append('    "{}": allow'.format(pattern))
    else:
        if denies:
            lines.append("  edit:")
            lines.append('    "*": allow')
            for pattern in denies:
                lines.append('    "{}": deny'.format(pattern))
        else:
            lines.append("  edit: allow")

    lines.append("  bash: allow")
    lines.append("---")
    lines.append("")
    return "\n".join(lines) + "\n" + body


# --------------------------------------------------------------------------

def main():
    check_only = "--check" in sys.argv

    if not AGENTS_DIR.is_dir():
        sys.exit("Fehler: {} nicht gefunden. Aus dem Projekt-Root aufrufen.".format(AGENTS_DIR))

    tiers_file = AGENTS_DIR / "_tiers.yml"
    if not tiers_file.is_file():
        sys.exit("Fehler: {} fehlt.".format(tiers_file))
    tiers = parse_yaml_subset(tiers_file.read_text(encoding="utf-8"))

    for harness in ("claude", "opencode"):
        if harness not in tiers:
            sys.exit("Fehler: '{}' fehlt in _tiers.yml.".format(harness))

    targets = []
    for meta_file in sorted(AGENTS_DIR.glob("*.meta.yml")):
        role = meta_file.name[: -len(".meta.yml")]
        body_file = AGENTS_DIR / "{}.md".format(role)
        if not body_file.is_file():
            sys.exit("Fehler: {} hat keine Body-Datei {}.".format(meta_file.name, body_file))

        meta = parse_yaml_subset(meta_file.read_text(encoding="utf-8"))
        for required in ("role", "description", "model_tier"):
            if required not in meta:
                sys.exit("Fehler: '{}' fehlt in {}.".format(required, meta_file.name))
        if meta["model_tier"] not in tiers["claude"]:
            sys.exit("Fehler: unbekannter model_tier '{}' in {}.".format(meta["model_tier"], meta_file.name))

        body = body_file.read_text(encoding="utf-8")

        # Der Orchestrator ist die Hauptschleife, kein Sub-Agent: Claude Code
        # laedt ihn ueber AGENTS.md/CLAUDE.md, nicht aus .claude/agents/.
        if meta.get("kind") != "primary":
            targets.append((CLAUDE_DIR / "{}.md".format(role), claude_adapter(meta, tiers, body)))
        targets.append((OPENCODE_DIR / "{}.md".format(role), opencode_adapter(meta, tiers, body)))

    if not targets:
        sys.exit("Fehler: keine *.meta.yml unter {} gefunden.".format(AGENTS_DIR))

    stale = []
    for path, content in targets:
        if not path.is_file() or path.read_text(encoding="utf-8") != content:
            stale.append(path)

    if check_only:
        if stale:
            print("Nicht aktuell ({}):".format(len(stale)))
            for path in stale:
                print("  {}".format(path))
            print("\n-> python3 .agent/sync-agents.py")
            return 1
        print("Aktuell: {} generierte Datei(en).".format(len(targets)))
        return 0

    for path, content in targets:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    print("Generiert: {} Datei(en) aus {} Rolle(n).".format(
        len(targets), len(list(AGENTS_DIR.glob("*.meta.yml")))))
    for path, _ in targets:
        print("  {}".format(path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
