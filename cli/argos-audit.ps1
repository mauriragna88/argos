#Requires -Version 5.1
<#
.SYNOPSIS
argos audit - Contract Audit DB <-> API <-> Frontend (ARNES, ADR-006).

DESPLIEGA el gate deterministico a CUALQUIER proyecto y lo corre.

Comandos:
  argos audit init        -> despliega scripts/contract-audit/ al proyecto actual
                             (detecta rutas: supabase/migrations, database.types.ts, app/api, src)
                             + anade npm script "contract:audit"
  argos audit scan        -> escanea migrations + codigo para detectar patrones de auth
                             (tenant column, profile table, helpers RLS, claims JWT)
                             + guarda en config.json (los agentes lo leen pre-codigo)
  argos audit             -> corre el gate en el proyecto actual (exit 0/1)
  argos audit status      -> muestra si el gate esta desplegado y que capas aplican
  argos audit --json      -> salida JSON (para Tywin / CI)

Integracion:
  - Proyecto 0: se despliega automaticamente en "argos init" (forzoso)
  - Proyecto en seguimiento (RES/CHAT): corre "argos audit init" UNA vez
  - Tywin lo invoca pre-verdict; Auron lo incluye en el L0 Gate
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet('', 'init', 'scan', 'status', 'run')]
    [string]$Command = '',

    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$Root = Resolve-Path (Join-Path $ScriptDir '..')
$ProjectDir = (Get-Location).Path
$TemplateDir = Join-Path $Root 'core\contract-audit'
$TargetDir = Join-Path $ProjectDir 'scripts\contract-audit'
$ConfigPath = Join-Path $TargetDir 'config.json'

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Write-Step {
    param([string]$Msg)
    Write-Host ("  ▸ {0}" -f $Msg) -ForegroundColor Cyan
}
function Write-Ok {
    param([string]$Msg)
    Write-Host ("  [OK] {0}" -f $Msg) -ForegroundColor Green
}
function Write-Warn {
    param([string]$Msg)
    Write-Host ("  [!] {0}" -f $Msg) -ForegroundColor Yellow
}

# === Auto-deteccion de rutas del proyecto ===
function Get-DetectedConfig {
    $types = $null
    $foundTypes = @(Get-ChildItem -Path $ProjectDir -Recurse -File -Filter 'database.types.ts' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch 'node_modules' } | Select-Object -First 1)
    if ($foundTypes) {
        # Ruta relativa compatible con PS 5.1 (Path.GetRelativePath no existe en .NET Framework)
        $types = $foundTypes[0].FullName.Substring($ProjectDir.Length).TrimStart('\', '/')
    }

    $scanDirs = @('src', 'app')
    $existingScan = @($scanDirs | Where-Object { Test-Path (Join-Path $ProjectDir $_) })
    if ($existingScan.Count -eq 0) { $existingScan = @('.') }

    $migrations = 'supabase/migrations'
    if (-not (Test-Path (Join-Path $ProjectDir $migrations))) { $migrations = $null }

    $apiRoutes = 'app/api'
    if (-not (Test-Path (Join-Path $ProjectDir $apiRoutes))) { $apiRoutes = $null }

    return [ordered]@{
        version = '1.0'
        project = (Split-Path $ProjectDir -Leaf)
        supabase = [ordered]@{
            migrations_dir = $migrations
            types_file = $types
            local_stack = $true
        }
        code = [ordered]@{
            scan_dirs = $existingScan
            extensions = @('.ts', '.tsx', '.js', '.jsx')
            max_line_distance_from = 8
        }
        api = [ordered]@{
            routes_dir = $apiRoutes
            require_input_schema = $true
            forbid_select_star = $true
        }
        tiers = [ordered]@{
            minimum = @('L1', 'L2')
            full = @('L1', 'L2', 'L3', 'L4', 'L5', 'L6')
        }
    }
}

# === Anadir npm script "contract:audit" al package.json del proyecto ===
function Add-NpmScript {
    $pkgPath = Join-Path $ProjectDir 'package.json'
    if (-not (Test-Path $pkgPath)) { return $false }
    try {
        $pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
        if (-not $pkg.scripts) { $pkg | Add-Member -NotePropertyName 'scripts' -NotePropertyValue ([ordered]@{}) -Force }
        $pkg.scripts | Add-Member -NotePropertyName 'contract:audit' -NotePropertyValue 'pwsh ./scripts/contract-audit/run-all.ps1' -Force
        $json = $pkg | ConvertTo-Json -Depth 12
        # UTF-8 SIN BOM (PS 5.1 Set-Content -Encoding UTF8 agrega BOM y rompe JSON.parse)
        [IO.File]::WriteAllText($pkgPath, $json, (New-Object Text.UTF8Encoding $false))
        return $true
    } catch {
        return $false
    }
}

# === INIT ===
function Invoke-Init {
    Write-Step 'Contract Audit - desplegando gate al proyecto'

    if (-not (Test-Path $TemplateDir)) {
        Write-Warn "Template no encontrado: $TemplateDir (repos arnes incompleto)"
        exit 1
    }
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    # Copiar scripts del template
    foreach ($f in @('types-diff.ps1', 'select-audit.mjs', 'fk-audit.sql', 'run-all.ps1', 'README.md')) {
        $src = Join-Path $TemplateDir $f
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $TargetDir $f) -Force
        }
    }

    # Config detectada (no sobreescribir config existente sin flag -Force)
    $cfgDetected = Get-DetectedConfig
    if (-not (Test-Path $ConfigPath)) {
        $cfgJson = $cfgDetected | ConvertTo-Json -Depth 6
        # UTF-8 SIN BOM (el BOM rompe JSON.parse en Node)
        [IO.File]::WriteAllText($ConfigPath, $cfgJson, (New-Object Text.UTF8Encoding $false))
        Write-Ok "config.json generado con rutas detectadas"
    } else {
        Write-Warn 'config.json ya existe - no se sobreescribio'
    }

    # npm script
    $hasNpm = Add-NpmScript
    if ($hasNpm) {
        Write-Ok 'npm script "contract:audit" anadido al package.json'
    } else {
        Write-Warn 'no package.json - corre el gate con: pwsh ./scripts/contract-audit/run-all.ps1'
    }

    Write-Ok 'Gate desplegado. Resumen de deteccion:'
    Write-Host ''
    Write-Host ("    supabase/migrations: {0}" -f $(if ($cfgDetected.supabase.migrations_dir) { 'DETECTADO' } else { 'no (gate L1/L3 saltaran)' })) -ForegroundColor White
    Write-Host ("    database.types.ts:    {0}" -f $(if ($cfgDetected.supabase.types_file) { $cfgDetected.supabase.types_file } else { 'NO ENCONTRADO' })) -ForegroundColor White
    Write-Host ("    codigo (scan):         {0}" -f ($cfgDetected.code.scan_dirs -join ', ')) -ForegroundColor White
    Write-Host ''
    Write-Host '  Corre el gate ahora:  argos audit' -ForegroundColor Green
    Write-Host '  (o: npm run contract:audit)  — Tywin lo invoca automatico pre-verdict' -ForegroundColor DarkGray
}

# === STATUS ===
function Invoke-Status {
    Write-Step 'Contract Audit - estado del gate'
    if (-not (Test-Path $TargetDir)) {
        Write-Warn 'El gate NO esta desplegado en este proyecto.'
        Write-Host '  Corre:  argos audit init' -ForegroundColor Cyan
        Write-Host '  (proyectos nuevos: se despliega solo en "argos init")' -ForegroundColor DarkGray
        exit 0
    }
    Write-Ok 'Gate desplegado en scripts/contract-audit/'
    $cfg = $null
    if (Test-Path $ConfigPath) { $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json }
    if ($cfg) {
        Write-Host ''
        Write-Host ("    types_file:     {0}" -f $(if ($cfg.supabase.types_file) { $cfg.supabase.types_file } else { 'no detectado' })) -ForegroundColor White
        Write-Host ("    scan_dirs:      {0}" -f ($cfg.code.scan_dirs -join ', ')) -ForegroundColor White
        Write-Host ("    migrations_dir: {0}" -f $(if ($cfg.supabase.migrations_dir) { $cfg.supabase.migrations_dir } else { 'no detectado' })) -ForegroundColor White
    }
    # npm script?
    $pkgPath = Join-Path $ProjectDir 'package.json'
    if (Test-Path $pkgPath) {
        $pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
        if ($pkg.scripts.'contract:audit') {
            Write-Ok 'npm script "contract:audit" presente'
        }
    }
    Write-Host ''
    Write-Host '  Corre el gate:  argos audit' -ForegroundColor Green
}

# === SCAN (detectar patrones de auth del proyecto) ===
function Invoke-Scan {
    Write-Step 'Contract Audit - escaneando patrones de autenticacion del proyecto'

    $result = [ordered]@{
        tenant_column = $null
        profile_table = $null
        profile_fk_auth_users = $false
        auth_helpers = @()
        auth_claims = @()
        rls_pattern = 'unknown'
        role_resolution = 'unknown'
        summary = ''
    }

    # Buscar en migraciones (si existen)
    $migrationsDir = Join-Path $ProjectDir 'supabase/migrations'
    if (Test-Path $migrationsDir) {
        $migrationFiles = @(Get-ChildItem $migrationsDir -Filter '*.sql' | Sort-Object Name)
        $allSql = @($migrationFiles | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"

        # Profile table name
        if ($allSql -match 'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?public\.usuarios\b') {
            $result.profile_table = 'usuarios'
        } elseif ($allSql -match 'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?public\.profiles\b') {
            $result.profile_table = 'profiles'
        }

        # FK to auth.users
        if ($allSql -match 'REFERENCES\s+auth\.users') {
            $result.profile_fk_auth_users = $true
        }

        # Tenant column name
        if ($allSql -match '\borganization_id\b') {
            $result.tenant_column = 'organization_id'
        } elseif ($allSql -match '\bempresa_id\b') {
            $result.tenant_column = 'empresa_id'
        }

        # Auth helper functions
        $helpers = @()
        if ($allSql -match 'current_active_organization_id') { $helpers += 'current_active_organization_id' }
        if ($allSql -match 'has_active_membership_for_tenant') { $helpers += 'has_active_membership_for_tenant' }
        if ($allSql -match 'auth_user_empresa_id') { $helpers += 'auth_user_empresa_id' }
        if ($allSql -match 'auth_user_rol') { $helpers += 'auth_user_rol' }
        if ($allSql -match 'auth_user_rol_strict') { $helpers += 'auth_user_rol_strict' }
        if ($allSql -match 'auth_user_sucursal_ids') { $helpers += 'auth_user_sucursal_ids' }
        if ($helpers.Count -eq 0) { $helpers += 'auth.uid_only' }
        $result.auth_helpers = $helpers

        # Auth claims used in RLS
        $claims = @()
        if ($allSql -match 'auth\.jwt\(\)') { $claims += 'auth.jwt' }
        if ($allSql -match 'auth\.email\(\)') { $claims += 'auth.email' }
        if ($allSql -match 'auth\.role\(\)') { $claims += 'auth.role' }
        if ($allSql -match 'auth\.uid\(\)') { $claims += 'auth.uid' }
        if ($claims.Count -eq 0) { $claims += 'none_detected' }
        $result.auth_claims = $claims

        # RLS pattern
        if ($allSql -match 'has_active_membership_for_tenant') { $result.rls_pattern = 'tenant_membership' }
        elseif ($allSql -match 'auth_user_empresa_id') { $result.rls_pattern = 'empresa_id_match' }
        elseif ($allSql -match 'auth_user_rol') { $result.rls_pattern = 'role_based' }
        else { $result.rls_pattern = 'auth_uid_only' }

        # Role resolution
        if ($allSql -match 'organization_member_roles') { $result.role_resolution = 'db_lookup_roles' }
        elseif ($allSql -match '\broles\b.*\bcode\b') { $result.role_resolution = 'db_lookup_role_code' }
        elseif ($allSql -match '\brol\b') { $result.role_resolution = 'db_column' }
        else { $result.role_resolution = 'unknown' }
    }

    # Buscar en codigo frontend patrones de auth
    $srcDir = $null
    foreach ($d in @('src', 'app', 'lib')) {
        $p = Join-Path $ProjectDir $d
        if (Test-Path $p) { $srcDir = $p; break }
    }
    if ($srcDir) {
        $tsFiles = @(Get-ChildItem $srcDir -Recurse -Include '*.ts', '*.tsx', '*.js', '*.jsx' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch 'node_modules|\.next' } | Select-Object -First 100)
        $allCode = ""
        if ($tsFiles.Count -gt 0) {
            $allCode = @($tsFiles | ForEach-Object { 
                try { Get-Content $_.FullName -Raw } catch { "" }
            }) -join "`n"
        }

        # How does frontend get tenant ID?
        if ($allCode -match '\.from\("usuarios"\)') { $result.profile_table = 'usuarios' }
        elseif ($allCode -match '\.from\("profiles"\)') { $result.profile_table = 'profiles' }

        # Auth helpers used in frontend
        if ($allCode -match 'getMyPortalAccess') { $result.auth_helpers += 'getMyPortalAccess' }
        if ($allCode -match 'auth_user_empresa_id') { $result.auth_helpers += 'auth_user_empresa_id' }
        if ($allCode -match 'list_selectable_memberships') { $result.auth_helpers += 'list_selectable_memberships' }
        if ($allCode -match 'getSession') { $result.auth_helpers += 'getSession' }
        if ($allCode -match 'getUser\(') { $result.auth_helpers += 'getUser' }
    }

    # Summary
    $tc = if ($result.tenant_column) { $result.tenant_column } else { '?' }
    $pr = if ($result.role_resolution) { $result.role_resolution } else { '?' }
    $pt = if ($result.profile_table) { $result.profile_table } else { '?' }
    $ah = if ($result.auth_helpers) { $result.auth_helpers -join ', ' } else { '?' }
    $ac = if ($result.auth_claims) { $result.auth_claims -join ', ' } else { '?' }
    $rp = if ($result.rls_pattern) { $result.rls_pattern } else { '?' }
    $result.summary = "Tenant via $tc, roles via $pr, profile table: $pt, helpers: $ah, JWT claims: $ac, RLS: $rp"

    # Guardar en config.json
    $configPath = $ConfigPath
    $cfg = @{}
    if (Test-Path $configPath) {
        try { $cfg = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable } catch { $cfg = @{} }
    }
    $cfg['auth'] = $result
    $cfgJson = $cfg | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($configPath, $cfgJson, (New-Object Text.UTF8Encoding $false))
    Write-Ok "Patrones de auth detectados y guardados en config.json"

    Write-Host ''
    Write-Host "    tenant_column:    $($result.tenant_column)" -ForegroundColor White
    Write-Host "    profile_table:    $($result.profile_table)" -ForegroundColor White
    Write-Host "    profile_fk_auth:  $($result.profile_fk_auth_users)" -ForegroundColor White
    Write-Host "    auth_helpers:     $($result.auth_helpers -join ', ')" -ForegroundColor White
    Write-Host "    auth_claims:      $($result.auth_claims -join ', ')" -ForegroundColor White
    Write-Host "    rls_pattern:      $($result.rls_pattern)" -ForegroundColor White
    Write-Host "    role_resolution:  $($result.role_resolution)" -ForegroundColor White
    Write-Host ''
    Write-Host "    $($result.summary)" -ForegroundColor DarkGray
}

# === RUN ===
function Invoke-Run {
    if (-not (Test-Path $TargetDir)) {
        Write-Warn 'El gate NO esta desplegado en este proyecto.'
        Write-Host '  Corre:  argos audit init' -ForegroundColor Cyan
        exit 1
    }
    $runner = Join-Path $TargetDir 'run-all.ps1'
    if (-not (Test-Path $runner)) {
        Write-Warn 'run-all.ps1 no encontrado en scripts/contract-audit/'
        exit 1
    }
    if ($Json) {
        & $runner -Json
    } else {
        & $runner
    }
    exit $LASTEXITCODE
}

# === MAIN ===
switch ($Command) {
    'init' { Invoke-Init }
    'scan' { Invoke-Scan }
    'status' { Invoke-Status }
    'run' { Invoke-Run }
    default {
        if ($Json) { Invoke-Run } else { Invoke-Status }
    }
}
