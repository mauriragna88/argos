#!/usr/bin/env pwsh
# install.ps1 - ARNES ARGOS Installer (oficial)
# =============================================
# Uso: pwsh ./install.ps1
# O one-liner: iwr -useb https://raw.githubusercontent.com/mauriragna88/arnes/main/install.ps1 | iex
# Parametros:
#   -RepoUrl https://github.com/mauriragna88/arnes.git   (URL del repo a instalar)
#   -Branch main
# Instala el harness en ~/arnes + wrappers 'argos'/'atlas' globales + sync de agentes.

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RepoUrl = "https://github.com/mauriragna88/arnes.git",
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

if ($RepoUrl -like "*<TU-USUARIO>*") {
    Write-Host ""
    Write-Host "  [X] Falta tu URL de GitHub. Usa:" -ForegroundColor Red
    Write-Host "      pwsh ./install.ps1 -RepoUrl https://github.com/mauriragna88/arnes.git" -ForegroundColor Yellow
    exit 1
}

$INSTALL_DIR = Join-Path $HOME "arnes"

function Step($m) { Write-Host ""; Write-Host "  > $m" -ForegroundColor Cyan }
function OK($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "  [X] $m" -ForegroundColor Red; exit 1 }
function Minor($m) { Write-Host "      $m" -ForegroundColor DarkGray }

Write-Host ""
Write-Host "========================================================" -ForegroundColor Red
Write-Host "  ATLAS HARNESS RPG - Installer" -ForegroundColor Red
Write-Host "  Rojo & Negro, Atlas de la Liga MX" -ForegroundColor Red
Write-Host "========================================================" -ForegroundColor Red
Write-Host ""

Step "Verificando git..."
try {
    $gitVer = (& git --version 2>&1 | Select-Object -First 1) -replace "git version ", ""
    OK "git $gitVer detectado"
} catch {
    Fail "git no esta instalado. Instala git desde https://git-scm.com/download/win"
}

Step "Detectando plataformas de IA..."
$platforms = @()
if (Test-Path "$env:USERPROFILE/.config/opencode") { $platforms += "OpenCode"; OK "OpenCode encontrado" }
else { Minor "OpenCode no detectado" }
if (Get-Command codex -EA SilentlyContinue) { $platforms += "Codex"; OK "Codex CLI encontrado" }
else { Minor "Codex CLI no detectado" }
if ((Test-Path "$env:USERPROFILE/.claude") -or (Get-Command claude -EA SilentlyContinue)) { $platforms += "Claude"; OK "Claude Code encontrado" }
else { Minor "Claude Code no detectado" }

if ($platforms.Count -eq 0) {
    Warn "No se detecto ninguna plataforma de IA."
    Warn "Atlas funcionara en modo Evenatan offline hasta que instales una."
}

Step "Instalando repo arnes en $INSTALL_DIR..."
if (Test-Path $INSTALL_DIR) {
    Warn "Ya existe una instalacion previa. Actualizando..."
    Push-Location $INSTALL_DIR
    try {
        & git pull origin $Branch 2>&1 | Out-Null
        OK "Repo actualizado"
    } catch {
        Warn "No pude hacer pull. Continuando con version actual."
    }
    Pop-Location
} else {
    try {
        & git clone --depth 1 --branch $Branch $RepoUrl $INSTALL_DIR 2>&1 | Out-Null
        OK "Repo clonado en $INSTALL_DIR"
    } catch {
        Fail "No pude clonar el repo. Verifica tu conexion o la URL: $RepoUrl"
    }
}

Step "Creando wrapper 'atlas' en PATH..."

if ($IsWindows -or ($env:OS -match "Windows")) {
    $WRAPPER_DIR = "$env:LOCALAPPDATA/Microsoft/WindowsApps"
    if (-not (Test-Path $WRAPPER_DIR)) {
        New-Item -ItemType Directory -Path $WRAPPER_DIR -Force | Out-Null
    }
    $wrapperPath = Join-Path $WRAPPER_DIR "atlas.cmd"
    $wrapperContent = "@echo off`r`nREM atlas.cmd - Wrapper`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$INSTALL_DIR/cli/atlas.ps1`" %*"
    Set-Content -LiteralPath $wrapperPath -Value $wrapperContent -Encoding ASCII -Force
    OK "Wrapper creado en $wrapperPath"
    $argosWrapper = Join-Path $WRAPPER_DIR "argos.cmd"
    $argosContent = "@echo off`r`nREM argos.cmd - Wrapper ARNES ARGOS`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$INSTALL_DIR/cli/argos.ps1`" %*"
    Set-Content -LiteralPath $argosWrapper -Value $argosContent -Encoding ASCII -Force
    OK "Wrapper 'argos' creado en $argosWrapper"
} else {
    $WRAPPER_DIR = "$HOME/.local/bin"
    if (-not (Test-Path $WRAPPER_DIR)) {
        New-Item -ItemType Directory -Path $WRAPPER_DIR -Force | Out-Null
    }
    $wrapperPath = Join-Path $WRAPPER_DIR "atlas"
    $wrapperContent = "#!/usr/bin/env pwsh`n# atlas wrapper Linux/Mac`npwsh -NoProfile -File '$INSTALL_DIR/cli/atlas.ps1' `$@"
    Set-Content -LiteralPath $wrapperPath -Value $wrapperContent -Encoding ASCII -Force
    try { & chmod +x $wrapperPath 2>$null } catch {}
    OK "Wrapper creado en $wrapperPath"
    $argosWrapper = Join-Path $WRAPPER_DIR "argos"
    $argosContent = "#!/usr/bin/env pwsh`n# argos wrapper Linux/Mac`npwsh -NoProfile -File '$INSTALL_DIR/cli/argos.ps1' `$@"
    Set-Content -LiteralPath $argosWrapper -Value $argosContent -Encoding ASCII -Force
    try { & chmod +x $argosWrapper 2>$null } catch {}
    OK "Wrapper 'argos' creado en $argosWrapper"
}

Step "Sincronizando agentes, skills y setup global..."
Push-Location $INSTALL_DIR
try {
    & "$INSTALL_DIR/cli/atlas.ps1" --sync 2>&1 | Select-Object -First 20 | ForEach-Object { Write-Host "      $_" }
    OK "Sincronizacion inicial completada"
} catch {
    Warn "Sincronizacion inicial fallo. Puedes correr 'argos' despues para reintentar."
}
try {
    & "$INSTALL_DIR/cli/argos-connect.ps1" init | Out-Null
    & "$INSTALL_DIR/cli/argos-models-apply.ps1" 2>&1 | Select-Object -First 5 | ForEach-Object { Write-Host "      $_" }
    OK "Configuracion global lista (~/.config/arnes)"
} catch {
    Warn "Setup global incompleto. Corre 'argos connect' manualmente."
}
Pop-Location

Step "Configurando alias de PowerShell..."
$profilePath = $PROFILE
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}
$aliasLine = "Set-Alias -Name atlas -Value '$INSTALL_DIR/cli/atlas.ps1' -Scope Global -Force"
$profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($profileContent -notmatch [regex]::Escape($aliasLine)) {
    Add-Content -LiteralPath $profilePath -Value ("`n# Atlas Harness RPG alias`n" + $aliasLine)
    OK "Alias 'atlas' agregado al profile de PowerShell"
} else {
    OK "Alias 'atlas' ya existe en profile"
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Red
Write-Host "  INSTALACION COMPLETADA" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Red
Write-Host ""
Write-Host "  Uso:"
Write-Host "    1. Abre una NUEVA terminal (para cargar el alias)"
Write-Host "    2. cd <tu-proyecto>"
Write-Host "    3. argos          (entorno: connect -> configure -> chat)" -ForegroundColor Green
Write-Host "       argos connect    conectar proveedores (una vez por maquina)"
Write-Host "       argos configure  elegir modelo por agente (una vez por maquina)"
Write-Host ""
Write-Host "  Detectado:    $($platforms -join ', ')"
Write-Host "  Instalado en: $INSTALL_DIR"
Write-Host ""
