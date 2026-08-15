#Requires -Version 5.1
<#
.SYNOPSIS
ARNES CODE - Modo CODING nativo: el agente lee, crea y edita archivos en vivo (como Claude Code/Codex)

.DESCRIPTION
Loop agente+herramientas con el motor propio (argos-engine.ps1), sin opencode:
- Herramientas: list_dir, read_file, write_file, edit_file, run_command, search
- El agente decide que herramienta usar, ejecuta, observa el resultado y repite hasta terminar
- UI llamativa: cada accion se muestra en vivo con colores, diffs en ediciones, uso de tokens
- Seguridad: las herramientas operan dentro de la carpeta del proyecto

.EXAMPLE
.\argos-code.ps1 -Quest "crea un archivo README.md con 3 secciones"
.\argos-code.ps1 -Quest "agrega una funcion validarEmail en utils.js" -Agent vivi
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Quest,

    [string]$Agent = 'ansem',

    [int]$MaxSteps = 15,

    [switch]$Auto,   # -Auto: ejecuta sin pedir permiso (para automatizacion)

    [string]$SystemExtra = ''   # contrato extra que se anade al system prompt (party autonoma)
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'osma-resolve.ps1')
$script:auto = $Auto

# === Puerta de permiso: alerta antes de tocar archivos / ejecutar comandos ===
function Confirm-Action {
    param([string]$Action, [string]$Detail)
    if ($script:auto) { return $true }
    $interactive = $true
    try { $null = [Console]::CursorVisible } catch { $interactive = $false }
    if (-not $interactive) { return $true }
    $resp = Read-Input ("  [PERMISO] $Action $Detail ? [Y/n] ")
    return ($resp -eq '' -or $resp -match '^[YySs]')
}
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Engine = Join-Path $PSScriptRoot 'argos-engine.ps1'
$WorkDir = (Get-Location).Path
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
$ModelsPath = Join-Path $GlobalConfigDir 'agent-models.json'

# ============ AUTO-INIT (el entorno se inicializa solo) ============
$projArnes = Join-Path $WorkDir '.arnes'
$gConn = Join-Path $env:USERPROFILE '.config\arnes\connections.json'
$gModels = Join-Path $env:USERPROFILE '.config\arnes\agent-models.json'
$db = Join-Path (Get-Location) '.arnes\arnes.db'
$missing = @()
if (-not (Test-Path $projArnes)) { $missing += 'entorno del proyecto (.arnes)' }
if (-not (Test-Path $gConn)) { $missing += 'conexiones globales' }
if (-not (Test-Path $gModels)) { $missing += 'modelos por agente' }
if (-not (Test-Path $db)) { $missing += 'memoria (arnes.db)' }
if ($missing.Count -gt 0) {
    Write-Host ("  ▸ [AUTO-INIT] inicializando: " + ($missing -join ', ')) -ForegroundColor Yellow
    if (-not (Test-Path $projArnes)) { New-Item -ItemType Directory -Path $projArnes -Force | Out-Null }
    & (Join-Path $PSScriptRoot 'argos-connect.ps1') init | Out-Null
    if (-not (Test-Path $gModels)) { & (Join-Path $PSScriptRoot 'argos.ps1') init 2>&1 | Out-Null }
    if (-not (Test-Path $db)) {
        $mem = (Get-OsmaMemoryCli)
        if (Test-Path $mem) { & $mem init 2>&1 | Out-Null }
    }
    Write-Host '  ▸ [AUTO-INIT] entorno listo (contexto, conexiones, modelos y memoria).' -ForegroundColor Green
}

# ============ Modelo del agente ============
$model = ''
if (Test-Path $ModelsPath) {
    $raw = Get-Content $ModelsPath -Raw | ConvertFrom-Json
    if ($raw.agents.$Agent) { $model = [string]$raw.agents.$Agent }
}
if (-not $model) { $model = 'opencode-go/gpt-5.6-luna' }

# ============ Persona del agente (con reparacion de mojibake) ============
function Get-AgentPrompt {
    param([string]$Key)
    $candidates = @()
    $candidates += (Join-Path $Root "core\classes\$Key.agent.md")
    $candidates += (Join-Path $Root "core\auditors\$Key.agent.md")
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $text = [System.IO.File]::ReadAllText($c)
            try {
                $cp1252 = [System.Text.Encoding]::GetEncoding(1252)
                $utf8 = New-Object System.Text.UTF8Encoding($false)
                $fixed = foreach ($line in ($text -split "`n")) {
                    try {
                        $cand = $utf8.GetString($cp1252.GetBytes($line))
                        $chk = $cp1252.GetString($utf8.GetBytes($cand))
                        if ($chk -eq $line -and $cand -ne $line) { $cand } else { $line }
                    } catch { $line }
                }
                $text = $fixed -join "`n"
            } catch {}
            return $text.Trim()
        }
    }
    return ''
}
$persona = Get-AgentPrompt $Agent

$system = @"
$persona

[MODO CODING ARNES - reglas]
- Trabajas en el proyecto: $WorkDir
- Usa las herramientas disponibles para leer, crear y editar archivos REALES.
- Nunca digas 'no puedo' ni pongas 'TODO' o placeholders: entrega el codigo/archivo real.
- Para editar usa edit_file (reemplazo exacto) o write_file (crear/sobrescribir).
- Lee antes de editar si no conoces el archivo. Lista el directorio si necesitas orientarte.
- Si necesitas verificar algo, usa run_command (ej: npm test, node, python).
- REGLA CRITICA: usa UNA herramienta por mensaje. NUNCA llames varias herramientas a la vez.
- Al terminar, responde con un resumen corto de lo que hiciste y que archivos tocaste.
"@

# Contrato extra (party autonoma): se anade al system para que el agente ejecute la tarea real
if ($SystemExtra) { $system += "`n`n" + $SystemExtra }

# ============ Definiciones de herramientas ============
$tools = @(
    @{ type = 'function'; function = @{ name = 'list_dir'; description = 'Lista el contenido de un directorio del proyecto'; parameters = @{ type = 'object'; properties = @{ path = @{ type = 'string'; description = 'Ruta RELATIVA al proyecto (nunca usar rutas absolutas con barras invertidas)' } }; required = @('path') } } },
    @{ type = 'function'; function = @{ name = 'read_file'; description = 'Lee el contenido de un archivo'; parameters = @{ type = 'object'; properties = @{ path = @{ type = 'string' } }; required = @('path') } } },
    @{ type = 'function'; function = @{ name = 'write_file'; description = 'Crea o sobrescribe un archivo con contenido completo'; parameters = @{ type = 'object'; properties = @{ path = @{ type = 'string' }; content = @{ type = 'string' } }; required = @('path', 'content') } } },
    @{ type = 'function'; function = @{ name = 'edit_file'; description = 'Reemplaza un bloque de texto exacto dentro de un archivo'; parameters = @{ type = 'object'; properties = @{ path = @{ type = 'string' }; old_string = @{ type = 'string' }; new_string = @{ type = 'string' } }; required = @('path', 'old_string', 'new_string') } } },
    @{ type = 'function'; function = @{ name = 'run_command'; description = 'Ejecuta un comando en la terminal (dentro del proyecto)'; parameters = @{ type = 'object'; properties = @{ command = @{ type = 'string' } }; required = @('command') } } },
    @{ type = 'function'; function = @{ name = 'search'; description = 'Busca texto (regex) en archivos del proyecto'; parameters = @{ type = 'object'; properties = @{ pattern = @{ type = 'string' }; path = @{ type = 'string'; description = 'Directorio donde buscar (default: proyecto)' } }; required = @('pattern') } } }
)

# ============ Ejecutores de herramientas ============
function Resolve-SafePath {
    param([string]$Path)
    if (-not $Path) { return $WorkDir }
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $WorkDir $Path)
}

function Invoke-Tool {
    param([string]$Name, $ArgsObj)
    try {
        switch ($Name) {
            'list_dir' {
                $p = Resolve-SafePath $ArgsObj.path
                if (-not (Test-Path $p)) { return "DIRECTORIO NO EXISTE: $p" }
                $items = Get-ChildItem $p -ErrorAction Stop | Select-Object -First 400
                return (($items | ForEach-Object { if ($_.PSIsContainer) { "[DIR] $($_.Name)" } else { "      $($_.Name) ($($_.Length)b)" } }) -join "`n")
            }
            'read_file' {
                $p = Resolve-SafePath $ArgsObj.path
                if (-not (Test-Path $p)) { return "ARCHIVO NO EXISTE: $p" }
                $content = [System.IO.File]::ReadAllText($p)
                if ($content.Length -gt 40000) { $content = $content.Substring(0, 40000) + "`n...[corte por contexto]" }
                return $content
            }
            'write_file' {
                if (-not (Confirm-Action 'Escribir archivo' $ArgsObj.path)) { return "ACCION DENEGADA por el usuario: write_file $($ArgsObj.path)" }
                $p = Resolve-SafePath $ArgsObj.path
                $dir = Split-Path $p -Parent
                if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                [System.IO.File]::WriteAllText($p, [string]$ArgsObj.content, (New-Object System.Text.UTF8Encoding($false)))
                return "OK archivo escrito: $p ($($ArgsObj.content.Length) chars)"
            }
            'edit_file' {
                if (-not (Confirm-Action 'Editar archivo' $ArgsObj.path)) { return "ACCION DENEGADA por el usuario: edit_file $($ArgsObj.path)" }
                $p = Resolve-SafePath $ArgsObj.path
                if (-not (Test-Path $p)) { return "ARCHIVO NO EXISTE: $p" }
                $content = [System.IO.File]::ReadAllText($p)
                $old = [string]$ArgsObj.old_string
                $new = [string]$ArgsObj.new_string
                if (-not $content.Contains($old)) { return "ERROR: old_string no encontrado en $p" }
                $content = $content.Replace($old, $new)
                [System.IO.File]::WriteAllText($p, $content, (New-Object System.Text.UTF8Encoding($false)))
                return "OK editado: $p ($($old.Length) chars reemplazados)"
            }
            'run_command' {
                if (-not (Confirm-Action 'Ejecutar' $ArgsObj.command)) { return "ACCION DENEGADA por el usuario: run_command $($ArgsObj.command)" }
                $cmd = [string]$ArgsObj.command
                $prevEap = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                $out = @()
                try {
                    $out = @(& cmd /c $cmd 2>&1)
                    if ($LASTEXITCODE -ne 0) { $out += "`n[exit=$LASTEXITCODE]" }
                } catch { $out = @("ERROR: " + $_.Exception.Message) }
                $ErrorActionPreference = $prevEap
                $text = ($out -join "`n")
                if ($text.Length -gt 20000) { $text = $text.Substring(0, 20000) + "`n...[corte por contexto]" }
                return $text
            }
            'search' {
                $pat = [string]$ArgsObj.pattern
                $dir = if ($ArgsObj.path) { Resolve-SafePath $ArgsObj.path } else { $WorkDir }
                $hits = @()
                try {
                    $hits = @(rg -n --no-heading $pat $dir -g '!node_modules' -g '!.git' -g '!*.db' 2>$null | Select-Object -First 40)
                } catch {}
                if ($hits.Count -eq 0) { return "sin coincidencias para: $pat" }
                return ($hits -join "`n")
            }
            default { return "HERRAMIENTA DESCONOCIDA: $Name" }
        }
    } catch {
        return "ERROR EJECUTANDO $Name : $($_.Exception.Message)"
    }
}

# ============ Banner ============
Write-Host ''
Write-Host ("  ╔══════════════════════════════════════════════════════════════╗") -ForegroundColor DarkRed
Write-Host ("  ║   ARNES CODING - {0,-12} trabaja en vivo   ║" -f $Agent.ToUpper()) -ForegroundColor White
Write-Host '  ╚══════════════════════════════════════════════════════════════╝' -ForegroundColor DarkRed
Write-Host ''
Write-Host ("  ▸ Quest: $Quest") -ForegroundColor Yellow
Write-Host ("  ▸ Agente: $Agent | Modelo: $model | Carpeta: $WorkDir") -ForegroundColor DarkGray
Write-Host ''

# ============ LOOP agente + herramientas ============
$session = @()
$toolHistory = @()
$totalTokens = 0
$step = 0
$final = ''

while ($step -lt $MaxSteps) {
    $step++
    Write-Host ("  ── paso {0}/{1} ──" -f $step, $MaxSteps) -ForegroundColor DarkCyan

    $msg = if ($step -eq 1) { $Quest } else { '' }
    $r = & $Engine -Model $model -System $system -Session $session -ToolHistory $toolHistory -Message $msg -Tools $tools -MaxTokens 16000

    # Mitigacion del 400 ocasional del proveedor (zen/go con historial de tools):
    # un reintento con contexto reducido (sin historial) pidiendo terminar la tarea
    if (-not $r.ok -and $step -gt 1 -and -not $script:codeRetried) {
        $script:codeRetried = $true
        Write-Host ('  ↻ error del proveedor ({0}) - reintento con contexto reducido...' -f $r.error) -ForegroundColor Yellow
        $r = & $Engine -Model $model -System $system -Message ("Continua la tarea en curso. Resume brevemente que hiciste y termina respondiendo: STATUS: PASS o FAIL + SUMMARY + FILES_CHANGED.") -Tools $tools -MaxTokens 4000
    }

    if (-not $r.ok) {
        Write-Host ("  [!] " + $r.error) -ForegroundColor Yellow
        break
    }
    if ($r.usage) { $totalTokens += $r.usage.total_tokens }

    if ($r.tool_calls -and $r.tool_calls.Count -gt 0) {
        # Salvaguarda: el endpoint zen/go rechaza VARIOS tool_calls en un mensaje.
        # Si el modelo pide varios, ejecutamos solo el primero; el resto lo redecide en el siguiente paso.
        $calls = @($r.tool_calls)
        if ($calls.Count -gt 1) {
            Write-Host ("  ⚠ el modelo pidio {0} herramientas; se ejecutan de una en una" -f $calls.Count) -ForegroundColor Yellow
            $calls = @($calls[0])
        }
        $session += @{ role = 'assistant'; content = $r.reply; tool_calls = $calls }
        $toolHistory = @()
        foreach ($tc in $calls) {
            $name = $tc.function.name
            $args = @{}
            try { $args = $tc.function.arguments | ConvertFrom-Json } catch {}
            $argsSummary = ($args | ConvertTo-Json -Compress -Depth 3)
            if ($argsSummary.Length -gt 100) { $argsSummary = $argsSummary.Substring(0, 100) + '...' }
            Write-Host ("  ⚡ {0} {1}" -f $name, $argsSummary) -ForegroundColor Magenta
            $result = Invoke-Tool $name $args
            $preview = $result
            if ($preview.Length -gt 140) { $preview = $preview.Substring(0, 140) + '...' }
            Write-Host ("     ↳ {0}" -f $preview) -ForegroundColor DarkGray
            $toolHistory += @{ role = 'tool'; tool_call_id = $tc.id; content = $result }
        }
        continue
    }

    # Respuesta final del agente
    $final = $r.reply
    Write-Host ''
    Write-Host "  ── RESULTADO FINAL ──" -ForegroundColor Green
    Write-Host ''
    Write-Host "  $final" -ForegroundColor White
    break
}

if (-not $final) { Write-Host '  [!] El agente no entrego respuesta final.' -ForegroundColor Yellow }

Write-Host ''
Write-Host ("  ═══════════════════════════════════════════") -ForegroundColor Cyan
Write-Host ("  CODING COMPLETO | pasos: {0} | tokens: {1}" -f $step, $totalTokens) -ForegroundColor Green
Write-Host ("  Agente: {0} | modelo: {1}" -f $Agent, $model) -ForegroundColor DarkGray
Write-Host '  ═══════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''

# Resultado estructurado por el PIPELINE (capturable por argos-party)
Write-Output ("[ARGOS_TASK_RESULT]`n" + $final)
