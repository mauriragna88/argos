# benchmark.ps1 - FASE 6: benchmark interno del harness (con/sin ARGOS)
# =====================================================================
# Registra corridas del MISMO modelo con y sin ARGOS y compara las metricas
# canonicas: PASS rate, first_pass, tokens, costo, latencia, loops, regresiones,
# hallazgos de seguridad e intervenciones humanas (ADR-026).
#
# Criterio central: modelo medio + ARGOS >= mismo modelo sin ARGOS en PASS rate.
#
# Acciones:
#   record -> registrar una corrida (baseline = sin ARGOS | argos = con ARGOS)
#   report -> comparativa por modelo con deltas y veredicto del criterio central
#   list   -> corridas registradas
#
# Uso:
#   .\cli\benchmark.ps1 -Action record -Model opencode-go/deepseek-v4-flash -Config baseline `
#       -QuestId Q-900 -Verdict FAIL -Tokens 9000 -CostUsd 0.02 -LatencyMs 45000 -Loops 3 -FirstPass:$false
#   .\cli\benchmark.ps1 -Action record -Model opencode-go/deepseek-v4-flash -Config argos (... -Verdict PASS ...)
#   .\cli\benchmark.ps1 -Action report
#   .\cli\benchmark.ps1 -Action report -Json

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("record","report","list")]
    [string]$Action = "report",

    # --- record ---
    [string]$Model = "",
    [ValidateSet("","baseline","argos")]
    [string]$Config = "",
    [string]$QuestId = "",
    [ValidateSet("","PASS","FAIL_PARTIAL","FAIL_TOTAL")]
    [string]$Verdict = "",
    [int]$Tokens = 0,
    [double]$CostUsd = 0,
    [int]$LatencyMs = 0,
    [int]$Loops = 0,
    [switch]$FirstPass,
    [int]$Regressions = 0,
    [int]$SecurityFindings = 0,
    [int]$HumanInterventions = 0,
    [string]$Notes = "",

    [switch]$Json,
    [string]$ArnesDir = ""
)

$ErrorActionPreference = "Continue"

if (-not $ArnesDir) {
    $cwd = (Get-Location).Path
    if (Test-Path (Join-Path $cwd ".arnes\config.json")) { $ArnesDir = Join-Path $cwd ".arnes" } else { $ArnesDir = ".arnes" }
}

$logFile = Join-Path $ArnesDir "benchmarks.jsonl"

function Read-Runs {
    if (-not (Test-Path -LiteralPath $logFile)) { return @() }
    $items = @()
    foreach ($line in (Get-Content -LiteralPath $logFile -Encoding UTF8 | Where-Object { $_.Trim() })) {
        try { $items += ($line | ConvertFrom-Json) } catch {}
    }
    return @($items)
}

# === RECORD ===
if ($Action -eq "record") {
    if (-not $Model) { Write-Error "record requiere -Model"; exit 1 }
    if (-not $Config) { Write-Error "record requiere -Config baseline|argos"; exit 1 }
    if (-not $Verdict) { Write-Error "record requiere -Verdict"; exit 1 }

    $entry = [ordered]@{
        event = "benchmark_run"
        ts = (Get-Date).ToString("o")
        model = $Model
        config = $Config
        quest_id = $QuestId
        verdict = $Verdict
        pass = ($Verdict -eq "PASS")
        first_pass = [bool]$FirstPass
        tokens = $Tokens
        cost_usd = $CostUsd
        latency_ms = $LatencyMs
        loops = $Loops
        regressions = $Regressions
        security_findings = $SecurityFindings
        human_interventions = $HumanInterventions
        notes = $Notes
    } | ConvertTo-Json -Compress

    if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }
    Add-Content -LiteralPath $logFile -Value $entry -Encoding UTF8
    if ($Json) { $entry | ConvertFrom-Json | ConvertTo-Json -Depth 4 } else { Write-Host ("  [BENCH] {0} | {1} | {2}" -f $Model, $Config, $Verdict) -ForegroundColor Green }
    exit 0
}

# === LIST ===
if ($Action -eq "list") {
    $runs = Read-Runs
    if ($Json) { @($runs) | ConvertTo-Json -Depth 5; exit 0 }
    if (@($runs).Count -eq 0) { Write-Host '  [BENCH] Sin corridas registradas.' -ForegroundColor Yellow; exit 0 }
    Write-Host ""
    Write-Host "  BENCHMARK - corridas" -ForegroundColor Cyan
    foreach ($r in $runs) { Write-Host ("  {0,-40} {1,-9} {2,-13} {3,7} tok" -f $r.model, $r.config, $r.verdict, $r.tokens) -ForegroundColor White }
    Write-Host ""
    exit 0
}

# === REPORT ===
$runs = Read-Runs
if (@($runs).Count -eq 0) {
    if ($Json) { @{ total = 0; note = "no benchmark runs yet" } | ConvertTo-Json; exit 0 }
    Write-Host '  [BENCH] Sin datos. Registra corridas con -Action record (baseline y argos).' -ForegroundColor Yellow
    exit 0
}

function Get-Stats($items) {
    $n = @($items).Count
    if ($n -eq 0) { return $null }
    $pass = @($items | Where-Object { $_.pass -eq $true }).Count
    return [ordered]@{
        runs = $n
        pass = $pass
        pass_rate_pct = [math]::Round(($pass / $n) * 100, 0)
        first_pass_pct = [math]::Round((@($items | Where-Object { $_.first_pass -eq $true }).Count / $n) * 100, 0)
        avg_tokens = [int][math]::Round((@($items | Measure-Object tokens -Sum).Sum / $n))
        avg_cost_usd = [math]::Round((@($items | Measure-Object cost_usd -Sum).Sum / $n), 4)
        avg_latency_ms = [int][math]::Round((@($items | Measure-Object latency_ms -Sum).Sum / $n))
        avg_loops = [math]::Round((@($items | Measure-Object loops -Sum).Sum / $n), 1)
        regressions = [int](@($items | Measure-Object regressions -Sum).Sum)
        security_findings = [int](@($items | Measure-Object security_findings -Sum).Sum)
        human_interventions = [int](@($items | Measure-Object human_interventions -Sum).Sum)
    }
}

$models = @($runs | ForEach-Object { $_.model } | Select-Object -Unique)
$report = @()
foreach ($m in $models) {
    $base = Get-Stats @($runs | Where-Object { $_.model -eq $m -and $_.config -eq "baseline" })
    $argo = Get-Stats @($runs | Where-Object { $_.model -eq $m -and $_.config -eq "argos" })
    $centralVerdict = "pendiente"
    if ($base -and $argo) {
        $centralVerdict = if ($argo.pass_rate_pct -ge $base.pass_rate_pct) { "argos>=baseline (criterio central)" } else { "argos<baseline (revisar)" }
    }
    $report += [ordered]@{ model = $m; baseline = $base; argos = $argo; verdict = $centralVerdict }
}

if ($Json) {
    @{ total_runs = @($runs).Count; models = $report } | ConvertTo-Json -Depth 8
    exit 0
}

Write-Host ""
Write-Host "  BENCHMARK DEL HARNESS (mismo modelo, con/sin ARGOS)" -ForegroundColor Cyan
Write-Host "  ====================================================" -ForegroundColor Cyan
foreach ($r in $report) {
    Write-Host ("  {0}" -f $r.model) -ForegroundColor White
    if ($r.baseline) { Write-Host ("    baseline: {0} runs | pass {1}% | first-pass {2}% | {3} tok avg | {4} loops | {5} regr | {6} sec | {7} human" -f $r.baseline.runs, $r.baseline.pass_rate_pct, $r.baseline.first_pass_pct, $r.baseline.avg_tokens, $r.baseline.avg_loops, $r.baseline.regressions, $r.baseline.security_findings, $r.baseline.human_interventions) -ForegroundColor DarkGray }
    if ($r.argos) { Write-Host ("    argos   : {0} runs | pass {1}% | first-pass {2}% | {3} tok avg | {4} loops | {5} regr | {6} sec | {7} human" -f $r.argos.runs, $r.argos.pass_rate_pct, $r.argos.first_pass_pct, $r.argos.avg_tokens, $r.argos.avg_loops, $r.argos.regressions, $r.argos.security_findings, $r.argos.human_interventions) -ForegroundColor DarkGray }
    $color = if ($r.verdict -like "argos>=baseline*") { "Green" } elseif ($r.verdict -like "argos<baseline*") { "Yellow" } else { "DarkGray" }
    Write-Host ("    veredicto: {0}" -f $r.verdict) -ForegroundColor $color
}
Write-Host ""
exit 0
