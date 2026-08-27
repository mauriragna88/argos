# user-style.ps1 - Perfil de estilo del usuario (memoria OSMA user/style/*)
# =========================================================================
# Aprende COMO el usuario escribe y como le gusta que le respondan.
# Cada prompt se clasifica en estilos (directo/detallado/ambiguo/incremental/
# pregunta/urgente) y se guarda como observacion + experiencia en OSMA.
# Atlas consulta el perfil antes de responder para adaptar tono y formato.
#
# Acciones:
#   detect   -> clasifica un prompt en estilos (sin tocar memoria)
#   remember -> guarda el estilo detectado en OSMA (observacion + experiencia)
#   recall   -> consulta el perfil acumulado del usuario para el prompt actual
#   profile  -> muestra el perfil completo aprendido (sin prompt)
#
# Uso:
#   .\cli\user-style.ps1 -Action detect -Prompt "sigue adelante"
#   .\cli\user-style.ps1 -Action remember -Prompt "sigue adelante"
#   .\cli\user-style.ps1 -Action recall -Prompt "sigue adelante"
#   .\cli\user-style.ps1 -Action profile
#   .\cli\user-style.ps1 -Action detect -Prompt "..." -Json

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("detect","remember","recall","profile","profile-level")]
    [string]$Action = "detect",
    [string]$Prompt = "",
    [switch]$Json,
    [switch]$Quiet,   # remember: no imprimir confirmacion (para llamadas automaticas)
    [string]$ArnesDir = ""
)

$ErrorActionPreference = "Continue"

if (-not $ArnesDir) {
    $cwd = (Get-Location).Path
    if (Test-Path (Join-Path $cwd ".arnes\config.json")) {
        $ArnesDir = Join-Path $cwd ".arnes"
    } else {
        $ArnesDir = ".arnes"
    }
}

# === Deteccion de estilo ===
$STYLE_DEFS = @{
    directo = "Prompts cortos e imperativos (haz, dale, sigue). Prefiere accion directa, sin preambulo, respuestas compactas."
    detallado = "Prompts largos con contexto y requisitos. Prefiere respuestas estructuradas con plan y detalle."
    ambiguo = "Prompts abiertos o incompletos. Prefiere que Atlas complemente (alternativas + planeacion) antes de ejecutar."
    incremental = "Prompts iterativos (sigue, continua, luego). Prefiere avanzar por pasos con confirmacion ligera."
    pregunta = "Prompts interrogativos (es posible?, como?, puedes?). Prefiere explicacion y opciones antes de ejecutar."
    urgente = "Prompts con urgencia (ya, rapido, urgentemente). Prefiere minima friccion, prioridad alta, sin detalle innecesario."
}

$imperativeWords = @("haz","dale","sigue","continua","ejecuta","implementa","crea","hazme","arregla","agrega","añade","actualiza","termina","cierra","mueve","cambia","inicia","lanza","corre","sube","despliega")
$incrementalWords = @("sigue","continua","adelante","luego","despues","después","siguiente","proximo","próximo","ahora","de nuevo","otra vez","paso a paso","sigueme")
$questionWords = @("es posible","como ","como?","que opinas","se puede","puedes ","me recomiendas","cual es","seria bueno","sería bueno","no crees","verdad?","cierto?","esta bien","esta bien?","deberia","debería","que tal","explicame","me ayudas","ayudame","hay alguna","tienes alguna","seria mejor")
$urgentWords = @("ya","ya!","rapido","rápido","rapidisimo","urgente","urgentemente","cuanto antes","lo antes posible","pronto","ahora mismo","no tarda","no tardes")
$ambiguityWords = @("creas mejor","como tu veas","lo que mejor","alguna idea","recomiendame","que opinas","mejor forma","no se","nose","no se como","quiza","tal vez","no estoy seguro","ayudame a decidir","que haria","que harías","segun tu","que prefieres","dame ideas","me gustaria algo","haz algo","lo que quieras","tu decides","como creas")

function Get-PromptStyle {
    param([string]$Prompt)
    $lower = $Prompt.ToLower()
    $len = $Prompt.Length
    $scores = [ordered]@{ directo = 0; detallado = 0; ambiguo = 0; incremental = 0; pregunta = 0; urgente = 0 }

    # directo: corto + imperativo
    foreach ($w in $imperativeWords) { if ($lower -match ("(^|\s)" + [regex]::Escape($w))) { $scores.directo++ } }
    if ($len -le 40 -and $scores.directo -gt 0) { $scores.directo += 2 }
    # detallado: largo + contexto
    if ($len -ge 300) { $scores.detallado += 3 } elseif ($len -ge 120) { $scores.detallado += 2 } elseif ($len -ge 60) { $scores.detallado += 1 }
    # ambiguo: patrones abiertos
    foreach ($w in $ambiguityWords) { if ($lower.Contains($w)) { $scores.ambiguo++ } }
    if ($scores.ambiguo -gt 0) { $scores.ambiguo += 1 }
    # incremental: iterativo
    foreach ($w in $incrementalWords) { if ($lower.Contains($w)) { $scores.incremental++ } }
    if ($lower -match "^(sigue|continua|adelante|ok|dale|yes|si)(\s|,|\.|$)") { $scores.incremental += 2 }
    # pregunta: interrogativo
    foreach ($w in $questionWords) { if ($lower.Contains($w)) { $scores.pregunta++ } }
    if ($lower.Contains("?")) { $scores.pregunta += 2 }
    # urgente: urgencia
    foreach ($w in $urgentWords) { if ($lower -match ("(^|\s)" + [regex]::Escape($w))) { $scores.urgente++ } }

    # top estilos (>=1 punto), ordenados por score
    $ranked = @($scores.GetEnumerator() | Where-Object { $_.Value -gt 0 } | Sort-Object Value -Descending)
    $primary = if ($ranked.Count -gt 0) { $ranked[0].Key } else { "neutral" }
    $secondary = if ($ranked.Count -gt 1) { $ranked[1].Key } else { "" }
    $all = @($ranked | ForEach-Object { @{ style = $_.Key; score = $_.Value } })

    return [PSCustomObject]@{
        primary = $primary
        secondary = $secondary
        scores = $all
        style_desc = $STYLE_DEFS[$primary]
        prompt = $Prompt
    }
}

# === OSMA helpers ===
function Get-OsmaCli {
    try {
        . (Join-Path $PSScriptRoot 'osma-resolve.ps1')
        return Get-OsmaMemoryCli
    } catch { return $null }
}

# === DETECT ===
if ($Action -eq "detect") {
    if (-not $Prompt) { Write-Error "detect requiere -Prompt"; exit 1 }
    $st = Get-PromptStyle $Prompt
    if ($Json) {
        $st | ConvertTo-Json -Depth 4
    } else {
        Write-Host ""
        Write-Host "  USER STYLE - detect" -ForegroundColor Cyan
        Write-Host "  ===================" -ForegroundColor Cyan
        Write-Host ("  Estilo principal: {0}" -f $st.primary) -ForegroundColor Yellow
        if ($st.secondary) { Write-Host ("  Estilo secundario: {0}" -f $st.secondary) -ForegroundColor White }
        Write-Host ("  {0}" -f $st.style_desc) -ForegroundColor DarkGray
        if ($st.scores.Count -gt 0) {
            Write-Host ("  Scores: {0}" -f (($st.scores | ForEach-Object { "$($_.style)=$($_.score)" }) -join " ")) -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    exit 0
}

# === REMEMBER (guardar en OSMA) ===
if ($Action -eq "remember") {
    if (-not $Prompt) { Write-Error "remember requiere -Prompt"; exit 1 }
    $st = Get-PromptStyle $Prompt
    $memCli = Get-OsmaCli
    if (-not $memCli) {
        if ($Json) { @{ ok = $false; reason = "no osma" } | ConvertTo-Json; exit 0 }
        Write-Host "  [STYLE] OSMA no disponible - estilo no guardado (solo detectado)." -ForegroundColor Yellow
        $st | ConvertTo-Json -Depth 4
        exit 0
    }
    try {
        # 1. Observacion: user/style/<primary>
        $topic = "user/style/$($st.primary)"
        $content = "Prompt: $($Prompt.Substring(0, [Math]::Min(120, $Prompt.Length))) | estilos: $(($st.scores | ForEach-Object { "$($_.style)=$($_.score)" }) -join ' ') | secundario: $($st.secondary)"
        & $memCli save -Agent "atlas" -Topic $topic -Type "preference" -Content $content *> $null
        # 2. Experiencia: situation = prompt, outcome = estilo detectado (reward bajo, se refuerza con recall)
        $reward = 0.4
        & $memCli experience -ExperienceAction record `
            -Situation "Prompt del usuario: $($st.prompt)" `
            -Reasoning "Estilo detectado: $($st.primary) (scores: $(($st.scores | ForEach-Object { "$($_.style)=$($_.score)" }) -join ' '))" `
            -Conclusion "Responder como: $($st.primary) - $($st.style_desc)" `
            -Action "Atlas adapta respuesta al estilo $($st.primary)" `
            -Outcome "Estilo aprendido; refuerzo en proximo recall" `
            -Reward $reward -Agent "atlas" -Project (Split-Path (Get-Location) -Leaf) -Quiet *> $null
        if ($Json) {
            @{ ok = $true; primary = $st.primary; secondary = $st.secondary; topic = $topic } | ConvertTo-Json
        } elseif (-not $Quiet) {
            Write-Host ("  [STYLE] Aprendido: {0} (guardado en OSMA user/style/{1})" -f $st.primary, $st.primary) -ForegroundColor Green
        }
    } catch {
        if ($Json) { @{ ok = $false; reason = $_.Exception.Message } | ConvertTo-Json; exit 0 }
        if (-not $Quiet) { Write-Host "  [STYLE] Error guardando en OSMA: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    exit 0
}

# === RECALL (perfil del usuario para el prompt actual) ===
if ($Action -eq "recall") {
    if (-not $Prompt) { Write-Error "recall requiere -Prompt"; exit 1 }
    $st = Get-PromptStyle $Prompt
    $memCli = Get-OsmaCli
    $profile = [ordered]@{
        current = $st.primary
        current_secondary = $st.secondary
        description = $st.style_desc
        learned = $null
        history = @()
    }
    if ($memCli) {
        try {
            $rec = (& $memCli recall -Query "estilo preferencias del usuario" -Topic "user/style" -Limit 10 -Quiet 2>$null | Out-String).Trim()
            $history = @()
            if ($rec -and $rec -notmatch 'Sin recuerdos|^$' -and $rec -notmatch '^\[\]$') {
                # recall devuelve JSON array: extraer topic_key + content
                try {
                    $rows = $rec | ConvertFrom-Json
                    foreach ($r in $rows) {
                        if ($r.topic_key -match 'user/style/(\w+)') {
                            $s = $Matches[1]
                            if (-not ($history -contains $s)) { $history += $s }
                        }
                    }
                    $profile.learned = ($rows | ForEach-Object { "[$($_.topic_key)] $($_.content)" }) -join ' | '
                } catch {
                    $profile.learned = $rec
                }
            }
            $profile.history = $history
        } catch {}
    }
    if ($Json) {
        $profile | ConvertTo-Json -Depth 5
    } else {
        Write-Host ""
        Write-Host "  USER STYLE - recall" -ForegroundColor Cyan
        Write-Host "  ===================" -ForegroundColor Cyan
        Write-Host ("  Prompt actual: {0} (estilo {1})" -f $st.primary, $st.primary) -ForegroundColor Yellow
        Write-Host ("  Como responder: {0}" -f $st.style_desc) -ForegroundColor White
        if ($profile.history.Count -gt 0) {
            Write-Host ("  Estilos aprendidos en OSMA: {0}" -f ($profile.history -join ", ")) -ForegroundColor DarkGray
        } else {
            Write-Host "  Estilos aprendidos en OSMA: (aun ninguno - se llena con remember)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    exit 0
}

# === PROFILE (perfil completo) ===
if ($Action -eq "profile") {
    $memCli = Get-OsmaCli
    if ($Json) {
        $out = @{ styles = @($STYLE_DEFS.GetEnumerator() | ForEach-Object { @{ style = $_.Key; desc = $_.Value } }) }
        if ($memCli) {
            try {
                $rec = (& $memCli recall -Query "estilo preferencias del usuario" -Topic "user/style" -Limit 12 -Quiet 2>$null | Out-String).Trim()
                if ($rec -and $rec -notmatch 'Sin recuerdos|^$' -and $rec -notmatch '^\[\]$') {
                    try {
                        $rows = $rec | ConvertFrom-Json
                        $out.learned = ($rows | ForEach-Object { "[$($_.topic_key)] $($_.content)" }) -join ' | '
                    } catch { $out.learned = $rec }
                }
            } catch {}
        }
        $out | ConvertTo-Json -Depth 5
    } else {
        Write-Host ""
        Write-Host "  USER STYLE - perfil" -ForegroundColor Cyan
        Write-Host "  ====================" -ForegroundColor Cyan
        Write-Host "  Estilos que Atlas reconoce y como adapta:" -ForegroundColor Yellow
        foreach ($k in $STYLE_DEFS.Keys) {
            Write-Host ("    {0,-11} {1}" -f $k, $STYLE_DEFS[$k]) -ForegroundColor White
        }
        Write-Host ""
        if ($memCli) {
            try {
                $rec = (& $memCli recall -Query "estilo preferencias del usuario" -Topic "user/style" -Limit 12 -Quiet 2>$null | Out-String).Trim()
                if ($rec -and $rec -notmatch 'Sin recuerdos|^$' -and $rec -notmatch '^\[\]$') {
                    try {
                        $rows = $rec | ConvertFrom-Json
                        foreach ($r in $rows) {
                            Write-Host ("  [{0}] {1}" -f $r.topic_key, $r.content) -ForegroundColor DarkGray
                        }
                    } catch {
                        Write-Host "  $rec" -ForegroundColor DarkGray
                    }
                } else {
                    Write-Host "  Aun no hay historial aprendido (OSMA vacio para user/style)." -ForegroundColor DarkGray
                }
            } catch {}
        } else {
            Write-Host "  OSMA no disponible - solo catalogo de estilos." -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    exit 0
}

# === PROFILE-LEVEL: nivel de experticia acumulativo del usuario (novato/intermedio/experto) ===
# Aprendizaje acumulativo con OSMA: mide cuantos prompts, cuanta tecnicalidad y cuanta
# independencia tiene el usuario. La retroalimentacion se adapta: al novato se le explica,
# al experto se le va directo. Retroalimentacion SUMAMENTE FACIL para el nivel actual.
if ($Action -eq "profile-level") {
    $memCli = Get-OsmaCli
    $totalPrompts = 0
    $techCount = 0
    $ambiguousCount = 0
    $imperativeCount = 0
    $styleCounts = @{}
    if ($memCli) {
        try {
            $rec = (& $memCli recall -Query "estilo del usuario prompt" -Topic "user/style" -Limit 50 -Quiet 2>$null | Out-String).Trim()
            if ($rec -and $rec -notmatch 'Sin recuerdos|^$|^\[\]$') {
                try {
                    $rows = $rec | ConvertFrom-Json
                    foreach ($r in $rows) {
                        $totalPrompts++
                        if ($r.topic_key -match 'user/style/(\w+)') {
                            $s = $Matches[1]
                            if (-not $styleCounts.ContainsKey($s)) { $styleCounts[$s] = 0 }
                            $styleCounts[$s]++
                            if ($s -in @('directo')) { $imperativeCount++ }
                            if ($s -in @('ambiguo')) { $ambiguousCount++ }
                        }
                        # tecnicalidad: el prompt menciona conceptos tecnicos
                        if ($r.content -match 'component|api|schema|rls|endpoint|deploy|migration|test|react|supabase|sql') { $techCount++ }
                    }
                } catch {}
            }
        } catch {}
    }

    # Calcular nivel: prompts + tecnicalidad + independencia (menos ambiguo = mas experto)
    $level = 'novato'
    $score = 0
    if ($totalPrompts -ge 5) { $score += 1 }
    if ($totalPrompts -ge 15) { $score += 1 }
    if ($totalPrompts -ge 30) { $score += 1 }
    if ($totalPrompts -gt 0 -and ($techCount / $totalPrompts) -ge 0.5) { $score += 2 }
    if ($totalPrompts -gt 0 -and ($imperativeCount / $totalPrompts) -ge 0.4) { $score += 2 }
    if ($totalPrompts -gt 0 -and ($ambiguousCount / $totalPrompts) -le 0.2) { $score += 1 }
    if ($score -ge 6) { $level = 'experto' }
    elseif ($score -ge 3) { $level = 'intermedio' }

    # Instrucciones de retroalimentacion POR NIVEL (sumamente facil de seguir para Atlas)
    $feedbackRules = @{
        novato = @{
            explain = 'SIEMPRE explica conceptos tecnicos en lenguaje simple (sin jerga sin definir).'
            detail = 'Respuestas con pasos numerados y ejemplos. Nada asumido.'
            questions = 'Haz TODAS las preguntas de clarificacion necesarias (mejor preguntar que adivinar).'
            suggestions = 'Sugiere la mejor opcion directamente y explica por que (el usuario aprende de ti).'
            tone = 'Cercano y motivador; celebra el progreso.'
        }
        intermedio = @{
            explain = 'Explica solo lo no-obvio; no definas conceptos basicos.'
            detail = 'Resumen + detalle bajo demanda. Pasos solo para tareas complejas.'
            questions = 'Pregunta solo lo critico (agrupa preguntas, max 2-3).'
            suggestions = 'Ofrece 2 opciones con pros/cons cortos y tu recomendacion.'
            tone = 'Directo y colaborativo.'
        }
        experto = @{
            explain = 'CERO explicaciones basicas. Ve directo al grano tecnico.'
            detail = 'Respuestas compactas: que se hizo, que falta, riesgos. Sin preambulos.'
            questions = 'Solo preguntas bloqueantes. Todo lo demas, decidelo tu con SUPUESTOS explicitos.'
            suggestions = 'Decisiones directas con justificacion de 1 linea.'
            tone = 'Par-a-par, minima friccion.'
        }
    }[$level]

    $out = [ordered]@{
        level = $level
        score = $score
        total_prompts_seen = $totalPrompts
        tech_ratio = if ($totalPrompts -gt 0) { [math]::Round($techCount / $totalPrompts, 2) } else { 0 }
        ambiguous_ratio = if ($totalPrompts -gt 0) { [math]::Round($ambiguousCount / $totalPrompts, 2) } else { 0 }
        style_counts = $styleCounts
        feedback_rules = $feedbackRules
    }
    if ($Json) { $out | ConvertTo-Json -Depth 5; exit 0 }
    Write-Host ''
    Write-Host '  USER PROFILE - NIVEL DE EXPERTICIA' -ForegroundColor Cyan
    Write-Host '  ==================================' -ForegroundColor Cyan
    Write-Host ("  Nivel: {0} (score {1})" -f $level.ToUpper(), $score) -ForegroundColor $(if ($level -eq 'experto') { 'Green' } elseif ($level -eq 'intermedio') { 'Yellow' } else { 'White' })
    Write-Host ("  Prompts aprendidos: {0} | tecnicos: {1:P0} | ambiguos: {2:P0}" -f $totalPrompts, $out.tech_ratio, $out.ambiguous_ratio) -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Como Atlas retroalimenta a este usuario:' -ForegroundColor Yellow
    Write-Host ("    Explicar:     {0}" -f $feedbackRules.explain) -ForegroundColor White
    Write-Host ("    Detalle:      {0}" -f $feedbackRules.detail) -ForegroundColor White
    Write-Host ("    Preguntas:    {0}" -f $feedbackRules.questions) -ForegroundColor White
    Write-Host ("    Sugerencias:  {0}" -f $feedbackRules.suggestions) -ForegroundColor White
    Write-Host ("    Tono:         {0}" -f $feedbackRules.tone) -ForegroundColor White
    Write-Host ''
    exit 0
}
