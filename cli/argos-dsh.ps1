#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS FOR DSH - Instala el plugin ARGOS/OSMA en DeepSeek Harness

.DESCRIPTION
Carga ARGOS junto al harness de DeepSeek: instala el bundle dsh/argos-osma
en el perfil web de DSH (~/.dsh/profiles/web). El plugin registra tools
argos_* (status/save/recall/experience/cue/episode/scan) y un hook de
aprendizaje que escribe cada turno en el MISMO .arnes/arnes.db del proyecto
(memoria compartida con opencode, pi, claude, codex y dsh).

.EXAMPLE
.\argos-dsh.ps1                      # instala el plugin en el perfil web
.\argos-dsh.ps1 -Profile cli         # instala en otro perfil
.\argos-dsh.ps1 -Status              # ver si ya esta instalado
.\argos-dsh.ps1 -Remove              # desinstala
#>
[CmdletBinding()]
param(
    [string]$Profile = 'web',
    [switch]$Status,
    [switch]$Remove,
    [string]$DshRoot = ''   # ruta del checkout de deepseek-harness (si dsh no esta en PATH)
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$PluginDir = Join-Path $Root 'dsh\argos-osma'
$DshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
$ProfileDir = Join-Path $DshHome "profiles\$Profile"
$ManifestPath = Join-Path $ProfileDir 'package.json'
$BundleName = '@arnes/dsh-argos-osma'

# === Resolver el binario dsh ===
function Resolve-DshBin {
    $cmd = Get-Command dsh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # buscar en el checkout: node apps/cli/lib/bin.js (el .cmd no siempre existe)
    $cand = @(
        $DshRoot,
        (Join-Path $env:USERPROFILE 'deepseek-harness'),
        'C:\Users\LapOne Mx\deepseek-harness',
        (Join-Path $env:USERPROFILE 'Documents\GitHub\deepseek-harness')
    ) | Where-Object { $_ -and (Test-Path (Join-Path $_ 'apps\cli\lib\bin.js')) } | Select-Object -First 1
    if ($cand) {
        return @{ node = $true; path = (Join-Path $cand 'apps\cli\lib\bin.js') }
    }
    return $null
}

# === Status ===
if ($Status) {
    Write-Host ''
    Write-Host '  ARGOS/OSMA en DeepSeek Harness - ESTADO' -ForegroundColor Cyan
    if (-not (Test-Path $ManifestPath)) {
        Write-Host "  [!] Perfil '$Profile' no existe en $ProfileDir" -ForegroundColor Yellow
        exit 1
    }
    $m = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $bundles = @($m.dsh.profile.bundles)
    if ($bundles -contains $BundleName) {
        Write-Host "  [OK] $BundleName instalado en perfil '$Profile'." -ForegroundColor Green
        Write-Host "  Bundles: $($bundles -join ', ')" -ForegroundColor DarkGray
    } else {
        Write-Host "  [--] $BundleName NO instalado en perfil '$Profile'." -ForegroundColor Yellow
        Write-Host "  Bundles actuales: $($bundles -join ', ')" -ForegroundColor DarkGray
    }
    exit 0
}

# === Remove ===
if ($Remove) {
    if (-not (Test-Path $ManifestPath)) { Write-Host "  [!] Perfil '$Profile' no existe." -ForegroundColor Yellow; exit 1 }
    $m = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $bundles = @($m.dsh.profile.bundles) | Where-Object { $_ -ne $BundleName }
    $m.dsh.profile.bundles = @($bundles)
    $m | ConvertTo-Json -Depth 10 | Set-Content $ManifestPath -Encoding UTF8
    Write-Host "  [OK] $BundleName removido del perfil '$Profile'." -ForegroundColor Green
    Write-Host '  Reinicia dsh web para aplicar.' -ForegroundColor Yellow
    exit 0
}

# === Precondiciones ===
if (-not (Test-Path $PluginDir)) { Write-Host "[!] No existe el plugin: $PluginDir" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $ProfileDir)) { Write-Host "[!] Perfil '$Profile' no existe: $ProfileDir. Arranca dsh web una vez primero." -ForegroundColor Yellow; exit 1 }

Write-Host ''
Write-Host '  ARGOS/OSMA -> DeepSeek Harness' -ForegroundColor Cyan
Write-Host ("  Plugin:   {0}" -f $PluginDir) -ForegroundColor White
Write-Host ("  Perfil:   {0}" -f $ProfileDir) -ForegroundColor White
Write-Host ''

$dsh = Resolve-DshBin
if (-not $dsh) {
    Write-Host '  [!] No se encontro el binario dsh ni el checkout de deepseek-harness.' -ForegroundColor Red
    Write-Host '      Usa -DshRoot <ruta del checkout> o instala dsh (npx @deepseek-ai/dsh).' -ForegroundColor Yellow
    exit 1
}

# === Instalar: dsh plugin add (reconcilia bundles automaticamente) ===
# NOTA: rutas con espacios ("LapOne Mx") rompen el spawn shell de dsh plugin;
# fallback manual con pnpm + registro del bundle en el manifest.
$installed = $false
$m = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$bundles = @($m.dsh.profile.bundles)

if ($bundles -contains $BundleName) {
    Write-Host ("  [OK] {0} ya esta en bundles del perfil '{1}'." -f $BundleName, $Profile) -ForegroundColor Green
    $installed = $true
} else {
    # intento 1: dsh plugin (rutas sin espacios)
    if (-not $dsh.node -and ($PluginDir -notmatch ' ')) {
        Write-Host "  [>>] dsh plugin --profile $Profile add $PluginDir" -ForegroundColor Cyan
        & $dsh plugin --profile $Profile add $PluginDir
        $installed = ($LASTEXITCODE -eq 0)
    }
    if (-not $installed) {
        # intento 2: pnpm add directo + registro manual del bundle
        Write-Host '  [>>] pnpm add (fallback manual por ruta con espacios)' -ForegroundColor Cyan
        Push-Location $ProfileDir
        try {
            & pnpm add "file:$PluginDir" 2>&1 | Out-Host
            $installed = ($LASTEXITCODE -eq 0)
        } finally { Pop-Location }
        if ($installed) {
            # reconciliar: registrar el bundle si el paquete declara dsh.bundle.patch
            $installedPkg = Join-Path $ProfileDir "node_modules\$BundleName"
            $pkgManifest = Join-Path $installedPkg 'package.json'
            if (Test-Path $pkgManifest) {
                $p = Get-Content $pkgManifest -Raw | ConvertFrom-Json
                if ($p.dsh.bundle.patch) {
                    $b = @($bundles) + $BundleName
                    $m.dsh.profile.bundles = @($b)
                    $m | ConvertTo-Json -Depth 10 | Set-Content $ManifestPath -Encoding UTF8
                } else {
                    $installed = $false
                    Write-Host '  [!] El paquete instalado no declara dsh.bundle.patch' -ForegroundColor Yellow
                }
            }
        }
    }
}

# === Verificar en el manifest ===
if ($installed) {
    $m = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $bundles = @($m.dsh.profile.bundles)
    if ($bundles -contains $BundleName) {
        Write-Host ''
        Write-Host ("  [OK] {0} instalado en perfil '{1}'." -f $BundleName, $Profile) -ForegroundColor Green
        Write-Host '  Bundles: ' + ($bundles -join ', ') -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '  ⚠  Reinicia dsh web (cierra y vuelve a abrir) para activar ARGOS/OSMA.' -ForegroundColor Yellow
        Write-Host '  Cuando esté activo tendrás tools: argos_status, argos_save, argos_recall,' -ForegroundColor White
        Write-Host '  argos_experience_record, argos_experience_search, argos_cue_search,' -ForegroundColor White
        Write-Host '  argos_episode, argos_scan — todas sobre .arnes/arnes.db del proyecto.' -ForegroundColor White
    } else {
        Write-Host "  [!] Se instalo pero no se reconcilio en bundles. Revisa: $ManifestPath" -ForegroundColor Yellow
    }
} else {
    Write-Host '  [!!] Fallo la instalacion. Revisa el error de pnpm arriba.' -ForegroundColor Red
    exit 1
}
