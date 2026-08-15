# audit-exec.ps1 - Ejecuta la auditoria independiente de Tywin
# =============================================================
# Consume el audit-request de Varys y solo persiste artefactos si Tywin
# responde con el JSON estricto esperado. Nunca corrige codigo.

#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet("opencode", "codex", "claude")] [string]$Platform,
    [Parameter(Mandatory)] [ValidatePattern("^Q-\d{3,}$")] [string]$QuestId,
    [ValidatePattern("^$|^A-\d{3,}$")] [string]$AttemptId = "",
    [string]$ArnesDir = "",
    [int]$TimeoutSec = 600
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot "artifact-integrity.ps1")
if (-not $env:ARNES_ARTIFACT_HMAC_KEY) { Write-Host "  [AUDIT BLOCKED] Define ARNES_ARTIFACT_HMAC_KEY antes de auditar." -ForegroundColor Red; exit 1 }
if (-not $ArnesDir) { $ArnesDir = ".arnes" }
if (-not $AttemptId) { try { $AttemptId = (Get-Content (Join-Path $ArnesDir "loop-state.json") -Raw | ConvertFrom-Json).current_attempt_id } catch {} }
if (-not $AttemptId) { throw "AttemptId requerido." }
$runDir = Join-Path $ArnesDir (Join-Path (Join-Path "runs" $QuestId) $AttemptId)
$requestPath = Join-Path $runDir "audit-request.json"
$verdictPath = Join-Path $runDir "verdict.json"
$remediationPath = Join-Path $runDir "remediation.json"
$samInputPath = Join-Path $runDir "sam-input.json"

function Stop-Audit([string]$message, [int]$code = 1) {
    Write-Host "  [AUDIT BLOCKED] $message" -ForegroundColor Red
    exit $code
}

function Get-StrictJson([string]$text) {
    $candidate = $text.Trim()
    $candidate = $candidate -replace '^(?s)```json\s*', ''
    $candidate = $candidate -replace '(?s)\s*```$', ''
    try { return ($candidate | ConvertFrom-Json) } catch { return $null }
}

if (-not (Test-Path -LiteralPath $requestPath -PathType Leaf)) { Stop-Audit "No existe audit request: $requestPath" }
try { $request = Get-Content -LiteralPath $requestPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Stop-Audit "audit-request.json invalido." }
if ($request.type -ne "audit_request" -or $request.quest_id -ne $QuestId -or $request.attempt_id -ne $AttemptId) { Stop-Audit "audit request no corresponde al intento activo." }
if (-not (Test-Path -LiteralPath $request.evidence_pack_path -PathType Leaf)) { Stop-Audit "No existe evidence pack indicado por Varys." }
try { $evidence = Get-Content -LiteralPath $request.evidence_pack_path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Stop-Audit "evidence.json invalido." }
if ($evidence.type -ne "evidence_pack" -or $evidence.quest_id -ne $QuestId -or $evidence.attempt_id -ne $AttemptId) { Stop-Audit "evidence pack no corresponde al intento activo." }

$cmd = switch ($Platform) { "opencode" { "opencode" } "codex" { "codex" } "claude" { "claude" } }
if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { Stop-Audit "'$cmd' CLI no esta en PATH." }

$prompt = @"
Eres Tywin, auditor independiente. NO escribas codigo, NO asignes agentes y NO inventes evidencia.
Audita exclusivamente este evidence pack: $($request.evidence_pack_path)
Quest: $QuestId
Attempt: $AttemptId

Responde SOLO un objeto JSON sin markdown:
{
  "verdict": {
    "type": "verdict",
    "quest_id": "$QuestId",
    "attempt_id": "$AttemptId",
    "verdict": "PASS | FAIL_PARTIAL | FAIL_TOTAL",
    "checks": [{"category":"...","status":"PASS|FAIL","evidence":"..."}],
    "reason": "..."
  },
  "remediation_brief": null
}

Si verdict no es PASS, remediation_brief es OBLIGATORIO y debe tener:
{"type":"remediation_brief","quest_id":"$QuestId","attempt_id":"$AttemptId","items":[{"check":"...","file":"...","symbol_or_area":"...","line_or_range":"...|unknown","evidence":"...","expected_outcome":"...","closure_validation":"..."}]}
"@

$args = switch ($Platform) {
    "opencode" { @("--agent", "tywin", "--prompt", $prompt) }
    "codex" { @("exec", "--skip-git-repo-check", $prompt) }
    "claude" { @("--print", $prompt) }
}

Write-Host "  TYWIN AUDIT: $QuestId via $Platform" -ForegroundColor Cyan
$job = Start-Job -ScriptBlock {
    param($command, $cliArgs, $cwd)
    Set-Location $cwd
    & $command @cliArgs
    [PSCustomObject]@{ __arnes_exit_code = $LASTEXITCODE }
} -ArgumentList $cmd, $args, (Get-Location).Path
$completed = Wait-Job -Job $job -Timeout $TimeoutSec
if (-not $completed) { Stop-Job $job; Remove-Job $job -Force; Stop-Audit "Timeout de Tywin." 2 }
$result = @(Receive-Job $job); Remove-Job $job -Force
$exitRecord = @($result | Where-Object { $_ -is [PSCustomObject] -and $_.PSObject.Properties.Name -contains "__arnes_exit_code" } | Select-Object -Last 1)
$exitCode = if ($exitRecord) { [int]$exitRecord[0].__arnes_exit_code } else { 0 }
$output = @($result | Where-Object { -not ($_ -is [PSCustomObject] -and $_.PSObject.Properties.Name -contains "__arnes_exit_code") })
$outputPath = Join-Path $runDir "tywin-output.txt"
$output | Set-Content -LiteralPath $outputPath -Encoding UTF8
if ($exitCode -ne 0) { Stop-Audit "Tywin CLI termino con codigo $exitCode." $exitCode }

$bundle = Get-StrictJson ($output -join [Environment]::NewLine)
if ($null -eq $bundle -or $null -eq $bundle.verdict) { Stop-Audit "Tywin no devolvio JSON estricto; ver $outputPath" 3 }
$verdict = $bundle.verdict
if ($verdict.type -ne "verdict" -or $verdict.quest_id -ne $QuestId -or $verdict.attempt_id -ne $AttemptId -or $verdict.verdict -notin @("PASS", "FAIL_PARTIAL", "FAIL_TOTAL")) { Stop-Audit "Veredicto invalido; ver $outputPath" 3 }
if ($verdict.verdict -ne "PASS") {
    $brief = $bundle.remediation_brief
    if ($null -eq $brief -or $brief.type -ne "remediation_brief" -or $brief.quest_id -ne $QuestId -or $brief.attempt_id -ne $AttemptId -or -not $brief.items -or @($brief.items).Count -eq 0) { Stop-Audit "FAIL sin remediation brief valido; ver $outputPath" 3 }
    $brief | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $remediationPath -Encoding UTF8
    Write-ArtifactHash $remediationPath
}
$verdict | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $verdictPath -Encoding UTF8
Write-ArtifactHash $verdictPath

$samInput = [ordered]@{
    type = "sam_advisory_input"
    quest_id = $QuestId
    attempt_id = $AttemptId
    evidence_pack_path = $request.evidence_pack_path
    verdict_path = $verdictPath
    remediation_brief_path = if ($verdict.verdict -eq "PASS") { $null } else { $remediationPath }
    required_decision = "Atlas must consume Sam counsel before finalizing or retrying."
}
$samInput | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $samInputPath -Encoding UTF8
Write-ArtifactHash $samInputPath
Write-Host "  [OK] Tywin verdict: $($verdict.verdict)" -ForegroundColor Green
Write-Host "  Sam input: $samInputPath" -ForegroundColor DarkGray
