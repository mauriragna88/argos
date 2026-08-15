#Requires -Version 5.1
<#
.SYNOPSIS
ARNES CYCLE - Ciclo orquestador NATIVO completo (sin opencode)

.DESCRIPTION
Ciclo RPG completo con el motor propio (argos-engine.ps1):
  1. ATLAS   -> detecta el quest, decide el PARTY y el plan general
  2. AMARANT -> plan tecnico (SDD: pasos concretos, archivos)
  3. BARD    -> MEJORA CONTINUA: que falta, que no se menciono, que agregar (relacionado al proyecto)
  4. PARTY   -> cada especialista ejecuta su parte con SU modelo asignado
  5. TYWIN   -> verifica contra el plan (PASS/FAIL + remediation)
  6. ATLAS   -> autoriza (FINALIZAR) o pide RETOQUE
Guarda reporte en .arnes/quests/ y registra mejoras/verdict en la memoria (arnes.db).

.EXAMPLE
.\argos-cycle.ps1 -Quest "haz un login form con Zod y RLS en Supabase"
.\argos-cycle.ps1 -Quest "crea la API de productos con validacion" -OutDir .\.arnes\quests
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Quest,

    [string]$OutDir = '',

    # Modo objetivo autonomo: argos-goal.ps1 encadena ciclos con estos flags
    [string]$Goal = '',
    [switch]$EmitJson,

    # Contexto de memoria: historial de iteraciones previas del objetivo.
    # Atlas lo usa para decidir el party/plan y para autorizar (FINALIZAR/RETOQUE/GOAL_COMPLETE).
    [string]$MemoryContext = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'osma-resolve.ps1')
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Engine = Join-Path $PSScriptRoot 'argos-engine.ps1'
$Mem = (Get-OsmaMemoryCli)
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
$ModelsPath = Join-Path $GlobalConfigDir 'agent-models.json'
if (-not $OutDir) { $OutDir = Join-Path (Get-Location) '.arnes\quests' }

# === Modelos asignados (config GLOBAL de la maquina) ===
$am = @{}
if (Test-Path $ModelsPath) {
    $raw = Get-Content $ModelsPath -Raw | ConvertFrom-Json
    foreach ($a in $raw.agents.PSObject.Properties) { $am[$a.Name] = [string]$a.Value }
}
function Get-AgentModel($key) {
    if ($am.ContainsKey($key) -and $am[$key]) { return $am[$key] }
    return 'opencode-go/gpt-5.6-luna'
}

# === Persona RPG del agente (con reparacion de mojibake) ===
function Get-AgentPrompt {
    param([string]$Key)
    $candidates = @()
    if ($Key -eq 'atlas') { $candidates += (Join-Path $Root 'core\atlas-player.agent.md') }
    $candidates += (Join-Path $Root "core\classes\$Key.agent.md")
    $candidates += (Join-Path $Root "core\auditors\$Key.agent.md")
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $text = [System.IO.File]::ReadAllText($c)
            try {
                $cp1252 = [System.Text.Encoding]::GetEncoding(1252)
                $utf8 = New-Object System.Text.UTF8Encoding($false)
                $fixed = foreach ($line in ($text -split "`n")) {
                    try {
                        $cand = $utf8.GetString($cp1252.GetBytes($line))
                        $chk = $cp1252.GetString($utf8.GetBytes($cand))
                        if ($chk -eq $line -and $cand -ne $line) { $cand } else { $line }
                    } catch { $line }
                }
                $text = $fixed -join "`n"
            } catch {}
            # Persona COMPLETA para Atlas (orquestador tier, recibe prompts largos);
            # el motor sanitiza controles que rompen las APIs
            return $text.Trim()
        }
    }
    return ''
}

# === Ejecutar un paso del ciclo con el motor nativo ===
$script:stepLog = New-Object System.Collections.ArrayList
$script:stepNum = 0
$script:stepTotal = 6
function Run-Step {
    param([string]$AgentKey, [string]$Title, [string]$System, [string]$Msg, [int]$Max = 600)

    $script:stepNum++
    $model = Get-AgentModel $AgentKey
    Write-Host ''
    Write-Host ("  â•â•â• {0}/{1} {2} â•â•â•" -f $script:stepNum, $script:stepTotal, $Title) -ForegroundColor Cyan
    Write-Host ("  [agente: {0,-8} | modelo: {1}]" -f $AgentKey, $model) -ForegroundColor DarkGray

    $r = & $Engine -Model $model -System $System -Message $Msg -MaxTokens $Max
    if ($r.ok) {
        Write-Host ''
        Write-Host "  $($r.reply)" -ForegroundColor White
        if ($r.usage) {
            Write-Host ("  [uso: {0} tkns]" -f $r.usage.total_tokens) -ForegroundColor DarkGray
        }
    } else {
        Write-Host ("  [!] " + $r.error) -ForegroundColor Yellow
        Write-Host "  [paso omitido]" -ForegroundColor DarkGray
    }
    [void]$script:stepLog.Add([pscustomobject]@{
        step = $Title; agent = $AgentKey; model = $model; ok = $r.ok;
        reply = $(if ($r.ok) { $r.reply } else { $r.error });
        tokens = $(if ($r.usage) { $r.usage.total_tokens } else { 0 })
    })
    return $r
}

$partyList = 'vivi, ansem, kuja'
$plan = $Quest
$mejoras = ''
$partyResults = @()
$verdict = 'FAIL'
$decision = 'RETOQUE'

# === AUTO-INIT: el entorno se inicializa solo (casi forzoso), sin preguntar ===
$projArnes = Join-Path (Get-Location) '.arnes'
$gConn = Join-Path $env:USERPROFILE '.config\arnes\connections.json'
$gModels = Join-Path $env:USERPROFILE '.config\arnes\agent-models.json'
$db = Join-Path $Root '.arnes\arnes.db'
$missing = @()
if (-not (Test-Path $projArnes)) { $missing += 'entorno del proyecto (.arnes)' }
if (-not (Test-Path $gConn)) { $missing += 'conexiones globales' }
if (-not (Test-Path $gModels)) { $missing += 'modelos por agente' }
if (-not (Test-Path $db)) { $missing += 'memoria (arnes.db)' }
if ($missing.Count -gt 0) {
    Write-Host ("  ▸ [AUTO-INIT] inicializando: " + ($missing -join ', ')) -ForegroundColor Yellow
    if (-not (Test-Path $projArnes)) { New-Item -ItemType Directory -Path $projArnes -Force | Out-Null }
    & (Join-Path $PSScriptRoot 'argos-connect.ps1') init | Out-Null
    if (-not (Test-Path $gModels)) { & (Join-Path $PSScriptRoot 'argos.ps1') init 2>&1 | Out-Null }
    if (-not (Test-Path $db)) {
        $mem = (Get-OsmaMemoryCli)
        if (Test-Path $mem) { & $mem init 2>&1 | Out-Null }
    }
    Write-Host '  ▸ [AUTO-INIT] entorno listo (contexto, conexiones, modelos y memoria).' -ForegroundColor Green
}

# ============ 0. MEMORIA: recall previo (ARGOS+OSMA unificados) ============
# Consulta OSMA ANTES de planear: lecciones de quests parecidos + experiencias
# validadas reutilizables. Atlas arranca con memoria, no desde cero.
$memContext = ''
if ($MemoryContext) {
    $memContext = $MemoryContext
} elseif (Test-Path $Mem) {
    $memRecall = ''
    $memExp = ''
    try { $memRecall = (& $Mem recall -Query $Quest -Limit 5 -Quiet 2>$null | Out-String).Trim() } catch {}
    try { $memExp = (& $Mem experience -ExperienceAction search -Query $Quest -Limit 3 -Quiet 2>$null | Out-String).Trim() } catch {}
    if ($memRecall -and $memRecall -notmatch 'Sin recuerdos|^$|^\[\]$') { $memContext += "RECUERDOS DE QUESTS PARECIDOS:`n$memRecall`n" }
    if ($memExp -and $memExp -notmatch 'Sin experiencias|^$|^\[\]$') { $memContext += "EXPERIENCIAS VALIDADAS REUTILIZABLES:`n$memExp`n" }
    if ($memContext) {
        Write-Host '' -ForegroundColor DarkGray
        Write-Host '  ▸ [OSMA] Memoria consultada: lecciones de quests parecidos cargadas para Atlas.' -ForegroundColor DarkGray
    }
}

# ============ 1. ATLAS: orquesta ============
$atlasSystem = (Get-AgentPrompt 'atlas')
if (-not $atlasSystem) { $atlasSystem = 'Eres Atlas, orquestador de un harness RPG. Nunca codeas: planeas, delega y autorizas.' }
$atlasMsg = "Quest del usuario: $Quest`n`nDecide el PARTY (agentes especialistas) y el plan general.`nFormato EXACTO:`nPARTY: nombre1, nombre2, nombre3`nPLAN: <resumen del plan en 2-3 lineas>`nElige el party de esta lista: vivi, ansem, kuja, eiko, amarant, eremez, auron, bran, quina, varys, tywin, sam, bard, tidus, ragnarok"
if ($memContext) {
    $atlasMsg += "`n`nCONTEXTO DE MEMORIA (lecciones de quests previos, evita repetir errores):`n$memContext`n`nUsa este contexto para decidir el party y el plan: evita repetir lo ya hecho y ataca lo pendiente."
}
$atlasR = Run-Step 'atlas' 'ATLAS - ORQUESTA' $atlasSystem $atlasMsg 4000
if ($atlasR.ok) {
    $m = [regex]::Match($atlasR.reply, 'PARTY:\s*(.+)')
    if ($m.Success) {
        $partyList = ($m.Groups[1].Value -replace '[^a-z, ]', '').Trim()
    }
}

# ============ 2. AMARANT: plan tecnico ============
$amarantSystem = (Get-AgentPrompt 'amarant')
if (-not $amarantSystem) { $amarantSystem = 'Eres Amarant, arquitecto y planner. No codeas: planificas con pasos concretos.' }
$amarantMsg = "Quest: $Quest`n`nPlan general (Atlas): $plan`n`nProduce el PLAN TECNICO: pasos concretos (que archivos/componentes tocar, que validar, que integrar). Formato markdown con pasos numerados."
$amarantR = Run-Step 'amarant' 'AMARANT - PLAN TECNICO' $amarantSystem $amarantMsg 4000
if ($amarantR.ok) { $plan = $amarantR.reply }

# ============ 3. BARD: mejora continua ============
$bardSystem = (Get-AgentPrompt 'bard')
if (-not $bardSystem) { $bardSystem = 'Eres Bard, el agente de mejora continua. Siempre atento a mejorar lo que se planea.' }
$bardMsg = "Quest: $Quest`n`nPlan tecnico:`n$plan`n`nMEJORA CONTINUA: revisa el plan. Di:`nFALTA: <que faltaria>`nNO SE MENCIONO: <que no se menciono y conviene>`nAGREGAR: <que otra cosa se puede meter, SOLO si tiene que ver con el proyecto>`nSe breve y concreto."
$bardR = Run-Step 'bard' 'BARD - MEJORA CONTINUA' $bardSystem $bardMsg 3000
if ($bardR.ok) { $mejoras = $bardR.reply }

# ============ 4. PARTY: cada especialista ejecuta su parte ============
$members = @($partyList -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -ne 'atlas' })
if ($members.Count -eq 0) { $members = @('vivi', 'ansem', 'kuja') }
# --- SEGURIDAD AUTOMATICA: Auron entra si el quest toca auth/RLS/secrets/deploy ---
$securityKeywords = 'auth|login|password|token|secret|rls|row.level|supabase.*policy|apikey|api.key|ssl|https|cors|sanitize|inyeccion|injection|deploy|produccion|production|permisos|roles|encrypt|hash'
$questLower = $Quest.ToLower()
if ($questLower -match $securityKeywords) {
    if ($members -notcontains 'auron') {
        $members += 'auron'
        Write-Host '' -ForegroundColor Yellow
        Write-Host '  ▸ [AURON] Quest con superficie de seguridad detectada: Auron se une al party automaticamente.' -ForegroundColor Yellow
    }
}
$script:stepTotal = 3 + $members.Count + 2   # atlas + amarant + bard + party + tywin + atlas-final
$roleHint = @{
    'vivi' = 'Frontend: React/Next.js/Tailwind. Entrega componentes y estilos.'
    'ansem' = 'Backend: APIs, Supabase, Zod, logica de negocio. Entrega endpoints y validaciones.'
    'kuja' = 'QA: tests, edge cases, seguridad. Entrega casos de prueba y hallazgos.'
    'eiko' = 'DevOps: builds, CI/CD, deploy. Entrega pipeline y config.'
    'amarant' = 'Arquitectura: estructura y decisiones tecnicas.'
    'eremez' = 'Research: librerias y mejores practicas.'
    'auron' = 'Seguridad: auditoria, RLS, auth, secrets.'
    'bran' = 'Analisis: estado y progreso.'
    'quina' = 'Tokens: costo y presupuesto del quest.'
    'varys' = 'Tracker: seguimiento y evidencia.'
    'tywin' = 'Verificacion: criterios de aceptacion.'
    'sam' = 'Consejo estrategico.'
    'bard' = 'Mejora y redaccion.'
    'tidus' = 'Infra: recursos y entorno.'
    'ragnarok' = 'Compras: herramientas y proveedores.'
}
$i = 1
$memberSummaries = @()
foreach ($member in $members) {
    $persona = (Get-AgentPrompt $member)
    $hint = if ($roleHint.ContainsKey($member)) { $roleHint[$member] } else { 'Ejecuta tu parte del plan.' }
    $sys = if ($persona) { $persona + "`n`nTu rol en este quest: $hint" } else { "Eres $member. $hint" }
    $msg = "Quest: $Quest`n`nPlan tecnico (Amarant):`n$plan`n`nEjecuta TU parte. Entrega un resultado concreto y accionable."
    $r = Run-Step $member ("PARTY - $($member.ToUpper())") $sys $msg 4000
    if ($r.ok) {
        $partyResults += $r.reply
        # Memoria del agente: que hizo y que dejo pendiente (para futuras decisiones de Atlas)
        $summary = ([string]$r.reply) -replace "`n", ' '
        if ($summary.Length -gt 200) { $summary = $summary.Substring(0, 200) }
        $memberSummaries += "  - ${member}: $summary"
        try {
            if (Test-Path $Mem) {
                & $Mem save -Agent $member -Topic "${member}/executions/$questId" -Type 'execution' -Content "Quest: $Quest | Entrego: $summary" 2>$null
            }
        } catch { }
    }
    $i++
}

# ============ 5. TYWIN: verifica ============
$tywinSystem = (Get-AgentPrompt 'tywin')
if (-not $tywinSystem) { $tywinSystem = 'Eres Tywin, el verificador. Emites verdict PASS/FAIL con evidencia.' }
$resultsText = if ($partyResults.Count -gt 0) { ($partyResults -join "`n`n---`n`n") } else { '(party sin resultados)' }
$tywinMsg = "Quest: $Quest`n`nPlan (Amarant):`n$plan`n`nResultado del party:`n$resultsText`n`nEmiti: VERDICT: PASS o FAIL. Luego EVIDENCIA (2-3 puntos). Si FAIL, REMEDIATION (que falta)."
$tywinR = Run-Step 'tywin' 'TYWIN - VERIFICA' $tywinSystem $tywinMsg 3000
if ($tywinR.ok) {
    $verdict = if ($tywinR.reply -match 'VERDICT:\s*(PASS|FAIL)') { $Matches[1] } else { 'FAIL' }
}

# ============ 6. ATLAS: autoriza ============
$atlasFinalMsg = "Quest: $Quest`n`nPlan:`n$plan`n`nVerdict de Tywin: $verdict`n`nDecision: responde 'DECISION: FINALIZAR' si el trabajo cumple, o 'DECISION: RETOQUE: <que falta>' si hay que ajustar."
if ($MemoryContext) {
    $atlasFinalMsg += "`n`nCONTEXTO DE MEMORIA (historial del objetivo):`n$MemoryContext`n`nEvalua si lo entregado en ESTA iteracion + lo previo cubren el objetivo, o si aun falta trabajo."
}
if ($Goal) {
    $atlasFinalMsg += "`n`nObjetivo GLOBAL: '$Goal'. Si con lo entregado el objetivo global YA esta logrado, responde 'DECISION: GOAL_COMPLETE' en vez de FINALIZAR."
}
$atlasFinalR = Run-Step 'atlas' 'ATLAS - AUTORIZA' $atlasSystem $atlasFinalMsg 3000
if ($atlasFinalR.ok) {
    if ($atlasFinalR.reply -match 'DECISION:\s*FINALIZAR') { $decision = 'FINALIZAR' }
    elseif ($atlasFinalR.reply -match 'DECISION:\s*GOAL_COMPLETE') { $decision = 'GOAL_COMPLETE' }
    elseif ($atlasFinalR.reply -match 'DECISION:\s*RETOQUE:\s*(.+)') { $decision = 'RETOQUE' }
}

# ============ Reporte + memoria ============
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$questId = "quest-$ts"

# ==== Bitacora de secuencia (Varys): que se hizo y en que orden ====
$bitacora = @()
$stepIdx = 0
foreach ($s in $script:stepLog) {
    $stepIdx++
    $status = if ($s.ok) { 'OK' } else { 'OMITIDO' }
    $short = ([string]$s.reply) -replace "`n", ' '
    if ($short.Length -gt 120) { $short = $short.Substring(0, 120) }
    $bitacora += ("  {0}. [{1}] {2} ({3}) - {4}" -f $stepIdx, $s.agent, $s.step, $status, $short)
}
$remediation = ''
if ($tywinR.ok -and $tywinR.reply -match 'REMEDIATION:\s*(.+)') { $remediation = $Matches[1].Trim() }
$bitacoraText = $bitacora -join "`n"
$report = @"
# ARNES CYCLE - Reporte de quest
**Quest**: $Quest
**ID**: $questId
**Fecha**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Verdict Tywin**: $verdict
**Decision Atlas**: $decision

## Party
$partyList

## Plan tecnico (Amarant)
$plan

## Mejora continua (Bard)
$mejoras

## Resultado del party
$resultsText

## Verificacion (Tywin)
$(if ($tywinR.ok) { $tywinR.reply } else { 'sin respuesta' })

## Bitacora de secuencia (Varys) - que se hizo y en que orden
$bitacoraText
"@
$reportPath = Join-Path $OutDir "$questId.md"
$report | Set-Content -Path $reportPath -Encoding UTF8

$log = [pscustomobject]@{
    quest = $Quest
    quest_id = $questId
    timestamp = (Get-Date).ToString('o')
    verdict = $verdict
    decision = $decision
    party = $partyList
    sequence = $bitacoraText
    steps = $script:stepLog
}
$log | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $OutDir "$questId.json") -Encoding UTF8

# Mejoras + verdict a la memoria (arnes.db) para mejora continua entre quests
try {
    if (Test-Path $Mem) {
        & $Mem save -Agent 'bard' -Topic "bard/mejoras/$questId" -Type 'recommendation' -Content "Quest: $Quest | Mejoras: $mejoras" 2>$null
        & $Mem save -Agent 'tywin' -Topic "tywin/verdicts/$questId" -Type 'verdict' -Content "Quest: $Quest | Verdict: $verdict | Decision: $decision" 2>$null
        # Varys: bitacora de secuencia - quien hizo que y en que orden (la linea de tiempo del quest)
        & $Mem save -Agent 'varys' -Topic "varys/evidence-packs/$questId" -Type 'evidence' -Content "Quest: $Quest | Verdict: $verdict | Decision: $decision`n$bitacoraText" 2>$null
        # Debrief completo: que se hizo, que falta (la fuente de verdad para la proxima decision de Atlas)
        $debrief = "Quest: $Quest | Verdict: $verdict | Decision: $decision"
        if ($decision -eq 'RETOQUE' -and $tywinR.ok -and $tywinR.reply -match 'REMEDIATION:\s*(.+)') {
            $debrief += " | PENDIENTE: " + $Matches[1].Trim()
        }
        if ($memberSummaries.Count -gt 0) {
            $debrief += "`nAgentes:`n" + ($memberSummaries -join "`n")
        }
        & $Mem save -Agent 'atlas' -Topic "atlas/debriefs/$questId" -Type 'debrief' -Content $debrief 2>$null
    }
} catch {}

# === Experiencia VALIDADA V5: el ciclo completo queda como experiencia reutilizable ===
# PASS -> reward 0.9 (verified, se reutiliza en problemas parecidos)
# FAIL/RETOQUE -> reward -0.8 (evita repetir la ruta que fallo)
try {
    if (Test-Path $Mem) {
        $projName = (Split-Path (Get-Location) -Leaf)
        $expSituation = $Quest
        $expReasoning = "Ciclo ARGOS: party [$partyList]. Plan de Amarant + mejoras de Bard."
        $expConclusion = "Verdict Tywin: $verdict. Decision Atlas: $decision."
        $expAction = "Party ejecuto: " + (($memberSummaries | Select-Object -First 2) -join ' | ')
        $expOutcome = "Quest $questId completado con verdict $verdict."
        $reward = if ($verdict -eq 'PASS' -and $decision -ne 'RETOQUE') { 0.9 } elseif ($verdict -eq 'FAIL' -or $decision -eq 'RETOQUE') { -0.8 } else { 0.3 }
        & $Mem experience -ExperienceAction record -Situation $expSituation -Reasoning $expReasoning -Conclusion $expConclusion -Action $expAction -Outcome $expOutcome -Reward $reward -Project $projName -Agent 'atlas' -Quiet 2>$null | Out-Null
    }
} catch {}

Write-Host ''
Write-Host '  ═══════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ("  CICLO COMPLETO | Verdict: {0} | Decision: {1}" -f $verdict, $decision) -ForegroundColor Green
$totalTokens = @($script:stepLog | Measure-Object -Property tokens -Sum).Sum
Write-Host ("  Tokens totales del ciclo: {0}" -f $totalTokens) -ForegroundColor DarkGray
Write-Host ("  Reporte: {0}" -f $reportPath) -ForegroundColor DarkGray
Write-Host '  ═══════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''

# === Checkpoint cognitivo natural al completar el quest ===
try {
    $memCli = (Get-OsmaMemoryCli)
    if (Test-Path $memCli) {
        $next = if ($decision -eq 'RETOQUE') { "Retomar quest por RETOQUE de Tywin: $Quest" } elseif ($decision -eq 'GOAL_COMPLETE') { 'Objetivo global logrado' } else { 'Siguiente quest del backlog' }
        & $memCli checkpoint -Create -QuestId $questId -Agent 'atlas' -Goal $Quest -Phase 'cycle-complete' -Completed $questId -Pending $(if ($decision -eq 'RETOQUE') { @('retoque pendiente') } else { @() }) -Decisions @() -Skill '' -NextAction $next -Quiet 2>$null | Out-Null
    }
} catch {}

# === Salida JSON para el driver de objetivo autonomo (argos-goal.ps1) ===
if ($EmitJson) {
    [pscustomobject]@{
        ok          = $true
        quest_id    = $questId
        quest       = $Quest
        verdict     = $verdict
        decision    = $decision
        remediation = $remediation
        plan        = $plan
        sequence    = $bitacoraText
        report      = $reportPath
        goal        = $Goal
    } | ConvertTo-Json -Depth 4 -Compress | Write-Output
}
