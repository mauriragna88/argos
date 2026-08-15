#Requires -Version 5.1
<#
.SYNOPSIS
OSMA MEMORY NOOP - stub de memoria cuando el motor OSMA NO esta instalado.

.DESCRIPTION
Absorbe cualquier llamada de memoria (init/save/recall/stats/aquest/atask/
checkpoint/experience/route/...) sin romper el harness. Avisa UNA vez por
proceso que OSMA no esta disponible y devuelve salida vacia (JSON de stats
minimo para no romper ConvertFrom-Json).

ARGOS funciona sin memoria (modo degradado); la memoria real se activa
instalando OSMA: osma/install.ps1 o `argos osma-install`.

.EXAMPLE
& osma-memory-noop.ps1 stats -Quiet
& osma-memory-noop.ps1 recall -Query "x" -Limit 5
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = '',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

# Avisar UNA vez por proceso (variable de sesion para no repetir en loops)
if (-not $script:OsmaNoopWarned -and -not $env:ARNES_OSMA_NOOP_QUIET) {
    $script:OsmaNoopWarned = $true
    Write-Host '  [!] OSMA no instalado: memoria desactivada (modo degradado).' -ForegroundColor Yellow
    Write-Host '      Instala la memoria: argos osma-install  (o: osma/install.ps1)' -ForegroundColor DarkGray
}

# Salida minima por comando para no romper parsers
switch ($Command) {
    'stats' { if ($Args -contains '-Quiet') { Write-Output '{"observations":0,"total":0}' } }
    # default: sin salida (recall/save/aquest/atask/etc devuelven vacio, no rompen el flujo)
}
