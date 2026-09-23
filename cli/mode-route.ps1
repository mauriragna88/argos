# mode-route.ps1 - FASE 6: router de modo de ejecucion + Auron Gate para scripts
# ==============================================================================
# Decide como ejecutar una tarea (DIRECT_TOOL | CODE_MODE | AGENT | SUBAGENT) y
# aplica el gate de Auron a codigo generado (ADR-024: CODE_MODE reducido, sin
# sandbox real; el gate es obligatorio).
#
# Acciones:
#   route -> decidir el modo segun la secuencia necesaria (heuristica explicita)
#   gate  -> auditar un script (texto o archivo) antes de ejecutarlo: PASS/BLOCK
#
# Uso:
#   .\cli\mode-route.ps1 -Action route -ToolCalls 2
#   .\cli\mode-route.ps1 -Action route -ToolCalls 9 -Sequential -LongOutput -Json
#   .\cli\mode-route.ps1 -Action gate -ScriptFile C:\tmp\script.ps1
#   .\cli\mode-route.ps1 -Action gate -ScriptText "Remove-Item -Recurse -Force C:\"

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("route","gate")]
    [string]$Action = "route",

    # --- route ---
    [int]$ToolCalls = 0,
    [switch]$Sequential,
    [switch]$NeedsModelJudgment,
    [switch]$LongOutput,
    [switch]$IndependentParts,

    # --- gate ---
    [string]$ScriptFile = "",
    [string]$ScriptText = "",

    [switch]$Json
)

$ErrorActionPreference = "Continue"

# Patrones destructivos o prohibidos en codigo generado (Auron Gate, ADR-024)
$BLOCK_PATTERNS = @(
    @{ p = 'rm\s+-rf\s+(/|\*|~)';            r = 'rm -rf sobre raiz/home/glob' },
    @{ p = 'rm\s+-rf\b';                     r = 'rm -rf' },
    @{ p = 'Remove-Item[^\n]*-Recurse[^\n]*-Force[^\n]*\b(C:\\|/|~)'; r = 'Remove-Item recursivo sobre raiz/home' },
    @{ p = 'rmdir\s+/s\s+/q';                r = 'rmdir /s /q' },
    @{ p = 'del\s+/f\s+/s\s+/q';             r = 'del /f /s /q' },
    @{ p = '\bformat\s+[a-zA-Z]:';           r = 'format de disco' },
    @{ p = 'DROP\s+(TABLE|DATABASE|SCHEMA)'; r = 'DROP TABLE/DATABASE/SCHEMA' },
    @{ p = 'TRUNCATE\s+TABLE';               r = 'TRUNCATE TABLE' },
    @{ p = 'git\s+push[^\n]*--force';        r = 'git push --force' },
    @{ p = '--no-verify';                    r = 'saltarse hooks (--no-verify)' },
    @{ p = '(curl|iwr|Invoke-WebRequest)[^\n|]*\|\s*(bash|sh|iex|Invoke-Expression)'; r = 'pipe remoto a shell (curl|bash)' },
    @{ p = 'Invoke-Expression\s*\(';         r = 'Invoke-Expression' },
    @{ p = '\.(env|ssh|git)[\\/]|\.env\b';   r = 'ruta protegida (.env/.ssh/.git)' },
    @{ p = 'connections\.json|auth\.json';   r = 'archivo de credenciales' },
    @{ p = '\.arnes[\\/]arnes\.db';          r = 'memoria OSMA (arnes.db)' }
)

# === ROUTE ===
if ($Action -eq "route") {
    $mode = "DIRECT_TOOL"
    $reasons = @()

    if ($IndependentParts -and $ToolCalls -ge 6) {
        $mode = "SUBAGENT"
        $reasons += "partes independientes ($ToolCalls llamadas) - paralelizable en subagentes"
    } elseif ($NeedsModelJudgment -and $ToolCalls -ge 4) {
        $mode = "AGENT"
        $reasons += "requiere juicio del modelo en varios pasos ($ToolCalls llamadas)"
    } elseif ($Sequential -and $ToolCalls -ge 4) {
        $mode = "CODE_MODE"
        $reasons += "secuencia secuencial larga ($ToolCalls llamadas) - script local rinde mas que N tools"
    } elseif ($ToolCalls -le 3) {
        $mode = "DIRECT_TOOL"
        $reasons += "1-3 llamadas directas (sin overhead de script)"
    } else {
        $mode = "AGENT"
        $reasons += "$ToolCalls llamadas: flujo normal del agente"
    }
    if ($LongOutput -and $mode -ne "DIRECT_TOOL") { $reasons += "output grande: procesar fuera de contexto (resumen compacto)" }

    $result = [ordered]@{ mode = $mode; tool_calls = $ToolCalls; reasons = $reasons; code_mode_requires_gate = ($mode -eq "CODE_MODE") }
    if ($Json) { $result | ConvertTo-Json -Compress } else { Write-Host ("  [MODE] {0}" -f $mode) -ForegroundColor Cyan; foreach ($r in $reasons) { Write-Host ("         - {0}" -f $r) -ForegroundColor DarkGray } }
    exit 0
}

# === GATE (Auron) ===
if ($Action -eq "gate") {
    if (-not $ScriptFile -and -not $ScriptText) { Write-Error "gate requiere -ScriptFile o -ScriptText"; exit 1 }
    $source = $ScriptText
    if ($ScriptFile) {
        if (-not (Test-Path -LiteralPath $ScriptFile)) { Write-Error "ScriptFile no existe: $ScriptFile"; exit 1 }
        $source = [System.IO.File]::ReadAllText($ScriptFile)
    }

    $findings = @()
    foreach ($rule in $BLOCK_PATTERNS) {
        if ($source -match $rule.p) { $findings += $rule.r }
    }

    $verdict = if (@($findings).Count -gt 0) { "BLOCK" } else { "PASS" }
    $result = [ordered]@{ verdict = $verdict; findings = @($findings); script_file = $ScriptFile; bytes = $source.Length }
    if ($Json) { $result | ConvertTo-Json -Depth 4; if ($verdict -eq "BLOCK") { exit 1 } else { exit 0 } }
    if ($verdict -eq "BLOCK") {
        Write-Host "  [AURON GATE] BLOCK - script rechazado:" -ForegroundColor Red
        foreach ($f in $findings) { Write-Host ("      - {0}" -f $f) -ForegroundColor Red }
        exit 1
    }
    Write-Host "  [AURON GATE] PASS - sin patrones destructivos." -ForegroundColor Green
    exit 0
}
