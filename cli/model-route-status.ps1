#Requires -Version 5.1
<#
.SYNOPSIS
Read-only status and route-preview commands for the catalog-backed policy.

.DESCRIPTION
This command never writes a route, model-chain, assignment, or failover file.
`auto` previews the policy resolver result. `manual` previews one explicitly
requested capability only when it has a healthy live catalog match.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('models', 'routes', 'provider-status', 'auto', 'manual')]
    [string]$Action,
    [string]$Agent = '',
    [string]$Capability = '',
    [string]$ArnesDir = '',
    [string]$PolicyPath = '',
    [string]$CatalogPath = '',
    [string]$Provider = '',
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Test-CapabilityMatch {
    param([string]$Value, [string]$FullId)
    $modelPart = (($FullId -split '/', 2)[-1]).ToLowerInvariant()
    switch ($Value) {
        'kimi_k3'         { return $modelPart -match '(^|[/_-])kimi[-_]?k3($|[-_])' }
        'glm_5_2'         { return $modelPart -match '(^|[/_-])glm[-_]?5[._-]?2($|[-_])' }
        'minimax_m3'      { return $modelPart -match '(^|[/_-])minimax[-_]?m3($|[-_])' }
        'deepseek_v4_pro' { return $modelPart -match '(^|[/_-])deepseek[-_]?v4[-_]?pro($|[-_])' }
        default { return $false }
    }
}

function Get-Catalog {
    if ($CatalogPath) {
        if (-not (Test-Path -LiteralPath $CatalogPath)) { throw "No encontre el catalogo '$CatalogPath'." }
        return @(Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json)
    }
    $catalogScript = Join-Path $PSScriptRoot 'model-catalog.ps1'
    $raw = & $catalogScript -ArnesDir $ArnesDir
    if ($LASTEXITCODE -ne 0) { throw "El catalogo vivo no estuvo disponible: $raw" }
    return @($raw | ConvertFrom-Json)
}

function Get-HealthyRows {
    param($Catalog)
    $errors = @($Catalog | Where-Object { $null -ne $_.error })
    if ($errors.Count) { throw "El catalogo reporto $($errors[0].error.code): $($errors[0].error.message)" }
    return @($Catalog | Where-Object {
        $_.source -eq 'live' -and $_.availability -eq 'available' -and
        ($null -eq $_.health -or $_.health -eq 'healthy')
    } | Sort-Object full_id)
}

function Get-Preview {
    param($Policy, [string]$RequestedAgent, $HealthyRows, [string]$RequestedCapability = '')
    $agentPolicy = $Policy.agents.$RequestedAgent
    if ($null -eq $agentPolicy) { throw "El agente '$RequestedAgent' no esta definido en la politica." }
    $choices = if ($RequestedCapability) { @($RequestedCapability) } else { @($agentPolicy.preference_order) }
    foreach ($choice in $choices) {
        if ($choice -notin @($Policy.model_capabilities.PSObject.Properties.Name)) {
            throw "La capability '$choice' no esta definida en la politica."
        }
        $candidate = @($HealthyRows | Where-Object { Test-CapabilityMatch $choice ([string]$_.full_id) } | Select-Object -First 1)
        if ($candidate.Count) {
            $parts = ([string]$candidate[0].full_id) -split '/', 2
            return [ordered]@{
                status = 'preview'; mode = if ($RequestedCapability) { 'manual' } else { 'auto' }
                mutates_state = $false; agent = $RequestedAgent; selected_model = $candidate[0].full_id
                provider = $parts[0]; capability = $choice
                preference_index = if ($RequestedCapability) { @($agentPolicy.preference_order).IndexOf($choice) } else { @($agentPolicy.preference_order).IndexOf($choice) }
                reason = if ($RequestedCapability) { 'requested_healthy_live_capability' } else { 'first_healthy_live_preference' }
            }
        }
    }
    return [ordered]@{
        status = 'unresolved'; mode = if ($RequestedCapability) { 'manual' } else { 'auto' }
        mutates_state = $false; agent = $RequestedAgent; selected_model = $null; provider = $null
        capability = $RequestedCapability; preference_index = $null
        reason = if ($RequestedCapability) { 'requested_capability_has_no_healthy_live_candidate' } else { 'no_healthy_live_candidate' }
    }
}

function Write-Result {
    param($Value)
    if ($Json) { $Value | ConvertTo-Json -Depth 8; return }
    switch ($Action) {
        'models' {
            Write-Host 'MODELOS: catalogo vivo/configurado (solo lectura)' -ForegroundColor Cyan
            $Value | ForEach-Object { Write-Host ("  {0,-42} {1,-11} {2}" -f $_.full_id, $_.availability, $_.source) }
        }
        'routes' {
            Write-Host 'RUTAS POR AGENTE: preferencia declarativa (no aplica cambios)' -ForegroundColor Cyan
            $Value | ForEach-Object { Write-Host ("  {0,-8} {1}" -f $_.agent, ($_.preference_order -join ' -> ')) }
        }
        'provider-status' {
            Write-Host 'ESTADO DE PROVEEDORES: catalogo y presupuesto declarativo' -ForegroundColor Cyan
            $Value | ForEach-Object { Write-Host ("  {0,-18} sanos:{1,-3} cap semanal:{2}%" -f $_.capability, $_.healthy_models, $_.weekly_soft_cap_percent) }
        }
        default {
            if ($Value.status -eq 'preview') {
                Write-Host ("PREVIEW {0}: {1} -> {2} ({3})" -f $Value.mode.ToUpperInvariant(), $Value.agent, $Value.selected_model, $Value.capability) -ForegroundColor Green
            } else {
                Write-Host ("PREVIEW {0}: sin modelo elegible para {1}. {2}" -f $Value.mode.ToUpperInvariant(), $Value.agent, $Value.reason) -ForegroundColor Yellow
            }
            Write-Host '  No se escribio ningun archivo de routing.' -ForegroundColor DarkGray
        }
    }
}

try {
    if (-not $ArnesDir) { $ArnesDir = Join-Path (Get-Location) '.arnes' }
    if (-not $PolicyPath) { $PolicyPath = Join-Path $ArnesDir 'model-routing-policy.json' }
    if (-not (Test-Path -LiteralPath $PolicyPath)) { throw "No encontre la politica '$PolicyPath'." }
    $policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
    $catalog = Get-Catalog
    $healthy = Get-HealthyRows $catalog

    switch ($Action) {
        'models' {
            $result = @($catalog | Where-Object {
                -not $Provider -or ([string]$_.full_id).StartsWith("$Provider/", [System.StringComparison]::OrdinalIgnoreCase)
            } | Sort-Object full_id)
        }
        'routes' {
            $result = @($policy.agents.PSObject.Properties | Sort-Object Name | ForEach-Object {
                [ordered]@{ agent = $_.Name; preference_order = @($_.Value.preference_order); preview_only = $true }
            })
        }
        'provider-status' {
            $result = @($policy.model_capabilities.PSObject.Properties | Sort-Object Name | ForEach-Object {
                $capability = $_.Name
                [ordered]@{
                    capability = $capability; display_name = $_.Value.display_name
                    healthy_models = @($healthy | Where-Object { Test-CapabilityMatch $capability ([string]$_.full_id) }).Count
                    weekly_soft_cap_percent = $policy.provider_budget_defaults.caps_percent_by_capability.$capability
                    budget_is_usage_tracking = $false
                }
            })
        }
        'auto' {
            if (-not $Agent) { throw 'auto requiere -Agent <nombre>.' }
            $result = Get-Preview $policy $Agent $healthy
        }
        'manual' {
            if (-not $Agent -or -not $Capability) { throw 'manual requiere -Agent <nombre> -Capability <alias>.' }
            if ($Capability -notin @($policy.agents.$Agent.preference_order)) { throw "'$Capability' no esta autorizada para '$Agent'; usa una capability de su ruta declarada." }
            $result = Get-Preview $policy $Agent $healthy $Capability
        }
    }
    Write-Result $result
    if (($Action -in @('auto', 'manual')) -and $result.status -ne 'preview') { exit 2 }
    exit 0
} catch {
    $errorResult = [ordered]@{ status = 'error'; action = $Action; mutates_state = $false; message = $_.Exception.Message }
    if ($Json) { $errorResult | ConvertTo-Json -Depth 4 } else { Write-Error $errorResult.message }
    exit 1
}
