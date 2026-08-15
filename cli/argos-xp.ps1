#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS XP - ranking de experiencia por agente basado en quest-ledger.

.DESCRIPTION
Lee `.arnes/quest-ledger.json` del proyecto, acumula XP por agente
(PASS = +100 XP, FAIL = +10 XP) y calcula nivel con la formula
nivel = floor(sqrt(xp/100)) + 1. Muestra el ranking completo o un agente.

.EXAMPLE
.\cli\argos-xp.ps1
.\cli\argos-xp.ps1 -Agent vivi
#>
[CmdletBinding()]
param(
    [string]$Agent = ''
)

$ErrorActionPreference = 'Stop'

# Skills por nivel: helper de unlocks desde skill-unlocks.ps1
. (Join-Path $PSScriptRoot 'skill-unlocks.ps1')

# Tema activo: colores compartidos desde theme-colors.ps1
. (Join-Path $PSScriptRoot 'theme-colors.ps1')
$theme = Get-ThemeColors

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$WorkDir = (Get-Location).Path
$ArnesDir = Join-Path $WorkDir '.arnes'
$LedgerFile = Join-Path $ArnesDir 'quest-ledger.json'

if (-not (Test-Path $LedgerFile)) {
    Write-Host '  [!] No hay quest-ledger.json en este proyecto.' -ForegroundColor Yellow
    Write-Host '      Completa un quest primero (argos quest o argos party).' -ForegroundColor Yellow
    exit 1
}

$ledger = Get-Content $LedgerFile -Raw | ConvertFrom-Json

# ==== Formula de nivel ====
function Get-Level([int]$xp) {
    if ($xp -le 0) { return 1 }
    return [math]::Floor([math]::Sqrt($xp / 100.0)) + 1
}

# ==== Acumular XP por agente ====
$xpMap = @{}
$questMap = @{}
$tokenMap = @{}
foreach ($q in @($ledger.quests)) {
    $name = [string]$q.agent
    if (-not $name) { continue }
    if (-not $xpMap.ContainsKey($name)) { $xpMap[$name] = 0; $questMap[$name] = 0; $tokenMap[$name] = 0 }
    $xpMap[$name] += if ([string]$q.verdict -eq 'PASS') { 100 } else { 10 }
    $questMap[$name]++
    $tokenMap[$name] += [int]$q.tokens_used
}

if ($xpMap.Count -eq 0) {
    Write-Host '  [!] El quest-ledger no tiene quests registrados.' -ForegroundColor Yellow
    exit 1
}

# ==== Output ====
if ($Agent) {
    $name = $Agent.ToLower()
    if (-not $xpMap.ContainsKey($name)) {
        Write-Host "  [!] No hay XP para el agente '$Agent'." -ForegroundColor Yellow
        exit 1
    }
    $xp = $xpMap[$name]
    $lvl = Get-Level $xp
    Write-Host ''
    Write-Host "  $name - Nivel $lvl (XP $xp)" -ForegroundColor $theme.Primary
    Write-Host "    Quests: $($questMap[$name]) | Tokens usados: $($tokenMap[$name])" -ForegroundColor $theme.Accent

    $skillFile = Get-AgentSkillFile $name
    if ($skillFile -and (Test-Path $skillFile)) {
        Write-Host ''
        Write-Host '    Skills unlocked:' -ForegroundColor $theme.Accent
        for ($l = 1; $l -le $lvl; $l++) {
            $atLevel = @(Get-SkillsForLevel $name $l)
            if ($atLevel.Count -gt 0) {
                Write-Host ("      [Level {0}] {1}" -f $l, ($atLevel -join ', ')) -ForegroundColor $theme.Accent
            }
        }
    }
    else {
        Write-Host '    Skills: N/A' -ForegroundColor $theme.Accent
    }
    Write-Host ''
    exit 0
}

Write-Host ''
Write-Host '  ARNES ARGOS - RANKING XP' -ForegroundColor $theme.Title
Write-Host '  ========================' -ForegroundColor $theme.Title
Write-Host ''
$rows = $xpMap.GetEnumerator() | Sort-Object Value -Descending
foreach ($r in $rows) {
    $lvl = Get-Level ([int]$r.Value)
    $counts = Get-SkillCounts $r.Key $lvl
    $skillsText = 'N/A'
    if ($counts.Total -gt 0) { $skillsText = '{0}/{1}' -f $counts.Unlocked, $counts.Total }
    Write-Host ("  {0,-12} Nivel {1,-4} XP {2,-6} Quest(s) {3,-3} Tokens {4,-6} Skills: {5}" -f $r.Key, $lvl, $r.Value, $questMap[$r.Key], $tokenMap[$r.Key], $skillsText) -ForegroundColor $theme.Accent
}
Write-Host ''
