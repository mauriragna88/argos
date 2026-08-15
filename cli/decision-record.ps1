# decision-record.ps1 - Registra la decision explicita de Atlas
# ==============================================================
# Convierte el consejo de Sam en una decision auditable. No infiere ni
# auto-acepta recomendaciones: Atlas debe indicar la accion.

#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidatePattern("^Q-\d{3,}$")] [string]$QuestId,
    [ValidatePattern("^$|^A-\d{3,}$")] [string]$AttemptId = "",
    [Parameter(Mandatory)] [ValidateSet("finalize", "retry", "pause", "escalate")] [string]$Decision,
    [Parameter(Mandatory)] [string]$Rationale,
    [string]$ArnesDir = "",
    [switch]$OverrideCounsel
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "artifact-integrity.ps1")
if (-not $env:ARNES_ARTIFACT_HMAC_KEY) { throw "Define ARNES_ARTIFACT_HMAC_KEY antes de registrar la decision." }
if (-not $ArnesDir) { $ArnesDir = ".arnes" }
if (-not $AttemptId) { try { $AttemptId = (Get-Content (Join-Path $ArnesDir "loop-state.json") -Raw | ConvertFrom-Json).current_attempt_id } catch {} }
if (-not $AttemptId) { throw "AttemptId requerido." }
$runDir = Join-Path $ArnesDir (Join-Path (Join-Path "runs" $QuestId) $AttemptId)
$counselPath = Join-Path $runDir "sam-counsel.json"
$decisionPath = Join-Path $runDir "atlas-decision.json"

if (-not (Test-Path -LiteralPath $counselPath -PathType Leaf)) { throw "No existe consejo de Sam: $counselPath" }
$counsel = Get-Content -LiteralPath $counselPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($counsel.type -ne "sam_counsel" -or $counsel.quest_id -ne $QuestId -or $counsel.attempt_id -ne $AttemptId) { throw "El consejo no corresponde al intento activo." }
if (-not $OverrideCounsel -and $Decision -ne $counsel.recommendation.action) {
    throw "Decision '$Decision' difiere del consejo '$($counsel.recommendation.action)'. Usa -OverrideCounsel y explica el motivo."
}

$record = [ordered]@{
    type = "atlas_decision"
    quest_id = $QuestId
    attempt_id = $AttemptId
    decision = $Decision
    rationale = $Rationale
    sam_counsel_path = $counselPath
    counsel_action = $counsel.recommendation.action
    overrides_counsel = [bool]$OverrideCounsel
    decided_at = (Get-Date).ToString("o")
}
$record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $decisionPath -Encoding UTF8
Write-ArtifactHash $decisionPath
Write-Host "  [OK] Atlas decision: $Decision" -ForegroundColor Green
Write-Host "  Decision: $decisionPath" -ForegroundColor DarkGray
