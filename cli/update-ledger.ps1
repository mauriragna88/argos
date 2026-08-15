# update-ledger.ps1 - Tracker de tokens y quests
# =============================================
# Usado por Quina (Banker) para actualizar .arnes/quest-ledger.json
# despues de cada quest completado.

#Requires -Version 5.1
param(
    [Parameter(Mandatory=$true)] [string]$QuestName,
    [Parameter(Mandatory=$true)] [int]$TokensUsed,
    [string]$Platform = "opencode",
    [string]$Status = "completed",
    [string]$Agents = "",
    [int]$DurationSeconds = 0,
    [int]$CacheHitTokens = 0,
    [int]$CacheMissTokens = 0
)

$ROOT = $PSScriptRoot
while (-not (Test-Path (Join-Path $ROOT ".arnes")) -and (Split-Path -Parent $ROOT)) {
    $ROOT = Split-Path -Parent $ROOT
}
$LedgerFile = Join-Path $ROOT ".arnes\quest-ledger.json"

if (-not (Test-Path $LedgerFile)) {
    Write-Warning "No existe $LedgerFile. Corre 'atlas' primero para inicializar."
    exit 1
}

$ledger = Get-Content $LedgerFile -Raw | ConvertFrom-Json

# === Weekly reset check ===
$now = Get-Date
$weekStart = Get-Date -Day $now.Day -Hour 0 -Minute 0 -Second 0
# Ajustar al lunes mas reciente
while ($weekStart.DayOfWeek -ne "Monday") {
    $weekStart = $weekStart.AddDays(-1)
}
if (-not $ledger.weekly_reset_at -or (Get-Date $ledger.weekly_reset_at) -lt $weekStart) {
    # Reset semanal
    $ledger.limits.weekly_tokens_used = 0
    $ledger.limits.weekly_tokens_remaining = $ledger.limits.weekly_tokens_budget
    foreach ($p in @("opencode", "codex", "claude")) {
        $ledger.by_platform.$p.actual_used = 0
    }
    $ledger.weekly_reset_at = (Get-Date -Format "o")
    Write-Host "[QUINA] Weekly reset aplicado (lunes 00:00)"
}

# === Registrar quest ===
$entry = [PSCustomObject]@{
    quest_id       = [guid]::NewGuid().ToString()
    name           = $QuestName
    platform       = $Platform
    status         = $Status
    tokens_used    = $TokensUsed
    duration_sec   = $DurationSeconds
    agents         = $Agents
    cache_hit      = $CacheHitTokens
    cache_miss     = $CacheMissTokens
    started_at     = (Get-Date -Format "o")
}

$ledger.quests += $entry
$ledger.stats.total_quests = $ledger.quests.Count
$ledger.stats.total_tokens_used += $TokensUsed
$ledger.stats.avg_tokens_per_quest = [int]($ledger.stats.total_tokens_used / [Math]::Max($ledger.stats.total_quests, 1))

# Actualizar weekly
$ledger.limits.weekly_tokens_used += $TokensUsed
$ledger.limits.weekly_tokens_remaining = [Math]::Max(0, $ledger.limits.weekly_tokens_budget - $ledger.limits.weekly_tokens_used)

# Actualizar platform
if ($ledger.by_platform.$Platform) {
    $ledger.by_platform.$Platform.actual_used += $TokensUsed
}

# === Guardar ===
$ledger | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $LedgerFile -Encoding UTF8

# === Mostrar /status ===
Write-Host ""
Write-Host "========================================================" -ForegroundColor Red
Write-Host "  [QUINA] Status actualizado" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Red
Write-Host ""
Write-Host "  Quest:           $QuestName"
Write-Host "  Tokens used:     $TokensUsed"
Write-Host "  Platform:        $Platform"
if ($CacheHitTokens -gt 0) {
    $cachePct = [math]::Round(($CacheHitTokens / [Math]::Max($TokensUsed, 1)) * 100, 0)
    Write-Host "  Cache hit:       $CacheHitTokens tkns ($cachePct%) - ahorro activo" -ForegroundColor Green
}
Write-Host ""
$pct = [int](($ledger.limits.weekly_tokens_used / $ledger.limits.weekly_tokens_budget) * 100)
Write-Host "  Budget semanal:  $($ledger.limits.weekly_tokens_budget) tokens"
Write-Host "  Used esta sem:   $($ledger.limits.weekly_tokens_used) tokens ($pct%)"
Write-Host "  Remaining:       $($ledger.limits.weekly_tokens_remaining) tokens"
Write-Host ""

# Aviso de threshold
if ($pct -ge $ledger.limits.critical_threshold_pct) {
    Write-Host "  [QUINA] !!! CRITICAL: solo queda $($ledger.limits.weekly_tokens_remaining) tokens. Pausar Atlas?" -ForegroundColor Red
} elseif ($pct -ge $ledger.limits.warn_threshold_pct) {
    Write-Host "  [QUINA] Warn: llevas $pct% del budget semanal" -ForegroundColor Yellow
}
