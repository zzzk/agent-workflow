# Sandbox-Image für "volle Freiheit"-Agent-Ausführung (bypassPermissions).
# Sicherheits-Kontext/Begründung: siehe SANDBOX_BOOTSTRAP_PATTERN.md in
# diesem Ordner. Dieses Dockerfile ist projektunabhängig — projektspezifisches
# Setup (z.B. .venv-backup-tool, requirements.txt) macht der Agent selbst
# beim Start gemäss dem jeweiligen Projekt-AGENTS.md, nicht dieses Image.

FROM node:22-slim

# git: fürs Lesen der (read-only gemounteten) Historie im Container.
# python3/venv/pip: Standard-Toolchain für Python-Projekte wie backupEncrypted.
# curl/ca-certificates: für spätere Installationsschritte innerhalb der Sandbox.
# jq/bc: von project-template/.claude/statusline.sh benötigt (Kontextfenster-
# und Ratenlimit-Anzeige in der Statuszeile).
# sudo: der Agent läuft als Non-Root-User (siehe unten), braucht aber weiterhin
# Rückfragen-frei apt-get etc. innerhalb des Containers (Sandbox-Grenze bleibt
# der Container selbst, siehe SANDBOX_BOOTSTRAP_PATTERN.md Schritt 0).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       python3 \
       python3-venv \
       python3-pip \
       curl \
       ca-certificates \
       jq \
       bc \
       sudo \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# Claude Code verweigert --dangerously-skip-permissions / defaultMode
# "bypassPermissions" (siehe SANDBOX_BOOTSTRAP_PATTERN.md Schritt 1), wenn
# der Prozess als root läuft ("cannot be used with root/sudo privileges").
# Deshalb hier bewusst ein Non-Root-User statt des Container-Default-root,
# mit passwortlosem sudo (nur innerhalb des Containers wirksam), damit
# apt-get/pip-Installationen weiterhin ohne Rückfrage möglich sind.
RUN useradd --create-home --shell /bin/bash agent \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent
USER agent
ENV HOME=/home/agent

# Bind-Mount-Zielpunkt für das Projektverzeichnis (siehe README.md /
# SANDBOX_BOOTSTRAP_PATTERN.md für die -v-Flags beim Start).
WORKDIR /work

CMD ["claude"]
