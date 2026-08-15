# ============================================================
# STUB de argos-cycle.ps1 para tests de arnes-goal (hermetico)
#
# NO llama a APIs. Devuelve JSON identico al ciclo real segun
# el conteo de invocaciones:
#   1a llamada  -> verdict FAIL, decision RETOQUE, remediation fija
#   2a llamada  -> verdict PASS, decision GOAL_COMPLETE
#   ARNES_FAKE_ALWAYS_FAIL=1 -> siempre FAIL (para test de limite)
#
# Uso (desde argos-goal.ps1): -CycleCommand <path de este stub>
# ============================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Quest,
    [string]$Goal = '',
    [switch]$EmitJson,
    [string]$OutDir = '',
    [string]$MemoryContext = ''
)

$ErrorActionPreference = 'Stop'
$workDir = (Get-Location).Path
$stateFile = Join-Path $workDir '.arnes\stub-count.txt'
$count = 0
if (Test-Path $stateFile) {
    $count = [int](Get-Content $stateFile -Raw).Trim()
}
$count++
Set-Content -Path $stateFile -Value "$count" -Encoding UTF8

$alwaysFail = ($env:ARNES_FAKE_ALWAYS_FAIL -eq '1')

if ($alwaysFail -or $count -eq 1) {
    $result = [pscustomobject]@{
        ok          = $true
        quest_id    = "quest-stub-$count"
        quest       = $Quest
        verdict     = 'FAIL'
        decision    = 'RETOQUE'
        remediation = 'falta la API de login con validacion Zod'
        plan        = "Plan stub ${count}: login, validacion, RLS"
        sequence    = "  1. [atlas] ATLAS - ORQUESTA (OK) - party: vivi, ansem`n  2. [vivi] PARTY - VIVI (OK) - login UI" + $count
        report      = 'stub-report.md'
        goal        = $Goal
    }
} else {
    $result = [pscustomobject]@{
        ok          = $true
        quest_id    = "quest-stub-$count"
        quest       = $Quest
        verdict     = 'PASS'
        decision    = 'GOAL_COMPLETE'
        remediation = ''
        plan        = "Plan stub ${count}: todo entregado"
        sequence    = "  1. [atlas] ATLAS - ORQUESTA (OK) - party: vivi, ansem`n  2. [ansem] PARTY - ANSEM (OK) - API login" + $count
        report      = 'stub-report.md'
        goal        = $Goal
    }
}

if ($EmitJson) {
    $result | ConvertTo-Json -Depth 4 -Compress | Write-Output
}
