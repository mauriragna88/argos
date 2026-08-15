#!/usr/bin/env bash
# activate.sh - Atlas Harness RPG activation (Linux / Mac)
# =============================================
# Uso: ./cli/activate.sh
# Equivalente bash de activate.ps1 para sistemas Linux/Mac.
# Detecta plataforma, sync agentes a OpenCode, lanza OpenCode con Atlas como primary.
#
# Requiere: pwsh (PowerShell Core) SI quieres usar atlas.ps1 completo.
#           Para modo bash-only (sin pwsh), este script hace sync + print party.

set -e

# === Resolver ROOT del repo ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$ROOT/.arnes"
CONFIG_FILE="$CONFIG_DIR/config.json"

# === Colores ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m'

Step()  { echo ""; echo -e "  ${CYAN}> $1${NC}"; }
OK()    { echo -e "  ${GREEN}[OK] $1${NC}"; }
Warn()  { echo -e "  ${YELLOW}[!] $1${NC}"; }
Line()  { echo -e "  ${WHITE}$1${NC}"; }
Minor() { echo -e "      ${GRAY}$1${NC}"; }
Fail()  { echo -e "  ${RED}[X] $1${NC}"; exit 1; }

echo ""
echo "========================================================"
echo -e "  ${RED}ATLAS HARNESS RPG - activador (Linux/Mac)${NC}"
echo -e "  ${RED}Rojo & Negro, Atlas de la Liga MX${NC}"
echo "========================================================"

# === 1. Verificar que estamos en el repo arnes ===
if [[ ! -f "$ROOT/core/atlas-player.agent.md" ]]; then
    Fail "No encontre core/atlas-player.agent.md. No estoy en el repo arnes."
fi
OK "Repo arnes: $ROOT"

# === 2. Parsear CLI flags (--lean, --full-party, --boss-party, --auto) ===
PARTY_OVERRIDE=""
QUEST_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --lean)         PARTY_OVERRIDE="lean" ;;
        --medium)       PARTY_OVERRIDE="medium" ;;
        --standard)     PARTY_OVERRIDE="standard" ;;
        --boss|--boss-party) PARTY_OVERRIDE="boss" ;;
        --full-party)   PARTY_OVERRIDE="full" ;;
        --auto)         PARTY_OVERRIDE="" ;;
        *)              QUEST_ARGS+=("$arg") ;;
    esac
done
INITIAL_QUEST="${QUEST_ARGS[*]}"

# === 3. Aplicar override a .arnes/config.json ===
if [[ -n "$PARTY_OVERRIDE" && -f "$CONFIG_FILE" ]]; then
    if command -v jq >/dev/null 2>&1; then
        case "$PARTY_OVERRIDE" in
            lean|medium|standard|boss)
                jq --arg t "$PARTY_OVERRIDE" '.repo_root.override_tier = $t' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
                ;;
            full)
                jq '.repo_root.override_tier = null | .repo_root.override_party_size = 6 | .repo_root.override_model_tier = "pro"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
                ;;
        esac
        Minor "Override aplicado a config.json: $PARTY_OVERRIDE"
    else
        Warn "jq no instalado - no se pudo aplicar override. Instala jq o edita config.json manualmente."
    fi
fi

# === 4. Detectar plataforma ===
Step "Detectando plataforma..."
PLATFORMS=()
if [[ -d "$HOME/.config/opencode" ]]; then
    PLATFORMS+=("OpenCode")
fi
if command -v codex >/dev/null 2>&1; then
    PLATFORMS+=("Codex")
fi
if [[ -d "$HOME/.claude" ]] || command -v claude >/dev/null 2>&1; then
    PLATFORMS+=("Claude")
fi

PLATFORM=""
if [[ ${#PLATFORMS[@]} -eq 1 ]]; then
    PLATFORM="${PLATFORMS[0]}"
elif [[ ${#PLATFORMS[@]} -gt 1 ]]; then
    echo -e "  ${WHITE}Detectadas varias plataformas:${NC}"
    for i in "${!PLATFORMS[@]}"; do
        echo -e "  ${WHITE}[$((i+1))] ${PLATFORMS[$i]}${NC}"
    done
    read -p "  Elige: " sel
    PLATFORM="${PLATFORMS[$((sel-1))]}"
else
    echo -e "  ${WHITE}[1] OpenCode  [2] Codex  [3] Claude${NC}"
    read -p "  Elige: " sel
    case "$sel" in
        1) PLATFORM="OpenCode" ;;
        2) PLATFORM="Codex" ;;
        3) PLATFORM="Claude" ;;
        *) Fail "Plataforma invalida" ;;
    esac
fi
OK "Plataforma: $PLATFORM"

# === 5. Sync agentes a ~/.config/opencode/agents ===
Step "Sincronizando agentes..."
TARGET_AGENTS_DIR="$HOME/.config/opencode/agents"
mkdir -p "$TARGET_AGENTS_DIR"

declare -A AGENTS=(
    ["atlas-player"]="core/atlas-player.agent.md"
    ["vivi"]="core/classes/eiko.agent.md"
    ["eiko"]="core/classes/eiko.agent.md"
    ["ansem"]="core/classes/paladin.agent.md"
    ["kuja"]="core/classes/rogue.agent.md"
    ["amarant"]="core/classes/monk.agent.md"
    ["eremez"]="core/classes/ranger.agent.md"
    ["bard"]="core/classes/bard.agent.md"
    ["varys"]="core/auditors/varys.agent.md"
    ["varys-documentalist"]="core/auditors/varys-documentalist.agent.md"
    ["tywin"]="core/auditors/tywin.agent.md"
    ["sam"]="core/auditors/sam.agent.md"
    ["auron"]="core/auditors/auron.agent.md"
    ["bran"]="core/auditors/bran.agent.md"
    ["quina"]="core/auditors/quina.agent.md"
)

AGENT_COUNT=0
for name in "${!AGENTS[@]}"; do
    src="$ROOT/${AGENTS[$name]}"
    if [[ -f "$src" ]]; then
        cp "$src" "$TARGET_AGENTS_DIR/$name.md"
        ((AGENT_COUNT++))
    fi
done
OK "$AGENT_COUNT agentes sincronizados a $TARGET_AGENTS_DIR"

# === 6. Sync skill trees ===
TARGET_SKILLS_DIR="$HOME/.config/opencode/skills/atlas"
mkdir -p "$TARGET_SKILLS_DIR"
SRC_SKILLS_DIR="$ROOT/core/skills"
SKILL_COUNT=0
if [[ -d "$SRC_SKILLS_DIR" ]]; then
    for f in "$SRC_SKILLS_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        cp "$f" "$TARGET_SKILLS_DIR/$(basename "$f")"
        ((SKILL_COUNT++))
    done
    OK "$SKILL_COUNT skill trees copiados a $TARGET_SKILLS_DIR"
else
    Warn "No hay skill trees en $SRC_SKILLS_DIR"
fi

# === 7. Ejecutar atlas-init (si pwsh disponible) ===
if command -v pwsh >/dev/null 2>&1; then
    Step "Ejecutando atlas-init.ps1 (via pwsh)..."
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$ROOT/cli/atlas-init.ps1" -RepoRoot "$ROOT" || {
        Warn "atlas-init.ps1 fallo. Continuando sin init completo."
    }
else
    Step "pwsh no detectado - init minimal bash"
    mkdir -p "$CONFIG_DIR"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo '{"version":"1.0.0","codename":"atlas-harness-rpg","configured_at":"'$(date -Iseconds)'","player":{"name":"Atlas","role":"Player / Orchestrator"}}' > "$CONFIG_FILE"
        OK "config.json creado (minimal)"
    fi
    LEDGER="$CONFIG_DIR/quest-ledger.json"
    if [[ ! -f "$LEDGER" ]]; then
        echo '{"version":"1.0.0","quests":[],"stats":{"total_quests":0,"total_tokens_used":0}}' > "$LEDGER"
        OK "quest-ledger.json creado (minimal)"
    fi
fi

# === 8. Lanzar plataforma ===
Step "Lanzando $PLATFORM..."
if [[ -n "$INITIAL_QUEST" ]]; then
    Minor "Quest inicial: $INITIAL_QUEST"
fi

case "$PLATFORM" in
    OpenCode)
        if command -v opencode >/dev/null 2>&1; then
            if [[ -n "$INITIAL_QUEST" ]]; then
                opencode --prompt "$INITIAL_QUEST"
            else
                opencode
            fi
        else
            Warn "opencode CLI no en PATH. Abre OpenCode manualmente."
            EvenatanFallback
        fi
        ;;
    Codex)
        if command -v codex >/dev/null 2>&1; then
            if [[ -n "$INITIAL_QUEST" ]]; then
                codex --prompt "$INITIAL_QUEST"
            else
                codex
            fi
        else
            Warn "codex CLI no en PATH. Abre Codex manualmente."
            EvenatanFallback
        fi
        ;;
    Claude)
        if command -v claude >/dev/null 2>&1; then
            if [[ -n "$INITIAL_QUEST" ]]; then
                claude --print "$INITIAL_QUEST"
            else
                claude
            fi
        else
            Warn "claude CLI no en PATH. Abre Claude Code manualmente."
            EvenatanFallback
        fi
        ;;
    *)
        EvenatanFallback
        ;;
esac

# === Evenatan fallback (modo offline, sin IA) ===
EvenatanFallback() {
    echo ""
    echo "========================================================"
    echo -e "  ${RED}EVENATAN - Terminal RPG (modo offline)${NC}"
    echo "========================================================"
    Line "Party: Vivi, Eiko, Ansem, Kuja, Amarant, Eremez"
    Line "Audit: Varys (Tracker), Tywin (Verifier), Sam (Archivist)"
    Line "Especiales: Auron (Security), Bran (Seer), Quina (Banker)"
    echo ""
    Minor "Commands: /party /audit /skills /status /audit-docs /pause /resume /save /quit"
    echo ""
    while true; do
        echo -ne "  ${RED}ATLAS> ${NC}"
        read -r inp
        [[ -z "$inp" ]] && continue
        case "$inp" in
            /quit|/exit)
                Line "Cerrando ATLAS."
                break
                ;;
            /party)
                Line "VIVI(Mage) EIKO(Cleric) ANSEM(Paladin) KUJA(Rogue) AMARANT(Monk) EREMEZ(Ranger)"
                ;;
            /audit)
                Line "VARYS(Tracker) TYWIN(Verifier) SAM(Archivist)"
                ;;
            /special)
                Line "AURON(Warden) BRAN(Seer) QUINA(Banker)"
                ;;
            /skills)
                Line "Vivi: Fireball/Flare/Inferno/Meteor | Eiko: Mend/Esuna/Cura/Mass Heal"
                ;;
            /status)
                Minor "HP: 85/120 MP: 12K/18K  Streak: 10"
                ;;
            /audit-docs)
                Minor "Triggering Varys Documentalist audit..."
                Line "VARYS-DOC: Mis pajaritos estan volando sobre el repo..."
                Minor "(Offline - no real audit. Abre OpenCode y usa @varys-documentalist)"
                ;;
            /save)
                Minor "Estado guardado .arnes/save/quest-state.json"
                ;;
            /pause)
                Line "PAUSE. Escribe /resume."
                ;;
            /resume)
                Line "RESUMED!"
                ;;
            *)
                Line "[QUEST RECEIVED]"
                Minor "  (Sin IA offline. Abre OpenCode y usa @atlas-player)"
                ;;
        esac
    done
}
