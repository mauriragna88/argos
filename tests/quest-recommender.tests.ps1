# ============================================================
# ARNES - verificacion del Quest Recommender Gate
#
# Verifica:
#   1. quest-detector -Recommend -Json emite objeto recommendation con gate
#   2. Quest L0 ("drop table users production") -> gate == required
#   3. Quest trivial ("haz un fix de typo") -> gate == auto_pass
#   4. preferences.json tiene quest_gate tras la actualizacion
#   5. atlas-orchestrator -Gate always: con "no" cancela (no llega a Step 2),
#      con "si" procede pasando Step 1
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/quest-recommender.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$QD = Join-Path $Root 'cli\quest-detector.ps1'
$AO = Join-Path $Root 'cli\atlas-orchestrator.ps1'
$Prefs = Join-Path $Root '.arnes\preferences.json'
$work = Join-Path $Root ('.quest-gate-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

$PSChild = 'powershell -NoProfile -ExecutionPolicy Bypass'

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

try {
    # 1. quest-detector -Recommend -Json emite recommendation con gate
    $json1 = (& powershell -NoProfile -ExecutionPolicy Bypass -File $QD -Prompt "crea login form con Zod" -Json -Recommend | Out-String)
    $r1 = $json1 | ConvertFrom-Json
    Assert-That ($null -ne $r1.recommendation) 'recommendation object present'
    Assert-That ($null -ne $r1.recommendation.gate) 'gate field present'
    Assert-That ($null -ne $r1.recommendation.risk) 'risk field present'
    Assert-That ($null -ne $r1.recommendation.party_label) 'party_label present'
    Assert-That ($null -ne $r1.recommendation.estimated_cost_usd) 'estimated_cost_usd present'
    Assert-That ($null -ne $r1.recommendation.title) 'title present'

    # 2. Quest L0 -> gate == required (y risk == L0)
    $json2 = (& powershell -NoProfile -ExecutionPolicy Bypass -File $QD -Prompt "drop table users production" -Json -Recommend | Out-String)
    $r2 = $json2 | ConvertFrom-Json
    Assert-That ($r2.is_l0) 'L0 flag true'
    Assert-That ([string]$r2.recommendation.gate -eq 'required') "L0 gate == required (obtenido $($r2.recommendation.gate))"
    Assert-That ([string]$r2.recommendation.risk -eq 'L0') "L0 risk == L0 (obtenido $($r2.recommendation.risk))"

    # 3. Quest trivial -> gate == auto_pass
    $json3 = (& powershell -NoProfile -ExecutionPolicy Bypass -File $QD -Prompt "haz un fix de typo" -Json -Recommend | Out-String)
    $r3 = $json3 | ConvertFrom-Json
    Assert-That ([string]$r3.recommendation.gate -eq 'auto_pass') "trivial gate == auto_pass (obtenido $($r3.recommendation.gate))"

    # 4. preferences.json tiene quest_gate tras la actualizacion
    Assert-That (Test-Path -LiteralPath $Prefs) 'preferences.json existe'
    $prefs = Get-Content -LiteralPath $Prefs -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-That ([string]$prefs.quest_gate -eq 'auto') "preferences quest_gate == auto (obtenido $($prefs.quest_gate))"

    # 5a. atlas-orchestrator -Gate always + "no" -> cancela, NO llega a Step 2
    $noOut = ('no' | powershell -NoProfile -ExecutionPolicy Bypass -File $AO -Gate always -Quest "drop table users production" -ArnesDir $work 2>&1 | Out-String)
    Assert-That ($noOut -match 'cancel') "gate con 'no' cancela -> $noOut"
    Assert-That ($noOut -notmatch 'Step 2') 'gate con "no" no ejecuta (no llega a Step 2)'

    # 5b. atlas-orchestrator -Gate always + "si" -> procede pasando Step 1
    $yesOut = ('si' | powershell -NoProfile -ExecutionPolicy Bypass -File $AO -Gate always -Quest "crea login form" -ArnesDir $work 2>&1 | Out-String)
    Assert-That ($yesOut -match 'Step 2') "gate con 'si' procede pasado Step 1 -> $yesOut"

    # 6. atlas-orchestrator -Json -Gate off -> emite recommendation JSON y sale (sin Step 2)
    $jsonGateOff = (& powershell -NoProfile -ExecutionPolicy Bypass -File $AO -Json -Gate off -Quest "crea login form con Zod" -ArnesDir $work | Out-String)
    $g = $jsonGateOff | ConvertFrom-Json
    Assert-That ($null -ne $g.recommendation) 'json+gate off emite recommendation'
    Assert-That ($null -ne $g.gate) 'json+gate off incluye gate'
    Assert-That ($jsonGateOff -notmatch 'Step 2') 'json+gate off sale sin ejecutar (sin Step 2)'

    Write-Output 'PASS quest-recommender: detector recommendation + gate + prefs + orchestrator gate + json gate off'
    exit 0
} finally {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
