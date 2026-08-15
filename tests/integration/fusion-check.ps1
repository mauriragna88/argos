# ============================================================
# ARGOS SUPERPOWERS - suite de integración de la fusión
# Verifica de forma automatizable los criterios del spec (§94)
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File tests/integration/fusion-check.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fail = $false

function Check([string]$name, [scriptblock]$body) {
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'  # stderr nativo no debe abortar los checks
    try {
        & $body
        Write-Host "  PASS  $name" -ForegroundColor Green
    } catch {
        Write-Host "  FAIL  $name :: $($_.Exception.Message)" -ForegroundColor Red
        $script:fail = $true
    } finally {
        $ErrorActionPreference = $oldEAP
    }
}

Write-Host "== ARGOS SUPERPOWERS fusion check (root: $root) ==" -ForegroundColor Cyan

# 1. Launcher dry-run
Check "argos pi -DryRun arranca (single brain)" {
    Push-Location $root
    & powershell -NoProfile -ExecutionPolicy Bypass -File cli/argos-pi.ps1 -DryRun *> $null
    if ($LASTEXITCODE -ne 0) { throw "exit $LASTEXITCODE" }
    Pop-Location
}

# 2. Superpowers disponible (settings.json packages + dir de skills — pi list no lo refleja en esta config)
Check "superpowers disponible (settings + skills dir)" {
    $settings = Join-Path $env:USERPROFILE '.pi\agent\settings.json'
    if (-not (Test-Path $settings)) { throw "no settings.json: $settings" }
    $content = Get-Content $settings -Raw
    if ($content -notmatch 'superpowers') { throw 'superpowers no esta en settings.json' }
    $skillsDir = Join-Path $env:USERPROFILE '.pi\agent\git\github.com\obra\superpowers\skills'
    if (-not (Test-Path $skillsDir)) { throw "no skills dir: $skillsDir" }
    $n = (Get-ChildItem $skillsDir -Directory).Count
    if ($n -lt 10) { throw "solo $n skills" }
}

# 3. Role-skills generadas (>= 16)
Check "16+ role-skills en pi/skills" {
    $n = (Get-ChildItem (Join-Path $root 'pi/skills') -Directory).Count
    if ($n -lt 16) { throw "solo $n" }
}

# 4. Tests unitarios
Check "tests unitarios (tsx --test)" {
    Push-Location (Join-Path $root 'pi')
    $out = & npx tsx --test ../tests/unit/*.test.ts 2>&1 | Out-String
    Pop-Location
    if ($out -notmatch 'pass \d+' -or $out -match 'fail [1-9]') { throw 'tests fallan' }
}

# 5. Boot smoke (extensión carga con pi real)
Check "boot-smoke: pi arranca con la extension" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tests/integration/boot-smoke.ps1') *> $null
    if ($LASTEXITCODE -ne 0) { throw "exit $LASTEXITCODE" }
}

# 6. La fusion NO toco opencode.json ni cli existentes (respecto al commit de inicio de la fusion)
Check "opencode.json intacto en commits de la fusion" {
    $d = & git -C $root diff 6355a0d..HEAD --stat -- opencode.json 2>&1
    if ($d -match 'opencode.json') { throw 'opencode.json fue modificado' }
}

# 7. Typecheck limpio
Check "tsc --noEmit limpio" {
    Push-Location (Join-Path $root 'pi')
    $out = & npx tsc --noEmit -p tsconfig.json 2>&1 | Out-String
    Pop-Location
    if ($LASTEXITCODE -ne 0) { throw $out }
}

if ($fail) {
    Write-Host "`nRESULTADO: FAIL" -ForegroundColor Red
    exit 1
}
Write-Host "`nRESULTADO: PASS - fusion operativa (checks automatizables)" -ForegroundColor Green
exit 0
