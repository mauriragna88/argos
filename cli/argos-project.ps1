#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS PROJECT - Perfil del proyecto: guarda ruta, git, stack, stats y memoria

.DESCRIPTION
Cada vez que trabajas en una carpeta, ARNES guarda .arnes/project.json con:
- nombre, ruta, fechas (creado/actualizado/ultimo acceso)
- git: branch, remote, ultimo commit
- stack detectado (node, nextjs, docker...)
- stats: archivos, quests, observaciones de memoria
Se actualiza automaticamente al abrir argos (init/menu) y se muestra en status.

.EXAMPLE
.\argos-project.ps1 -Update   # guarda/actualiza el perfil
.\argos-project.ps1 -Show     # muestra el perfil
#>
[CmdletBinding()]
param(
    [switch]$Update,
    [switch]$Show
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'osma-resolve.ps1')
$ProjectDir = (Get-Location).Path
$ArnesDir = Join-Path $ProjectDir '.arnes'
$ProfilePath = Join-Path $ArnesDir 'project.json'
$ConfigPath = Join-Path $ArnesDir 'config.json'

if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }

$profile = $null
if (Test-Path $ProfilePath) {
    try { $profile = Get-Content $ProfilePath -Raw | ConvertFrom-Json } catch {}
}

if ($Update) {
    $name = Split-Path $ProjectDir -Leaf
    $created = if ($profile -and $profile.created_at) { $profile.created_at } else { (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') }

    # git
    $branch = ''; $remote = ''; $commit = ''
    try { $branch = (git branch --show-current 2>$null) } catch {}
    try { $remote = (git remote get-url origin 2>$null) } catch {}
    try { $commit = (git log -1 --format=%h 2>$null) } catch {}

    # stack detectado
    $stack = @()
    if (Test-Path (Join-Path $ProjectDir 'package.json')) { $stack += 'node' }
    if (Test-Path (Join-Path $ProjectDir 'next.config.js')) { $stack += 'nextjs' }
    if (Test-Path (Join-Path $ProjectDir 'next.config.mjs')) { $stack += 'nextjs' }
    if (Test-Path (Join-Path $ProjectDir 'Dockerfile')) { $stack += 'docker' }
    if (Test-Path (Join-Path $ProjectDir 'docker-compose.yml')) { $stack += 'docker' }
    if (Test-Path (Join-Path $ProjectDir 'requirements.txt')) { $stack += 'python' }
    if (Test-Path (Join-Path $ProjectDir 'go.mod')) { $stack += 'go' }
    if ($stack.Count -eq 0) { $stack += 'generico' }

    # stats - conteo de archivos ACOTADO (un -Recurse sobre el HOME recorre AppData/.config
    # y tarda minutos o cuelga; aqui solo se recorre si la carpeta es un proyecto real):
    $fileCount = 0
    try {
        $hasGit = Test-Path (Join-Path $ProjectDir '.git')
        $hasStack = (Test-Path (Join-Path $ProjectDir 'package.json')) -or
                    (Test-Path (Join-Path $ProjectDir 'next.config.js')) -or
                    (Test-Path (Join-Path $ProjectDir 'next.config.mjs')) -or
                    (Test-Path (Join-Path $ProjectDir 'Dockerfile')) -or
                    (Test-Path (Join-Path $ProjectDir 'go.mod')) -or
                    (Test-Path (Join-Path $ProjectDir 'requirements.txt'))
        if ($hasGit) {
            # Repo git: contar archivos trackeados (instantaneo, no toca node_modules)
            $fileCount = @(git ls-files 2>$null | Measure-Object).Count
        } elseif ($hasStack) {
            # Proyecto sin git: recursivo pero excluyendo carpetas pesadas
            $fileCount = (Get-ChildItem $ProjectDir -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '\\node_modules\\|\\.git\\|\\.venv\\|\\dist\\|\\build\\|\\.next\\|\\.nuxt\\|\\.turbo\\|\\coverage\\|\\__pycache__\\' } | Measure-Object).Count
        } else {
            # Carpeta no-proyecto (HOME, Desktop, etc.): solo nivel superior, instantaneo
            $fileCount = @(Get-ChildItem $ProjectDir -File -ErrorAction SilentlyContinue | Measure-Object).Count
        }
    } catch {}
    $questCount = @(Get-ChildItem (Join-Path $ArnesDir 'quests\*.md') -ErrorAction SilentlyContinue | Measure-Object).Count
    $memObs = 0
    try {
        $statsOut = @(& ((Get-OsmaMemoryCli)) stats -Quiet 2>$null) -join ''
        if ($statsOut) { $memObs = [int]($statsOut | ConvertFrom-Json).observations }
    } catch {}

    $profile = [ordered]@{
        name           = $name
        path           = $ProjectDir
        created_at     = $created
        updated_at     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        last_opened_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        git            = @{ branch = $branch; remote = $remote; last_commit = $commit }
        stack          = @($stack)
        stats          = @{ files = $fileCount; quests = $questCount; memory_observations = $memObs }
    }
    $profile | ConvertTo-Json -Depth 5 | Set-Content -Path $ProfilePath -Encoding UTF8

    # config.json del proyecto (minimo, si no existe)
    if (-not (Test-Path $ConfigPath)) {
        @{ project = $name; created_at = $created; engine = 'ARNES ARGOS' } | ConvertTo-Json | Set-Content $ConfigPath -Encoding UTF8
    }
}

if ($Show -or $Update) {
    $p = if ($Update) { $profile } else { $profile }
    if (-not $p) { Write-Host '  [!] Sin perfil de proyecto. Corre: argos-project.ps1 -Update' -ForegroundColor Yellow; exit 0 }
    Write-Host ''
    Write-Host '  ARNES ARGOS - PERFIL DEL PROYECTO' -ForegroundColor Cyan
    Write-Host '  =================================' -ForegroundColor Cyan
    Write-Host ("  {0,-16} {1}" -f 'Proyecto:', $p.name) -ForegroundColor White
    Write-Host ("  {0,-16} {1}" -f 'Ruta:', $p.path) -ForegroundColor DarkGray
    Write-Host ("  {0,-16} {1}" -f 'Stack:', ($p.stack -join ', ')) -ForegroundColor White
    Write-Host ("  {0,-16} {1}" -f 'Git:', $(if ($p.git.branch) { $p.git.branch + ' | ' + $p.git.last_commit } else { 'sin git' })) -ForegroundColor White
    if ($p.git.remote) { Write-Host ("  {0,-16} {1}" -f 'Remote:', $p.git.remote) -ForegroundColor DarkGray }
    Write-Host ("  {0,-16} {1}" -f 'Archivos:', $p.stats.files) -ForegroundColor White
    Write-Host ("  {0,-16} {1}" -f 'Quests:', $p.stats.quests) -ForegroundColor White
    Write-Host ("  {0,-16} {1}" -f 'Memoria:', ($p.stats.memory_observations.ToString() + ' observaciones')) -ForegroundColor White
    Write-Host ("  {0,-16} {1}" -f 'Creado:', $p.created_at) -ForegroundColor DarkGray
    Write-Host ("  {0,-16} {1}" -f 'Ultimo acceso:', $p.last_opened_at) -ForegroundColor DarkGray
    Write-Host ''
}
