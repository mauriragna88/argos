# atlas-init.ps1 - Inicializador idempotente del entorno Atlas
# =============================================
# Se ejecuta automaticamente al iniciar Atlas en cualquier plataforma
# (OpenCode/Codex/Claude). Crea .arnes/ si no existe, sincroniza
# agentes y skill trees, inicializa quest-ledger.
#
# Idempotente: corre multiples veces sin daño.

#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# === Forzar salida UTF-8 para el banner (Windows Terminal / VSCode / cualquier consola) ===
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch { /* consolas viejas: se usa lo que haya */ }

# === Determinar ROOT del repo Atlas ===
# Busca ~/arnes o la ruta donde esta este script
$ScriptDir = $PSScriptRoot
if (Test-Path (Join-Path $ScriptDir "..\core\atlas-player.agent.md")) {
    # Estamos dentro del repo arnes
    $REPO_ROOT = Resolve-Path (Join-Path $ScriptDir "..")
} elseif (Test-Path (Join-Path $ScriptDir "core\atlas-player.agent.md")) {
    $REPO_ROOT = Resolve-Path $ScriptDir
} else {
    # Estamos en el directorio de instalacion (~/.local/bin o WindowsApps)
    # Buscar ~/arnes
    $homeInstall = Join-Path $HOME "arnes"
    if (Test-Path (Join-Path $homeInstall "core\atlas-player.agent.md")) {
        $REPO_ROOT = Resolve-Path $homeInstall
    } else {
        Write-Error "No encuentro el repo arnes. Esperaba ~/arnes o ejecutar desde el repo."
        exit 1
    }
}

# === Determinar PROJECT_ROOT (donde corre Atlas) ===
$PROJECT_ROOT = (Get-Location).Path
$ArnesDir     = Join-Path $PROJECT_ROOT ".arnes"

# === Output helpers ===
function Step($m) { Write-Host "  [INIT] $m" -ForegroundColor Cyan }
function OK($m)   { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Minor($m) { Write-Host "         $m" -ForegroundColor DarkGray }
function Warn($m) { Write-Host "  [!]   $m" -ForegroundColor Yellow }

# === Banner ASCII mamalon - ARNES en rojo y negro ===
function Show-AtlasBanner {
    # Borde superior
    Write-Host ""
    Write-Host "      ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄" -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "        █████╗ ██████╗ ██████╗  ██████╗ ███████╗" -ForegroundColor Red
    Write-Host "       ██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗██╔════╝" -ForegroundColor White
    Write-Host "       ███████║██████╔╝██║  ███╗██║   ██║███████╗" -ForegroundColor Red
    Write-Host "       ██╔══██║██╔══██╗██║   ██║██║   ██║╚════██║" -ForegroundColor White
    Write-Host "       ██║  ██║██║  ██║╚██████╔╝╚██████╔╝███████║" -ForegroundColor Red
    Write-Host "       ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝" -ForegroundColor White
    Write-Host ""
    Write-Host "      ⚔═══════════════════════════════════════════════════════════════════⚔" -ForegroundColor DarkRed
    Write-Host "      ⚔   ARNES ARGOS · EL ORQUESTADOR RPG · LOS 100 OJOS   ⚔" -ForegroundColor White
    Write-Host "      ⚔═══════════════════════════════════════════════════════════════════⚔" -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "      ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀" -ForegroundColor DarkRed
    Write-Host ""
}

Show-AtlasBanner

Step "Atlas Harness RPG - Inicializador automatico"
Step "Repo arnes:   $REPO_ROOT"
Step "Proyecto:     $PROJECT_ROOT"
Write-Host ""

# === 1. Crear .arnes/ si no existe ===
if (-not (Test-Path $ArnesDir)) {
    Step "Creando .arnes/ en proyecto..."
    New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null
    OK ".arnes/ creado"
} else {
    Minor ".arnes/ ya existe"
}

# === 2. Sincronizar agentes a ~/.config/opencode/agents ===
$targetAgentsDir = "$env:USERPROFILE/.config/opencode/agents"
if (-not (Test-Path $targetAgentsDir)) {
    New-Item -ItemType Directory -Path $targetAgentsDir -Force | Out-Null
}

$agents = @{
    "atlas-player"         = "core\atlas-player.agent.md"
    "vivi"                 = "core\classes\mage.agent.md"
    "eiko"                 = "core\classes\eiko.agent.md"
    "ansem"                = "core\classes\paladin.agent.md"
    "kuja"                 = "core\classes\rogue.agent.md"
    "amarant"              = "core\classes\monk.agent.md"
    "eremez"               = "core\classes\ranger.agent.md"
    "bard"                 = "core\classes\bard.agent.md"
    "tywin"                = "core\auditors\tywin.agent.md"
    "varys"                = "core\auditors\varys.agent.md"
    "varys-documentalist"  = "core\auditors\varys-documentalist.agent.md"
    "sam"                  = "core\auditors\sam.agent.md"
    "bran"                 = "core\auditors\bran.agent.md"
    "quina"                = "core\auditors\quina.agent.md"
    "auron"                = "core\auditors\auron.agent.md"
}

$agentCount = 0
foreach ($k in $agents.Keys) {
    $src = Join-Path $REPO_ROOT $agents[$k]
    if (Test-Path $src) {
        Copy-Item $src -Destination (Join-Path $targetAgentsDir "$k.md") -Force
        $agentCount++
    }
}
OK "$agentCount agentes sincronizados a $targetAgentsDir"

# === 3. Sincronizar skill trees a ~/.config/opencode/skills/atlas/ ===
$targetSkillsDir = "$env:USERPROFILE/.config/opencode/skills/atlas"
if (-not (Test-Path $targetSkillsDir)) {
    New-Item -ItemType Directory -Path $targetSkillsDir -Force | Out-Null
}
$srcSkillsDir = Join-Path $REPO_ROOT "core\skills"
if (Test-Path $srcSkillsDir) {
    $skillCount = 0
    Get-ChildItem $srcSkillsDir -Filter "*.json" | ForEach-Object {
        Copy-Item $_.FullName -Destination (Join-Path $targetSkillsDir $_.Name) -Force
        $skillCount++
    }
    OK "$skillCount skill trees sincronizados"
} else {
    Minor "No hay skill trees en $srcSkillsDir"
}

# === 4. Crear config.json si no existe ===
$configFile = Join-Path $ArnesDir "config.json"
if (-not (Test-Path $configFile)) {
    Step "Creando .arnes/config.json (primera vez)..."
    $defaultConfig = @{
        version = "1.0.0"
        codename = "atlas-harness-rpg"
        configured_at = (Get-Date -Format "o")
        player = @{
            name = "Atlas"
            role = "Player / Orchestrator"
            model = "auto"
            colors = @("#C8102E", "#1A1A1A")
            tagline = "Rojo y Negro como el Atlas de la Liga MX"
        }
        subscription = @{
            opencode = "pro"
            codex = $null
            claude = $null
        }
        provider = @{
            primary = "auto-detect"
            quality_mode = "balance"
        }
        models = @{}
        preferences = @{
            default_party_size = 4
            auto_loop = $true
            show_tokens = $true
            show_hp_mp = $true
            theme = "atlas-rojo-negro"
            language = "es-MX"
        }
        # Repo size auto-deteccion - Bran lee este campo para ajustar party_size / model tier
        # Override CLI flags (--lean, --full-party, --boss-party) escriben aqui
        repo_root = @{
            tier = "auto"                  # auto | lean | medium | standard | boss
            override_tier = $null           # seteado por CLI flags, null = Bran decide
            override_party_size = $null     # seteado por --full-party / --lean
            override_model_tier = $null     # seteado por --lean (free) / --boss (highest)
            last_eval_at = $null
            next_eval_after_quest = 0       # Bran recalcula cada 20 quests
            loc = 0
            file_count = 0
            module_count = 0
        }
        characters = @{}
    }
    $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configFile -Encoding UTF8
    OK "config.json creado con defaults"
} else {
    Minor "config.json ya existe"
}

# === 5. Crear quest-ledger.json si no existe ===
$ledgerFile = Join-Path $ArnesDir "quest-ledger.json"
if (-not (Test-Path $ledgerFile)) {
    Step "Creando .arnes/quest-ledger.json..."
    $ledger = @{
        version = "1.0.0"
        purpose = "Registro persistente de quests, tokens gastados, y limites semanales"
        weekly_reset_day = "monday"
        weekly_reset_hour_utc = 0
        limits = @{
            weekly_tokens_budget = 1000000
            weekly_tokens_used = 0
            weekly_tokens_remaining = 1000000
            warn_threshold_pct = 80
            critical_threshold_pct = 95
        }
        by_platform = @{
            opencode = @{ tier = "pro"; weekly_limit = 1000000; actual_used = 0 }
            codex    = @{ tier = $null; weekly_limit = $null; actual_used = 0 }
            claude   = @{ tier = $null; weekly_limit = $null; actual_used = 0 }
        }
        quests = @()
        stats = @{
            total_quests = 0
            total_tokens_used = 0
            avg_tokens_per_quest = 0
            success_rate_pct = 0
        }
    }
    $ledger | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ledgerFile -Encoding UTF8
    OK "quest-ledger.json creado"
} else {
    Minor "quest-ledger.json ya existe"
}

# === 6. Correr Repo Sizer para Bran (idempotente) ===
$repoProfileFile = Join-Path $ArnesDir "repo-profile.json"
$repoProfiler    = Join-Path $REPO_ROOT "cli\repo-profile.ps1"
if ((Test-Path $repoProfiler)) {
    if (-not (Test-Path $repoProfileFile)) {
        Step "Corriendo Repo Sizer para Bran..."
        & $repoProfiler -ProjectPath $PROJECT_ROOT -ArnesDir $ArnesDir -Silent
        if (Test-Path $repoProfileFile) {
            try {
                $rp = Get-Content -LiteralPath $repoProfileFile -Raw | ConvertFrom-Json
                OK "repo-profile.json: tier=$($rp.repo_tier) party=$($rp.recommended_party_size) model=$($rp.recommended_model_tier)"
                if ($rp.growth_hint) {
                    Minor "  growth: $($rp.growth_hint)"
                }
            } catch {
                Minor "  (no se pudo leer repo-profile.json: $($_.Exception.Message))"
            }
        }
    } else {
        try {
            $rp = Get-Content -LiteralPath $repoProfileFile -Raw | ConvertFrom-Json
            Minor "repo-profile.json ya existe: tier=$($rp.repo_tier)"
        } catch { Minor "repo-profile.json ya existe" }
    }
} else {
    Minor "repo-profile.ps1 no encontrado en $repoProfiler"
}

# === 7. Smoke test rapido ===
$smokeScript = Join-Path $REPO_ROOT "cli\smoke-test.ps1"
if (Test-Path $smokeScript) {
    Step "Corriendo smoke test para validar el harness..."
    & $smokeScript -ProjectPath $PROJECT_ROOT -Silent
    if ($LASTEXITCODE -eq 0) {
        OK "Smoke test: 15/15 PASS - harness saludable"
    } else {
        Warn "Smoke test fallo ($LASTEXITCODE). Corre smoke-test.ps1 sin -Silent para ver detalle."
    }
    Write-Host ""
}

# === 8. Resumen ===
Write-Host ""
Write-Host "  ATLAS ENTORNO LISTO" -ForegroundColor Red
Write-Host ""
Write-Host "  Ubicacion:        $ArnesDir"
Write-Host "  Agentes sync:     $agentCount"
try {
    # Leer # quests del proyecto actual del ledger
    $ledger = Get-Content $LedgerFile -Raw -ErrorAction Stop | ConvertFrom-Json
    $qCount = [int]$ledger.stats.total_quests
    $qTokens = [int]$ledger.stats.total_tokens_used
    Write-Host "  Quests:           $qCount ($qTokens tokens total)"
} catch { Write-Host "  Quests registradas: 0" }
Write-Host ""
