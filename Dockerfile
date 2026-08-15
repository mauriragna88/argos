# ARNES ARGOS - imagen para correr el harness en cualquier PC
# Base: PowerShell Core (pwsh) sobre Ubuntu LTS
FROM mcr.microsoft.com/powershell:lts-7.4-ubuntu-22.04

ENV DEBIAN_FRONTEND=noninteractive

# Prerrequisitos: git + node (para opencode CLI y el paquete npm)
RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# OpenCode CLI (motor de agentes)
RUN npm install -g opencode-ai

WORKDIR /opt/arnes
COPY . .

# Instalar el harness (postinstall sincroniza agentes y crea conexiones)
RUN npm install --production --ignore-scripts=false || true

# El workspace del usuario se monta en /workspace (ver docker-compose.yml)
WORKDIR /workspace

# argos es la entrada principal
ENTRYPOINT ["pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "/opt/arnes/cli/argos.ps1"]
CMD []
