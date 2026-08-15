#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('configure', 'show', 'validate')]
    [string]$Action = 'configure',
    # Read-only validation input used by deterministic tests and automation.
    [string[]]$ModelIds = @(),
    [string]$CatalogPath = ''
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$ArnesDir = Join-Path $Root '.arnes'
$ChainPath = Join-Path $ArnesDir 'model-chain.json'

function Read-Chain {
    if (Test-Path $ChainPath) {
        return Get-Content -LiteralPath $ChainPath -Raw | ConvertFrom-Json
    }
    return $null
}

function Get-OpenCodeModels {
    if ($CatalogPath) {
        if (-not (Test-Path -LiteralPath $CatalogPath)) { throw "No encontre el catalogo '$CatalogPath'." }
        return @(Get-Content -LiteralPath $CatalogPath | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[\w.-]+/.+' } | Sort-Object -Unique)
    }
    $raw = @(cmd /c 'opencode models' 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "No pude consultar 'opencode models': $($raw -join ' ')"
    }
    return @($raw | Where-Object { $_ -match '^[\w-]+/.+' } | ForEach-Object { $_.Trim() })
}

function Assert-ModelSelection {
    param([string[]]$SelectedModels, [string[]]$Catalog)
    if ($SelectedModels.Count -ne 4) { throw 'Debes seleccionar exactamente cuatro modelos.' }
    if (@($SelectedModels | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count) { throw 'Cada slot debe tener un modelo.' }
    $duplicates = @($SelectedModels | Group-Object | Where-Object Count -gt 1)
    if ($duplicates.Count) { throw "No repitas modelos: '$($duplicates[0].Name)' esta seleccionado mas de una vez." }
    $unknown = @($SelectedModels | Where-Object { $_ -notin $Catalog })
    if ($unknown.Count) { throw "Modelo no disponible en el catalogo vivo: '$($unknown[0])'." }
}

function Read-MenuChoice {
    param([string]$Prompt, [int]$Maximum, [int]$Default = 1)
    $raw = Read-Host "$Prompt (1-$Maximum, Enter=$Default)"
    if ([string]::IsNullOrWhiteSpace($raw)) { return $Default - 1 }
    $value = 0
    if (-not [int]::TryParse($raw, [ref]$value) -or $value -lt 1 -or $value -gt $Maximum) {
        Write-Host '  Seleccion invalida.' -ForegroundColor Red
        return Read-MenuChoice -Prompt $Prompt -Maximum $Maximum -Default $Default
    }
    return $value - 1
}

function Show-Chain {
    $chain = Read-Chain
    if (-not $chain) {
        Write-Host '  Aun no hay una cadena configurada. Usa: atlas configure' -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Host '  CADENA DE MODELOS ATLAS FF' -ForegroundColor Cyan
    Write-Host '  ===========================' -ForegroundColor Cyan
    $platform = if ($chain.platform) { $chain.platform } else { 'opencode (cadena heredada)' }
    Write-Host "  Plataforma: $platform" -ForegroundColor White
    $available = $null
    if ($platform -like 'opencode*') {
        try { $available = Get-OpenCodeModels } catch { Write-Host '  Catalogo vivo: no disponible en este momento.' -ForegroundColor Yellow }
    }
    foreach ($model in @($chain.models | Sort-Object slot)) {
        $state = if ($null -eq $available) { 'SIN VERIFICAR' } elseif ($model.full_id -in $available) { 'LISTO' } else { 'NO DISPONIBLE' }
        $color = if ($state -eq 'LISTO') { 'Green' } elseif ($state -eq 'NO DISPONIBLE') { 'Red' } else { 'Yellow' }
        Write-Host ("  {0}. {1} [{2}]" -f $model.slot, $model.full_id, $state) -ForegroundColor $color
    }
    Write-Host "  Cambio despues de: $($chain.circuit_breaker.max_failures_per_model) errores transitorios por modelo" -ForegroundColor White
    Write-Host "  Estado: $ChainPath" -ForegroundColor DarkGray
}

function Configure-Chain {
    Write-Host ''
    Write-Host '  CONFIGURADOR ATLAS FF' -ForegroundColor Cyan
    Write-Host '  =====================' -ForegroundColor Cyan
    Write-Host '  Define cuatro modelos de cualquier proveedor en orden. Atlas inicia con el 1 y cambia al siguiente tras 3 errores transitorios.' -ForegroundColor White
    $platform = 'opencode'
    $catalog = Get-OpenCodeModels
    if ($catalog.Count -eq 0) { throw 'OpenCode no devolvio modelos configurados.' }
    $providers = @($catalog | ForEach-Object { ($_.Split('/'))[0] } | Sort-Object -Unique)
    Write-Host "  Catalogo completo: $($catalog.Count) modelos en $($providers.Count) proveedores. Se permite mezclar proveedores entre slots." -ForegroundColor White
    Write-Host '  Para revisar: atlas models (o atlas models -Provider <proveedor>)' -ForegroundColor DarkGray

    $existing = Read-Chain
    $models = @()
    for ($slot = 1; $slot -le 4; $slot++) {
        $previous = $null
        if ($existing -and $existing.models -and $existing.models.Count -ge $slot) {
            $candidate = $existing.models[$slot - 1].full_id
            if (($platform -ne 'opencode') -or ($candidate -in $catalog)) { $previous = $candidate }
        }

        while ($true) {
            $suffix = if ($previous) { " (Enter=$previous)" } else { '' }
            $model = Read-Host "  Modelo $slot$suffix"
            if ([string]::IsNullOrWhiteSpace($model) -and $previous) { $model = $previous }
            if ([string]::IsNullOrWhiteSpace($model)) {
                Write-Host '    Debes indicar un modelo.' -ForegroundColor Red
                continue
            }
            if ($model -notin $catalog) {
                Write-Host '    Ese modelo no esta disponible en el catalogo vivo. Copialo de atlas models.' -ForegroundColor Red
                continue
            }
            if ($models.full_id -contains $model) {
                Write-Host '    No repitas modelos: cada slot debe ser un fallback diferente.' -ForegroundColor Red
                continue
            }
            $models += [ordered]@{ slot = $slot; provider = ($model.Split('/'))[0]; full_id = $model }
            break
        }
    }

    Assert-ModelSelection -SelectedModels @($models | ForEach-Object full_id) -Catalog $catalog
    $selectedProviders = @($models | ForEach-Object provider | Sort-Object -Unique)

    $chain = [ordered]@{
        '$schema' = 'https://arnes.dev/schemas/model-chain-v2.json'
        version = '2.0.0'
        configured_at = (Get-Date).ToString('o')
        platform = $platform
        primary_provider = if ($selectedProviders.Count -eq 1) { $selectedProviders[0] } else { 'mixed' }
        chain_strategy = 'sequential_on_transient_errors'
        models = $models
        circuit_breaker = [ordered]@{
            max_failures_per_model = 3
            cooldown_minutes = 30
            error_patterns = @('internal server', 'internal_error', 'reconnecting', 'connection reset', 'connection refused', 'timeout', 'rate limit', '429', '503', '502')
        }
    }

    if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }
    $chain | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ChainPath -Encoding UTF8
    Write-Host ''
    Write-Host '  Cadena guardada. Atlas usara 1 -> 2 -> 3 -> 4 ante tres fallos transitorios.' -ForegroundColor Green
    Show-Chain
}

if ($Action -eq 'show') {
    Show-Chain
} elseif ($Action -eq 'validate') {
    $catalog = Get-OpenCodeModels
    Assert-ModelSelection -SelectedModels $ModelIds -Catalog $catalog
    [ordered]@{ status = 'valid'; models = @($ModelIds); providers = @($ModelIds | ForEach-Object { ($_ -split '/', 2)[0] } | Sort-Object -Unique); mutates_state = $false } | ConvertTo-Json -Compress
} else {
    Configure-Chain
}
