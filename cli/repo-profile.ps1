# repo-profile.ps1 - Repo Sizer heuristica para Bran
# =============================================
# Cuenta archivos de codigo, LOC, modulos y clasifica el repo en:
#   lean / medium / standard / boss
# Escribe .arnes/repo-profile.json (idempotente si se fuerza --force).
#
# Uso:
#   .\repo-profile.ps1                         # lee cwd y escribe .arnes/repo-profile.json
#   .\repo-profile.ps1 -Force                  # recalcular aunque ya exista
#   .\repo-profile.ps1 -ProjectPath C:\mi\repo # apuntar a otro path
#   .\repo-profile.ps1 -OutputJson             # stdout solo el JSON

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).Path,
    [string]$ArnesDir   = (Join-Path (Get-Location).Path ".arnes"),
    [switch]$Force,
    [switch]$OutputJson,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"

$ProfileFile = Join-Path $ArnesDir "repo-profile.json"

# Si ya existe y no es forzado, salir temprano (idempotente)
if ((Test-Path $ProfileFile) -and -not $Force -and -not $OutputJson) {
    if (-not $Silent) { Write-Host "  [skip] repo-profile.json ya existe. Use -Force para recalcular." -ForegroundColor DarkGray }
    return
}

# === Extensiones de codigo reconocidas ===
$codeExts = @(
    '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs',
    '.py', '.go', '.rs', '.java', '.cs', '.rb', '.php',
    '.vue', '.svelte', '.css', '.scss', '.sass',
    '.swift', '.kt', '.cpp', '.c', '.h', '.hpp'
)

# === Directorios excluidos ===
# Todo lo que no es superficie logica del proyecto
$excludeDirPatterns = @(
    'node_modules', '.git', '.next', 'dist', 'build', '.cache',
    '.turbo', '.vercel', '__pycache__', '.venv', 'venv', 'env',
    'target', '.gradle', '.idea', '.vscode', 'bin', 'obj',
    '.pytest_cache', '.mypy_cache', '.ruff_cache', 'coverage',
    '.nyc_output', '.nuxt', '.svelte-kit', '.output', '.astro'
)

# === Patrones de test excluidos del conteo de codigo ===
# Los tests son signal de madurez pero no de tamano logico
$testFilePattern = '(^|[\\\/])(test|tests|spec|specs|__tests__)([\\\/]|$)|\.(test|spec)\.(ts|tsx|js|jsx|py|go|rs)$'

# === Thresholds (configurables en config.json -> repo_root.thresholds) ===
$thresholds = @{
    files   = @{ lean = 50;   medium = 300;  standard = 1000 }
    loc     = @{ lean = 5000; medium = 30000; standard = 100000 }
    modules = @{ lean = 3;    medium = 9;    standard = 15  }
}

# Permitir override desde config.json
$configFile = Join-Path $ArnesDir "config.json"
if (Test-Path $configFile) {
    try {
        $cfg = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
        if ($cfg.repo_root -and $cfg.repo_root.PSObject.Properties.Name -contains 'thresholds') {
            foreach ($k in @('files','loc','modules')) {
                $t = $cfg.repo_root.thresholds.$k
                if ($t -and $t.PSObject.Properties.Name -contains 'lean') {
                    $thresholds[$k] = @{ lean=[int]$t.lean; medium=[int]$t.medium; standard=[int]$t.standard }
                }
            }
        }
    } catch { /* ignore, use defaults */ }
}

function Test-Excluded([string]$fullPath, [string]$relPath) {
    foreach ($d in $excludeDirPatterns) {
        if ($relPath -match "(^|[\\\/])$d([\\\/]|$)") { return $true }
    }
    return $false
}

function Test-IsTestFile([string]$fileName) {
    return ($fileName -match $testFilePattern)
}

# === Caminar el arbol ===
$codeFiles     = @()
$testFiles     = @()
$seenModules   = @{}
$seenLangs     = @{}
$seenFrameworks = @{}

if (-not $Silent) { Write-Host "  [scan] $ProjectPath" -ForegroundColor Cyan }

$allFiles = Get-ChildItem -Path $ProjectPath -Recurse -File -ErrorAction SilentlyContinue
foreach ($f in $allFiles) {
    $rel = $f.FullName.Substring($ProjectPath.Length).TrimStart('\','/').Replace('\','/')
    if (Test-Excluded -fullPath $f.FullName -relPath $rel) { continue }
    if (-not $codeExts.Contains($f.Extension.ToLower())) { continue }
    if (Test-IsTestFile -fileName $rel) { $testFiles += $rel; continue }

    $codeFiles += [PSCustomObject]@{ Path = $rel; Ext = $f.Extension.ToLower(); Length = $f.Length }

    # Detectar modulo (directorios de nivel 1 con codigo)
    $parts = $rel -split '/'
    if ($parts.Length -ge 2) {
        $mod = $parts[0]
        if (-not $seenModules.ContainsKey($mod)) { $seenModules[$mod] = 0 }
        $seenModules[$mod]++
    }

    # Detectar lenguajes
    $lang = switch ($f.Extension.ToLower()) {
        '.ts'  { if ($rel -match '\.tsx?$' -and $rel -match '/') { 'typescript' } else { 'typescript' } }
        '.tsx' { 'typescript' }
        '.js'  { 'javascript' }
        '.jsx' { 'javascript' }
        '.mjs' { 'javascript' }
        '.cjs' { 'javascript' }
        '.py'  { 'python' }
        '.go'  { 'go' }
        '.rs'  { 'rust' }
        '.java'{ 'java' }
        '.cs'  { 'csharp' }
        '.rb'  { 'ruby' }
        '.php' { 'php' }
        '.vue' { 'vue' }
        '.svelte' { 'svelte' }
        '.css' { 'css' }
        '.scss' { 'scss' }
        '.sass' { 'sass' }
        '.swift' { 'swift' }
        '.kt'  { 'kotlin' }
        '.cpp' { 'cpp' }
        '.c'   { 'c' }
        '.h'   { 'c' }
        '.hpp' { 'cpp' }
        default { 'other' }
    }
    if (-not $seenLangs.ContainsKey($lang)) { $seenLangs[$lang] = 0 }
    $seenLangs[$lang]++
}

# === Sumar LOC (lineas no vacias, sin comentarios puros) ===
$locTotal = 0
foreach ($cf in $codeFiles) {
    try {
        $full = Join-Path $ProjectPath ($cf.Path -replace '/', '\')
        $lines = Get-Content -LiteralPath $full -ErrorAction SilentlyContinue
        if ($null -eq $lines) { continue }
        foreach ($ln in $lines) {
            $trim = "$ln".Trim()
            if ($trim.Length -eq 0) { continue }
            # No contar lineas que son puro comentario (heuristica simple)
            if ($trim -match '^\s*(#|//|--|/\*)\s*$') { continue }
            $locTotal++
        }
    } catch { /* skip unreadable */ }
}

$fileCount    = $codeFiles.Count
$moduleCount  = $seenModules.Keys.Count
$testFileCount = $testFiles.Count

# === Detectar frameworks (heuristica rapida por presencia de archivos clave) ===
$indicators = @{
    'next.js'     = @('next.config.js', 'next.config.mjs', 'next.config.ts')
    'react'       = @('package.json')
    'svelte'      = @('svelte.config.js', 'svelte.config.mjs')
    'nuxt'        = @('nuxt.config.ts', 'nuxt.config.js')
    'vue'         = @('vue.config.js')
    'astro'       = @('astro.config.mjs', 'astro.config.js')
    'supabase'    = @('supabase/config', 'supabase.toml')
    'prisma'      = @('prisma/schema.prisma', 'schema.prisma')
    'tailwind'    = @('tailwind.config.js', 'tailwind.config.ts', 'tailwind.config.mjs')
    'vitest'      = @('vitest.config.ts', 'vitest.config.js', 'vitest.config.mjs')
    'jest'        = @('jest.config.js', 'jest.config.ts')
    'playwright'  = @('playwright.config.ts', 'playwright.config.js')
    'docker'      = @('Dockerfile', 'docker-compose.yml', 'docker-compose.yaml')
    'github-ci'   = @('.github/workflows')
    'go-mod'      = @('go.mod')
    'cargo'       = @('Cargo.toml')
    'requirements'= @('requirements.txt', 'pyproject.toml')
    'gem'         = @('Gemfile')
    'composer'    = @('composer.json')
}
foreach ($fw in $indicators.Keys) {
    foreach ($ind in $indicators[$fw]) {
        $check = Join-Path $ProjectPath ($ind -replace '/', '\')
        if (Test-Path $check) { $seenFrameworks[$fw] = $true; break }
    }
}

# === Classificar por max tier de 3 signals ===
function Get-Tier($value, $thr) {
    if ($value -lt $thr.lean)    { return 'lean' }
    if ($value -lt $thr.medium)  { return 'medium' }
    if ($value -lt $thr.standard){ return 'standard' }
    return 'boss'
}

$tierFiles   = Get-Tier $fileCount   $thresholds.files
$tierLoc     = Get-Tier $locTotal    $thresholds.loc
$tierModules = Get-Tier $moduleCount $thresholds.modules

# Max tier wins
$tierRank = @{ lean = 0; medium = 1; standard = 2; boss = 3 }
$finalTier = 'lean'
foreach ($t in @($tierFiles, $tierLoc, $tierModules)) {
    if ($tierRank[$t] -gt $tierRank[$finalTier]) { $finalTier = $t }
}

# === Party size default por tier ===
$partySizeByTier = @{ lean = 2; medium = 3; standard = 5; boss = 6 }
$defaultPartySize = $partySizeByTier[$finalTier]

# === Model tier por repo tier ===
$modelTierByTier = @{ lean = 'free'; medium = 'balance'; standard = 'pro'; boss = 'highest' }
$defaultModelTier = $modelTierByTier[$finalTier]

# === Honor override de config.json ===
$overrideTier = $null
$overridePartySize = $null
$overrideModelTier = $null
if (Test-Path $configFile) {
    try {
        $cfg = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
        if ($cfg.repo_root) {
            if ($cfg.repo_root.PSObject.Properties.Name -contains 'override_tier' -and $cfg.repo_root.override_tier) {
                $overrideTier = $cfg.repo_root.override_tier
                $finalTier = $overrideTier
            }
            if ($cfg.repo_root.PSObject.Properties.Name -contains 'override_party_size' -and $cfg.repo_root.override_party_size) {
                $overridePartySize = [int]$cfg.repo_root.override_party_size
                $defaultPartySize = $overridePartySize
            }
            if ($cfg.repo_root.PSObject.Properties.Name -contains 'override_model_tier' -and $cfg.repo_root.override_model_tier) {
                $overrideModelTier = $cfg.repo_root.override_model_tier
                $defaultModelTier = $overrideModelTier
            }
        }
    } catch { /* ignore */ }
}

# === Growth hint simple ===
$growthHint = $null
if ($testFileCount -eq 0 -and $fileCount -gt 10) {
    $growthHint = "Sin archivos de test detectados. Considera agregar tests (Vitest/Playwright) para mejorar cobertura."
} elseif ($seenLangs.ContainsKey('typescript') -and -not $seenFrameworks.ContainsKey('vitest') -and $fileCount -gt 30) {
    $growthHint = "TypeScript detectado sin Vitest. Rogue esta under-used; buena oportunidad para Backstab."
} elseif ($seenFrameworks.ContainsKey('supabase') -and -not $seenFrameworks.ContainsKey('prisma')) {
    $growthHint = "Supabase detectado pero Prisma no. Paladin podria usar Holy-ground para tipar el schema."
} elseif ($fileCount -gt 200 -and -not $seenFrameworks.ContainsKey('docker')) {
    $growthHint = "Repo >200 archivos sin Docker. Eiko podria preparar containers para reproducibilidad."
}

# === Construir objeto de perfil ===
$profile = [ordered]@{
    repo_tier            = $finalTier
    file_count_code      = $fileCount
    file_count_tests     = $testFileCount
    loc_total            = $locTotal
    module_count         = $moduleCount
    modules              = @($seenModules.Keys | Sort-Object)
    languages            = @($seenLangs.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object { $_.Key })
    frameworks_detected  = @($seenFrameworks.Keys | Sort-Object)
    has_tests            = ($testFileCount -gt 0)
    has_ci               = $seenFrameworks.ContainsKey('github-ci')
    has_docker           = $seenFrameworks.ContainsKey('docker')
    recommended_party_size = $defaultPartySize
    recommended_model_tier = $defaultModelTier
    override_applied     = $overrideTier
    override_party_size  = $overridePartySize
    override_model_tier  = $overrideModelTier
    growth_hint          = $growthHint
    tier_by_signal       = [ordered]@{
        files   = $tierFiles
        loc     = $tierLoc
        modules = $tierModules
    }
    thresholds_used      = $thresholds
    evaluated_at         = (Get-Date -Format "o")
    next_eval_after_quest = 0  # se llenara abajo si hay ledger
}

# Si hay quest-ledger, fijar proxima re-eval a +20 quests
$ledgerFile = Join-Path $ArnesDir "quest-ledger.json"
if (Test-Path $ledgerFile) {
    try {
        $ledger = Get-Content -LiteralPath $ledgerFile -Raw | ConvertFrom-Json
        $currentQ = [int]$ledger.stats.total_quests
        $profile.next_eval_after_quest = $currentQ + 20
    } catch { /* ignore */ }
}

# === Output ===
$json = $profile | ConvertTo-Json -Depth 6

if ($OutputJson) {
    $json
    return
}

if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }
$json | Set-Content -LiteralPath $ProfileFile -Encoding UTF8

if (-not $Silent) {
    Write-Host "  [OK] repo-profile.json escrito a $ProfileFile" -ForegroundColor Green
    Write-Host ""
    Write-Host "  REPORTE REPO SIZER" -ForegroundColor Cyan
    Write-Host "  Tier:             $finalTier" -ForegroundColor White
    Write-Host "  Files de codigo:  $fileCount" -ForegroundColor DarkGray
    Write-Host "  Test files:       $testFileCount" -ForegroundColor DarkGray
    Write-Host "  LOC total:         $locTotal" -ForegroundColor DarkGray
    Write-Host "  Modulos:          $moduleCount ($($profile.modules -join ', '))" -ForegroundColor DarkGray
    Write-Host "  Lenguajes:        $($profile.languages -join ', ')" -ForegroundColor DarkGray
    Write-Host "  Frameworks:       $($profile.frameworks_detected -join ', ')" -ForegroundColor DarkGray
    Write-Host "  Tier por signal:  files=$tierFiles loc=$tierLoc modules=$tierModules" -ForegroundColor DarkGray
    Write-Host "  Party recommend:  $defaultPartySize miembros" -ForegroundColor White
    Write-Host "  Model recommend:  $defaultModelTier tier" -ForegroundColor White
    if ($overrideTier) {
        Write-Host "  Override aplicado: $overrideTier (CLI flag)" -ForegroundColor Yellow
    }
    if ($growthHint) {
        Write-Host ""
        Write-Host "  Growth hint: $growthHint" -ForegroundColor Yellow
    }
}
