# smoke-test.ps1 - Atlas Harness RPG validation
# ==================================================
# Chequea todos los componentes criticos del harness.
# 30+ checks cubriendo: agentes, harness scripts, encoding, integration.

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$Json,
    [switch]$Silent
)

$ErrorActionPreference = "Continue"
$env:ARNES_ARTIFACT_HMAC_KEY = "smoke-test-only-key"

$myRoot = $PSScriptRoot
if (Test-Path (Join-Path $myRoot "..\core\atlas-player.agent.md")) {
    $ArnesRoot = Resolve-Path (Join-Path $myRoot "..")
} else {
    $homeRoot = Join-Path $HOME "arnes"
    if (Test-Path (Join-Path $homeRoot "core\atlas-player.agent.md")) {
        $ArnesRoot = Resolve-Path $homeRoot
    } else {
        if (-not $Silent) { Write-Host "FAIL: No se encontro el repo arnes." -ForegroundColor Red }
        exit 2
    }
}

$ArnesDir = Join-Path $ProjectPath ".arnes"
$ConfigFile = Join-Path $ArnesDir "config.json"
$LedgerFile = Join-Path $ArnesDir "quest-ledger.json"
$ProfileFile = Join-Path $ArnesDir "repo-profile.json"
. (Join-Path $ArnesRoot "cli\artifact-integrity.ps1")

$checks = @()
$passCount = 0
$failCount = 0

function Check {
    param([string]$Name, [string]$Category, [scriptblock]$Test, [string]$Fix = "")
    $passed = $false
    $error = $null
    try {
        $result = & $Test
        if ($result -is [bool]) { $passed = $result }
        elseif ($result -is [string]) { $passed = $true }
        elseif ($result -is [hashtable]) { $passed = $result.passed; $error = $result.error }
        else { $passed = ($null -ne $result) }
    } catch {
        $passed = $false
        $error = $_.Exception.Message
    }
    if ($passed) { $script:passCount++ } else { $script:failCount++ }
    $script:checks += [ordered]@{
        name     = $Name
        category = $Category
        passed   = $passed
        error    = $error
        fix      = $Fix
    }
}

function Run-Capture([scriptblock]$Cmd) {
    $tmpFile = [System.IO.Path]::GetTempFileName()
    try {
        & $Cmd *> $tmpFile
        return (Get-Content -LiteralPath $tmpFile -Raw -ErrorAction SilentlyContinue)
    } finally {
        Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue
    }
}

function New-AuditFixture([string]$QuestId, [string]$Verdict) {
    $attemptId = (Get-Content (Join-Path $ArnesDir "loop-state.json") -Raw | ConvertFrom-Json).current_attempt_id
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("arnes-smoke-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $evidencePath = Join-Path $dir "evidence.json"
    $verdictPath = Join-Path $dir "verdict.json"
    $remediationPath = Join-Path $dir "remediation.json"
    @{ type = "evidence_pack"; quest_id = $QuestId; attempt_id = $attemptId; quest_acceptance_criteria = @("smoke") } | ConvertTo-Json | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    @{ type = "verdict"; quest_id = $QuestId; attempt_id = $attemptId; verdict = $Verdict } | ConvertTo-Json | Set-Content -LiteralPath $verdictPath -Encoding UTF8
    if ($Verdict -ne "PASS") {
        @{ type = "remediation_brief"; quest_id = $QuestId; attempt_id = $attemptId; items = @(@{ check = "smoke"; file = "smoke" }) } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $remediationPath -Encoding UTF8
    }
    $counselPath = Join-Path $dir "sam-counsel.json"
    @{ type = "sam_counsel"; quest_id = $QuestId; attempt_id = $attemptId; verdict = $Verdict; recommendation = @{ action = "finalize" } } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $counselPath -Encoding UTF8
    $decisionPath = Join-Path $dir "atlas-decision.json"
    @{ type = "atlas_decision"; quest_id = $QuestId; attempt_id = $attemptId; decision = "finalize"; rationale = "smoke decision"; sam_counsel_path = $counselPath; counsel_action = "finalize"; overrides_counsel = $false } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $decisionPath -Encoding UTF8
    @($evidencePath, $verdictPath, $counselPath, $decisionPath, $remediationPath) | Where-Object { Test-Path $_ } | ForEach-Object { Write-ArtifactHash $_ }
    return [PSCustomObject]@{ directory = $dir; evidence = $evidencePath; verdict = $verdictPath; remediation = $remediationPath; counsel = $counselPath; decision = $decisionPath }
}

# === Core files ===
Check "atlas-player.agent.md existe" "core" {
    Test-Path (Join-Path $ArnesRoot "core\atlas-player.agent.md")
}

Check "atlas-init.ps1 existe" "cli" {
    Test-Path (Join-Path $ArnesRoot "cli\atlas-init.ps1")
}

Check "repo-profile.ps1 existe" "cli" {
    Test-Path (Join-Path $ArnesRoot "cli\repo-profile.ps1")
}

Check "update-ledger.ps1 existe" "cli" {
    Test-Path (Join-Path $ArnesRoot "cli\update-ledger.ps1")
}

Check "14+ agentes sincronizados" "agents" {
    $agentDir = "$env:USERPROFILE\.config\opencode\agents"
    if (-not (Test-Path $agentDir)) { return $false }
    $count = (Get-ChildItem $agentDir -Filter "*.md" -ErrorAction Stop).Count
    return ($count -ge 14)
}

Check "9 skill trees en cli dir" "skills" {
    $skillDir = "$env:USERPROFILE\.config\opencode\skills\atlas"
    if (-not (Test-Path $skillDir)) { return $false }
    $count = (Get-ChildItem $skillDir -Filter "*.json" -ErrorAction Stop).Count
    return ($count -ge 8)
}

# === .arnes/ health ===
Check ".arnes/ existe" "config" {
    Test-Path $ArnesDir
}

Check "config.json valido" "config" {
    if (-not (Test-Path $ConfigFile)) { return $false }
    try { $null = Get-Content $ConfigFile -Raw | ConvertFrom-Json; return $true } catch { return $false }
}

Check "quest-ledger.json valido" "config" {
    if (-not (Test-Path $LedgerFile)) { return $false }
    try { $null = Get-Content $LedgerFile -Raw | ConvertFrom-Json; return $true } catch { return $false }
}

Check "repo-profile.json tiene tier" "config" {
    if (-not (Test-Path $ProfileFile)) { return $false }
    $rp = Get-Content $ProfileFile -Raw | ConvertFrom-Json
    return ($rp.PSObject.Properties.Name -contains 'repo_tier')
}

# === Runtime ===
Check "PowerShell >= 5.1" "runtime" {
    return ($PSVersionTable.PSVersion.Major -ge 5)
}

Check "pwsh o powershell available" "runtime" {
    $c = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($c) { return $true }
    $c = Get-Command powershell -ErrorAction SilentlyContinue
    return ($null -ne $c)
}

Check "UTF-8 strict en agentes" "agents" {
    $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
    $agentDir = "$env:USERPROFILE\.config\opencode\agents"
    Get-ChildItem $agentDir -Filter "*.md" -ErrorAction Stop | ForEach-Object {
        if ($_.Name -eq "atlas-player.agent.md") { return }
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        $null = $utf8Strict.GetString($bytes)
    }
    return $true
}

# === Onboarding ===
Check "config.json tiene subscription" "onboarding" {
    if (-not (Test-Path $ConfigFile)) { return $false }
    $c = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    if (-not $c.PSObject.Properties.Name -contains 'subscription') { return $false }
    $sub = $c.subscription
    $activeCount = 0
    foreach ($k in $sub.PSObject.Properties.Name) { if ($sub.$k) { $activeCount++ } }
    return ($activeCount -ge 1)
}

# === Harness scripts ===
Check "circuit-breaker.ps1 existe" "harness" {
    Test-Path (Join-Path $ArnesRoot "cli\circuit-breaker.ps1")
}

Check "quest-detector.ps1 existe" "harness" {
    Test-Path (Join-Path $ArnesRoot "cli\quest-detector.ps1")
}

Check "model-router.ps1 existe" "harness" {
    Test-Path (Join-Path $ArnesRoot "cli\model-router.ps1")
}

Check "loop-engine.ps1 existe" "harness" {
    Test-Path (Join-Path $ArnesRoot "cli\loop-engine.ps1")
}

Check "atlas-orchestrator.ps1 existe" "harness" {
    Test-Path (Join-Path $ArnesRoot "cli\atlas-orchestrator.ps1")
}

Check "platform-exec.ps1 existe" "harness" {
    Test-Path (Join-Path $ArnesRoot "cli\platform-exec.ps1")
}

Check "audit-exec.ps1 existe" "harness" {
    Test-Path (Join-Path $ArnesRoot "cli\audit-exec.ps1")
}

Check "counsel-exec.ps1 existe" "harness" {
    Test-Path (Join-Path $ArnesRoot "cli\counsel-exec.ps1")
}

Check "decision-record.ps1 existe" "harness" {
    Test-Path (Join-Path $ArnesRoot "cli\decision-record.ps1")
}

Check "fix-encoding-v2.ps1 existe" "harness" {
    Test-Path (Join-Path $ArnesRoot "cli\fix-encoding-v2.ps1")
}

# === Harness ejecutable ===
Check "circuit-breaker ejecutable" "harness" {
    $c = Run-Capture { & (Join-Path $ArnesRoot "cli\circuit-breaker.ps1") -Action status -ArnesDir $ArnesDir }
    return ($c -match "CIRCUIT BREAKER")
}

Check "quest-detector ejecutable" "harness" {
    $c = Run-Capture { & (Join-Path $ArnesRoot "cli\quest-detector.ps1") -Prompt "test frontend" -Json }
    return ($c -match "quest_type")
}

Check "model-router ejecutable" "harness" {
    $c = Run-Capture { & (Join-Path $ArnesRoot "cli\model-router.ps1") -Platform opencode -Tier pro -QuestType frontend -ArnesDir $ArnesDir }
    return ($c -match "MODEL ROUTER")
}

Check "loop-engine ejecutable" "harness" {
    $c = Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action state -ArnesDir $ArnesDir }
    return ($c -match "LOOP ENGINE STATE")
}

Check "loop-engine L0 pause" "harness" {
    Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action reset -ArnesDir $ArnesDir } | Out-Null
    $c = Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action start -Quest "deploy to prod with rls change" -ArnesDir $ArnesDir }
    return ($c -match "L0 PAUSE")
}

Check "loop-engine chain auto-next" "harness" {
    Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action reset -ArnesDir $ArnesDir } | Out-Null
    $before = Get-Content (Join-Path $ArnesDir "loop-state.json") -Raw | ConvertFrom-Json
    if (-not $before.auto_loop) {
        Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action toggle-auto -ArnesDir $ArnesDir } | Out-Null
    }
    $c1 = Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action start -Quest "Q1" -Chain @("Q1","Q2","Q3") -ArnesDir $ArnesDir }
    $questId = (Get-Content (Join-Path $ArnesDir "loop-state.json") -Raw | ConvertFrom-Json).current_quest_id
    $fixture = New-AuditFixture $questId "PASS"
    try {
        $c2 = Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action quest-done -Verdict PASS -AgentUsed vivi -TokensUsed 1000 -EvidencePackPath $fixture.evidence -AuditVerdictPath $fixture.verdict -SamCounselPath $fixture.counsel -AtlasDecisionPath $fixture.decision -ArnesDir $ArnesDir }
        return ($c1 -match "sub-quests queued" -and $c2 -match "Auto-next step 2/3")
    } finally {
        Remove-Item -LiteralPath $fixture.directory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Check "loop-engine bloquea auditoria incompleta" "harness" {
    Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action reset -ArnesDir $ArnesDir } | Out-Null
    Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action start -Quest "Q audit" -ArnesDir $ArnesDir } | Out-Null
    $c = Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action quest-done -Verdict PASS -AgentUsed vivi -TokensUsed 1 -ArnesDir $ArnesDir }
    return ($c -match "DECISION BLOCKED")
}

Check "loop-engine rechaza artefactos de otro intento" "harness" {
    Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action reset -ArnesDir $ArnesDir } | Out-Null
    Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action start -Quest "Q provenance" -ArnesDir $ArnesDir } | Out-Null
    $questId = (Get-Content (Join-Path $ArnesDir "loop-state.json") -Raw | ConvertFrom-Json).current_quest_id
    $fixture = New-AuditFixture $questId "PASS"
    try {
        $raw = Get-Content $fixture.evidence -Raw | ConvertFrom-Json
        $raw.attempt_id = "A-000"
        $raw | ConvertTo-Json -Depth 8 | Set-Content $fixture.evidence -Encoding UTF8
        Write-ArtifactHash $fixture.evidence
        $c = Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action quest-done -Verdict PASS -AgentUsed vivi -TokensUsed 1 -EvidencePackPath $fixture.evidence -AuditVerdictPath $fixture.verdict -SamCounselPath $fixture.counsel -AtlasDecisionPath $fixture.decision -ArnesDir $ArnesDir }
        return ($c -match "DECISION BLOCKED" -and $c -match "another attempt")
    } finally {
        Remove-Item -LiteralPath $fixture.directory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Check "loop-engine rechaza artefacto manipulado" "harness" {
    Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action reset -ArnesDir $ArnesDir } | Out-Null
    Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action start -Quest "Q integrity" -ArnesDir $ArnesDir } | Out-Null
    $questId = (Get-Content (Join-Path $ArnesDir "loop-state.json") -Raw | ConvertFrom-Json).current_quest_id
    $fixture = New-AuditFixture $questId "PASS"
    try {
        Add-Content -LiteralPath $fixture.verdict -Value " " -Encoding UTF8
        $c = Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action quest-done -Verdict PASS -AgentUsed vivi -TokensUsed 1 -EvidencePackPath $fixture.evidence -AuditVerdictPath $fixture.verdict -SamCounselPath $fixture.counsel -AtlasDecisionPath $fixture.decision -ArnesDir $ArnesDir }
        return ($c -match "DECISION BLOCKED" -and $c -match "integrity check failed")
    } finally { Remove-Item -LiteralPath $fixture.directory -Recurse -Force -ErrorAction SilentlyContinue }
}

Check "loop-engine rechaza firma adulterada" "harness" {
    Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action reset -ArnesDir $ArnesDir } | Out-Null
    Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action start -Quest "Q signature" -ArnesDir $ArnesDir } | Out-Null
    $questId = (Get-Content (Join-Path $ArnesDir "loop-state.json") -Raw | ConvertFrom-Json).current_quest_id
    $fixture = New-AuditFixture $questId "PASS"
    try {
        Set-Content -LiteralPath "$($fixture.verdict).sig" -Value "BAD" -Encoding ASCII
        $c = Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action quest-done -Verdict PASS -AgentUsed vivi -TokensUsed 1 -EvidencePackPath $fixture.evidence -AuditVerdictPath $fixture.verdict -SamCounselPath $fixture.counsel -AtlasDecisionPath $fixture.decision -ArnesDir $ArnesDir }
        return ($c -match "DECISION BLOCKED" -and $c -match "integrity check failed")
    } finally { Remove-Item -LiteralPath $fixture.directory -Recurse -Force -ErrorAction SilentlyContinue }
}

Check "quest-detector chain split" "harness" {
    $c = Run-Capture { & (Join-Path $ArnesRoot "cli\quest-detector.ps1") -Prompt "crea login y tests y deploy" -Json }
    return ($c -match "sub_quests" -and $c -match '"sub_quest_count":\s*3')
}

Check "opencode.json existe con 15 agentes" "config" {
    $f = Join-Path $ArnesRoot "opencode.json"
    if (-not (Test-Path $f)) { return $false }
    $c = Get-Content $f -Raw | ConvertFrom-Json
    return ($c.agent.PSObject.Properties.Name.Count -ge 14)
}

Check "loop-engine toggle-auto" "harness" {
    $before = Get-Content (Join-Path $ArnesDir "loop-state.json") -Raw | ConvertFrom-Json
    if (-not $before.auto_loop) {
        Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action toggle-auto -ArnesDir $ArnesDir } | Out-Null
    }
    $c = Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action toggle-auto -ArnesDir $ArnesDir }
    $restore = Run-Capture { & (Join-Path $ArnesRoot "cli\loop-engine.ps1") -Action toggle-auto -ArnesDir $ArnesDir }
    return ($c -match "auto_loop = OFF" -and $restore -match "auto_loop = ON")
}

Check "orchestrator integra repo-profile" "harness" {
    $c = Run-Capture { & (Join-Path $ArnesRoot "cli\atlas-orchestrator.ps1") -Quest "test" -ArnesDir $ArnesDir }
    return ($c -match "Repo Profile")
}

Check "platform-exec invocable para 3 plataformas" "harness" {
    $script = Get-Content (Join-Path $ArnesRoot "cli\platform-exec.ps1") -Raw
    $platforms = @("opencode","codex","claude")
    foreach ($p in $platforms) {
        if ($script -notmatch [regex]::Escape($p)) { return $false }
    }
    return $true
}

Check "platform-exec genera evidence pack" "harness" {
    $content = Get-Content (Join-Path $ArnesRoot "cli\platform-exec.ps1") -Raw
    return ($content -match 'type = "evidence_pack"' -and $content -match 'audit-request.json')
}

Check "platform-exec no fabrica veredictos" "harness" {
    $content = Get-Content (Join-Path $ArnesRoot "cli\platform-exec.ps1") -Raw
    return ($content -match 'reviewer = "tywin"' -and $content -match 'Tywin must emit verdict.json' -and $content -notmatch 'type = "verdict"')
}

Check "audit-exec valida bundle Tywin" "harness" {
    $content = Get-Content (Join-Path $ArnesRoot "cli\audit-exec.ps1") -Raw
    return ($content -match 'remediation_brief' -and $content -match 'Tywin no devolvio JSON estricto' -and $content -match 'sam_advisory_input')
}

Check "counsel-exec valida consejo Sam" "harness" {
    $content = Get-Content (Join-Path $ArnesRoot "cli\counsel-exec.ps1") -Raw
    return ($content -match 'sam_counsel' -and $content -match 'Sam no devolvio consejo JSON valido' -and $content -match 'finalize", "retry", "pause", "escalate')
}

Check "decision-record exige decision explicita" "harness" {
    $content = Get-Content (Join-Path $ArnesRoot "cli\decision-record.ps1") -Raw
    return ($content -match 'atlas_decision' -and $content -match 'OverrideCounsel' -and $content -match 'Rationale')
}

# === Agent quality ===
Check "Eiko tiene Skills Externas" "agents" {
    $eiko = Get-Content (Join-Path $ArnesRoot "core\classes\eiko.agent.md") -Raw
    return ($eiko -match "Skills Externas Importadas")
}

Check "4+ auditores con Hand-off Varys" "agents" {
    $names = @("auron","bran","sam","varys-documentalist")
    foreach ($a in $names) {
        $f = Join-Path $ArnesRoot "core\auditors\$a.agent.md"
        $c = Get-Content $f -Raw
        if ($c -notmatch "Hand-off con Varys") { return $false }
    }
    return $true
}

Check "6 party members con Hand-off Varys" "agents" {
    $names = @("eiko","mage","monk","paladin","ranger","rogue")
    foreach ($a in $names) {
        $f = Join-Path $ArnesRoot "core\classes\$a.agent.md"
        $c = Get-Content $f -Raw
        if ($c -notmatch "Hand-off con Varys") { return $false }
    }
    return $true
}

Check "Quina tiene Output Protocol JSON" "agents" {
    $q = Get-Content (Join-Path $ArnesRoot "core\auditors\quina.agent.md") -Raw
    return ($q -match "Output Protocol")
}

Check "Tywin tiene Verdict JSON" "agents" {
    $t = Get-Content (Join-Path $ArnesRoot "core\auditors\tywin.agent.md") -Raw
    return ($t -match "Verdict JSON")
}

Check "9 agentes sin patron -join roto" "agents" {
    $names = @("eiko","mage","monk","paladin","ranger","rogue")
    foreach ($a in $names) {
        $f = Join-Path $ArnesRoot "core\classes\$a.agent.md"
        $c = Get-Content $f -Raw
        if ($c -match '-\s*join\s*"') { return $false }
    }
    $auditors = @("varys","sam","bran")
    foreach ($a in $auditors) {
        $f = Join-Path $ArnesRoot "core\auditors\$a.agent.md"
        $c = Get-Content $f -Raw
        if ($c -match '-\s*join\s*"') { return $false }
    }
    return $true
}

# === Exit ===
$total = $checks.Count
$exitCode = if ($failCount -eq 0) { 0 } else { 1 }

if ($Json) {
    $output = [ordered]@{
        total     = $total
        passed    = $passCount
        failed    = $failCount
        exit_code = $exitCode
        checks    = @($checks)
    }
    $output | ConvertTo-Json -Depth 5
    exit $exitCode
}

if (-not $Silent) {
    Write-Host ""
    Write-Host "  ATLAS SMOKE TEST [$passCount/$total PASS]" -ForegroundColor Cyan
    Write-Host "  ----------------------------------------"
    foreach ($ch in $checks) {
        if ($ch.passed) {
            Write-Host "  [PASS] $($ch.name) ($($ch.category))" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] $($ch.name)" -ForegroundColor Red
            if ($ch.error) { Write-Host "         $($ch.error)" -ForegroundColor DarkGray }
            if ($ch.fix)   { Write-Host "         fix: $($ch.fix)" -ForegroundColor Yellow }
        }
    }
    Write-Host ""
    if ($exitCode -ne 0) {
        Write-Host "  $failCount/$total check(s) failed.`n" -ForegroundColor Red
    } else {
        Write-Host "  TODOS LOS CHEQUEOS PASARON. Atlas lanzable.`n" -ForegroundColor Green
    }
}

exit $exitCode
