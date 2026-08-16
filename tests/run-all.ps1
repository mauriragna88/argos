#Requires -Version 5.1
<#
.SYNOPSIS
RUN-ALL - Suite de validacion completa de ARNES ARGOS.

.DESCRIPTION
Ejecuta en orden:
  1. Tests unitarios TypeScript (node:test + tsx)  -> tests/unit/*.test.ts
  2. Tests funcionales PowerShell                   -> tests/argos-xp, tests/model-catalog
  3. Test de politica read/write de skills          -> tests/verify-read-write-only.ps1
  4. Parseo de TODOS los scripts de cli/*.ps1
  5. Escaneo de secretos                            -> tests/scan-secrets.ps1
  6. Smoke test del harness                         -> cli/smoke-test.ps1 (opcional)

Exit: 0 = PASS total | 1 = FAIL (al menos una etapa fallo)

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1 -SkipSmoke
#>
[CmdletBinding()]
param(
    [switch]$SkipSmoke,
    [switch]$SmokeInit
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$failCount = 0

# Interprete que corre esta suite: pwsh en Linux/macOS, powershell en Windows
$PSExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }

function Invoke-Step {
    param([string]$Name, [scriptblock]$Body)
    Write-Host ''
    Write-Host ("===== {0} =====" -f $Name) -ForegroundColor Cyan
    try {
        # Limpiar el exit code heredado de la etapa anterior: cada etapa
        # solo falla si SU propio ultimo comando externo devolvio != 0.
        $global:LASTEXITCODE = 0
        & $Body
        if ($LASTEXITCODE -ne 0) { throw "etapa termino con exit code $LASTEXITCODE" }
        Write-Host ("  [OK] {0}" -f $Name) -ForegroundColor Green
    } catch {
        $script:failCount++
        Write-Host ("  [FAIL] {0}: {1}" -f $Name, $_.Exception.Message) -ForegroundColor Red
    }
}

# 1. Unit tests TS
Invoke-Step 'Unit tests TypeScript' {
    node --import tsx --test (Join-Path $Root 'tests\unit\*.test.ts')
}

# 2. Tests funcionales PS
Invoke-Step 'Tests funcionales PowerShell' {
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tests\argos-xp.tests.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'argos-xp.tests fallo' }
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tests\model-catalog.tests.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'model-catalog.tests fallo' }
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tests\arnes-graph.tests.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'arnes-graph.tests fallo' }
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tests\orchestration-contract.tests.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'orchestration-contract.tests fallo' }
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tests\argos-stats-theme.tests.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'argos-stats-theme.tests fallo' }
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tests\argos-target.tests.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'argos-target.tests fallo' }
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tests\argos-goal.tests.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'argos-goal.tests fallo' }
}

# 3. Politica read/write
Invoke-Step 'Politica read/write de skills' {
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tests\verify-read-write-only.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'verify-read-write-only fallo' }
}

# 4. Parseo de todos los .ps1 de cli/
Invoke-Step 'Parseo de scripts PowerShell' {
    $files = @(Get-ChildItem -Path (Join-Path $Root 'cli') -Filter '*.ps1' -File -Recurse)
    $bad = 0
    foreach ($file in $files) {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors.Count -gt 0) {
            $bad++
            Write-Host ("  PARSE FAIL: {0}" -f $file.FullName) -ForegroundColor Red
            $errors | ForEach-Object { Write-Host ("    {0}" -f $_.Message) -ForegroundColor Red }
        }
    }
    Write-Host ("  scripts revisados: {0}" -f $files.Count)
    if ($bad -gt 0) { throw "$bad scripts con errores de parseo" }
}

# 5. Escaneo de secretos
Invoke-Step 'Escaneo de secretos' {
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'tests\scan-secrets.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'scan-secrets encontro patrones sospechosos' }
}

# 6. Smoke test (opcional)
if (-not $SkipSmoke) {
    Invoke-Step 'Smoke test del harness' {
        $smokeArgs = @()
        if ($SmokeInit) { $smokeArgs += '-InitArnes' }
        # Sin -Silent: la salida (checks PASS/FAIL/SKIP) va al log para diagnosticar
        # fallos en CI. Si falla, el detalle queda visible en el error de la etapa.
        $smokeOut = (& $PSExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'cli\smoke-test.ps1') @smokeArgs 2>&1 | Out-String)
        $smokeCode = $LASTEXITCODE
        if ($smokeCode -ne 0) {
            throw "smoke-test fallo (exit $smokeCode)`n$smokeOut"
        }
    }
}

Write-Host ''
if ($failCount -gt 0) {
    Write-Host ("  RESULTADO: FAIL - {0} etapa(s) con errores" -f $failCount) -ForegroundColor Red
    exit 1
}
Write-Host '  RESULTADO: PASS - suite completa correcta.' -ForegroundColor Green
exit 0
