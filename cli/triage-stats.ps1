# triage-stats.ps1 - Prompt Triage statistics (/triage-stats)
# =========================================================
# Lee .arnes/triage-log.jsonl (event log append-only del Prompt Triage) y
# reporta:
#   - Volumen por dificultad (1-4)
#   - Modelo recomendado por dificultad
#   - Success rate por dificultad (outcome PASS vs FAIL)
#   - Success rate por modelo recomendado (cual dificultad->modelo funciona)
#   - Pendientes sin cerrar (ciclo de memoria abierto)
#
# Uso:
#   .\cli\triage-stats.ps1
#   .\cli\triage-stats.ps1 -Json

#Requires -Version 5.1
[CmdletBinding()]
param(
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

$logFile = Join-Path $ArnesDir "triage-log.jsonl"
if (-not (Test-Path -LiteralPath $logFile)) {
    if ($Json) {
        @{ total = 0; note = "no triage log yet" } | ConvertTo-Json
        exit 0
    }
    Write-Host "  [TRIAGE] No hay .arnes/triage-log.jsonl todavia." -ForegroundColor Yellow
    Write-Host "           El log se crea con cada ejecucion de quest-detector (cli/quest-detector.ps1)." -ForegroundColor DarkGray
    exit 0
}

$events = @()
foreach ($line in (Get-Content -LiteralPath $logFile -Encoding UTF8 | Where-Object { $_.Trim() })) {
    try {
        $evt = $line | ConvertFrom-Json
        if ($evt.event -eq "triage") { $events += $evt }
    } catch {}
}

$total = @($events).Count
if ($total -eq 0) {
    if ($Json) { @{ total = 0; note = "log exists but no triage events" } | ConvertTo-Json; exit 0 }
    Write-Host "  [TRIAGE] Log existe pero sin eventos 'triage'." -ForegroundColor Yellow
    exit 0
}

# --- Agregar por dificultad ---
$byDifficulty = @{}
foreach ($d in 1..4) { $byDifficulty[$d] = @{ count = 0; pass = 0; fail = 0; pending = 0 } }
$modelsByDifficulty = @{}
foreach ($evt in $events) {
    $d = [int]$evt.difficulty
    if ($d -lt 1 -or $d -gt 4) { $d = 0 }
    if (-not $byDifficulty.ContainsKey($d)) { $byDifficulty[$d] = @{ count = 0; pass = 0; fail = 0; pending = 0 } }
    $byDifficulty[$d].count++
    switch ($evt.outcome) {
        "PASS" { $byDifficulty[$d].pass++ }
        "FAIL" { $byDifficulty[$d].fail++ }
        default { $byDifficulty[$d].pending++ }
    }
    $m = "$($evt.model_used) [$($evt.recommendation)]"
    if (-not $modelsByDifficulty.ContainsKey($d)) { $modelsByDifficulty[$d] = @{} }
    if (-not $modelsByDifficulty[$d].ContainsKey($m)) { $modelsByDifficulty[$d][$m] = @{ count = 0; pass = 0; fail = 0 } }
    $modelsByDifficulty[$d][$m].count++
    if ($evt.outcome -eq "PASS") { $modelsByDifficulty[$d][$m].pass++ }
    elseif ($evt.outcome -eq "FAIL") { $modelsByDifficulty[$d][$m].fail++ }
}

# --- Success rate por modelo (global) ---
$byModel = @{}
foreach ($evt in $events) {
    $m = "$($evt.model_used) [$($evt.recommendation)]"
    if (-not $byModel.ContainsKey($m)) { $byModel[$m] = @{ count = 0; pass = 0; fail = 0; pending = 0; difficulty = @{} } }
    $byModel[$m].count++
    if ($evt.outcome -eq "PASS") { $byModel[$m].pass++ }
    elseif ($evt.outcome -eq "FAIL") { $byModel[$m].fail++ }
    else { $byModel[$m].pending++ }
    $d = [int]$evt.difficulty
    if (-not $byModel[$m].difficulty.ContainsKey($d)) { $byModel[$m].difficulty[$d] = 0 }
    $byModel[$m].difficulty[$d]++
}

function Rate($pass, $total) {
    if ($total -le 0) { return 0 }
    return [math]::Round(($pass / $total) * 100, 0)
}

# --- Salida ---
if ($Json) {
    $out = @{
        total = $total
        by_difficulty = $byDifficulty
        by_model = @($byModel.GetEnumerator() | ForEach-Object {
            @{ model = $_.Key; count = $_.Value.count; pass = $_.Value.pass; fail = $_.Value.fail; pending = $_.Value.pending; success_pct = (Rate $_.Value.pass $_.Value.count); difficulties = $_.Value.difficulty }
        })
    }
    $out | ConvertTo-Json -Depth 6
    exit 0
}

# Consola UTF-8 antes del primer Write-Host
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

Write-Host ""
Write-Host "  TRIAGE STATS - Prompt Triage (difficulty -> modelo -> outcome)" -ForegroundColor Cyan
Write-Host "  ==============================================================" -ForegroundColor Cyan
Write-Host ("  Eventos: {0}  |  PASS {1}  FAIL {2}  PENDING {3}" -f $total,
    @($events | Where-Object { $_.outcome -eq "PASS" }).Count,
    @($events | Where-Object { $_.outcome -eq "FAIL" }).Count,
    @($events | Where-Object { $_.outcome -ne "PASS" -and $_.outcome -ne "FAIL" }).Count) -ForegroundColor White
Write-Host ""

Write-Host "  Por dificultad:" -ForegroundColor Yellow
foreach ($d in (1..4)) {
    $row = $byDifficulty[$d]
    if (-not $row -or $row.count -eq 0) { continue }
    $closed = $row.pass + $row.fail
    $sr = Rate $row.pass $closed
    $color = if ($sr -ge 80) { "Green" } elseif ($sr -ge 50) { "Yellow" } else { "Red" }
    $pend = if ($row.pending -gt 0) { "  (pendientes: $($row.pending))" } else { "" }
    Write-Host ("    D{0}: {1,-4} quests | success {2,3}% ({3}P/{4}F){5}" -f $d, $row.count, $sr, $row.pass, $row.fail, $pend) -ForegroundColor $color
    # Modelo mas usado en esta dificultad
    $topModel = ($modelsByDifficulty[$d].GetEnumerator() | Sort-Object { $_.Value.count } -Descending | Select-Object -First 1)
    if ($topModel) {
        $mRow = $topModel.Value
        $mClosed = $mRow.pass + $mRow.fail
        $mSr = Rate $mRow.pass $mClosed
        Write-Host ("        top modelo: {0,-38} ({1} usos, success {2}%)" -f $topModel.Key, $mRow.count, $mSr) -ForegroundColor DarkGray
    }
}
Write-Host ""

Write-Host "  Por modelo recomendado:" -ForegroundColor Yellow
$pendingTotal = @($events | Where-Object { $_.outcome -ne "PASS" -and $_.outcome -ne "FAIL" }).Count
if ($pendingTotal -gt 0) {
    Write-Host ("    [!] {0} eventos sin cerrar (outcome PENDING) - el ciclo de memoria los cierra en quest-done." -f $pendingTotal) -ForegroundColor DarkGray
}
$byModel.GetEnumerator() | Sort-Object { $_.Value.count } -Descending | ForEach-Object {
    $row = $_.Value
    $closed = $row.pass + $row.fail
    $sr = Rate $row.pass $closed
    $color = if ($sr -ge 80) { "Green" } elseif ($sr -ge 50) { "Yellow" } else { "Red" }
    $dList = ($row.difficulty.GetEnumerator() | Sort-Object Key | ForEach-Object { "D$($_.Key)x$($_.Value)" }) -join " "
    Write-Host ("    {0,-40} {1,4} usos | success {2,3}% ({3}P/{4}F) | {5}" -f $_.Key, $row.count, $sr, $row.pass, $row.fail, $dList) -ForegroundColor $color
}
Write-Host ""

# Mejor config por data disponible (>=3 eventos cerrados)
$best = $byModel.GetEnumerator() | ForEach-Object {
    $row = $_.Value
    $closed = $row.pass + $row.fail
    [PSCustomObject]@{ model = $_.Key; count = $_.Value.count; closed = $closed; pass = $row.pass; success_pct = (Rate $row.pass $closed) }
} | Where-Object { $_.closed -ge 3 } | Sort-Object success_pct -Descending | Select-Object -First 1
if ($best) {
    Write-Host ("  Mejor config (>=3 quests cerrados): {0} -> {1}% success" -f $best.model, $best.success_pct) -ForegroundColor Green
    Write-Host ""
}
