# Sandbox-Image für "volle Freiheit"-Agent-Ausführung (bypassPermissions).
# Sicherheits-Kontext/Begründung: siehe SANDBOX_BOOTSTRAP_PATTERN.md in
# diesem Ordner. Dieses Dockerfile ist projektunabhängig — projektspezifisches
# Setup (z.B. .venv-backup-tool, requirements.txt) macht der Agent selbst
# beim Start gemäss dem jeweiligen Projekt-AGENTS.md, nicht dieses Image.
#
# Enthaltene Toolchains: Node (Basis-Image), Python 3, JDK + Maven. Bewusst
# ein gemeinsames Polyglott-Image statt mehrerer abgeleiteter: Layer werden
# von allen Containern geteilt (Platz wird einmal bezahlt, nicht je Container)
# und die Grösse kostet zur Laufzeit nichts — Layer werden gemountet, nicht
# kopiert, ein ungenutztes JDK belegt weder RAM noch CPU.

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

# --- JVM-Toolchain (Spring Boot / Spring AI u.ä.) -------------------------
# Debian bookworm liefert per apt nur JDK 17; Java 25 kommt deshalb aus dem
# Adoptium-Repo (Eclipse Temurin), signiert gegen dessen GPG-Key.
ARG TEMURIN_MAJOR=25
RUN apt-get update \
    && apt-get install -y --no-install-recommends wget gnupg \
    && wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public \
       | gpg --dearmor > /usr/share/keyrings/adoptium.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(. /etc/os-release && echo $VERSION_CODENAME) main" \
       > /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends "temurin-${TEMURIN_MAJOR}-jdk" \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s "/usr/lib/jvm/temurin-${TEMURIN_MAJOR}-jdk-$(dpkg --print-architecture)" /usr/lib/jvm/temurin
# Temurin installiert arch-suffixiert (…-jdk-arm64 / …-jdk-amd64); der Symlink
# oben macht JAVA_HOME davon unabhängig. Ohne ihn zeigt JAVA_HOME ins Leere
# und Maven bricht mit "JAVA_HOME is not defined correctly" ab.
ENV JAVA_HOME=/usr/lib/jvm/temurin

# Maven als Apache-Tarball statt per apt: das Debian-Paket zieht
# default-jre-headless (JDK 17) als Abhängigkeit nach und würde damit ein
# zweites, älteres JDK neben Temurin installieren. Checksumme von
# dlcdn.apache.org, Version bewusst gepinnt (mise.toml-Projekte fordern "3").
ARG MAVEN_VERSION=3.9.16
ARG MAVEN_SHA512=831a8591fe20c8243b1dbe7d71e3244f31d1665b0804b2e825e38cbbe5ce0cafb8338851f90780735568773e0a6cd07bbec107cda0b896b008b861075358b6f6
RUN wget -q "https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" -O /tmp/maven.tar.gz \
    && echo "${MAVEN_SHA512}  /tmp/maven.tar.gz" | sha512sum -c - \
    && tar -xzf /tmp/maven.tar.gz -C /opt \
    && ln -s "/opt/apache-maven-${MAVEN_VERSION}/bin/mvn" /usr/local/bin/mvn \
    && rm /tmp/maven.tar.gz

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
