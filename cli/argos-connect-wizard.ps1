#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS CONNECT WIZARD - Asistente interactivo para conectar proveedores

.DESCRIPTION
Wizard con flechas (estilo /connect de OpenCode pero NUESTRO):
1. Lista proveedores conocidos (OpenAI OAuth, Claude OAuth, OpenCode Go, NVIDIA, B.AI...)
2. El usuario elige con flechas
3. Para API: pide la key (o nombre de variable de entorno)
4. Para OAuth: flujo REAL de autorizacion del plan via `opencode auth login`
   (abre la pagina de autorizacion del proveedor, guarda la sesion en auth.json y verifica)
5. Opcion de agregar proveedor custom

.EXAMPLE
.\argos-connect-wizard.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
# === RUTA GLOBAL: conexiones UNA VEZ por computadora ===
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
if (-not (Test-Path $GlobalConfigDir)) { New-Item -ItemType Directory -Path $GlobalConfigDir -Force | Out-Null }
$ConnPath = Join-Path $GlobalConfigDir 'connections.json'
$ProjectDir = (Get-Location).Path
$ArnesDir = Join-Path $ProjectDir '.arnes'
$Picker = Join-Path $PSScriptRoot 'argos-picker.ps1'
$ConnMgr = Join-Path $PSScriptRoot 'argos-connect.ps1'

# Forzar UTF-8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# Lectura segura (no interactivo: vacio en vez de crashear)
function Read-Input {
    param([string]$Prompt)
    try { return Read-Host $Prompt } catch { return '' }
}

# Asegurar que existe connections.json
& $ConnMgr init | Out-Null

function Show-Header {
    Write-Host ''
    Write-Host '  ╔══════════════════════════════════════════════════════════╗' -ForegroundColor DarkRed
    Write-Host '  ║   ARNES ARGOS - Conectar proveedores (nuestro /connect)  ║' -ForegroundColor White
    Write-Host '  ╚══════════════════════════════════════════════════════════╝' -ForegroundColor DarkRed
    Write-Host ''
}

function Get-Connections {
    if (Test-Path $ConnPath) { return Get-Content $ConnPath -Raw | ConvertFrom-Json }
    return $null
}

function Save-Connections {
    param($Data)
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $ConnPath -Encoding UTF8
}

# === Verificar sesion OAuth real en opencode (auth.json) ===
function Test-OpenCodeAuth {
    param([string]$ProviderId)
    $raw = @(& opencode auth list 2>&1)
    $line = @($raw | Where-Object { $_ -match [regex]::Escape($ProviderId) } | Select-Object -First 1)
    return ($line.Count -gt 0 -and $line[0] -match 'oauth|api')
}

# === MAIN ===
Show-Header

$data = Get-Connections
if (-not $data) {
    & $ConnMgr init | Out-Null
    $data = Get-Connections
}

# Build lista de opciones: [nombre] nombre legible (estado)
$options = @()
foreach ($p in $data.providers.PSObject.Properties) {
    $v = $p.Value
    $status = if ($v.connected) { '[CONECTADO]' } else { '[sin conectar]' }
    $options += ("{0} | {1} ({2}) {3}" -f $p.Name, $v.name, $v.type, $status)
}
$options += '--- Agregar proveedor custom ---'
$options += '--- Volver ---'

$choice = & $Picker -Title 'Elige un proveedor para conectar' -Options $options -Group 'ARNES ARGOS connect'
if ([string]::IsNullOrWhiteSpace($choice) -or $choice -like '*Volver*' -or $LASTEXITCODE -eq 130) {
    Write-Host '  Cancelado.' -ForegroundColor Yellow
    exit 0
}

if ($choice -like '*Agregar proveedor custom*') {
    Write-Host ''
    $cName = Read-Input '  Nombre del proveedor (ej: groq, mistral, ollama)'
    $cType = Read-Input '  Tipo [api/oauth] (default api)'
    if ([string]::IsNullOrWhiteSpace($cType)) { $cType = 'api' }
    $cUrl = Read-Input '  Base URL (ej: https://api.groq.com/v1)'
    $cDisplay = Read-Input '  Nombre legible (default = nombre)'
    if ([string]::IsNullOrWhiteSpace($cDisplay)) { $cDisplay = $cName }
    & $ConnMgr add -Name $cName -Type $cType -BaseUrl $cUrl -DisplayName $cDisplay
    Write-Host ''
    Write-Host '  Ahora configura la API key:' -ForegroundColor Yellow
    $cKey = Read-Input '  API key (o Enter para usar variable de entorno)'
    if ($cKey) {
        & $ConnMgr set-key -Name $cName -ApiKey $cKey
    } else {
        $cEnv = Read-Input '  Nombre de variable de entorno (ej: GROQ_API_KEY)'
        if ($cEnv) { & $ConnMgr set-key -Name $cName -KeyEnv $cEnv }
    }
    Write-Host '  [OK] Proveedor custom conectado.' -ForegroundColor Green
    exit 0
}

# Parsear nombre del choice: "nombre | ..."
$providerName = ($choice -split ' \| ')[0].Trim()

$provider = $data.providers.$providerName
if (-not $provider) { Write-Host "  [!] Proveedor '$providerName' no encontrado." -ForegroundColor Red; exit 1 }

Write-Host ''
Write-Host "  Conectando: $($provider.name) ($providerName)" -ForegroundColor Cyan

if ($provider.type -eq 'api') {
    $current = if ($provider.api_key) { 'key ya configurada' } else { 'sin key' }
    Write-Host "  Estado: $current" -ForegroundColor DarkGray
    Write-Host ''
    $keyInput = Read-Input '  API key (Enter = usar variable de entorno, Q = cancelar)'
    if ($keyInput -eq 'q' -or $keyInput -eq 'Q') { Write-Host '  Cancelado.'; exit 0 }
    if ($keyInput) {
        & $ConnMgr set-key -Name $providerName -ApiKey $keyInput
        Write-Host "  [OK] $providerName conectado con API key." -ForegroundColor Green
    } else {
        $envName = if ($provider.key_env) { $provider.key_env } else { Read-Input '  Nombre de variable de entorno (ej: NVIDIA_API_KEY)' }
        if (-not $envName) { Write-Host '  [!] Sin key ni env - no se conecto.' -ForegroundColor Yellow; exit 1 }
        $hasEnv = [bool](Get-Item "Env:$envName" -ErrorAction SilentlyContinue)
        & $ConnMgr set-key -Name $providerName -KeyEnv $envName
        if ($hasEnv) {
            Write-Host "  [OK] $providerName conectado via env:$envName" -ForegroundColor Green
        } else {
            Write-Host "  [OK] $providerName configurado para usar env:$envName (aun no definida en el sistema)" -ForegroundColor Yellow
        }
    }
} else {
    # OAuth - flujo REAL de autorizacion del plan (como Codex / Claude / opencode)
    # Mapeo de proveedor ARNES -> proveedor opencode
    $oauthProviderId = switch ($providerName) {
        'openai' { 'openai' }
        'claude' { 'anthropic' }
        default  { $null }
    }

    if ($oauthProviderId) {
        Write-Host ''
        Write-Host "  $($provider.name) usa OAuth del PLAN (ChatGPT Plus/Pro, Claude Pro/Max...)." -ForegroundColor White
        Write-Host '  El flujo real es como el de Codex/Claude/opencode:' -ForegroundColor DarkGray
        Write-Host '    1. Se abre el navegador con la pagina de AUTORIZACION' -ForegroundColor DarkGray
        Write-Host '    2. Autorizas con tu suscripcion' -ForegroundColor DarkGray
        Write-Host '    3. La sesion queda guardada y los agentes usan el plan' -ForegroundColor DarkGray
        Write-Host ''

        # 1) Ya hay sesion autorizada? (auth.json de opencode)
        if (Test-OpenCodeAuth -ProviderId $oauthProviderId) {
            Write-Host "  [OK] Ya tienes sesion autorizada para $($provider.name)." -ForegroundColor Green
            Write-Host '  Sesion guardada en ~/.local/share/opencode/auth.json' -ForegroundColor DarkGray
            $data = Get-Connections
            $data.providers.$providerName.connected = $true
            $data.updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            Save-Connections $data
            Write-Host "  [OK] $providerName conectado (OAuth verificado)." -ForegroundColor Green
        } else {
            Write-Host '  Aun no hay sesion autorizada.' -ForegroundColor Yellow
            $resp = Read-Input '  Iniciar autorizacion ahora? [Y/n]'
            if ($resp -eq '' -or $resp -eq 'y' -or $resp -eq 'Y') {
                Write-Host ''
                Write-Host '  Abriendo el flujo de autorizacion de opencode (elige tu metodo de plan):' -ForegroundColor Cyan
                Write-Host '    - OpenAI: "ChatGPT Plus/Pro" -> abre el navegador y autorizas' -ForegroundColor DarkGray
                Write-Host '    - Claude: "Claude Pro/Max" (con plugin) o API key' -ForegroundColor DarkGray
                Write-Host ''
                & opencode auth login -p $oauthProviderId
                Write-Host ''
                if (Test-OpenCodeAuth -ProviderId $oauthProviderId) {
                    $data = Get-Connections
                    $data.providers.$providerName.connected = $true
                    $data.updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                    Save-Connections $data
                    Write-Host "  [OK] $($provider.name) autorizado y conectado. Sesion guardada." -ForegroundColor Green
                } else {
                    Write-Host "  [!] No se completo la autorizacion de $($provider.name)." -ForegroundColor Yellow
                    Write-Host '  Intenta de nuevo con: opencode auth login -p <proveedor>' -ForegroundColor DarkGray
                }
            }
        }
    } else {
        # OAuth custom (sin mapeo a opencode): abrir el login del proveedor
        Write-Host ''
        Write-Host "  $($provider.name) es un OAuth custom sin flujo de plan integrado." -ForegroundColor White
        $resp = Read-Input '  Abrir el login del proveedor en el navegador? [Y/n]'
        if ($resp -eq '' -or $resp -eq 'y' -or $resp -eq 'Y') {
            $openUrl = if ($provider.login_url) { $provider.login_url } else { $provider.base_url }
            Write-Host "  Abriendo $openUrl en el navegador..." -ForegroundColor Cyan
            Start-Process $openUrl
            $done = Read-Input '  Cuando termines, escribe OK'
            if ($done -eq 'OK' -or $done -eq 'ok') {
                $data = Get-Connections
                $data.providers.$providerName.connected = $true
                $data.updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                Save-Connections $data
                Write-Host "  [OK] $providerName marcado como conectado (OAuth custom)." -ForegroundColor Green
            }
        }
    }
}

Write-Host ''
Write-Host '  Estado actual de tus conexiones:' -ForegroundColor Cyan
& $ConnMgr status
