#!/usr/bin/env bash
# install.sh - Atlas Harness RPG Installer (Linux / Mac)
# =============================================
# Uso: ./install.sh
# O one-liner:
#   curl -fsSL https://raw.githubusercontent.com/mauriragna88/arnes/main/install.sh | bash
#
# Requiere: git, pwsh (PowerShell Core)

set -e

REPO_URL="https://github.com/mauriragna88/arnes.git"
REPO_BRANCH="main"
INSTALL_DIR="$HOME/arnes"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
GRAY="\033[0;90m"
NC="\033[0m" # No Color

Step() { echo ""; echo -e "  ${CYAN}> $1${NC}"; }
OK()   { echo -e "  ${GREEN}[OK] $1${NC}"; }
Warn() { echo -e "  ${YELLOW}[!] $1${NC}"; }
Fail() { echo -e "  ${RED}[X] $1${NC}"; exit 1; }
Minor(){ echo -e "      ${GRAY}$1${NC}"; }

echo ""
echo "========================================================"
echo -e "  ${RED}ATLAS HARNESS RPG - Installer (Linux/Mac)${NC}"
echo -e "  ${RED}Rojo & Negro, Atlas de la Liga MX${NC}"
echo "========================================================"
echo ""

# === Pre-check: git ===
Step "Verificando git..."
if ! command -v git >/dev/null 2>&1; then
    Fail "git no esta instalado. Instala git primero."
fi
GIT_VER=$(git --version | sed 's/git version //')
OK "git $GIT_VER detectado"

# === Pre-check: pwsh ===
Step "Verificando PowerShell Core (pwsh)..."
if ! command -v pwsh >/dev/null 2>&1; then
    Warn "PowerShell Core (pwsh) no esta instalado."
    echo -e "      ${GRAY}Instala con: brew install --cask powershell (Mac) o sudo apt install pwsh (Linux)${NC}"
    Fail "Atlas requiere pwsh para ejecutar el harness."
fi
PWSH_VER=$(pwsh --version | sed 's/PowerShell v//')
OK "pwsh $PWSH_VER detectado"

# === Pre-check: plataforma IA ===
Step "Detectando plataformas de IA..."
PLATFORMS=()
if [[ -d "$HOME/.config/opencode" ]]; then
    PLATFORMS+=("OpenCode")
    OK "OpenCode encontrado en ~/.config/opencode"
else
    Minor "OpenCode no detectado"
fi
if command -v codex >/dev/null 2>&1; then
    PLATFORMS+=("Codex")
    OK "Codex CLI encontrado"
else
    Minor "Codex CLI no detectado"
fi
if [[ -d "$HOME/.claude" ]] || command -v claude >/dev/null 2>&1; then
    PLATFORMS+=("Claude")
    OK "Claude Code encontrado"
else
    Minor "Claude Code no detectado"
fi

if [ ${#PLATFORMS[@]} -eq 0 ]; then
    Warn "No se detecto ninguna plataforma de IA."
    Warn "Atlas funcionara en modo Evenatan offline hasta que instales una."
fi

# === Clone or update repo ===
Step "Instalando repo arnes en $INSTALL_DIR..."
if [[ -d "$INSTALL_DIR" ]]; then
    Warn "Ya existe una instalacion previa. Actualizando..."
    pushd "$INSTALL_DIR" >/dev/null
    if git pull origin "$REPO_BRANCH" >/dev/null 2>&1; then
        OK "Repo actualizado"
    else
        Warn "No pude hacer pull. Continuando con version actual."
    fi
    popd >/dev/null
else
    if git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR" >/dev/null 2>&1; then
        OK "Repo clonado en $INSTALL_DIR"
    else
        Fail "No pude clonar el repo. Verifica tu conexion o la URL: $REPO_URL"
    fi
fi

# === Crear wrappers globales 'atlas' y 'argos' ===
Step "Creando wrappers 'atlas' y 'argos' en PATH..."
WRAPPER_DIR="$HOME/.local/bin"
mkdir -p "$WRAPPER_DIR"
WRAPPER_PATH="$WRAPPER_DIR/atlas"
cat > "$WRAPPER_PATH" <<EOF
#!/usr/bin/env bash
# atlas wrapper para Linux/Mac
exec pwsh -NoProfile -File "$INSTALL_DIR/cli/atlas.ps1" "\$@"
EOF
chmod +x "$WRAPPER_PATH"
OK "Wrapper 'atlas' creado en $WRAPPER_PATH"
ARGOS_WRAPPER="$WRAPPER_DIR/argos"
cat > "$ARGOS_WRAPPER" <<EOF
#!/usr/bin/env bash
# argos wrapper para Linux/Mac
exec pwsh -NoProfile -File "$INSTALL_DIR/cli/argos.ps1" "\$@"
EOF
chmod +x "$ARGOS_WRAPPER"
OK "Wrapper 'argos' creado en $ARGOS_WRAPPER"

# === Sync inicial ===
Step "Sincronizando agentes, skills y setup global..."
pushd "$INSTALL_DIR" >/dev/null
if pwsh -NoProfile -File "$INSTALL_DIR/cli/atlas.ps1" --sync >/dev/null 2>&1; then
    OK "Sincronizacion inicial completada"
else
    Warn "Sincronizacion inicial fallo. Puedes correr 'argos' despues para reintentar."
fi
pwsh -NoProfile -File "$INSTALL_DIR/cli/argos-connect.ps1" init >/dev/null 2>&1
pwsh -NoProfile -File "$INSTALL_DIR/cli/argos-models-apply.ps1" >/dev/null 2>&1
popd >/dev/null

# === Mensaje final ===
echo ""
echo "========================================================"
echo -e "  ${RED}INSTALACION COMPLETADA${NC}"
echo "========================================================"
echo ""
echo "  Uso:"
echo "    1. Asegurate que ~/.local/bin este en tu PATH"
echo "    2. Abre una NUEVA terminal"
echo "    3. cd <tu-proyecto>"
echo "    4. argos          (entorno: connect -> configure -> chat)"
echo "       argos connect    conectar proveedores (una vez por maquina)"
echo "       argos configure  elegir modelo por agente (una vez por maquina)"
echo ""
echo "  Detectado:    ${PLATFORMS[*]}"
echo "  Instalado en: $INSTALL_DIR"
echo ""
echo "  Si 'atlas' no se encuentra, agrega a tu ~/.bashrc o ~/.zshrc:"
echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
echo ""
