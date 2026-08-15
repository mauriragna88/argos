#Requires -Version 5.1
<#
.SYNOPSIS
ARNES PICKER - Selector con BUSCADOR INTEGRADO y agrupacion por proveedor (estilo opencode)

.DESCRIPTION
- Campo de busqueda ARRIBA: escribe directamente y filtra en vivo (no depende del layout).
- Lista agrupada por proveedor (NVIDIA (96), OpenAI (13)...) cuando no hay filtro.
- Flechas ↑/↓ para navegar, Enter para elegir, Esc limpia el filtro / cancela, Backspace edita.
- Modo no interactivo: devuelve el default (para automatizacion).

.EXAMPLE
$choice = .\argos-picker.ps1 -Title "Elige modelo para Vivi" -Options $models -DefaultIndex 3
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string[]]$Options,

    [int]$DefaultIndex = 0,

    [string]$Group = ''
)

$ErrorActionPreference = 'Stop'

# Sin opciones = salida vacia
if ($Options.Count -eq 0) {
    Write-Output ''
    exit 0
}

# Normalizar indice
if ($DefaultIndex -lt 0 -or $DefaultIndex -ge $Options.Count) { $DefaultIndex = 0 }
$selected = $DefaultIndex

# Detectar si estamos en consola interactiva
$interactive = $true
try {
    $null = [Console]::CursorVisible
} catch {
    $interactive = $false
}

if (-not $interactive) {
    # Modo no interactivo: devolver el default
    Write-Output $Options[$DefaultIndex]
    exit 0
}

# Entradas: proveedor + modelo, ordenadas (el indice default apunta a la lista ordenada)
$entries = @($Options | Sort-Object | ForEach-Object {
    $parts = $_ -split '/', 2
    [pscustomobject]@{ Provider = $parts[0]; Model = $_ }
})
$filter = ''

function Get-VisibleModels {
    if ([string]::IsNullOrWhiteSpace($filter)) {
        return @($entries | ForEach-Object { $_.Model })
    }
    return @($entries | Where-Object { $_.Model -match [regex]::Escape($filter) } | ForEach-Object { $_.Model })
}

function Get-VisibleEntries {
    if ([string]::IsNullOrWhiteSpace($filter)) { return $entries }
    return @($entries | Where-Object { $_.Model -match [regex]::Escape($filter) })
}

function Show-Picker {
    Clear-Host
    Write-Host ''
    Write-Host "  $Title" -ForegroundColor Cyan
    if ($Group) { Write-Host "  [$Group]" -ForegroundColor DarkGray }
    Write-Host ''
    Write-Host "  Buscar: $filter`_" -ForegroundColor White
    Write-Host '  ' + ('-' * 60) -ForegroundColor DarkGray

    $visible = Get-VisibleEntries
    if ($visible.Count -eq 0) {
        Write-Host '    (sin resultados para el filtro)' -ForegroundColor DarkGray
    } else {
        $grouped = [string]::IsNullOrWhiteSpace($filter)
        $windowSize = 18
        $startIdx = [Math]::Max(0, $selected - ($windowSize - 1))
        $itemIdx = 0
        $lastProvider = ''
        $printed = 0

        foreach ($e in $visible) {
            if ($itemIdx -lt $startIdx) { $itemIdx++; continue }
            if ($printed -ge $windowSize) { break }

            if ($grouped -and $e.Provider -ne $lastProvider) {
                $count = @($visible | Where-Object { $_.Provider -eq $e.Provider }).Count
                Write-Host ("  {0} ({1})" -f $e.Provider.ToUpper(), $count) -ForegroundColor DarkYellow
                $lastProvider = $e.Provider
            }
            if ($itemIdx -eq $selected) {
                Write-Host ("  > {0}" -f $e.Model) -ForegroundColor Red -NoNewline
                Write-Host '  <-' -ForegroundColor White
            } else {
                Write-Host ("    {0}" -f $e.Model) -ForegroundColor White
            }
            $itemIdx++
            $printed++
        }
        if ($visible.Count -gt $windowSize) {
            Write-Host ("    ... (" + $visible.Count + " modelos, position " + ($selected + 1) + "/" + $visible.Count + ")") -ForegroundColor DarkGray
        }
    }

    Write-Host ''
    Write-Host '  [↑/↓] mover  [escribir] buscar  [Enter] elegir  [Esc] limpiar/salir' -ForegroundColor DarkGray
}

Show-Picker

while ($true) {
    $ki = [Console]::ReadKey($true)

    if ($ki.Key -eq [ConsoleKey]::UpArrow) {
        if ($selected -gt 0) { $selected-- }
        Show-Picker
    }
    elseif ($ki.Key -eq [ConsoleKey]::DownArrow) {
        $v = Get-VisibleModels
        if ($selected -lt $v.Count - 1) { $selected++ }
        Show-Picker
    }
    elseif ($ki.Key -eq [ConsoleKey]::Enter) {
        Clear-Host
        $v = Get-VisibleModels
        if ($v.Count -eq 0) { Write-Output '' } else { Write-Output $v[$selected] }
        exit 0
    }
    elseif ($ki.Key -eq [ConsoleKey]::Escape) {
        if ($filter) {
            $filter = ''
            $selected = 0
            Show-Picker
        } else {
            Clear-Host
            Write-Output ''
            exit 130
        }
    }
    elseif ($ki.Key -eq [ConsoleKey]::Backspace) {
        if ($filter.Length -gt 0) {
            $filter = $filter.Substring(0, $filter.Length - 1)
            $v = Get-VisibleModels
            if ($selected -ge $v.Count) { $selected = [Math]::Max(0, $v.Count - 1) }
            Show-Picker
        }
    }
    else {
        # Cualquier otra tecla imprimible: FILTRA en vivo (busqueda arriba, como opencode)
        $c = $ki.KeyChar
        if ($c -ne "`0" -and -not [char]::IsControl($c)) {
            $filter += $c
            $selected = 0
            Show-Picker
        }
    }
}
