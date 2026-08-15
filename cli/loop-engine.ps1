# loop-engine.ps1 - B4 Atlas harness loop state machine
# =============================================
# Implements the loop engine state machine from core/loop-engine.agent.md:
#   IDLE -> QUESTING -> EVALUATING -> AUTO_NEXT / PAUSE_USER / CIRCUIT_BREAKER
#
# Usage:
#   .\loop-engine.ps1 -Action start -Quest "crea login"
#   .\loop-engine.ps1 -Action state
#   .\loop-engine.ps1 -Action tick
#   .\loop-engine.ps1 -Action quest-done -QuestId Q-001 -Verdict PASS -EvidencePackPath .arnes\runs\Q-001\evidence.json -AuditVerdictPath .arnes\runs\Q-001\verdict.json -SamCounselPath .arnes\runs\Q-001\sam-counsel.json -AtlasDecisionPath .arnes\runs\Q-001\atlas-decision.json
#   .\loop-engine.ps1 -Action quest-done -QuestId Q-002 -Verdict FAIL_PARTIAL -EvidencePackPath .arnes\runs\Q-002\evidence.json -AuditVerdictPath .arnes\runs\Q-002\verdict.json -RemediationBriefPath .arnes\runs\Q-002\remediation.json -SamCounselPath .arnes\runs\Q-002\sam-counsel.json -AtlasDecisionPath .arnes\runs\Q-002\atlas-decision.json

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("start","state","tick","quest-done","reset","pause","resume","toggle-auto")]
    [string]$Action = "state",

    [string]$Quest = "",
    [ValidatePattern("^$|^Q-\d{3,}$")]
    [string]$QuestId = "",
    [ValidateSet("PASS", "FAIL_PARTIAL", "FAIL_TOTAL")]
    [string]$Verdict = "PASS",
    [string]$AgentUsed = "",
    [int]$TokensUsed = 0,

    [string]$EvidencePackPath = "",
    [string]$AuditVerdictPath = "",
    [string]$RemediationBriefPath = "",
    [string]$SamCounselPath = "",
    [string]$AtlasDecisionPath = "",

    [string]$ArnesDir = "",

    [switch]$Json,

    [switch]$Force,

    [string[]]$Chain = @(),

    [switch]$ChainPop,
    [string]$NextQuest,
    [int]$MaxChainSteps = 5
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot 'osma-resolve.ps1')

if (-not $ArnesDir) {
    $cwd = (Get-Location).Path
    if (Test-Path (Join-Path $cwd ".arnes\config.json")) {
        $ArnesDir = Join-Path $cwd ".arnes"
    } else {
        $ArnesDir = ".arnes"
    }
}

$StateFile = Join-Path $ArnesDir "loop-state.json"
$LedgerFile = Join-Path $ArnesDir "quest-ledger.json"
. (Join-Path $PSScriptRoot "artifact-integrity.ps1")

function Get-LoopState {
    if (Test-Path $StateFile) {
        try {
            $raw = Get-Content -LiteralPath $StateFile -Raw -Encoding UTF8
            $state = ($raw | ConvertFrom-Json)
            # Ensure new fields exist (migration)
            if (-not ($state.PSObject.Properties.Name -contains 'chain_step')) {
                $state | Add-Member -NotePropertyName chain_step -NotePropertyValue 0 -Force
            }
            if (-not ($state.PSObject.Properties.Name -contains 'quest_chain') -or $state.quest_chain -eq $null) {
                $state | Add-Member -NotePropertyName quest_chain -NotePropertyValue @() -Force
            }
            if (-not ($state.PSObject.Properties.Name -contains 'audit_artifacts')) {
                $state | Add-Member -NotePropertyName audit_artifacts -NotePropertyValue $null -Force
            }
            if (-not ($state.PSObject.Properties.Name -contains 'current_attempt_id')) { $state | Add-Member -NotePropertyName current_attempt_id -NotePropertyValue "A-001" -Force }
            if (-not ($state.PSObject.Properties.Name -contains 'attempt_count')) { $state | Add-Member -NotePropertyName attempt_count -NotePropertyValue 1 -Force }
            return $state
        } catch {}
    }
    $fresh = New-Object PSObject
    $fresh | Add-Member -NotePropertyName state -NotePropertyValue "IDLE"
    $fresh | Add-Member -NotePropertyName current_quest -NotePropertyValue $null
    $fresh | Add-Member -NotePropertyName current_quest_id -NotePropertyValue $null
    $fresh | Add-Member -NotePropertyName started_at -NotePropertyValue $null
    $fresh | Add-Member -NotePropertyName turns -NotePropertyValue 0
    $fresh | Add-Member -NotePropertyName auto_loop -NotePropertyValue $true
    $fresh | Add-Member -NotePropertyName quest_chain -NotePropertyValue @()
    $fresh | Add-Member -NotePropertyName chain_step -NotePropertyValue 0
    $fresh | Add-Member -NotePropertyName pause_reason -NotePropertyValue $null
    $fresh | Add-Member -NotePropertyName last_verdict -NotePropertyValue $null
    $fresh | Add-Member -NotePropertyName last_agent -NotePropertyValue $null
    $fresh | Add-Member -NotePropertyName last_tokens -NotePropertyValue 0
    $fresh | Add-Member -NotePropertyName audit_artifacts -NotePropertyValue $null
    $fresh | Add-Member -NotePropertyName current_attempt_id -NotePropertyValue "A-001"
    $fresh | Add-Member -NotePropertyName attempt_count -NotePropertyValue 1
    $fresh | Add-Member -NotePropertyName updated_at -NotePropertyValue (Get-Date).ToString("o")
    return $fresh
}

function Save-LoopState($state) {
    if (-not (Test-Path $ArnesDir)) {
        New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null
    }
    $state.updated_at = (Get-Date).ToString("o")
    $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StateFile -Encoding UTF8
}

function Get-Ledger {
    if (Test-Path $LedgerFile) {
        try {
            return (Get-Content -LiteralPath $LedgerFile -Raw -Encoding UTF8 | ConvertFrom-Json)
        } catch {}
    }
    return $null
}

function Update-Ledger($questId, $verdict, $agent, $tokens) {
    if (-not (Test-Path $LedgerFile)) { return }
    $ledger = Get-Ledger
    if ($ledger -eq $null) { return }

    # Update quest entry
    $entry = @{
        quest_id = $questId
        verdict = $verdict
        agent = $agent
        tokens_used = $tokens
        timestamp = (Get-Date).ToString("o")
    }
    if ($ledger.quests -eq $null) { $ledger.quests = @() }
    $ledger.quests += @($entry)

    # Update stats
    if ($ledger.stats -eq $null) {
        $ledger | Add-Member -NotePropertyName stats -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    $ledger.stats.total_quests = @($ledger.quests).Count
    if ($ledger.stats.total_tokens_used -eq $null) { $ledger.stats | Add-Member -NotePropertyName total_tokens_used -NotePropertyValue 0 -Force }
    $ledger.stats.total_tokens_used = [int]$ledger.stats.total_tokens_used + $tokens

    $ledger.limits.weekly_tokens_used = [int]$ledger.limits.weekly_tokens_used + $tokens
    $ledger.limits.weekly_tokens_remaining = [int]$ledger.limits.weekly_tokens_budget - [int]$ledger.limits.weekly_tokens_used

    if ($verdict -eq "PASS") {
        $passes = ($ledger.quests | Where-Object { $_.verdict -eq "PASS" }).Count
        $ledger.stats.success_rate_pct = [int](($passes / $ledger.stats.total_quests) * 100)
    }

    $ledger | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $LedgerFile -Encoding UTF8
}

function Invoke-CircuitBreaker($agentName) {
    if (-not $agentName) { return }
    $cbScript = Join-Path $PSScriptRoot "circuit-breaker.ps1"
    if (Test-Path $cbScript) {
        try {
            $null = & $cbScript -Action record-fail -Agent $agentName -ErrorAction SilentlyContinue 2>&1
        } catch {}
    }
}

function Start-Quest($state, $questText) {
    # L0 detection via quest-detector
    $l0Indicators = @("delete","bulk delete","destroy","drop table","rm -rf","production deploy","prod deploy","force push","git reset","schema migration","rls change","rls policy","rls modification","auth change","rollback prod","rollback production","secret rotation","breaking change")
    $isL0 = $false
    $lower = $questText.ToLower()
    foreach ($ind in $l0Indicators) {
        if ($lower.Contains($ind)) { $isL0 = $true; break }
    }

    if ($isL0) {
        Write-Host "  [L0 PAUSE] Quest detectado como L0 (cambio destructivo/produccion)" -ForegroundColor Red
        Write-Host "  Re-quirio confirmacion explicita del usuario antes de proceder." -ForegroundColor Yellow
        Write-Host "  Use -Force para override (NORMALMENTE NO)." -ForegroundColor DarkGray
        $state.state = "PAUSE_USER"
        $state.pause_reason = "L0_requires_confirmation"
        $state.current_quest = $questText
        return $state
    }

    $state.state = "QUESTING"
    $state.current_quest = $questText
    $state.started_at = (Get-Date).ToString("o")
    $state.turns = 0
    $state.last_verdict = $null
    $state.last_agent = $null
    $state.last_tokens = 0

    # Generate quest ID
    $ledger = Get-Ledger
    $nextNum = 1
    if ($ledger -and $ledger.quests) {
        $last = ($ledger.quests | Select-Object -Last 1)
        if ($last -and $last.quest_id -match 'Q-(\d+)') {
            $nextNum = [int]$Matches[1] + 1
        }
    }
    $state.current_quest_id = "Q-{0:D3}" -f $nextNum
    $state.current_attempt_id = "A-001"
    $state.attempt_count = 1

    return $state
}

function Tick($state) {
    if ($state.state -ne "QUESTING") {
        Write-Host "  [WARN] Cannot tick in state $($state.state)" -ForegroundColor Yellow
        return $state
    }
    $state.turns++
    return $state
}

function Read-AuditArtifact($path, $expectedType, $questId) {
    if (-not $path) { throw "Missing $expectedType artifact path." }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Artifact not found: $path" }
    if (-not (Test-ArtifactHash $path)) { throw "Artifact integrity check failed: $path" }
    try { $artifact = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { throw "Invalid JSON in artifact: $path" }
    if ($artifact.type -ne $expectedType) { throw "Expected artifact type '$expectedType' in $path." }
    if ($artifact.quest_id -ne $questId) { throw "Artifact $path belongs to '$($artifact.quest_id)', not '$questId'." }
    return $artifact
}

function Test-AuditContract($questId, $attemptId, $verdict, $evidencePath, $verdictPath, $remediationPath, $counselPath, $decisionPath) {
    try {
        $evidence = Read-AuditArtifact $evidencePath "evidence_pack" $questId
        $auditVerdict = Read-AuditArtifact $verdictPath "verdict" $questId
        if ($evidence.attempt_id -ne $attemptId -or $auditVerdict.attempt_id -ne $attemptId) { throw "Evidence or verdict belongs to another attempt." }
        if ($auditVerdict.verdict -ne $verdict) { throw "CLI verdict '$verdict' does not match audit verdict '$($auditVerdict.verdict)'." }

        $remediation = $null
        if ($verdict -ne "PASS") {
            $remediation = Read-AuditArtifact $remediationPath "remediation_brief" $questId
            if ($remediation.attempt_id -ne $attemptId) { throw "Remediation belongs to another attempt." }
            if (-not $remediation.items -or @($remediation.items).Count -eq 0) { throw "Remediation brief must contain at least one item." }
        }
        $counsel = Read-AuditArtifact $counselPath "sam_counsel" $questId
        if ($counsel.attempt_id -ne $attemptId) { throw "Sam counsel belongs to another attempt." }
        if ($counsel.verdict -ne $verdict) { throw "Sam counsel verdict '$($counsel.verdict)' does not match '$verdict'." }
        if ($counsel.recommendation.action -notin @("finalize", "retry", "pause", "escalate")) { throw "Sam counsel has no valid recommendation action." }
        $decision = Read-AuditArtifact $decisionPath "atlas_decision" $questId
        if ($decision.attempt_id -ne $attemptId) { throw "Atlas decision belongs to another attempt." }
        if ($decision.decision -notin @("finalize", "retry", "pause", "escalate")) { throw "Atlas decision has no valid action." }
        if ($decision.sam_counsel_path -ne $counselPath) { throw "Atlas decision does not reference the supplied Sam counsel." }
        if ([string]::IsNullOrWhiteSpace($decision.rationale)) { throw "Atlas decision rationale is required." }
        if ($decision.counsel_action -ne $counsel.recommendation.action) { throw "Atlas decision does not bind the current Sam recommendation." }
        if (-not $decision.overrides_counsel -and $decision.decision -ne $counsel.recommendation.action) { throw "Atlas decision differs from Sam without an override." }
        if ($decision.decision -eq "finalize" -and $verdict -ne "PASS") { throw "Atlas cannot finalize a non-PASS verdict." }

        return [PSCustomObject]@{
            valid = $true
            references = [PSCustomObject]@{
                evidence_pack = $evidencePath
                verdict = $verdictPath
                remediation_brief = $remediationPath
                sam_counsel = $counselPath
                atlas_decision = $decisionPath
            }
        }
    } catch {
        return [PSCustomObject]@{ valid = $false; error = $_.Exception.Message }
    }
}

function Quest-Done($state, $questId, $verdict, $agent, $tokens, $evidencePath, $verdictPath, $remediationPath, $counselPath, $decisionPath) {
    if (-not $questId) { $questId = $state.current_quest_id }
    if ($state.state -ne "QUESTING") { $state.state = "PAUSE_USER"; $state.pause_reason = "quest_done_requires_active_quest"; Write-Host "  [DECISION BLOCKED] No active quest to close." -ForegroundColor Red; return $state }
    if ($questId -ne $state.current_quest_id) { $state.state = "PAUSE_USER"; $state.pause_reason = "quest_id_mismatch"; Write-Host "  [DECISION BLOCKED] QuestId does not match active quest." -ForegroundColor Red; return $state }
    $audit = Test-AuditContract $questId $state.current_attempt_id $verdict $evidencePath $verdictPath $remediationPath $counselPath $decisionPath
    if (-not $audit.valid) {
        $state.state = "PAUSE_USER"
        $state.pause_reason = "decision_contract_incomplete: $($audit.error)"
        Write-Host "  [DECISION BLOCKED] ${questId}: $($audit.error)" -ForegroundColor Red
        return $state
    }

    $state.last_verdict = $verdict
    $state.last_agent = $agent
    $state.last_tokens = $tokens
    $state.audit_artifacts = $audit.references

    # Update ledger
    Update-Ledger $questId $verdict $agent $tokens

    # Circuit breaker
    if ($verdict -ne "PASS" -and $agent) {
        Invoke-CircuitBreaker $agent
    } elseif ($verdict -eq "PASS" -and $agent) {
        $cbScript = Join-Path $PSScriptRoot "circuit-breaker.ps1"
        if (Test-Path $cbScript) {
            try { $null = & $cbScript -Action record-pass -Agent $agent -ErrorAction SilentlyContinue 2>&1 } catch {}
        }
    }

    # Memoria propia: guardar resultado del quest en arnes.db
    try {
        $memScript = (Get-OsmaMemoryCli)
        if (Test-Path $memScript) {
            $title = "Quest $questId $verdict ($agent, $tokens tokens)"
            $content = "Quest $questId verdict: $verdict. Agent: $agent. Tokens: $tokens. Quest: $($state.current_quest). Evidence: $evidencePath. Audit verdict: $verdictPath. Remediation: $remediationPath. Sam counsel: $counselPath. Atlas decision: $decisionPath"
            $memAgent = if ($agent) { $agent } else { 'atlas' }
            $type = if ($verdict -eq "PASS") { "pattern" } else { "bugfix" }
            $null = & $memScript save -Agent $memAgent -Topic "atlas/quest-outcomes/$questId" -Type $type -Content $content 2>&1
            # OSMA V5: registrar una EXPERIENCIA VALIDADA por quest finalizado
            # (situation->solution->outcome con reward; PASS=validado, FAIL=fallo).
            # Hace que el CLI harness (no solo PI) pueble la capa de experiencias.
            $reward = if ($verdict -eq "PASS") { 0.9 } elseif ($verdict -eq "FAIL_PARTIAL") { 0.3 } else { -0.8 }
            $null = & $memScript experience -ExperienceAction record `
                -Situation ("Quest: {0} | {1}" -f $questId, $state.current_quest) `
                -Reasoning ("Agente asignado: {0}. Objetivo procesado mediante el harness." -f $memAgent) `
                -Conclusion ("Accion llevada: {0}" -f $title) `
                -Action ("Quest {0} finalizado con veredicto {1}." -f $questId, $verdict) `
                -Outcome $content `
                -Reward $reward `
                -Agent $memAgent -Project (Split-Path (Get-Location) -Leaf) -QuestId $questId -Quiet 2>&1
        }
    } catch {}

    # Transition follows Atlas's explicit decision, not only the verdict.
    $atlasDecision = (Read-AuditArtifact $decisionPath "atlas_decision" $questId).decision
    $state.state = "EVALUATING"
    if ($atlasDecision -eq "finalize") {
        if ($state.auto_loop) {
            $state.state = "AUTO_NEXT"
            Write-Host "  [OK] $questId finalized. Auto-next..." -ForegroundColor Green
        } else {
            $state.state = "PAUSE_USER"
            Write-Host "  [OK] $questId finalized. Paused (auto_loop=false)." -ForegroundColor Yellow
        }
    } elseif ($atlasDecision -eq "retry") {
        $state.attempt_count = [int]$state.attempt_count + 1
        $state.current_attempt_id = "A-{0:D3}" -f $state.attempt_count
        $state.turns = 0
        $state.pause_reason = $null
        $state.state = "QUESTING"
        Write-Host "  [RETRY] $questId inicia $($state.current_attempt_id) con artefactos nuevos." -ForegroundColor Yellow
    } else {
        $state.state = "PAUSE_USER"
        $state.pause_reason = "atlas_decision_$atlasDecision"
        Write-Host "  [ATLAS] $questId decision: $atlasDecision. Paused." -ForegroundColor Yellow
    }

    return $state
}

function Append-MemoryFallback($agent, $title, $content, $type) {
    $memDir = Join-Path $ArnesDir "memory"
    if (-not (Test-Path $memDir)) {
        New-Item -ItemType Directory -Path $memDir -Force | Out-Null
    }
    $agentKey = if ($agent) { $agent } else { "atlas" }
    $file = Join-Path $memDir "$agentKey-memory.jsonl"
    $entry = @{
        timestamp = (Get-Date).ToString("o")
        title = $title
        content = $content
        type = $type
    }
    $entry | ConvertTo-Json -Compress | Add-Content -LiteralPath $file -Encoding UTF8
}

# === Main ===
$state = Get-LoopState

switch ($Action) {
    "start" {
        if (-not $Quest) { Write-Error "Quest required for start"; exit 1 }
        if ($Force) {
            # Override L0 pause
            $state.state = "QUESTING"
            $state.current_quest = $Quest
            $state.started_at = (Get-Date).ToString("o")
            $state.turns = 0
            $ledger = Get-Ledger
            $nextNum = 1
            if ($ledger -and $ledger.quests) {
                $last = ($ledger.quests | Select-Object -Last 1)
                if ($last -and $last.quest_id -match 'Q-(\d+)') {
                    $nextNum = [int]$Matches[1] + 1
                }
            }
            $state.current_quest_id = "Q-{0:D3}" -f $nextNum
            $state.current_attempt_id = "A-001"
            $state.attempt_count = 1
            Write-Host "  [OK] Quest started (L0 override): $($state.current_quest_id)" -ForegroundColor Green
        } else {
            $state = Start-Quest $state $Quest
        }

        # Save chain if provided
        if ($Chain -and $Chain.Count -gt 0) {
            $state.quest_chain = @($Chain)
            $state.chain_step = 0
            Write-Host "  [CHAIN] $($Chain.Count) sub-quests queued" -ForegroundColor Cyan
        }

        Save-LoopState $state
        if ($state.state -ne "PAUSE_USER") {
            Write-Host "  Quest: $Quest" -ForegroundColor White
        }
    }
    "state" {
        if ($Json) {
            $state | ConvertTo-Json -Depth 6
            exit 0
        }
        Write-Host ""
        Write-Host "  LOOP ENGINE STATE" -ForegroundColor Cyan
        Write-Host "  =================" -ForegroundColor Cyan
        Write-Host "  State:           $($state.state)" -ForegroundColor White
        Write-Host "  Current quest:   $($state.current_quest_id)" -ForegroundColor White
        Write-Host "  Turns:           $($state.turns)" -ForegroundColor White
        Write-Host "  Auto-loop:       $($state.auto_loop)" -ForegroundColor White
        if ($state.last_verdict) {
            Write-Host "  Last verdict:    $($state.last_verdict)" -ForegroundColor White
            Write-Host "  Last agent:      $($state.last_agent)" -ForegroundColor DarkGray
            Write-Host "  Last tokens:     $($state.last_tokens)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    "tick" {
        $state = Tick $state
        Save-LoopState $state
        Write-Host "  [TICK] Turn $($state.turns)" -ForegroundColor Cyan
    }
    "quest-done" {
        if (-not $QuestId) { $QuestId = $state.current_quest_id }
        $state = Quest-Done $state $QuestId $Verdict $AgentUsed $TokensUsed $EvidencePackPath $AuditVerdictPath $RemediationBriefPath $SamCounselPath $AtlasDecisionPath

        # Auto-chain: if there are more sub-quests queued and verdict is PASS, start next
        if ($state.state -eq "AUTO_NEXT" -and $state.quest_chain -and $state.chain_step -lt ($state.quest_chain.Count - 1)) {
            $state.chain_step++
            $nextQ = $state.quest_chain[$state.chain_step]
            $state.state = "QUESTING"
            $state.current_quest = $nextQ
            $state.started_at = (Get-Date).ToString("o")
            $state.turns = 0
            $ledger = Get-Ledger
            $nextNum = 1
            if ($ledger -and $ledger.quests) {
                $last = ($ledger.quests | Select-Object -Last 1)
                if ($last -and $last.quest_id -match 'Q-(\d+)') {
                    $nextNum = [int]$Matches[1] + 1
                }
            }
            $state.current_quest_id = "Q-{0:D3}" -f $nextNum
            Write-Host "  [CHAIN] Auto-next step $($state.chain_step + 1)/$($state.quest_chain.Count): Q = $nextQ" -ForegroundColor Cyan
        } elseif ($state.state -eq "AUTO_NEXT" -and $state.quest_chain -and $state.chain_step -ge ($state.quest_chain.Count - 1)) {
            Write-Host "  [CHAIN] Chain complete ($($state.quest_chain.Count) sub-quests)" -ForegroundColor Green
            $state.state = "IDLE"
            $state.quest_chain = @()
            $state.chain_step = 0
        }

        Save-LoopState $state
    }
    "reset" {
        $state.state = "IDLE"
        $state.current_quest = $null
        $state.current_quest_id = $null
        $state.turns = 0
        Save-LoopState $state
        Write-Host "  [OK] Loop reset to IDLE" -ForegroundColor Green
    }
    "toggle-auto" {
        $state.auto_loop = -not $state.auto_loop
        Save-LoopState $state
        $newState = if ($state.auto_loop) { "ON" } else { "OFF" }
        Write-Host "  [OK] auto_loop = $newState" -ForegroundColor Cyan
    }
    "pause" {
        $state.state = "PAUSE_USER"
        $state.pause_reason = "user_requested"
        Save-LoopState $state
        Write-Host "  [OK] Loop paused" -ForegroundColor Yellow
    }
    "resume" {
        $state.state = "IDLE"
        $state.pause_reason = $null
        Save-LoopState $state
        Write-Host "  [OK] Loop resumed" -ForegroundColor Green
    }
}
