#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS CHAT - Chat NATIVO de ARNES ARGOS (CLI propio, motor propio, sin OpenCode)

.DESCRIPTION
Loop de chat interactivo con el agente atlas-player usando el MOTOR NATIVO de ARNES
(argos-engine.ps1): habla DIRECTO con las APIs de los proveedores, con la persona RPG
del agente, multi-turno y uso de tokens por respuesta. Cero dependencia de opencode.

.EXAMPLE
.\argos-chat.ps1                 -> chat interactivo
.\argos-chat.ps1 -Quest "haz login form con Zod"  -> quest directo sin TUI
#>
[CmdletBinding()]
param(
    [string]$Quest = '',
    [switch]$Agent = $false,
    [string]$AgentName = 'atlas-player'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'osma-resolve.ps1')

# Tema activo: colores compartidos desde theme-colors.ps1
. (Join-Path $PSScriptRoot 'theme-colors.ps1')
$theme = Get-ThemeColors

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$ArnesDir = Join-Path $Root '.arnes'
$script:chatSession = @()   # memoria de conversacion multi-turno

# Forzar UTF-8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# Lectura segura (no interactivo: vacio en vez de crashear)
function Read-Input {
    param([string]$Prompt)
    try { return Read-Host $Prompt } catch { return '' }
}

# === Prompt del agente con reparacion de mojibake cp1252->UTF-8 ===
function Get-AgentPrompt {
    param([string]$Path)
    $text = [System.IO.File]::ReadAllText($Path)
    try {
        $cp1252 = [System.Text.Encoding]::GetEncoding(1252)
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        $lines = $text -split "`n"
        $fixed = foreach ($line in $lines) {
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

# === Banner mini ===
function Show-MiniBanner {
    Write-Host ''
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor $theme.Primary
    Write-Host "  ║   ARNES ARGOS - Chat del Orquestador RPG - Los 100 Ojos   ║" -ForegroundColor $theme.Accent
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor $theme.Primary
    Write-Host '   ARNES v2.6 · 2026-08-06 · motor nativo · sin opencode' -ForegroundColor DarkGray
    Write-Host ''
}

# === Ejecutar un quest con el MOTOR NATIVO de ARNES (directo a la API) ===
function Invoke-ArgoQuest {
    param([string]$Message)

    $engine = Join-Path $PSScriptRoot 'argos-engine.ps1'

    # Modelo asignado al agente (config GLOBAL de la maquina)
    $model = ''
    $amPath = Join-Path $env:USERPROFILE '.config\arnes\agent-models.json'
    if (Test-Path $amPath) {
        $am = Get-Content $amPath -Raw | ConvertFrom-Json
        $agentKey = if ($AgentName -eq 'atlas-player') { 'atlas' } else { $AgentName }
        if ($am.agents.$agentKey) { $model = [string]$am.agents.$agentKey }
    }
    if (-not $model) { $model = 'opencode-go/gpt-5.6-luna' }

    # Persona RPG del agente (prompt propio de ARNES)
    $system = ''
    $candidates = @()
    if ($AgentName -eq 'atlas-player') { $candidates += (Join-Path $Root 'core\atlas-player.agent.md') }
    $candidates += (Join-Path $Root "core\classes\$AgentName.agent.md")
    $candidates += (Join-Path $Root "core\auditors\$AgentName.agent.md")
    foreach ($c in $candidates) {
        if (Test-Path $c) { $system = Get-AgentPrompt $c; break }
    }
    # Directiva de profundidad: respuestas completas y estructuradas para quests complejos
    $system += @'

[DIRECTIVA DE RESPUESTA]
- Adapta la profundidad al quest: breve si es simple; COMPLETA si es complejo o estructural.
- Para quests grandes entrega secciones, pasos numerados, opciones y tablas cuando aporte.
- NO recortes: si el quest merece detalle, entregalo completo (el usuario valora estructura).
- Usa markdown: ## secciones, - listas, 1. pasos numerados.
'@

    # === SEPARACION PARA CACHE DE PREFIJO (DeepSeek/OpenAI prompt caching) ===
    # $system = prompt ESTATICO (agent.md + directiva): NO cambia entre turns -> cacheable
    # $systemDynamic = prompt DINAMICO (memoria + recall + contexto): cambia cada turn
    # El engine envia system-estatico primero, system-dinamico despues. DeepSeek cobra
    # cache hit (4x mas barato) en el prefijo estable y solo cache miss en la parte variable.
    $systemDynamic = ''

    # Contexto de memoria (arnes.db): lo que Atlas recuerda de sesiones anteriores
    if ($script:memoryContext) {
        $systemDynamic += "`n`n[MEMORIA DEL HARNESS - sesiones anteriores. Usa esto para responder con contexto real, no digas que no tienes memoria si esto esta presente]`n$($script:memoryContext)"
    }

    # Recall inteligente (RAG): recuerdos RELEVANTES a esta pregunta en particular
    $recall = Get-Recall $Message
    if ($recall) {
        $systemDynamic += "`n`n[RECUERDOS RELEVANTES de este proyecto para esta pregunta. Usalos si aplican]`n$recall"
    }

    # Ruta cognitiva (FAST/RECALL/SKILL/DELIBERATE/DEEP) - saber cuando pensar
    $script:lastRoute = ''
    try {
        $memCli = (Get-OsmaMemoryCli)
        if (Test-Path $memCli) {
            $routeJson = @(& $memCli route -Query $Message -Quiet 2>$null) -join ''
            if ($routeJson) { $script:lastRoute = ($routeJson | ConvertFrom-Json).path }
        }
    } catch {}

    $maxTokens = 16000   # sin restriccion practica: respuestas completas, deepseek da buen uso

    Write-Host ''
    if ($script:lastRoute) {
        Write-Host ("  ▸ Trabajando... (ruta: {0})" -f $script:lastRoute) -ForegroundColor DarkGray
    } else {
        Write-Host '  ▸ Trabajando...' -ForegroundColor DarkGray
    }
    Write-Host ''

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $result = & $engine -Model $model -System $system -SystemDynamic $systemDynamic -Session $script:chatSession -Message $Message -MaxTokens $maxTokens
    $sw.Stop()
    $exit = if ($result.ok) { 0 } else { 1 }
    $script:chatModel = $model   # el modelo usado, para el indicador permanente del prompt

    if ($result.ok) {
        Write-Host ''
        Render-Reply $result.reply
        # Mostrar cache hit/miss si el proveedor lo reporto
        if ($result.cache_hit -gt 0 -or $result.cache_miss -gt 0) {
            $total = [int]$result.cache_hit + [int]$result.cache_miss
            $pct = if ($total -gt 0) { [math]::Round(([int]$result.cache_hit / $total) * 100, 0) } else { 0 }
            if ($pct -gt 0) {
                Write-Host ("  (cache hit: {0} tkns / {1}% - ahorro activo)" -f $result.cache_hit, $pct) -ForegroundColor DarkGray
            }
        }
        # Memoria de conversacion multi-turno (ultimas 20)
        $script:chatSession += @{ role = 'user'; content = $Message }, @{ role = 'assistant'; content = $result.reply }
        if ($script:chatSession.Count -gt 20) { $script:chatSession = @($script:chatSession | Select-Object -Last 20) }
        $script:lastReply = $result.reply
        $script:lastQuest = $Message
        # Guardado INCREMENTAL: este intercambio queda en memoria ya (no espera a salir)
        Save-ChatExchange -UserMsg $Message -Reply $result.reply
    } else {
        Write-Host "  [!] $($result.error)" -ForegroundColor Yellow
        Write-Host '  [X] Quest fallido.' -ForegroundColor Red
    }
}

# === Chat interactivo propio ===
function Show-InteractiveChat {
    Show-MiniBanner
    Write-Host '  Bienvenido al chat de ARNES ARGOS.' -ForegroundColor Green
    Write-Host '  Escribe tus quests (ej: "haz login form con Zod") o usa los comandos:' -ForegroundColor $theme.Accent
    Write-Host '    /party        ver party' -ForegroundColor DarkGray
    Write-Host '    /connectagent reconfigurar modelos por agente' -ForegroundColor DarkGray
    Write-Host '    /memory       estado de memoria' -ForegroundColor DarkGray
    Write-Host '    /models       ver catalogo de modelos' -ForegroundColor DarkGray
    Write-Host '    /status       estado del harness' -ForegroundColor DarkGray
    Write-Host '    /triage-stats stats de dificultad -> modelo -> resultado' -ForegroundColor DarkGray
    Write-Host '    /style        perfil de estilo del usuario (como responde Atlas)' -ForegroundColor DarkGray
    Write-Host '    /skills       inventario de skills (Ragnarok)' -ForegroundColor DarkGray
    Write-Host '    /skills find  buscar skills externas' -ForegroundColor DarkGray
    Write-Host '    /quit         salir' -ForegroundColor DarkGray
    Write-Host ''

    while ($true) {
        Write-Host ''
        $modelShort = if ($script:chatModel) { ($script:chatModel -split '/')[-1] } else { '' }
        $workPath = (Get-Location).Path
        $prompt = if ($modelShort) { "  [ARGOS · $modelShort · $workPath] >" } else { "  [ARGOS · $workPath] >" }
        $input = Read-Input $prompt

        switch -Regex ($input) {
            '^\s*/quit\s*$' {
                Write-Host '  Adios, jugador. Rojo y negro. 👁️' -ForegroundColor $theme.Accent
                Save-ChatMemory
                # Checkpoint final de sesion (continuidad garantizada) + backup
                try {
                    $cmem = (Get-OsmaMemoryCli)
                    if (Test-Path $cmem) {
                        $cq = if ($script:lastQuest) { $script:lastQuest } else { 'sesion-actual' }
                        & $cmem checkpoint -Create -QuestId $cq -Agent 'atlas' -Goal $cq -NextAction ("Retomar: " + $cq) -Quiet 2>$null | Out-Null
                        & $cmem backup -Quiet 2>$null | Out-Null
                    }
                } catch {}
                exit 0
            }
            '^\s*/connectagent\s*$' {
                Write-Host ''
                Write-Host '  ▸ Reconfigurando modelos por agente (argos configure)...' -ForegroundColor $theme.Primary
                & (Join-Path $PSScriptRoot 'argos.ps1') configure
                Write-Host '  ▸ Modelos reconfigurados. Los agentes usaran su modelo al delegar.' -ForegroundColor Green
                continue
            }
            '^\s*/code(?:\s+(.+))?$' {
                $codeQuest = if ($Matches[1]) { $Matches[1] } else { $script:lastQuest }
                if ([string]::IsNullOrWhiteSpace($codeQuest)) {
                    Write-Host '  Uso: /code <quest de coding>  (crea archivos REALES en este proyecto)' -ForegroundColor Yellow
                    Write-Host '  Ej:  /code crea el schema.sql de businesses con las 9 tablas' -ForegroundColor $theme.Primary
                } else {
                    & (Join-Path $PSScriptRoot 'argos-code.ps1') -Quest $codeQuest
                }
                continue
            }
            '^\s*/argos-checkpoint(?:\s+(.+))?$' {
                $memCli = (Get-OsmaMemoryCli)
                $cpQuest = if ($Matches[1]) { $Matches[1] } else { $script:lastQuest }
                if ([string]::IsNullOrWhiteSpace($cpQuest)) { $cpQuest = 'sesion-actual' }
                Write-Host '  COGNITIVE CHECKPOINT manual (preserva estado sin compactar)' -ForegroundColor $theme.Primary
                $next = Read-Input '  Cual es la SIGUIENTE ACCION exacta? '
                & $memCli checkpoint -Create -QuestId $cpQuest -Agent 'atlas' -Goal $cpQuest -NextAction $next 2>&1 | Select-Object -Last 1 | ForEach-Object { $_.Trim() }
                continue
            }
            '^\s*/argos-checkpoints\s*$' {
                & ((Get-OsmaMemoryCli)) checkpoint -List
                continue
            }
            '^\s*/argos-continuity\s*$' {
                $memCli = (Get-OsmaMemoryCli)
                $last = @(& $memCli checkpoint -List -Quiet 2>$null) -join '' | ConvertFrom-Json
                if (-not $last -or $last.Count -eq 0) { Write-Host '  Sin checkpoints aun. Usa /argos-checkpoint' -ForegroundColor Yellow; continue }
                $top = $last[0]
                & $memCli capsule -Id $top.id
                continue
            }
            '^\s*/argos-compact\s*$' {
                $memCli = (Get-OsmaMemoryCli)
                Write-Host '  ARGOS COGNITIVE COMPACTION (consolidar + checkpoint + capsule)' -ForegroundColor $theme.Primary
                $cpQuest = if ($script:lastQuest) { $script:lastQuest } else { 'sesion-actual' }
                $next = Read-Input '  Cual es la SIGUIENTE ACCION exacta? '
                & $memCli cognitive-compact -QuestId $cpQuest -Agent 'atlas' -Goal $cpQuest -NextAction $next
                Write-Host '  (Pi puede compactar ahora; la continuidad esta garantizada por ARGOS)' -ForegroundColor DarkGray
                continue
            }
            '^\s*/argos-party(?:\s+(.+))?$' {
                $pQuest = if ($Matches[1]) { $Matches[1] } else { $script:lastQuest }
                if ([string]::IsNullOrWhiteSpace($pQuest)) {
                    Write-Host '  Uso: /argos-party <quest GRANDE>  (Atlas decide, el party ejecuta)' -ForegroundColor Yellow
                } else {
                    & (Join-Path $PSScriptRoot 'argos-party.ps1') -Quest $pQuest
                }
                continue
            }
            '^\s*/argos-tasks\s*$' {
                $memCli = (Get-OsmaMemoryCli)
                $lastQuest = @(& $memCli aquest -List -Quiet 2>$null) -join '' | ConvertFrom-Json
                if (-not $lastQuest -or $lastQuest.Count -eq 0) { Write-Host '  Sin quests autonomas.' -ForegroundColor Yellow; continue }
                & $memCli atask -List -QuestId $lastQuest[0].id
                continue
            }
            '^\s*/argos-quest\s*$' {
                $memCli = (Get-OsmaMemoryCli)
                $lastQuest = @(& $memCli aquest -List -Quiet 2>$null) -join '' | ConvertFrom-Json
                if (-not $lastQuest -or $lastQuest.Count -eq 0) { Write-Host '  Sin quests autonomas.' -ForegroundColor Yellow; continue }
                & $memCli aquest -QuestId $lastQuest[0].id
                continue
            }
            '^\s*/party\s*$' {
                Show-Party
                continue
            }
            '^\s*/autowork\s+stop\s*$' {
                $stopFlag = Join-Path (Get-Location) '.arnes\autowork-stop'
                New-Item -ItemType Directory -Path (Split-Path $stopFlag) -Force -ErrorAction SilentlyContinue | Out-Null
                Set-Content -Path $stopFlag -Value 'stop' -Encoding UTF8
                Write-Host '  ▸ [STOP] Modo autonomo se detendra al terminar la iteracion actual.' -ForegroundColor Yellow
                continue
            }
            '^\s*/autowork(?:\s+(.+))?$' {
                $goal = if ($Matches[1]) { $Matches[1].Trim() } else { '' }
                if (-not $goal) {
                    Write-Host '  Uso: /autowork <objetivo global>  (modo autonomo hasta lograrlo)' -ForegroundColor Yellow
                    Write-Host '       /autowork stop               (detener al terminar la iteracion)' -ForegroundColor Yellow
                    Write-Host '  Ej: /autowork crea la plataforma escolar completa con login, calificaciones y avisos' -ForegroundColor $theme.Primary
                } else {
                    & (Join-Path $PSScriptRoot 'argos-goal.ps1') -Goal $goal
                }
                continue
            }
            '^\s*/memory\s*$' {
                $mem = (Get-OsmaMemoryCli)
                & $mem stats
                continue
            }
            '^\s*/models\s*$' {
                $raw = @(cmd /c 'opencode models' 2>$null)
                $models = @($raw | Where-Object { $_ -match '^[\w-]+/.+' })
                Write-Host "  Catalogo vivo: $($models.Count) modelos" -ForegroundColor $theme.Primary
                $models | Group-Object { ($_ -split '/')[0] } | Sort-Object Name | Select-Object -First 10 | ForEach-Object {
                    Write-Host "  [$($_.Name)]" -ForegroundColor Yellow
                    $_.Group | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" -ForegroundColor $theme.Accent }
                }
                continue
            }
            '^\s*/status\s*$' {
                Write-Host '  ARNES ARGOS - Estado' -ForegroundColor $theme.Primary
                Write-Host "  Agentes: 16 · Memoria: arnes.db · Proceso: SDD/FDD/ADR" -ForegroundColor Green
                continue
            }
            '^\s*/triage-stats\s*$' {
                & (Join-Path $PSScriptRoot 'triage-stats.ps1')
                continue
            }
            '^\s*/style\s*$' {
                & (Join-Path $PSScriptRoot 'user-style.ps1') -Action profile
                continue
            }
            '^\s*/skills\s*$' {
                & (Join-Path $PSScriptRoot 'argos-skills.ps1') -Action installed
                continue
            }
            '^\s*/skills\s+find\s+(.+)$' {
                & (Join-Path $PSScriptRoot 'argos-skills.ps1') -Action find -Query $Matches[1]
                continue
            }
            default {
                if ([string]::IsNullOrWhiteSpace($input)) { continue }
                # === Disparador de modo autonomo por lenguaje natural ===
                # "atlas activa modo automatico <objetivo>" / "pon modo auto: <objetivo>"
                $autoMatch = [regex]::Match($input, '(?i)(activa|inicia|pon|entra).*(modo auto(m[aá]tico)?|modo aut[oó]nomo|autowork)\s*[:\-]?\s*(.*)$')
                if ($autoMatch.Success) {
                    $autoGoal = $autoMatch.Groups[3].Value.Trim()
                    if (-not $autoGoal) {
                        $autoGoal = Read-Input '  Atlas: dame el OBJETIVO del modo autonomo: '
                    }
                    if ($autoGoal) {
                        Write-Host '  ▸ [AUTOWORK] Modo autonomo activado por solicitud.' -ForegroundColor $theme.Primary
                        & (Join-Path $PSScriptRoot 'argos-goal.ps1') -Goal $autoGoal
                    } else {
                        Write-Host '  Atlas: no recibí el objetivo. Usa /autowork <objetivo>.' -ForegroundColor Yellow
                    }
                    continue
                }
                Invoke-ArgoQuest -Message $input
                # === Interactividad: cuestionario paso a paso o lista de opciones ===
                Show-Interactive
                # === Si Atlas no puede escribir, ofrecer el MODO CODING ===
                Show-BuildOffer
            }
        }
    }
}

function Show-Party {
    Write-Host ''
    Write-Host '  ARNES ARGOS - PARTY (16 agentes)' -ForegroundColor $theme.Primary
    Write-Host '  Atlas (Player) · Vivi (Frontend) · Ansem (Backend) · Kuja (QA)' -ForegroundColor $theme.Accent
    Write-Host '  Eiko (DevOps) · Amarant (Arq) · Eremez (Research) · Auron (Sec)' -ForegroundColor $theme.Accent
    Write-Host '  Bran (Analista) · Quina (Tokens) · Varys (Tracker) · Tywin (Verif)' -ForegroundColor $theme.Accent
    Write-Host '  Sam (Consejero) · Bard (Mejora) · Tidus (Infra) · Ragnarok (Compras)' -ForegroundColor $theme.Accent
    # === Niveles XP desde quest-ledger ===
    $ledgerFile = Join-Path (Get-Location) '.arnes\quest-ledger.json'
    if (Test-Path $ledgerFile) {
        try {
            $ledger = Get-Content $ledgerFile -Raw | ConvertFrom-Json
            $xpMap = @{}
            foreach ($q in @($ledger.quests)) {
                $name = [string]$q.agent
                if (-not $name) { continue }
                if (-not $xpMap.ContainsKey($name)) { $xpMap[$name] = 0 }
                $xpMap[$name] += if ([string]$q.verdict -eq 'PASS') { 100 } else { 10 }
            }
            $levels = foreach ($r in ($xpMap.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5)) {
                $lvl = [math]::Floor([math]::Sqrt([int]$r.Value / 100.0)) + 1
                "{0} Lv{1}" -f $r.Key, $lvl
            }
            if ($levels) {
                Write-Host ("  Niveles:  {0}" -f ($levels -join ' · ')) -ForegroundColor DarkGray
            }
        } catch { }
    }
    Write-Host ''
}

# === Renderizar respuesta con estructura (encabezados, viñetas, bold) ===
function Render-Reply {
    param([string]$Text)
    if (-not $Text) { return }
    foreach ($line in ($Text -split "`n")) {
        $t = $line.TrimEnd()
        if ($t -match '^\s*#{1,3}\s+(.+)$') {
            Write-Host ("  " + $Matches[1]) -ForegroundColor $theme.Primary
        }
        elseif ($t -match '^\s*[-*]\s+(.+)$') {
            Write-Host ("  • " + $Matches[1]) -ForegroundColor $theme.Accent
        }
        elseif ($t -match '^\s*\d+[\.\)]\s+.+$') {
            Write-Host ("  " + $t.Trim()) -ForegroundColor $theme.Accent
        }
        elseif ([string]::IsNullOrWhiteSpace($t)) {
            Write-Host ''
        }
        else {
            # texto plano (sin ANSI: PS 5.1/consolas no lo renderizan)
            $rendered = $t -replace '\*\*(.+?)\*\*', '$1'
            Write-Host ("  " + $rendered) -ForegroundColor $theme.Accent
        }
    }
}

# === Cuestionario interactivo: Atlas lanza varias preguntas, eliges una por una ===
function Show-Questionnaire {
    param([string]$Reply)
    # Detectar preguntas numeradas con opciones: "1. **Frecuencia:** diario, semanal o ambas."
    $questions = @()
    foreach ($line in ($Reply -split "`n")) {
        $t = $line.Trim()
        $m = [regex]::Match($t, '^\d+[\.\)]\s+\*\*(.+?)\*\*\s*:?\s*(.+)$')
        if (-not $m.Success) { $m = [regex]::Match($t, '^\d+[\.\)]\s+(.+?):\s*(.+)$') }
        if ($m.Success) {
            $q = $m.Groups[1].Value.Trim().TrimEnd(':').Trim()
            $opts = $m.Groups[2].Value.Trim()
            $optList = @($opts -split ',\s*|\s+o\s+' | ForEach-Object { $_.Trim().TrimEnd('.', '?') } | Where-Object { $_ })
            $questions += [pscustomobject]@{ Question = $q; Options = $optList }
        }
    }
    if ($questions.Count -lt 2) { return $false }

    Write-Host ''
    Write-Host '  ── Atlas necesita tu respuesta ──' -ForegroundColor $theme.Primary
    $answers = @()
    for ($i = 0; $i -lt $questions.Count; $i++) {
        $q = $questions[$i]
        Write-Host ''
        Write-Host ("  Pregunta {0}/{1}: {2}" -f ($i + 1), $questions.Count, $q.Question) -ForegroundColor $theme.Primary
        if ($q.Options.Count -ge 2) {
            for ($j = 0; $j -lt $q.Options.Count; $j++) {
                Write-Host ("     [{0}] {1}" -f ($j + 1), $q.Options[$j]) -ForegroundColor $theme.Accent
            }
            Write-Host '  (elige un numero, escribe tu respuesta, o Enter para omitir) [Q salir]' -ForegroundColor DarkGray
        }
        $ans = Read-Input ("  [Q{0}] >" -f ($i + 1))
        if ($ans -match '^[Qq]$') { exit 0 }
        if ($ans -match '^\d+$') {
            $n = [int]$ans
            if ($n -ge 1 -and $n -le $q.Options.Count) { $answers += "[$($q.Question)] " + $q.Options[$n - 1] }
            else { $answers += "[$($q.Question)] " + $ans }
        } elseif (-not [string]::IsNullOrWhiteSpace($ans)) {
            $answers += "[$($q.Question)] " + $ans
        } else {
            $answers += "[$($q.Question)] (sin respuesta)"
        }
    }
    # Enviar las respuestas a Atlas y seguir el flujo
    Invoke-ArgoQuest -Message ("Mis respuestas a tus preguntas: " + ($answers -join ' | '))
    Show-Interactive
    return $true
}

# === Punto de entrada: cuestionario o lista corta de opciones ===
function Show-Interactive {
    $reply = $script:lastReply
    if ([string]::IsNullOrWhiteSpace($reply)) { return }
    if (Show-Questionnaire $reply) { return }
    Show-OptionsChoice
}

# === Oferta de MODO CODING: si Atlas dice que no puede escribir, ofrecer construir ===
function Show-BuildOffer {
    $reply = $script:lastReply
    if ([string]::IsNullOrWhiteSpace($reply)) { return }
    if ($reply -match 'no tengo acceso|no puedo|sin acceso de escritura|acceso de escritura|crear archivos|construir|implementar|escribir archivos|modificar tus archivos|migracion|migración|tablas|esquema|schema') {
        Write-Host ''
        Write-Host '  ── ¿Lo construyo en el MODO CODING? (crea archivos REALES en este proyecto) ──' -ForegroundColor Yellow
        Write-Host '  (o escribe: /code <quest> para lanzarlo tu mismo)' -ForegroundColor DarkGray
        $r = Read-Input '  [y/N] '
        if ($r -match '^[YySs]') {
            if ($script:lastQuest) {
                & (Join-Path $PSScriptRoot 'argos-code.ps1') -Quest $script:lastQuest
            } else {
                Write-Host '  No tengo el quest en contexto. Escribe: /code <tu quest de coding>' -ForegroundColor Yellow
            }
        }
    }
}

# === Interactividad: detecta opciones numeradas en la respuesta de Atlas y ofrece elegir ===
function Show-OptionsChoice {
    $reply = $script:lastReply
    $script:lastReply = ''
    if ([string]::IsNullOrWhiteSpace($reply)) { return }
    # Solo activa si es una PREGUNTA con opciones (no listas informativas de archivos/secciones)
    if ($reply -notmatch 'elige|dime|selecciona|prefieres|opcion|opción|cual|cuales|cuál|cuáles|quieres|\?\s*$') { return }
    # Y solo en respuestas CORTAS (listas de opciones), no en documentos largos con secciones
    if ($reply.Length -gt 1000) { return }
    $options = @()
    foreach ($line in ($reply -split "`n")) {
        $t = $line.Trim()
        if ($t -match '^\s*(?:\d+[\.\)]\s+|-\s+)(.+)$') {
            $opt = $Matches[1].Trim()
            if ($opt.Length -gt 1 -and $opt.Length -lt 40) { $options += $opt }
        }
    }
    if ($options.Count -lt 2) { return }
    # Heuristica: en una lista real de opciones, casi TODAS las lineas son opciones.
    # Si hay mucho cuerpo de texto entre numeros, es un documento, no un menu.
    $nonEmptyLines = @($reply -split "`n" | Where-Object { $_.Trim() }).Count
    if ($nonEmptyLines -gt 0 -and (($options.Count / $nonEmptyLines) -lt 0.5)) { return }
    Write-Host ''
    Write-Host '  ── Atlas espera tu eleccion ──' -ForegroundColor $theme.Primary
    for ($i = 0; $i -lt $options.Count; $i++) {
        Write-Host ("     [{0}] {1}" -f ($i + 1), $options[$i]) -ForegroundColor $theme.Accent
    }
    Write-Host '  (escribe el numero, tu propia respuesta, o Q para salir)' -ForegroundColor DarkGray
    $choice = Read-Input '  [ARGOS] >'
    if ($choice -match '^[Qq]$') { exit 0 }
    if ([string]::IsNullOrWhiteSpace($choice)) { return }
    if ($choice -match '^\d+$') {
        $n = [int]$choice
        if ($n -ge 1 -and $n -le $options.Count) {
            Invoke-ArgoQuest -Message ("Elijo la opcion {0}: {1}" -f $n, $options[$n - 1])
            Show-OptionsChoice
            return
        }
    }
    Invoke-ArgoQuest -Message $choice
    Show-OptionsChoice
}

# === AUTO-INIT: el entorno se inicializa solo (casi forzoso), sin preguntar ===
function Ensure-Initialized {
    $missing = @()
    $projArnes = Join-Path (Get-Location) '.arnes'
    $gConn = Join-Path $env:USERPROFILE '.config\arnes\connections.json'
    $gModels = Join-Path $env:USERPROFILE '.config\arnes\agent-models.json'
    $db = Join-Path (Get-Location) '.arnes\arnes.db'
    if (-not (Test-Path $projArnes)) { $missing += 'entorno del proyecto (.arnes)' }
    if (-not (Test-Path $gConn)) { $missing += 'conexiones globales' }
    if (-not (Test-Path $gModels)) { $missing += 'modelos por agente' }
    if (-not (Test-Path $db)) { $missing += 'memoria (arnes.db)' }
    if ($missing.Count -eq 0) { return }
    Write-Host ("  ▸ [AUTO-INIT] inicializando: " + ($missing -join ', ')) -ForegroundColor Yellow
    if (-not (Test-Path $projArnes)) { New-Item -ItemType Directory -Path $projArnes -Force | Out-Null }
    & (Join-Path $PSScriptRoot 'argos-connect.ps1') init | Out-Null
    if (-not (Test-Path $gModels)) {
        & (Join-Path $PSScriptRoot 'argos.ps1') init 2>&1 | Out-Null
    }
    if (-not (Test-Path $db)) {
        $mem = (Get-OsmaMemoryCli)
        if (Test-Path $mem) { & $mem init 2>&1 | Out-Null }
    }
    Write-Host '  ▸ [AUTO-INIT] entorno listo (contexto, conexiones, modelos y memoria).' -ForegroundColor Green
}

# === Cargar contexto de memoria (arnes.db): Atlas recuerda sesiones pasadas ===
function Load-MemoryContext {
    $script:memoryContext = ''
    $mem = (Get-OsmaMemoryCli)
    if (-not (Test-Path $mem)) { return }
    $agentKey = if ($AgentName -eq 'atlas-player') { 'atlas' } else { $AgentName }
    $parts = @()
    try {
        $agentJson = @(& $mem agent -Agent $agentKey -Quiet 2>$null) -join ''
        if ($agentJson) {
            foreach ($r in ($agentJson | ConvertFrom-Json | Select-Object -First 8)) {
                $parts += ("[{0}] {1}" -f $r.topic_key, $r.content)
            }
        }
    } catch {}
    try {
        $recentJson = @(& $mem context -Quiet 2>$null) -join ''
        if ($recentJson) {
            foreach ($r in ($recentJson | ConvertFrom-Json | Select-Object -First 8)) {
                $parts += ("[{0}] {1}: {2}" -f $r.agent, $r.topic_key, $r.content)
            }
        }
    } catch {}
    if ($parts.Count -gt 0) {
        $script:memoryContext = ($parts -join "`n")
        if ($script:memoryContext.Length -gt 5000) { $script:memoryContext = $script:memoryContext.Substring(0, 5000) + '...' }
        Write-Host ("  ▸ [MEMORIA] {0} recuerdo(s) cargados de este proyecto" -f $parts.Count) -ForegroundColor Green
    } else {
        Write-Host '  ▸ [MEMORIA] sin recuerdos previos en este proyecto' -ForegroundColor DarkGray
    }
}

# === Recall inteligente V3 (RAG): working memory primero, luego recall ponderado ===
$script:hotMemory = @()   # working memory: lo fresco de la sesion (sin RAG completo)

function Get-Recall {
    param([string]$Text)
    $mem = (Get-OsmaMemoryCli)
    if (-not (Test-Path $mem)) { return '' }
    $stop = @('para','que','con','los','las','una','uno','este','esta','como','cual','sobre','por','del','al','su','sus','cada','debe','tener','quiero','necesito','hacer','puede','ser','entre','hasta','segun','otra','otro','the','and','with','from','this','that','was','were','will','have','has','been','our','your','about','what','when','how','solo','sino','pero','mas')
    $words = @($Text.ToLower() -split '\W+' | Where-Object { $_.Length -gt 3 -and $_ -notin $stop } | Select-Object -Unique)
    $kw = ($words | Select-Object -First 8) -join ' '
    if (-not $kw) { return '' }

    # 1) WORKING MEMORY (pensamiento fresco): hot cache antes que RAG completo
    $hotHits = @($script:hotMemory | Where-Object {
        $hit = $_
        $matched = @($words | Where-Object { $hit.content -match [regex]::Escape($_) -or $hit.topic_key -match [regex]::Escape($_) })
        $matched.Count -gt 0
    })
    if ($hotHits.Count -gt 0) {
        return (($hotHits | Select-Object -First 3 | ForEach-Object { "[HOT {0}] {1}: {2}" -f $_.id, $_.topic_key, $_.content }) -join "`n")
    }

    # 2) RECALL V3: ponderado (BM25 + retrieval + confianza + importancia) + practica
    try {
        $json = @(& $mem recall -Query $kw -Limit 5 -Quiet 2>$null) -join ''
        if (-not $json) { return '' }
        $hits = $json | ConvertFrom-Json
        if (-not $hits -or $hits.Count -eq 0) { return '' }
        $parts = @()
        foreach ($h in $hits | Select-Object -First 5) {
            $parts += ("[{0} c={1}] {2}" -f $h.topic_key, $h.confidence, $h.content)
        }
        # poblar working memory con lo recuperado (para follow-ups sin re-RAG)
        $script:hotMemory = @($hits | Select-Object -First 3 | ForEach-Object {
            @{ id = $_.id; topic_key = $_.topic_key; content = $_.content }
        }) + @($script:hotMemory | Select-Object -First 4)
        return ($parts -join "`n")
    } catch { return '' }
}

# === Guardar CADA intercambio en memoria (incremental: Ctrl+C / apagon no pierde nada) ===
function Save-ChatExchange {
    param([string]$UserMsg, [string]$Reply)
    $mem = (Get-OsmaMemoryCli)
    if (-not (Test-Path $mem)) { return }
    $content = "[user] $UserMsg`n[atlas] $Reply"
    if ($content.Length -gt 1500) { $content = $content.Substring(0, 1500) + '...' }
    try {
        & $mem save -Agent 'atlas' -Topic ("atlas/chat/" + (Get-Date -Format 'yyyy-MM-dd')) -Type 'pattern' -Content $content -Quiet 2>$null | Out-Null
    } catch {}
}

# === Guardar digest de la conversacion en memoria (arnes.db) ===
function Save-ChatMemory {
    if ($script:chatSession.Count -eq 0) { return }
    $mem = (Get-OsmaMemoryCli)
    if (-not (Test-Path $mem)) { return }
    $last = @($script:chatSession | Select-Object -Last 6 | ForEach-Object { "[$($_.role)] " + $_.content })
    $summary = ($last -join ' | ')
    if ($summary.Length -gt 1200) { $summary = $summary.Substring(0, 1200) + '...' }
    try {
        & $mem save -Agent 'atlas' -Topic ("atlas/chat-digest/" + (Get-Date -Format 'yyyy-MM-dd-HHmm')) -Type 'pattern' -Content $summary -Quiet 2>$null | Out-Null
    } catch {}
}

# === MAIN ===
Ensure-Initialized
Load-MemoryContext
if ($Quest) {
    Show-MiniBanner
    Write-Host "  Quest directo: $Quest" -ForegroundColor Yellow
    Invoke-ArgoQuest -Message $Quest
    Save-ChatMemory
} else {
    Show-InteractiveChat
}
