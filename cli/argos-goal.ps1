#Requires -Version 5.1
<#
.SYNOPSIS
ARNES GOAL - modo autonomo por objetivo: encadena ciclos completos hasta lograr el objetivo.

.DESCRIPTION
Recibe un OBJETIVO GLOBAL y lo persigue en iteraciones:
  1. Cada iteracion ejecuta argos-cycle.ps1 (Atlas -> Amarant -> Bard -> Party -> Tywin -> Atlas autoriza).
  2. Si Tywin falla o Atlas pide RETOQUE, la REMEDIATION se convierte en el siguiente prompt.
  3. Si pasa, Atlas genera el siguiente paso incremental hacia el objetivo.
  4. Se detiene cuando Atlas emite GOAL_COMPLETE, se alcanza MaxIterations, o hay un archivo
     de stop (.arnes/autowork-stop, creado por /autowork stop).

NO se activa solo: se lanza con `argos goal "<objetivo>"`, `/autowork <objetivo>` en el chat,
o cuando Atlas escucha "activa modo automatico <objetivo>".

.EXAMPLE
.\argos-goal.ps1 -Goal "crea la plataforma escolar completa" -MaxIterations 8
.\argos-goal.ps1 -Goal "arregla los bugs del login" -Resume
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Goal,

    [int]$MaxIterations = 8,
    [int]$PauseSeconds = 3,
    [string]$OutDir = '',
    [string]$CycleCommand = '',

    [switch]$Resume
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
if (-not $CycleCommand) { $CycleCommand = Join-Path $PSScriptRoot 'argos-cycle.ps1' }
if (-not $OutDir) { $OutDir = Join-Path (Get-Location) '.arnes\quests' }
$ArnesDir = Join-Path (Get-Location) '.arnes'
$GoalStateFile = Join-Path $ArnesDir 'goal-state.json'
$StopFlag = Join-Path $ArnesDir 'autowork-stop'

# ==== Estado persistente (sobrevive restarts / resume) ====
$iteration = 1
$nextPrompt = $Goal
$history = @()
if ($Resume -and (Test-Path $GoalStateFile)) {
    try {
        $prev = Get-Content $GoalStateFile -Raw | ConvertFrom-Json
        if ($prev.goal -eq $Goal -and $prev.status -eq 'running') {
            $iteration = [int]$prev.iteration + 1
            $nextPrompt = [string]$prev.next_prompt
            if ($prev.history) { $history = @($prev.history) }
            Write-Host ("  -> Reanudando desde iteracion {0}" -f $iteration) -ForegroundColor Yellow
        }
    } catch { }
}

function Save-GoalState {
    param([string]$Status, [string]$NextPrompt, [string]$LastVerdict, [string]$LastDecision)
    if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }
    [pscustomobject]@{
        goal           = $Goal
        iteration      = $iteration
        max_iterations = $MaxIterations
        status         = $Status
        next_prompt    = $NextPrompt
        last_verdict   = $LastVerdict
        last_decision  = $LastDecision
        history        = $history
        started_at     = $startedAt
        updated_at     = (Get-Date).ToString('o')
    } | ConvertTo-Json -Depth 6 | Set-Content -Path $GoalStateFile -Encoding UTF8
}

# ==== Contexto de memoria: historial compacto para la decision de Atlas ====
function Build-MemoryContext {
    if ($history.Count -eq 0) { return '' }
    $last = @($history | Select-Object -Last 3)
    $lines = foreach ($h in $last) {
        $pend = if ($h.remediation) { " | Pendiente: $($h.remediation)" } else { '' }
        "  Iteracion {0}: {1} | Verdict {2} | Decision {3}{4}" -f $h.iteration, $h.quest, $h.verdict, $h.decision, $pend
    }
    # Bitacora de la ultima iteracion: que se hizo y en que orden
    $lastSeq = @($history | Select-Object -Last 1)
    $seqLines = @()
    if ($lastSeq.Count -gt 0 -and $lastSeq[0].sequence) {
        foreach ($line in (([string]$lastSeq[0].sequence) -split "`n")) {
            if ($line -match '^\s*\d+\.') { $seqLines += "      $line" }
        }
    }
    $ctx = "Historial del objetivo '$Goal':`n" + ($lines -join "`n")
    if ($seqLines.Count -gt 0) {
        $ctx += "`n  Secuencia de la ultima iteracion (quien hizo que):`n" + ($seqLines -join "`n")
    }
    return $ctx
}

$startedAt = (Get-Date).ToString('o')
$verdicts = @()
Write-Host ''
Write-Host '  =====================================================' -ForegroundColor DarkRed
Write-Host '  ARNES GOAL - MODO AUTONOMO ACTIVADO' -ForegroundColor DarkRed
Write-Host ("  Objetivo: {0}" -f $Goal) -ForegroundColor White
Write-Host ("  Max iteraciones: {0} | Reanudando: {1}" -f $MaxIterations, [bool]$Resume) -ForegroundColor DarkGray
Write-Host '  Para detener en cualquier momento: Ctrl+C (o /autowork stop)' -ForegroundColor DarkGray
Write-Host '  =====================================================' -ForegroundColor DarkRed
Write-Host ''

$done = $false
$limit = $false

while ($iteration -le $MaxIterations -and -not $done) {
    # Chequeo de stop (flag creado por /autowork stop)
    if (Test-Path $StopFlag) {
        Remove-Item $StopFlag -Force -ErrorAction SilentlyContinue
        Write-Host '  -> [STOP] Modo autonomo detenido por solicitud.' -ForegroundColor Yellow
        Save-GoalState 'stopped' $nextPrompt '' ''
        exit 0
    }

    Write-Host ("`n  --- Iteracion {0}/{1} -------------------------------" -f $iteration, $MaxIterations) -ForegroundColor Cyan
    Write-Host ("  Quest: {0}" -f $nextPrompt) -ForegroundColor White
    Write-Host ''

    # Ejecutar un ciclo completo y capturar su JSON
    $memCtx = Build-MemoryContext
    $raw = & $CycleCommand -Quest $nextPrompt -Goal $Goal -MemoryContext $memCtx -EmitJson -OutDir $OutDir 2>$null | Select-Object -Last 1
    $cycle = $null
    try { $cycle = $raw | ConvertFrom-Json } catch { }

    if (-not $cycle -or -not $cycle.ok) {
        Write-Host '  [!] El ciclo no devolvio resultado JSON valido. Abortando.' -ForegroundColor Red
        Save-GoalState 'error' $nextPrompt '' ''
        exit 1
    }

    $verdicts += $cycle.verdict
    # Registrar la iteracion en el historial (alimenta la memoria de Atlas)
    $history += [pscustomobject]@{
        iteration   = $iteration
        quest       = $nextPrompt
        verdict     = $cycle.verdict
        decision    = $cycle.decision
        remediation = $cycle.remediation
        sequence    = $cycle.sequence
    }
    Write-Host ("`n  >>> Verdict Tywin: {0} | Decision Atlas: {1}" -f $cycle.verdict, $cycle.decision) -ForegroundColor Green

    # ==== Logica de continuacion: la retroalimentacion genera el siguiente prompt ====
    if ($cycle.decision -eq 'GOAL_COMPLETE') {
        $done = $true
        Save-GoalState 'done' $nextPrompt $cycle.verdict $cycle.decision
        Write-Host '  =====================================================' -ForegroundColor Green
        Write-Host ('  OK OBJETIVO LOGRADO en {0} iteracion(es).' -f $iteration) -ForegroundColor Green
        Write-Host ('    Reporte final: {0}' -f $cycle.report) -ForegroundColor DarkGray
        Write-Host '  =====================================================' -ForegroundColor Green
        break
    }

    if ($cycle.decision -eq 'RETOQUE' -or $cycle.verdict -eq 'FAIL') {
        # FAIL / RETOQUE: la remediacion de Tywin es el siguiente prompt
        $fix = if ($cycle.remediation) { $cycle.remediation } else { 'Completa lo que falto de la iteracion anterior.' }
        $nextPrompt = "Objetivo global: '$Goal'. La iteracion anterior NO completo. Retroalimentacion de Tywin: $fix. Objetivo global: '$Goal'"
        Write-Host '  -> FAIL/RETOQUE: la retroalimentacion genera el siguiente prompt.' -ForegroundColor Yellow
    } else {
        # PASS: siguiente paso incremental hacia el objetivo
        $advance = ([string]$cycle.plan) -replace "`n", ' '
        if ($advance.Length -gt 300) { $advance = $advance.Substring(0, 300) }
        $nextPrompt = "Objetivo global: '$Goal'. La iteracion anterior avanzo (PASS). Ultimo avance: $advance. Sigue con el siguiente paso incremental. Si el objetivo ya esta logrado con lo entregado, responde GOAL_COMPLETE."
        Write-Host '  -> PASS: siguiente paso incremental generado.' -ForegroundColor Cyan
    }

    Save-GoalState 'running' $nextPrompt $cycle.verdict $cycle.decision
    $iteration++

    if ($iteration -gt $MaxIterations) {
        $limit = $true
        break
    }

    if ($PauseSeconds -gt 0) {
        Write-Host ("  -> siguiente iteracion en {0}s (Ctrl+C para detener)..." -f $PauseSeconds) -ForegroundColor DarkGray
        Start-Sleep -Seconds $PauseSeconds
    }
}

if (-not $done) {
    if ($limit) {
        Write-Host ''
        Write-Host ('  [!] Limite de {0} iteraciones alcanzado sin GOAL_COMPLETE.' -f $MaxIterations) -ForegroundColor Yellow
        Write-Host '      Reanuda cuando quieras con: argos goal "<mismo objetivo>" -Resume' -ForegroundColor Yellow
        Write-Host ('      (retoma desde la iteracion {0} con el ultimo prompt)' -f $iteration) -ForegroundColor DarkGray
    }
    exit 1
}

Write-Host ''
Write-Host ("  Resumen: {0} iteracion(es) | verdicts: {1}" -f $iteration, ($verdicts -join ', ')) -ForegroundColor White
Write-Host ("  Reportes en: {0}" -f $OutDir) -ForegroundColor DarkGray
Write-Host ''
exit 0
