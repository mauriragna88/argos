#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$catalog = Join-Path $root 'cli\model-catalog.ps1'
$work = Join-Path $root ('.model-catalog-test-' + [guid]::NewGuid().ToString('N'))
$ok = Join-Path $work 'models-ok.cmd'
$fail = Join-Path $work 'models-fail.cmd'
$chain = Join-Path $work 'model-chain.json'

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    # A .cmd path exercises the Windows wrapper branch, independent of OpenCode.
    @('@echo off', 'echo zzz/model-b', 'echo aaa/model-a', 'exit /b 0') |
        Set-Content -LiteralPath $ok -Encoding ascii
    @('@echo off', 'echo controlled provider failure 1>&2', 'exit /b 7') |
        Set-Content -LiteralPath $fail -Encoding ascii
    [ordered]@{
        models = @(
            [ordered]@{ full_id = 'aaa/model-a'; nickname = 'Configured A' },
            [ordered]@{ full_id = 'missing/model-c'; nickname = 'Missing configured model' }
        )
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $chain -Encoding utf8

    $successOutput = & $catalog -ArnesDir $work -OpenCodeCommand $ok -TimeoutSeconds 5
    $successExit = $LASTEXITCODE
    $parsedRows = $successOutput | ConvertFrom-Json
    $rows = @()
    foreach ($entry in $parsedRows) { $rows += $entry }
    $ids = @($rows | ForEach-Object { $_.full_id })
    $liveRows = @($rows | Where-Object { $_.source -eq 'live' -and $_.availability -eq 'available' })
    $missing = @($rows | Where-Object { $_.full_id -eq 'missing/model-c' })

    Assert-That ($successExit -eq 0) "successful .cmd wrapper exits 0 (got $successExit)"
    Assert-That (($ids -join ',') -eq 'aaa/model-a,missing/model-c,zzz/model-b') 'rows use lexicographic full_id ordering'
    Assert-That ($liveRows.Count -eq 2) 'both discovered entries are live and available'
    Assert-That (($missing.Count -eq 1) -and ($missing[0].source -eq 'configured') -and ($missing[0].availability -eq 'unavailable')) 'missing configured model is visible but unavailable'

    $failureOutput = & $catalog -ArnesDir $work -OpenCodeCommand $fail -TimeoutSeconds 5
    $failureExit = $LASTEXITCODE
    $failure = $failureOutput | ConvertFrom-Json
    Assert-That ($failureExit -eq 1) "failing .cmd wrapper exits 1 (got $failureExit)"
    Assert-That ($failure.error.code -eq 'OPENCODE_CATALOG_UNAVAILABLE') 'failure uses structured catalog error code'
    Assert-That ((@($failure.PSObject.Properties.Name) -join ',') -eq 'error,checked_at') 'failure result contains only the structured error object, not catalog rows'

    Write-Output 'PASS model-catalog: cmd wrapper, configured-only entry, stable ordering, structured failure'
    exit 0
} finally {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
