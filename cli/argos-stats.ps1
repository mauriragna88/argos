#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS STATS - dashboard de actividad basado en quest-ledger.

.DESCRIPTION
Lee `.arnes/quest-ledger.json` y muestra: quests totales, tokens usados,
costo estimado en USD, desglose por dia (ultimos 7), por agente, tasa de
exito, racha actual y mejor racha historica de dias activos.

.EXAMPLE
.\cli\argos-stats.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Tema activo: colores compartidos desde theme-colors.ps1
. (Join-Path $PSScriptRoot 'theme-colors.ps1')
$theme = Get-ThemeColors

# Dot-source tabla de precios por modelo (Get-ModelPricePerToken)
$PricingFile = Join-Path $PSScriptRoot 'pricing.ps1'
if (-not (Test-Path $PricingFile)) {
    Write-Host '  [!] No se encontro cli\pricing.ps1 (tabla de precios).' -ForegroundColor Yellow
    exit 1
}
. $PricingFile

$WorkDir = (Get-Location).Path
$LedgerFile = Join-Path $WorkDir '.arnes\quest-ledger.json'

if (-not (Test-Path $LedgerFile)) {
    Write-Host '  [!] No hay quest-ledger.json en este proyecto.' -ForegroundColor Yellow
    exit 1
}

$ledger = Get-Content $LedgerFile -Raw | ConvertFrom-Json
$quests = @($ledger.quests)
if ($quests.Count -eq 0) {
    Write-Host '  [!] El quest-ledger no tiene quests registrados.' -ForegroundColor Yellow
    exit 1
}

$today = (Get-Date).Date
$totalTokens = 0
$totalCost = 0.0
$passCount = 0
$byDay = @{}
$byDayCost = @{}
$byAgent = @{}
$byWeek = @{}

foreach ($q in $quests) {
    $tokens = [int]$q.tokens_used
    $totalTokens += $tokens

    # Costo estimado USD: si el quest no registra modelo, usa DeepSeek Flash (0.21/1M)
    $model = [string]$q.model
    $pricePerToken = 0.21 / 1000000.0
    if ($model) { $pricePerToken = Get-ModelPricePerToken $model }
    $cost = $tokens * $pricePerToken
    $totalCost += $cost

    if ([string]$q.verdict -eq 'PASS') { $passCount++ }

    $ts = [datetime]::MinValue
    if (-not [DateTime]::TryParse([string]$q.timestamp, [ref]$ts)) { continue }
    $dayKey = $ts.Date.ToString('yyyy-MM-dd')
    $weekKey = ('{0}-W{1:00}' -f $ts.Year, [Globalization.CultureInfo]::InvariantCulture.Calendar.GetWeekOfYear($ts, [System.DayOfWeek]::Monday, [System.DayOfWeek]::Monday))
    if (-not $byDay.ContainsKey($dayKey)) { $byDay[$dayKey] = 0 }
    $byDay[$dayKey] += $tokens
    if (-not $byDayCost.ContainsKey($dayKey)) { $byDayCost[$dayKey] = 0.0 }
    $byDayCost[$dayKey] += $cost
    if (-not $byWeek.ContainsKey($weekKey)) { $byWeek[$weekKey] = 0 }
    $byWeek[$weekKey] += $tokens

    $name = [string]$q.agent
    if ($name) {
        if (-not $byAgent.ContainsKey($name)) { $byAgent[$name] = @{ quests = 0; tokens = 0; cost = 0.0 } }
        $byAgent[$name].quests++
        $byAgent[$name].tokens += $tokens
        $byAgent[$name].cost += $cost
    }
}

# Racha: dias consecutivos con actividad terminando hoy (o ayer si hoy no hubo)
$activeDays = @($byDay.Keys | Sort-Object -Descending)
$streak = 0
$cursor = $today
if ($activeDays.Count -gt 0 -and $activeDays[0] -ne $today.ToString('yyyy-MM-dd')) {
    $cursor = $today.AddDays(-1)
}
while ($activeDays -contains $cursor.ToString('yyyy-MM-dd')) {
    $streak++
    $cursor = $cursor.AddDays(-1)
}

# Mejor racha historica: recorrer todos los dias activos en orden ascendente
# y encontrar la secuencia consecutiva mas larga.
$sortedDays = @($byDay.Keys | Sort-Object)
$bestStreak = 0
$currentRun = 0
$prevDate = $null
foreach ($dayKey in $sortedDays) {
    $parsed = [datetime]::MinValue
    if (-not [DateTime]::TryParse($dayKey, [ref]$parsed)) { continue }
    $parsed = $parsed.Date
    if ($prevDate -ne $null -and $parsed.Date -eq $prevDate.AddDays(1)) {
        $currentRun++
    } else {
        $currentRun = 1
    }
    if ($currentRun -gt $bestStreak) { $bestStreak = $currentRun }
    $prevDate = $parsed
}

$successPct = [math]::Round(($passCount / $quests.Count) * 100, 1)
$topAgent = ($byAgent.GetEnumerator() | Sort-Object { $_.Value.tokens } -Descending | Select-Object -First 1)

# === Cache hit/miss agregado (deepseek prompt caching) ===
$totalCacheHit = 0
$totalCacheMiss = 0
foreach ($q in $quests) {
    if ($q.cache_hit) { $totalCacheHit += [int]$q.cache_hit }
    if ($q.cache_miss) { $totalCacheMiss += [int]$q.cache_miss }
}
$cacheSavings = 0.0
if ($totalCacheHit -gt 0) {
    # Calcular savings: cache hit = 1/4 del precio normal vs pagar precio completo
    $normalPrice = 0.21 / 1000000.0   # fallback Flash
    $cacheSavings = $totalCacheHit * $normalPrice * 0.75   # 75% de descuento en cache hit
}

Write-Host ''
Write-Host '  ARNES ARGOS - STATS' -ForegroundColor $theme.Primary
Write-Host '  ==================' -ForegroundColor $theme.Primary
Write-Host ("  Quests:          {0}" -f $quests.Count) -ForegroundColor $theme.Accent
Write-Host ("  Tasa de exito:   {0}%  ({1} PASS / {2})" -f $successPct, $passCount, $quests.Count) -ForegroundColor $theme.Accent
Write-Host ("  Tokens usados:   {0}" -f $totalTokens) -ForegroundColor $theme.Accent
$totalCostStr = ('${0:N2}' -f $totalCost)
Write-Host ("  Costo est.:      {0} USD" -f $totalCostStr) -ForegroundColor $theme.Accent
Write-Host ("  Racha actual:   {0} dias" -f $streak) -ForegroundColor $theme.Accent
Write-Host ("  Mejor racha:    {0} dias" -f $bestStreak) -ForegroundColor $theme.Accent
Write-Host ("  Top por tokens:  {0} ({1} tkns, {2} quests)" -f $topAgent.Key, $topAgent.Value.tokens, $topAgent.Value.quests) -ForegroundColor $theme.Accent

Write-Host ''
Write-Host '  Ultimos 7 dias:' -ForegroundColor $theme.Primary
$last7 = @($byDay.GetEnumerator() | Sort-Object Key -Descending | Select-Object -First 7)
foreach ($d in $last7) {
    $dayCostStr = ('${0:N2}' -f $byDayCost[$d.Key])
    Write-Host ("    {0}  {1} tkns - {2}" -f $d.Key, $d.Value, $dayCostStr) -ForegroundColor $theme.Accent
}

Write-Host ''
Write-Host '  Por agente:' -ForegroundColor $theme.Primary
foreach ($a in ($byAgent.GetEnumerator() | Sort-Object { $_.Value.tokens } -Descending)) {
    $agentCostStr = ('${0:N2}' -f $a.Value.cost)
    Write-Host ("    {0,-12} {1} tkns - {2} · {3} quests" -f $a.Key, $a.Value.tokens, $agentCostStr, $a.Value.quests) -ForegroundColor $theme.Accent
}

# === Seccion de cache (solo si hay datos) ===
if ($totalCacheHit -gt 0 -or $totalCacheMiss -gt 0) {
    $totalInputTokens = $totalCacheHit + $totalCacheMiss
    $cachePct = if ($totalInputTokens -gt 0) { [math]::Round(($totalCacheHit / $totalInputTokens) * 100, 1) } else { 0 }
    $savingsStr = ('${0:N2}' -f $cacheSavings)
    Write-Host ''
    Write-Host '  Cache de prefijo (DeepSeek/OpenAI):' -ForegroundColor $theme.Primary
    Write-Host ("    Cache hit:     {0} tkns ({1}%)" -f $totalCacheHit, $cachePct) -ForegroundColor $theme.Accent
    Write-Host ("    Cache miss:    {0} tkns" -f $totalCacheMiss) -ForegroundColor $theme.Accent
    Write-Host ("    Ahorro est.:   {0} USD" -f $savingsStr) -ForegroundColor Green
}
Write-Host ''
