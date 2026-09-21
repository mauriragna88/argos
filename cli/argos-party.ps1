#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS PARTY - Orquestacion multiagente AUTONOMA (Atlas decide, el party ejecuta)

.DESCRIPTION
Quest grande con UN prompt:
1. ATLAS (top-tier, 1 llamada) clasifica, elige party y descompone en epics (task graph)
2. Scheduler: ejecuta tareas listas (deps satisfechas) EN PARALELO, cada agente con SU modelo
3. Contratos/resultados estructurados (Atlas lee resumenes, no transcripts)
4. Retry con escalacion de modelo (flash -> pro) y limites
5. Tywin verifica milestones; Atlas autoriza FINALIZAR
6. Estado en arnes.db (sobrevive restart/compaction) + memoria + checkpoint

.EXAMPLE
.\argos-party.ps1 -Quest "Crea una plataforma web para una escuela con login, calificaciones y avisos"
.\argos-party.ps1 -Quest "..." -Mode safe
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Quest,

    [ValidateSet('safe', 'balanced', 'autonomous')]
    [string]$Mode = 'balanced',

    [int]$MaxIterations = 20,

    [int]$Budget = 120000
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'osma-resolve.ps1')
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Engine = Join-Path $PSScriptRoot 'argos-engine.ps1'
$Mem = (Get-OsmaMemoryCli)
# argos party usa quest/atask (tracking real) - sin OSMA no hay scheduler: abortar con aviso.
if (-not (Test-OsmaInstalled)) {
    Write-Host ''
    Write-Host '  [!] argos party necesita la memoria OSMA (tracking de quests/tareas).' -ForegroundColor Yellow
    Write-Host '      Instala la memoria:  argos osma-install   (o: osma/install.ps1)' -ForegroundColor Cyan
    Write-Host '      O usa:  argos code "<quest>"  (sin party, funciona sin memoria)' -ForegroundColor DarkGray
    exit 1
}
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
$ModelsPath = Join-Path $GlobalConfigDir 'agent-models.json'
$WorkDir = (Get-Location).Path
$questId = ('quest-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))

# ============ AUTO-INIT ============
$projArnes = Join-Path $WorkDir '.arnes'
if (-not (Test-Path $projArnes)) { New-Item -ItemType Directory -Path $projArnes -Force | Out-Null }
if (-not (Test-Path (Join-Path $env:USERPROFILE '.config\arnes\connections.json'))) { & (Join-Path $PSScriptRoot 'argos-connect.ps1') init | Out-Null }
if (-not (Test-Path (Join-Path $GlobalConfigDir 'agent-models.json'))) { & (Join-Path $PSScriptRoot 'argos.ps1') init 2>&1 | Out-Null }
if (-not (Test-Path (Join-Path $Root '.arnes\arnes.db'))) { & $Mem init -Quiet | Out-Null }

# ============ MODELOS por agente (fuente de verdad) ============
$am = @{}
if (Test-Path $ModelsPath) {
    $raw = Get-Content $ModelsPath -Raw | ConvertFrom-Json
    foreach ($a in $raw.agents.PSObject.Properties) { $am[$a.Name] = [string]$a.Value }
}
function Get-AgentModel($k) { if ($am.ContainsKey($k) -and $am[$k]) { return $am[$k] }; return 'opencode-go/deepseek-v4-flash' }

# ============ PERSONA (con reparacion de mojibake) ============
function Get-Persona {
    param([string]$Key)
    $cands = @()
    if ($Key -eq 'atlas') { $cands += (Join-Path $Root 'core\atlas-player.agent.md') }
    $cands += (Join-Path $Root "core\classes\$Key.agent.md")
    $cands += (Join-Path $Root "core\auditors\$Key.agent.md")
    # Los agentes usan su nombre RPG (vivi/ansem) pero los archivos usan la clase (mage/paladin)
    $classAlias = @{ 'vivi'='mage'; 'ansem'='paladin'; 'kuja'='rogue'; 'eiko'='cleric'; 'amarant'='monk'; 'eremez'='ranger' }
    if ($classAlias.ContainsKey($Key)) {
        $cands += (Join-Path $Root "core\classes\$($classAlias[$Key]).agent.md")
        $cands += (Join-Path $Root "core\auditors\$($classAlias[$Key]).agent.md")
    }
    foreach ($c in $cands) {
        if (Test-Path $c) {
            $text = [System.IO.File]::ReadAllText($c)
            try {
                $cp1252 = [System.Text.Encoding]::GetEncoding(1252)
                $utf8 = New-Object System.Text.UTF8Encoding($false)
                $fixed = foreach ($line in ($text -split "`n")) {
                    try { $cand = $utf8.GetString($cp1252.GetBytes($line)); $chk = $cp1252.GetString($utf8.GetBytes($cand)); if ($chk -eq $line -and $cand -ne $line) { $cand } else { $line } } catch { $line }
                }
                $text = $fixed -join "`n"
            } catch {}
            return $text.Trim()
        }
    }
    return ''
}

# ============ SKILLS por agente (auto-injection del skill registry) ============
# Cada rol carga sus skills (.agents/skills/) como metodologia obligatoria.
# Fuente de verdad del mapa: .atl/skill-registry.md
function Get-AgentSkills {
    param([string]$Key)
    $skillMap = @{
        'vivi'    = @('vivi-design-principles', 'vivi-visual-excellence', 'ui-ux-pro-max', 'taste-skill', 'vivi-motion-design', 'vivi-visual-qa', 'need-info-escalation')
        'ansem'   = @('postgres-best-practices', 'need-info-escalation')
        'kuja'    = @('verification-before-completion', 'need-info-escalation')
        'tywin'   = @('verification-before-completion')
        'amarant' = @('writing-plans', 'need-info-escalation')
        'ragnarok' = @('ceo-vision')
        'maestro' = @('prompt-refinement', 'need-info-escalation')
        'bard'    = @('taste-skill')
        'atlas'   = @('handoff', 'need-info-escalation')
        'eiko'    = @('handoff', 'need-info-escalation')
    }
    $skills = @()
    $names = @()
    if ($skillMap.ContainsKey($Key)) { $names = @($skillMap[$Key]) }
    foreach ($s in $names) {
        $p = Join-Path $Root ".agents\skills\$s\SKILL.md"
        # Fallback: skills canonicas del arnes que viven en core/skills/v2 (ej. vivi-visual-excellence)
        if (-not (Test-Path $p)) { $p = Join-Path $Root "core\skills\v2\$s\SKILL.md" }
        if (Test-Path $p) {
            try {
                $raw = [System.IO.File]::ReadAllText($p)
                $body = $raw -replace '(?s)^---.*?---\s*', ''
                $skills += ("### SKILL: {0}`n{1}" -f $s, $body.Trim())
            } catch {}
        }
    }
    return ($skills -join "`n`n")
}

# ============ UI helpers ============
$script:ui = @()
function Show-Progress {
    param($Progress)
    $bar = ('█' * [Math]::Floor($Progress.pct / 10)) + ('░' * (10 - [Math]::Floor($Progress.pct / 10)))
    Write-Host ''
    Write-Host ("  Quest {0}  [{1}] {2}%" -f $questId, $bar, $Progress.pct) -ForegroundColor Cyan
    Write-Host ("  PASS {0}  RUNNING {1}  READY {2}  BLOCKED {3}  FAIL {4}" -f $Progress.pass, $Progress.running, $Progress.ready, $Progress.blocked, $Progress.fail) -ForegroundColor White
}

# ============ 1. ATLAS DESCOMPONE (1 llamada top-tier) ============
Write-Host ''
Write-Host '  ╔══════════════════════════════════════════════════════════════╗' -ForegroundColor DarkRed
Write-Host '  ║   ARGOS AUTONOMOUS PARTY - Atlas decide, el party ejecuta  ║' -ForegroundColor White
Write-Host '  ╚══════════════════════════════════════════════════════════════╝' -ForegroundColor DarkRed
Write-Host ("  Quest: {0}" -f $Quest) -ForegroundColor Yellow
Write-Host ("  Modo: {0} | Budget: {1} tkns" -f $Mode, $Budget) -ForegroundColor DarkGray
Write-Host ''

# ============ 0-pre. MAESTRO REFINE (triage V2 -> prompt architect) ============
# Si el quest del usuario es vago/ambiguo (vagueness >= 31), MAESTRO lo refina
# a prompt profesional (objetivo/alcance/criterios) ANTES de que Atlas descomponga.
# Quests claros pasan directo (cero friccion). Boss/architecture SIEMPRE pasan por Maestro.
$detectorScript = Join-Path $PSScriptRoot 'quest-detector.ps1'
$needsMaestro = $false
$triage = $null
if (Test-Path $detectorScript) {
    try {
        $triageJson = & $detectorScript -Prompt $Quest -Json -NoLog -SkipOsma -NoStyle 2>$null
        if ($triageJson) {
            $triage = $triageJson | ConvertFrom-Json
            if ($triage.vagueness_score -ge 31 -or $triage.quest_type -in @('boss','architecture')) {
                $needsMaestro = $true
            }
        }
    } catch {}
}
if ($needsMaestro) {
    $reason = if ($triage -and $triage.vagueness_score -ge 31) { "prompt vago (vagueness $($triage.vagueness_score)/100)" } else { "quest $($triage.quest_type) (siempre pasa por Maestro)" }
    Write-Host ("  ▸ [MAESTRO] Refinando quest: {0}..." -f $reason) -ForegroundColor Magenta
    $maestroPersona = Get-Persona 'maestro'
    if (-not $maestroPersona) { $maestroPersona = 'Eres Maestro, Prompt Architect de ARNES. Refinas pedidos crudos en prompts profesionales.' }
    $maestroSkills = Get-AgentSkills 'maestro'
    $maestroSystem = $maestroPersona
    if ($maestroSkills) { $maestroSystem += "`n`n[SKILLS DEL ROL]`n$maestroSkills" }
    $maestroMsg = @"
Refina este pedido del usuario en un prompt profesional. Formato EXACTO (solo JSON):
{
  "refined_quest": "prompt refinado completo en una sola string (con OBJETIVO, ALCANCE INCLUYE/EXCLUYE, CRITERIOS DE ACEPTACION verificables, RESTRICCIONES)",
  "clarify_questions": ["pregunta 1 si falta info critica", "pregunta 2 (max 3)"],
  "quest_type": "frontend|backend|fix|architecture|research|devops|boss",
  "suggested_party": ["agentes", "segun", "dominio"]
}
Reglas: NO inventes requisitos. Vacios criticos -> clarify_questions. Traduce informalidad a especificidad.
PEDIDO DEL USUARIO: $Quest
"@
    $maestroR = & $Engine -Model (Get-AgentModel 'maestro') -System $maestroSystem -Message $maestroMsg -MaxTokens 1500
    if ($maestroR.ok) {
        $mj = [regex]::Match($maestroR.reply, '(?s)\{.*\}')
        if ($mj.Success) {
            try {
                $mp = $mj.Value | ConvertFrom-Json
                if ($mp.refined_quest) {
                    # El quest refinado reemplaza al crudo para TODO el pipeline
                    $Quest = [string]$mp.refined_quest
                    Write-Host ("  [OK] Maestro refinó el quest ({0} chars)." -f $Quest.Length) -ForegroundColor Green
                    # Preguntas de clarificacion: Atlas pregunta al usuario ANTES de descomponer
                    if ($mp.clarify_questions -and $mp.clarify_questions.Count -gt 0) {
                        Write-Host '  ═══ MAESTRO NECESITA ACLARAR ANTES DE CONTINUAR ═══' -ForegroundColor Yellow
                        foreach ($cq in $mp.clarify_questions) { Write-Host ("   ? {0}" -f $cq) -ForegroundColor White }
                        try {
                            $userAns = Read-Host '   Tu respuesta (Enter = continuar con supuestos de Maestro)'
                            if ($userAns) {
                                $Quest = "$Quest`n`nRESPUESTAS DEL USUARIO: $userAns"
                                # aprendizaje acumulativo: preferencias del usuario en OSMA
                                try { & $Mem save -Agent maestro -Topic "user/answers/refine" -Type preference -Content ("PREGUNTAS: $($mp.clarify_questions -join ' | ') | RESPUESTA: $userAns") -Score 3 -Quiet 2>$null | Out-Null } catch {}
                            }
                        } catch {}
                    }
                    # quest type / party sugerido por Maestro quedan como hint en el quest refinado
                    if ($mp.quest_type -or $mp.suggested_party) {
                        $Quest = "$Quest`n`nHINT MAESTRO: tipo=$($mp.quest_type) party=[$($mp.suggested_party -join ',')]"
                    }
                }
            } catch {
                Write-Host ("  [!] Maestro no entrego JSON valido - se usa el quest original. ({0})" -f $_.Exception.Message) -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host '  [!] Maestro fallo - se usa el quest original.' -ForegroundColor Yellow
    }
    Write-Host ''
}

# ============ 0. MEMORIA: recall previo (ARGOS+OSMA unificados) ============
# Consulta OSMA ANTES de descomponer: lecciones de quests parecidos + experiencias
# validadas reutilizables. Atlas descompone con memoria, no desde cero.
$memContext = ''
if (Test-Path $Mem) {
    $memRecall = ''
    $memExp = ''
    try { $memRecall = (& $Mem recall -Query $Quest -Limit 5 -Quiet 2>$null | Out-String).Trim() } catch {}
    try { $memExp = (& $Mem experience -ExperienceAction search -Query $Quest -Limit 3 -Quiet 2>$null | Out-String).Trim() } catch {}
    if ($memRecall -and $memRecall -notmatch 'Sin recuerdos|^$|^\[\]$') { $memContext += "RECUERDOS DE QUESTS PARECIDOS:`n$memRecall`n" }
    if ($memExp -and $memExp -notmatch 'Sin experiencias|^$|^\[\]$') { $memContext += "EXPERIENCIAS VALIDADAS REUTILIZABLES:`n$memExp`n" }
    if ($memContext) {
        Write-Host '  ▸ [OSMA] Memoria consultada: lecciones de quests parecidos cargadas para Atlas.' -ForegroundColor DarkGray
    }
}

# ============ 0b. BLACKBOARD COMPARTIDO (retroalimentacion entre agentes) ============
# Lee shared-blackboard.json ANTES de que Atlas decida el party: trust_scores por agente,
# party_config_history (que party funciono para este tipo de quest), failed_attempts,
# patrones reusables y agentes bloqueados. Atlas elige party con retroalimentacion historica,
# no solo por keywords.
$bbContext = ''
$blackboardPath = Join-Path $ArnesDir 'shared-blackboard.json'
if (Test-Path $blackboardPath) {
    try {
        $bb = Get-Content $blackboardPath -Raw | ConvertFrom-Json
        # 1. trust_scores: quien esta caliente y quien va bajando
        $trustLines = @()
        if ($bb.trust_scores) {
            foreach ($p in $bb.trust_scores.PSObject.Properties) {
                $ts = $p.Value
                $score = [double]$ts.score
                $trend = [string]$ts.trend
                $failCount = [int]$ts.recent_fail_count
                $flag = ''
                if ($failCount -gt 0) { $flag = ' [!! fallos recientes]' }
                elseif ($trend -eq 'falling') { $flag = ' [bajando]' }
                elseif ($trend -eq 'rising') { $flag = ' [subiendo]' }
                elseif ($score -ge 0.9) { $flag = ' [confiable]' }
                $trustLines += ("    - {0}: trust {1:N2} ({2}){3}" -f $p.Name, $score, $trend, $flag)
            }
        }
        if ($trustLines.Count -gt 0) {
            $bbContext += "TRUST SCORES POR AGENTE (quien es confiable para esta tarea):`n" + ($trustLines -join "`n") + "`n"
        }
        # 2. party_config_history: que party funciono para este tipo de quest
        $histLines = @()
        if ($bb.party_config_history) {
            foreach ($h in @($bb.party_config_history)) {
                $histLines += ("    - {0}: party [{1}] -> {2:N0}% exito ({3} quests)" -f $h.quest_type, ($h.party -join ','), ([double]$h.success_rate * 100), $h.total_quests)
            }
        }
        if ($histLines.Count -gt 0) {
            $bbContext += "PARTY CONFIG HISTORICA (que party funciono para cada tipo de quest):`n" + ($histLines -join "`n") + "`n"
        }
        # 3. failed_attempts: errores pasados para no repetir
        $failLines = @()
        if ($bb.failed_attempts) {
            foreach ($f in @($bb.failed_attempts | Select-Object -First 3)) {
                $failLines += ("    - [{0}] {1}: {2}" -f $f.quest_id, $f.agent, $f.error)
            }
        }
        if ($failLines.Count -gt 0) {
            $bbContext += "ERRORES PASADOS (no repetir):`n" + ($failLines -join "`n") + "`n"
        }
        # 4. agentes bloqueados por circuit breaker: NUNCA asignar
        $blockedList = @()
        if ($bb.circuit_breaker_state -and $bb.circuit_breaker_state.blocked_agents) {
            $blockedList = @($bb.circuit_breaker_state.blocked_agents)
        }
        if ($blockedList.Count -gt 0) {
            $bbContext += "AGENTES BLOQUEADOS (NO asignar a esta tarea): " + ($blockedList -join ', ') + "`n"
        }
        if ($bbContext) {
            Write-Host '  ▸ [BLACKBOARD] Retroalimentacion historica (trust/party/errores) cargada para Atlas.' -ForegroundColor DarkGray
        }
    } catch {
        Write-Host ("  [!] Blackboard ilegible: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
}

$atlasSystem = (Get-Persona 'atlas')
if (-not $atlasSystem) { $atlasSystem = 'Eres Atlas, orquestador de un harness RPG. Nunca codeas: planeas, delega, autoriza.' }
$roster = @('vivi','ansem','kuja','eiko','amarant','eremez','auron','bran','quina','varys','tywin','sam','bard','tidus','ragnarok')

# mapeo clase -> agente (Atlas a veces devuelve la CLASE en vez del nombre del agente)
$classMap = @{
    'mage' = 'vivi'; 'paladin' = 'ansem'; 'rogue' = 'kuja'; 'cleric' = 'eiko'
    'monk' = 'amarant'; 'ranger' = 'eremez'; 'archivist' = 'sam'; 'bard' = 'bard'
    'seer' = 'bran'; 'banker' = 'quina'; 'spider' = 'varys'; 'verifier' = 'tywin'
    'warden' = 'auron'; 'player' = 'atlas'; 'alchemist' = 'bard'
}
function Normalize-Agent {
    param([string]$Name)
    $n = $Name.Trim().ToLower()
    if ($classMap.ContainsKey($n)) { $n = $classMap[$n] }
    if ($n -in $roster) { return $n }
    return ''
}
$atlasMsg = @"
Quest del usuario: $Quest

Descompone la quest en TAREAS (workstreams) y elige el PARTY. Formato EXACTO (solo JSON):
{
  "party": ["amarant", "vivi", "ansem", "kuja", ...],
  "epics": [
    {"id": "ARC-01", "title": "...", "agent": "amarant", "deps": [], "acceptance": "...", "files": ["src/lib/auth.ts"]},
    {"id": "AUTH-01", "title": "...", "agent": "ansem", "deps": ["ARC-01"], "acceptance": "...", "files": ["src/api/auth/route.ts"]}
  ]
}
Reglas:
- Crea SOLO las tareas necesarias (2-6 max). Quest trivial = 1-2 tareas.
- NO dupliques trabajo: cada archivo/entregable lo toca UNA sola tarea. Si dos tareas tocarian el mismo archivo, fusiona o divide por fases.
- "files" = archivos que la tarea va a modificar (rutas relativas, para controlar colisiones en paralelo).
- Cada tarea con UN agente del roster. Dependencias por id. No inventes agentes.
"@
if ($memContext) {
    $atlasMsg += "`nCONTEXTO DE MEMORIA (lecciones de quests previos, evita repetir errores):`n$memContext`nUsa este contexto para descomponer y elegir party: evita repetir lo ya hecho y ataca lo pendiente.`n"
}
if ($bbContext) {
    $atlasMsg += "`nRETROALIMENTACION HISTORICA (blackboard compartido entre agentes):`n$bbContext`nUsa esto para elegir el party: prefiere agentes con trust alto para este tipo de tarea, evita agentes bloqueados, y si un party ya funciono para este tipo de quest, consideralo.`n"
}
Write-Host '  ▸ ATLAS descomponiendo y eligiendo party...' -ForegroundColor Cyan
$atlasR = & $Engine -Model (Get-AgentModel 'atlas') -System $atlasSystem -Message $atlasMsg -MaxTokens 2500
$party = @('vivi', 'ansem', 'kuja')
$epics = @()
if ($atlasR.ok) {
    $jsonMatch = [regex]::Match($atlasR.reply, '(?s)\{.*\}')
    if ($jsonMatch.Success) {
        try {
            $parsed = $jsonMatch.Value | ConvertFrom-Json
            if ($parsed.party) {
                $party = @($parsed.party | ForEach-Object { Normalize-Agent $_ } | Where-Object { $_ } | Select-Object -First 8)
                if ($party.Count -eq 0) { $party = @('vivi', 'ansem', 'kuja') }
            }
            # --- SEGURIDAD AUTOMATICA: Auron entra si el quest toca auth/RLS/secrets/deploy ---
            $securityKeywords = 'auth|login|password|token|secret|rls|row.level|supabase.*policy|apikey|api.key|ssl|https|cors|sanitize|inyeccion|injection|deploy|produccion|production|permisos|roles|encrypt|hash'
            if ($Quest.ToLower() -match $securityKeywords -and $party -notcontains 'auron') {
                $party += 'auron'
                Write-Host '       [AURON] Quest con superficie de seguridad detectada: Auron se une al party automaticamente.' -ForegroundColor Yellow
            }
            if ($parsed.epics) {
                $epics = @($parsed.epics | Select-Object -First 10)
                # normalizar agente de cada tarea (clase -> agente)
                foreach ($e in $epics) { $e.agent = (Normalize-Agent ([string]$e.agent)) }
                $epics = @($epics | Where-Object { $_.agent })
                Write-Host ("       [OK] party: {0} | {1} tareas" -f ($party -join ', '), $epics.Count) -ForegroundColor Green
            }
        } catch {}
    }
}
if ($epics.Count -eq 0) {
    # fallback deterministico por keywords
    Write-Host '       [!] Atlas no entrego JSON valido - fallback por keywords' -ForegroundColor Yellow
    $epics = @(
        @{ id = 'T-01'; title = $Quest; agent = 'ansem'; deps = @(); acceptance = 'implementar la base del quest' }
    )
}

# ============ 2. CREAR QUEST + TAREAS (con dedupe de solapadas) ============
& $Mem aquest -Create -QuestId $questId -Goal $Quest -Phase $Mode -Quiet | Out-Null
$seenFiles = @{}
$seenTitles = @{}
foreach ($e in $epics) {
    $tid = [string]$e.id
    $title = ([string]$e.title).Trim()
    # dedupe: misma descripcion o mismo archivo ya asignado a otra tarea
    $normTitle = ($title -replace '[^a-z0-9]', '').ToLower()
    if ($seenTitles.ContainsKey($normTitle)) { Write-Host ("       - omitida duplicada: {0}" -f $tid) -ForegroundColor DarkGray; continue }
    $seenTitles[$normTitle] = $true
    $deps = @($e.deps | ForEach-Object { [string]$_ })
    & $Mem atask -Create -QuestId $questId -TaskId $tid -Agent ([string]$e.agent) -Content $title -TaskDeps $deps -Acceptance ([string]$e.acceptance) -Quiet | Out-Null
}
Write-Host ("  [OK] Quest {0} registrada" -f $questId) -ForegroundColor Green

# ============ 3. SCHEDULER AUTONOMO ============
function Parse-TaskResult {
    param([string]$Text)
    $r = @{ status = 'FAIL'; summary = ''; files = @(); tests = ''; blockers = @(); need_info = @() }
    # extraer el bloque estructurado del pipeline
    if ($Text -match '(?s)\[ARGOS_TASK_RESULT\](.*)$') { $Text = $Matches[1] }
    if ($Text -match 'STATUS:\s*(PASS|FAIL|NEED_INFO)') { $r.status = $Matches[1] }
    if ($Text -match '(?s)SUMMARY:\s*(.+?)(\n[A-Z_]+:|$)') { $r.summary = $Matches[1].Trim() }
    if ($Text -match '(?s)FILES_CHANGED:\s*(.+?)(\n[A-Z_]+:|$)') { $r.files = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    if ($Text -match 'TESTS:\s*(.+)') { $r.tests = $Matches[1].Trim() }
    if ($Text -match '(?s)BLOCKERS:\s*(.+?)(\n[A-Z_]+:|$)') { $r.blockers = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    # NEED_INFO protocol: el agente declara que le falta informacion (no adivina)
    if ($Text -match '(?s)NEED_INFO:(.*?)(\nSTATUS:|$)') {
        $niBlock = $Matches[1]
        $qs = [regex]::Matches($niBlock, 'QUESTION:\s*(.+)')
        foreach ($m in $qs) { $r.need_info += $m.Groups[1].Value.Trim() }
    }
    # fallback legacy: sin STATUS pero con lenguaje de exito
    if ($Text -notmatch 'STATUS:' -and $Text -match 'implemented|completed|done|pasa|listo|cre[oó]') { $r.status = 'PASS' }
    return $r
}

$totalTokens = 0
$iteration = 0
$finalVerdict = 'FAIL'
$script:needInfoTasks = @()   # NEED_INFO: tareas esperando respuesta del usuario

while ($iteration -lt $MaxIterations) {
    $iteration++
    $progress = (& $Mem aquest -QuestId $questId -Quiet | ConvertFrom-Json)
    Show-Progress $progress
    if ($progress.pass -eq $progress.total -and $progress.total -gt 0) {
        $finalVerdict = 'PASS'
        break
    }
    if ($progress.blocked -eq $progress.total -and $progress.total -gt 0) { Write-Host '  [!] Todas las tareas bloqueadas.' -ForegroundColor Red; break }
    if ($totalTokens -gt $Budget) { Write-Host '  [!] Budget de tokens agotado.' -ForegroundColor Red; break }
    if ($progress.fail -gt 0 -and $progress.ready -eq 0 -and $progress.running -eq 0) { Write-Host '  [!] Tareas fallidas sin retry posible - escalar a Atlas.' -ForegroundColor Yellow; break }

    # tareas listas
    $ready = @(& $Mem atask -List -QuestId $questId -Status 'pending' -Quiet | ConvertFrom-Json | ForEach-Object { $_ })
    $readyTasks = @($ready | Where-Object { $_.status -eq 'pending' } | Select-Object -First 6)

    # CONTROL DE COLISION DE ARCHIVOS: si dos tareas paralelas tocan el mismo archivo,
    # lanzar una ahora y diferir la otra (evita ediciones simultaneas peligrosas)
    $launchSet = @()
    $launchedFiles = @()
    foreach ($t in $readyTasks) {
        $tFiles = @([regex]::Matches($t.description, '[\w/\\-]+\.\w+') | ForEach-Object { $_.Value.ToLower().Replace('\', '/') })
        $conflict = @($tFiles | Where-Object { $launchedFiles -contains $_ })
        if ($conflict.Count -gt 0) {
            Write-Host ("  ⏸ {0} en espera (colision de archivo con tarea en paralelo)" -f $t.task_id) -ForegroundColor DarkGray
            continue
        }
        $launchSet += $t
        $launchedFiles += $tFiles
    }
    if ($launchSet.Count -eq 0) {
        if ($readyTasks.Count -eq 0) { Write-Host '  (esperando dependencias o sin tareas listas)' -ForegroundColor DarkGray; Start-Sleep -Seconds 2; continue }
        Write-Host '  (todas las listas colisionan entre si - se ejecutaran en la siguiente pasada)' -ForegroundColor DarkGray
        Start-Sleep -Seconds 2
        continue
    }

    # lanzar en PARALELO (jobs reales, cada uno con el modelo del agente + herramientas de coding)
    $jobs = @()
    foreach ($t in $launchSet) {
        $model = Get-AgentModel $t.agent
        $persona = Get-Persona $t.agent
        if (-not $persona) { $persona = "Eres $($t.agent), especialista de ARNES ARGOS." }
        $agentSkills = Get-AgentSkills $t.agent
        $contract = @"
$persona
"@ + $(if ($agentSkills) { "`n`n[SKILLS DEL ROL — metodologia obligatoria para este agente]`n$agentSkills" }) + @"

[ARGOS TASK CONTRACT]
Quest: $Quest
Task: $($t.task_id) - $($t.description)
Acceptance: $($t.acceptance)

Reglas:
- Trabajas en: $WorkDir (usa rutas relativas)
- Usa las herramientas de coding para crear/editar archivos REALES.
- Entrega resultado REAL, no placeholders.
- Al terminar responde con formato EXACTO:
STATUS: PASS|FAIL
SUMMARY: <resumen corto>
FILES_CHANGED: <archivo1, archivo2>
TESTS: <resultado>
BLOCKERS: <nada o lista>
"@
        & $Mem atask -Id $t.id -Status 'running' -Quiet | Out-Null
        Write-Host ("  ══ {0} [{1}] inicia ({2})" -f $t.task_id, $t.agent, $model) -ForegroundColor Cyan
        # Cada tarea = coding-agent con SU modelo + herramientas + -Auto (autonomo)
        $job = Start-Job -ScriptBlock {
            param($codeCli, $ag, $taskText, $contractExtra, $wd)
            Set-Location $wd   # Start-Job NO hereda el CWD - trabajar en el proyecto real
            # 6>&1 captura Write-Host (stream de informacion) - sin esto el resultado llega vacio
            $r = & $codeCli -Quest $taskText -Agent $ag -Auto -SystemExtra $contractExtra 2>&1 6>&1 | Out-String
            [pscustomobject]@{ ok = $true; reply = $r; tokens = 0 } | ConvertTo-Json -Compress
        } -ArgumentList (Join-Path $PSScriptRoot 'argos-code.ps1'), $t.agent, ("TAREA $($t.task_id): " + $t.description + " | Aceptacion: " + $t.acceptance), $contract, $WorkDir
        $jobs += @{ task = $t; job = $job }
    }

    foreach ($j in $jobs) {
        $t = $j.task
        $null = Wait-Job $j.job -Timeout 600   # tareas de coding pueden tardar
        $state = $j.job.State
        $out = @(Receive-Job $j.job)
        Remove-Job $j.job -Force
        if ($state -eq 'Running') {
            Write-Host ("  ✗ {0} excedio el tiempo ({1})" -f $t.task_id, $t.agent) -ForegroundColor Red
            & $Mem atask -Id $t.id -Status 'fail' -Attempts ($t.attempts + 1) -Quiet | Out-Null
            continue
        }
        $raw = ($out -join '')
        $res = $null
        try { $res = $raw | ConvertFrom-Json } catch {}
        if (-not $res -or -not $res.ok) {
            Write-Host ("  ✗ {0} fallo de ejecucion ({1})" -f $t.task_id, $(if ($res) { $res.reply } else { 'sin respuesta' })) -ForegroundColor Red
            $attempts = $t.attempts + 1
            & $Mem atask -Id $t.id -Status 'fail' -Attempts $attempts -Quiet | Out-Null
            continue
        }
        $totalTokens += $res.tokens
        $parsed = Parse-TaskResult $res.reply
        Write-Host ("  ✓ {0} [{1}] -> {2}" -f $t.task_id, $t.agent, $parsed.status) -ForegroundColor $(if ($parsed.status -eq 'PASS') { 'Green' } else { 'Red' })
        if ($parsed.summary) { Write-Host ("      {0}" -f $parsed.summary) -ForegroundColor DarkGray }
        if ($parsed.tests) { Write-Host ("      tests: {0}" -f $parsed.tests) -ForegroundColor DarkGray }
        $attempts = $t.attempts + 1
        if ($parsed.status -eq 'PASS') {
            & $Mem atask -Id $t.id -Status 'pass' -Summary $parsed.summary -Attempts $attempts -TokensUsed $res.tokens -Quiet | Out-Null
            & $Mem save -Agent $t.agent -Topic ("party/" + $questId + "/" + $t.task_id) -Type action -Content ("Task $($t.task_id) PASS: " + $parsed.summary) -Score 3 -Quiet | Out-Null
        } elseif ($parsed.status -eq 'NEED_INFO' -and $parsed.need_info.Count -gt 0) {
            # === PROTOCOLO NEED_INFO: el agente no adivina, Atlas pregunta al usuario ===
            # La tarea queda 'blocked' con las preguntas; Atlas consolida al final del ciclo.
            & $Mem atask -Id $t.id -Status 'blocked' -Summary ("NEED_INFO: " + ($parsed.need_info -join ' | ')) -Attempts $attempts -Blockers @('need_info') -Quiet | Out-Null
            Write-Host ("  ? {0} [{1}] necesita info: {2}" -f $t.task_id, $t.agent, ($parsed.need_info -join ' | ')) -ForegroundColor Yellow
            $script:needInfoTasks += @{ task = $t; agent = $t.agent; questions = $parsed.need_info }
        } else {
            # retry con escalacion (flash -> pro -> blocked)
            if ($attempts -ge 4) {
                & $Mem atask -Id $t.id -Status 'blocked' -Summary ($parsed.summary + ' (agotado retries)') -Attempts $attempts -Blockers $parsed.blockers -Quiet | Out-Null
                Write-Host ("      ⛔ {0} bloqueada tras {1} intentos" -f $t.task_id, $attempts) -ForegroundColor Yellow
            } else {
                # retry con intento incrementado (escalacion de estrategia; modelos por config)
                & $Mem atask -Id $t.id -Status 'pending' -Summary ('retry ' + $attempts) -Attempts $attempts -Quiet | Out-Null
                Write-Host ("      ↻ {0} reintento {1}" -f $t.task_id, $attempts) -ForegroundColor Yellow
            }
        }
    }

    # === CONSOLIDACION NEED_INFO: si hay tareas esperando info, Atlas pregunta UNA vez ===
    if (Get-Variable -Name needInfoTasks -Scope Script -ErrorAction SilentlyContinue -ValueOnly) {
        if ($script:needInfoTasks.Count -gt 0) {
            Write-Host ''
            Write-Host '  ═══ ATLAS NECESITA TU RESPUESTA PARA CONTINUAR ═══' -ForegroundColor Yellow
            $allQ = @()
            foreach ($ni in $script:needInfoTasks) {
                foreach ($q in $ni.questions) {
                    $allQ += "[{0}/{1}] {2}" -f $ni.task.task_id, $ni.agent, $q
                    Write-Host ("   ? {0}" -f $q) -ForegroundColor White
                }
            }
            Write-Host ('   Responde y relanzo las tareas afectadas (' + $script:needInfoTasks.Count + ').') -ForegroundColor Yellow
            try {
                $userAnswer = Read-Host '   Tu respuesta (Enter = usar defaults/omitir)'
                foreach ($ni in $script:needInfoTasks) {
                    # re-lanzar la tarea con la respuesta inyectada en el contexto
                    & $Mem atask -List -QuestId $questId -Status 'blocked' -Quiet 2>$null | ConvertFrom-Json | ForEach-Object {
                        if ($_.task_id -eq $ni.task.task_id) {
                            & $Mem atask -Id $_.id -Status 'pending' -Summary ('need-info resuelto por usuario: ' + $userAnswer) -Quiet | Out-Null
                        }
                    }
                    # guardar la Q&A en OSMA: aprendizaje acumulativo de preferencias
                    foreach ($q in $ni.questions) {
                        & $Mem save -Agent $ni.agent -Topic "user/answers/$questId" -Type preference -Content ("PREGUNTA: $q | RESPUESTA: $userAnswer") -Score 3 -Quiet 2>$null | Out-Null
                    }
                }
                $script:needInfoTasks = @()
            } catch {}
        }
    }

    # Tywin verifica milestone (cada 3 tareas completadas o al final)
    $prog2 = (& $Mem aquest -QuestId $questId -Quiet | ConvertFrom-Json)
    if (($prog2.pass % 3 -eq 0 -and $prog2.pass -gt 0) -or $prog2.pass -eq $prog2.total) {
        Write-Host '  ▸ TYWIN verificando milestone...' -ForegroundColor Magenta
        $done = @(& $Mem atask -List -QuestId $questId -Status 'pass' -Quiet | ConvertFrom-Json)
        $summ = ($done | Select-Object -Last 5 | ForEach-Object { "[$($_.task_id) $($_.agent)] $($_.summary)" }) -join "`n"
        $tywin = & $Engine -Model (Get-AgentModel 'tywin') -System 'Eres Tywin, verificador. Emite VERDICT PASS o FAIL con evidencia.' -Message ("Milestone de: $Quest`nResultados:`n$summ`nVERDICT: PASS si todo cumple, FAIL + REMEDIATION si no.") -MaxTokens 600
        if ($tywin.ok -and $tywin.reply -match 'VERDICT:\s*PASS') { Write-Host '       [TYWIN] milestone PASS' -ForegroundColor Green } else { Write-Host '       [TYWIN] milestone FAIL - se reabren tareas' -ForegroundColor Yellow }
    }
}

# ============ 4. ATLAS AUTORIZA ============
$finalProg = (& $Mem aquest -QuestId $questId -Quiet | ConvertFrom-Json)
Write-Host ''
Write-Host '  ═══════════════════════════════════════════' -ForegroundColor Cyan
if ($finalVerdict -eq 'PASS') {
    $done2 = @(& $Mem atask -List -QuestId $questId -Status 'pass' -Quiet | ConvertFrom-Json)
    $finalMsg = "Quest: $Quest`nResultados del party:`n" + (($done2 | ForEach-Object { "[$($_.task_id) $($_.agent)] " + $_.summary }) -join "`n") + "`nAutoriza FINALIZAR o pide retoques."
    $atlasFinal = & $Engine -Model (Get-AgentModel 'atlas') -System $atlasSystem -Message $finalMsg -MaxTokens 500
    Write-Host ("  PARTY COMPLETO | Verdict: {0}" -f $finalVerdict) -ForegroundColor Green
    if ($atlasFinal.ok) { Write-Host ("  Atlas: {0}" -f $atlasFinal.reply) -ForegroundColor White }
} else {
    Write-Host ("  PARTY INCOMPLETO | Verdict: {0} | tokens: {1}" -f $finalVerdict, $totalTokens) -ForegroundColor Yellow
}
Write-Host ("  Tokens del party: {0} | iteraciones: {1}" -f $totalTokens, $iteration) -ForegroundColor DarkGray
Write-Host '  ═══════════════════════════════════════════' -ForegroundColor Cyan

# checkpoint + persistencia
try {
    $next = if ($finalVerdict -eq 'PASS') { 'Siguiente quest del backlog' } else { "Retomar quest $questId (tareas pendientes/fallidas)" }
    & $Mem checkpoint -Create -QuestId $questId -Agent 'atlas' -Goal $Quest -Phase "party-$finalVerdict" -Completed @((& $Mem atask -List -QuestId $questId -Status 'pass' -Quiet | ConvertFrom-Json | ForEach-Object { $_.task_id })) -Pending @((& $Mem atask -List -QuestId $questId -Status 'pending' -Quiet | ConvertFrom-Json | ForEach-Object { $_.task_id })) -NextAction $next -Quiet 2>$null | Out-Null
} catch {}

# === Experiencia VALIDADA V5: el party completo queda como experiencia reutilizable ===
try {
    if (Test-Path $Mem) {
        $projName = (Split-Path (Get-Location) -Leaf)
        $doneTasks = @(& $Mem atask -List -QuestId $questId -Status 'pass' -Quiet | ConvertFrom-Json)
        $expReasoning = "Party autonomo ARGOS: party [$($party -join ', ')], $($epics.Count) tareas, modo $Mode."
        $expAction = "Tareas PASS: " + (($doneTasks | Select-Object -First 3 | ForEach-Object { "$($_.task_id): $($_.summary)" }) -join ' | ')
        $expOutcome = "Quest $questId con verdict $finalVerdict ($iteration iteraciones, $totalTokens tkns)."
        $reward = if ($finalVerdict -eq 'PASS') { 0.9 } else { -0.8 }
        & $Mem experience -ExperienceAction record -Situation $Quest -Reasoning $expReasoning -Conclusion "Verdict final del party: $finalVerdict." -Action $expAction -Outcome $expOutcome -Reward $reward -Project $projName -Agent 'atlas' -Quiet 2>$null | Out-Null
    }
} catch {}
Write-Host ''
