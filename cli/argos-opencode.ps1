#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS OPENCODE - Sincroniza los 16 agentes ARNES a OpenCode y lo abre en la carpeta actual

.DESCRIPTION
El puente entre ARNES y OpenCode:
1. Sincroniza los 16 agentes RPG (Atlas, Vivi, Ansem, Kuja, Eiko, Amarant, Eremez,
   Auron, Bran, Quina, Varys, Tywin, Sam, Bard, Tidus, Ragnarok) a
   ~/.config/opencode/agents/ CON SU MODELO asignado (frontmatter).
2. Verifica conexiones y modelos globales.
3. Abre OpenCode con ATLAS como agente primario (orquestador) en el proyecto actual.
   Opcional: pasar un quest inicial que Atlas recibe al abrir.

ARNES queda como capa de configuracion y memoria; OpenCode como entorno de trabajo;
OhMyOpenCode como motor de orquestacion (categorias, subagentes, fallbacks).

.EXAMPLE
.\argos-opencode.ps1
.\argos-opencode.ps1 -Quest "haz un login form con Zod y RLS"
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Quest = ''
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'

# === Mutex de sincronizacion (serializa invocaciones concurrentes de argos) ===
# Objeto kernel nombrado: no deja lock files huerfanos y el SO lo limpia solo si el proceso muere.
function Get-ArnesSyncMutex {
    $base = 'arnes_argos_sync'
    foreach ($ns in @('Global\', 'Local\')) {
        try {
            return New-Object System.Threading.Mutex($false, "$ns$base")
        } catch [System.UnauthorizedAccessException] {
            # Sin SeCreateGlobalPrivilege (usuario no admin): usar namespace de sesion
        }
    }
    throw 'No se pudo crear el mutex de sincronizacion Argos.'
}

Write-Host ''
Write-Host '  ARNES -> OPENCODE  |  los 16 agentes con sus modelos' -ForegroundColor DarkRed
Write-Host ''

# 1) Sincronizar agentes + modelos a OpenCode (protegido por mutex contra colisiones)
$syncMutex = $null
$mutexOwned = $false
try {
    $syncMutex = Get-ArnesSyncMutex
    # Espera determinista (120s). Si el dueno murio sin liberar, WaitOne lanza
    # AbandonedMutexException y la propiedad se transfiere a este proceso.
    try {
        $mutexOwned = $syncMutex.WaitOne(120000)
    } catch [System.Threading.AbandonedMutexException] {
        $mutexOwned = $true
    }
    if (-not $mutexOwned) {
        Write-Host '  [!] Otra sincronizacion Argos sigue en curso. Reintenta en unos segundos.' -ForegroundColor Yellow
        exit 1
    }
    Write-Host '  [1/3] Sincronizando agentes RPG y modelos a OpenCode...' -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'atlas.ps1') --sync
} finally {
    if ($syncMutex) {
        if ($mutexOwned) {
            try { $syncMutex.ReleaseMutex() } catch { }
        }
        $syncMutex.Dispose()
    }
}

# 2) Verificar config global
Write-Host ''
Write-Host '  [2/3] Verificando configuracion global...' -ForegroundColor Cyan
$conn = Test-Path (Join-Path $GlobalConfigDir 'connections.json')
$models = Test-Path (Join-Path $GlobalConfigDir 'agent-models.json')
if ($conn -and $models) {
    Write-Host '       [OK] conexiones + modelos por agente (una vez por maquina)' -ForegroundColor Green
} else {
    Write-Host '       [!] Falta configuracion. Corre: argos connect + argos configure' -ForegroundColor Yellow
}

# 3) Abrir OpenCode con Atlas como orquestador primario
Write-Host ''
Write-Host '  [3/3] Abriendo OpenCode con los 16 agentes ARNES...' -ForegroundColor Cyan
Write-Host '    Atlas (orquestador) | Vivi | Ansem | Kuja | Eiko | Amarant | Eremez | Auron' -ForegroundColor White
Write-Host '    Bran | Quina | Varys | Tywin | Sam | Bard | Tidus | Ragnarok' -ForegroundColor White
Write-Host '    (cada agente usa SU modelo de ~/.config/arnes/agent-models.json)' -ForegroundColor DarkGray
Write-Host '    (Atlas es el orquestador primary; OhMyOpenCode es el motor de orquestacion)' -ForegroundColor DarkGray
Write-Host ''

# Auto-reparacion del opencode.json global: si referencia {file:...} a un archivo
# inexistente (ej: repo renombrado/borrado), lo corrige apuntando al repo actual.
function Repair-OpenCodeConfigRefs {
    $ocCfg = Join-Path $env:USERPROFILE '.config\opencode\opencode.json'
    if (-not (Test-Path $ocCfg)) { return }
    try {
        $raw = Get-Content $ocCfg -Raw
    } catch { return }
    # Todas las refs {file:<absoluto>} que no existen
    $regex = [regex]'\{file:([^}]+)\}'
    $changed = $false
    foreach ($m in $regex.Matches($raw)) {
        $p = $m.Groups[1].Value -replace '^file:', '' -replace '\\', '\'
        if (-not $p) { continue }
        # Normalizar C:/... -> C:\... para Test-Path
        $abs = if ($p -match '^[A-Za-z]:/') { $p -replace '^([A-Za-z]):/', '$1:\' } else { $p }
        if (-not (Test-Path -LiteralPath $abs -ErrorAction SilentlyContinue)) {
            # Si la ref apuntaba a un repo ARNES viejo junto a este, apuntar a este repo
            $fixedPath = (Join-Path $Root 'core\atlas-player.agent.md')
            $raw = $raw.Replace($m.Value, ('{file:' + ($fixedPath -replace '\\', '/') + '}'))
            $changed = $true
            Write-Host ("  [~] opencode.json global: ruta rota corregida ({0})" -f (Split-Path $p -Leaf)) -ForegroundColor Yellow
        }
    }
    if ($changed) {
        try {
            $null = $raw | ConvertFrom-Json
            Set-Content -LiteralPath $ocCfg -Value $raw -Encoding UTF8
        } catch {
            Write-Host '  [!] No se pudo reparar opencode.json (JSON invalido).' -ForegroundColor Red
        }
    }
}

Repair-OpenCodeConfigRefs

$oc = Get-Command opencode -ErrorAction SilentlyContinue
if (-not $oc) {
    Write-Host '  [!] opencode no encontrado. Instala: npm install -g opencode-ai' -ForegroundColor Red
    exit 1
}

# Abrir opencode con Atlas como agente primario (TUI interactivo)
# Usar array splatting: garantiza que el quest (con espacios) llegue como UN solo argumento
$ocArgs = @('--agent', 'atlas-player')
if ($Quest) {
    Write-Host '  Abriendo opencode con Atlas y tu quest...' -ForegroundColor Yellow
    $ocArgs += $Quest
    & opencode @ocArgs
} else {
    Write-Host '  Abriendo opencode con Atlas (orquestador)...' -ForegroundColor Yellow
    & opencode @ocArgs
}