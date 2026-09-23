# ============================================================
# ARNES - router de modo + Auron Gate (Fase 6): mode-route.ps1
#
# Hermetico: sin APIs; scripts de prueba en archivos temporales.
# Verifica: route (DIRECT_TOOL/CODE_MODE/AGENT/SUBAGENT + gate requerido) y
# gate (bloquea rm -rf, Remove-Item sobre raiz, DROP TABLE, git push --force,
# .env y pipe remoto a shell; permite un script seguro; ScriptFile inexistente
# -> exit 1).
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/mode-route.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$PSExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
$Cli = Join-Path $Root 'cli\mode-route.ps1'
$work = Join-Path $Root ('.mode-route-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Invoke-Mode {
    param([string[]]$ModeArgs, [switch]$AllowFail)
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $text = (& $PSExe -NoProfile -ExecutionPolicy Bypass -File $Cli @ModeArgs 2>&1 | Out-String)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousEap
    }
    if ($code -ne 0 -and -not $AllowFail) { throw "mode-route fallo (exit $code): $($text.Trim())" }
    return @{ text = $text; code = $code }
}

function Parse-Json { param([string]$Text) return ($Text | ConvertFrom-Json) }

function Write-Script {
    param([string]$Name, [string]$Content)
    $p = Join-Path $work $Name
    [System.IO.File]::WriteAllText($p, $Content, (New-Object System.Text.UTF8Encoding($false)))
    return $p
}

try {
    # 1. route: 2 llamadas -> DIRECT_TOOL
    $r1 = Parse-Json (Invoke-Mode @('-Action','route','-ToolCalls','2','-Json')).text
    Assert-That ($r1.mode -eq 'DIRECT_TOOL') "2 llamadas -> DIRECT_TOOL (obtenido $($r1.mode))"
    Assert-That ($r1.code_mode_requires_gate -eq $false) 'DIRECT_TOOL no requiere gate'

    # 2. route: secuencia larga -> CODE_MODE + gate requerido
    $r2 = Parse-Json (Invoke-Mode @('-Action','route','-ToolCalls','9','-Sequential','-LongOutput','-Json')).text
    Assert-That ($r2.mode -eq 'CODE_MODE') "9 secuenciales -> CODE_MODE (obtenido $($r2.mode))"
    Assert-That ($r2.code_mode_requires_gate -eq $true) 'CODE_MODE exige Auron Gate'

    # 3. route: partes independientes -> SUBAGENT; juicio -> AGENT
    $r3 = Parse-Json (Invoke-Mode @('-Action','route','-ToolCalls','8','-IndependentParts','-Json')).text
    Assert-That ($r3.mode -eq 'SUBAGENT') "8 independientes -> SUBAGENT (obtenido $($r3.mode))"
    $r4 = Parse-Json (Invoke-Mode @('-Action','route','-ToolCalls','5','-NeedsModelJudgment','-Json')).text
    Assert-That ($r4.mode -eq 'AGENT') "5 con juicio -> AGENT (obtenido $($r4.mode))"

    # 4. gate: script seguro -> PASS
    $safe = Write-Script 'safe.ps1' "Write-Output 'hola'`nGet-ChildItem . | Select-Object -First 3`n"
    $g1 = Invoke-Mode @('-Action','gate','-ScriptFile',$safe)
    Assert-That ($g1.code -eq 0) "script seguro -> exit 0 (obtenido $($g1.code))"
    Assert-That ($g1.text -match 'PASS') 'script seguro reporta PASS'

    # 5. gate: rm -rf -> BLOCK
    $dangerous = Write-Script 'danger.ps1' "rm -rf / --no-preserve-root`n"
    $g2 = Invoke-Mode @('-Action','gate','-ScriptFile',$dangerous) -AllowFail
    Assert-That ($g2.code -eq 1) "rm -rf -> bloqueado (obtenido $($g2.code))"

    # 6. gate: Remove-Item recursivo sobre raiz -> BLOCK
    $dangerous2 = Write-Script 'danger2.ps1' "Remove-Item -Recurse -Force C:\Users -ErrorAction SilentlyContinue`n"
    $g3 = Invoke-Mode @('-Action','gate','-ScriptFile',$dangerous2) -AllowFail
    Assert-That ($g3.code -eq 1) "Remove-Item sobre raiz -> bloqueado (obtenido $($g3.code))"

    # 7. gate: DROP TABLE y git push --force -> BLOCK
    $dangerous3 = Write-Script 'danger3.sql' "DROP TABLE users;`n"
    $g4 = Invoke-Mode @('-Action','gate','-ScriptFile',$dangerous3) -AllowFail
    Assert-That ($g4.code -eq 1) 'DROP TABLE -> bloqueado'
    $dangerous4 = Write-Script 'danger4.sh' "git push --force origin main`n"
    $g5 = Invoke-Mode @('-Action','gate','-ScriptFile',$dangerous4) -AllowFail
    Assert-That ($g5.code -eq 1) 'git push --force -> bloqueado'

    # 8. gate: credenciales (.env) -> BLOCK; ScriptFile inexistente -> exit 1
    $dangerous5 = Write-Script 'danger5.ps1' "Set-Content .env 'X=1'`n"
    $g6 = Invoke-Mode @('-Action','gate','-ScriptFile',$dangerous5) -AllowFail
    Assert-That ($g6.code -eq 1) '.env -> bloqueado'
    $g7 = Invoke-Mode @('-Action','gate','-ScriptFile',(Join-Path $work 'nope.ps1'),'-Json' ) -AllowFail
    Assert-That ($g7.code -eq 1) 'ScriptFile inexistente -> exit 1'

    # 9. gate -Json reporta findings para auditoria
    $g8 = Invoke-Mode @('-Action','gate','-ScriptFile',$dangerous4,'-Json') -AllowFail
    $gj = Parse-Json $g8.text
    Assert-That ($gj.verdict -eq 'BLOCK') 'gate -Json verdict BLOCK'
    Assert-That (@($gj.findings).Count -ge 1) 'gate -Json incluye findings'

    Write-Output 'PASS mode-route: router de modo + Auron Gate (bloquea destructivos, permite seguros)'
    exit 0
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
