# ============================================================
# ARNES - contrato de orquestacion (sin llamadas a APIs)
#
# Verifica que los scripts de orquestacion (cycle/party/engine)
# parseen sin errores y conserven el contrato minimo: parametros
# obligatorios y referencias al motor nativo. No ejecuta llamadas
# reales a modelos: eso lo prueba el usuario en sesion real.
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/orchestration-contract.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Cli = Join-Path $Root 'cli'

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

# 1. Parseo sin errores
foreach ($name in @('argos-cycle.ps1', 'argos-party.ps1', 'argos-engine.ps1')) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Cli $name), [ref]$tokens, [ref]$errors) | Out-Null
    Assert-That ($errors.Count -eq 0) "$name parsea sin errores (obtenido $($errors.Count))"
    Write-Host "PASS  $name parsea" -ForegroundColor Green
}

# 2. Contrato de argos-cycle.ps1
$cycle = Get-Content (Join-Path $Cli 'argos-cycle.ps1') -Raw
Assert-That ($cycle -match '\[Parameter\(Mandatory = \$true\)\]') 'arnes-cycle: Quest obligatoria'
Assert-That ($cycle -match 'argos-engine\.ps1') 'arnes-cycle: referencia a argos-engine'
Assert-That ($cycle -match 'osma-resolve\.ps1') 'arnes-cycle: memoria via osma-resolve'
Write-Host 'PASS  arnes-cycle contrato (Quest + engine + memoria)' -ForegroundColor Green

# 3. Contrato de argos-party.ps1
$party = Get-Content (Join-Path $Cli 'argos-party.ps1') -Raw
Assert-That ($party -match "\[ValidateSet\('safe', 'balanced', 'autonomous'\)\]") 'argos-party: Modo safe/balanced/autonomous'
Assert-That ($party -match 'argos-engine\.ps1') 'argos-party: referencia a argos-engine'
Assert-That ($party -match 'MaxIterations') 'argos-party: MaxIterations presente'
Write-Host 'PASS  argos-party contrato (Quest + Modo + engine)' -ForegroundColor Green

# 4. Contrato de argos-engine.ps1 (motor que habla con las APIs)
$engine = Get-Content (Join-Path $Cli 'argos-engine.ps1') -Raw
Assert-That ($engine -match 'Resolve-ApiKey') 'arnes-engine: resolucion de API key presente'
Assert-That ($engine -match '429') 'arnes-engine: manejo de reintentos en errores transitorios'
Assert-That ($engine -match 'MaxTokens') 'arnes-engine: control de tokens presente'
Write-Host 'PASS  arnes-engine contrato (api-key + retry + tokens)' -ForegroundColor Green

Write-Output 'PASS orchestration-contract: parseo y contrato minimo sin llamadas reales'
exit 0
