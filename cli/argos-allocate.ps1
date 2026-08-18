# argos-allocate.ps1 - BRAN ALLOCATE (TURN 0.5 con datos reales)
# =================================================================
# Bran decide CUANTOS agentes, QUE modelos y CON QUE presupuesto para un quest.
# Ahora alimentado con DATOS REALES (no heuristica pura):
#   - quest-detector: quest_type, difficulty, party base, L0
#   - model-telemetry: success_rate real por modelo x quest_type (model-runs.jsonl)
#   - quest-ledger: presupuesto semanal restante (weekly_tokens_remaining)
# Output: { party_size, members, model_tier, estimated_cost, budget_ok, best_model }
#
# Uso:
#   .\cli\argos-allocate.ps1 -Prompt "crea api con auth"
#   .\cli\argos-allocate.ps1 -Prompt "..." -Json
#   .\cli\argos-allocate.ps1 -Status

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Prompt = "",
    [switch]$Json,
    [switch]$Status,
    [string]$ArnesDir = ""
)

$ErrorActionPreference = "Continue"
$ScriptDir = $PSScriptRoot

if (-not $ArnesDir) {
    $cwd = (Get-Location).Path
    if (Test-Path (Join-Path $cwd ".arnes\config.json")) {
        $ArnesDir = Join-Path $cwd ".arnes"
    } else {
        $ArnesDir = ".arnes"
    }
}

$QD = Join-Path $ScriptDir "quest-detector.ps1"
$MT = Join-Path $ScriptDir "model-telemetry.ps1"

# === STATUS: presupuesto + telemetria resumida ===
if ($Status) {
    $ledgerFile = Join-Path $ArnesDir "quest-ledger.json"
    $budget = [ordered]@{ weekly_budget = 0; weekly_used = 0; weekly_remaining = 0; warn_pct = 80; critical_pct = 95; semaforo = "n/a" }
    if (Test-Path $ledgerFile) {
        try {
            $ledger = Get-Content -LiteralPath $ledgerFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $budget.weekly_budget = $ledger.limits.weekly_tokens_budget
            $budget.weekly_used = $ledger.limits.weekly_tokens_used
            $budget.weekly_remaining = $ledger.limits.weekly_tokens_remaining
            $budget.warn_pct = $ledger.limits.warn_threshold_pct
            $budget.critical_pct = $ledger.limits.critical_threshold_pct
            $pct = if ($budget.weekly_budget -gt 0) { [int]($budget.weekly_used / $budget.weekly_budget * 100) } else { 0 }
            $budget.semaforo = if ($pct -ge $budget.critical_pct) { "red" } elseif ($pct -ge $budget.warn_pct) { "yellow" } else { "green" }
        } catch {}
    }
    if ($Json) {
        $budget | ConvertTo-Json -Depth 4
        exit 0
    }
    Write-Host ""
    Write-Host "  BRAN ALLOCATE - estado" -ForegroundColor Cyan
    Write-Host "  ======================" -ForegroundColor Cyan
    Write-Host ("  Presupuesto semanal: {0:N0} tokens | usado: {1:N0} ({2}%) | restante: {3:N0}" -f $budget.weekly_budget, $budget.weekly_used, [int]($budget.weekly_used / [Math]::Max(1, $budget.weekly_budget) * 100), $budget.weekly_remaining) -ForegroundColor $(if ($budget.semaforo -eq "red") { "Red" } elseif ($budget.semaforo -eq "yellow") { "Yellow" } else { "Green" })
    Write-Host ""
    if (Test-Path $MT) {
        & $MT -Action stats -ArnesDir $ArnesDir 2>&1 | Select-Object -First 12
    }
    exit 0
}

# === ALLOCATE ===
if (-not $Prompt) { Write-Error "Allocate requiere -Prompt (o -Status)"; exit 1 }

# 1. Detectar quest
$qdOut = & $QD -Prompt $Prompt -Json -NoLog 2>$null
$quest = $qdOut | ConvertFrom-Json
$questType = $quest.quest_type
$difficulty = [int]$quest.difficulty
$baseParty = @($quest.suggested_party)
$isL0 = [bool]$quest.is_l0

# 2. Presupuesto (Quina): cuanto queda
$ledgerFile = Join-Path $ArnesDir "quest-ledger.json"
$weeklyRemaining = 0
$weeklyBudget = 0
if (Test-Path $ledgerFile) {
    try {
        $ledger = Get-Content -LiteralPath $ledgerFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $weeklyRemaining = [int]$ledger.limits.weekly_tokens_remaining
        $weeklyBudget = [int]$ledger.limits.weekly_tokens_budget
    } catch {}
}
$estimatedMP = [int]$quest.estimated_mp
$budgetOk = $weeklyRemaining -ge $estimatedMP

# 3. Telemetria: mejor modelo para este quest_type (success rate real)
$bestModel = ""
$bestModelTier = ""
$modelCount = 0
$modelPassPct = 0
if (Test-Path $MT) {
    try {
        $statsOut = & $MT -Action stats -Json -ArnesDir $ArnesDir 2>$null
        $stats = ($statsOut -join "`n").Trim() | ConvertFrom-Json
        if ($stats.by_model) {
            $candidates = @()
            foreach ($m in $stats.by_model) {
                # priorizar modelos con EVIDENCIA REAL en este quest_type (>=2 runs)
                if ($m.quest_types.PSObject.Properties[$questType] -and [int]$m.count -ge 2) {
                    $candidates += [PSCustomObject]@{
                        label = $m.model
                        count = [int]$m.count
                        pass = [int]$m.pass
                        pct = [double]$m.success_pct
                    }
                }
            }
            if ($candidates.Count -eq 0) {
                # sin evidencia suficiente de este tipo: el mejor global con >=3 runs
                $candidates = @($stats.by_model | Where-Object { [int]$_.count -ge 3 } | ForEach-Object {
                    [PSCustomObject]@{ label = $_.model; count = [int]$_.count; pass = [int]$_.pass; pct = [double]$_.success_pct }
                })
            }
            $best = $candidates | Sort-Object pct -Descending | Select-Object -First 1
            if ($best) {
                $bestModel = $best.label
                $modelCount = [int]$best.count
                $modelPassPct = [double]$best.pct
                if ($bestModel -match "\[pro\]") { $bestModelTier = "pro" }
                elseif ($bestModel -match "\[highest\]") { $bestModelTier = "highest" }
                else { $bestModelTier = "flash" }
            }
        }
    } catch {}
}

# 4. Model tier final = MAX(telemetria, minimo por dificultad)
# Regla del triage: L0/dificultad 3+ exigen minimo pro/highest; la telemetria
# INFORM la eleccion pero nunca baja el piso de seguridad del protocolo.
$minTier = "flash"
if ($difficulty -ge 4 -or $isL0) { $minTier = "highest" }
elseif ($difficulty -eq 3) { $minTier = "pro" }

if (-not $bestModelTier) {
    $bestModelTier = $minTier
} else {
    # escalar si el piso es mas alto que lo que sugiere la telemetria
    $tierRank = @{ flash = 1; pro = 2; highest = 3 }
    if ($tierRank[$bestModelTier] -lt $tierRank[$minTier]) {
        $bestModelTier = $minTier
    }
}

# 5. Party size segun dificultad + L0
$partySize = $baseParty.Count
if ($difficulty -ge 4) { $partySize = [Math]::Max($partySize, 4) }
elseif ($isL0) { $partySize = [Math]::Max($partySize, 3) }

$result = [ordered]@{
    quest_type = $questType
    difficulty = $difficulty
    is_l0 = $isL0
    party_size = $partySize
    members = $baseParty
    model_tier = $bestModelTier
    best_model = $bestModel
    best_model_runs = $modelCount
    best_model_success_pct = $modelPassPct
    estimated_cost = "$estimatedMP tokens (~$([math]::Round($estimatedMP * 0.0005, 2)) USD)"
    budget_remaining = $weeklyRemaining
    budget_ok = $budgetOk
    budget_note = if ($budgetOk) { "dentro de presupuesto" } else { "SUPERA el presupuesto semanal restante" }
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
    exit 0
}

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

Write-Host ""
Write-Host "  BRAN ALLOCATE - TURN 0.5 (con datos reales)" -ForegroundColor Cyan
Write-Host "  ===========================================" -ForegroundColor Cyan
Write-Host ("  Quest: {0} ({1}) | dificultad {2}/4 | L0: {3}" -f $questType, $Prompt.Substring(0, [Math]::Min(40, $Prompt.Length)), $difficulty, $isL0) -ForegroundColor White
Write-Host ("  Party: {0} ({1} miembros)" -f ($baseParty -join ", "), $partySize) -ForegroundColor Yellow
if ($bestModel) {
    Write-Host ("  Modelo: {0} (tier {1}, {2} runs reales, {3}% success en {4})" -f $bestModel, $bestModelTier, $modelCount, $modelPassPct, $questType) -ForegroundColor $(if ($modelPassPct -ge 80) { "Green" } else { "Yellow" })
} else {
    Write-Host ("  Modelo: tier {0} (sin datos de telemetria aun - fallback por dificultad)" -f $bestModelTier) -ForegroundColor DarkGray
}
Write-Host ("  Costo est.: {0}" -f $result.estimated_cost) -ForegroundColor White
$budgetColor = if ($budgetOk) { "Green" } else { "Red" }
Write-Host ("  Presupuesto: {0:N0} restantes | {1}" -f $weeklyRemaining, $result.budget_note) -ForegroundColor $budgetColor
Write-Host ""
