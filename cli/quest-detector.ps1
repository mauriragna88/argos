# quest-detector.ps1 - B2 Classify user prompt into quest type + suggested party
# =============================================
# Detects quest_type (frontend/backend/fix/architecture/research/devops/boss)
# Returns JSON with: quest_type, complexity, suggested_party, is_l0, estimated_hp/mp
# With -Recommend adds a recommendation block (gate required/auto_pass, cost, risk).
#
# Usage:
#   .\quest-detector.ps1 -Prompt "crea login form con Zod"
#   .\quest-detector.ps1 -Prompt "..." -Json
#   .\quest-detector.ps1 -Prompt "..." -Recommend

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Prompt = "",
    [switch]$Json,
    [switch]$Silent,
    [switch]$Recommend,
    [switch]$NoLog,    # Prompt Triage: no hacer append a .arnes/triage-log.jsonl
    [switch]$SkipOsma, # Prompt Triage: no consultar OSMA (experiencias similares)
    [switch]$NoStyle   # User Style: no registrar el estilo del prompt en OSMA
)

$ErrorActionPreference = "Stop"

# Encoding-robust: PS 5.1 cachea el encoding del host en el PRIMER Write-Host;
# setear [Console]::OutputEncoding despues no tiene efecto. Forzamos consola
# UTF-8 ANTES de cualquier output humano para que la caja no-ASCII (box-drawing,
# acentos) renderice limpia. El JSON path (-Json) no usa Write-Host: queda intacto.
$prevConsoleEncoding = $null
if (-not $Json -and -not $Silent) {
    try {
        $prevConsoleEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    } catch {}
}

if (-not $Prompt) {
    Write-Error "Prompt required"
    exit 1
}

$promptLower = $Prompt.ToLower()

# === Detection rules: keyword -> quest_type ===
$patterns = @{
    "frontend" = @("componente","component","tsx","jsx","ui","css","tailwind","modal","dashboard","formulario","form","login form","signup","pagina","pantalla","responsive","animacion","sidebar","navbar","header","footer","button","input","select","checkbox","radio","card","hero","alert","tooltip","dialog","dropdown","menu","tabs","accordion","carousel","toast","avatar","badge","progress","skeleton","table","list","grid","layout","flexbox","gridbox","styled","emotion","css-in-js")
    "backend" = @("api","endpoint","route","supabase","postgres","postgresql","prisma","schema","query","mutation","rls","server action","middleware","zod","webhook","backend","server","database","table","migration","stored procedure","trigger","function","sql","rest","graphql","trpc","rpc","edge function","cron")
    "fix" = @("bug","fix","broken","error","fail","no funciona","crashea","crash","404","500","regression","regress","broken","doesn't work","won't work","failing","exception","stack trace","undefined","null pointer","race condition","memory leak","crashed")
    "architecture" = @("arquitectura","architecture","plan","redisen","refactor mayor","migrar","migration","monorepo","design system","project structure","adr","module","module boundary","clean architecture","hexagonal","microservice","monolith","serverless","event-driven","cqrs","event sourcing")
    "research" = @("investiga","busca","compara","que libreria","best practice","mejor forma","docs","documentation","como se hace","how to","tutorial","benchmark","comparison","library comparison","alternatives","vs")
    "devops" = @("deploy","ci","cd","docker","production","prod","rollback","vercel","netlify","railway","fly","github actions","pipeline","workflow","build","release","tag","semver","infrastructure","k8s","kubernetes","terraform","ansible","helm")
    "boss" = @("feature completa","nueva area","nueva área","modulo entero","módulo entero","v1","mvp","from scratch","desde cero","build a","rebuild","new project","proyecto nuevo","greenfield","kickstart","bootstrap","launch","go-live","prod-ready","complete feature","end to end","plataforma completa","app completa","sistema completo")
}

# L0 indicators (require user confirmation)
$l0Indicators = @("delete","bulk delete","destroy","drop table","rm -rf","production deploy","prod deploy","force push","git reset","schema migration","rls change","rls policy","rls modification","auth change","rollback prod","rollback production","secret rotation","aws","gcp","azure","database migration","breaking change","produccion","producción","rollback","migracion","migración","rls","borrar","rotacion de secrets","rotación de secrets")

# Count matches per quest_type
$scores = @{}
foreach ($qt in $patterns.Keys) {
    $score = 0
    foreach ($kw in $patterns[$qt]) {
        if ($promptLower.Contains($kw)) { $score++ }
    }
    $scores[$qt] = $score
}

# Find max
$bestType = "unknown"
$bestScore = 0
foreach ($qt in $scores.Keys) {
    if ($scores[$qt] -gt $bestScore) {
        $bestScore = $scores[$qt]
        $bestType = $qt
    }
}

if ($bestScore -eq 0) {
    $bestType = "unknown"
}

# === L0 detection ===
$isL0 = $false
foreach ($ind in $l0Indicators) {
    if ($promptLower.Contains($ind)) {
        $isL0 = $true
        break
    }
}

# === Suggested party by quest_type ===
$parties = @{
    "frontend"      = @("vivi","eiko")
    "backend"       = @("ansem","eiko")
    "fix"           = @("kuja","eiko")
    "architecture"  = @("amarant","eremez")
    "research"      = @("eremez")
    "devops"        = @("eiko")
    "boss"          = @("vivi","ansem","eiko","kuja","amarant","eremez")
    "unknown"       = @("amarant")
}
$suggestedParty = $parties[$bestType]

# === Justificacion del party (retroalimentacion explicita: POR QUE este party) ===
# El "para esta tarea trabajamos con X porque..." — cada rol es experto en su dominio.
# Analogia del usuario: no mandas a un ingeniero a hacer trabajo de secretaria.
$partyReasons = @{
    "frontend"     = "Vivi (Mage) es la experta UI/UX (React, Tailwind); Eiko la acompana (regla fija: soporte y QA de builds)."
    "backend"      = "Ansem (Paladin) es el backend tank (APIs, Supabase, Zod, RLS); Eiko da soporte devops."
    "fix"          = "Kuja (Rogue) caza bugs con precision quirurgica; Eiko repara builds si algo se rompe."
    "architecture" = "Amarant (Monk) disena la arquitectura (SDD, clean-arch); Eremez (Ranger) investiga referencias."
    "research"     = "Eremez (Ranger) es el investigador/librarian: rapido, cita fuentes, no inventa."
    "devops"       = "Eiko (Cleric) es la healer/devops: deploy, CI/CD, builds, rollback."
    "boss"         = "Quest completa: todo el party (Vivi+Ansem+Eiko+Kuja+Amarant+Eremez) con sus especialidades."
    "unknown"      = "Tipo no claro: Amarant (Monk) planifica primero y Atlas decide tras complementar."
}
$partyReason = $partyReasons[$bestType]
# Auron se une por seguridad: anadir su justificacion
if ($suggestedParty -contains 'auron') {
    $partyReason += " Auron (Warden) se une: el quest toca auth/RLS/secrets/deploy (superficie de seguridad)."
}

# === Auron auto-join (SEGURIDAD): RLS/security keywords -> Auron al party ===
# Misma regla que argos-party.ps1: si el quest toca auth/RLS/secrets/deploy,
# Auron entra al party sugerido (consistencia detector <-> ejecucion).
$securityKeywords = 'auth|login|password|token|secret|rls|row.level|supabase.*policy|apikey|api.key|ssl|https|cors|sanitize|inyeccion|injection|deploy|produccion|production|permisos|roles|encrypt|hash|migracion|migración|rollback'
if ($promptLower -match $securityKeywords -and $suggestedParty -notcontains 'auron') {
    $suggestedParty = @($suggestedParty) + @('auron')
}

# === Complexity heuristic ===
$promptLen = $Prompt.Length
$complexity = "simple"
$estimatedHP = 20
$estimatedMP = 3000

if ($promptLen -lt 30) {
    $complexity = "trivial"
    $estimatedHP = 10
    $estimatedMP = 1000
} elseif ($promptLen -lt 80) {
    $complexity = "simple"
    $estimatedHP = 20
    $estimatedMP = 3000
} elseif ($promptLen -lt 200) {
    $complexity = "medium"
    $estimatedHP = 40
    $estimatedMP = 6000
} elseif ($promptLen -lt 500) {
    $complexity = "complex"
    $estimatedHP = 70
    $estimatedMP = 12000
} else {
    $complexity = "boss"
    $estimatedHP = 150
    $estimatedMP = 25000
}

if ($bestType -eq "boss") {
    $complexity = "boss"
    $estimatedHP = 150
    $estimatedMP = 25000
}

if ($isL0) {
    $complexity = "complex"
    $estimatedHP = 100
    $estimatedMP = 15000
}

# === Multi-quest chain detection ===
$chainKeywords = @(" y "," then "," luego "," despues "," also "," and then "," segundo "," finalmente "," finally "," next ")
$hasChain = $false
foreach ($kw in $chainKeywords) {
    if ($promptLower.Contains($kw)) {
        $hasChain = $true
        break
    }
}

# === Quest chain splitting ===
# Divide prompt en sub-quests cuando hay chain keywords
$subQuests = @($Prompt)
if ($hasChain) {
    $splitPattern = "(\s+(y|then|luego|despues|also|and then|segundo|finalmente|finally|next)\s+)"
    $parts = [regex]::Split($Prompt, $splitPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # Limpiar: solo las partes con contenido (no delimitadores puros)
    $cleanParts = @()
    foreach ($p in $parts) {
        $t = $p.Trim()
        if ($t -match "^(y|then|luego|despues|also|segundo|finalmente|finally|next)$") { continue }
        if ($t.Length -gt 3) { $cleanParts += $t }
    }
    if ($cleanParts.Count -gt 1) {
        $subQuests = @($cleanParts)
    }
}

# === Build output ===
$result = @{
    prompt = $Prompt
    quest_type = $bestType
    confidence = $bestScore
    complexity = $complexity
    suggested_party = $suggestedParty
    party_reason = $partyReason
    is_l0 = $isL0
    has_chain = $hasChain
    sub_quests = $subQuests
    sub_quest_count = $subQuests.Count
    estimated_hp = $estimatedHP
    estimated_mp = $estimatedMP
    all_scores = $scores
    timestamp = (Get-Date).ToString("o")
}

# === PROMPT TRIAGE: difficulty 1-4 + modelo recomendado + memoria ===
# Protocolo: core/protocols/prompt-triage.md
$difficulty = 2
switch ($complexity) {
    'trivial' { $difficulty = 1 }
    'simple'  { $difficulty = 2 }
    'medium'  { $difficulty = 3 }
    'complex' { $difficulty = 3 }
    'boss'    { $difficulty = 4 }
}
if ($bestType -eq 'boss') { $difficulty = 4 }
if ($isL0 -and $difficulty -lt 3) { $difficulty = 3 }  # L0 manda: minimo complejo

# === TRIAGE V3: CONTINUACION ("sigue", "continua", ...) -> el contexto manda ===
# Un "sigue adelante" de 6 caracteres caeria en trivial por longitud. Si el prompt
# es de continuacion, hereda la dificultad del contexto ABIERTO (ultimo evento
# PENDING en .arnes/triage-log.jsonl) y, sin contexto abierto, usa piso 2 (nunca trivial).
$continuationPatterns = @('sigue adelante','sigue','continua','continúa','continuar','keep going','go on','procede','avanza','dale','next step')
$isContinuation = $false
foreach ($cp in $continuationPatterns) {
    if ($promptLower.Contains($cp)) { $isContinuation = $true; break }
}
# Evitar falsos positivos: "sigue fallando el login" es un fix nuevo, no continuacion.
# Solo cuenta como continuacion si el prompt es corto o no matcheo keywords de dominio.
if ($isContinuation -and $Prompt.Trim().Length -gt 40 -and $bestScore -gt 0) { $isContinuation = $false }

$contextInherited = $false
if ($isContinuation) {
    try {
        $triageLogPath = Join-Path (Split-Path $PSScriptRoot -Parent) '.arnes\triage-log.jsonl'
        if (Test-Path $triageLogPath) {
            $recent = @(Get-Content $triageLogPath -Tail 50 -ErrorAction SilentlyContinue)
            for ($i = $recent.Count - 1; $i -ge 0; $i--) {
                try { $prevEvt = $recent[$i] | ConvertFrom-Json } catch { continue }
                if ($prevEvt.event -eq 'triage' -and $prevEvt.outcome -eq 'PENDING' -and $prevEvt.difficulty) {
                    $difficulty = [Math]::Max([int]$prevEvt.difficulty, 1)
                    $contextInherited = $true
                    break
                }
            }
        }
    } catch {}
    if (-not $contextInherited -and $difficulty -lt 2) { $difficulty = 2 }  # piso: continuacion nunca trivial
}

# === CATALOGO MULTI-MODELO (2026-09-12): recomienda, no bloquea ===
# flash   -> deepseek-v4.1-flash / glm-5.3-flash   (repetitivo, volumen alto, barato)
# pro     -> gpt-5.6-luna / gpt-5.6-terra          (complejo: multi-archivo, raiz no evidente)
# highest -> gpt-6-astra / gpt-5.6-sol             (planeacion/arquitectura/boss)
# Ids canonicos: el prefijo del proveedor (opencode-go/, openai-codex/, nvidia/)
# se resuelve en runtime segun las conexiones activas.
$MODEL_CATALOG = @{
    flash   = @{ primary = 'deepseek-v4.1-flash'; alternatives = @('glm-5.3-flash') }
    pro     = @{ primary = 'gpt-5.6-luna'; alternatives = @('gpt-5.6-terra', 'glm-5.3-flash') }
    highest = @{ primary = 'gpt-6-astra'; alternatives = @('gpt-5.6-sol', 'gpt-5.6-luna') }
}
$modelTier = switch ($difficulty) {
    4 { 'highest' }
    3 { 'pro' }
    default { 'flash' }
}
$recommendedModel = $MODEL_CATALOG[$modelTier].primary
$recommendedAlternatives = @($MODEL_CATALOG[$modelTier].alternatives)

# === MODELOS EN USO (solo lectura) + ADVISORY: el modelo NUNCA se cambia en automatico ===
# Lee ~/.config/arnes/agent-models.json (fuente de verdad de los modelos desplegados)
# para reportar QUE estas usando y QUE se sugiere. El switch siempre lo hace el usuario:
# el harness solo aconseja ("para esta/siguiente tarea usa tal y por esto").
$currentModel = ''
$modelsInUse = @()
try {
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
    $amPath = Join-Path $homeDir '.config\arnes\agent-models.json'
    if (Test-Path $amPath) {
        $amData = Get-Content $amPath -Raw | ConvertFrom-Json
        $inUse = @()
        foreach ($prop in $amData.agents.PSObject.Properties) {
            if ($prop.Value) { $inUse += [string]$prop.Value }
        }
        $modelsInUse = @($inUse | Sort-Object -Unique)
        if ($amData.agents.atlas) { $currentModel = [string]$amData.agents.atlas }
        elseif ($modelsInUse.Count -gt 0) { $currentModel = $modelsInUse[0] }
    }
} catch {}

# Inferir el tier del modelo en uso (canon = ultimo segmento del id)
$currentTier = ''
if ($currentModel) {
    $canonCurrent = ($currentModel -split '/')[-1]
    foreach ($t in @('flash','pro','highest')) {
        if ($MODEL_CATALOG[$t].primary -eq $canonCurrent -or $MODEL_CATALOG[$t].alternatives -contains $canonCurrent) { $currentTier = $t; break }
    }
    if (-not $currentTier -and $canonCurrent -match 'flash') { $currentTier = 'flash' }
}

# Mensaje de retroalimentacion: que usas, que te sugiero y por que (informativo, no automatico)
$advisory = if ($currentModel -and $currentTier -and $currentTier -ne $modelTier) {
    "Estas usando $currentModel (tier $currentTier). Para esta tarea (dificultad $difficulty, $bestType) te sugiero $recommendedModel (tier $modelTier)$(if ($recommendedAlternatives) { "; alternativas: $($recommendedAlternatives -join ', ')" }). NO se cambia en automatico: el switch lo haces tu."
} elseif ($currentModel) {
    "Estas usando $currentModel. Sugerencia informativa para dificultad ${difficulty}: $recommendedModel (tier $modelTier). El modelo NUNCA se cambia en automatico."
} else {
    "Recomendacion para esta tarea: $recommendedModel (tier $modelTier)$(if ($recommendedAlternatives) { "; alternativas: $($recommendedAlternatives -join ', ')" }). No se cambia en automatico: tu eliges el modelo."
}

$triageGate = if ($difficulty -ge 4 -or $isL0) { 'required' } elseif ($difficulty -eq 3) { 'ask' } else { 'auto_pass' }

# AMBIGUITY: prompt abierto -> Atlas complementa antes de clasificar (V1.3).
# El nivel final = prompt del usuario + complemento de Atlas; el complemento puede
# subir el nivel, asi que un prompt ambiguo sube el gate a 'ask' (Atlas enriquecera).
$ambiguityPatterns = @("creas mejor","creas que mejor","como tu veas","lo que mejor","alguna idea","sugiere","sugiereme","recomiendame","recomiendame algo","que opinas","que me recomiendas","mejor forma","no se","nose","no se como","quiza","tal vez","a poco","no estoy seguro","ayudame a decidir","que haria","que harías","segun tu","según tu","que prefieres","tienes alguna","podrias sugerir","dame ideas","me gustaria algo","haz algo","hazme algo")
$isAmbiguous = $false
if ($bestScore -eq 0) { $isAmbiguous = $true }   # 0 keywords: ni sabemos el tipo de quest
foreach ($ap in $ambiguityPatterns) {
    if ($promptLower.Contains($ap)) { $isAmbiguous = $true; break }
}
if ($isAmbiguous -and $triageGate -eq 'auto_pass') {
    $triageGate = 'ask'   # Atlas va a complementar; el nivel puede subir -> confirmar
}

# === TRIAGE V2: VAGUENESS SCORE + INFO GAPS + CLARIFY QUESTIONS ===
# Retroalimentacion EXACTA cuando el prompt es vago o ambiguo. En vez de solo
# marcar "ambiguo", medimos QUE falta y generamos las preguntas exactas que
# Atlas debe hacer al usuario ANTES de trabajar (NEED_INFO protocol).
# 0-30 claro | 31-60 mejorable | 61-100 muy vago (clarificacion obligatoria)
$vaguenessScore = 0
$infoGaps = @()
$clarifyQuestions = @()

# 1. Longitud del prompt (muy corto = poco contexto)
if ($Prompt.Length -lt 20) { $vaguenessScore += 25 }
elseif ($Prompt.Length -lt 40) { $vaguenessScore += 15 }
elseif ($Prompt.Length -lt 80) { $vaguenessScore += 5 }

# 2. Tipo de quest desconocido (ni una keyword de dominio)
if ($bestScore -eq 0) { $vaguenessScore += 30 }

# 3. Sin objetivo tecnico detectable (no menciona archivo/feature/bug/lib)
$hasTechTarget = $promptLower -match '\.(tsx|ts|jsx|js|py|sql|json|css)|componente|api|endpoint|tabla|schema|funcion|función|clase|pagina|página|test|bug|error|deploy|migracion|migración'
if (-not $hasTechTarget) { $vaguenessScore += 15; $infoGaps += 'objetivo_tecnico' }

# 4. Gaps especificos por tipo de quest (que le falta a CADA dominio)
switch ($bestType) {
    'frontend' {
        if (-not ($promptLower -match 'componente|pagina|página|seccion|sección|modal|formulario|form')) { $infoGaps += 'que_ui_exacta' ; $clarifyQuestions += '¿Que pantalla o componente exactamente? (ej: formulario de login, tabla de clientes)' }
        if (-not ($promptLower -match 'tailwind|css|estilo|color|dark|tema')) { $infoGaps += 'estilo_deseado' ; $clarifyQuestions += '¿Tiene diseño/referencia visual o lo diseño yo? (si hay Figma/mockup, pasalo)' }
    }
    'backend' {
        if (-not ($promptLower -match 'tabla|schema|entidad|modelo|endpoint|api|ruta')) { $infoGaps += 'que_backend_exacto'; $clarifyQuestions += '¿Que endpoint/tabla/entidad exactamente? (nombre y campos si los tienes)' }
        if (-not ($promptLower -match 'rls|permiso|rol|auth|validacion|validación|zod')) { $infoGaps += 'reglas_negocio'; $clarifyQuestions += '¿Quien puede usar esto? (roles/permisos) ¿Hay validaciones especiales?' }
    }
    'fix' {
        if (-not ($promptLower -match 'error|excepción|excepcion|stack|trace|log|mensaje')) { $infoGaps += 'mensaje_error'; $clarifyQuestions += '¿Cual es el mensaje de error EXACTO? (pegalo completo si puedes)' }
        if (-not ($promptLower -match 'cuando|al |pasos|reproduc')) { $infoGaps += 'pasos_reproduccion'; $clarifyQuestions += '¿Cuando pasa? (pasos para reproducirlo)' }
    }
    'architecture' {
        if (-not ($promptLower -match 'porque|motivo|problema|necesito|goal|objetivo')) { $infoGaps += 'motivacion'; $clarifyQuestions += '¿Que problema real resuelve este cambio? (el "para qué")' }
        if (-not ($promptLower -match 'alcance|solo|incluye|excluye')) { $infoGaps += 'alcance'; $clarifyQuestions += '¿Alcance? (que incluye y que queda fuera)' }
    }
    'devops' {
        if (-not ($promptLower -match 'vercel|netlify|docker|aws|github|servidor|hosting')) { $infoGaps += 'plataforma_deploy'; $clarifyQuestions += '¿A donde se despliega? (Vercel, Docker, servidor propio...)' }
    }
}
# 5. Sin criterio de exito (como sabremos que quedo bien)
if (-not ($promptLower -match 'debe|tiene que|criterio|aceptacion|aceptación|esperado|correcto')) { $vaguenessScore += 10; $infoGaps += 'criterio_exito' }

# Pregunta universal si todo lo demas es vago
if ($vaguenessScore -ge 60 -and $clarifyQuestions.Count -eq 0) {
    $clarifyQuestions += '¿Puedes describir con mas detalle que quieres lograr? (objetivo, alcance, como se usara)'
}

# Normalizar score a 0-100 (cap)
if ($vaguenessScore -gt 100) { $vaguenessScore = 100 }

# Clarificacion obligatoria: score alto -> gate sube a 'required' (Atlas DEBE preguntar)
$needsClarification = ($vaguenessScore -ge 61 -and $clarifyQuestions.Count -gt 0)
if ($needsClarification -and $triageGate -in @('auto_pass','ask')) {
    $triageGate = 'ask'
}

# OSMA consulta (best-effort): experiencias similares para afinar la clasificacion
$osmaHint = ''
if (-not $SkipOsma) {
    try {
        . (Join-Path $PSScriptRoot 'osma-resolve.ps1')
        $memCli = Get-OsmaMemoryCli
        if ($memCli) {
            $exp = (& $memCli experience -ExperienceAction search -Query $Prompt -Limit 3 -Quiet 2>$null | Out-String).Trim()
            $rec = (& $memCli recall -Query $Prompt -Limit 3 -Quiet 2>$null | Out-String).Trim()
            $parts = @()
            if ($exp -and $exp -notmatch 'Sin experiencias|^$|^\[\]$') { $parts += "exp: $exp" }
            if ($rec -and $rec -notmatch 'Sin recuerdos|^$|^\[\]$') { $parts += "rec: $rec" }
            if ($parts.Count -gt 0) { $osmaHint = $parts -join ' | ' }
        }
    } catch {}

    # User Style: aprender el estilo del prompt (OSMA user/style/*) - best effort
    if (-not $NoStyle) {
        try {
            $styleScript = Join-Path $PSScriptRoot 'user-style.ps1'
            if (Test-Path $styleScript) {
                $null = & $styleScript -Action remember -Prompt $Prompt -Quiet 2>&1
            }
        } catch {}
    }
}

$result.difficulty = $difficulty
$result.model_tier = $modelTier
$result.recommended_model = $recommendedModel
$result.triage_gate = $triageGate
$result.is_ambiguous = $isAmbiguous
$result.osma_hint = $osmaHint
# TRIAGE V2: vagueness + info gaps + preguntas de clarificacion
$result.vagueness_score = $vaguenessScore
$result.info_gaps = $infoGaps
$result.clarify_questions = $clarifyQuestions
$result.needs_clarification = $needsClarification
# TRIAGE V3: continuacion + alternativas del catalogo
$result.is_continuation = $isContinuation
$result.context_inherited = $contextInherited
$result.recommended_alternatives = $recommendedAlternatives
# Advisory de modelos: que usas vs que se sugiere (el switch siempre es del usuario)
$result.current_model = $currentModel
$result.models_in_use = $modelsInUse
$result.advisory = $advisory

# Memoria: append a .arnes/triage-log.jsonl (event log append-only, no memoria paralela)
if (-not $NoLog) {
    try {
        $logDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.arnes'
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $logFile = Join-Path $logDir 'triage-log.jsonl'
        $signals = @()
        if ($isL0) { $signals += 'l0' }
        if ($hasChain) { $signals += 'chain' }
        if ($bestType -eq 'unknown') { $signals += 'unknown_type' }
        if ($isAmbiguous) { $signals += 'ambiguity' }
        if ($isContinuation) { $signals += 'continuation' }
        $evt = [ordered]@{
            event = 'triage'
            ts = (Get-Date).ToString('o')
            prompt_type = $bestType
            difficulty = $difficulty
            signals = $signals
            similarity = @{ matched = [bool]$osmaHint; hint = $osmaHint }
            model_used = $recommendedModel
            recommendation = $modelTier
            user_decision = 'auto'
            outcome = 'PENDING'
            notes = "quest-detector heuristic | gate=$triageGate$(if ($isAmbiguous) { ' | ambiguity: Atlas complementa antes de clasificar' })$(if ($contextInherited) { ' | continuacion: dificultad heredada de triage PENDING' })"
        } | ConvertTo-Json -Compress
        Add-Content -Path $logFile -Value $evt -Encoding UTF8
    } catch {}
}

# === Recommendation block (only when -Recommend) ===
if ($Recommend) {
    # Costo estimado: 1K tokens ~ $0.005 -> MP*0.0005 centavos, redondeado a 2 decimales.
    # Suma epsilon para evitar que el float 0.015 -> 0.01 (banker's rounding).
    $costCents = [int][math]::Round($estimatedMP * 0.0005 + 0.000001)
    $estimatedCostUsd = $costCents / 100.0

    $risk = "none"
    if ($isL0) {
        $risk = "L0"
    } elseif ($complexity -in @("complex","boss")) {
        $risk = "medium"
    }

    $gate = "auto_pass"
    if ($isL0 -or $complexity -in @("complex","boss")) {
        $gate = "required"
    }

    $agentLabels = @{
        "vivi" = "Vivi (Mage)"
        "eiko" = "Eiko (Cleric)"
        "ansem" = "Ansem (Paladin)"
        "kuja" = "Kuja (Rogue)"
        "amarant" = "Amarant (Monk)"
        "eremez" = "Eremez (Ranger)"
        "auron" = "Auron (Warden)"
        "bran" = "Bran (Seer)"
        "quina" = "Quina (Banker)"
        "varys" = "Varys (Spider)"
        "tywin" = "Tywin (Verifier)"
        "sam" = "Sam (Counselor)"
    }
    $labelParts = foreach ($a in $suggestedParty) {
        if ($agentLabels.ContainsKey($a)) { $agentLabels[$a] } else { $a }
    }
    $partyLabel = $labelParts -join " + "

    $recommendation = @{
        title = "Quest candidata detectada"
        party_label = $partyLabel
        estimated_cost_usd = $estimatedCostUsd
        risk = $risk
        gate = $gate
        message = "Esto parece trabajo para quest: $bestType. Party sugerido: $($suggestedParty -join ', '). ¿Ejecutar?"
    }
    $result.recommendation = $recommendation
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
    exit 0
}

if (-not $Silent) {
    Write-Host ""
    Write-Host "  QUEST DETECTOR" -ForegroundColor Cyan
    Write-Host "  ==============" -ForegroundColor Cyan
    Write-Host "  Quest type:    $bestType (score: $bestScore)" -ForegroundColor White
    Write-Host "  Complexity:    $complexity" -ForegroundColor White
    Write-Host "  Party:         $($suggestedParty -join ', ')" -ForegroundColor Yellow
    Write-Host "  Por que:       $partyReason" -ForegroundColor DarkGray
    Write-Host "  L0 quest:      $isL0" -ForegroundColor $(if ($isL0) { "Red" } else { "DarkGray" })
    Write-Host "  Has chain:     $hasChain" -ForegroundColor DarkGray
    Write-Host "  Estimated HP:  $estimatedHP" -ForegroundColor DarkGray
    Write-Host "  Estimated MP:  $estimatedMP tokens" -ForegroundColor DarkGray
    Write-Host ("  Triage:        dificultad {0}/4 · sugerido: {1} ({2})" -f $difficulty, $recommendedModel, $modelTier) -ForegroundColor Green
    if ($currentModel) {
        Write-Host ("  En uso:        {0}  (tu eliges el modelo; no se cambia en automatico)" -f $currentModel) -ForegroundColor DarkGray
    }
    Write-Host ""
}

# === Human recommendation block (only when -Recommend) ===
# El encoding UTF-8 ya se fijo al inicio del script (antes del primer Write-Host).
if ($Recommend -and -not $Silent) {
    $mpK = [int][math]::Round($estimatedMP / 1000)
    $shortParty = ($suggestedParty -join " + ")
    if ($shortParty.Length -gt 41) { $shortParty = $shortParty.Substring(0, 38) + "..." }
    $l0Txt = "no"; if ($isL0) { $l0Txt = "sí" }
    Write-Host ("╔" + ("═" * 43) + "╗") -ForegroundColor Cyan
    Write-Host ("║ {0,-41} ║" -f "[ATLAS] RECOMENDACIÓN DE QUEST") -ForegroundColor Yellow
    Write-Host ("║ {0,-41} ║" -f (" Tipo: $bestType ($bestScore keywords)")) -ForegroundColor White
    Write-Host ("║ {0,-41} ║" -f (" Party sugerido: $shortParty")) -ForegroundColor Yellow
    Write-Host ("║ {0,-41} ║" -f (" Costo est.: $mpK" + "K tokens · ~$" + ("{0:N2}" -f $estimatedCostUsd))) -ForegroundColor Yellow
    Write-Host ("║ {0,-41} ║" -f (" Complejidad: $complexity · L0: $l0Txt")) -ForegroundColor White
    Write-Host ("║ {0,-41} ║" -f (" Modelo: $recommendedModel ($modelTier)")) -ForegroundColor Green
    $curShort = if ($currentModel) { if ($currentModel.Length -gt 28) { $currentModel.Substring(0, 25) + '...' } else { $currentModel } } else { 'n/d' }
    Write-Host ("║ {0,-41} ║" -f (" En uso: $curShort · tu eliges")) -ForegroundColor DarkGray
    # TRIAGE V2: clarificacion si el prompt es vago (retroalimentacion exacta)
    if ($needsClarification) {
        Write-Host ("╠" + ("═" * 43) + "╣") -ForegroundColor Yellow
        Write-Host ("║ {0,-41} ║" -f (" ⚠ PROMPT VAGO (vagueness $vaguenessScore/100)")) -ForegroundColor Yellow
        foreach ($q in ($clarifyQuestions | Select-Object -First 3)) {
            $qt = $q
            while ($qt.Length -gt 41) {
                Write-Host ("║ {0,-41} ║" -f $qt.Substring(0, 41)) -ForegroundColor White
                $qt = "   " + $qt.Substring(41)
            }
            if ($qt) { Write-Host ("║ {0,-41} ║" -f $qt) -ForegroundColor White }
        }
        Write-Host ("║ {0,-41} ║" -f " → Responde y Atlas arma el quest bien.") -ForegroundColor Yellow
    }
    Write-Host ("║ {0,-41} ║" -f " → ¿Ejecutar? (sí / ajustar / no)") -ForegroundColor Yellow
    Write-Host ("╚" + ("═" * 43) + "╝") -ForegroundColor Cyan
    Write-Host ""
}

# Restaurar encoding previo (higiene; el script normalmente termina aqui)
if ($prevConsoleEncoding) {
    try { [Console]::OutputEncoding = $prevConsoleEncoding } catch {}
}
