# loop-contract.ps1 - FASE 3: LOOP CONTRACT por quest
# ====================================================
# Cada quest lleva un contrato explicito: goal, acceptance criteria,
# verificacion, limites (max_iterations, token_budget, cost_budget),
# retry_policy y stop_conditions. Se persiste en .arnes/loop-contracts/Q-XXX.json
# y se consulta al inicio del quest para que el party sepa CUANDO parar.
#
# Acciones:
#   create   -> crear/actualizar el contrato de un quest
#   get      -> consultar el contrato de un quest (o del quest activo)
#   list     -> listar contratos existentes
#   check    -> validar que el quest sigue dentro del contrato (iterations/tokens)
#
# Uso:
#   .\cli\loop-contract.ps1 -Action create -QuestId Q-001 -Prompt "crea login"
#   .\cli\loop-contract.ps1 -Action create -QuestId Q-001 -MaxIterations 3 -TokenBudget 8000
#   .\cli\loop-contract.ps1 -Action get -QuestId Q-001
#   .\cli\loop-contract.ps1 -Action list
#   .\cli\loop-contract.ps1 -Action check -QuestId Q-001 -Attempt 2 -TokensUsed 6000

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("create","get","list","check")]
    [string]$Action = "get",
    [string]$QuestId = "",
    [string]$Prompt = "",
    [int]$MaxIterations = 3,
    [int]$TokenBudget = 0,
    [int]$Attempt = 0,
    [int]$TokensUsed = 0,
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

$contractsDir = Join-Path $ArnesDir "loop-contracts"
if (-not (Test-Path $contractsDir)) { New-Item -ItemType Directory -Path $contractsDir -Force | Out-Null }

function Get-ContractFile([string]$qid) {
    return Join-Path $contractsDir ("{0}.json" -f $qid)
}

# === CREATE ===
if ($Action -eq "create") {
    if (-not $QuestId) {
        # intentar leer del loop-state activo
        try {
            $ls = Get-Content (Join-Path $ArnesDir "loop-state.json") -Raw -Encoding UTF8 | ConvertFrom-Json
            $QuestId = $ls.current_quest_id
        } catch {}
    }
    if (-not $QuestId) { Write-Error "create requiere -QuestId"; exit 1 }

    # auto-detectar token budget por dificultad si no viene
    if ($TokenBudget -eq 0) {
        # estimar: leer triage-log del quest si existe, sino default 8000
        $TokenBudget = 8000
    }

    # auto-detectar acceptance por tipo (heuristica basica; Atlas enriquece)
    $acceptance = @("el output cumple el prompt original")
    $verification = @("typecheck", "tests", "build")
    if ($Prompt) {
        $lower = $Prompt.ToLower()
        if ($lower -match "frontend|component|ui|modal|form|dashboard|login") {
            $acceptance = @("componente renderiza", "tipos TS estrictos (sin any)", "tests de UI pasan")
            $verification = @("tsc --noEmit", "tests UI")
        } elseif ($lower -match "api|endpoint|supabase|schema|rls|backend") {
            $acceptance = @("endpoint/query funciona", "input validado (zod)", "RLS aplicado si aplica")
            $verification = @("tsc --noEmit", "tests backend", "RLS check")
        } elseif ($lower -match "bug|fix|error|crash|broken") {
            $acceptance = @("el bug ya no se reproduce", "test que captura el bug", "sin regresiones")
            $verification = @("test del bug pasa", "suite completa")
        } elseif ($lower -match "deploy|production|prod|migracion|rollback|rls") {
            $acceptance = @("plan de rollback documentado", "secrets sin exponer", "migracion reversible")
            $verification = @("security scan", "rollback plan", "L0 approval")
        }
    }

    $contract = [ordered]@{
        type = "loop_contract"
        quest_id = $QuestId
        prompt = $Prompt
        goal = $Prompt
        acceptance_criteria = $acceptance
        verification = $verification
        max_iterations = $MaxIterations
        token_budget = $TokenBudget
        retry_policy = @{ max_retries = ($MaxIterations - 1); change_one_variable = $true }
        stop_conditions = @(
            "verdict PASS",
            "max_iterations excedido ($MaxIterations)",
            "token_budget excedido ($TokenBudget)",
            "atlas_decision pause/escalate"
        )
        created_at = (Get-Date).ToString("o")
        updated_at = (Get-Date).ToString("o")
    }

    $file = Get-ContractFile $QuestId
    $contract | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $file -Encoding UTF8

    if ($Json) {
        $contract | ConvertTo-Json -Depth 5
    } else {
        Write-Host ("  [CONTRACT] {0} creado: goal='{1}' | max_iter={2} | token_budget={3}" -f $QuestId, $Prompt.Substring(0, [Math]::Min(40, $Prompt.Length)), $MaxIterations, $TokenBudget) -ForegroundColor Green
        Write-Host ("            acceptance: {0}" -f ($acceptance -join " | ")) -ForegroundColor DarkGray
    }
    exit 0
}

# === GET ===
if ($Action -eq "get") {
    if (-not $QuestId) {
        try {
            $ls = Get-Content (Join-Path $ArnesDir "loop-state.json") -Raw -Encoding UTF8 | ConvertFrom-Json
            $QuestId = $ls.current_quest_id
        } catch {}
    }
    if (-not $QuestId) { Write-Error "get requiere -QuestId (o quest activo)"; exit 1 }
    $file = Get-ContractFile $QuestId
    if (-not (Test-Path $file)) {
        if ($Json) { @{ quest_id = $QuestId; exists = $false } | ConvertTo-Json; exit 0 }
        Write-Host ("  [CONTRACT] {0}: no existe. Crea con -Action create." -f $QuestId) -ForegroundColor Yellow
        exit 0
    }
    $c = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($Json) {
        $c | ConvertTo-Json -Depth 5
    } else {
        Write-Host ""
        Write-Host ("  LOOP CONTRACT {0}" -f $QuestId) -ForegroundColor Cyan
        Write-Host "  =====================" -ForegroundColor Cyan
        Write-Host ("  Goal: {0}" -f $c.goal) -ForegroundColor White
        Write-Host ("  Acceptance: {0}" -f ($c.acceptance_criteria -join " | ")) -ForegroundColor White
        Write-Host ("  Verify: {0}" -f ($c.verification -join " | ")) -ForegroundColor White
        Write-Host ("  Max iterations: {0} | Token budget: {1:N0}" -f $c.max_iterations, $c.token_budget) -ForegroundColor Yellow
        Write-Host ("  Stop: {0}" -f ($c.stop_conditions -join " | ")) -ForegroundColor DarkGray
        Write-Host ""
    }
    exit 0
}

# === LIST ===
if ($Action -eq "list") {
    $files = @(Get-ChildItem -Path $contractsDir -Filter "*.json" -ErrorAction SilentlyContinue)
    if ($Json) {
        @($files | ForEach-Object { @{ quest_id = $_.BaseName; file = $_.FullName } }) | ConvertTo-Json -Depth 3
        exit 0
    }
    if ($files.Count -eq 0) {
        Write-Host "  [CONTRACT] Ningun contrato creado aun." -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""
    Write-Host "  LOOP CONTRACTS" -ForegroundColor Cyan
    Write-Host "  ==============" -ForegroundColor Cyan
    foreach ($f in $files) {
        try {
            $c = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            Write-Host ("  {0} | max_iter={1} | budget={2:N0} | {3}" -f $f.BaseName, $c.max_iterations, $c.token_budget, $c.prompt.Substring(0, [Math]::Min(40, "$($c.prompt)".Length))) -ForegroundColor White
        } catch {}
    }
    Write-Host ""
    exit 0
}

# === CHECK ===
if ($Action -eq "check") {
    if (-not $QuestId) {
        try {
            $ls = Get-Content (Join-Path $ArnesDir "loop-state.json") -Raw -Encoding UTF8 | ConvertFrom-Json
            $QuestId = $ls.current_quest_id
            if (-not $Attempt) { $Attempt = [int]$ls.attempt_count }
        } catch {}
    }
    if (-not $QuestId) { Write-Error "check requiere -QuestId"; exit 1 }
    $file = Get-ContractFile $QuestId
    $result = [ordered]@{ quest_id = $QuestId; contract_exists = $false; within_limits = $true; issues = @() }
    if (Test-Path $file) {
        $c = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
        $result.contract_exists = $true
        if ($Attempt -gt [int]$c.max_iterations) {
            $result.within_limits = $false
            $result.issues += "max_iterations excedido: intento $Attempt > $($c.max_iterations)"
        }
        if ($TokensUsed -gt [int]$c.token_budget) {
            $result.within_limits = $false
            $result.issues += "token_budget excedido: $TokensUsed > $($c.token_budget)"
        }
        $result.max_iterations = [int]$c.max_iterations
        $result.token_budget = [int]$c.token_budget
    } else {
        $result.issues += "contrato no existe (crear con -Action create)"
    }
    if ($Json) {
        $result | ConvertTo-Json -Depth 4
    } else {
        $color = if ($result.within_limits) { "Green" } else { "Red" }
        Write-Host ("  [CONTRACT] {0}: {1}" -f $QuestId, $(if ($result.within_limits) { "dentro de limites" } else { "FUERA DE LIMITES" })) -ForegroundColor $color
        foreach ($i in $result.issues) { Write-Host ("            - {0}" -f $i) -ForegroundColor Yellow }
    }
    exit 0
}
