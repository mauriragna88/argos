#Requires -Version 5.1
<#! Deterministic acceptance test; it never invokes OpenCode. #>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$command = Join-Path $PSScriptRoot 'model-route-status.ps1'
$atlas = Join-Path $PSScriptRoot 'atlas-ff.ps1'
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ('arnes-route-catalog-' + [guid]::NewGuid().ToString() + '.json')
$policy = Join-Path $root '.arnes\model-routing-policy.json'
$legacy = @(
    (Join-Path $root '.arnes\model-chain.json'),
    (Join-Path $root '.arnes\model-assignments.json')
) | Where-Object { Test-Path -LiteralPath $_ }

function Assert-That([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

try {
    @(
        [ordered]@{ full_id='nvidia/deepseek-v4-pro'; source='live'; availability='available'; health='healthy' },
        [ordered]@{ full_id='tokenrouter/moonshotai/kimi-k3-free'; source='live'; availability='available'; health='healthy' },
        [ordered]@{ full_id='nvidia/minimax-m3'; source='live'; availability='available'; health='healthy' },
        [ordered]@{ full_id='nvidia/glm-5.2'; source='live'; availability='available'; health='degraded' },
        [ordered]@{ full_id='nvidia/other'; source='configured'; availability='unavailable' }
    ) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $fixture -Encoding utf8
    $before = @($legacy | ForEach-Object { "$_=$((Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash)" })

    $raw = & $command routes -CatalogPath $fixture -PolicyPath $policy -Json; $exit = $LASTEXITCODE; $routes = $raw | ConvertFrom-Json
    Assert-That ($exit -eq 0 -and @($routes).Count -eq 13) 'routes lists every policy agent'
    $raw = & $command provider-status -CatalogPath $fixture -PolicyPath $policy -Json; $exit = $LASTEXITCODE; $providers = $raw | ConvertFrom-Json
    $kimi = @($providers | Where-Object capability -eq 'kimi_k3')[0]
    Assert-That ($exit -eq 0 -and $kimi.healthy_models -eq 1 -and $kimi.weekly_soft_cap_percent -eq 30) 'provider status derives healthy count and declarative cap'

    $raw = & $command auto -Agent vivi -CatalogPath $fixture -PolicyPath $policy -Json; $exit = $LASTEXITCODE; $auto = $raw | ConvertFrom-Json
    Assert-That ($exit -eq 0 -and $auto.selected_model -eq 'tokenrouter/moonshotai/kimi-k3-free' -and -not $auto.mutates_state) 'auto preview selects first healthy preference without mutation'
    $raw = & $command manual -Agent vivi -Capability minimax_m3 -CatalogPath $fixture -PolicyPath $policy -Json; $exit = $LASTEXITCODE; $manual = $raw | ConvertFrom-Json
    Assert-That ($exit -eq 0 -and $manual.selected_model -eq 'nvidia/minimax-m3' -and $manual.mode -eq 'manual') 'manual preview honors an authorized healthy alternative'
    $raw = & $command manual -Agent vivi -Capability glm_5_2 -CatalogPath $fixture -PolicyPath $policy -Json; $exit = $LASTEXITCODE; $unhealthy = $raw | ConvertFrom-Json
    Assert-That ($exit -eq 2 -and $unhealthy.status -eq 'unresolved') 'manual preview refuses an unhealthy capability'
    $raw = & $command manual -Agent vivi -Capability not_authorized -CatalogPath $fixture -PolicyPath $policy -Json 2>$null; $exit = $LASTEXITCODE; $invalid = $raw | ConvertFrom-Json
    Assert-That ($exit -eq 1 -and $invalid.status -eq 'error') 'manual preview rejects unknown capability'

    # Covers public dispatcher wiring without querying the real OpenCode catalog.
    $raw = & $atlas models -Provider nvidia -CatalogPath $fixture -Json; $ok = $?
    Assert-That ($ok -and ($raw -join "`n") -match 'nvidia/deepseek-v4-pro') 'atlas models maps to catalog command'
    $raw = & $atlas routes -CatalogPath $fixture -Json; $ok = $?
    Assert-That ($ok -and ($raw -join "`n") -match 'vivi') 'atlas routes maps to route status command'
    $raw = & $atlas provider-status -CatalogPath $fixture -Json; $ok = $?
    Assert-That ($ok -and ($raw -join "`n") -match 'kimi_k3') 'atlas provider-status maps to status command'
    $raw = & $atlas -Command route -LegacyArguments @('auto', 'vivi') -CatalogPath $fixture -Json; $ok = $?
    Assert-That ($ok -and ($raw -join "`n") -match 'kimi-k3-free') 'atlas route auto maps agent argument'
    $raw = & $atlas -Command route -LegacyArguments @('manual', 'vivi', 'minimax_m3') -CatalogPath $fixture -Json; $ok = $?
    Assert-That ($ok -and ($raw -join "`n") -match 'minimax-m3') 'atlas route manual maps capability argument'

    $after = @($legacy | ForEach-Object { "$_=$((Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash)" })
    Assert-That (($before -join "`n") -eq ($after -join "`n")) 'all legacy routing files remain byte-identical'
    Write-Host 'PASS model-route-status: catalog, routes, provider health, safe auto/manual previews, dispatcher mapping, no legacy mutation' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $fixture -Force -ErrorAction SilentlyContinue
}
exit 0
