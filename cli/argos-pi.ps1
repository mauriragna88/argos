<#
.SYNOPSIS
ARGOS SUPERPOWERS - launcher: health-check + arranque de Pi como runtime (single brain).
.SUMMARY
Solo arranca la experiencia. El desarrollo ocurre DENTRO de Pi. La unica memoria
persistente es <proyecto>/.arnes/arnes.db (pi corre con --no-session).
La sesion principal de Pi arranca con el modelo de ATLAS (orquestador) desde
agent-models.json - no hace falta /model manual.
#>
[CmdletBinding()]
param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'osma-resolve.ps1')

# 1. project root + .arnes
$root = (Get-Location).Path
$arnes = Join-Path $root '.arnes'
if (-not (Test-Path (Join-Path $arnes 'arnes.db'))) {
    Write-Host '  [ARGOS] Sin .arnes/arnes.db aqui.' -ForegroundColor Yellow
    Write-Host '  [ARGOS] Se abrira Pi normal (sin ARGOS).' -ForegroundColor Yellow
    if ($DryRun) { exit 0 }
    & pi --no-session
    exit $LASTEXITCODE
}

# 2. health-check basico (memoria)
Write-Host '  [ARGOS] Health-check...' -ForegroundColor Cyan
$memCli = (Get-OsmaMemoryCli)
if (-not (Test-OsmaInstalled)) {
    Write-Host '  [ARGOS] OSMA no instalado: memoria desactivada (modo degradado).' -ForegroundColor Yellow
    Write-Host '          Instala: argos osma-install   (o: osma/install.ps1)' -ForegroundColor DarkGray
} else {
    $stats = & $memCli stats 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ARGOS] FALLO memoria: $stats" -ForegroundColor Red
        exit 1
    }
}

# 2b. sync de skills (fusion harnesses: Pi <-> OpenCode)
Write-Host '  [ARGOS] Sync skills (Pi <-> OpenCode)...' -ForegroundColor Cyan
$syncCli = Join-Path $PSScriptRoot 'argos-sync-skills.ps1'
if (Test-Path $syncCli) {
    & $syncCli 2>&1 | Where-Object { $_ -match '\[SYNC\]\s*[+=!]' } | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
} else {
    Write-Host '  [ARGOS] AVISO: no hay argos-sync-skills.ps1' -ForegroundColor Yellow
}

# 3. pi + superpowers + modelos
if (-not (Get-Command pi -ErrorAction SilentlyContinue)) {
    Write-Host '  [ARGOS] FALLO: pi no instalado' -ForegroundColor Red
    exit 1
}
$sp = & { $ErrorActionPreference = 'Continue'; (& pi list 2>&1 | Out-String) }
if ($sp -notmatch 'superpowers') {
    Write-Host '  [ARGOS] AVISO: superpowers no visible en pi list' -ForegroundColor Yellow
}
$models = Join-Path $env:USERPROFILE '.config\arnes\agent-models.json'
if (-not (Test-Path $models)) {
    Write-Host '  [ARGOS] AVISO: no hay agent-models.json global' -ForegroundColor Yellow
}

# 4. modelo del ORQUESTADOR (Atlas) - la sesion principal de Pi arranca con EL
$atlasModel = ''
if (Test-Path $models) {
    try {
        $raw = Get-Content $models -Raw | ConvertFrom-Json
        if ($raw.agents.atlas) { $atlasModel = [string]$raw.agents.atlas }
    } catch {}
}

# 5. banner (ASCII, sin mojibake)
Write-Host '============================================================' -ForegroundColor Red
Write-Host '  ARGOS SUPERPOWERS' -ForegroundColor Red
Write-Host '  Runtime       Pi Coding Agent' -ForegroundColor Gray
Write-Host '  Brain         ARGOS Cognitive Memory V3' -ForegroundColor Gray
Write-Host '  Memory        .arnes/arnes.db' -ForegroundColor Gray
Write-Host '  RAG           FTS5 / BM25' -ForegroundColor Gray
Write-Host '  Party         16 agents' -ForegroundColor Gray
if ($atlasModel) { Write-Host ("  Orquestador   Atlas -> {0}" -f $atlasModel) -ForegroundColor Yellow }
Write-Host '  Superpowers   READY' -ForegroundColor Gray
Write-Host '============================================================' -ForegroundColor Red
Write-Host ''

# 6. transferir a Pi (single brain) - SIEMPRE con el modelo de Atlas (orquestador)
if ($DryRun) { exit 0 }
if ($atlasModel) {
    Write-Host ("  [ARGOS] Arrancando Pi con Atlas ({0}) como orquestador..." -f $atlasModel) -ForegroundColor Cyan
    & pi --model $atlasModel --no-session
} else {
    Write-Host '  [ARGOS] Sin modelo de Atlas configurado - arrancando Pi default.' -ForegroundColor Yellow
    & pi --no-session
}
exit $LASTEXITCODE
