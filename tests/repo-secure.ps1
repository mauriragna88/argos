#Requires -Version 5.1
<#
.SYNOPSIS
REPO SECURE - instala el blindaje anti-secretos en un repo git.

.DESCRIPTION
Para cada repo (default: el repo de argos; o los que se pasen con -RepoPath):
  1. Instala deploy/hooks/pre-commit en .git/hooks/pre-commit (ejecutable).
     El hook bloquea commits con secretos reales (JWT, sb_secret_, ghp_,
     conekta, mercadopago...) y rutas sensibles (.env, settings.local.json,
     .commandcode/, auth.json, *.db).
  2. Endurece .gitignore: agrega las entradas que falten
     (.commandcode/, .claude/settings.local.json, .env*, *.db local...).

Uso:
  powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-secure.ps1
  powershell ... -File tests/repo-secure.ps1 -RepoPath "C:\path\repo1","C:\path\repo2"
#>
param(
    [string[]]$RepoPath = @((Resolve-Path (Join-Path $PSScriptRoot '..')).Path),
    [switch]$NoGitignore
)

$ErrorActionPreference = 'Stop'
$argosRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$hookSource = Join-Path $argosRoot 'deploy\hooks\pre-commit'

if (-not (Test-Path $hookSource)) {
    Write-Host "  [FAIL] No existe el hook fuente: $hookSource" -ForegroundColor Red
    exit 1
}

# Entradas de .gitignore para el blindaje
$gitignoreEntries = @(
    '# --- repo-secure: credenciales y config local ---',
    '.commandcode/',
    '.claude/settings.local.json',
    '.arnes/',
    '.env',
    '.env.local',
    '.env.*.local',
    '.env.production'
)

$results = @()
foreach ($repo in $RepoPath) {
    if (-not (Test-Path (Join-Path $repo '.git'))) {
        Write-Host ("  [SKIP] {0} - no es repo git" -f $repo) -ForegroundColor Yellow
        $results += [pscustomobject]@{ Repo = $repo; Hook = 'skip'; Gitignore = 'skip' }
        continue
    }

    # === 1. Instalar hook ===
    $hooksDir = Join-Path $repo '.git\hooks'
    if (-not (Test-Path $hooksDir)) { New-Item -ItemType Directory -Path $hooksDir | Out-Null }
    $hookTarget = Join-Path $hooksDir 'pre-commit'

    # Backup si ya existia un hook distinto
    if ((Test-Path $hookTarget) -and ((Get-FileHash $hookTarget).Hash -ne (Get-FileHash $hookSource).Hash)) {
        Copy-Item $hookTarget "$hookTarget.bak" -Force
        Write-Host ("  [{0}] hook previo respaldado como pre-commit.bak" -f $repo) -ForegroundColor Yellow
    }
    Copy-Item $hookSource $hookTarget -Force

    # Ejecutable en git-bash / sh
    try {
        & git -C $repo update-index --chmod=+x .git/hooks/pre-commit 2>$null
    } catch { }

    # chmod real si hay chmod disponible (git bash/msys)
    if (Get-Command chmod -ErrorAction SilentlyContinue) {
        & chmod +x $hookTarget 2>$null
    }

    # === 2. Endurecer .gitignore ===
    $giStatus = 'ok'
    if (-not $NoGitignore) {
        $giPath = Join-Path $repo '.gitignore'
        $existing = @()
        if (Test-Path $giPath) { $existing = @(Get-Content $giPath) }
        $missing = $gitignoreEntries | Where-Object { $_ -notmatch '^#' -and -not ($existing -contains $_) }
        if ($missing.Count -gt 0) {
            Add-Content -Path $giPath -Value ''
            Add-Content -Path $giPath -Value ($missing -join "`r`n")
            $giStatus = "agregadas $($missing.Count)"
        } else {
            $giStatus = 'ya cubierto'
        }
    } else {
        $giStatus = 'omitido'
    }

    Write-Host ("  [OK] {0} - hook instalado, .gitignore: {1}" -f $repo, $giStatus) -ForegroundColor Green
    $results += [pscustomobject]@{ Repo = $repo; Hook = 'instalado'; Gitignore = $giStatus }
}

Write-Host ''
Write-Host ('  RESUMEN: {0} repo(s) procesados.' -f $results.Count) -ForegroundColor Cyan
exit 0
