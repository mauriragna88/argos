#Requires -Version 5.1
<#
.SYNOPSIS
Resolves one Arnes agent's model preference against a live model catalog.

.DESCRIPTION
This is deliberately read-only: it does not edit model-chain.json or the
legacy model-router assignments.  Catalog entries are selectable only when
their source is live and their availability is available.

.EXAMPLE
.\agent-model-resolver.ps1 -Agent vivi -CatalogPath .\tests\fixtures\catalog.json -Json
.\agent-model-resolver.ps1 -Agent vivi -LiveCatalog -Json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Agent,
    [string]$ArnesDir = '',
    [string]$PolicyPath = '',
    [string]$CatalogPath = '',
    [switch]$LiveCatalog,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Write-Decision { param($Value) $Value | ConvertTo-Json -Depth 8 }

function Test-CapabilityMatch {
    param([string]$Capability, [string]$FullId)
    $modelPart = (($FullId -split '/', 2)[-1]).ToLowerInvariant()
    switch ($Capability) {
        'kimi_k3'         { return $modelPart -match '(^|[/_-])kimi[-_]?k3($|[-_])' }
        'glm_5_2'         { return $modelPart -match '(^|[/_-])glm[-_]?5[._-]?2($|[-_])' }
        'minimax_m3'      { return $modelPart -match '(^|[/_-])minimax[-_]?m3($|[-_])' }
        'deepseek_v4_pro' { return $modelPart -match '(^|[/_-])deepseek[-_]?v4[-_]?pro($|[-_])' }
        default { return $false }
    }
}

try {
    if (-not $ArnesDir) { $ArnesDir = Join-Path (Get-Location) '.arnes' }
    if (-not $PolicyPath) { $PolicyPath = Join-Path $ArnesDir 'model-routing-policy.json' }
    if (-not (Test-Path -LiteralPath $PolicyPath)) { throw "No encontre la politica de routing '$PolicyPath'." }
    $policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
    # Validate the whole policy before considering a catalog. A typo must never
    # silently look like a provider outage for just the requested agent.
    $knownCapabilities = @($policy.model_capabilities.PSObject.Properties.Name)
    foreach ($policyAgent in @($policy.agents.PSObject.Properties)) {
        foreach ($capability in @($policyAgent.Value.preference_order)) {
            if ($capability -notin $knownCapabilities) {
                throw "La politica contiene el alias desconocido '$capability' para el agente '$($policyAgent.Name)'."
            }
        }
    }
    $agentPolicy = $policy.agents.$Agent
    if ($null -eq $agentPolicy) { throw "El agente '$Agent' no esta definido en la politica." }

    if ($LiveCatalog) {
        if ($CatalogPath) { throw 'Usa CatalogPath o LiveCatalog, no ambos.' }
        $catalogScript = Join-Path $PSScriptRoot 'model-catalog.ps1'
        $rawCatalog = & $catalogScript -ArnesDir $ArnesDir
        if ($LASTEXITCODE -ne 0) { throw "El catalogo vivo no estuvo disponible: $rawCatalog" }
        $catalog = $rawCatalog | ConvertFrom-Json
    } elseif ($CatalogPath) {
        if (-not (Test-Path -LiteralPath $CatalogPath)) { throw "No encontre el catalogo '$CatalogPath'." }
        $catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
    } else {
        throw 'Debes indicar -CatalogPath para una entrada validada o -LiveCatalog para consultar OpenCode.'
    }

    # Catalog errors have a JSON object shape, while a valid catalog is an array.
    $catalogItems = @($catalog)
    $catalogErrors = @($catalogItems | Where-Object { $null -ne $_.error })
    if ($catalogErrors.Count -gt 0) { throw "El catalogo reporto $($catalogErrors[0].error.code): $($catalogErrors[0].error.message)" }
    $liveRows = @($catalogItems | Where-Object {
        $_.source -eq 'live' -and $_.availability -eq 'available' -and
        ($null -eq $_.health -or $_.health -eq 'healthy')
    } | Sort-Object full_id)

    $index = 0
    foreach ($capability in @($agentPolicy.preference_order)) {
        $match = @($liveRows | Where-Object { Test-CapabilityMatch -Capability $capability -FullId ([string]$_.full_id) } | Select-Object -First 1)
        if ($match.Count -gt 0) {
            $selected = $match[0]
            $parts = ([string]$selected.full_id) -split '/', 2
            $result = [ordered]@{
                status = 'resolved'; agent = $Agent; selected_model = $selected.full_id
                provider = $parts[0]; capability = $capability; preference_index = $index
                reason = 'first_healthy_live_preference'; catalog_source = $selected.source
            }
            Write-Decision $result
            exit 0
        }
        $index++
    }
    $result = [ordered]@{
        status = 'unresolved'; agent = $Agent; selected_model = $null; provider = $null
        preference_index = $null; reason = 'no_healthy_live_candidate'
    }
    Write-Decision $result
    exit 2
} catch {
    $result = [ordered]@{ status = 'error'; agent = $Agent; reason = 'resolver_error'; message = $_.Exception.Message }
    Write-Decision $result
    exit 1
}
