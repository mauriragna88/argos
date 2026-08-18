# argos-context.ps1 - Context Compiler (Fase 2)
# =========================================================================
# Compila el contexto optimo del turno con PRESUPUESTO POR FUENTE y
# scoring de utilidad (context_utility_score). Fuentes:
#   memory     -> OSMA recall (observaciones relevantes)
#   experience -> OSMA experience search (experiencias validadas)
#   principles -> .arnes/principles/<dominio>.md (solo los relevantes al quest)
#   skills     -> metadata de skills (progressive disclosure: sin cargar SKILL.md)
#   evidence   -> contrato del quest actual + regression guards
#
# Reglas:
#   - Cada fuente tiene su propio presupuesto de tokens (Budget por fuente).
#   - Cada fila tiene context_utility_score = (relevance*0.4 + validation*0.3
#     + salience*0.3) * trust / (1 + tokens/100)
#   - Degradacion parcial: si una fuente falla, el compile continua (nunca
#     bloquea el turno).
#   - La telemetria informa los budgets; el piso de calidad es por protocolo.
#
# Uso:
#   .\cli\argos-context.ps1 -Action compile -Prompt "crea login con zod"
#   .\cli\argos-context.ps1 -Action compile -Prompt "..." -QuestType backend
#   .\cli\argos-context.ps1 -Action compile -Prompt "..." -Budgets '{"memory":600,"experience":400,"principles":300,"skills":250,"evidence":200}' -Json
#   .\cli\argos-context.ps1 -Action budgets

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("compile","budgets")]
    [string]$Action = "compile",
    [string]$Prompt = "",
    [string]$QuestType = "",
    [string]$Budgets = "",
    [switch]$Json,
    [switch]$Quiet,
    [string]$ArnesDir = ""
)

$ErrorActionPreference = "Continue"

# Encoding-robust: PS 5.1 cachea el encoding en el PRIMER output. Forzamos
# UTF-8 ANTES de cualquier salida (humana o JSON) para que los pipes entreguen
# bytes UTF-8 validos (sin esto, -Json sale en OEM y consumidores UTF-8 como
# python fallan al parsear). En -Json no hay Write-Host antes del JSON: seguro.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

if (-not $ArnesDir) {
    $cwd = (Get-Location).Path
    if (Test-Path (Join-Path $cwd ".arnes\config.json")) {
        $ArnesDir = Join-Path $cwd ".arnes"
    } else {
        $ArnesDir = ".arnes"
    }
}

# === Presupuestos por fuente (defaults) ===
$DEFAULT_BUDGETS = [ordered]@{
    memory     = 600
    experience = 400
    principles = 500
    skills     = 250
    evidence   = 200
}

$SOURCE_TRUST = @{
    memory     = 0.7
    experience = 0.9
    principles = 1.0
    skills     = 0.6
    evidence   = 1.0
}

# === Accion: budgets ===
if ($Action -eq "budgets") {
    if ($Json) {
        $DEFAULT_BUDGETS | ConvertTo-Json -Depth 4
    } else {
        Write-Host ""
        Write-Host "  CONTEXT COMPILER - budgets por fuente" -ForegroundColor Cyan
        Write-Host "  =====================================" -ForegroundColor Cyan
        foreach ($k in $DEFAULT_BUDGETS.Keys) {
            Write-Host ("  {0,-12} {1,5} tokens" -f $k, $DEFAULT_BUDGETS[$k]) -ForegroundColor White
        }
        Write-Host ("  {0,-12} {1,5} tokens" -f "TOTAL", (($DEFAULT_BUDGETS.Values | Measure-Object -Sum).Sum)) -ForegroundColor Yellow
        Write-Host "  (override con -Budgets '{\"memory\":600,...}')" -ForegroundColor DarkGray
        Write-Host ""
    }
    exit 0
}

if (-not $Prompt) { Write-Error "compile requiere -Prompt"; exit 1 }

# === Budgets (parse o defaults) ===
# Nota: $budgetMap es la variable de trabajo (el parametro $Budgets es string
# y en PS las variables son case-insensitive: no pueden chocar).
$budgetMap = @{}
foreach ($k in $DEFAULT_BUDGETS.Keys) { $budgetMap[$k] = [int]$DEFAULT_BUDGETS[$k] }
if ($Budgets) {
    try {
        $parsed = $Budgets | ConvertFrom-Json
        foreach ($k in $DEFAULT_BUDGETS.Keys) {
            if ($parsed.PSObject.Properties.Name -contains $k) {
                $budgetMap[$k] = [int]$parsed.$k
            }
        }
    } catch {
        # budgets invalidos -> defaults (degradacion silenciosa)
    }
}

# === Quest type (si no viene, inferencia ligera) ===
function Get-QuestTypeHint {
    param([string]$P)
    $l = $P.ToLower()
    if ($l -match "login|form|modal|dashboard|ui|component|frontend|boton|header|css|tailwind|react|vue") { return "frontend" }
    if ($l -match "api|endpoint|schema|supabase|postgres|backend|sql|query|migration|zod") { return "backend" }
    if ($l -match "test|bug|fix|error|broken") { return "fix" }
    if ($l -match "rls|auth|password|token|secret|security|permiso") { return "security" }
    if ($l -match "arquitectura|refactor|design|plan") { return "architecture" }
    return "general"
}
if (-not $QuestType) { $QuestType = Get-QuestTypeHint $Prompt }

# === Helpers ===
function Get-OsmaCli {
    try {
        . (Join-Path $PSScriptRoot 'osma-resolve.ps1')
        return Get-OsmaMemoryCli
    } catch { return $null }
}

function Get-TextTokens([string]$Text) {
    if (-not $Text) { return 0 }
    # estimacion: ~4 chars por token (mixto ES/EN/codigo)
    return [math]::Max(1, [int][math]::Ceiling($Text.Length / 4))
}

function Get-Relevance([string]$Prompt, [string]$Text) {
    $pw = $Prompt.ToLower() -split '\W+' | Where-Object { $_.Length -gt 3 } | Select-Object -Unique
    $tw = $Text.ToLower() -split '\W+' | Where-Object { $_.Length -gt 3 }
    if ($pw.Count -eq 0 -or $tw.Count -eq 0) { return 0.1 }
    $hits = 0
    foreach ($w in $pw) { if ($tw -contains $w) { $hits++ } }
    return [math]::Min(1.0, [math]::Round($hits / $pw.Count, 3))
}

function Get-Utility {
    param([double]$Relevance, [double]$Validation, [double]$Salience, [string]$Source, [int]$Tokens)
    $trust = $SOURCE_TRUST[$Source]; if (-not $trust) { $trust = 0.6 }
    $base = (0.4 * $Relevance) + (0.3 * $Validation) + (0.3 * $Salience)
    return [math]::Round(($base * $trust) / (1 + ($Tokens / 100.0)), 4)
}

# === Fuente: MEMORY (OSMA recall) ===
function Get-MemoryRows {
    param([string]$Query, [string]$Dir)
    $memCli = Get-OsmaCli
    if (-not $memCli) { return @() }
    $out = & $memCli recall -Query $Query -Limit 8 -Quiet 2>$null
    $rows = @()
    try {
        $data = (($out | Out-String).Trim()) | ConvertFrom-Json
        $i = 0
        foreach ($r in $data) {
            $text = "$($r.topic_key): $($r.content)"
            $tokens = Get-TextTokens $text
            $relevance = Get-Relevance $Query $text
            $salience = 1.0 - (0.1 * $i)
            if ($salience -lt 0.3) { $salience = 0.3 }
            $rows += [ordered]@{
                id = "mem-$($r.id)"
                source = "memory"
                text = $text
                tokens = $tokens
                relevance = $relevance
                validation = 0.5
                salience = $salience
                utility = Get-Utility -Relevance $relevance -Validation 0.5 -Salience $salience -Source "memory" -Tokens $tokens
            }
            $i++
        }
    } catch {}
    return $rows
}

# === Fuente: EXPERIENCE (OSMA experience search) ===
function Get-ExperienceRows {
    param([string]$Query, [string]$Dir)
    $memCli = Get-OsmaCli
    if (-not $memCli) { return @() }
    $out = & $memCli experience -ExperienceAction search -Query $Query -Limit 5 -Quiet 2>$null
    $rows = @()
    try {
        $data = (($out | Out-String).Trim()) | ConvertFrom-Json
        $i = 0
        foreach ($r in $data) {
            $text = "$($r.conclusion) | action: $($r.action)"
            $tokens = Get-TextTokens $text
            $relevance = Get-Relevance $Query $text
            $validation = [math]::Min(1.0, [math]::Max(0.2, [double]($r.confidence) + [double]($r.reward_signal) / 2))
            $salience = 1.0 - (0.15 * $i)
            if ($salience -lt 0.3) { $salience = 0.3 }
            $rows += [ordered]@{
                id = "exp-$($r.id)"
                source = "experience"
                text = $text
                tokens = $tokens
                relevance = $relevance
                validation = [math]::Round($validation, 3)
                salience = $salience
                utility = Get-Utility -Relevance $relevance -Validation $validation -Salience $salience -Source "experience" -Tokens $tokens
            }
            $i++
        }
    } catch {}
    return $rows
}

# === Fuente: PRINCIPLES (.arnes/principles/) ===
function Get-PrincipleRows {
    param([string]$Type, [string]$Dir)
    $principlesDir = Join-Path $Dir "principles"
    if (-not (Test-Path $principlesDir)) { return @() }
    $rows = @()
    # general.md siempre; el del dominio si existe
    $files = @()
    $general = Join-Path $principlesDir "general.md"
    if (Test-Path $general) { $files += $general }
    $domFile = Join-Path $principlesDir "$Type.md"
    if ($Type -ne "general" -and (Test-Path $domFile)) { $files += $domFile }
    $i = 0
    foreach ($f in $files) {
        $text = (Get-Content -LiteralPath $f -Raw).Trim()
        if (-not $text) { continue }
        $text = "[$Type] " + $text
        $tokens = Get-TextTokens $text
        $salience = 1.0 - (0.2 * $i)
        if ($salience -lt 0.5) { $salience = 0.5 }
        $rows += [ordered]@{
            id = "principle-$(Split-Path $f -Leaf)"
            source = "principles"
            text = $text
            tokens = $tokens
            relevance = 1.0   # son reglas de oro del harness: siempre relevantes si aplican
            validation = 1.0
            salience = $salience
            utility = Get-Utility -Relevance 1.0 -Validation 1.0 -Salience $salience -Source "principles" -Tokens $tokens
        }
        $i++
    }
    return $rows
}

# === Fuente: SKILLS (metadata only - progressive disclosure) ===
function Get-SkillRows {
    $skillsScript = Join-Path $PSScriptRoot "argos-skills.ps1"
    if (-not (Test-Path $skillsScript)) { return @() }
    $rows = @()
    try {
        $out = & $skillsScript -Action meta -Json 2>$null
        $data = ($out | Out-String).Trim() | ConvertFrom-Json
        $i = 0
        foreach ($s in $data.skills) {
            $text = "$($s.name): $($s.description)"
            if ($s.trigger) { $text += " (trigger: $($s.trigger))" }
            $tokens = Get-TextTokens $text
            $salience = 1.0 - (0.05 * $i)
            if ($salience -lt 0.4) { $salience = 0.4 }
            $rows += [ordered]@{
                id = "skill-$($s.name)"
                source = "skills"
                text = $text
                tokens = $tokens
                relevance = 0.5
                validation = 0.6
                salience = $salience
                utility = Get-Utility -Relevance 0.5 -Validation 0.6 -Salience $salience -Source "skills" -Tokens $tokens
            }
            $i++
        }
    } catch {}
    return $rows
}

# === Fuente: EVIDENCE (contrato quest actual + regression guards) ===
function Get-EvidenceRows {
    param([string]$Dir)
    $rows = @()
    # Contrato del quest actual (loop-state -> loop-contract get)
    $stateFile = Join-Path $Dir "loop-state.json"
    if (Test-Path $stateFile) {
        try {
            $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
            $qid = $state.current_quest_id
            if ($qid) {
                $lc = Join-Path $PSScriptRoot "loop-contract.ps1"
                if (Test-Path $lc) {
                    $out = & $lc -Action get -QuestId $qid -ArnesDir $Dir -Json 2>$null
                    $ct = ($out | Out-String).Trim()
                    if ($ct) {
                        $contract = $ct | ConvertFrom-Json
                        $text = "Quest ${qid}: $($contract.goal) | acceptance: $($contract.acceptance_criteria -join '; ') | max_iterations: $($contract.max_iterations) | retry_policy: $($contract.retry_policy)"
                        $tokens = Get-TextTokens $text
                        $rows += [ordered]@{
                            id = "contract-$qid"
                            source = "evidence"
                            text = $text
                            tokens = $tokens
                            relevance = 1.0
                            validation = 1.0
                            salience = 1.0
                            utility = Get-Utility -Relevance 1.0 -Validation 1.0 -Salience 1.0 -Source "evidence" -Tokens $tokens
                        }
                    }
                }
            }
        } catch {}
    }
    # Regression guards recientes
    $regScript = Join-Path $PSScriptRoot "regression.ps1"
    if (Test-Path $regScript) {
        try {
            $out = & $regScript -Action list -ArnesDir $Dir -Json 2>$null
            $regs = ($out | Out-String).Trim()
            if ($regs) {
                $data = $regs | ConvertFrom-Json
                $guards = @()
                if ($data.guards) { $guards = @($data.guards) }
                $guards | Select-Object -First 3 | ForEach-Object {
                    $text = "Guard $($_.guard_id): bug '$($_.failure_signature)' -> test $($_.test_file) (tipo $($_.guard_type))"
                    $tokens = Get-TextTokens $text
                    $rows += [ordered]@{
                        id = "guard-$($_.guard_id)"
                        source = "evidence"
                        text = $text
                        tokens = $tokens
                        relevance = 0.8
                        validation = 1.0
                        salience = 0.7
                        utility = Get-Utility -Relevance 0.8 -Validation 1.0 -Salience 0.7 -Source "evidence" -Tokens $tokens
                    }
                }
            }
        } catch {}
    }
    return $rows
}

# === Compile ===
$degradation = @()
$sourcesOut = @()
$totalTokens = 0

# memory
$memRows = @()
try { $memRows = Get-MemoryRows -Query $Prompt -Dir $ArnesDir } catch { $degradation += "memory: $($_.Exception.Message)" }
# experience
$expRows = @()
try { $expRows = Get-ExperienceRows -Query $Prompt -Dir $ArnesDir } catch { $degradation += "experience: $($_.Exception.Message)" }
# principles
$priRows = @()
try { $priRows = Get-PrincipleRows -Type $QuestType -Dir $ArnesDir } catch { $degradation += "principles: $($_.Exception.Message)" }
# skills (metadata)
$skRows = @()
try { $skRows = Get-SkillRows } catch { $degradation += "skills: $($_.Exception.Message)" }
# evidence
$evRows = @()
try { $evRows = Get-EvidenceRows -Dir $ArnesDir } catch { $degradation += "evidence: $($_.Exception.Message)" }

$bySource = @{
    memory     = $memRows
    experience = $expRows
    principles = $priRows
    skills     = $skRows
    evidence   = $evRows
}

foreach ($src in $DEFAULT_BUDGETS.Keys) {
    $budget = [int]$budgetMap[$src]
    $rows = @($bySource[$src])
    # ordenar por utility desc
    $sorted = @($rows | Sort-Object -Property @{ Expression = { $_.utility } } -Descending)
    $used = 0
    $selected = @()
    foreach ($r in $sorted) {
        $t = [int]$r.tokens
        if (($used + $t) -gt $budget) { continue }   # respeta el presupuesto de la fuente
        $used += $t
        $selected += $r
    }
    $totalTokens += $used
    # Media manual: Measure-Object no resuelve keys de OrderedDictionary en PS 5.1
    $utilityAvg = 0.0
    if ($selected.Count -gt 0) {
        $uSum = 0.0
        foreach ($r in $selected) { $uSum += [double]$r.utility }
        $utilityAvg = [math]::Round($uSum / $selected.Count, 4)
    }
    $sourcesOut += [ordered]@{
        name        = $src
        budget      = $budget
        tokens_used = $used
        rows        = @($selected)
        utility_avg = $utilityAvg
    }
}

$result = [ordered]@{
    action           = "compile"
    quest_type       = $QuestType
    budgets          = $budgetMap
    tokens_injected  = $totalTokens
    sources          = @($sourcesOut)
    degradation      = @($degradation)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 8
    exit 0
}

if ($Quiet) {
    # solo datos para orquestador (una linea)
    $result | ConvertTo-Json -Depth 8 -Compress
    exit 0
}

# === Salida humana ===
Write-Host ""
Write-Host "  CONTEXT COMPILER - turno compilado" -ForegroundColor Cyan
Write-Host "  =================================" -ForegroundColor Cyan
Write-Host ("  Quest type: {0} | Tokens inyectados: {1}" -f $QuestType, $totalTokens) -ForegroundColor Yellow
Write-Host ""
foreach ($s in $sourcesOut) {
    $color = if ($s.rows.Count -gt 0) { "White" } else { "DarkGray" }
    Write-Host ("  [{0,-10}] {1}/{2} tokens · {3} filas · utilidad {4}" -f $s.name, $s.tokens_used, $s.budget, $s.rows.Count, $s.utility_avg) -ForegroundColor $color
    foreach ($r in $s.rows) {
        $short = $r.text
        if ($short.Length -gt 90) { $short = $short.Substring(0, 87) + "..." }
        Write-Host ("      {0} (u={1}) {2}" -f $r.id, $r.utility, $short) -ForegroundColor DarkGray
    }
}
if ($degradation.Count -gt 0) {
    Write-Host "  Degradacion parcial (fuentes que fallaron, compile continuo):" -ForegroundColor Yellow
    foreach ($d in $degradation) { Write-Host "    - $d" -ForegroundColor DarkGray }
}
Write-Host ""
