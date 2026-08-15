# Atlas Harness RPG - Installer (Linux / Mac / WSL)
# =================================================
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/mauriragna88/arnes/main/install.sh | bash
#
# O descarga y ejecuta:
#   ./install.sh

set -e

REPO_URL="${ATLAS_REPO_URL:-https://github.com/mauriragna88/arnes.git}"
REPO_BRANCH="${ATLAS_REPO_BRANCH:-main}"
INSTALL_DIR="${ATLAS_INSTALL_DIR:-$HOME/arnes}"

echo "  > Clonando arnes en $INSTALL_DIR ..."
if [[ -d "$INSTALL_DIR" ]]; then
    pushd "$INSTALL_DIR" >/dev/null
    git pull origin "$REPO_BRANCH" >/dev/null 2>&1 || true
    popd >/dev/null
else
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi

echo "  > Creando wrapper ~/.local/bin/atlas ..."
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/atlas" <<EOF
#!/usr/bin/env bash
exec pwsh -NoProfile -File "$INSTALL_DIR/cli/atlas.ps1" "\$@"
EOF
chmod +x "$HOME/.local/bin/atlas"

echo "  > Listo. En una nueva terminal corre: atlas"
