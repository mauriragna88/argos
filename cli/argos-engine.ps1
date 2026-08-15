#Requires -Version 5.1
<#
.SYNOPSIS
ARNES ENGINE - Motor nativo de ARNES ARGOS (habla DIRECTO con las APIs de los modelos)

.DESCRIPTION
Ejecuta completions contra los proveedores (OpenAI-compatible) SIN pasar por opencode:
- bai     -> https://api.b.ai/v1/chat/completions
- nvidia  -> https://integrate.api.nvidia.com/v1/chat/completions
- opencode-go -> https://api.opencode.ai/v1/chat/completions
- openai  -> https://api.openai.com/v1/chat/completions (token OAuth del plan)
Las keys vienen de ~/.config/arnes/connections.json (o auth.json como fallback).
Devuelve la respuesta + uso de tokens (prompt/completion).

.EXAMPLE
.\argos-engine.ps1 -Model nvidia/deepseek-ai/deepseek-v4-flash -Message "hola"
.\argos-engine.ps1 -Model opencode-go/gpt-5.6-luna -System "Eres Atlas" -Session @(@{role='user';content='hi'}) -Message "continua"
.\argos-engine.ps1 -Model opencode-go/deepseek-v4-flash -System "Identidad RPG y skills cacheable" -SystemDynamic "Memoria y contexto del quest" -Message "haz login"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Model,           # id completo: nvidia/deepseek-ai/deepseek-v4-flash

    [string]$System = '',     # system prompt LEGACY (un solo bloque). Se envia como system
                              # estatico si no se pasa $SystemDynamic; si se pasa ambos,
                              # $System va como prefijo estable (cacheable) y
                              # $SystemDynamic como system message adicional despues.

    [string]$SystemDynamic = '',  # system prompt DINAMICO (memoria, contexto del quest).
                                   # Se envia DESPUES de $System para no romper el prefijo
                                   # cacheable. DeepSeek/OpenAI cachean el prefijo estable
                                   # ($System) y solo cobran cache miss en la parte variable.

    [string]$Message = '',

    [array]$Session = @(),    # historial previo: @{ role='user'|'assistant'; content='...' } (+ tool_calls)

    [array]$Tools = @(),      # definiciones OpenAI function-calling

    [array]$ToolHistory = @(),# resultados de tools del paso anterior: @{ role='tool'; tool_call_id=..; content=.. }

    [int]$MaxTokens = 0,      # 0 = sin limite (el proveedor usa su maximo); si >0 se envia al API

    [double]$Temperature = 0.3
)

$ErrorActionPreference = 'Stop'
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
$ConnPath = Join-Path $GlobalConfigDir 'connections.json'
$AuthPath = Join-Path $env:USERPROFILE '.local\share\opencode\auth.json'

function Get-ProviderName($fullId) { ($fullId -split '/', 2)[0] }
function Get-ApiModelId($fullId) { ($fullId -split '/', 2)[1] }

# === Sanitizar texto: quita controles C0/C1 (128-159), DEL y U+FFFD que rompen las APIs ===
function Sanitize-Text {
    param([string]$Text)
    if (-not $Text) { return $Text }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int]$ch
        if ($code -in @(9, 10, 13)) { [void]$sb.Append($ch); continue }
        if ($code -lt 32 -or ($code -ge 127 -and $code -le 159) -or $code -eq 0xFFFD) { continue }
        [void]$sb.Append($ch)
    }
    return $sb.ToString()
}

# === Resolver credencial: connections.json (nuestra) -> auth.json (fallback) ===
function Resolve-ApiKey {
    param([string]$ProviderName)
    if (Test-Path $ConnPath) {
        $conn = Get-Content $ConnPath -Raw | ConvertFrom-Json
        $p = $conn.providers.$ProviderName
        if ($p) {
            if ($p.api_key) { return @{ key = [string]$p.api_key; type = 'api' } }
            if ($p.key_env) {
                $envVal = Get-Item "Env:$($p.key_env)" -ErrorAction SilentlyContinue
                if ($envVal) { return @{ key = [string]$envVal.Value; type = 'api' } }
            }
        }
    }
    if (Test-Path $AuthPath) {
        $auth = Get-Content $AuthPath -Raw | ConvertFrom-Json
        $a = $auth.$ProviderName
        if ($a) {
            if ($a.access) { return @{ key = [string]$a.access; type = 'oauth' } }
            if ($a.key) { return @{ key = [string]$a.key; type = 'api' } }
        }
    }
    return $null
}

$provider = Get-ProviderName $Model
$apiModel = Get-ApiModelId $Model

# === Endpoint nativo por proveedor (OpenAI-compatible) ===
$baseUrl = switch ($provider) {
    'bai'         { 'https://api.b.ai/v1' }
    'nvidia'      { 'https://integrate.api.nvidia.com/v1' }
    'opencode-go' { 'https://opencode.ai/zen/go/v1' }   # endpoint real de OpenCode Go
    'openai'      { 'https://api.openai.com/v1' }
    default       { '' }
}
if (-not $baseUrl) {
    Write-Output ([pscustomobject]@{ ok = $false; reply = ''; model = $Model; provider = $provider; error = "Proveedor '$provider' sin endpoint nativo en ARNES."; usage = $null; cache_hit = 0; cache_miss = 0 })
    exit 0
}

$cred = Resolve-ApiKey $provider
if (-not $cred) {
    Write-Output ([pscustomobject]@{ ok = $false; reply = ''; model = $Model; provider = $provider; error = "Sin credenciales para '$provider'. Corre: argos connect"; usage = $null; cache_hit = 0; cache_miss = 0 })
    exit 0
}

# === Construir mensajes (sanitizados) ===
# ORDEN CRITICO PARA CACHE DE PREFIJO:
#   1. system (estatico)   <- cacheable: AGENTS.md, identity, skills (NO cambia entre turns)
#   2. system (dinamico)   <- NO cacheable: memoria, recall, contexto del quest actual
#   3. session[0..N-1]      <- crece con cada turno (parcialmente cacheable si estable)
#   4. message (nuevo)     <- NO cacheable: cambia cada turno
# DeepSeek/OpenAI cachean el prefijo estable (system estatico) y cobran cache hit
# (4x mas barato) en vez de cache miss. El system dinamico va despues para no romper
# el prefijo cacheable del system estatico.
$messages = @()
if ($System) { $messages += @{ role = 'system'; content = (Sanitize-Text $System) } }
if ($SystemDynamic) { $messages += @{ role = 'system'; content = (Sanitize-Text $SystemDynamic) } }
foreach ($m in $Session) {
    if ($m.tool_calls) {
        # Mensaje de asistente con tool_calls (debe serializarse tal cual)
        $msg = @{ role = 'assistant'; content = [string]$m.content }
        $msg.tool_calls = @($m.tool_calls | ForEach-Object {
            @{ id = $_.id; type = 'function'; function = @{ name = $_.function.name; arguments = [string]$_.function.arguments } }
        })
        $messages += $msg
    } else {
        $messages += @{ role = $m.role; content = (Sanitize-Text ([string]$m.content)) }
    }
}
foreach ($th in $ToolHistory) { $messages += @{ role = 'tool'; tool_call_id = $th.tool_call_id; content = (Sanitize-Text ([string]$th.content)) } }
if ($Message) { $messages += @{ role = 'user'; content = (Sanitize-Text $Message) } }

$body = @{
    model       = $apiModel
    messages    = $messages
    temperature = $Temperature
}
if ($MaxTokens -gt 0) { $body.max_tokens = $MaxTokens }
if ($Tools.Count -gt 0) { $body.tools = $Tools }
$body = $body | ConvertTo-Json -Depth 12

$headers = @{ Authorization = "Bearer $($cred.key)" }
# CRITICO: enviar el body como bytes UTF-8 (PS 5.1 manda ISO-8859-1 si es string -> server 500 con unicode)
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$resp = $null
$lastErr = ''
$lastCode = 0
for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
        # Invoke-WebRequest + decode UTF-8 EXPLICITO: PS 5.1 decodifica la respuesta como ISO-8859-1
        # si el Content-Type no trae charset -> mojibake ("Â¡"). Con los bytes crudos queda perfecto.
        $httpResp = Invoke-WebRequest -Uri "$baseUrl/chat/completions" -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $bodyBytes -TimeoutSec 150 -UseBasicParsing -ErrorAction Stop
        $resp = ([System.Text.Encoding]::UTF8.GetString($httpResp.RawContentStream.ToArray()) | ConvertFrom-Json)
        break
    } catch {
        $lastCode = 0
        try { $lastCode = [int]$_.Exception.Response.StatusCode } catch {}
        $lastErr = $_.Exception.Message
        # Reintento en errores transitorios (429/500/503)
        if ($lastCode -in @(429, 500, 503) -and $attempt -lt 3) {
            Start-Sleep -Seconds (2 * $attempt)
            continue
        }
        break
    }
}
if (-not $resp -or -not $resp.choices -or $resp.choices.Count -eq 0) {
    $ErrorActionPreference = $prevEap
    Write-Output ([pscustomobject]@{
        ok = $false; reply = ''; model = $Model; api_model = $apiModel; provider = $provider
        error = if ($lastErr) { "HTTP $lastCode - $lastErr" } else { "Respuesta vacia o sin 'choices' de $baseUrl (verifica el endpoint o el modelo '$apiModel')" }
        usage = $null
        cache_hit = 0
        cache_miss = 0
    })
    exit 0
}
$reply = [string]$resp.choices[0].message.content
$usage = $resp.usage

# === Capturar metricas de cache (DeepSeek / OpenAI prompt caching) ===
# DeepSeek devuelve: prompt_cache_hit_tokens, prompt_cache_miss_tokens
# OpenAI devuelve:   prompt_tokens_details.cached_tokens
# Guardamos ambos formatos para que argos-stats pueda calcular el ahorro.
$cacheHit = 0
$cacheMiss = 0
if ($usage) {
    if ($usage.prompt_cache_hit_tokens) { $cacheHit = [int]$usage.prompt_cache_hit_tokens }
    if ($usage.prompt_cache_miss_tokens) { $cacheMiss = [int]$usage.prompt_cache_miss_tokens }
    # OpenAI formato anidado
    if ($usage.prompt_tokens_details -and $usage.prompt_tokens_details.cached_tokens) {
        $cacheHit = [int]$usage.prompt_tokens_details.cached_tokens
    }
}

$ErrorActionPreference = $prevEap
Write-Output ([pscustomobject]@{
    ok              = $true
    reply           = $reply.Trim()
    tool_calls      = $resp.choices[0].message.tool_calls
    model           = $Model
    api_model       = $apiModel
    provider        = $provider
    usage           = $usage
    cache_hit       = $cacheHit
    cache_miss      = $cacheMiss
})
