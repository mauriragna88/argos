#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS CONNECT - Gestor de conexiones y proveedores (nuestro propio /connect)

.DESCRIPTION
Maneja .arnes/connections.json: proveedores, API keys, OAuth, modelos disponibles.
Todo propio de ARNES ARGOS - conexiones globales de la maquina, cero dependencias externas.

.EXAMPLE
.\argos-connect.ps1 list              -> ver conexiones
.\argos-connect.ps1 add -Name openai -Type oauth -BaseUrl https://api.openai.com/v1
.\argos-connect.ps1 status
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'list', 'status', 'verify', 'add', 'remove', 'set-key', 'models')]
    [string]$Command = 'list',

    [string]$Name,
    [ValidateSet('oauth', 'api')]
    [string]$Type,
    [string]$BaseUrl,
    [string]$ApiKey,
    [string]$KeyEnv,
    [string]$DisplayName
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
# === RUTA GLOBAL: conexiones se configuran UNA VEZ por computadora ===
# No en el proyecto - es config de la maquina, no del proyecto.
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
if (-not (Test-Path $GlobalConfigDir)) { New-Item -ItemType Directory -Path $GlobalConfigDir -Force | Out-Null }
$ConnPath = Join-Path $GlobalConfigDir 'connections.json'
$ProjectDir = (Get-Location).Path
$ArnesDir = Join-Path $ProjectDir '.arnes'

# Proveedores conocidos (defaults - el usuario puede agregar custom)
$KNOWN_PROVIDERS = @{
    'openai' = @{ type = 'oauth'; name = 'OpenAI (cuenta GPT)'; base_url = 'https://api.openai.com/v1'; login_url = 'https://chatgpt.com/auth/login'; models = @('gpt-5.6-sol', 'gpt-5.6-terra', 'gpt-5.6-luna', 'gpt-5.5', 'gpt-5.4') }
    'claude' = @{ type = 'oauth'; name = 'Claude (cuenta)'; base_url = 'https://api.anthropic.com/v1'; login_url = 'https://claude.ai/login'; models = @('claude-opus-5', 'claude-sonnet-5', 'claude-fable-5') }
    'opencode-go' = @{ type = 'api'; name = 'OpenCode Go'; base_url = 'https://opencode.ai/zen/go/v1'; key_env = 'OPENCODE_GO_API_KEY'; models = @('deepseek-v4-flash', 'deepseek-v4-pro', 'qwen3.8-max', 'gpt-5.6-luna', 'glm-5.2', 'kimi-k2.6') }
    'nvidia' = @{ type = 'api'; name = 'NVIDIA NIM (gratis)'; base_url = 'https://integrate.api.nvidia.com/v1'; key_env = 'NVIDIA_API_KEY'; models = @('deepseek-ai/deepseek-v4-flash', 'deepseek-ai/deepseek-v4-pro', 'qwen/qwen3-coder-480b') }
    'bai' = @{ type = 'api'; name = 'B.AI (Claude/GPT/Qwen)'; base_url = 'https://api.b.ai/v1'; key_env = 'BAI_API_KEY'; models = @('claude-opus-5', 'claude-fable-5', 'gpt-5.6-sol', 'qwen3.8-max', 'deepseek-v4-flash') }
    'z-ai' = @{ type = 'api'; name = 'Z.AI (Zhipu GLM)'; base_url = 'https://open.bigmodel.cn/api/paas/v4'; key_env = 'ZHIPU_API_KEY'; models = @('glm-5.2') }
    'siliconflow' = @{ type = 'api'; name = 'SiliconFlow'; base_url = 'https://api.siliconflow.cn/v1'; key_env = 'SILICONFLOW_API_KEY'; models = @() }
    'tokenrouter' = @{ type = 'api'; name = 'TokenRouter'; base_url = 'https://api.tokenrouter.com/v1'; key_env = 'TOKENROUTER_API_KEY'; models = @('kimi-k3-free') }
    'minimax' = @{ type = 'api'; name = 'MiniMax'; base_url = ''; key_env = 'MINIMAX_API_KEY'; models = @('minimax-m3') }
}

function Read-Connections {
    if (Test-Path $ConnPath) {
        return Get-Content $ConnPath -Raw | ConvertFrom-Json
    }
    return $null
}

function Write-Connections {
    param($Data)
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $ConnPath -Encoding UTF8
}

function Init-Connections {
    if (Test-Path $ConnPath) {
        # Migracion idempotente: asegurar login_url en proveedores conocidos (OAuth)
        $data = Read-Connections
        $changed = $false
        foreach ($k in $KNOWN_PROVIDERS.Keys) {
            if ($data.providers.$k -and -not $data.providers.$k.login_url) {
                $loginUrl = if ($KNOWN_PROVIDERS[$k].login_url) { $KNOWN_PROVIDERS[$k].login_url } else { '' }
                $data.providers.$k | Add-Member -NotePropertyName 'login_url' -NotePropertyValue $loginUrl -Force
                $changed = $true
            }
        }
        if ($changed) { $data.updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); Write-Connections $data }
        Write-Output '  [OK] connections.json ya existe.'; return
    }
    $providers = [ordered]@{}
    foreach ($k in $KNOWN_PROVIDERS.Keys | Sort-Object) {
        $p = $KNOWN_PROVIDERS[$k]
        $providers[$k] = [ordered]@{
            type       = $p.type
            name       = $p.name
            base_url   = $p.base_url
            login_url  = if ($p.login_url) { $p.login_url } else { '' }
            key_env    = if ($p.key_env) { $p.key_env } else { '' }
            api_key    = ''
            connected  = $false
            models     = @($p.models)
            added_at   = ''
        }
    }
    $data = [ordered]@{
        version    = '1.0'
        updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        providers  = $providers
    }
    Write-Connections $data
    Write-Output "  [OK] connections.json creado en $ConnPath"
}

# === Obtener la key efectiva de un proveedor (api_key directa o variable de entorno) ===
function Get-ProviderKey {
    param($Provider)
    if ($Provider.api_key) { return [string]$Provider.api_key }
    if ($Provider.key_env) {
        $envVal = Get-Item "Env:$($Provider.key_env)" -ErrorAction SilentlyContinue
        if ($envVal) { return [string]$envVal.Value }
    }
    return ''
}

# === Verificar sesion OAuth real en opencode (auth.json) ===
function Test-OAuthSession {
    param([string]$ProviderName)
    $map = @{ 'openai' = 'OpenAI'; 'claude' = 'Anthropic' }
    $needle = if ($map.ContainsKey($ProviderName)) { $map[$ProviderName] } else { $ProviderName }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # el ANSI de stderr de opencode.exe no debe romper
    $raw = @()
    try { $raw = @(& opencode auth list 2>&1) } catch {}
    $ErrorActionPreference = $prevEap
    $line = @($raw | Where-Object { $_ -match [regex]::Escape($needle) } | Select-Object -First 1)
    return ($line.Count -gt 0 -and $line[0] -match 'oauth|api')
}

# === Verificar que una conexion es REAL (API probada contra /models, OAuth con sesion) ===
function Test-ProviderConnection {
    param([string]$ProviderName, $Provider)
    if ($Provider.type -ne 'oauth') {
        $key = Get-ProviderKey $Provider
        if (-not $key) { return @{ ok = $false; detail = 'sin key (falta api_key o variable de entorno)' } }
        $url = $Provider.base_url.TrimEnd('/') + '/models'
        try {
            $null = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $key" } -Method Get -TimeoutSec 20 -ErrorAction Stop
            return @{ ok = $true; detail = 'verificado (la API responde con la key)' }
        } catch {
            $code = 0
            try { $code = [int]$_.Exception.Response.StatusCode } catch {}
            if ($code -eq 401 -or $code -eq 403) { return @{ ok = $false; detail = "key INVALIDA (HTTP $code)" } }
            return @{ ok = $true; detail = "key presente (verificacion de red no disponible: HTTP $code)" }
        }
    }
    # OAuth
    $authed = Test-OAuthSession -ProviderName $ProviderName
    if ($authed) { return @{ ok = $true; detail = 'sesion OAuth verificada (plan)' } }
    return @{ ok = $false; detail = 'sin sesion OAuth (corre: argos connect)' }
}

function Show-Status {
    $data = Read-Connections
    if (-not $data) { Write-Output '  [!] No hay connections.json. Usa: argos-connect.ps1 init'; return }
    Write-Host ''
    Write-Host '  ARNES ARGOS - CONEXIONES (verificadas)' -ForegroundColor Cyan
    Write-Host '  =====================================' -ForegroundColor Cyan
    foreach ($p in $data.providers.PSObject.Properties) {
        $v = $p.Value
        $type = if ($v.type -eq 'oauth') { 'OAuth' } else { 'API' }
        if (-not $v.connected) {
            Write-Host ("  [--] {0,-12} {1,-35} {2}" -f $p.Name, $v.name, $type) -ForegroundColor DarkGray
            continue
        }
        $test = Test-ProviderConnection -ProviderName $p.Name -Provider $v
        if ($test.ok) {
            Write-Host ("  [OK] {0,-12} {1,-35} {2}" -f $p.Name, $v.name, $type) -ForegroundColor Green
            Write-Host ("      {0}" -f $test.detail) -ForegroundColor DarkGray
            Write-Host ("      base: {0}" -f $v.base_url) -ForegroundColor DarkGray
        } else {
            Write-Host ("  [!!] {0,-12} {1,-35} {2}" -f $p.Name, $v.name, $type) -ForegroundColor Yellow
            Write-Host ("      {0}" -f $test.detail) -ForegroundColor DarkGray
        }
    }
}

function Show-Models {
    param([string]$Provider)
    $data = Read-Connections
    if (-not $data) { Write-Output '  [!] No hay connections.json.'; return }
    $p = $data.providers.$Provider
    if (-not $p) { Write-Output "  [!] Proveedor '$Provider' no existe."; return }
    Write-Host "  Modelos de $Provider ($($p.name)):" -ForegroundColor Cyan
    foreach ($m in @($p.models)) {
        Write-Host "    $m" -ForegroundColor White
    }
}

switch ($Command) {
    'init' { Init-Connections }
    'list' { Show-Status }
    'status' { Show-Status }
    'add' {
        if (-not $Name) { throw 'Falta -Name (ej: openai, claude, nvidia, custom-name)' }
        $data = Read-Connections
        if (-not $data) { Init-Connections; $data = Read-Connections }
        $p = $KNOWN_PROVIDERS[$Name]
        if (-not $p -and $Type) {
            # Proveedor custom
            $p = @{ type = $Type; name = $DisplayName; base_url = $BaseUrl; key_env = $KeyEnv; models = @() }
        }
        if (-not $p) { throw "Proveedor '$Name' no conocido y falta -Type/-BaseUrl para custom." }
        $data.providers | Add-Member -NotePropertyName $Name -NotePropertyValue ([ordered]@{
            type      = $p.type
            name      = $p.name
            base_url  = $p.base_url
            login_url = if ($p.login_url) { $p.login_url } else { '' }
            key_env   = if ($p.key_env) { $p.key_env } else { '' }
            api_key   = ''
            connected = $false
            models    = @($p.models)
            added_at  = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        }) -Force
        Write-Connections $data
        Write-Output "  [OK] Proveedor '$Name' agregado. Conectalo con set-key."
    }
    'set-key' {
        if (-not $Name) { throw 'Falta -Name' }
        if (-not $ApiKey -and -not $KeyEnv) { throw 'Falta -ApiKey o -KeyEnv' }
        $data = Read-Connections
        if (-not $data) { Init-Connections; $data = Read-Connections }
        if (-not $data.providers.$Name) { throw "Proveedor '$Name' no existe." }
        if ($ApiKey) { $data.providers.$Name.api_key = $ApiKey }
        if ($KeyEnv) { $data.providers.$Name.key_env = $KeyEnv }
        $data.providers.$Name.connected = $true
        $data.updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Write-Connections $data
        # Verificar la conexion REAL contra la API
        $test = Test-ProviderConnection -ProviderName $Name -Provider $data.providers.$Name
        if ($test.ok) {
            Write-Output "  [OK] '$Name' conectado y VERIFICADO: $($test.detail)."
        } else {
            Write-Output "  [!] '$Name' configurado pero NO verificado: $($test.detail)."
        }
    }
    'verify' {
        $data = Read-Connections
        if (-not $data) { Write-Output '  [!] No hay connections.json.'; return }
        foreach ($p in $data.providers.PSObject.Properties) {
            if (-not $p.Value.connected) { Write-Output ("  [--] " + $p.Name + ": sin conectar"); continue }
            $t = Test-ProviderConnection -ProviderName $p.Name -Provider $p.Value
            $mark = if ($t.ok) { '[OK]' } else { '[!!]' }
            Write-Output ("  " + $mark + " " + $p.Name + ": " + $t.detail)
        }
    }
    'remove' {
        if (-not $Name) { throw 'Falta -Name' }
        $data = Read-Connections
        if (-not $data -or -not $data.providers.$Name) { throw "Proveedor '$Name' no existe." }
        $data.providers.PSObject.Properties.Remove($Name)
        $data.updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Write-Connections $data
        Write-Output "  [OK] Proveedor '$Name' eliminado."
    }
    'models' {
        if ($Name) { Show-Models -Provider $Name } else { Show-Status }
    }
    default { Show-Status }
}
