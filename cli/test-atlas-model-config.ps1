#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$configurator = Join-Path $PSScriptRoot 'atlas-model-config.ps1'
$catalog = Join-Path ([System.IO.Path]::GetTempPath()) ('arnes-model-config-' + [guid]::NewGuid().ToString() + '.txt')
function Assert-That([bool]$Condition, [string]$Message) { if (-not $Condition) { throw "Assertion failed: $Message" } }
try {
    @('tokenrouter/moonshotai/kimi-k3-free', 'nvidia/z-ai/glm-5.2', 'nvidia/minimaxai/minimax-m3', 'nvidia/deepseek-ai/deepseek-v4-pro') | Set-Content -LiteralPath $catalog -Encoding utf8
    $models = @(Get-Content $catalog)
    $raw = & $configurator validate -ModelIds $models -CatalogPath $catalog; $ok = $?; $valid = $raw | ConvertFrom-Json
    Assert-That ($ok -and $valid.status -eq 'valid' -and @($valid.providers).Count -eq 2 -and -not $valid.mutates_state) 'mixed-provider live catalog selection is valid and read-only'
    $failed = $false; try { & $configurator validate -ModelIds @($models[0], $models[1], $models[2], $models[2]) -CatalogPath $catalog 2>$null } catch { $failed = $true }
    Assert-That $failed 'duplicate model ID is rejected'
    $failed = $false; try { & $configurator validate -ModelIds @($models[0], $models[1], $models[2], 'unknown/provider-model') -CatalogPath $catalog 2>$null } catch { $failed = $true }
    Assert-That $failed 'unknown model ID is rejected against full live catalog'
    Write-Host 'PASS atlas-model-config: mixed providers, duplicate rejection, unknown-ID rejection' -ForegroundColor Green
} finally { Remove-Item -LiteralPath $catalog -Force -ErrorAction SilentlyContinue }
exit 0
