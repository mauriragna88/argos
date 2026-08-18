# model-telemetry.ps1 - FASE 1: telemetria formal por modelo (osma-model-run / osma-model-stats)
# =============================================================================================
# Registra y consulta QUE modelo hizo QUE, con QUE resultado y a QUE costo.
# Event log append-only: .arnes/model-runs.jsonl (no es memoria paralela — es registro
# de telemetria; OSMA sigue siendo el cerebro).
#
# Acciones:
#   record  -> append de una corrida de modelo (agent/model/provider/quest_type/difficulty/
#              route/party/tokens/verdict/reward/timestamp)
#   stats   -> agregados: success_rate, avg_tokens, cost estimado por model x quest_type
#
# Uso:
#   .\cli\model-telemetry.ps1 -Action record -Agent vivi -Model opencode-go/deepseek-v4-pro `
#       -Provider opencode -QuestId Q-001 -QuestType frontend -Difficulty 3 -Route pro `
#       -Party "vivi,eiko" -TokensUsed 4500 -Verdict PASS -Reward 0.9
#   .\cli\model-telemetry.ps1 -Action stats
#   .\cli\model-telemetry.ps1 -Action stats -Json
#   .\cli\model-telemetry.ps1 -Action stats -Model opencode-go/deepseek-v4-pro

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("record","stats")]
    [string]$Action = "stats",

    # --- record ---
    [string]$Agent = "",
    [string]$Model = "",
    [string]$Provider = "",
    [string]$QuestId = "",
    [string]$QuestType = "",
    [int]$Difficulty = 0,
    [string]$Route = "",
    [string]$Party = "",
    [int]$TokensUsed = 0,
    [ValidateSet("PASS","FAIL_PARTIAL","FAIL_TOTAL")]
    [string]$Verdict = "",
    [double]$Reward = 0,

    [switch]$Json,
    [string]$ArnesDir = ""
)

$ErrorActionPreference = "Continue"

if (-not $ArnesDir) {
    $cwd = (Get-Location).Path
    if (Test-Path (Join-Path $cwd ".arnes\config.json")) {
        $ArnesDir = Join-Path $cwd ".arnes"
    } else {
        $ArnesDir = ".arnes"
    }
}

$logFile = Join-Path $ArnesDir "model-runs.jsonl"

function Read-Runs {
    if (-not (Test-Path -LiteralPath $logFile)) { return @() }
    $runs = @()
    foreach ($line in (Get-Content -LiteralPath $logFile -Encoding UTF8 | Where-Object { $_.Trim() })) {
        try { $runs += ($line | ConvertFrom-Json) } catch {}
    }
    return @($runs)
}

# === RECORD ===
if ($Action -eq "record") {
    if (-not $Model) { Write-Error "record requiere -Model"; exit 1 }
    if (-not $Agent) { $Agent = "atlas" }
    if (-not $Provider) {
        $p = ($Model -split "/")[0]
        $Provider = $p
    }
    if (-not $QuestType) { $QuestType = "unknown" }
    if (-not $Route) {
        $Route = if ($Difficulty -ge 4) { "highest" } elseif ($Difficulty -eq 3) { "pro" } else { "flash" }
    }
    if ($Verdict -eq "PASS") { $reward = if ($Reward -ne 0) { $Reward } else { 0.9 } }
    elseif ($Verdict -eq "FAIL_PARTIAL") { $reward = if ($Reward -ne 0) { $Reward } else { 0.3 } }
    elseif ($Verdict -eq "FAIL_TOTAL") { $reward = if ($Reward -ne 0) { $Reward } else { -0.8 } }
    else { $reward = $Reward }

    $run = [ordered]@{
        event = "model_run"
        ts = (Get-Date).ToString("o")
        agent = $Agent
        model = $Model
        provider = $Provider
        quest_id = $QuestId
        quest_type = $QuestType
        difficulty = $Difficulty
        route = $Route
        party = $Party
        tokens_used = $TokensUsed
        verdict = $Verdict
        reward = $reward
    } | ConvertTo-Json -Compress

    if (-not (Test-Path -LiteralPath $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }
    Add-Content -LiteralPath $logFile -Value $run -Encoding UTF8
    if ($Json) {
        $run | ConvertFrom-Json | ConvertTo-Json -Depth 4
    } else {
        Write-Host ("  [TELEMETRY] run registrado: {0} | {1} | {2} | {3} tokens | {4}" -f $QuestId, $Model, $Agent, $TokensUsed, $Verdict) -ForegroundColor Green
    }
    exit 0
}

# === STATS ===
$runs = Read-Runs
if (@($runs).Count -eq 0) {
    if ($Json) { @{ total = 0; note = "no model runs yet" } | ConvertTo-Json; exit 0 }
    Write-Host "  [TELEMETRY] No hay .arnes/model-runs.jsonl todavia." -ForegroundColor Yellow
    Write-Host "             Se registran runs en quest-done (loop-engine) o con model-telemetry.ps1 -Action record." -ForegroundColor DarkGray
    exit 0
}

$filtered = if ($Model) { @($runs | Where-Object { $_.model -eq $Model }) } else { $runs }
if (@($filtered).Count -eq 0) {
    if ($Json) { @{ total = 0; note = "no runs for model $Model" } | ConvertTo-Json; exit 0 }
    Write-Host "  [TELEMETRY] Sin runs para modelo '$Model'." -ForegroundColor Yellow
    exit 0
}

$byModel = @{}
foreach ($r in $filtered) {
    $key = "$($r.model) [$($r.route)]"
    if (-not $byModel.ContainsKey($key)) { $byModel[$key] = @{ count = 0; pass = 0; fail = 0; tokens = 0; difficulty = @{}; quest_types = @{} } }
    $byModel[$key].count++
    if ($r.verdict -eq "PASS") { $byModel[$key].pass++ } elseif ($r.verdict) { $byModel[$key].fail++ }
    $byModel[$key].tokens += [int]$r.tokens_used
    $d = "D$([int]$r.difficulty)"
    if (-not $byModel[$key].difficulty.ContainsKey($d)) { $byModel[$key].difficulty[$d] = 0 }
    $byModel[$key].difficulty[$d]++
    $qt = "$($r.quest_type)"
    if (-not $byModel[$key].quest_types.ContainsKey($qt)) { $byModel[$key].quest_types[$qt] = 0 }
    $byModel[$key].quest_types[$qt]++
}

function Rate([int]$pass, [int]$total) {
    if ($total -le 0) { return 0 }
    return [math]::Round(($pass / $total) * 100, 0)
}

if ($Json) {
    $out = @{
        total = @($filtered).Count
        by_model = @($byModel.GetEnumerator() | ForEach-Object {
            $v = $_.Value
            @{
                model = $_.Key
                count = $v.count
                pass = $v.pass
                fail = $v.fail
                success_pct = (Rate $v.pass $v.count)
                avg_tokens = if ($v.count -gt 0) { [int][math]::Round($v.tokens / $v.count) } else { 0 }
                total_tokens = $v.tokens
                difficulties = $v.difficulty
                quest_types = $v.quest_types
            }
        })
    }
    $out | ConvertTo-Json -Depth 6
    exit 0
}

# Consola UTF-8 antes del primer Write-Host
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

Write-Host ""
Write-Host "  TELEMETRIA DE MODELOS - Fase 1 (model -> resultado)" -ForegroundColor Cyan
Write-Host "  =====================================================" -ForegroundColor Cyan
Write-Host ("  Runs: {0}  |  PASS {1}  FAIL {2}  |  tokens totales {3}" -f @($filtered).Count,
    @($filtered | Where-Object { $_.verdict -eq "PASS" }).Count,
    @($filtered | Where-Object { $_.verdict -and $_.verdict -ne "PASS" }).Count,
    ($filtered | Measure-Object tokens_used -Sum | Select-Object -ExpandProperty Sum)) -ForegroundColor White
Write-Host ""

$byModel.GetEnumerator() | Sort-Object { $_.Value.count } -Descending | ForEach-Object {
    $v = $_.Value
    $sr = Rate $v.pass $v.count
    $color = if ($sr -ge 80) { "Green" } elseif ($sr -ge 50) { "Yellow" } else { "Red" }
    $avg = if ($v.count -gt 0) { [int][math]::Round($v.tokens / $v.count) } else { 0 }
    $dList = ($v.difficulty.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)x$($_.Value)" }) -join " "
    $qtList = ($v.quest_types.GetEnumerator() | Sort-Object { $_.Value } -Descending | ForEach-Object { "$($_.Key)x$($_.Value)" }) -join " "
    Write-Host ("    {0,-42} {1,4} runs | success {2,3}% | avg {3,5} tok | {4}" -f $_.Key, $v.count, $sr, $avg, $dList) -ForegroundColor $color
    Write-Host ("        quests: {0}" -f $qtList) -ForegroundColor DarkGray
}
Write-Host ""

# Mejor config (>=2 runs)
$best = $byModel.GetEnumerator() | ForEach-Object {
    $v = $_.Value
    [PSCustomObject]@{ model = $_.Key; count = $v.count; pass = $v.pass; success_pct = (Rate $v.pass $v.count) }
} | Where-Object { $_.count -ge 2 } | Sort-Object success_pct -Descending | Select-Object -First 1
if ($best) {
    Write-Host ("  Mejor modelo (>=2 runs): {0} -> {1}% success" -f $best.model, $best.success_pct) -ForegroundColor Green
    Write-Host ""
}
