# atlas-orchestrator.ps1 - B5 Wired orchestration using all harness scripts
# =============================================
# Glues together: quest-detector -> model-router -> loop-engine -> circuit-breaker
# Demonstrates the full harness flow.
#
# Usage:
#   .\atlas-orchestrator.ps1 -Quest "crea login form con Zod"
#   .\atlas-orchestrator.ps1 -Quest "..." -Platform codex -Tier plus -AutoExecute
#   .\atlas-orchestrator.ps1 -Status              # show all states

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Quest = "",
    [string]$Platform = "opencode",
    [string]$Tier = "pro",
    [switch]$AutoExecute,
    [switch]$Status,
    [switch]$Json,
    [ValidateSet("always","auto","off")]
    [string]$Gate = "auto",
    [string]$ArnesDir = "",
    [switch]$NoAutoLoop,
    [int]$MaxChainSteps = 5
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

$ScriptDir = $PSScriptRoot
$QD = Join-Path $ScriptDir "quest-detector.ps1"
$MR = Join-Path $ScriptDir "model-router.ps1"
$LE = Join-Path $ScriptDir "loop-engine.ps1"
$CB = Join-Path $ScriptDir "circuit-breaker.ps1"
$PE = Join-Path $ScriptDir "platform-exec.ps1"
$AE = Join-Path $ScriptDir "audit-exec.ps1"
$CE = Join-Path $ScriptDir "counsel-exec.ps1"

# === Status mode ===
if ($Status) {
    Write-Host ""
    Write-Host "  ATLAS HARNESS - FULL STATUS" -ForegroundColor Cyan
    Write-Host "  ===========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  -- Loop Engine --" -ForegroundColor Yellow
    if (Test-Path $LE) { & $LE -Action state }
    Write-Host "  -- Circuit Breaker --" -ForegroundColor Yellow
    if (Test-Path $CB) { & $CB -Action status }
    Write-Host "  -- Model Assignments --" -ForegroundColor Yellow
    $maFile = Join-Path $ArnesDir "model-assignments.json"
    if (Test-Path $maFile) {
        Get-Content -LiteralPath $maFile -Raw | ConvertFrom-Json | Format-List
    } else {
        Write-Host "  (no assignments yet)" -ForegroundColor DarkGray
    }
    Write-Host ""
    exit 0
}

# Encoding-robust: PS 5.1 cachea el encoding del host en el PRIMER Write-Host;
# setear [Console]::OutputEncoding despues no tiene efecto. Forzamos consola
# UTF-8 ANTES de cualquier output humano para que la caja de recomendacion
# (box-drawing, acentos) renderice limpia. En -Json no hay Write-Host: intacto.
$prevConsoleEncoding = $null
if (-not $Json) {
    try {
        $prevConsoleEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    } catch {}
}

# === Quest Gate resolution (CLI -Gate > preferences.json quest_gate > default auto) ===
$resolvedGate = "auto"
$prefsFile = Join-Path $ArnesDir "preferences.json"
if ($PSBoundParameters.ContainsKey("Gate")) {
    $resolvedGate = $Gate
} elseif (Test-Path $prefsFile) {
    try {
        $prefs = Get-Content -LiteralPath $prefsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($prefs.quest_gate -and ($prefs.quest_gate -in @("always","auto","off"))) {
            $resolvedGate = [string]$prefs.quest_gate
        }
    } catch {}
}

# === Quest mode ===
if (-not $Quest) {
    Write-Error "Quest required (or use -Status)"
    exit 1
}

# Step 1: Detect quest type
if (-not $Json) {
    Write-Host ""
    Write-Host "  Step 1: Quest Detection" -ForegroundColor Cyan
}
$qdOutput = & $QD -Prompt $Quest -Json -Recommend 2>&1
$questInfo = $qdOutput | ConvertFrom-Json
if (-not $Json) {
    Write-Host "  Type:     $($questInfo.quest_type)" -ForegroundColor White
    Write-Host "  Party:    $($questInfo.suggested_party -join ', ')" -ForegroundColor White
    Write-Host "  L0:       $($questInfo.is_l0)" -ForegroundColor $(if ($questInfo.is_l0) { "Red" } else { "White" })
    Write-Host ""
}

# === Quest Recommendation Gate ===
$gateCancelled = $false

if ($resolvedGate -ne "off" -and -not $Json) {
    $rec = $questInfo.recommendation
    Write-Host ("╔" + ("═" * 43) + "╗") -ForegroundColor Cyan
    Write-Host ("║ {0,-41} ║" -f "[ATLAS] RECOMENDACIÓN DE QUEST") -ForegroundColor Yellow
    if ($rec) {
        Write-Host ("║ {0,-41} ║" -f (" Tipo: $($questInfo.quest_type) ($($questInfo.confidence) keywords)")) -ForegroundColor White
        $shortParty = ($questInfo.suggested_party -join " + ")
        if ($shortParty.Length -gt 41) { $shortParty = $shortParty.Substring(0, 38) + "..." }
        Write-Host ("║ {0,-41} ║" -f (" Party sugerido: $shortParty")) -ForegroundColor Yellow
        $mpK = [int][math]::Round($questInfo.estimated_mp / 1000)
        $costTxt = " Costo est.: $mpK" + "K tokens · ~$" + ("{0:N2}" -f $rec.estimated_cost_usd)
        Write-Host ("║ {0,-41} ║" -f $costTxt) -ForegroundColor Yellow
        $l0Txt = "no"; if ($questInfo.is_l0) { $l0Txt = "sí" }
        Write-Host ("║ {0,-41} ║" -f (" Complejidad: $($questInfo.complexity) · L0: $l0Txt · Gate: $($rec.gate)")) -ForegroundColor White
    } else {
        Write-Host ("║ {0,-41} ║" -f " (sin recommendation - detector sin -Recommend)") -ForegroundColor DarkGray
    }
    Write-Host ("║ {0,-41} ║" -f " → ¿Ejecutar? (sí / ajustar / no)") -ForegroundColor Yellow
    Write-Host ("╚" + ("═" * 43) + "╝") -ForegroundColor Cyan
    Write-Host ""
}

# -Json mode: no prompt; emit recommendation JSON and exit (callers decide).
# Aplica SIEMPRE con -Json (incluyendo -Gate off): nunca cae a model routing/loop.
if ($Json) {
    $jsonGateResult = @{
        quest_info = $questInfo
        gate = $resolvedGate
        recommendation = $questInfo.recommendation
        timestamp = (Get-Date).ToString("o")
    }
    $jsonGateResult | ConvertTo-Json -Depth 6
    exit 0
}

# Gate decision: prompt or auto-proceed
$shouldPrompt = $false
if ($resolvedGate -eq "always") {
    $shouldPrompt = $true
} elseif ($resolvedGate -eq "auto") {
    if ($questInfo.recommendation -and $questInfo.recommendation.gate -eq "required") {
        $shouldPrompt = $true
    } else {
        Write-Host "  → Ejecutando (modo auto)" -ForegroundColor DarkGray
    }
}

if ($shouldPrompt) {
    if ($AutoExecute) {
        Write-Host "  [GATE] -AutoExecute activo: sin prompt, se procede." -ForegroundColor DarkGray
    } else {
        $answer = Read-Host "  ¿Ejecutar? (sí / ajustar / no)"
        if ($answer -match '^(s[ií]?|yes|y)$') {
            Write-Host "  [GATE] Quest aprobada. Procediendo." -ForegroundColor Green
        } elseif ($answer -match '^(a|ajustar|adjust)$') {
            Write-Host "  [GATE] Quest marcada para ajuste. Ajusta el prompt y reintenta." -ForegroundColor Yellow
            $gateCancelled = $true
        } else {
            Write-Host "  [GATE] Quest cancelada por el usuario. Nada se ejecutó." -ForegroundColor Yellow
            $gateCancelled = $true
        }
    }
}

if ($gateCancelled) {
    exit 0
}

# Legacy L0 pause (solo con gate off; en always/auto el gate ya lo maneja)
if ($resolvedGate -eq "off" -and $questInfo.is_l0 -and -not $AutoExecute) {
    Write-Host "  [L0 PAUSE] This is an L0 quest. User confirmation required." -ForegroundColor Red
    Write-Host "  Re-run with -AutoExecute to proceed." -ForegroundColor DarkGray
    exit 0
}

# Step 1.5: Repo profile integration
$repoProfileFile = Join-Path $ArnesDir "repo-profile.json"
$repoTier = "medium"
$repoPartySize = 3
$repoModelTier = $Tier
if (Test-Path $repoProfileFile) {
    try {
        $rp = Get-Content -LiteralPath $repoProfileFile -Raw | ConvertFrom-Json
        if ($rp.repo_tier) {
            $repoTier = $rp.repo_tier
            Write-Host "  Step 1.5: Repo Profile (tier=$repoTier)" -ForegroundColor Cyan
            switch ($repoTier) {
                "lean"    { $repoPartySize = 2; $repoModelTier = "free" }
                "medium"  { $repoPartySize = 3; $repoModelTier = "balance" }
                "standard"{ $repoPartySize = 5; $repoModelTier = "pro" }
                "boss"    { $repoPartySize = 6; $repoModelTier = "highest" }
            }
            Write-Host "  Repo tier: $repoTier -> party_size=$repoPartySize, model_tier=$repoModelTier" -ForegroundColor DarkGray
            # Override tier del CLI si repo tier dice algo distinto
            if ($Tier -eq "pro" -and $repoModelTier -ne "balance") {
                Write-Host "  [ADJUST] CLI Tier=pro pero repo sugiere $repoModelTier" -ForegroundColor Yellow
            }
        }
    } catch {}
}

# Step 2: Route models
Write-Host "  Step 2: Model Routing" -ForegroundColor Cyan
$questTypeLower = $questInfo.quest_type.ToLower()
if ($questInfo.complexity -eq "boss") {
    $routeType = "boss"
} elseif ($questInfo.complexity -eq "trivial") {
    $routeType = "trivial"
} else {
    $routeType = $questTypeLower
}
& $MR -Platform $Platform -Tier $Tier -QuestType $routeType -ArnesDir $ArnesDir | Out-Null
Write-Host ""

# Step 3: Start loop
Write-Host "  Step 3: Loop Engine" -ForegroundColor Cyan

# Build start args
$startArgs = @("-Action", "start", "-Quest", $Quest)

# Si quest-detector devolvio sub_quests, iniciar chain
if ($questInfo.has_chain -and $questInfo.sub_quest_count -gt 1) {
    Write-Host "  [CHAIN] Quest detector dividio en $($questInfo.sub_quest_count) sub-quests" -ForegroundColor Cyan
    Write-Host "          Auto-chain activado (max $MaxChainSteps pasos)" -ForegroundColor DarkGray
    # PS5.1 no soporta splat de arrays via param, usar --Chain con comma-separated
    # loop-engine tiene -Chain [string[]] asi que lo pasamos como array via invocation
    & $LE -Action start -Quest $Quest -Chain $questInfo.sub_quests -ArnesDir $ArnesDir 2>&1 | Out-Null
} else {
    & $LE -Action start -Quest $Quest -ArnesDir $ArnesDir 2>&1 | Out-Null
}
Write-Host ""

$loopStateFile = Join-Path $ArnesDir "loop-state.json"
$currentQuestId = ""
$currentAttemptId = ""
if (Test-Path $loopStateFile) {
    try { $loopState = Get-Content -LiteralPath $loopStateFile -Raw -Encoding UTF8 | ConvertFrom-Json; $currentQuestId = $loopState.current_quest_id; $currentAttemptId = $loopState.current_attempt_id } catch {}
}
if (-not $currentQuestId -or -not $currentAttemptId) {
    Write-Error "Loop did not provide a quest id; platform execution cannot create an evidence pack."
    exit 1
}

# Step 4: Check agents in party
Write-Host "  Step 4: Circuit Breaker Check (party members)" -ForegroundColor Cyan
$blockedAgents = @()
foreach ($agent in $questInfo.suggested_party) {
    $checkOutput = & $CB -Action check -Agent $agent -ArnesDir $ArnesDir 2>&1
    if ($LASTEXITCODE -eq 1) {
        $blockedAgents += $agent
        Write-Host "    [BLOCKED] $agent - blocked" -ForegroundColor Red
    } else {
        Write-Host "    [OK] $agent - active" -ForegroundColor Green
    }
}
Write-Host ""

if ($blockedAgents.Count -gt 0) {
    Write-Host "  [WARN] $($blockedAgents.Count) agent(s) blocked: $($blockedAgents -join ', ')" -ForegroundColor Yellow
}

# Step 5: Real execution OR simulate
if ($AutoExecute) {
    Write-Host "  Step 5: Auto-Execute" -ForegroundColor Cyan

    # Detect platform CLI availability
    $platformCmd = switch ($Platform) {
        "opencode" { "opencode" }
        "codex"    { "codex" }
        "claude"   { "claude" }
    }
    $hasCli = [bool](Get-Command $platformCmd -ErrorAction SilentlyContinue)

    if ($hasCli -and (Test-Path $PE)) {
        Write-Host "  [REAL] Llamando $platformCmd CLI..." -ForegroundColor Green
        Write-Host ""
        & $PE -Platform $Platform -Prompt $Quest -Agent atlas-player -QuestId $currentQuestId -AttemptId $currentAttemptId -ArnesDir $ArnesDir
        if ($LASTEXITCODE -eq 0) {
            & $AE -Platform $Platform -QuestId $currentQuestId -AttemptId $currentAttemptId -ArnesDir $ArnesDir
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  [PAUSE] Tywin no entrego un audit bundle valido; quest queda abierto." -ForegroundColor Red
            } else {
                & $CE -Platform $Platform -QuestId $currentQuestId -AttemptId $currentAttemptId -ArnesDir $ArnesDir
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  [PAUSE] Sam no entrego consejo valido; Atlas no puede decidir." -ForegroundColor Red
                } else {
                    $runDir = Join-Path $ArnesDir (Join-Path (Join-Path "runs" $currentQuestId) $currentAttemptId)
                    Write-Host "  [ATLAS] Revisa sam-counsel.json y registra decision explicita:" -ForegroundColor Yellow
                    Write-Host "    pwsh cli/decision-record.ps1 -QuestId $currentQuestId -AttemptId $currentAttemptId -Decision <finalize|retry|pause|escalate> -Rationale '<motivo>'" -ForegroundColor DarkGray
                    Write-Host "  Despues cierra con loop-engine usando evidence.json, verdict.json, sam-counsel.json y atlas-decision.json de $runDir" -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "  [PAUSE] Party execution failed; no se invoca a Tywin." -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "  [OK] Real execution complete. Check output above." -ForegroundColor Green
        Write-Host "  Despues registra el resultado:" -ForegroundColor DarkGray
        Write-Host "    pwsh cli/loop-engine.ps1 -Action quest-done -Verdict PASS -AgentUsed vivi -TokensUsed 4500 -EvidencePackPath .arnes\\runs\\Q-001\\evidence.json -AuditVerdictPath .arnes\\runs\\Q-001\\verdict.json" -ForegroundColor Yellow
    } else {
        Write-Host "  [SIMULATED] CLI '$platformCmd' no en PATH. Simulando..." -ForegroundColor Yellow
        Write-Host "  [TURN 1] Party activo. HP depletes..." -ForegroundColor White
        & $LE -Action tick -ArnesDir $ArnesDir
        Write-Host "  [TURN 2] Skill casts..." -ForegroundColor White
        & $LE -Action tick -ArnesDir $ArnesDir
        Write-Host "  [TURN 3] Verify..." -ForegroundColor White
        & $LE -Action tick -ArnesDir $ArnesDir
        Write-Host ""
        Write-Host "  Para ejecucion real: instala OpenCode (opencode.dev) o usa Codex/Claude." -ForegroundColor DarkGray
    }
} else {
    Write-Host "  Step 5: Manual execution required" -ForegroundColor Cyan
    Write-Host "  Para ejecutar el quest: abre OpenCode y usa @atlas-player con el prompt." -ForegroundColor DarkGray
    Write-Host "  O con -AutoExecute y platform CLI instalado: ejecuta real." -ForegroundColor DarkGray
    Write-Host "  Despues de completar el quest:" -ForegroundColor DarkGray
    Write-Host "    pwsh cli/loop-engine.ps1 -Action quest-done -Verdict PASS -AgentUsed vivi -TokensUsed 4500 -EvidencePackPath .arnes\\runs\\Q-001\\evidence.json -AuditVerdictPath .arnes\\runs\\Q-001\\verdict.json" -ForegroundColor Yellow
}
Write-Host ""
