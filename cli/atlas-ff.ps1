#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Command = 'home',
    [string]$Provider = '',
    # Test-only injection; normal CLI usage always reads the live catalog.
    [string]$CatalogPath = '',
    [switch]$Json,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$LegacyArguments
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$LegacyLauncher = Join-Path $ScriptDir 'atlas.ps1'
$ModelConfigurator = Join-Path $ScriptDir 'atlas-model-config.ps1'
$Failover = Join-Path $ScriptDir 'atlas-failover.ps1'
$GuardedLauncher = Join-Path $ScriptDir 'atlas-guarded-launch.ps1'
$RouteStatus = Join-Path $ScriptDir 'model-route-status.ps1'
$KnownCommands = @('home', 'models', 'routes', 'provider-status', 'route', 'doctor', 'configure', 'config', 'failover', 'launch')

function Show-Banner {
    Write-Host ''
    Write-Host '     _   _____ _        _    ____   _____ _____ ' -ForegroundColor Red
    Write-Host '    / \ |_   _| |      / \  / ___| |  ___|  ___|' -ForegroundColor Red
    Write-Host '   / _ \  | | | |     / _ \ \___ \ | |_  | |_   ' -ForegroundColor White
    Write-Host '  / ___ \ | | | |___ / ___ \ ___) ||  _| |  _|  ' -ForegroundColor DarkGray
    Write-Host ' /_/   \_\|_| |_____/_/   \_\____/ |_|   |_|    ' -ForegroundColor Red
    Write-Host ''
    Write-Host '                 COMMAND CENTER - Arnes Harness' -ForegroundColor DarkGray
    Write-Host ''
}

function Get-ProviderStatus {
    @('opencode', 'codex', 'claude') | ForEach-Object {
        [PSCustomObject]@{
            Provider = $_
            Available = [bool](Get-Command $_ -ErrorAction SilentlyContinue)
        }
    }
}

function Get-OpenCodeModels {
    $raw = @(cmd /c 'opencode models' 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "OpenCode no pudo listar modelos: $($raw -join ' ')"
    }

    $models = $raw | Where-Object { $_ -match '^[\w-]+/.+' }
    if ($Provider) {
        $models = $models | Where-Object { $_ -like "$Provider/*" }
    }
    return $models
}

function Show-Models {
    Show-Banner
    Write-Host '  MODELOS DISPONIBLES' -ForegroundColor Cyan
    Write-Host '  ===================' -ForegroundColor Cyan
    $models = Get-OpenCodeModels
    if (-not $models) {
        Write-Host '  No hay modelos disponibles para el filtro indicado.' -ForegroundColor Yellow
        return
    }

    $models | Group-Object { ($_.ToString() -split '/')[0] } | Sort-Object Name | ForEach-Object {
        Write-Host "`n  [$($_.Name)]" -ForegroundColor Yellow
        $_.Group | ForEach-Object { Write-Host "    $_" -ForegroundColor White }
    }
}

function Show-Doctor {
    Show-Banner
    Write-Host '  SYSTEM DOCTOR' -ForegroundColor Cyan
    Write-Host '  =============' -ForegroundColor Cyan
    Get-ProviderStatus | ForEach-Object {
        $color = if ($_.Available) { 'Green' } else { 'Red' }
        $status = if ($_.Available) { 'READY' } else { 'NOT FOUND' }
        Write-Host "  $($_.Provider.PadRight(10)) $status" -ForegroundColor $color
    }
    $hmac = if ($env:ARNES_ARTIFACT_HMAC_KEY) { 'READY' } else { 'MISSING' }
    $hmacColor = if ($hmac -eq 'READY') { 'Green' } else { 'Yellow' }
    Write-Host "  HMAC key   $hmac" -ForegroundColor $hmacColor
}

function Show-Home {
    Show-Banner
    Get-ProviderStatus | ForEach-Object {
        $status = if ($_.Available) { 'READY' } else { 'OFFLINE' }
        $color = if ($_.Available) { 'Green' } else { 'Red' }
        Write-Host "  $($_.Provider.PadRight(10)) $status" -ForegroundColor $color
    }
    Write-Host ''
    Write-Host '  atlas models                  Lista catalogo vivo' -ForegroundColor White
    Write-Host '  atlas models -Provider nvidia Filtra por proveedor' -ForegroundColor White
    Write-Host '  atlas routes                  Muestra preferencias por agente' -ForegroundColor White
    Write-Host '  atlas provider-status         Muestra salud y caps declarados' -ForegroundColor White
    Write-Host '  atlas route auto vivi         Previsualiza la ruta automatica' -ForegroundColor White
    Write-Host '  atlas route manual vivi minimax_m3  Previsualiza override seguro' -ForegroundColor White
    Write-Host '  atlas doctor                  Diagnostico de proveedores y firma' -ForegroundColor White
    Write-Host '  atlas configure               Configura 4 modelos y su orden de fallback' -ForegroundColor White
    Write-Host '  atlas config                  Muestra la cadena activa de modelos' -ForegroundColor White
    Write-Host '  atlas failover                Muestra modelo elegible y cooldowns' -ForegroundColor White
    Write-Host '  atlas launch                  Abre el launcher Atlas actual' -ForegroundColor White
    Write-Host '  atlas --lean                  Compatibilidad con el launcher anterior' -ForegroundColor DarkGray
}

if (($Command -notin $KnownCommands) -or (($Command -eq 'home') -and $LegacyArguments.Count -gt 0)) {
    & $LegacyLauncher @($Command) @LegacyArguments
    exit $LASTEXITCODE
}

switch ($Command) {
    'models' { & $RouteStatus models -Provider $Provider -CatalogPath $CatalogPath -Json:$Json; exit $LASTEXITCODE }
    'routes' { & $RouteStatus routes -CatalogPath $CatalogPath -Json:$Json; exit $LASTEXITCODE }
    'provider-status' { & $RouteStatus provider-status -CatalogPath $CatalogPath -Json:$Json; exit $LASTEXITCODE }
    'route' {
        $mode = if ($LegacyArguments.Count -gt 0) { $LegacyArguments[0] } else { '' }
        $agent = if ($LegacyArguments.Count -gt 1) { $LegacyArguments[1] } else { '' }
        $capability = if ($LegacyArguments.Count -gt 2) { $LegacyArguments[2] } else { '' }
        if ($mode -notin @('auto', 'manual')) {
            Write-Error 'Uso: atlas route auto <agente> | atlas route manual <agente> <capability>'
            exit 1
        }
        if ($mode -eq 'auto') { & $RouteStatus auto -Agent $agent -CatalogPath $CatalogPath -Json:$Json } else { & $RouteStatus manual -Agent $agent -Capability $capability -CatalogPath $CatalogPath -Json:$Json }
        exit $LASTEXITCODE
    }
    'doctor' { Show-Doctor }
    'configure' { & $ModelConfigurator configure; exit $LASTEXITCODE }
    'config' { & $ModelConfigurator show; exit $LASTEXITCODE }
    'failover' { & $Failover status; exit $LASTEXITCODE }
    'launch' { & $GuardedLauncher @LegacyArguments; exit $LASTEXITCODE }
    default { Show-Home }
}
