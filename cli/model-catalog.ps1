#Requires -Version 5.1
<#
.SYNOPSIS
Returns the live OpenCode model catalog as stable JSON.

.DESCRIPTION
The catalog is intentionally read-only.  It never updates routing state and it
never treats a configured model as available: availability is established only
by a successful `opencode models` call in the current invocation.
#>
[CmdletBinding()]
param(
    [string]$ArnesDir = '',
    [string]$Provider = '',
    # Intended for deterministic verification; production callers omit it.
    [string]$OpenCodeCommand = '',
    [string]$OpenCodeArguments = 'models',
    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 30,
    [switch]$Pretty
)

$ErrorActionPreference = 'Stop'

function Write-CatalogJson {
    param([Parameter(Mandatory = $true)]$Value)

    $depth = 8
    if ($Pretty) {
        $Value | ConvertTo-Json -Depth $depth
    } else {
        $Value | ConvertTo-Json -Depth $depth -Compress
    }
}

function Get-ConfiguredModels {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return @() }

    try {
        $chain = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        throw "No pude leer la configuracion de modelos '$Path': $($_.Exception.Message)"
    }

    return @($chain.models | Where-Object { $_.full_id } | ForEach-Object {
        [PSCustomObject]@{
            full_id = [string]$_.full_id
            label = if ($_.nickname) { [string]$_.nickname } else { [string]$_.full_id }
        }
    })
}

function Get-LiveOpenCodeModels {
    $commandPath = $OpenCodeCommand
    if (-not $commandPath) {
        $command = Get-Command 'opencode' -ErrorAction SilentlyContinue
        if (-not $command) {
            throw "No encontre el comando 'opencode' en PATH."
        }
        $commandPath = if ($command.Path) { $command.Path } else { $command.Source }
    }

    $extension = [System.IO.Path]::GetExtension($commandPath).ToLowerInvariant()
    $processPath = $commandPath
    $processArguments = $OpenCodeArguments
    if ($extension -eq '.ps1') {
        $shellCommand = Get-Command 'pwsh' -ErrorAction SilentlyContinue
        if (-not $shellCommand) { $shellCommand = Get-Command 'powershell.exe' -ErrorAction Stop }
        $processPath = if ($shellCommand.Path) { $shellCommand.Path } else { $shellCommand.Source }
        $processArguments = "-NoProfile -File `"$commandPath`" $OpenCodeArguments"
    } elseif ($extension -in @('.cmd', '.bat')) {
        if (-not $env:ComSpec) { throw 'No encontre cmd.exe (ComSpec) para ejecutar el wrapper de OpenCode.' }
        $processPath = $env:ComSpec
        $processArguments = "/d /s /c `"`"$commandPath`" $OpenCodeArguments`""
    }

    # A provider CLI can hang before producing output. Use Process directly:
    # unlike Start-Job, WaitForExit has a reliable timeout on Windows PS 5.1.
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $processPath
    $startInfo.Arguments = $processArguments
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw "No pude iniciar '$commandPath'."
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            $process.WaitForExit()
            throw "'opencode models' excedio el limite de $TimeoutSeconds segundos."
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
    } finally {
        $process.Dispose()
    }

    $raw = @($stdout -split "`r?`n") + @($stderr -split "`r?`n")
    if ($exitCode -ne 0) {
        $details = @($raw | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ }) -join ' '
        throw "'opencode models' termino con codigo $exitCode. $details"
    }

    # OpenCode prints one complete provider/model id per line. Keep only those
    # IDs, so headings and terminal decoration cannot leak into the JSON API.
    return @($raw |
        ForEach-Object { $_.ToString().Trim() } |
        Where-Object { $_ -match '^[A-Za-z0-9._-]+/.+' } |
        ForEach-Object { ($_ -split '\s+')[0] } |
        Sort-Object -Unique)
}

try {
    if (-not $ArnesDir) {
        $ArnesDir = Join-Path (Get-Location) '.arnes'
    }
    $ArnesDir = [System.IO.Path]::GetFullPath($ArnesDir)
    $checkedAt = (Get-Date).ToUniversalTime().ToString('o')
    $configured = Get-ConfiguredModels -Path (Join-Path $ArnesDir 'model-chain.json')
    $configuredById = @{}
    foreach ($entry in $configured) { $configuredById[$entry.full_id] = $entry }

    $liveIds = Get-LiveOpenCodeModels
    if ($Provider) {
        $liveIds = @($liveIds | Where-Object { $_ -like "$Provider/*" })
    }

    $catalog = @()
    foreach ($fullId in $liveIds) {
        $parts = $fullId -split '/', 2
        $label = if ($configuredById.ContainsKey($fullId)) { $configuredById[$fullId].label } else { $fullId }
        $catalog += [PSCustomObject][ordered]@{
            full_id = $fullId
            provider = $parts[0]
            label = $label
            source = 'live'
            availability = 'available'
            checked_at = $checkedAt
        }
    }

    # Configured-only entries are shown for operator visibility, but are never
    # claimed to be live or selectable.
    foreach ($entry in $configured) {
        if ($Provider -and $entry.full_id -notlike "$Provider/*") { continue }
        if ($entry.full_id -in $liveIds) { continue }
        $parts = $entry.full_id -split '/', 2
        $catalog += [PSCustomObject][ordered]@{
            full_id = $entry.full_id
            provider = $parts[0]
            label = $entry.label
            source = 'configured'
            availability = 'unavailable'
            checked_at = $checkedAt
        }
    }

    Write-CatalogJson -Value @($catalog | Sort-Object full_id)
    exit 0
} catch {
    $errorResult = [ordered]@{
        error = [ordered]@{
            code = 'OPENCODE_CATALOG_UNAVAILABLE'
            message = $_.Exception.Message
        }
        checked_at = (Get-Date).ToUniversalTime().ToString('o')
    }
    Write-CatalogJson -Value $errorResult
    exit 1
}
