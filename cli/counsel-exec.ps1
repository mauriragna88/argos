# counsel-exec.ps1 - Ejecuta el consejo estructurado de Sam
# ==========================================================
# Sam consume el resultado de Tywin y emite recomendacion; nunca implementa
# ni decide por Atlas.

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
if (-not $env:ARNES_ARTIFACT_HMAC_KEY) { Write-Host "  [COUNSEL BLOCKED] Define ARNES_ARTIFACT_HMAC_KEY antes de pedir consejo." -ForegroundColor Red; exit 1 }
if (-not $ArnesDir) { $ArnesDir = ".arnes" }
if (-not $AttemptId) { try { $AttemptId = (Get-Content (Join-Path $ArnesDir "loop-state.json") -Raw | ConvertFrom-Json).current_attempt_id } catch {} }
if (-not $AttemptId) { throw "AttemptId requerido." }
$runDir = Join-Path $ArnesDir (Join-Path (Join-Path "runs" $QuestId) $AttemptId)
$samInputPath = Join-Path $runDir "sam-input.json"
$counselPath = Join-Path $runDir "sam-counsel.json"

function Stop-Counsel([string]$message, [int]$code = 1) {
    Write-Host "  [COUNSEL BLOCKED] $message" -ForegroundColor Red
    exit $code
}

function Get-StrictJson([string]$text) {
    $candidate = $text.Trim()
    $candidate = $candidate -replace '^(?s)```json\s*', ''
    $candidate = $candidate -replace '(?s)\s*```$', ''
    try { return ($candidate | ConvertFrom-Json) } catch { return $null }
}

if (-not (Test-Path -LiteralPath $samInputPath -PathType Leaf)) { Stop-Counsel "No existe sam input: $samInputPath" }
try { $input = Get-Content -LiteralPath $samInputPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Stop-Counsel "sam-input.json invalido." }
if ($input.type -ne "sam_advisory_input" -or $input.quest_id -ne $QuestId -or $input.attempt_id -ne $AttemptId) { Stop-Counsel "Sam input no corresponde al intento activo." }
foreach ($path in @($input.evidence_pack_path, $input.verdict_path)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Stop-Counsel "Falta artefacto requerido para Sam: $path" }
}
try { $verdict = Get-Content -LiteralPath $input.verdict_path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Stop-Counsel "verdict.json invalido." }
if ($verdict.type -ne "verdict" -or $verdict.quest_id -ne $QuestId -or $verdict.attempt_id -ne $AttemptId) { Stop-Counsel "Veredicto no corresponde al intento activo." }
if ($verdict.verdict -ne "PASS" -and -not (Test-Path -LiteralPath $input.remediation_brief_path -PathType Leaf)) { Stop-Counsel "FAIL sin remediation brief para Sam." }

$cmd = switch ($Platform) { "opencode" { "opencode" } "codex" { "codex" } "claude" { "claude" } }
if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { Stop-Counsel "'$cmd' CLI no esta en PATH." }

$prompt = @"
Eres Sam, Elder Counselor. No escribes codigo ni tomas la decision final.
Lee el input estructurado: $samInputPath
Quest: $QuestId
Attempt: $AttemptId

Responde SOLO un objeto JSON sin markdown:
{
  "type": "sam_counsel",
  "quest_id": "$QuestId",
  "attempt_id": "$AttemptId",
  "verdict": "$($verdict.verdict)",
  "recommendation": {
    "action": "finalize | retry | pause | escalate",
    "reason": "...",
    "suggested_party": ["..."]
  },
  "risks": ["..."],
  "memory_basis": ["hecho verificable o 'insufficient historical context'"]
}
No inventes historia. Atlas decide despues de leer este consejo.
"@

$args = switch ($Platform) {
    "opencode" { @("--agent", "sam", "--prompt", $prompt) }
    "codex" { @("exec", "--skip-git-repo-check", $prompt) }
    "claude" { @("--print", $prompt) }
}

Write-Host "  SAM COUNSEL: $QuestId via $Platform" -ForegroundColor Cyan
$job = Start-Job -ScriptBlock {
    param($command, $cliArgs, $cwd)
    Set-Location $cwd
    & $command @cliArgs
    [PSCustomObject]@{ __arnes_exit_code = $LASTEXITCODE }
} -ArgumentList $cmd, $args, (Get-Location).Path
$completed = Wait-Job -Job $job -Timeout $TimeoutSec
if (-not $completed) { Stop-Job $job; Remove-Job $job -Force; Stop-Counsel "Timeout de Sam." 2 }
$result = @(Receive-Job $job); Remove-Job $job -Force
$exitRecord = @($result | Where-Object { $_ -is [PSCustomObject] -and $_.PSObject.Properties.Name -contains "__arnes_exit_code" } | Select-Object -Last 1)
$exitCode = if ($exitRecord) { [int]$exitRecord[0].__arnes_exit_code } else { 0 }
$output = @($result | Where-Object { -not ($_ -is [PSCustomObject] -and $_.PSObject.Properties.Name -contains "__arnes_exit_code") })
$outputPath = Join-Path $runDir "sam-output.txt"
$output | Set-Content -LiteralPath $outputPath -Encoding UTF8
if ($exitCode -ne 0) { Stop-Counsel "Sam CLI termino con codigo $exitCode." $exitCode }

$counsel = Get-StrictJson ($output -join [Environment]::NewLine)
if ($null -eq $counsel -or $counsel.type -ne "sam_counsel" -or $counsel.quest_id -ne $QuestId -or $counsel.attempt_id -ne $AttemptId) { Stop-Counsel "Sam no devolvio consejo JSON valido; ver $outputPath" 3 }
if ($counsel.verdict -ne $verdict.verdict -or $counsel.recommendation.action -notin @("finalize", "retry", "pause", "escalate")) { Stop-Counsel "Consejo no coincide con el veredicto o tiene accion invalida; ver $outputPath" 3 }
$counsel | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $counselPath -Encoding UTF8
Write-ArtifactHash $counselPath
Write-Host "  [OK] Sam recomienda: $($counsel.recommendation.action)" -ForegroundColor Green
Write-Host "  Counsel: $counselPath" -ForegroundColor DarkGray
