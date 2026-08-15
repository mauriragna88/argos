#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$resolver = Join-Path $PSScriptRoot 'agent-model-resolver.ps1'
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ('arnes-catalog-' + [guid]::NewGuid().ToString() + '.json')
$invalidPolicy = Join-Path ([System.IO.Path]::GetTempPath()) ('arnes-policy-' + [guid]::NewGuid().ToString() + '.json')
try {
    @(
        [ordered]@{ full_id='nvidia/deepseek-v4-pro'; provider='nvidia'; source='live'; availability='available' },
        [ordered]@{ full_id='tokenrouter/moonshotai/kimi-k3-free'; provider='tokenrouter'; source='live'; availability='available' },
        [ordered]@{ full_id='nvidia/minimax-m3'; provider='nvidia'; source='live'; availability='available' },
        [ordered]@{ full_id='nvidia/glm-5.2'; provider='nvidia'; source='configured'; availability='unavailable' }
    ) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $fixture -Encoding UTF8

    $raw = & $resolver -Agent vivi -CatalogPath $fixture -ArnesDir (Join-Path $root '.arnes') -Json; $exit = $LASTEXITCODE; $vivi = $raw | ConvertFrom-Json
    if ($exit -ne 0 -or $vivi.selected_model -ne 'tokenrouter/moonshotai/kimi-k3-free' -or $vivi.preference_index -ne 0) { throw 'Vivi did not choose the first live preference.' }
    $raw = & $resolver -Agent tywin -CatalogPath $fixture -ArnesDir (Join-Path $root '.arnes') -Json; $exit = $LASTEXITCODE; $tywin = $raw | ConvertFrom-Json
    if ($exit -ne 0 -or $tywin.selected_model -ne 'nvidia/deepseek-v4-pro' -or $tywin.provider -ne 'nvidia') { throw 'Tywin resolution failed.' }

    @(
        [ordered]@{ full_id='tokenrouter/kimi-k3-free'; provider='tokenrouter'; source='live'; availability='available'; health='degraded' },
        [ordered]@{ full_id='nvidia/minimax-m3'; provider='nvidia'; source='live'; availability='available'; health='healthy' }
    ) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $fixture -Encoding UTF8
    $raw = & $resolver -Agent vivi -CatalogPath $fixture -ArnesDir (Join-Path $root '.arnes') -Json; $exit = $LASTEXITCODE; $fallback = $raw | ConvertFrom-Json
    if ($exit -ne 0 -or $fallback.selected_model -ne 'nvidia/minimax-m3' -or $fallback.preference_index -ne 1) { throw 'Vivi did not skip an unhealthy preferred model.' }

    @([ordered]@{ full_id='nvidia/glm-5.2'; provider='nvidia'; source='configured'; availability='unavailable' }) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $fixture -Encoding UTF8
    $raw = & $resolver -Agent vivi -CatalogPath $fixture -ArnesDir (Join-Path $root '.arnes') -Json; $exit = $LASTEXITCODE; $nothing = $raw | ConvertFrom-Json
    if ($exit -ne 2 -or $nothing.status -ne 'unresolved' -or $nothing.reason -ne 'no_healthy_live_candidate') { throw 'Unavailable configured-only model was not rejected deterministically.' }

    $policy = Get-Content -LiteralPath (Join-Path $root '.arnes\model-routing-policy.json') -Raw | ConvertFrom-Json
    $policy.agents.vivi.preference_order = @('unknown_capability')
    $policy | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $invalidPolicy -Encoding UTF8
    $raw = & $resolver -Agent vivi -CatalogPath $fixture -PolicyPath $invalidPolicy -Json; $exit = $LASTEXITCODE; $invalid = $raw | ConvertFrom-Json
    if ($exit -ne 1 -or $invalid.status -ne 'error' -or $invalid.reason -ne 'resolver_error' -or $invalid.message -notmatch 'alias desconocido') { throw 'Invalid policy alias was not rejected deterministically.' }

    Write-Host 'PASS agent-model-resolver: live preference, health fallback, configured-only rejection, unresolved and invalid-policy error' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $fixture -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $invalidPolicy -Force -ErrorAction SilentlyContinue
}
exit 0
