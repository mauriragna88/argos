#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS CONNECT-AGENT - Asigna modelo por agente SOLO con los proveedores logueados

.DESCRIPTION
1. Detecta los logins REALES (Pi auth.json + conexiones ARNES) y muestra SOLO esos.
2. Arma el catalogo con ids completos proveedor/modelo (sin ambiguedad:
   opencode-go/gpt-5.6-luna != openai-codex/gpt-5.6-luna).
3. Wizard por agente: eliges con flechas/busqueda (como opencode/pi).
4. Guarda en agent-models.json y sincroniza a Pi (argos-pi -SyncOnly).

Si quieres usar un proveedor nuevo (ej: Claude), primero logueate:
  argos connect   (o en Pi: /login -> anthropic)  y vuelve a correr esto.

.EXAMPLE
.\argos-connect-agent.ps1          # wizard completo (16 agentes)
.\argos-connect-agent.ps1 -Agent vivi   # solo un agente
#>
[CmdletBinding()]
param(
    [string]$Agent = ''
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
$ConnPath = Join-Path $GlobalConfigDir 'connections.json'
$ModelsPath = Join-Path $GlobalConfigDir 'agent-models.json'
$PiAuthPath = Join-Path $env:USERPROFILE '.pi\agent\auth.json'
$PiAgentsDir = Join-Path $env:USERPROFILE '.pi\agent\agents'
$Picker = Join-Path $PSScriptRoot 'argos-picker.ps1'

# ============ 1. PROVEEDORES LOGEADOS (fuente de verdad real) ============
$authed = [ordered]@{}
$authNotes = @()

# Pi auth.json (lo que Pi puede usar de verdad)
if (Test-Path $PiAuthPath) {
    $pa = Get-Content $PiAuthPath -Raw | ConvertFrom-Json
    foreach ($p in $pa.PSObject.Properties) {
        $authed[$p.Name] = @{ source = 'pi'; type = $p.Value.type }
        $authNotes += "  [OK] {0} (login Pi: {1})" -f $p.Name, $p.Value.type
    }
}
# Conexiones ARNES (las nuestras)
if (Test-Path $ConnPath) {
    $conn = Get-Content $ConnPath -Raw | ConvertFrom-Json
    foreach ($p in $conn.providers.PSObject.Properties) {
        if ($p.Value.connected -and -not $authed.Contains($p.Name)) {
            $authed[$p.Name] = @{ source = 'arnes'; type = $p.Value.type }
            $authNotes += "  [OK] {0} (conexion ARNES: {1})" -f $p.Name, $p.Value.type
        }
    }
}

Write-Host ''
Write-Host '  ARNES ARGOS - CONNECT AGENT (modelo por agente, solo logueados)' -ForegroundColor Cyan
Write-Host '  ==============================================================' -ForegroundColor Cyan
Write-Host ''
if ($authed.Count -eq 0) {
    Write-Host '  [!] Sin proveedores logueados. Corre: argos connect' -ForegroundColor Yellow
    exit 1
}
Write-Host '  Proveedores con login real:' -ForegroundColor White
$authNotes | ForEach-Object { Write-Host $_ -ForegroundColor Green }
Write-Host ''

# ============ 2. CATALOGO por proveedor (ids completos, Pi-compatibles) ============
$piProviderMap = @{ 'openai' = 'openai-codex'; 'opencode-go' = 'opencode-go'; 'nvidia' = 'nvidia'; 'bai' = 'bai' }
$knownModels = @{
    'opencode-go' = @('deepseek-v4-flash', 'deepseek-v4-pro', 'qwen3.8-max', 'gpt-5.6-luna', 'glm-5.2', 'kimi-k2.6')
    'nvidia'      = @('nvidia/llama-3.3-nemotron-super-49b-v1.5', 'z-ai/glm-5.2', 'google/gemma-3-12b-it')
    'openai-codex' = @('gpt-5.6-sol', 'gpt-5.6-terra', 'gpt-5.6-luna', 'gpt-5.6-fast', 'gpt-5.5', 'gpt-5.4')
    'bai'         = @('claude-opus-5', 'claude-fable-5', 'claude-sonnet-5', 'gpt-5.6-sol', 'gpt-5.6-luna', 'deepseek-v4-flash', 'qwen3.8-max', 'kimi-k2.6', 'glm-5.2', 'gemini-3.1-pro')
}
# ampliar con los modelos de connections.json si existen
if (Test-Path $ConnPath) {
    $conn2 = Get-Content $ConnPath -Raw | ConvertFrom-Json
    foreach ($p in $conn2.providers.PSObject.Properties) {
        $provId3 = if ($piProviderMap.ContainsKey($p.Name)) { $piProviderMap[$p.Name] } else { $p.Name }
        if ($p.Value.models -and $p.Value.models.Count -gt 0) { $knownModels[$provId3] = @($p.Value.models) }
    }
}

$allModels = @()
foreach ($p in $authed.Keys) {
    $provId = if ($piProviderMap.ContainsKey($p)) { $piProviderMap[$p] } else { $p }
    $models = if ($knownModels.ContainsKey($provId)) { $knownModels[$provId] } else { @() }
    foreach ($m in $models) { $allModels += ("{0}/{1}" -f $provId, $m) }
}
if ($allModels.Count -eq 0) {
    Write-Host '  [!] Los proveedores logueados no tienen catalogo conocido.' -ForegroundColor Yellow
    exit 1
}
$allModels = @($allModels | Sort-Object -Unique)
Write-Host ("  Catalogo disponible: {0} modelos (ids completos proveedor/modelo)" -f $allModels.Count) -ForegroundColor DarkGray
Write-Host ''

# ============ 3. WIZARD por agente ============
$am = @{}
if (Test-Path $ModelsPath) {
    $raw = Get-Content $ModelsPath -Raw | ConvertFrom-Json
    foreach ($a in $raw.agents.PSObject.Properties) { $am[$a.Name] = [string]$a.Value }
}
# Lista unificada: 16 agentes ARNES + agentes OMO (orquestacion/consultores)
$agents = @('atlas', 'vivi', 'ansem', 'kuja', 'eiko', 'amarant', 'eremez', 'auron', 'bran', 'quina', 'varys', 'tywin', 'sam', 'bard', 'tidus', 'ragnarok')
$omoAgents = @('sisyphus', 'oracle', 'explore', 'librarian', 'momus', 'metis', 'plan', 'maestro', 'gentleman', 'prometheus', 'hephaestus', 'deep_worker', 'kimi')
$agents += $omoAgents | Where-Object { $_ -notin $agents }
if ($Agent) { $agents = @($Agent) }

foreach ($ag in $agents) {
    $current = if ($am.ContainsKey($ag)) { $am[$ag] } else { '' }
    Write-Host ("  ▸ Agente: {0}" -f $ag) -ForegroundColor White
    Write-Host ("    actual: {0}" -f $(if ($current) { $current } else { '(sin asignar)' })) -ForegroundColor DarkGray
    $defaultIdx = 0
    if ($current) {
        $found = [Array]::IndexOf($allModels, $current)
        if ($found -ge 0) { $defaultIdx = $found }
    }
    $choice = & $Picker -Title ("Modelo para " + $ag) -Options $allModels -DefaultIndex $defaultIdx -Group 'solo proveedores logueados'
    if ($choice -and $choice -ne '') {
        $am[$ag] = $choice
        Write-Host ("    [OK] {0} -> {1}" -f $ag, $choice) -ForegroundColor Green
    } else {
        Write-Host '    (sin cambio)' -ForegroundColor DarkGray
    }
    Write-Host ''
}

# ============ 4. GUARDAR + SINCRONIZAR A PI ============
$out = [ordered]@{
    version = '1.0'
    updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    agents = [ordered]@{}
}
foreach ($a in $agents) { $out.agents[$a] = $am[$a] }
# preservar agentes no tocados
if (Test-Path $ModelsPath) {
    $existing = Get-Content $ModelsPath -Raw | ConvertFrom-Json
    foreach ($e in $existing.agents.PSObject.Properties) {
        if (-not $out.agents.PSObject.Properties.Name.Contains($e.Name)) { $out.agents[$e.Name] = [string]$e.Value }
    }
}
$out | ConvertTo-Json -Depth 6 | Set-Content $ModelsPath -Encoding UTF8
Write-Host ('  [OK] Configuracion guardada: {0}' -f $ModelsPath) -ForegroundColor Green
Write-Host '  Pi tomara los modelos via la extension argos-agents-manager (reinicia Pi si hace falta).' -ForegroundColor DarkGray
Write-Host ''
