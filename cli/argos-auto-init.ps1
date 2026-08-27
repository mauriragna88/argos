#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS AUTO-INIT - Auto-verificador e inicializador de ARNES (argos) + OSMA (memoria).
Se ejecuta SIEMPRE al abrir un entorno (opencode/codex/claude/freebuff/dsh/agy), ANTES del primer prompt.

.DESCRIPTION
Garantiza que el proyecto actual tenga:
  1) ARNES  (.arnes/config.json + project.json + arnes.db)  -> si falta, lo inicializa
  2) OSMA   (motor de memoria real en ~/.config/arnes/osma) -> si falta, lo instala
  3) MEMORIA PRECARGADA (.arnes/memory/ + observaciones iniciales) -> si falta, la siembra
Idempotente: corre multiples veces sin dano. Reporta en verde/amarillo que tiene y que hizo.
#>
[CmdletBinding()]
param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# Home portable
function Get-ArnesHome {
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    return $HOME
}

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$ScriptDir = $PSScriptRoot
$ProjectRoot = (Get-Location).Path
$ArnesDir = Join-Path $ProjectRoot '.arnes'

# Output helpers
function C-OK   { param([string]$m) if (-not $Quiet) { Write-Host ("  [OK]   {0}" -f $m) -ForegroundColor Green } }
function C-INFO { param([string]$m) if (-not $Quiet) { Write-Host ("  [..]   {0}" -f $m) -ForegroundColor DarkGray } }
function C-WARN { param([string]$m) if (-not $Quiet) { Write-Host ("  [!]    {0}" -f $m) -ForegroundColor Yellow } }
function C-STEP { param([string]$m) if (-not $Quiet) { Write-Host ("  [INIT] {0}" -f $m) -ForegroundColor Cyan } }
function C-DONE { param([string]$m) if (-not $Quiet) { Write-Host ("  [OK]   {0}" -f $m) -ForegroundColor Green } }

if (-not $Quiet) {
    Write-Host ''
    Write-Host '  ⚔ AUTO-VERIFICADOR ARNES + OSMA ⚔' -ForegroundColor DarkRed
}

# ============ 1. ARNES (.arnes/) ============
$arnesReady = $false
if (Test-Path $ArnesDir) {
    $cfg = Join-Path $ArnesDir 'config.json'
    $prj = Join-Path $ArnesDir 'project.json'
    if ((Test-Path $cfg) -and (Test-Path $prj)) { $arnesReady = $true }
}

if (-not $arnesReady) {
    C-STEP 'ARNES no detectado en esta carpeta - inicializando...'
    if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }
    # config.json de referencia (harness)
    $cfgOut = Join-Path $ArnesDir 'config.json'
    if (-not (Test-Path $cfgOut)) {
        $template = Join-Path $Root '.arnes\config.json'
        if (Test-Path $template) { Copy-Item $template $cfgOut -Force }
        else {
            @{ version='1.0.0'; codename='argos'; player=@{ name='Atlas'; role='Player / Orchestrator'; tagline='Rojo y Negro como el Atlas de la Liga MX' } } |
                ConvertTo-Json -Depth 5 | Set-Content -Path $cfgOut -Encoding UTF8
        }
    }
    # perfil del proyecto
    try { & (Join-Path $ScriptDir 'argos-project.ps1') -Update | Out-Null } catch { }
    C-DONE 'ARNES inicializado (.arnes/config.json + project.json)'
} else {
    C-INFO 'ARNES ya inicializado en esta carpeta'
}

# ============ 2. OSMA (motor de memoria) ============
# Cargar resolver (provee Test-OsmaInstalled / Get-OsmaRoot / Get-OsmaMemoryCli)
. (Join-Path $ScriptDir 'osma-resolve.ps1')

if (Test-OsmaInstalled) {
    C-INFO ("OSMA motor presente: {0}" -f (Get-OsmaRoot))
} else {
    C-WARN 'OSMA (motor de memoria) NO esta instalado en ~/.config/arnes/osma'
    C-STEP 'Instalando OSMA...'
    try {
        # Reutilizar la logica de osma-install de argos.ps1 (repo local o clon GitHub)
        $osmaInstall = $null
        $localCandidates = @(
            (Join-Path (Get-ArnesHome) 'Documents\GitHub\osma\install.ps1'),
            (Join-Path $Root '..\osma\install.ps1'),
            (Join-Path $Root 'osma\install.ps1')
        )
        foreach ($c in $localCandidates) { if (Test-Path $c) { $osmaInstall = $c; break } }
        if (-not $osmaInstall) {
            $tmp = Join-Path $env:TEMP ('osma-install-' + [guid]::NewGuid().ToString('N'))
            & git clone --depth 1 https://github.com/mauriragna88/osma.git $tmp 2>&1 | Out-Null
            $osmaInstall = Join-Path $tmp 'install.ps1'
        }
        if ($osmaInstall -and (Test-Path $osmaInstall)) {
            & $osmaInstall
            . (Join-Path $ScriptDir 'osma-resolve.ps1')
            if (Test-OsmaInstalled) { C-DONE 'OSMA instalado correctamente' }
            else { C-WARN 'OSMA install termino pero no se detecta el motor; revisar manualmente' }
        } else {
            C-WARN 'No se pudo localizar install.ps1 de OSMA. Corre: argos osma-install'
        }
    } catch {
        C-WARN ("Fallo al instalar OSMA: {0}" -f $_.Exception.Message)
    }
}

# ============ 3. MEMORIA PRECARGADA (.arnes/arnes.db + .arnes/memory/) ============
$dbPath = Join-Path $ArnesDir 'arnes.db'
$memDir = Join-Path $ArnesDir 'memory'

# 3a. arnes.db (esquema de memoria) - via motor OSMA init (idempotente)
$memCli = Get-OsmaMemoryCli
if ($memCli) {
    try { & $memCli init *> $null; C-INFO 'arnes.db: esquema de memoria listo' } catch {
        C-WARN ("arnes.db init fallo: {0}" -f $_.Exception.Message)
    }
} else {
    C-WARN 'Sin CLI de memoria disponible (modo degradado)'
}

# 3b. .arnes/memory/ (carpeta de exports JSONL por agente)
if (-not (Test-Path $memDir)) {
    C-STEP 'Creando .arnes/memory/ (memoria por agente)...'
    New-Item -ItemType Directory -Path $memDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $memDir 'export') -Force | Out-Null
    # Carpeta por agente del party
    foreach ($ag in @('atlas','vivi','ansem','kuja','eiko','amarant','eremez','auron','bran','quina','varys','tywin','sam','bard','tidus','ragnarok')) {
        $ad = Join-Path $memDir $ag
        if (-not (Test-Path $ad)) { New-Item -ItemType Directory -Path $ad -Force | Out-Null }
    }
    C-DONE '.arnes/memory/ creado con carpetas por agente'
} else {
    C-INFO '.arnes/memory/ ya existe'
}

# 3c. Sembrar observaciones iniciales SI la memoria esta vacia (primera vez en el proyecto)
$obsCount = 0
try {
    if ($memCli) {
        $stats = & $memCli stats -Quiet 2>$null
        if ($stats) {
            try { $s = $stats | ConvertFrom-Json; $obsCount = [int]$s.observations } catch { $obsCount = 0 }
        }
    }
} catch { $obsCount = 0 }

if ($obsCount -eq 0) {
    C-STEP 'Memoria vacia - sembrando observaciones iniciales desde el proyecto...'
    $seeded = 0
    # Fuente 1: docs del proyecto (README, SEGUIMIENTO, DECISION, CLAUDE.md)
    $docCandidates = @('README.md','SEGUIMIENTO*.md','DECISION*.md','PLAN*.md','ROADMAP*.md','CLAUDE.md','AGENTS.md')
    $foundDocs = @()
    foreach ($pat in $docCandidates) {
        $foundDocs += Get-ChildItem -Path $ProjectRoot -Filter $pat -File -ErrorAction SilentlyContinue
    }
    foreach ($d in $foundDocs | Select-Object -First 8) {
        try {
            $txt = Get-Content $d.FullName -Raw -ErrorAction Stop
            $snip = $txt.Substring(0, [Math]::Min(600, $txt.Length)) -replace '\s+', ' '
            if ($snip.Length -gt 40) {
                & $memCli save -Agent atlas -Content ("Contexto del proyecto ({0}): {1}" -f $d.Name, $snip) -Type discovery -Topic "proyecto/$($d.BaseName.ToLower())" -Score 3 *> $null
                $seeded++
            }
        } catch { }
    }
    # Fuente 2: perfil del proyecto
    $prjFile = Join-Path $ArnesDir 'project.json'
    if (Test-Path $prjFile) {
        try {
            $pj = Get-Content $prjFile -Raw | ConvertFrom-Json
            $snip2 = "Proyecto {0} en {1}. Stack: {2}. Git: {3}" -f $pj.name, $pj.path, ($pj.stack -join ','), $pj.git_branch
            & $memCli save -Agent atlas -Content $snip2 -Type discovery -Topic 'proyecto/perfil' -Score 4 *> $null
            $seeded++
        } catch { }
    }
    C-DONE ("Memoria sembrada: {0} observaciones iniciales" -f $seeded)
} else {
    C-INFO ("Memoria con {0} observaciones (OK)" -f $obsCount)
}

# ============ 3d. PROJECT PROFILER (tipo de app + variantes de solucion) ============
# Clasifica el proyecto: landing/fullstack/api/spa/desktop/mobile/cli.
# Ofrece variantes (web/desktop/movil/offline): NO siempre la web es la mejor respuesta.
$profiler = Join-Path $ScriptDir 'project-profiler.ps1'
if (Test-Path $profiler) {
    try {
        if (-not $Quiet) { C-STEP 'Profileando tipo de proyecto...' }
        if ($Quiet) {
            & $profiler -ProjectPath $ProjectRoot -ArnesDir $ArnesDir -Silent | Out-Null
        } else {
            & $profiler -ProjectPath $ProjectRoot -ArnesDir $ArnesDir | Out-Null
        }
        # Mostrar resumen del tipo si no es silencioso
        $typeFile = Join-Path $ArnesDir 'project-type.json'
        if ((Test-Path $typeFile) -and -not $Quiet) {
            try {
                $pt = Get-Content $typeFile -Raw | ConvertFrom-Json
                C-INFO ("Tipo de proyecto: {0} (confianza {1}%)" -f $pt.project_type.ToUpper(), $pt.confidence)
                foreach ($r in @($pt.recommendations) | Select-Object -First 2) {
                    Write-Host ("         {0}" -f $r) -ForegroundColor DarkGray
                }
            } catch {}
        }
    } catch {
        C-WARN ("Profiler fallo (continua): {0}" -f $_.Exception.Message)
    }
}

# ============ 4. Resumen ============
if (-not $Quiet) {
    $dbOk = Test-Path $dbPath
    $memOk = Test-Path $memDir
    Write-Host ''
    Write-Host '  ═══════════════════════════════════════' -ForegroundColor DarkRed
    Write-Host ('  ARNES:  {0}' -f $(if (Test-Path (Join-Path $ArnesDir 'config.json')) { 'OK ✓' } else { 'FALTA' })) -ForegroundColor White
    Write-Host ('  OSMA:   {0}' -f $(if (Test-OsmaInstalled) { 'OK ✓' } else { 'NO instalado' })) -ForegroundColor White
    Write-Host ('  arnes.db: {0}' -f $(if ($dbOk) { 'OK ✓' } else { 'FALTA' })) -ForegroundColor White
    Write-Host ('  memoria/: {0}' -f $(if ($memOk) { 'OK ✓' } else { 'FALTA' })) -ForegroundColor White
    Write-Host '  ═══════════════════════════════════════' -ForegroundColor DarkRed
    Write-Host ''
    Write-Host '  Listo para trabajar. El party y la memoria estan cargados.' -ForegroundColor Green
    Write-Host ''
}