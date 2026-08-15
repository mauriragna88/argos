#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS TEST-MODEL - Prueba en vivo que un modelo responde (MOTOR NATIVO de ARNES)

.DESCRIPTION
Envia un "hola" al modelo elegido usando argos-engine.ps1 (directo a la API, sin opencode)
y muestra su respuesta: que modelo es y que proveedor lo creo. Confirma tambien el uso
de tokens. Complementario al `argos verify` (que valida la conexion de la API).

.EXAMPLE
.\argos-test-model.ps1 -Model nvidia/deepseek-ai/deepseek-v4-flash
.\argos-test-model.ps1 -Model openai/gpt-5.6-luna
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Model
)

$ErrorActionPreference = 'Stop'
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
$ConnPath = Join-Path $GlobalConfigDir 'connections.json'
$Engine = Join-Path $PSScriptRoot 'argos-engine.ps1'

# Validar que el modelo pertenece a un proveedor CONECTADO
if (-not (Test-Path $ConnPath)) { Write-Host '  [!] No hay conexiones. Corre: argos connect' -ForegroundColor Yellow; exit 1 }
$conn = Get-Content $ConnPath -Raw | ConvertFrom-Json
$prefix = (($Model -split '/', 2)[0]) + '/'
$connected = @($conn.providers.PSObject.Properties | Where-Object { $_.Value.connected -and ($prefix -eq ($_.Name + '/')) })
if ($connected.Count -eq 0) {
    Write-Host "  [!] '$Model' no pertenece a un proveedor CONECTADO." -ForegroundColor Yellow
    Write-Host '  Solo se pueden probar modelos de conexiones verificadas (argos connect).' -ForegroundColor DarkGray
    exit 1
}

Write-Host ''
Write-Host "  Probando modelo: $Model (motor nativo ARNES, sin opencode)" -ForegroundColor Cyan
Write-Host '  Pregunta: "hola, que modelo eres y quien te creo?"' -ForegroundColor DarkGray
Write-Host ''

$prompt = 'Responde SOLO con una linea: el nombre exacto del modelo que te esta ejecutando y quien te creo. Formato: "Soy <modelo>, creado por <proveedor>".'

$result = & $Engine -Model $Model -Message $prompt -MaxTokens 200

Write-Host '  Respuesta del modelo:' -ForegroundColor White
if ($result.ok) {
    Write-Host "    $($result.reply)" -ForegroundColor Green
    Write-Host ''
    if ($result.usage) {
        Write-Host ("  [uso] prompt={0} completion={1} total={2}" -f $result.usage.prompt_tokens, $result.usage.completion_tokens, $result.usage.total_tokens) -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host "  [OK] $Model responde correctamente (API: $($result.api_model) via $($result.provider))." -ForegroundColor Green
} else {
    Write-Host "    $($result.error)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host "  [!] $Model no respondio. Verifica la conexion con: argos verify" -ForegroundColor Yellow
}
Write-Host ''
