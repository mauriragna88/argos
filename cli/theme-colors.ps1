#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS THEME COLORS - modulo compartido (dot-source) con los colores del tema activo.

.DESCRIPTION
Lee `.arnes/config.json` (clave "theme") para devolver la paleta de colores del
tema activo como hashtable. Si no existe config o no hay tema, usa el default
"atlas". Pensado para dot-source desde los scripts de UI del harness:

    . .\cli\theme-colors.ps1
    $theme = Get-ThemeColors
    Write-Host 'Titulo' -ForegroundColor $theme.Primary

.EXAMPLE
. .\cli\theme-colors.ps1
$theme = Get-ThemeColors
#>
$ErrorActionPreference = 'Stop'

# Paleta base por tema (nombres validos de ConsoleColor). Solo colores, sin logica.
$script:ThemePalettes = @{
    atlas   = @{ Primary = 'DarkRed';    Secondary = 'DarkGray';    Accent = 'Red';    Title = 'DarkRed' }
    vivi    = @{ Primary = 'Magenta';    Secondary = 'DarkMagenta'; Accent = 'Cyan';   Title = 'Magenta' }
    amarant = @{ Primary = 'DarkYellow'; Secondary = 'DarkGray';    Accent = 'Yellow'; Title = 'DarkYellow' }
    eiko    = @{ Primary = 'Magenta';    Secondary = 'DarkMagenta'; Accent = 'Green';  Title = 'Magenta' }
    auron   = @{ Primary = 'DarkCyan';   Secondary = 'Gray';        Accent = 'White';  Title = 'DarkCyan' }
}

<#
.SYNOPSIS
Devuelve la paleta del tema activo como hashtable.

.DESCRIPTION
Lee el tema de `.arnes/config.json` (clave "theme"). Si no hay config,
no hay clave o el nombre no existe, usa "atlas". Idempotente: siempre
devuelve las 7 claves (Primary, Secondary, Accent, Title, Success, Warning, Error).
#>
function Get-ThemeColors {
    $themeName = 'atlas'
    $configFile = Join-Path (Join-Path (Get-Location).Path '.arnes') 'config.json'

    if (Test-Path $configFile) {
        try {
            $cfg = Get-Content $configFile -Raw | ConvertFrom-Json
            if ($cfg.theme) { $themeName = [string]$cfg.theme }
        } catch { }
    }

    $base = $script:ThemePalettes[$themeName.ToLower()]
    if (-not $base) { $base = $script:ThemePalettes['atlas'] }

    return @{
        Primary   = $base.Primary
        Secondary = $base.Secondary
        Accent    = $base.Accent
        Title     = $base.Title
        Success   = 'Green'
        Warning   = 'Yellow'
        Error     = 'Red'
    }
}
