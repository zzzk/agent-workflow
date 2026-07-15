# Sandbox-Image für "volle Freiheit"-Agent-Ausführung (bypassPermissions).
# Sicherheits-Kontext/Begründung: siehe SANDBOX_BOOTSTRAP_PATTERN.md in
# diesem Ordner. Dieses Dockerfile ist projektunabhängig — projektspezifisches
# Setup (z.B. .venv-backup-tool, requirements.txt) macht der Agent selbst
# beim Start gemäss dem jeweiligen Projekt-AGENTS.md, nicht dieses Image.

FROM node:22-slim

# git: fürs Lesen der (read-only gemounteten) Historie im Container.
# python3/venv/pip: Standard-Toolchain für Python-Projekte wie backupEncrypted.
# curl/ca-certificates: für spätere Installationsschritte innerhalb der Sandbox.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       python3 \
       python3-venv \
       python3-pip \
       curl \
       ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# Bind-Mount-Zielpunkt für das Projektverzeichnis (siehe README.md /
# SANDBOX_BOOTSTRAP_PATTERN.md für die -v-Flags beim Start).
WORKDIR /work

CMD ["claude"]
