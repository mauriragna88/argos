#Requires -Version 5.1
<#
.SYNOPSIS
Contract Audit - gate deterministico DB <-> API <-> Frontend (ARNES, ADR-006).

Corre las capas L1-L3 (validacion estatica; L4-L6 requieren stack local y se
documentan como requeridas). Genera el reporte consolidado y un exit code:
  0 = PASS (o SKIP cuando el proyecto no aplica una capa)
  1 = FAIL (al menos una capa fallo)

Uso:
  pwsh ./scripts/contract-audit/run-all.ps1              # reporte completo
  pwsh ./scripts/contract-audit/run-all.ps1 -Json        # salida JSON para Tywin
  npm run contract:audit                                 # via package.json

Integracion harness:
  - Tywin lo invoca como paso mandatory pre-verdict (tywin-judgment, arnes-sdd-verify, arnes-fdd-review)
  - Auron lo incluye en el L0 Gate pre-demo/deploy (auron-bulwark)
  - Manual: argos audit  |  argos audit init  (desplegar el gate al proyecto)
#>
param(
    [switch]$Json
)

$ErrorActionPreference = 'Continue'
$ScriptDir = $PSScriptRoot
$ConfigPath = Join-Path $ScriptDir 'config.json'
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir '..\..')

# Forzar UTF-8 (ADR-005: PS 5.1 sin esto corrompe caracteres multibyte en consola)
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Report-Line {
    param([string]$Line)
    if (-not $Json) { Write-Host $Line }
}

# === Banner ===
Report-Line ''
Report-Line '  ═══════════════════════════════════════════════════════════'
Report-Line '   CONTRACT AUDIT — DB ↔ API ↔ Frontend  (ARNES · ADR-006)'
Report-Line '  ═══════════════════════════════════════════════════════════'
Report-Line ("   Proyecto: {0}" -f (Split-Path $ProjectRoot -Leaf))
Report-Line ''

# === Config ===
$cfg = $null
if (Test-Path $ConfigPath) {
    try { $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json } catch { $cfg = $null }
}

# === Ejecutar capas ===
$layers = @()
$failed = $false

# --- L1: Migrations <-> Types ---
Report-Line '  ── L1 · Migrations ↔ Generated Types (staleness) ──────────'
$l1Json = & (Join-Path $ScriptDir 'types-diff.ps1') -ConfigPath $ConfigPath -Json
if ($LASTEXITCODE -eq 0) {
    Report-Line '  [PASS] types frescos vs migraciones'
    $layers += 'L1:PASS'
} elseif ($LASTEXITCODE -eq 2) {
    Report-Line '  [SKIP] proyecto sin supabase/types'
    $layers += 'L1:SKIP'
} else {
    Report-Line '  [FAIL] database.types.ts stale o tipos no generables (C1/C3)'
    $layers += 'L1:FAIL'
    $failed = $true
}

# --- L2: Schema <-> Codigo (select audit) ---
Report-Line '  ── L2 · Schema ↔ Código (columnas referenciadas) ────────────'
$l2Json = & node (Join-Path $ScriptDir 'select-audit.mjs') --config $ConfigPath --json 2>$null
$l2Exit = $LASTEXITCODE
if ($l2Exit -eq 0) {
    $l2 = $l2Json | ConvertFrom-Json
    Report-Line "  [PASS] $($l2.detail)"
    $layers += 'L2:PASS'
} elseif ($l2Exit -eq 2) {
    Report-Line '  [SKIP] sin archivos de codigo TS'
    $layers += 'L2:SKIP'
} else {
    $l2 = $l2Json | ConvertFrom-Json
    Report-Line "  [FAIL] $($l2.detail)"
    foreach ($f in @($l2.findings)) {
        Report-Line ("         {0}:{1}  {2}" -f (Split-Path $f.file -Leaf), $f.line, $f.message)
    }
    $layers += 'L2:FAIL'
    $failed = $true
}

# --- L2.5: Auth & Identity Contract (patrones del proyecto) ---
Report-Line '  ── L2.5 · Auth & Identity Contract (argos audit scan) ─────────'
$l25Pass = $true
$authCfg = $cfg.auth
if ($authCfg) {
    $authCfg = $cfg.auth
    $ok = $true
    # C7: Profile table known
    if (-not $authCfg.profile_table) {
        Report-Line '  [FAIL] C7: tabla de perfiles no detectada (profiles/usuarios)'
        $ok = $false
    }
    # C8: Tenant column known
    if (-not $authCfg.tenant_column) {
        Report-Line '  [FAIL] C8: tenant column no detectada (organization_id/empresa_id)'
        $ok = $false
    }
    # C11: Auth claims check
    if ($authCfg.auth_claims -contains 'auth.jwt' -or $authCfg.auth_claims -contains 'auth.email' -or $authCfg.auth_claims -contains 'auth.role') {
        Report-Line ('  [FAIL] C11: se usan claims JWT extras: {0} - verificar si es intencional' -f (@($authCfg.auth_claims | Where-Object { $_ -ne 'auth.uid' }) -join ', '))
        $ok = $false
    }
    if ($ok) {
        Report-Line ("  [PASS] auth OK: tenant=$($authCfg.tenant_column), profile=$($authCfg.profile_table), helpers=$($authCfg.auth_helpers -join ',')")
        $layers += 'L2.5:PASS'
    } else {
        $layers += 'L2.5:FAIL'
        $failed = $true
    }
} else {
    Report-Line '  [SKIP] sin config de auth (correr: argos audit scan)'
    $layers += 'L2.5:SKIP'
}

# --- L3: FK/PK integrity (requiere conexion a la DB) ---
Report-Line '  ── L3 · Relations (FK/PK integrity) ─────────────────────────'
$sqlFile = Join-Path $ScriptDir 'fk-audit.sql'
$l3Done = $false

# Vía 1: supabase CLI linkeado (sin password, via Management API)
$supabaseCli = Get-Command 'supabase' -ErrorAction SilentlyContinue
if ($supabaseCli) {
    $l3Json = & supabase db query --linked --file $sqlFile --output-format json 2>$null
    if ($LASTEXITCODE -eq 0 -and $l3Json) {
        try {
            $rows = @($l3Json | ConvertFrom-Json)
            $serious = @($rows | Where-Object { $_.check_id -in @('C12', 'C13', 'C16') })
            if ($serious.Count -eq 0) {
                Report-Line '  [PASS] sin violaciones FK/PK (C12-C16) - integridad de relaciones OK'
                $layers += 'L3:PASS'
            } else {
                Report-Line ("  [FAIL] {0} violaciones FK/PK serias:" -f $serious.Count)
                foreach ($row in @($serious | Select-Object -First 15)) {
                    Report-Line ("         {0}: {1}.{2} -> {3}.{4} ({5})" -f $row.check_id, $row.fk_table, $row.fk_column, $row.ref_table, $row.ref_column, $row.problem)
                }
                $layers += 'L3:FAIL'
                $failed = $true
            }
            $c15 = @($rows | Where-Object { $_.check_id -eq 'C15' })
            if ($c15.Count -gt 0) {
                Report-Line ("  [INFO] {0} FKs listadas para revision ON DELETE (C15 - auditoria humana)" -f $c15.Count)
            }
            $l3Done = $true
        } catch {
            $l3Done = $false
        }
    }
}

# Vía 2: DATABASE_URL + psql
if (-not $l3Done) {
    $dbUrl = $env:DATABASE_URL
    if (-not $dbUrl) { $dbUrl = $env:SUPABASE_DB_URL }
    if ($dbUrl -and (Get-Command 'psql' -ErrorAction SilentlyContinue)) {
        $l3Output = & psql $dbUrl -f $sqlFile -t -A 2>$null
        if ($LASTEXITCODE -eq 0 -and -not $l3Output) {
            Report-Line '  [PASS] sin violaciones FK/PK (C12-C16)'
            $layers += 'L3:PASS'
        } else {
            Report-Line '  [FAIL] violaciones FK/PK detectadas:'
            foreach ($row in @($l3Output)) { Report-Line "         $row" }
            $layers += 'L3:FAIL'
            $failed = $true
        }
        $l3Done = $true
    }
}

if (-not $l3Done) {
    Report-Line '  [SKIP] sin acceso a DB (necesita: supabase link + supabase db query, o DATABASE_URL + psql)'
    $layers += 'L3:SKIP'
}

# --- L4-L6 (requieren stack local / smoke tests) ---
Report-Line '  ── L4-L6 · API contract / Runtime smoke (requieren stack local) ──'
$hasTests = Test-Path (Join-Path $ProjectRoot 'scripts/contract-audit/zod-smoke.test.ts')
if ($hasTests) {
    Report-Line '  [WARN] zod-smoke.test.ts presente pero no ejecutado (correr con vitest + supabase start)'
    $layers += 'L4-L6:PENDING'
} else {
    Report-Line '  [PENDING] capas L4-L6 no configuradas en este proyecto (ver skill arnes-contract-audit)'
    $layers += 'L4-L6:PENDING'
}

# === Reporte consolidado ===
Report-Line ''
Report-Line '  ═══════════════════════════════════════════════════════════'
$verdict = if ($failed) { 'FAIL' } else { 'PASS' }
Report-Line ("   VERDICT: {0}" -f $verdict)
Report-Line ("   Capas:   {0}" -f ($layers -join ' · '))
if ($failed) {
    Report-Line '   Remediation: ver FALLOS arriba; regenerar types / fix .select() / fix FKs'
    Report-Line '   La skill arnes-contract-audit convierte cada FAIL en items C<N>'
}
Report-Line '  ═══════════════════════════════════════════════════════════'
Report-Line ''

# === Salida JSON (para Tywin / CI) ===
$report = [ordered]@{
    gate = 'contract-audit'
    project = Split-Path $ProjectRoot -Leaf
    verdict = $verdict
    layers = $layers
    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
    source = 'arnes-contract-audit / ADR-006'
}
if ($Json) {
    $report | ConvertTo-Json -Depth 4
}

exit $(if ($failed) { 1 } else { 0 })
