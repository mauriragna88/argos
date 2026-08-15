#Requires -Version 5.1
<#
.SYNOPSIS
ATLAS SHELL - El command center del harness ARNES RPG

.DESCRIPTION
Punto de entrada unico del arnes. Muestra el banner ARNES, detecta proveedores,
lanza el wizard de modelos (si no hay config o se pide), y permite chatear con Atlas.

.EXAMPLE
.\atlas-shell.ps1          -> menu principal
.\atlas-shell.ps1 -Chat    -> ir directo al chat
.\atlas-shell.ps1 -Setup   -> forzar wizard de configuracion
#>
[CmdletBinding()]
param(
    [switch]$Chat,
    [switch]$Setup,
    [switch]$Status,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$QuestArgs
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'osma-resolve.ps1')
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$ArnesDir = Join-Path $Root '.arnes'
$ConfigPath = Join-Path $ArnesDir 'config.json'

# Forzar UTF-8
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

# === BANNER ARNES MAMALON ===
function Show-Banner {
    Write-Host ''
    Write-Host "      ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄" -ForegroundColor DarkRed
    Write-Host ''
    Write-Host "        █████╗ ██████╗ ██████╗  ██████╗ ███████╗" -ForegroundColor Red
    Write-Host "       ██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗██╔════╝" -ForegroundColor White
    Write-Host "       ███████║██████╔╝██║  ███╗██║   ██║███████╗" -ForegroundColor Red
    Write-Host "       ██╔══██║██╔══██╗██║   ██║██║   ██║╚════██║" -ForegroundColor White
    Write-Host "       ██║  ██║██║  ██║╚██████╔╝╚██████╔╝███████║" -ForegroundColor Red
    Write-Host "       ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝" -ForegroundColor White
    Write-Host ''
    Write-Host "      ╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkRed
    Write-Host "      ║   ARNES ARGOS - EL ORQUESTADOR RPG - LOS 100 OJOS   ║" -ForegroundColor White
    Write-Host "      ╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor DarkRed
    Write-Host ''
    Write-Host "      ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀" -ForegroundColor DarkRed
    Write-Host ''
}

# === DETECCION DE PROVEEDORES ===
function Show-Providers {
    Write-Host '  ▸ Detectando suscripciones...' -ForegroundColor DarkGray
    $hasOpenCode = [bool](Get-Command opencode -ErrorAction SilentlyContinue)
    if ($hasOpenCode) {
        $authRaw = @(cmd /c 'opencode auth list' 2>$null)
        if ($authRaw -match 'OpenCode Go') { Write-Host '    [OK] OpenCode Go  ($10/mes - api)' -ForegroundColor Green } else { Write-Host '    [OK] OpenCode Go  (disponible)' -ForegroundColor Green }
        if ($authRaw -match 'OpenAI') { Write-Host '    [OK] OpenAI       (cuenta GPT - OAuth)' -ForegroundColor Green }
        if ($authRaw -match 'NVIDIA|nvidia') { Write-Host '    [OK] NVIDIA       (API gratis)' -ForegroundColor Green }
        if ($authRaw -match 'MiniMax') { Write-Host '    [OK] MiniMax      (token plan)' -ForegroundColor Green }
    } else {
        Write-Host '    [!] opencode no encontrado en PATH' -ForegroundColor Yellow
    }
    Write-Host ''
}

# === WIZARD DE MODELOS (picker con flechas) ===
function Show-ModelWizard {
    Write-Host '  ▸ CONFIGURACION DE MODELOS' -ForegroundColor Cyan
    Write-Host '  ▸ Selecciona el modelo para cada agente (flechas arriba/abajo, Enter para elegir)' -ForegroundColor White
    Write-Host ''

    $models = @()
    try {
        $raw = @(cmd /c 'opencode models' 2>$null)
        $models = @($raw | Where-Object { $_ -match '^[\w-]+/.+' } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)
    } catch {}
    if ($models.Count -eq 0) {
        Write-Host '  [!] No se pudo obtener el catalogo de modelos. Usa: opencode models' -ForegroundColor Yellow
        return $false
    }

    $agents = @(
        @{ key = 'mage';      name = 'Vivi (Frontend)' },
        @{ key = 'paladin';   name = 'Ansem (Backend)' },
        @{ key = 'rogue';     name = 'Kuja (QA)' },
        @{ key = 'cleric';    name = 'Eiko (DevOps)' },
        @{ key = 'monk';      name = 'Amarant (Arquitectura)' },
        @{ key = 'ranger';    name = 'Eremez (Research)' },
        @{ key = 'auron';     name = 'Auron (Seguridad)' },
        @{ key = 'bran';      name = 'Bran (Analista)' },
        @{ key = 'quina';     name = 'Quina (Tokens)' },
        @{ key = 'tidus';     name = 'Tidus (Infra)' },
        @{ key = 'bard';      name = 'Bard (Mejora)' },
        @{ key = 'ragnarok';  name = 'Ragnarok (Compras)' }
    )

    $cfg = $null
    if (Test-Path $ConfigPath) { $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json }

    $picker = Join-Path $PSScriptRoot 'argos-picker.ps1'
    $updates = @{}

    foreach ($a in $agents) {
        $current = ''
        if ($cfg -and $cfg.characters.($a.key)) {
            $current = $cfg.characters.($a.key).model_opencode
        }
        $defaultIdx = 0
        if ($current) {
            $found = [Array]::IndexOf($models, $current)
            if ($found -ge 0) { $defaultIdx = $found }
        }
        Write-Host ''
        Write-Host "  Asignando modelo a: $($a.name)" -ForegroundColor Yellow
        $chosen = & $picker -Title "Modelo para $($a.name)" -Options $models -DefaultIndex $defaultIdx -Group "Catalogo: $($models.Count) modelos"
        if ($LASTEXITCODE -eq 130 -or [string]::IsNullOrWhiteSpace($chosen)) {
            Write-Host '  Wizard cancelado. Los cambios no se aplicaron.' -ForegroundColor Yellow
            return $false
        }
        $updates[$a.key] = $chosen
        Write-Host "  OK $($a.name) -> $chosen" -ForegroundColor Green
    }

    if ($cfg -and $cfg.characters) {
        foreach ($k in $updates.Keys) {
            if ($cfg.characters.$k) {
                $cfg.characters.$k | Add-Member -NotePropertyName 'model_opencode' -NotePropertyValue $updates[$k] -Force
            }
        }
        $cfg | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8
        Write-Host ''
        Write-Host '  [OK] Configuracion guardada en .arnes/config.json' -ForegroundColor Green
        Write-Host '  [OK] El harness usara estos modelos automaticamente' -ForegroundColor Green
        return $true
    }
    Write-Host '  [!] No se pudo guardar (config.json no leible).' -ForegroundColor Yellow
    return $false
}

# === MENU PRINCIPAL ===
function Show-Menu {
    Clear-Host
    Show-Banner
    Write-Host '  ▸ Estado del entorno:' -ForegroundColor Cyan
    Write-Host '    [OK] Harness RPG listo - 16 agentes - memoria + grafo + SDD + FDD' -ForegroundColor Green
    Write-Host ''
    Show-Providers

    Write-Host '  ================================================' -ForegroundColor DarkGray
    Write-Host '  [1] Ir al chat con Atlas' -ForegroundColor White
    Write-Host '  [2] Configurar modelos (wizard)' -ForegroundColor White
    Write-Host '  [3] Estado de memoria' -ForegroundColor White
    Write-Host '  [4] Health-check (Tidus)' -ForegroundColor White
    Write-Host '  [5] Novedades (Ragnarok)' -ForegroundColor White
    Write-Host '  [Q] Salir' -ForegroundColor White
    Write-Host '  ================================================' -ForegroundColor DarkGray
    Write-Host ''

    $choice = Read-Host '  Selecciona una opcion'
    switch ($choice) {
        '1' { Launch-Chat }
        '2' { Show-ModelWizard; Read-Host '  Enter para volver'; Show-Menu }
        '3' { Show-MemoryStatus; Read-Host '  Enter para volver'; Show-Menu }
        '4' { Show-TidusCheck; Read-Host '  Enter para volver'; Show-Menu }
        '5' { Show-RagnarokInfo; Read-Host '  Enter para volver'; Show-Menu }
        'q' { Write-Host '  Adios, jugador. Rojo y negro.'; exit 0 }
        'Q' { Write-Host '  Adios, jugador. Rojo y negro.'; exit 0 }
        default { Show-Menu }
    }
}

function Launch-Chat {
    Write-Host ''
    Write-Host '  ▸ Lanzando el chat nativo de ARNES ARGOS...' -ForegroundColor Cyan
    Write-Host '  ▸ (prompt propio, sin TUI de OpenCode - el motor trabaja por detras)' -ForegroundColor DarkGray
    Write-Host ''
    $chat = Join-Path $PSScriptRoot 'argos-chat.ps1'
    & $chat
}

function Show-MemoryStatus {
    Write-Host ''
    Write-Host '  ▸ Estado de memoria (ARNES BRAIN):' -ForegroundColor Cyan
    $mem = (Get-OsmaMemoryCli)
    & $mem stats
}

function Show-TidusCheck {
    Write-Host ''
    Write-Host '  ▸ Health-check (TIDUS):' -ForegroundColor Cyan
    $disk = Get-PSDrive C | Select-Object -First 1
    $freeGB = [Math]::Round($disk.Free / 1GB, 1)
    $os = Get-CimInstance Win32_OperatingSystem
    $ramFree = [Math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $ramTotal = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    Write-Host ("  Disco: {0}GB libres" -f $freeGB) -ForegroundColor Green
    Write-Host ("  RAM:   {0}GB libres de {1}GB" -f $ramFree, $ramTotal) -ForegroundColor Green
    Write-Host ("  CPU:   {0}%" -f [Math]::Round($cpu, 0)) -ForegroundColor Green
    Write-Host '  Semaforo: GREEN' -ForegroundColor Green
}

function Show-RagnarokInfo {
    Write-Host ''
    Write-Host '  ▸ Novedades (RAGNAROK):' -ForegroundColor Cyan
    Write-Host '  [OK] Skills web: superpowers (258K), ui-ux-pro-max (79K), taste-skill (66K)' -ForegroundColor Green
    Write-Host '  [OK] Metodologias: SDD, FDD, TDD, Knowledge Graph, ADR' -ForegroundColor Green
    Write-Host '  [OK] Proveedores: OpenCode Go + OpenAI (OAuth) + NVIDIA (gratis)' -ForegroundColor Green
    Write-Host '  > Proximo scan: cuando pidas "ragnarok busca novedades"' -ForegroundColor DarkGray
}

# === INICIO ===
Show-Banner

if (-not (Test-Path $ConfigPath)) {
    Write-Host '  ▸ Primera vez detectada - configuraremos los modelos.' -ForegroundColor Yellow
    Show-Providers
    Show-ModelWizard
} elseif ($Setup) {
    Write-Host '  ▸ Reconfiguracion solicitada.' -ForegroundColor Yellow
    Show-ModelWizard
}

if ($Chat) {
    Launch-Chat
} elseif ($Status) {
    Show-MemoryStatus
} elseif ($QuestArgs.Count -gt 0) {
    # atlas quest "..." - quest directo via chat nativo
    $questText = $QuestArgs -join ' '
    $chat = Join-Path $PSScriptRoot 'argos-chat.ps1'
    & $chat -Quest $questText
} else {
    Show-Menu
}
