# regression.ps1 - FASE 5: REGRESSION FACTORY
# ===========================================
# Cuando un quest pasa de FAIL -> remediation -> PASS, el fallo puede volverse
# un GUARD permanente (test unitario, assertion, security rule, lint, contract).
# Este comando registra el guard con trazabilidad completa:
#   memory/quest/failure_signature -> guard_type -> guard_path -> status
# y permite verificarlo (el guard debe fallar si el bug se reintroduce).
#
# Acciones:
#   suggest  -> cuando quest-done detecta PASS tras FAIL, emite una candidata
#               de regression (sin crear aun - Kuja la implementa)
#   create   -> registrar el guard una vez implementado (Kuja)
#   list     -> listar guards por quest/failure
#   check    -> validar estado del guard (existe el archivo?)
#
# Uso:
#   .\cli\regression.ps1 -Action suggest -QuestId Q-040 -Verdict PASS -Prompt "fix bug 404"
#   .\cli\regression.ps1 -Action create -QuestId Q-040 -GuardType unit -GuardPath "tests/bug-404.test.ts" -FailureSignature "404 route"
#   .\cli\regression.ps1 -Action list -QuestId Q-040
#   .\cli\regression.ps1 -Action check -GuardPath "tests/bug-404.test.ts"

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("suggest","create","list","check")]
    [string]$Action = "list",
    [string]$QuestId = "",
    [string]$Verdict = "",
    [string]$Prompt = "",
    [string]$GuardType = "",
    [string]$GuardPath = "",
    [string]$FailureSignature = "",
    [string]$CreatedBy = "kuja",
    [switch]$Json,
    [string]$ArnesDir = ""
)

$ErrorActionPreference = "Continue"

if (-not $ArnesDir) {
    $cwd = (Get-Location).Path
    if (Test-Path (Join-Path $cwd ".arnes\config.json")) {
        $ArnesDir = Join-Path $cwd ".arnes"
    } else {
        $ArnesDir = ".arnes"
    }
}

$logFile = Join-Path $ArnesDir "regressions.jsonl"
if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }

function Read-Regressions {
    if (-not (Test-Path -LiteralPath $logFile)) { return @() }
    $items = @()
    foreach ($line in (Get-Content -LiteralPath $logFile -Encoding UTF8 | Where-Object { $_.Trim() })) {
        try { $items += ($line | ConvertFrom-Json) } catch {}
    }
    return @($items)
}

# === SUGGEST: candidata automatica en PASS tras FAIL ===
if ($Action -eq "suggest") {
    if (-not $QuestId) { Write-Error "suggest requiere -QuestId"; exit 1 }
    if (-not $Prompt) { $Prompt = $QuestId }

    # inferir guard_type por el prompt
    $guardType = "unit"
    $lower = $Prompt.ToLower()
    if ($lower -match "rls|policy|supabase|security|auth|permiso|permission") { $guardType = "security" }
    elseif ($lower -match "api|schema|contract|endpoint") { $guardType = "contract" }
    elseif ($lower -match "bug|error|crash|fix|404|500") { $guardType = "unit" }

    $suggestion = [ordered]@{
        event = "regression_suggestion"
        ts = (Get-Date).ToString("o")
        quest_id = $QuestId
        verdict = $Verdict
        guard_type = $guardType
        failure_signature = $lower.Substring(0, [Math]::Min(80, $lower.Length))
        reason = "PASS tras FAIL: el fallo puede volverse guard permanente"
        status = "suggested"
        created_by = "tywin"
    }
    if ($Json) {
        $suggestion | ConvertTo-Json -Depth 4
    } else {
        Write-Host ("  [REGRESSION] Candidata sugerida: {0} | guard_type={1}" -f $QuestId, $guardType) -ForegroundColor Yellow
        Write-Host ("               Kuja implementa el guard y lo registra con -Action create.") -ForegroundColor DarkGray
    }
    exit 0
}

# === CREATE: registrar el guard implementado (Kuja) ===
if ($Action -eq "create") {
    if (-not $QuestId -or -not $GuardType -or -not $GuardPath) {
        Write-Error "create requiere -QuestId -GuardType -GuardPath"; exit 1
    }
    if (-not $FailureSignature) { $FailureSignature = $GuardPath }

    # no-duplicacion: misma failure_signature + guard_type no crea duplicados
    $existing = Read-Regressions
    $dup = $existing | Where-Object { $_.failure_signature -eq $FailureSignature -and $_.guard_type -eq $GuardType -and $_.quest_id -eq $QuestId }
    if ($dup) {
        if ($Json) { @{ ok = $false; reason = "duplicate"; existing = $dup } | ConvertTo-Json -Depth 4; exit 0 }
        Write-Host "  [REGRESSION] Guard duplicado (misma failure_signature + tipo + quest). No se crea." -ForegroundColor Yellow
        exit 0
    }

    $guardExists = Test-Path -LiteralPath $GuardPath
    $entry = [ordered]@{
        event = "regression_guard"
        ts = (Get-Date).ToString("o")
        quest_id = $QuestId
        guard_type = $GuardType
        guard_path = $GuardPath
        guard_exists = $guardExists
        failure_signature = $FailureSignature
        status = if ($guardExists) { "active" } else { "missing_file" }
        created_by = $CreatedBy
        verified_at = $null
    } | ConvertTo-Json -Compress
    Add-Content -LiteralPath $logFile -Value $entry -Encoding UTF8

    if ($Json) {
        $entry | ConvertFrom-Json | ConvertTo-Json -Depth 4
    } else {
        $color = if ($guardExists) { "Green" } else { "Yellow" }
        Write-Host ("  [REGRESSION] Guard registrado: {0} | {1} | {2}" -f $QuestId, $GuardType, $GuardPath) -ForegroundColor $color
        if (-not $guardExists) {
            Write-Host ("               [!] El archivo {0} no existe - Kuja debe crearlo." -f $GuardPath) -ForegroundColor Yellow
        }
    }
    exit 0
}

# === LIST ===
if ($Action -eq "list") {
    $items = Read-Regressions
    if ($QuestId) { $items = @($items | Where-Object { $_.quest_id -eq $QuestId }) }
    if ($Json) {
        @($items | ForEach-Object {
            @{ quest_id = $_.quest_id; guard_type = $_.guard_type; guard_path = $_.guard_path; guard_exists = $_.guard_exists; failure_signature = $_.failure_signature; status = $_.status; created_by = $_.created_by; ts = $_.ts }
        }) | ConvertTo-Json -Depth 4
        exit 0
    }
    if (@($items).Count -eq 0) {
        $suffix = if ($QuestId) { " para $QuestId" } else { "" }
        Write-Host ("  [REGRESSION] Sin guards registrados{0}." -f $suffix) -ForegroundColor Yellow
        Write-Host "              Se crean en quest-done cuando un quest pasa de FAIL a PASS." -ForegroundColor DarkGray
        exit 0
    }
    Write-Host ""
    Write-Host "  REGRESSION FACTORY - guards" -ForegroundColor Cyan
    Write-Host "  ============================" -ForegroundColor Cyan
    foreach ($r in $items) {
        $color = if ($r.guard_exists) { "Green" } else { "Red" }
        Write-Host ("  {0} | {1,-8} | {2} | {3}" -f $r.quest_id, $r.guard_type, $r.guard_path, $(if ($r.guard_exists) { "ACTIVO" } else { "FALTA ARCHIVO" })) -ForegroundColor $color
        Write-Host ("      failure: {0} | by {1}" -f $r.failure_signature, $r.created_by) -ForegroundColor DarkGray
    }
    Write-Host ""
    exit 0
}

# === CHECK: el guard existe? ===
if ($Action -eq "check") {
    if (-not $GuardPath) { Write-Error "check requiere -GuardPath"; exit 1 }
    $exists = Test-Path -LiteralPath $GuardPath
    if ($Json) {
        @{ guard_path = $GuardPath; exists = $exists } | ConvertTo-Json
    } else {
        Write-Host ("  [REGRESSION] {0}: {1}" -f $GuardPath, $(if ($exists) { "existe (guard activo)" } else { "NO existe" })) -ForegroundColor $(if ($exists) { "Green" } else { "Red" })
    }
    exit 0
}
