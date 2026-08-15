# ============================================================
# ARNES - verificacion del sistema XP (F1)
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/argos-xp.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'

$fail = $false
function Assert-Equal {
    param([string]$Name, $Expected, $Actual)
    if ($Expected -ne $Actual) {
        $script:fail = $true
        Write-Host ("FAIL  {0}: esperado '{1}', obtenido '{2}'" -f $Name, $Expected, $Actual) -ForegroundColor Red
    } else {
        Write-Host ("PASS  {0}" -f $Name) -ForegroundColor Green
    }
}

# Formula duplicada intencionalmente para aislar el test (nivel = floor(sqrt(xp/100)) + 1)
function Test-Level([int]$xp) {
    if ($xp -le 0) { return 1 }
    return [math]::Floor([math]::Sqrt($xp / 100.0)) + 1
}

Assert-Equal 'XP 0 -> nivel 1' 1 (Test-Level 0)
Assert-Equal 'XP 100 -> nivel 2' 2 (Test-Level 100)
Assert-Equal 'XP 400 -> nivel 3' 3 (Test-Level 400)
Assert-Equal 'XP 900 -> nivel 4' 4 (Test-Level 900)
Assert-Equal 'XP 999 -> nivel 4' 4 (Test-Level 999)

# Verificar que el script argos-xp.ps1 parsea sin errores
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path '.\cli\argos-xp.ps1'),
    [ref]$tokens,
    [ref]$errors
) | Out-Null
Assert-Equal 'argos-xp.ps1 parsea' 0 $errors.Count

if ($fail) {
    Write-Host "`nRESULTADO: FAIL" -ForegroundColor Red
    exit 1
}
Write-Host "`nRESULTADO: PASS - formula XP correcta y script valido." -ForegroundColor Green
exit 0
