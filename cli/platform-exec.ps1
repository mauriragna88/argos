# platform-exec.ps1 - P5 Real CLI wrapper for OpenCode / Codex / Claude
# =============================================
# Wraps the actual platform CLI for real quest execution.
# Atlas orchestrator can call this to actually run the quest instead of simulating.

#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet("opencode","codex","claude")] [string]$Platform,
    [Parameter(Mandatory)] [string]$Prompt,
    [string]$Agent = "atlas-player",
    [ValidatePattern("^$|^Q-\d{3,}$")] [string]$QuestId = "",
    [ValidatePattern("^$|^A-\d{3,}$")] [string]$AttemptId = "",
    [int]$TimeoutSec = 600,
    [switch]$NonInteractive,
    [string]$ArnesDir = ""
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "artifact-integrity.ps1")
if (-not $env:ARNES_ARTIFACT_HMAC_KEY) { Write-Host "  [ERROR] Define ARNES_ARTIFACT_HMAC_KEY antes de ejecutar." -ForegroundColor Red; exit 1 }

if (-not $ArnesDir) { $ArnesDir = ".arnes" }
if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }

if (-not $QuestId) {
    $stateFile = Join-Path $ArnesDir "loop-state.json"
    if (Test-Path $stateFile) {
        try { $state = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json; $QuestId = $state.current_quest_id; if (-not $AttemptId) { $AttemptId = $state.current_attempt_id } } catch {}
    }
}
if (-not $QuestId -or -not $AttemptId) {
    Write-Host "  [ERROR] QuestId requerido. Inicia el loop antes de ejecutar la plataforma." -ForegroundColor Red
    exit 1
}

# === Resolve CLI command ===
$cmd = switch ($Platform) {
    "opencode" { "opencode" }
    "codex"    { "codex" }
    "claude"   { "claude" }
}

# Verify CLI exists
$cmdCheck = Get-Command $cmd -ErrorAction SilentlyContinue
if (-not $cmdCheck) {
    Write-Host "  [ERROR] '$cmd' CLI no esta en PATH." -ForegroundColor Red
    Write-Host "  Instala $cmd primero o elige otra plataforma." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "  PLATFORM EXECUTION" -ForegroundColor Cyan
Write-Host "  =================" -ForegroundColor Cyan
Write-Host "  Platform: $Platform" -ForegroundColor White
Write-Host "  Agent:    $Agent" -ForegroundColor White
Write-Host "  CLI:      $($cmdCheck.Source)" -ForegroundColor DarkGray
Write-Host ""

# Build CLI args per platform
$cliArgs = @()
switch ($Platform) {
    "opencode" {
        # opencode --agent <name> --prompt <text>
        $cliArgs = @("--agent", $Agent, "--prompt", $Prompt)
    }
    "codex" {
        # codex exec [PROMPT] - subcommand for non-interactive
        # Default Codex requires --skip-git-repo-check outside trusted dirs
        $cliArgs = @("exec", "--skip-git-repo-check", $Prompt)
    }
    "claude" {
        # claude --print <prompt> - non-interactive single-shot
        $cliArgs = @("--print", $Prompt)
    }
}

Write-Host "  Executing: $cmd $($cliArgs -join ' ')" -ForegroundColor DarkGray
Write-Host ""

# Execute with timeout
$job = Start-Job -ScriptBlock {
    param($cmd, $cliArgs, $cwd)
    Set-Location $cwd
    & $cmd @cliArgs
    [PSCustomObject]@{ __arnes_exit_code = $LASTEXITCODE }
} -ArgumentList $cmd, $cliArgs, (Get-Location).Path

$completed = Wait-Job -Job $job -Timeout $TimeoutSec
if (-not $completed) {
    Write-Host "  [TIMEOUT] $TimeoutSec segundos alcanzados. Stopping..." -ForegroundColor Red
    Stop-Job -Job $job
    Remove-Job -Job $job -Force
    exit 2
}

$result = @(Receive-Job -Job $job)
$exitRecord = @($result | Where-Object { $_ -is [PSCustomObject] -and $_.PSObject.Properties.Name -contains "__arnes_exit_code" } | Select-Object -Last 1)
$exitCode = if ($exitRecord) { [int]$exitRecord[0].__arnes_exit_code } else { 0 }
$output = @($result | Where-Object { -not ($_ -is [PSCustomObject] -and $_.PSObject.Properties.Name -contains "__arnes_exit_code") })
Remove-Job -Job $job -Force

# Output
Write-Host "  --- Output ---" -ForegroundColor Cyan
$output | ForEach-Object { Write-Host "  $_" }
Write-Host "  --- End output ---" -ForegroundColor Cyan
Write-Host ""

# Save output and generate Varys's evidence handoff artifacts.
$outFile = Join-Path $ArnesDir "last-exec-output.txt"
$output | Set-Content -LiteralPath $outFile -Encoding UTF8
Write-Host "  Output saved to: $outFile" -ForegroundColor DarkGray

$runDir = Join-Path $ArnesDir (Join-Path (Join-Path "runs" $QuestId) $AttemptId)
if (-not (Test-Path $runDir)) { New-Item -ItemType Directory -Path $runDir -Force | Out-Null }
$runOutputFile = Join-Path $runDir "party-output.txt"
$output | Set-Content -LiteralPath $runOutputFile -Encoding UTF8
$evidencePath = Join-Path $runDir "evidence.json"
$auditRequestPath = Join-Path $runDir "audit-request.json"

$changedFiles = @()
$unavailableEvidence = @()
try {
    $changedFiles = @(& git diff --name-only 2>$null)
    if ($LASTEXITCODE -ne 0) { $changedFiles = @(); $unavailableEvidence += "git diff unavailable" }
} catch { $unavailableEvidence += "git diff unavailable" }
if (-not $changedFiles -or $changedFiles.Count -eq 0) { $unavailableEvidence += "changed_files unavailable or empty" }

$evidence = [ordered]@{
    type = "evidence_pack"
    quest_id = $QuestId
    attempt_id = $AttemptId
    quest_prompt = $Prompt
    quest_acceptance_criteria = @()
    agents_and_outputs = @(@{ agent = $Agent; files = @($changedFiles); claim = "platform execution completed" })
    commands = @(@{ command = "$cmd $($cliArgs -join ' ')"; exit_code = $exitCode; output_ref = $runOutputFile })
    changed_files = @($changedFiles)
    diff_ref = $null
    unavailable_evidence = @($unavailableEvidence)
    created_at = (Get-Date).ToString("o")
}
$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
Write-ArtifactHash $evidencePath

$auditRequest = [ordered]@{
    type = "audit_request"
    quest_id = $QuestId
    attempt_id = $AttemptId
    evidence_pack_path = $evidencePath
    required_outputs = @("verdict", "remediation_brief when verdict is not PASS")
    reviewer = "tywin"
    advisor = "sam"
    created_at = (Get-Date).ToString("o")
}
$auditRequest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $auditRequestPath -Encoding UTF8
Write-ArtifactHash $auditRequestPath
Write-Host "  Evidence pack: $evidencePath" -ForegroundColor DarkGray
Write-Host "  Audit request: $auditRequestPath" -ForegroundColor DarkGray
Write-Host "  [NEXT] Tywin must emit verdict.json (and remediation.json on FAIL) before quest-done." -ForegroundColor Yellow

# Parse tokens used if present (best-effort)
$tokensUsed = 0
foreach ($line in $output) {
    if ($line -match "tokens.*?(\d+)") {
        $tokensUsed = [int]$Matches[1]
        break
    }
}
if ($tokensUsed -gt 0) {
    Write-Host "  Tokens used (estimated): $tokensUsed" -ForegroundColor Yellow
}

exit $exitCode
