#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS DOCTOR - Verifica los prerequisitos del harness ARNES ARGOS

.DESCRIPTION
Revisa: PowerShell, Python 3 (+sqlite3), Node.js/npm, OpenCode CLI, Freebuff CLI,
Git, configuracion global (~/.config/arnes), agentes instalados y Docker (opcional).
Reporta OK / WARN / MISSING con la instruccion de arreglo para cada uno.

.EXAMPLE
.\argos-doctor.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

$checks = New-Object System.Collections.ArrayList
function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Detail, [string]$Fix)
    [void]$script:checks.Add([pscustomobject]@{ Name = $Name; Ok = $Ok; Detail = $Detail; Fix = $Fix })
}

# === PowerShell ===
$psOk = $PSVersionTable.PSVersion.Major -ge 5
Add-Check 'PowerShell' $psOk "v$($PSVersionTable.PSVersion)" 'Windows: PS 5.1 preinstalado | macOS/Linux: pwsh 7+ (https://aka.ms/powershell)'

# === Python 3 + sqlite3 ===
$pyVer = ''
$pyOk = $false
try { $pyVer = (python --version 2>&1) -replace 'Python ', ''; $pyOk = $true } catch { $pyVer = 'no encontrado' }
$sqliteOk = $false
if ($pyOk) {
    try { python -c 'import sqlite3' 2>$null; $sqliteOk = ($LASTEXITCODE -eq 0) } catch {}
}
Add-Check 'Python 3 (+sqlite3)' ($pyOk -and $sqliteOk) "$pyVer / sqlite3=$(if ($sqliteOk) { 'OK' } else { 'MISSING' })" 'https://python.org (sqlite3 viene incluido en Python)'

# === Node.js + npm ===
$nodeVer = ''
$npmVer = ''
$nodeOk = $false
try { $nodeVer = node --version 2>$null; $nodeOk = $true } catch { $nodeVer = 'no encontrado' }
if ($nodeOk) { try { $npmVer = npm --version 2>$null } catch {} }
Add-Check 'Node.js + npm' $nodeOk "$nodeVer / npm $npmVer" 'https://nodejs.org (npm incluido; NO se necesita bun)'

# === OpenCode CLI ===
$oc = Get-Command opencode -ErrorAction SilentlyContinue
Add-Check 'OpenCode CLI (motor)' ($null -ne $oc) $(if ($oc) { $oc.Source } else { 'faltante' }) 'npm install -g opencode-ai'

# === Freebuff CLI (target gratuito) ===
$fb = Get-Command freebuff -ErrorAction SilentlyContinue
Add-Check 'Freebuff CLI (target)' ($null -ne $fb) $(if ($fb) { $fb.Source } else { 'faltante' }) 'npm install -g freebuff'

# === Git ===
$gitVer = ''
$gitOk = $false
try { $gitVer = (git --version 2>&1) -replace 'git version ', ''; $gitOk = $true } catch { $gitVer = 'no encontrado' }
Add-Check 'Git' $gitOk $gitVer 'https://git-scm.com/downloads'

# === Config global de la maquina ===
$cfgDir = Join-Path $env:USERPROFILE '.config\arnes'
$connOk = Test-Path (Join-Path $cfgDir 'connections.json')
$modelsOk = Test-Path (Join-Path $cfgDir 'agent-models.json')
Add-Check 'Conexiones globales' $connOk $(if ($connOk) { "$cfgDir\connections.json" } else { 'faltante' }) 'argos connect (UNA vez por maquina)'
Add-Check 'Modelos por agente' $modelsOk $(if ($modelsOk) { "$cfgDir\agent-models.json" } else { 'faltante' }) 'argos configure (UNA vez por maquina)'

# === Agentes RPG instalados ===
$agentsDir = Join-Path $env:USERPROFILE '.config\opencode\agents'
$expectedAgents = @('atlas-player', 'vivi', 'ansem', 'kuja', 'eiko', 'amarant', 'eremez', 'auron', 'bran', 'quina', 'varys', 'tywin', 'sam', 'bard', 'tidus', 'ragnarok')
$installed = @()
if (Test-Path $agentsDir) {
    $installed = @(Get-ChildItem (Join-Path $agentsDir '*.md') -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName })
}
$missing = @($expectedAgents | Where-Object { $_ -notin $installed })
$agentCount = $expectedAgents.Count - $missing.Count
$detail = "$agentCount/16 agentes"
if ($missing.Count -gt 0) {
    $detail += " | faltan: " + ($missing -join ', ')
}
Add-Check 'Agentes RPG instalados' ($missing.Count -eq 0) $detail 'atlas --sync  (o npm install -g .)'

# === Docker (opcional) ===
$docker = Get-Command docker -ErrorAction SilentlyContinue
Add-Check 'Docker (opcional)' ($null -ne $docker) $(if ($docker) { $docker.Source } else { 'no instalado (opcional)' }) 'Solo para la opcion contenedor: https://docker.com'

# === Render ===
Write-Host ''
Write-Host '  ARNES ARGOS - DOCTOR DE PREREQUISITOS' -ForegroundColor Cyan
Write-Host '  =====================================' -ForegroundColor Cyan
Write-Host ''
$okCount = 0
foreach ($c in $checks) {
    $icon = if ($c.Ok) { '[OK]' } else { '[!!]' }
    $color = if ($c.Ok) { 'Green' } else { 'Yellow' }
    Write-Host ("  {0} {1,-26} {2}" -f $icon, $c.Name, $c.Detail) -ForegroundColor $color
    if (-not $c.Ok) { Write-Host ("       -> " + $c.Fix) -ForegroundColor DarkGray }
    if ($c.Ok) { $okCount++ }
}
Write-Host ''
if ($okCount -eq $checks.Count) {
    Write-Host "  [OK] $okCount/$($checks.Count) prerequisitos correctos. Listo para ARGOS." -ForegroundColor Green
} else {
    Write-Host "  [!] $($checks.Count - $okCount) prerequisitos pendientes. Sigue las instrucciones de arriba." -ForegroundColor Yellow
}
Write-Host ''
