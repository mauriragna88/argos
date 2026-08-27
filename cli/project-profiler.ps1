#Requires -Version 5.1
<#
.SYNOPSIS
PROJECT PROFILER - Clasifica el proyecto por TIPO DE APP y ofrece VARIANTES de solucion.
Corre en el auto-init (cada vez que abres cualquier proyecto, nuevo o viejo).

.DESCRIPTION
Detecta el tipo de app (landing/fullstack/api/spa/desktop/mobile/cli) y ofrece
VARIANTES de plataforma (web / desktop / movil / offline-first) para quests nuevos:
NO siempre la web es la mejor respuesta. Bard (mejora continua) y Ragnarok (CEO/procurement)
recomiendan segun tipo. Guarda .arnes/project-type.json (idempotente con -Force).

Uso:
  .\cli\project-profiler.ps1                     # clasifica y escribe project-type.json
  .\cli\project-profiler.ps1 -Force -Silent      # recalcular sin output
  .\cli\project-profiler.ps1 -Json               # solo JSON a stdout
#>
[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).Path,
    [string]$ArnesDir = (Join-Path (Get-Location).Path ".arnes"),
    [switch]$Force,
    [switch]$Json,
    [switch]$Silent
)

$ErrorActionPreference = 'Continue'
$TypeFile = Join-Path $ArnesDir 'project-type.json'

# Si ya existe y no es forzado, salir temprano (idempotente)
if ((Test-Path $TypeFile) -and -not $Force -and -not $Json) {
    if (-not $Silent) { Write-Host "  [skip] project-type.json ya existe. Use -Force para recalcular." -ForegroundColor DarkGray }
    return
}

# === 1. Leer package.json (si existe) ===
$pkgDeps = @()
$hasPkg = Test-Path (Join-Path $ProjectPath 'package.json')
$pkg = $null
if ($hasPkg) {
    try {
        $pkg = Get-Content (Join-Path $ProjectPath 'package.json') -Raw | ConvertFrom-Json
        $all = @()
        if ($pkg.dependencies) { $all += @($pkg.dependencies.PSObject.Properties.Name) }
        if ($pkg.devDependencies) { $all += @($pkg.devDependencies.PSObject.Properties.Name) }
        $pkgDeps = @($all | Select-Object -Unique)
    } catch {}
}
function Test-Dep([string]$name) { return ($pkgDeps -contains $name) }

# === 2. Detectar senales ===
$hasDb = $false
$dbEngine = $null

# DB: archivos de config
$dbFileSignals = @(
    @{ engine = 'supabase'; paths = @('supabase/config.toml', 'supabase') },
    @{ engine = 'prisma';   paths = @('prisma/schema.prisma', 'schema.prisma') },
    @{ engine = 'drizzle';  paths = @('drizzle.config.ts', 'drizzle.config.js') }
)
foreach ($e in $dbFileSignals) {
    foreach ($p in $e.paths) {
        if (Test-Path (Join-Path $ProjectPath $p)) { $hasDb = $true; $dbEngine = $e.engine; break }
    }
    if ($hasDb) { break }
}
# DB: dependencias
if (-not $hasDb) {
    foreach ($dep in @('@supabase/supabase-js','prisma','@prisma/client','drizzle-orm','mongoose','pg','mysql2','better-sqlite3','sqlite3','typeorm','sequelize','firebase','mongodb')) {
        if (Test-Dep $dep) { $hasDb = $true; $dbEngine = ($dep -replace '^@','' -replace '/.*',''); break }
    }
}

$hasBackend = $false
foreach ($d in @('api','server','backend','routes')) {
    if (Test-Path (Join-Path $ProjectPath $d)) { $hasBackend = $true; break }
}
if (-not $hasBackend) {
    foreach ($dep in @('express','fastify','hono','@nestjs/core','@trpc/server')) {
        if (Test-Dep $dep) { $hasBackend = $true; break }
    }
}
# next/nuxt con DB = fullstack; sin DB pueden ser solo frontend
$isMetaFramework = (Test-Dep 'next') -or (Test-Dep 'nuxt') -or (Test-Dep '@remix-run/dev')

$hasFrontend = $false
foreach ($dep in @('react','vue','svelte','solid-js','preact','next','nuxt','astro','@angular/core','lit')) {
    if (Test-Dep $dep) { $hasFrontend = $true; break }
}

$hasAuth = $false
foreach ($dep in @('next-auth','@auth/core','clerk','@clerk/nextjs','passport','jose','firebase')) {
    if (Test-Dep $dep) { $hasAuth = $true; break }
}

# Desktop / Mobile / CLI
$isElectron = Test-Dep 'electron'
$isTauri = (Test-Path (Join-Path $ProjectPath 'src-tauri')) -or (Test-Dep '@tauri-apps/cli')
$isCapacitor = Test-Dep '@capacitor/core'
$isReactNative = (Test-Dep 'react-native') -or (Test-Dep 'expo')
$isFlutter = Test-Path (Join-Path $ProjectPath 'pubspec.yaml')
$isCli = $false
if ($hasPkg) {
    foreach ($dep in @('commander','yargs','cac','clipanion','oclif')) {
        if (Test-Dep $dep) { $isCli = $true; break }
    }
}

# Static site (landing candidates)
$isAstro = Test-Dep 'astro'
$isHtmlOnly = $false
if (-not $hasPkg) {
    $rootFiles = @(Get-ChildItem -Path $ProjectPath -File -ErrorAction SilentlyContinue)
    $htmlCount = @($rootFiles | Where-Object { $_.Extension -eq '.html' }).Count
    $codeExts = @('.ts','.tsx','.js','.jsx','.py','.go','.rs','.vue','.svelte')
    # FIX: Measure-Object devuelve Sum=$null sin datos -> contar con loop explicito
    $subDirs = @(Get-ChildItem -Path $ProjectPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('node_modules','.git','dist','build') })
    $subCode = 0
    foreach ($sd in $subDirs) {
        $subCode += @(Get-ChildItem -Path $sd.FullName -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $codeExts -contains $_.Extension.ToLower() }).Count
    }
    if ($htmlCount -gt 0 -and $subCode -eq 0) { $isHtmlOnly = $true }
}

# === 3. Clasificar TIPO DE APP ===
$appType = 'unknown'
$confidence = 0
if ($isReactNative -or $isFlutter -or $isCapacitor) {
    $appType = 'mobile'; $confidence = 90
} elseif ($isElectron -or $isTauri) {
    $appType = 'desktop'; $confidence = 90
} elseif ($isCli) {
    $appType = 'cli-tool'; $confidence = 85
} elseif ($hasDb -and $hasFrontend) {
    $appType = 'fullstack'; $confidence = 95
} elseif ($hasDb -and -not $hasFrontend) {
    $appType = 'api-only'; $confidence = 90
} elseif ($hasFrontend -and -not $hasDb) {
    $appType = 'spa-frontend'; $confidence = 80
    if ($isAstro -or $isHtmlOnly -or (-not $hasBackend -and -not $isMetaFramework)) { $appType = 'landing'; $confidence = 75 }
} elseif ($isHtmlOnly) {
    $appType = 'landing'; $confidence = 70
}

# === 4. VARIANTES DE SOLUCION (Bard/Ragnarok: NO siempre la web es la mejor) ===
$variants = @()
if ($appType -in @('unknown','landing','spa-frontend')) {
    $variants += @{ platform = 'web-estatica';  tool = 'HTML/CSS/JS o Astro'; pros = 'rapido, gratis, SEO facil'; cons = 'sin datos dinamicos' }
    $variants += @{ platform = 'web-fullstack'; tool = 'Next.js + Supabase'; pros = 'datos, auth, crece sin reescribir'; cons = 'mas complejo de mantener' }
    $variants += @{ platform = 'desktop';       tool = 'Tauri (binario ~10MB) o Electron'; pros = 'offline, acceso a hardware'; cons = 'mantenimiento doble plataforma' }
    $variants += @{ platform = 'movil';         tool = 'Capacitor o Expo (React Native)'; pros = 'usuarios moviles, push'; cons = 'stores y revisiones' }
    $variants += @{ platform = 'offline-pwa';   tool = 'PWA + IndexedDB (Dexie)'; pros = 'offline, instalable, un codebase'; cons = 'storage limitado' }
}
if ($appType -eq 'fullstack') {
    $variants += @{ platform = 'movil-companion'; tool = 'Capacitor sobre el mismo codebase'; pros = 'mismo codigo a movil'; cons = 'UI adaptada necesaria' }
    $variants += @{ platform = 'desktop-companion'; tool = 'Tauri wrapper del frontend'; pros = 'app desktop rapida'; cons = 'build extra en CI' }
    $variants += @{ platform = 'pwa-offline'; tool = 'Service worker + cache'; pros = 'offline parcial barato'; cons = 'no sustituye backend' }
}

# === 5. Recomendaciones por tipo (Ragnarok = CEO/procurement, Bard = mejora continua) ===
$recommendations = @()
switch ($appType) {
    'landing' {
        $recommendations += 'CEO (Ragnarok): Landing informativa SIN base de datos. Para diseno visual premium abre Open Design o Claude Design y confirma si quieres trabajar aqui.'
        $recommendations += 'PARTY LIGERO: Vivi sola (+Eiko opcional). No necesitas Ansem ni RLS.'
        $recommendations += 'Si luego necesitas formularios con datos: evalua PWA + servicio externo (Formspree) ANTES de montar fullstack.'
    }
    'fullstack' {
        $recommendations += 'CEO: App fullstack con BD. Party completo: Ansem (backend/RLS) + Vivi (frontend) + Eiko (devops) + Auron automatico en auth/deploy.'
        $recommendations += 'Bard: revisa que el schema tenga migraciones versionadas antes de crecer features.'
    }
    'api-only' {
        $recommendations += 'CEO: API pura. Ansem lidera. Documentacion OpenAPI desde el dia 1.'
    }
    'mobile' {
        $recommendations += 'CEO: App movil. Vivi adapta componentes touch-first; Eiko maneja builds/stores.'
    }
    'desktop' {
        $recommendations += 'CEO: App desktop. Tauri preferido sobre Electron (binario ~10MB vs ~150MB).'
    }
    'cli-tool' {
        $recommendations += 'CEO: CLI. Party minimo: Ansem o Amarant para arquitectura limpia.'
    }
    'spa-frontend' {
        $recommendations += 'CEO: SPA sin backend propio. Si necesitaras datos, evalua Supabase antes de construir tu propia API.'
    }
    default {
        $recommendations += 'Tipo no determinado. Atlas usara Triage V2 (clarify questions) para completar el perfil.'
    }
}

# === 6. Guardar resultado ===
$result = [ordered]@{
    project_type = $appType
    confidence = $confidence
    db_engine = $dbEngine
    signals = [ordered]@{
        has_db = $hasDb
        has_backend = $hasBackend
        has_frontend = $hasFrontend
        has_auth = $hasAuth
        is_meta_framework = $isMetaFramework
        is_electron = $isElectron
        is_tauri = $isTauri
        is_react_native = $isReactNative
        is_flutter = $isFlutter
        is_capacitor = $isCapacitor
        is_astro = $isAstro
        is_html_only = $isHtmlOnly
        is_cli = $isCli
    }
    variants = $variants
    recommendations = $recommendations
    profiled_at = (Get-Date -Format 'o')
}

if ($Json) { $result | ConvertTo-Json -Depth 6; return }

if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $TypeFile -Encoding UTF8

if (-not $Silent) {
    Write-Host ''
    Write-Host '  PROJECT PROFILER' -ForegroundColor Cyan
    Write-Host '  ================' -ForegroundColor Cyan
    Write-Host ("  Tipo de app:   {0} (confianza {1}%)" -f $appType.ToUpper(), $confidence) -ForegroundColor Yellow
    if ($dbEngine) { Write-Host ("  Base de datos: {0}" -f $dbEngine) -ForegroundColor White }
    Write-Host ("  Frontend: {0} | Backend: {1} | Auth: {2}" -f $(if ($hasFrontend) {'SI'} else {'no'}), $(if ($hasBackend) {'SI'} else {'no'}), $(if ($hasAuth) {'SI'} else {'no'})) -ForegroundColor DarkGray
    Write-Host ''
    foreach ($r in $recommendations) { Write-Host ("  {0}" -f $r) -ForegroundColor White }
    if ($variants.Count -gt 0) {
        Write-Host ''
        Write-Host '  VARIANTES DE SOLUCION (Bard/Ragnarok: NO siempre la web es la mejor):' -ForegroundColor Magenta
        foreach ($v in $variants) {
            Write-Host ("    [{0}] {1}" -f $v.platform, $v.tool) -ForegroundColor Yellow
            Write-Host ("       pro: {0}" -f $v.pros) -ForegroundColor DarkGray
            Write-Host ("       contra: {0}" -f $v.cons) -ForegroundColor DarkGray
        }
    }
    Write-Host ''
}
