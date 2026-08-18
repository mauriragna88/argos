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
    "boss" = @("feature completa","nueva area","modulo entero","v1","mvp","from scratch","build a","rebuild","new project","greenfield","kickstart","bootstrap","launch","go-live","prod-ready","complete feature","end to end")
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

$modelTier = 'flash'
$recommendedModel = 'opencode-go/deepseek-v4-flash'
if ($difficulty -ge 4) {
    $modelTier = 'highest'
    $recommendedModel = 'opencode-go/qwen3.8-max'
} elseif ($difficulty -eq 3) {
    $modelTier = 'pro'
    $recommendedModel = switch ($bestType) {
        'frontend'      { 'opencode-go/gpt-5.6-luna' }
        'architecture'  { 'opencode-go/kimi-k2.6' }
        'research'      { 'opencode-go/deepseek-v4-flash' }  # ranger: workhorse basta
        'devops'        { 'opencode-go/deepseek-v4-pro' }
        default         { 'opencode-go/deepseek-v4-pro' }    # backend / fix / unknown
    }
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
            notes = "quest-detector heuristic | gate=$triageGate$(if ($isAmbiguous) { ' | ambiguity: Atlas complementa antes de clasificar' })"
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
    Write-Host "  L0 quest:      $isL0" -ForegroundColor $(if ($isL0) { "Red" } else { "DarkGray" })
    Write-Host "  Has chain:     $hasChain" -ForegroundColor DarkGray
    Write-Host "  Estimated HP:  $estimatedHP" -ForegroundColor DarkGray
    Write-Host "  Estimated MP:  $estimatedMP tokens" -ForegroundColor DarkGray
    Write-Host ("  Triage:        dificultad {0}/4 · modelo: {1} ({2})" -f $difficulty, $recommendedModel, $modelTier) -ForegroundColor Green
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
    Write-Host ("║ {0,-41} ║" -f " → ¿Ejecutar? (sí / ajustar / no)") -ForegroundColor Yellow
    Write-Host ("╚" + ("═" * 43) + "╝") -ForegroundColor Cyan
    Write-Host ""
}

# Restaurar encoding previo (higiene; el script normalmente termina aqui)
if ($prevConsoleEncoding) {
    try { [Console]::OutputEncoding = $prevConsoleEncoding } catch {}
}
