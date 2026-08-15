#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS - El entorno de ARNES ARGOS (Los 100 Ojos)

.DESCRIPTION
El punto de entrada. Detecta si el proyecto esta inicializado, conecta proveedores,
configura modelos por agente, y lanza el chat donde Atlas orquesta.
DENTRO de argos, Atlas es el orquestador principal.
Todo propio: memoria en arnes.db, conexiones globales, cero dependencias externas.

.EXAMPLE
argos                    -> abre OpenCode con el entorno ARNES cargado (Atlas primary)
argos "quest inicial"    -> igual, pasando el quest a Atlas
argos menu               -> menu completo del entorno
argos connect            -> wizard de conexiones (/connect)
argos configure          -> wizard de modelos por agente (/configuremodel)
argos chat               -> chat con Atlas
argos status             -> estado del entorno
argos init               -> inicializar proyecto
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('', 'menu', 'init', 'connect', 'connect-agent', 'configure', 'chat', 'status', 'stats', 'models', 'model', 'memory', 'osma-install', 'recommend', 'mode', 'doctor', 'verify', 'test-model', 'quest', 'party', 'xp', 'theme', 'code', 'opencode', 'target', 'goal', 'audit')]
    [string]$Command = '',

    [Parameter(Position = 1)]
    [string]$Model = '',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'osma-resolve.ps1')
$ScriptDir = $PSScriptRoot
$Root = Resolve-Path (Join-Path $ScriptDir '..')
# El proyecto es la carpeta ACTUAL donde el usuario ejecuto argos (no el repo del script)
$ProjectDir = (Get-Location).Path
$ArnesDir = Join-Path $ProjectDir '.arnes'
$ConfigPath = Join-Path $ArnesDir 'config.json'
# Config GLOBAL de la maquina (una vez por computadora) - gestionada por argos-connect.ps1
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
$GlobalConnPath = Join-Path $GlobalConfigDir 'connections.json'
# Modelos por agente GLOBALES: se configuran UNA vez y se despliegan a los agentes de cualquier proyecto
$AgentModelsPath = Join-Path $GlobalConfigDir 'agent-models.json'
$LocalAgentModelsPath = Join-Path $ArnesDir 'agent-models.json'   # legado (solo para migrar)

# Forzar UTF-8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# === BANNER ARGOS ===
function Show-Banner {
    Write-Host ''
    Write-Host "      ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄" -ForegroundColor DarkRed
    Write-Host ''
    Write-Host "        █████╗ ██████╗ ██████╗  ██████╗ ███████╗" -ForegroundColor Red
    Write-Host "       ██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗██╔════╝" -ForegroundColor White
    Write-Host "       ███████║██████╔╝██║  ███╗██║   ██║███████╗" -ForegroundColor Red
    Write-Host "       ██╔══██║██╔══██╗██║   ██║██║   ██║╚════██║" -ForegroundColor White
    Write-Host "       ██║  ██║██║  ██║╚██████╔╝╚██████╔╝███████║" -ForegroundColor Red
    Write-Host "       ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝" -ForegroundColor White
    Write-Host ''
    Write-Host "      ╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkRed
    Write-Host "      ║   ARNES ARGOS - EL ENTORNO DE LOS 100 OJOS   ║" -ForegroundColor White
    Write-Host "      ╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor DarkRed
    Write-Host ''
    Write-Host "      ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀" -ForegroundColor DarkRed
    Write-Host ''
}

# === Deteccion de consola interactiva ===
$Script:IsInteractive = $true
try { $null = [Console]::CursorVisible } catch { $Script:IsInteractive = $false }

# === Lectura segura (no interactivo: vacio en vez de crashear) ===
function Read-Input {
    param([string]$Prompt)
    try { return Read-Host $Prompt } catch { return '' }
}

# === Reutilizar el motor de recomendacion de argos-recommend.ps1 (dot-source, no ejecuta su main) ===
. (Join-Path $ScriptDir 'argos-recommend.ps1')

# === Guia Ragnarok cuando no hay proveedores conectados ===
function Show-RagnarokGuide {
    Write-Host ''
    Write-Host '  ▸ RAGNAROK (Compras) sugiere conectar:' -ForegroundColor Cyan
    Write-Host '    nvidia      -> DeepSeek V4 Flash/Pro GRATIS (ahorro maximo)' -ForegroundColor White
    Write-Host '    opencode-go -> DeepSeek V4 Flash workhorse + Qwen3.8 Max (Atlas)' -ForegroundColor White
    Write-Host '    openai      -> GPT-5.6 Luna/Terra/Sol (cuenta ChatGPT Plus/Pro)' -ForegroundColor White
    Write-Host '    bai         -> Claude Opus 5 / GPT-5.6 Sol (calidad elite)' -ForegroundColor White
    Write-Host '  Corre: argos connect (una vez por computadora) cuando quieras.' -ForegroundColor DarkGray
    Write-Host ''
}

# === Detectar estado del proyecto ===
function Get-ProjectState {
    $state = [ordered]@{
        is_argos = $false
        has_config = $false
        has_connections = $false
        has_models = $false
        project_name = (Split-Path (Get-Location) -Leaf)
    }
    if (Test-Path $ArnesDir) { $state.is_argos = $true }
    if (Test-Path $ConfigPath) { $state.has_config = $true }
    # Conexiones GLOBALES: hay configuracion si al menos 1 proveedor esta conectado
    if (Test-Path $GlobalConnPath) {
        $conn = Get-Content $GlobalConnPath -Raw | ConvertFrom-Json
        $connected = @($conn.providers.PSObject.Properties | Where-Object { $_.Value.connected })
        if ($connected.Count -gt 0) { $state.has_connections = $true }
    }
    if (Test-Path $AgentModelsPath) { $state.has_models = $true }
    return $state
}

# === Inicializar proyecto ===
function Init-Project {
    Write-Host ''
    Write-Host "  ▸ Inicializando ARNES ARGOS en: $(Get-Location)" -ForegroundColor Cyan
    # Crear .arnes si no existe
    if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }
    # Crear connections.json (GLOBAL)
    $conn = Join-Path $ScriptDir 'argos-connect.ps1'
    & $conn init
    # Modelos GLOBALES: crear UNA vez por maquina (o migrar desde un proyecto existente)
    if (-not (Test-Path $AgentModelsPath)) {
        if (Test-Path $LocalAgentModelsPath) {
            if (-not (Test-Path $GlobalConfigDir)) { New-Item -ItemType Directory -Path $GlobalConfigDir -Force | Out-Null }
            Copy-Item $LocalAgentModelsPath $AgentModelsPath -Force
            Write-Host "  [OK] agent-models migrado a config GLOBAL de la maquina." -ForegroundColor Green
        } else {
            if (-not (Test-Path $GlobalConfigDir)) { New-Item -ItemType Directory -Path $GlobalConfigDir -Force | Out-Null }
            $defaults = [ordered]@{
                version = '1.0'
                updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                agents = [ordered]@{
                    atlas = 'opencode-go/qwen3.8-max'
                    vivi = 'openai/gpt-5.6-luna'
                    ansem = 'nvidia/deepseek-ai/deepseek-v4-flash'
                    kuja = 'nvidia/deepseek-ai/deepseek-v4-flash'
                    eiko = 'opencode-go/deepseek-v4-flash'
                    amarant = 'openai/gpt-5.6-luna'
                    eremez = 'nvidia/deepseek-ai/deepseek-v4-flash'
                    auron = 'nvidia/deepseek-ai/deepseek-v4-pro'
                    bran = 'openai/gpt-5.6-luna'
                    quina = 'opencode-go/deepseek-v4-flash'
                    varys = 'openai/gpt-5.6-luna'
                    tywin = 'nvidia/deepseek-ai/deepseek-v4-flash'
                    sam = 'openai/gpt-5.6-luna'
                    bard = 'openai/gpt-5.6-luna'
                    tidus = 'opencode-go/deepseek-v4-flash'
                    ragnarok = 'openai/gpt-5.6-luna'
                }
            }
            $defaults | ConvertTo-Json -Depth 6 | Set-Content -Path $AgentModelsPath -Encoding UTF8
            Write-Host "  [OK] agent-models.json GLOBAL creado (una vez por maquina)." -ForegroundColor Green
        }
    }
    # Desplegar los modelos a los agentes instalados
    & (Join-Path $ScriptDir 'argos-models-apply.ps1') -SkipBackup
    Write-Host "  [OK] Proyecto inicializado." -ForegroundColor Green
    # Contract Audit gate: despliegue FORZOSO en proyecto nuevo (ADR-006)
    Write-Host "  [OK] Desplegando Contract Audit gate (DB <-> Frontend)..." -ForegroundColor Cyan
    & (Join-Path $ScriptDir 'argos-audit.ps1') init
    # Perfil del proyecto: ruta, git, stack, stats, memoria
    & (Join-Path $ScriptDir 'argos-project.ps1') -Update | Out-Null
    Write-Host ''
}

# === Prefijos de proveedores CONECTADOS (solo los que realmente conectamos) ===
function Get-ConnectedPrefixes {
    $prefixes = @()
    if (Test-Path $GlobalConnPath) {
        $conn = Get-Content $GlobalConnPath -Raw | ConvertFrom-Json
        foreach ($p in $conn.providers.PSObject.Properties) {
            if ($p.Value.connected) { $prefixes += ($p.Name + '/') }
        }
    }
    return $prefixes
}

# === Catalogo VIVO de modelos (opencode models) ===
function Get-LiveModels {
    $live = @()
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $raw = @(cmd /c 'opencode models' 2>&1)
        if ($LASTEXITCODE -eq 0) {
            $live = @($raw | Where-Object { $_ -match '^[\w-]+/[\w.\-+/]+$' } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)
        }
    } catch {}
    $ErrorActionPreference = $prevEap
    return $live
}

# === Configurar modelos por agente (wizard) ===
function Show-ConfigureModels {
    Write-Host ''
    Write-Host '  ? Configuracion de modelos por agente' -ForegroundColor Cyan
    Write-Host '    Solo modelos de proveedores CONECTADOS (escribe para buscar, como opencode)' -ForegroundColor DarkGray
    $picker = Join-Path $ScriptDir 'argos-picker.ps1'
    $connMgr = Join-Path $ScriptDir 'argos-connect.ps1'

    # Obtener TODOS los modelos del catalogo vivo con sesion real
    $live = Get-LiveModels
    $authPrefixes = Get-ConnectedPrefixes
    $allModels = @()
    if ($live.Count -gt 0) {
        foreach ($m in $live) {
            foreach ($prefix in $authPrefixes) {
                if ($m.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $allModels += $m
                    break
                }
            }
        }
    } elseif (Test-Path $GlobalConnPath) {
        # Fallback: modelos hardcodeados de connections.json
        $data = Get-Content $GlobalConnPath -Raw | ConvertFrom-Json
        foreach ($p in $data.providers.PSObject.Properties) {
            if ($p.Value.connected) {
                foreach ($m in @($p.Value.models)) {
                    $allModels += ("{0}/{1}" -f $p.Name, $m)
                }
            }
        }
    }
    if ($allModels.Count -eq 0) {
        Write-Host '  [!] No hay proveedores conectados. Primero: argos connect' -ForegroundColor Yellow
        return
    }
    $allModels = $allModels | Sort-Object -Unique

    # Leer agent-models actual
    $agentModels = [ordered]@{}
    if (Test-Path $AgentModelsPath) {
        $am = Get-Content $AgentModelsPath -Raw | ConvertFrom-Json
        foreach ($a in $am.agents.PSObject.Properties) {
            $agentModels[$a.Name] = $a.Value
        }
    }

    $agents = @(
        @{ key = 'atlas'; name = 'Atlas (Orquestador)' },
        @{ key = 'vivi'; name = 'Vivi (Frontend)' },
        @{ key = 'ansem'; name = 'Ansem (Backend)' },
        @{ key = 'kuja'; name = 'Kuja (QA)' },
        @{ key = 'eiko'; name = 'Eiko (DevOps)' },
        @{ key = 'amarant'; name = 'Amarant (Arquitectura)' },
        @{ key = 'eremez'; name = 'Eremez (Research)' },
        @{ key = 'auron'; name = 'Auron (Seguridad)' },
        @{ key = 'bran'; name = 'Bran (Analista)' },
        @{ key = 'quina'; name = 'Quina (Tokens)' },
        @{ key = 'varys'; name = 'Varys (Tracker)' },
        @{ key = 'tywin'; name = 'Tywin (Verificador)' },
        @{ key = 'sam'; name = 'Sam (Consejero)' },
        @{ key = 'bard'; name = 'Bard (Mejora)' },
        @{ key = 'tidus'; name = 'Tidus (Infra)' },
        @{ key = 'ragnarok'; name = 'Ragnarok (Compras)' },
        @{ key = 'sisyphus'; name = 'Sisyphus (Orq. OMO)' },
        @{ key = 'oracle'; name = 'Oracle (Consultor OMO)' },
        @{ key = 'explore'; name = 'Explore (Busqueda OMO)' },
        @{ key = 'librarian'; name = 'Librarian (Docs OMO)' },
        @{ key = 'momus'; name = 'Momus (Plan QA OMO)' },
        @{ key = 'metis'; name = 'Metis (Pre-plan OMO)' },
        @{ key = 'plan'; name = 'Plan (Planificador OMO)' },
        @{ key = 'maestro'; name = 'Maestro (Arquitecto SDD)' },
        @{ key = 'gentleman'; name = 'Gentleman (Mentor)' },
        @{ key = 'prometheus'; name = 'Prometheus (Diseno)' },
        @{ key = 'hephaestus'; name = 'Hephaestus (Frontend OMO)' },
        @{ key = 'deep_worker'; name = 'Deep Worker (Backend OMO)' },
        @{ key = 'kimi'; name = 'Kimi (Razonamiento)' }
    )

    foreach ($a in $agents) {
        $current = if ($agentModels.Contains($a.key)) { $agentModels[$a.key] } else { '' }
        $defaultIdx = 0
        if ($current) {
            $found = [Array]::IndexOf($allModels, $current)
            if ($found -ge 0) { $defaultIdx = $found }
        }
        if ($defaultIdx -eq 0 -and $current -ne $allModels[0]) {
            # Modelo previo no disponible: usar la recomendacion (equilibrio) como default
            $rec = Get-Recommendation -AgentKey $a.key -Priority 'equilibrio'
            $recIdx = [Array]::IndexOf($allModels, $rec)
            if ($recIdx -ge 0) { $defaultIdx = $recIdx }
        }
        Write-Host ''
        $chosen = & $picker -Title "Modelo para $($a.name)" -Options $allModels -DefaultIndex $defaultIdx -Group "Modelos de proveedores conectados"
        if ($LASTEXITCODE -eq 130 -or [string]::IsNullOrWhiteSpace($chosen)) {
            Write-Host '  Cancelado.' -ForegroundColor Yellow
            return
        }
        $agentModels[$a.key] = $chosen
        Write-Host "  OK $($a.name) -> $chosen" -ForegroundColor Green
    }

    # Guardar
    $out = [ordered]@{
        version = '1.0'
        updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        agents = [ordered]@{}
    }
    foreach ($k in $agentModels.Keys) { $out.agents[$k] = $agentModels[$k] }
    $out | ConvertTo-Json -Depth 6 | Set-Content -Path $AgentModelsPath -Encoding UTF8
    Write-Host ''
    Write-Host '  [OK] Configuracion guardada en la MAQUINA (~/.config/arnes/agent-models.json)' -ForegroundColor Green
    Write-Host '  Aplicando modelos a los agentes instalados (opencode)...' -ForegroundColor Cyan
    & (Join-Path $ScriptDir 'argos-models-apply.ps1')
}

# === Menu principal ===
function Show-Menu {
    Clear-Host
    Show-Banner
    $state = Get-ProjectState

    Write-Host '  ▸ Proyecto:' -ForegroundColor Cyan
    Write-Host ("    {0}  (carpeta: {1})" -f $state.project_name, (Get-Location)) -ForegroundColor White
    Write-Host '  ▸ Estado del entorno:' -ForegroundColor Cyan
    if ($state.has_connections) { Write-Host '    [OK] Conexiones configuradas (global ~/.config/arnes)' -ForegroundColor Green } else { Write-Host '    [--] Sin conexiones' -ForegroundColor DarkGray }
    if ($state.has_models) { Write-Host '    [OK] Modelos por agente (global ~/.config/arnes)' -ForegroundColor Green } else { Write-Host '    [--] Modelos sin configurar' -ForegroundColor DarkGray }
    if ($state.is_argos) { Write-Host '    [OK] Memoria disponible (arnes.db)' -ForegroundColor Green } else { Write-Host '    [--] Sin memoria' -ForegroundColor DarkGray }
    # Mostrar modo de interaccion actual
    $interactionScript = Join-Path $ScriptDir 'argos-interaction.ps1'
    if (Test-Path $interactionScript) {
        $mode = (& $interactionScript get-mode 2>$null)
        if ($mode) {
            $modeColor = switch ($mode) { 'auto' { 'Red' } 'educativo' { 'Yellow' } default { 'Green' } }
            Write-Host ("    [MODO] Interaccion: {0}" -f $mode.ToUpper()) -ForegroundColor $modeColor
        }
    }
    Write-Host ''

    Write-Host '  ================================================' -ForegroundColor DarkGray
    Write-Host '  [1] Chat con Atlas (orquestador)' -ForegroundColor White
    Write-Host '  [2] Conectar proveedores (/connect)' -ForegroundColor White
    Write-Host '  [3] Configurar modelos por agente (/configuremodel)' -ForegroundColor White
    Write-Host '  [4] Recomendacion inteligente de modelos (/recommend)' -ForegroundColor White
    Write-Host '  [5] Modo de interaccion (auto/educativo/mixto)' -ForegroundColor White
    Write-Host '  [6] Estado del entorno (/status)' -ForegroundColor White
    Write-Host '  [7] Memoria (/memory)' -ForegroundColor White
    Write-Host '  [O] Instalar memoria OSMA (/osma-install)' -ForegroundColor White
    Write-Host '  [8] Diagnostico de prerequisitos (/doctor)' -ForegroundColor White
    Write-Host '  [9] Abrir entorno (OpenCode / Codex / Claude / Freebuff) (/target)' -ForegroundColor White
    Write-Host '  [A] Contract Audit DB<->Frontend (/audit)' -ForegroundColor White
    Write-Host '  [Q] Salir' -ForegroundColor White
    Write-Host '  ================================================' -ForegroundColor DarkGray
    Write-Host ''

    $choice = Read-Input '  Selecciona una opcion'
    if ([string]::IsNullOrWhiteSpace($choice) -and -not $Script:IsInteractive) { exit 0 }
    switch ($choice) {
        '1' { Launch-Chat }
        '2' { & (Join-Path $ScriptDir 'argos-connect-wizard.ps1'); Read-Input '  Enter para volver'; Show-Menu }
        '3' { Show-ConfigureModels; Read-Input '  Enter para volver'; Show-Menu }
        '4' { & (Join-Path $ScriptDir 'argos-recommend.ps1') -Apply; Read-Input '  Enter para volver'; Show-Menu }
        '5' { & $interactionScript wizard; Read-Input '  Enter para volver'; Show-Menu }
        '6' { Show-Status; Read-Input '  Enter para volver'; Show-Menu }
        '7' {
            $mem = (Get-OsmaMemoryCli)
            if (-not (Test-OsmaInstalled)) {
                Write-Host '  [!] OSMA no instalado: memoria desactivada. Corre: argos osma-install' -ForegroundColor Yellow
            } else { & $mem stats }
            Read-Input '  Enter para volver'; Show-Menu
        }
        'o' { & (Join-Path $ScriptDir 'argos.ps1') osma-install; Read-Input '  Enter para volver'; Show-Menu }
        'O' { & (Join-Path $ScriptDir 'argos.ps1') osma-install; Read-Input '  Enter para volver'; Show-Menu }
        '8' { & (Join-Path $ScriptDir 'argos-doctor.ps1'); Read-Input '  Enter para volver'; Show-Menu }
        '9' { & (Join-Path $ScriptDir 'argos-target.ps1') -Target auto }
        'a' { & (Join-Path $ScriptDir 'argos-audit.ps1'); Read-Input '  Enter para volver'; Show-Menu }
        'A' { & (Join-Path $ScriptDir 'argos-audit.ps1'); Read-Input '  Enter para volver'; Show-Menu }
        'q' { Write-Host '  Adios. Los 100 ojos te observan.'; exit 0 }
        'Q' { Write-Host '  Adios. Los 100 ojos te observan.'; exit 0 }
        default { Show-Menu }
    }
}

function Launch-Chat {
    Write-Host ''
    Write-Host '  ▸ Lanzando chat con Atlas (orquestador)...' -ForegroundColor Cyan
    $chat = Join-Path $ScriptDir 'argos-chat.ps1'
    & $chat
}

function Show-Status {
    Write-Host ''
    Write-Host '  ARNES ARGOS - ESTADO' -ForegroundColor Cyan
    Write-Host '  ==================' -ForegroundColor Cyan
    $state = Get-ProjectState
    Write-Host ("  Proyecto:    {0}" -f $state.project_name) -ForegroundColor White
    Write-Host ("  Carpeta:     {0}" -f (Get-Location)) -ForegroundColor White
    Write-Host ("  Entorno:     {0}" -f $(if ($state.is_argos) { 'ARGOS activo' } else { 'no inicializado' })) -ForegroundColor $(if ($state.is_argos) { 'Green' } else { 'Yellow' })
    # === Resumen XP desde quest-ledger ===
    $ledgerFile = Join-Path (Get-Location) '.arnes\quest-ledger.json'
    if (Test-Path $ledgerFile) {
        try {
            $ledger = Get-Content $ledgerFile -Raw | ConvertFrom-Json
            $xpMap = @{}
            $questCount = 0
            foreach ($q in @($ledger.quests)) {
                $name = [string]$q.agent
                if (-not $name) { continue }
                $questCount++
                if (-not $xpMap.ContainsKey($name)) { $xpMap[$name] = 0 }
                $xpMap[$name] += if ([string]$q.verdict -eq 'PASS') { 100 } else { 10 }
            }
            $top = foreach ($r in ($xpMap.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 3)) {
                $lvl = [math]::Floor([math]::Sqrt([int]$r.Value / 100.0)) + 1
                "{0} Lv{1}" -f $r.Key, $lvl
            }
            if ($top) {
                Write-Host ("  Quests:      {0} · Top: {1}" -f $questCount, ($top -join ' · ')) -ForegroundColor DarkGray
            }
        } catch { }
    }
    Write-Host ''
    # Perfil del proyecto (ruta, git, stack, stats, memoria)
    & (Join-Path $ScriptDir 'argos-project.ps1') -Show
    Write-Host ''
    $conn = Join-Path $ScriptDir 'argos-connect.ps1'
    & $conn status
    Write-Host ''
    # === Memoria OSMA: estado del motor + scan de proyectos ARGOS ===
    $osmaRoot = Get-OsmaRoot
    if (-not $osmaRoot) {
        Write-Host '  ▸ Memoria OSMA: no instalada. Corre: argos osma-install' -ForegroundColor Yellow
    } else {
        Write-Host '  ▸ Memoria OSMA: activa (motor global ~/.config/arnes/osma)' -ForegroundColor Green
        $scanCli = Join-Path $osmaRoot 'osma-scan-projects.ps1'
        if (Test-Path $scanCli) {
            try {
                $scanOut = @(& $scanCli -OnlyArnes -Json 2>$null) -join ''
                if ($scanOut) {
                    $scan = $scanOut | ConvertFrom-Json
                    Write-Host ("  ▸ Proyectos con ARGOS+OSMA: {0} de {1} escaneados" -f @($scan.arnes).Count, $scan.total) -ForegroundColor Cyan
                    foreach ($p in @($scan.arnes | Select-Object -First 6)) {
                        Write-Host ("      - {0} (obs={1}, exps={2}, quests={3})" -f $p.name, $p.obs, $p.exps, $p.quests) -ForegroundColor DarkGray
                    }
                }
            } catch { }
        }
    }
}

# === MAIN ===
Show-Banner

switch ($Command) {
    'init' { Init-Project; Read-Input '  Enter para continuar'; Show-Menu }
    'connect' { & (Join-Path $ScriptDir 'argos-connect-wizard.ps1') }
    'connect-agent' { & (Join-Path $ScriptDir 'argos-connect-agent.ps1') }
    'configure' { Show-ConfigureModels }
    'chat' { Launch-Chat }
    'status' { Show-Status }
    'stats' { & (Join-Path $ScriptDir 'argos-stats.ps1') }
    'theme' {
        $cmd = if ($Args -and $Args.Count -gt 0) { $Args[0] } elseif ($Model) { $Model } else { 'list' }
        $name = if ($Args -and $Args.Count -gt 1) { $Args[1] } else { '' }
        if ($cmd -eq 'set' -and -not $name) {
            Write-Host '  Uso: argos theme set <nombre>' -ForegroundColor Yellow
            Write-Host '  Temas: atlas, vivi, amarant, eiko, auron' -ForegroundColor Cyan
        } else {
            & (Join-Path $ScriptDir 'argos-theme.ps1') $cmd -Name $name
        }
    }
    'models' { Show-ConfigureModels }
    'model' {
        # argos model list                 -> listar modelos de todos los agentes
        # argos model <agente>             -> ver modelo de un agente
        # argos model <agente> <modelo>    -> asignar modelo y aplicar
        $sub = if ($Model) { $Model } elseif ($Args -and $Args.Count -gt 0) { $Args[0] } else { '' }
        # $Args contiene el resto: [0] puede ser el modelo completo (sin espacios) o parte de el
        # si viene con espacios (ej: opencode-go/Kimi K2.7-code llega partido). Unir todo.
        $extra = if ($Args -and $Args.Count -gt 0) { @($Args) } else { @() }
        $ModelsPath = $AgentModelsPath
        if (-not (Test-Path $ModelsPath)) {
            Write-Host '  [!] No existe agent-models.json global. Corre: argos configure' -ForegroundColor Yellow
            exit 1
        }
        $am = Get-Content $ModelsPath -Raw | ConvertFrom-Json
        if ($sub -eq 'list' -or $sub -eq '') {
            Write-Host ''
            Write-Host '  ARNES ARGOS - MODELOS POR AGENTE (fuente unica)' -ForegroundColor Cyan
            Write-Host '  ==============================================' -ForegroundColor Cyan
            $rows = @($am.agents.PSObject.Properties | Sort-Object Name)
            foreach ($a in $rows) {
                $model = [string]$a.Value
                Write-Host ("  {0,-16} -> {1}" -f $a.Name, $model) -ForegroundColor White
            }
            Write-Host ''
            Write-Host '  Uso: argos model <agente> <modelo>' -ForegroundColor DarkGray
            Write-Host '  Ej:  argos model vivi opencode-go/gpt-5.6-luna' -ForegroundColor Cyan
            Write-Host '       argos model atlas opencode-go/gpt-5.6-luna' -ForegroundColor Cyan
            Write-Host '  (aplica a agents/*.md + oh-my-opencode.jsonc + opencode.json)' -ForegroundColor DarkGray
            exit 0
        }
        # argos model <agente> [modelo]
        $agentKey = $sub
        if (-not $am.agents.PSObject.Properties.Name.Contains($agentKey)) {
            Write-Host "  [!] Agente desconocido: $agentKey" -ForegroundColor Yellow
            Write-Host '  Usa: argos model list' -ForegroundColor Cyan
            exit 1
        }
        $current = [string]$am.agents.$agentKey
        if ($extra.Count -eq 0) {
            Write-Host ("  {0} -> {1}" -f $agentKey, $current) -ForegroundColor White
            exit 0
        }
        # Unir argumentos restantes: modelos con espacio (ej: opencode-go/Kimi K2.6) llegan partidos
        $newModel = ($extra -join ' ').Trim()
        # Validar formato proveedor/modelo
        if ($newModel -notmatch '^[^/]+/[^/]+$') {
            Write-Host "  [!] Modelo invalido: $newModel (formato: proveedor/modelo, ej: opencode-go/gpt-5.6-luna)" -ForegroundColor Yellow
            exit 1
        }
        $am.agents.$agentKey = $newModel
        $am | ConvertTo-Json -Depth 6 | Set-Content $ModelsPath -Encoding UTF8
        Write-Host ("  [OK] {0}: {1} -> {2}" -f $agentKey, $current, $newModel) -ForegroundColor Green
        Write-Host '  Aplicando a los destinos (agents, oh-my-opencode, opencode)...' -ForegroundColor Cyan
        & (Join-Path $ScriptDir 'argos-models-apply.ps1') | Out-Null
        Write-Host '  [OK] Modelo actualizado y aplicado.' -ForegroundColor Green
        exit 0
    }
    'recommend' { & (Join-Path $ScriptDir 'argos-recommend.ps1') -Apply }
    'mode' { & (Join-Path $ScriptDir 'argos-interaction.ps1') wizard }
    'doctor' { & (Join-Path $ScriptDir 'argos-doctor.ps1') }
    'verify' { & (Join-Path $ScriptDir 'argos-connect.ps1') verify }
    'quest' {
        $q = if ($Args -and $Args.Count -gt 0) { $Args -join ' ' } elseif ($Model) { $Model } else { '' }
        if (-not $q) {
            Write-Host '  Uso: argos quest <tu quest>' -ForegroundColor Yellow
            Write-Host '  Ej:  argos quest "haz un login form con Zod y RLS"' -ForegroundColor Cyan
        } else {
            & (Join-Path $ScriptDir 'argos-cycle.ps1') -Quest $q
        }
    }
    'goal' {
        # argos goal "<objetivo>" [-MaxIterations N] [-Resume]
        $parts = @($Model) + @($Args) | Where-Object { $_ }
        $goal = ''
        $maxIter = 8
        $resume = $false
        $i = 0
        while ($i -lt $parts.Count) {
            $p = [string]$parts[$i]
            if ($p -eq '-MaxIterations' -and ($i + 1) -lt $parts.Count) {
                $maxIter = [int]$parts[$i + 1]; $i += 2
            } elseif ($p -eq '-Resume') {
                $resume = $true; $i++
            } else {
                $goal = (($parts[$i..($parts.Count - 1)] | ForEach-Object { [string]$_ }) -join ' ')
                $i = $parts.Count
            }
        }
        if (-not $goal) {
            Write-Host '  Uso: argos goal "<objetivo global>" [-MaxIterations N] [-Resume]' -ForegroundColor Yellow
            Write-Host '  Ej:  argos goal "crea la plataforma escolar completa" -MaxIterations 10' -ForegroundColor Cyan
            Write-Host '  (modo autonomo: encadena ciclos hasta lograr el objetivo; la retroalimentacion' -ForegroundColor DarkGray
            Write-Host '   genera el siguiente prompt. Detener: Ctrl+C. Reanudar: -Resume)' -ForegroundColor DarkGray
        } else {
            if ($resume) {
                & (Join-Path $ScriptDir 'argos-goal.ps1') -Goal $goal -MaxIterations $maxIter -Resume
            } else {
                & (Join-Path $ScriptDir 'argos-goal.ps1') -Goal $goal -MaxIterations $maxIter
            }
        }
    }
    'party' {
        $q = if ($Args -and $Args.Count -gt 0) { $Args -join ' ' } elseif ($Model) { $Model } else { '' }
        if (-not $q) {
            Write-Host '  Uso: argos party <tu quest GRANDE>' -ForegroundColor Yellow
            Write-Host '  Ej:  argos party "crea una plataforma escolar con login, calificaciones y avisos"' -ForegroundColor Cyan
            Write-Host '  (Atlas decide el party y descompone; cada agente usa SU modelo)' -ForegroundColor DarkGray
        } else {
            & (Join-Path $ScriptDir 'argos-party.ps1') -Quest $q
        }
    }
    'xp' {
        $a = if ($Args -and $Args.Count -gt 0) { $Args -join ' ' } elseif ($Model) { $Model } else { '' }
        if ($a) {
            & (Join-Path $ScriptDir 'argos-xp.ps1') -Agent $a
        } else {
            & (Join-Path $ScriptDir 'argos-xp.ps1')
        }
    }
    'code' {
        $q = if ($Args -and $Args.Count -gt 0) { $Args -join ' ' } elseif ($Model) { $Model } else { '' }
        if (-not $q) {
            Write-Host '  Uso: argos code <tu quest de coding>' -ForegroundColor Yellow
            Write-Host '  Ej:  argos code "crea un archivo README.md con 3 secciones"' -ForegroundColor Cyan
            Write-Host '  (el agente lee, crea y edita archivos REALES en esta carpeta)' -ForegroundColor DarkGray
        } else {
            & (Join-Path $ScriptDir 'argos-code.ps1') -Quest $q
        }
    }
    'opencode' {
        # Unir Model + Args: PowerShell parte el quest en palabras ($Model = 1a, $Args = resto)
        $q = @($Model) + @($Args) | Where-Object { $_ } | ForEach-Object { [string]$_ }
        $q = $q -join ' '
        & (Join-Path $ScriptDir 'argos-opencode.ps1') -Quest $q
    }
    'target' {
        # argos target [opencode|codex|claude|freebuff|auto|show|list|set <nombre>]
        $verb = if ($Model) { $Model } elseif ($Args -and $Args.Count -gt 0) { $Args[0] } else { '' }
        if ($verb -in @('opencode', 'codex', 'claude', 'freebuff', 'dsh', 'auto')) {
            # El quest es TODO lo que sigue al target (PowerShell parte el string en palabras)
            $quest = if ($Args -and $Args.Count -gt 0) { ($Args -join ' ') } else { '' }
            & (Join-Path $ScriptDir 'argos-target.ps1') -Target $verb -Quest $quest
        } elseif ($verb -eq 'set') {
            # argos target set <nombre>: el nombre es el primer argumento restante
            $name = if ($Args -and $Args.Count -gt 0) { $Args[0] } else { '' }
            & (Join-Path $ScriptDir 'argos-target.ps1') set -Name $name
        } elseif ($verb -eq 'show') {
            & (Join-Path $ScriptDir 'argos-target.ps1') show
        } elseif ($verb -eq 'list') {
            & (Join-Path $ScriptDir 'argos-target.ps1') list
        } else {
            & (Join-Path $ScriptDir 'argos-target.ps1')
        }
    }
    'audit' {
        # argos audit [init|scan|status|run] [--json]
        $verb = if ($Model) { $Model } elseif ($Args -and $Args.Count -gt 0) { $Args[0] } else { '' }
        $isJson = $Args -contains '--json' -or $Json
        if ($verb -eq 'init') {
            & (Join-Path $ScriptDir 'argos-audit.ps1') init
        } elseif ($verb -eq 'scan') {
            & (Join-Path $ScriptDir 'argos-audit.ps1') scan
        } elseif ($verb -eq 'status') {
            & (Join-Path $ScriptDir 'argos-audit.ps1') status
        } elseif ($verb -eq 'run') {
            if ($isJson) { & (Join-Path $ScriptDir 'argos-audit.ps1') run -Json } else { & (Join-Path $ScriptDir 'argos-audit.ps1') run }
        } else {
            & (Join-Path $ScriptDir 'argos-audit.ps1')
        }
    }
    'menu' { Show-Menu }
    'test-model' {
        if (-not $Model) {
            Write-Host '  Uso: argos test-model <modelo>' -ForegroundColor Yellow
            Write-Host '  Ej:  argos test-model nvidia/deepseek-ai/deepseek-v4-flash' -ForegroundColor Cyan
            Write-Host '       argos test-model openai/gpt-5.6-luna' -ForegroundColor Cyan
        } else {
            & (Join-Path $ScriptDir 'argos-test-model.ps1') -Model $Model
        }
    }
    'memory' {
        $mem = (Get-OsmaMemoryCli)
        if (-not (Test-OsmaInstalled)) {
            Write-Host '  [!] OSMA no instalado: memoria desactivada. Corre: argos osma-install' -ForegroundColor Yellow
        } else { & $mem stats }
    }
    'osma-install' {
        # Instala el motor OSMA a ~/.config/arnes/osma (desde repo local o GitHub)
        if (Test-OsmaInstalled) {
            Write-Host ("  [OK] OSMA ya instalado en: {0}" -f (Get-OsmaRoot)) -ForegroundColor Green
            exit 0
        }
        Write-Host '  ▸ Instalando OSMA (memoria per-proyecto)...' -ForegroundColor Cyan
        $osmaInstall = $null
        # 1) repo local hermano (Documents/GitHub/osma, ../osma)
        $localCandidates = @(
            (Join-Path $env:USERPROFILE 'Documents\GitHub\osma\install.ps1'),
            (Join-Path (Split-Path $ScriptDir -Parent) '..\osma\install.ps1'),
            (Join-Path (Split-Path $ScriptDir -Parent) 'osma\install.ps1')
        )
        foreach ($c in $localCandidates) { if (Test-Path $c) { $osmaInstall = $c; break } }
        if (-not $osmaInstall) {
            # 2) clonar temporal desde GitHub
            Write-Host '  [>>] Repo OSMA no encontrado localmente - clonando desde GitHub...' -ForegroundColor DarkGray
            $tmp = Join-Path $env:TEMP ('osma-install-' + [guid]::NewGuid().ToString('N'))
            try {
                & git clone --depth 1 https://github.com/mauriragna88/osma.git $tmp 2>&1 | Out-Null
                $osmaInstall = Join-Path $tmp 'install.ps1'
            } catch {
                Write-Host '  [!] No se pudo clonar OSMA. Instala manual: git clone https://github.com/mauriragna88/osma.git' -ForegroundColor Red
                exit 1
            }
        }
        & $osmaInstall
        Write-Host '  [OK] Memoria OSMA lista. Reinicia argos para activarla.' -ForegroundColor Green
        exit 0
    }
    default {
        # Quest inicial opcional: argos "haz X"  o  argos quest-inicial
        # Unir Model + Args (PowerShell parte el quest en palabras)
        $questParts = @($Model) + @($Args) | Where-Object { $_ }
        $questArg = ($questParts | ForEach-Object { [string]$_ }) -join ' '
        # Estado del proyecto + config global
        $state = Get-ProjectState
        # Si NO hay config GLOBAL (nunca conectaste nada) -> onboarding de primera vez.
        # En cualquier otro caso (aunque la carpeta no tenga .arnes/) -> abrir directo el entorno.
        if (-not $state.has_connections -and -not $state.has_models) {
            Write-Host '  ▸ Primera vez: conecta tus proveedores y elige modelos.' -ForegroundColor Yellow
            Init-Project
            Write-Host '  ▸ Primero conectemos tus proveedores de modelos:' -ForegroundColor Cyan
            & (Join-Path $ScriptDir 'argos-connect-wizard.ps1')
            if (-not (Get-AvailableModels)) { Show-RagnarokGuide }
            Write-Host '  ▸ Ahora configura que modelo usa cada agente:' -ForegroundColor Cyan
            Show-ConfigureModels
            Write-Host '  ▸ Listo! Abriendo tu entorno ARNES...' -ForegroundColor Green
        } else {
            # Ya hay config global. Si la carpeta no tiene .arnes/, inicializa la memoria
            # ARGOS/OSMA SILENCIOSA y automaticamente (sin wizard ni bloquear). Luego
            # SIEMPRE se abre el selector de entorno (opencode/codex/claude/freebuff/dsh).
            if (-not $state.is_argos) {
                Write-Host '  ▸ Detectando proyecto sin memoria ARGOS/OSMA - inicializando...' -ForegroundColor DarkGray
                # 1. carpeta .arnes/
                if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }
                # 2. memoria arnes.db (motor OSMA global). Idempotente: no falla si ya existe.
                try {
                    $osmaMem = Get-OsmaMemoryCli
                    if ($osmaMem) { & $osmaMem init *> $null }
                } catch { }
                # 3. config.json de referencia (harness)
                try {
                    if (-not (Test-Path $ConfigPath)) {
                        $template = Join-Path $ScriptDir '..\argos\.arnes\config.json'
                        if (-not (Test-Path $template)) { $template = Join-Path $ScriptDir '..\config.json' }
                        if (-not (Test-Path $template)) {
                            @{ version='1.0.0'; codename='argos'; player=@{ name='Atlas'; role='Player / Orchestrator'; tagline='Rojo y Negro como el Atlas de la Liga MX' } } |
                                ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigPath -Encoding UTF8
                        } else {
                            Copy-Item $template $ConfigPath -Force
                        }
                    }
                } catch { }
                # 4. perfil del proyecto (ruta, git, stack, stats, memoria)
                & (Join-Path $ScriptDir 'argos-project.ps1') -Update | Out-Null
                Write-Host '  [OK] Memoria ARGOS/OSMA inicializada en esta carpeta.' -ForegroundColor Green
            } else {
                & (Join-Path $ScriptDir 'argos-project.ps1') -Update | Out-Null
            }
        }
        # Abrir el entorno/target configurado (opencode/codex/claude/dsh)
        Start-Sleep -Milliseconds 500
        & (Join-Path $ScriptDir 'argos-target.ps1') -Target auto -Quest $questArg
    }
}
