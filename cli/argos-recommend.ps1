#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS RECOMMEND - Mini-guia inteligente de modelos

.DESCRIPTION
Detecta proveedores conectados (connections.json global) y recomienda el mejor
modelo por agente. Pregunta al usuario: ahorrar tokens o maxima calidad.
Basado en benchmarks de la industria (coding, agentic, value).

.EXAMPLE
.\argos-recommend.ps1          -> recomendar modelos por agente
.\argos-recommend.ps1 -Apply   -> guardar recomendacion en agent-models.json
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [ValidateSet('ahorro', 'equilibrio', 'calidad')]
    [string]$Priority = ''
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
$ConnPath = Join-Path $GlobalConfigDir 'connections.json'
$ProjectDir = (Get-Location).Path
$ArnesDir = Join-Path $ProjectDir '.arnes'
# Modelos por agente GLOBALES (una vez por maquina, se despliegan a los agentes)
$AgentModelsPath = Join-Path (Join-Path $env:USERPROFILE '.config\arnes') 'agent-models.json'

# Forzar UTF-8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# Lectura segura (no interactivo: vacio en vez de crashear)
function Read-Input {
    param([string]$Prompt)
    try { return Read-Host $Prompt } catch { return '' }
}

# === Agentes con descripcion breve (para tomar la mejor decision) ===
$AGENTS = @(
    @{ key = 'atlas';    name = 'Atlas';    role = 'Orquestador: delega, decide, loopea. Poco volumen, necesita buen razonamiento' }
    @{ key = 'vivi';     name = 'Vivi';     role = 'Frontend: React, Tailwind, UI/UX. Volumen alto, velocidad + calidad visual' }
    @{ key = 'ansem';    name = 'Ansem';    role = 'Backend: APIs, Supabase, Zod. Volumen alto, precisión' }
    @{ key = 'kuja';     name = 'Kuja';     role = 'QA: tests, edge cases, seguridad. Precisión, buen razonamiento' }
    @{ key = 'eiko';     name = 'Eiko';     role = 'DevOps: builds, CI/CD, fixes. Volumen medio, velocidad' }
    @{ key = 'amarant';  name = 'Amarant';  role = 'Arquitectura: SDD, diseño, decisiones. Bajo volumen, MAXIMO razonamiento' }
    @{ key = 'eremez';   name = 'Eremez';   role = 'Research: docs, librerias, web. Volumen medio, velocidad' }
    @{ key = 'auron';    name = 'Auron';    role = 'Seguridad: L0 gate, OWASP, RLS. Bajo volumen, alto razonamiento' }
    @{ key = 'bran';     name = 'Bran';     role = 'Analista: %, dead code, growth. Bajo volumen, razonamiento medio' }
    @{ key = 'quina';    name = 'Quina';    role = 'Tokens: presupuesto, /status. Volumen bajisimo, barato' }
    @{ key = 'varys';    name = 'Varys';    role = 'Tracker: observa, evidence_pack. Volumen alto, velocidad' }
    @{ key = 'tywin';    name = 'Tywin';    role = 'Verificador: PASS/FAIL. Volumen medio, razonamiento alto' }
    @{ key = 'sam';      name = 'Sam';      role = 'Consejero: memoria historica, recomendaciones. Bajo volumen, razonamiento alto' }
    @{ key = 'bard';     name = 'Bard';     role = 'Mejora: refactor, deuda, docs. Volumen bajo, razonamiento medio' }
    @{ key = 'tidus';    name = 'Tidus';    role = 'Infra: health-check, cuotas. Volumen bajisimo, barato' }
    @{ key = 'ragnarok'; name = 'Ragnarok'; role = 'Compras: investiga web, compara. Volumen bajo, razonamiento medio-alto' }
)

# === Benchmarks por familia de modelo (resumen 2026) ===
# value: 1=barato 2=equilibrado 3=calidad maxima
$BENCHMARKS = @{
    'opencode-go/deepseek-v4-flash' = @{ quality = 2; cost = 1; speed = 3; desc = 'Workhorse barato y rapido. Excelente coding general' }
    'opencode-go/deepseek-v4-pro'   = @{ quality = 3; cost = 2; speed = 2; desc = 'Razonamiento profundo. Mejor para logica compleja' }
    'opencode-go/qwen3.8-max'       = @{ quality = 3; cost = 3; speed = 2; desc = 'TOP agente/orquestacion. El mas inteligente' }
    'opencode-go/gpt-5.6-luna'      = @{ quality = 3; cost = 2; speed = 3; desc = 'GPT velocidad/valor. Excelente generalista' }
    'opencode-go/glm-5.2'           = @{ quality = 2; cost = 2; speed = 2; desc = 'Equilibrado (Zhipu)' }
    'opencode-go/kimi-k2.6'         = @{ quality = 2; cost = 2; speed = 2; desc = 'Razonamiento chino solido' }
    'openai/gpt-5.6-luna'           = @{ quality = 3; cost = 2; speed = 3; desc = 'GPT-5.6 Luna: velocidad + valor' }
    'openai/gpt-5.6-terra'          = @{ quality = 4; cost = 3; speed = 2; desc = 'GPT-5.6 Terra: balanceado premium' }
    'openai/gpt-5.6-sol'            = @{ quality = 5; cost = 3; speed = 1; desc = 'GPT-5.6 Sol: MAXIMO razonamiento' }
    'claude/claude-opus-5'          = @{ quality = 5; cost = 3; speed = 1; desc = 'Claude Opus 5: elite' }
    'claude/claude-sonnet-5'        = @{ quality = 4; cost = 2; speed = 3; desc = 'Claude Sonnet 5: balance elite' }
    'bai/claude-opus-5'             = @{ quality = 5; cost = 3; speed = 1; desc = 'Claude Opus 5 via B.AI' }
    'bai/claude-fable-5'            = @{ quality = 4; cost = 2; speed = 3; desc = 'Claude Fable 5 via B.AI: rapido' }
    'bai/gpt-5.6-sol'               = @{ quality = 5; cost = 3; speed = 1; desc = 'GPT-5.6 Sol via B.AI' }
    'nvidia/deepseek-ai/deepseek-v4-flash' = @{ quality = 2; cost = 0; speed = 3; desc = 'DeepSeek Flash GRATIS (NVIDIA)' }
    'nvidia/deepseek-ai/deepseek-v4-pro'   = @{ quality = 3; cost = 0; speed = 2; desc = 'DeepSeek Pro GRATIS (NVIDIA)' }
}

# === Obtener los modelos del catalogo VIVO de proveedores CONECTADOS ===
function Get-AvailableModels {
    if (-not (Test-Path $ConnPath)) { return @() }
    $data = Get-Content $ConnPath -Raw | ConvertFrom-Json

    # Prefijos de proveedores conectados (solo los que realmente conectamos)
    $prefixes = @()
    foreach ($p in $data.providers.PSObject.Properties) {
        if ($p.Value.connected) { $prefixes += ($p.Name + '/') }
    }

    # Catalogo vivo de opencode, filtrado a esos prefijos
    $live = @()
    try {
        $raw = @(cmd /c 'opencode models' 2>&1)
        if ($LASTEXITCODE -eq 0) {
            $live = @($raw | Where-Object { $_ -match '^[\w-]+/[\w.\-+/]+$' } | ForEach-Object { $_.Trim() })
        }
    } catch {}
    if ($live.Count -gt 0) {
        $models = @()
        foreach ($m in $live) {
            foreach ($prefix in $prefixes) {
                if ($m.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $models += $m
                    break
                }
            }
        }
        return @($models | Sort-Object -Unique)
    }

    # Fallback: modelos hardcodeados de connections.json
    $models = @()
    foreach ($p in $data.providers.PSObject.Properties) {
        if ($p.Value.connected) {
            foreach ($m in @($p.Value.models)) {
                $models += ("{0}/{1}" -f $p.Name, $m)
            }
        }
    }
    return @($models | Sort-Object -Unique)
}

# === Preferencia de modelo por rol (alineada a la estrategia: 75% DeepSeek, Luna razonamiento, Qwen Atlas) ===
$ROLE_PREF = @{
    atlas    = @('opencode-go/qwen3.8-max', 'bai/qwen3.8-max', 'opencode-go/deepseek-v4-pro', 'nvidia/deepseek-ai/deepseek-v4-pro')
    vivi     = @('openai/gpt-5.6-luna', 'opencode-go/gpt-5.6-luna', 'bai/claude-fable-5', 'opencode-go/deepseek-v4-flash', 'nvidia/deepseek-ai/deepseek-v4-flash')
    ansem    = @('nvidia/deepseek-ai/deepseek-v4-flash', 'opencode-go/deepseek-v4-flash', 'bai/deepseek-v4-flash', 'opencode-go/deepseek-v4-pro')
    kuja     = @('nvidia/deepseek-ai/deepseek-v4-flash', 'opencode-go/deepseek-v4-flash', 'bai/deepseek-v4-flash', 'opencode-go/deepseek-v4-pro')
    eiko     = @('nvidia/deepseek-ai/deepseek-v4-flash', 'opencode-go/deepseek-v4-flash', 'bai/deepseek-v4-flash', 'opencode-go/gpt-5.6-luna')
    amarant  = @('openai/gpt-5.6-luna', 'opencode-go/gpt-5.6-luna', 'bai/claude-fable-5', 'opencode-go/deepseek-v4-pro')
    eremez   = @('nvidia/deepseek-ai/deepseek-v4-flash', 'opencode-go/deepseek-v4-flash', 'opencode-go/gpt-5.6-luna', 'bai/deepseek-v4-flash')
    auron    = @('nvidia/deepseek-ai/deepseek-v4-pro', 'opencode-go/deepseek-v4-pro', 'bai/claude-opus-5', 'openai/gpt-5.6-terra')
    bran     = @('openai/gpt-5.6-luna', 'opencode-go/gpt-5.6-luna', 'bai/claude-fable-5', 'opencode-go/deepseek-v4-flash')
    quina    = @('opencode-go/deepseek-v4-flash', 'nvidia/deepseek-ai/deepseek-v4-flash', 'opencode-go/gpt-5.6-luna', 'bai/deepseek-v4-flash')
    varys    = @('openai/gpt-5.6-luna', 'opencode-go/gpt-5.6-luna', 'opencode-go/deepseek-v4-flash', 'nvidia/deepseek-ai/deepseek-v4-flash')
    tywin    = @('nvidia/deepseek-ai/deepseek-v4-flash', 'opencode-go/deepseek-v4-flash', 'openai/gpt-5.6-luna', 'opencode-go/deepseek-v4-pro')
    sam      = @('openai/gpt-5.6-luna', 'opencode-go/gpt-5.6-luna', 'bai/claude-fable-5', 'opencode-go/deepseek-v4-pro')
    bard     = @('openai/gpt-5.6-luna', 'opencode-go/gpt-5.6-luna', 'bai/claude-fable-5', 'opencode-go/deepseek-v4-flash')
    tidus    = @('opencode-go/deepseek-v4-flash', 'nvidia/deepseek-ai/deepseek-v4-flash', 'opencode-go/gpt-5.6-luna', 'bai/deepseek-v4-flash')
    ragnarok = @('openai/gpt-5.6-luna', 'opencode-go/gpt-5.6-luna', 'bai/claude-opus-5', 'opencode-go/deepseek-v4-pro')
}

# === Recomendar modelo para un rol segun prioridad ===
function Get-Recommendation {
    param(
        [string]$AgentKey,
        [string]$Priority  # ahorro | equilibrio | calidad
    )
    $models = Get-AvailableModels
    if ($models.Count -eq 0) { return '' }

    # 1) Preferencia por rol (alineada a la estrategia del usuario)
    $pref = $ROLE_PREF[$AgentKey]
    if ($pref) {
        $avail = @($pref | Where-Object { $models -contains $_ -and $BENCHMARKS[$_] })
        if ($avail.Count -gt 0) {
            if ($Priority -eq 'ahorro') {
                return ($avail | Sort-Object { $BENCHMARKS[$_].cost } | Select-Object -First 1)
            }
            if ($Priority -eq 'calidad') {
                return ($avail | Sort-Object { $BENCHMARKS[$_].quality } -Descending | Select-Object -First 1)
            }
            return $avail[0]
        }
    }

    # 2) Fallback: score segun prioridad
    $best = $null
    $bestScore = -1
    foreach ($m in $models) {
        $bm = $BENCHMARKS[$m]
        if (-not $bm) { continue }
        # Score segun prioridad
        $score = switch ($Priority) {
            'ahorro' { $bm.cost * 10 + $bm.speed * 5 - $bm.quality * 2 }
            'calidad' { $bm.quality * 10 + $bm.speed * 2 - $bm.cost }
            default { $bm.quality * 7 + $bm.speed * 3 - $bm.cost }
        }
        if ($score -gt $bestScore) {
            $bestScore = $score
            $best = $m
        }
    }
    return $best
}

# === MAIN ===
# Guard: cuando se hace dot-source (argos.ps1 reutiliza el motor), no se ejecuta el main
if ($MyInvocation.InvocationName -ne '.') {
Write-Host ''
Write-Host '  ╔══════════════════════════════════════════════════════════╗' -ForegroundColor DarkRed
Write-Host '  ║   ARNES ARGOS - Recomendacion inteligente de modelos     ║' -ForegroundColor White
Write-Host '  ╚══════════════════════════════════════════════════════════╝' -ForegroundColor DarkRed
Write-Host ''

# 1. Verificar conexiones
$models = Get-AvailableModels
if ($models.Count -eq 0) {
    Write-Host '  [!] No hay proveedores conectados.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  ▸ RAGNAROK (Compras) sugiere conectar primero:' -ForegroundColor Cyan
    Write-Host '    nvidia      -> DeepSeek V4 Flash/Pro GRATIS (ahorro maximo)' -ForegroundColor White
    Write-Host '    opencode-go -> DeepSeek V4 Flash workhorse + Qwen3.8 Max (Atlas)' -ForegroundColor White
    Write-Host '    openai      -> GPT-5.6 Luna/Terra/Sol (cuenta ChatGPT Plus/Pro)' -ForegroundColor White
    Write-Host '    bai         -> Claude Opus 5 / GPT-5.6 Sol (calidad elite)' -ForegroundColor White
    Write-Host ''
    Write-Host '  Conecta el que prefieras con: argos connect' -ForegroundColor Yellow
    Write-Host '  (Se hace UNA VEZ por computadora - conexiones globales)' -ForegroundColor DarkGray
    exit 1
}

Write-Host "  Proveedores conectados ($($models.Count) modelos disponibles):" -ForegroundColor Cyan
$models | ForEach-Object { Write-Host "    $_" -ForegroundColor White }
Write-Host ''

# 2. Preguntar prioridad (o usar la del parametro -Priority)
if (-not $Priority) {
    Write-Host '  ¿Que prefieres?' -ForegroundColor White
    Write-Host '  [1] AHORRAR tokens (usa modelos baratos/gratis)' -ForegroundColor Yellow
    Write-Host '  [2] EQUILIBRIO (calidad/costo balanceado)' -ForegroundColor Green
    Write-Host '  [3] MAXIMA CALIDAD (los mejores modelos sin importar costo)' -ForegroundColor Magenta
    $choice = Read-Input '  Elige [1/2/3]'
    $priority = switch ($choice) { '1' { 'ahorro' } '3' { 'calidad' } default { 'equilibrio' } }
} else {
    $priority = $Priority
}

Write-Host ''
Write-Host "  ▸ Prioridad: $priority" -ForegroundColor Cyan
Write-Host ''

# 3. Recomendar por agente
$recommendations = [ordered]@{}
foreach ($a in $AGENTS) {
    $rec = Get-Recommendation -AgentKey $a.key -Priority $priority
    if ($rec) {
        $recommendations[$a.key] = $rec
        Write-Host ("  {0,-10} {1,-25} -> {2}" -f $a.name, $a.role.Substring(0, [Math]::Min(25, $a.role.Length)), $rec) -ForegroundColor White
    }
}

# 4. Guardar
if ($Apply) {
    $out = [ordered]@{
        version = '1.0'
        priority = $priority
        updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        agents = $recommendations
    }
    $out | ConvertTo-Json -Depth 6 | Set-Content -Path $AgentModelsPath -Encoding UTF8
    Write-Host ''
    Write-Host '  [OK] Recomendacion guardada en la MAQUINA (~/.config/arnes/agent-models.json)' -ForegroundColor Green
    Write-Host '  Aplicando modelos a los agentes instalados (opencode)...' -ForegroundColor Cyan
    & (Join-Path $ScriptDir 'argos-models-apply.ps1')
    Write-Host '  Puedes ajustar manualmente con: argos configure' -ForegroundColor DarkGray
} else {
    Write-Host ''
    Write-Host '  Para guardar: usa -Apply  (argos recommend -Apply)' -ForegroundColor DarkGray
}
} # fin guard main (dot-source)
