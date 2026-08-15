#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS THEME - gestion del tema visual del harness.

.DESCRIPTION
Persiste el tema elegido en `.arnes/config.json` (clave "theme").
Temas disponibles: atlas (rojo-negro), vivi (violeta), amarant (bronce),
eiko (magenta), auron (acero).

.EXAMPLE
.\cli\argos-theme.ps1 list
.\cli\argos-theme.ps1 show
.\cli\argos-theme.ps1 set -Name vivi
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('list', 'show', 'set')]
    [string]$Command,

    [string]$Name
)

$ErrorActionPreference = 'Stop'

$Themes = @{
    atlas   = 'Rojo y Negro (default)'
    vivi    = 'Violeta Mage'
    amarant = 'Bronce Monk'
    eiko    = 'Magenta Cleric'
    auron   = 'Acero Warden'
}

$WorkDir = (Get-Location).Path
$ArnesDir = Join-Path $WorkDir '.arnes'
$ConfigFile = Join-Path $ArnesDir 'config.json'

function Get-CurrentTheme {
    if (-not (Test-Path $ConfigFile)) { return 'atlas' }
    try {
        $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        if ($cfg.theme) { return [string]$cfg.theme }
    } catch { }
    return 'atlas'
}

switch ($Command) {
    'list' {
        Write-Host ''
        Write-Host '  ARNES ARGOS - TEMAS' -ForegroundColor Cyan
        $current = Get-CurrentTheme
        foreach ($k in $Themes.Keys | Sort-Object) {
            $mark = if ($k -eq $current) { ' *' } else { '  ' }
            Write-Host ("  {0} {1,-10} {2}" -f $mark, $k, $Themes[$k]) -ForegroundColor White
        }
        Write-Host ''
        Write-Host '  Uso: argos theme set <nombre>' -ForegroundColor DarkGray
        Write-Host ''
    }
    'show' {
        $current = Get-CurrentTheme
        Write-Host ("  Tema actual: {0} ({1})" -f $current, $Themes[$current]) -ForegroundColor Cyan
    }
    'set' {
        if (-not $Name -or -not $Themes.ContainsKey($Name.ToLower())) {
            Write-Host "  [!] Tema invalido. Usa: argos theme set <nombre>" -ForegroundColor Yellow
            Write-Host ("      Disponibles: {0}" -f (($Themes.Keys | Sort-Object) -join ', ')) -ForegroundColor Yellow
            exit 1
        }
        $name = $Name.ToLower()
        if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }
        $cfg = $null
        if (Test-Path $ConfigFile) {
            try { $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json } catch { }
        }
        if (-not $cfg) { $cfg = [pscustomobject]@{ } }
        $cfg | Add-Member -NotePropertyName 'theme' -NotePropertyValue $name -Force
        $cfg | ConvertTo-Json -Depth 8 | Set-Content -Path $ConfigFile -Encoding UTF8
        Write-Host ("  [OK] Tema cambiado a '{0}' ({1})" -f $name, $Themes[$name]) -ForegroundColor Green
    }
}
