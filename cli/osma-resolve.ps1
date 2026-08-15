#Requires -Version 5.1
<#
.SYNOPSIS
OSMA RESOLVE - localiza el motor OSMA (repos separado) desde el harness ARGOS
.Resolucion: 1) $env:ARNES_OSMA_ROOT  2) ~/.config/arnes/osma  3) ../osma  4) ./cli (legacy)
#>
function Get-OsmaRoot {
    $candidates = @()
    if ($env:ARNES_OSMA_ROOT) { $candidates += $env:ARNES_OSMA_ROOT }
    $candidates += (Join-Path $env:USERPROFILE '.config\arnes\osma')
    $candidates += (Join-Path (Split-Path $PSScriptRoot -Parent) '..\osma')
    $candidates += $PSScriptRoot
    foreach ($c in $candidates) {
        if ($c -and (Test-Path (Join-Path $c 'osma-memory.ps1'))) { return $c }
    }
    foreach ($c in $candidates) {
        if ($c -and (Test-Path (Join-Path $c 'arnes-memory.ps1'))) { return $c }
    }
    return $null
}
function Get-OsmaMemoryCli {
    $root = Get-OsmaRoot
    if (-not $root) { return $null }
    $p = Join-Path $root 'osma-memory.ps1'
    if (Test-Path $p) { return $p }
    $legacy = Join-Path $root 'arnes-memory.ps1'
    if (Test-Path $legacy) { return $legacy }
    return $null
}
function Get-OsmaBrain {
    $root = Get-OsmaRoot
    if (-not $root) { return $null }
    $p = Join-Path $root 'osma_brain.py'
    if (Test-Path $p) { return $p }
    $legacy = Join-Path $root 'arnes_brain.py'
    if (Test-Path $legacy) { return $legacy }
    return $null
}
function Get-OsmaGraphCli {
    $root = Get-OsmaRoot
    if (-not $root) { return $null }
    $p = Join-Path $root 'osma-graph.ps1'
    if (Test-Path $p) { return $p }
    $legacy = Join-Path $root 'arnes-graph.ps1'
    if (Test-Path $legacy) { return $legacy }
    return $null
}