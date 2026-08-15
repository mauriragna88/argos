#Requires -Version 5.1
<#
.SYNOPSIS
Gate L1 - Migrations <-> Generated Types staleness.

Verifica que database.types.ts es IDENTICO a lo que supabase gen types produce hoy.
Si las migraciones cambiaron y los tipos no se regeneraron -> FAIL (C1, C3).

Exit codes:
  0 = PASS (types frescos)
  1 = FAIL (stale o gen types fallo)
  2 = SKIP (no hay supabase/types en el proyecto)
#>
param(
    [string]$ConfigPath = "scripts/contract-audit/config.json",
    [switch]$Json
)

$ErrorActionPreference = 'Continue'
$result = [ordered]@{ gate = 'L1'; status = 'SKIP'; detail = ''; checks = @() }

function Write-Report {
    param([string]$Line)
    if (-not $Json) { Write-Host $Line }
}

try {
    $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
} catch {
    Write-Report "  L1 | config.json no encontrado en $ConfigPath - usando defaults"
    $cfg = $null
}

# Detectar rutas (defaults sensatos si no hay config)
$migrationsDir = if ($cfg -and $cfg.supabase.migrations_dir) { $cfg.supabase.migrations_dir } else { 'supabase/migrations' }
$typesFile = if ($cfg -and $cfg.supabase.types_file) { $cfg.supabase.types_file } else { 'src/types/database.types.ts' }

# Si no hay migraciones ni types -> SKIP (proyecto no es supabase)
$hasMigrations = Test-Path $migrationsDir
$hasTypes = Test-Path $typesFile

if (-not $hasMigrations -and -not $hasTypes) {
    $result.detail = 'No supabase/migrations ni database.types.ts detectados - gate L1 no aplica'
    $result | ConvertTo-Json -Compress | Write-Output
    exit 2
}

# Buscar database.types.ts si la ruta configurada no existe (auto-detect)
if (-not $hasTypes) {
    $found = Get-ChildItem -Recurse -File -Filter 'database.types.ts' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch 'node_modules' } | Select-Object -First 1
    if ($found) { $typesFile = $found.FullName; $hasTypes = $true }
}

if (-not $hasTypes) {
    $result.status = 'FAIL'
    $result.detail = 'database.types.ts NO existe. Corre: npx supabase gen types typescript --local > src/types/database.types.ts (C1)'
    $result.checks += 'C1'
    $result | ConvertTo-Json -Compress | Write-Output
    exit 1
}

Write-Report "  L1 | types file: $typesFile"

# Verificar que hay migraciones que aplicar (C3)
$migrationFiles = @(Get-ChildItem $migrationsDir -Filter '*.sql' -ErrorAction SilentlyContinue)
if ($migrationFiles.Count -eq 0) {
    Write-Report "  L1 | WARN: $migrationsDir vacio - no hay migraciones que comparar"
}

# Regenerar types y comparar
$tmpTypes = Join-Path $env:TEMP ("types-gen-" + [guid]::NewGuid().ToString('N') + ".ts")
$supabaseCli = Get-Command 'supabase' -ErrorAction SilentlyContinue

if (-not $supabaseCli) {
    Write-Report '  L1 | WARN: supabase CLI no instalado - no se puede regenerar types'
    $result.status = 'WARN'
    $result.detail = 'supabase CLI no disponible; verifica manualmente que database.types.ts refleja las migraciones'
    $result | ConvertTo-Json -Compress | Write-Output
    exit 2
}

$ErrorActionPreference = 'Continue'
& supabase gen types typescript --local 2>$null | Out-File -FilePath $tmpTypes -Encoding UTF8
$genExit = $LASTEXITCODE

if ($genExit -ne 0 -or -not (Test-Path $tmpTypes) -or (Get-Item $tmpTypes).Length -eq 0) {
    # Fallback: intentar contra linked/prod si no hay stack local
    & supabase gen types typescript 2>$null | Out-File -FilePath $tmpTypes -Encoding UTF8
    $genExit = $LASTEXITCODE
}

if ($genExit -ne 0 -or -not (Test-Path $tmpTypes) -or (Get-Item $tmpTypes).Length -eq 0) {
    Write-Report '  L1 | FAIL: no se pudieron regenerar types (supabase start no esta corriendo o no hay proyecto linkeado)'
    $result.status = 'FAIL'
    $result.detail = 'gen types fallo. Corre: supabase start (local stack) o supabase link (proyecto). (C3)'
    $result.checks += 'C3'
    Remove-Item $tmpTypes -Force -ErrorAction SilentlyContinue
    $result | ConvertTo-Json -Compress | Write-Output
    exit 1
}

# Normalizar y comparar (ignorar diferencias de whitespace final)
$current = Get-Content $typesFile -Raw
$generated = Get-Content $tmpTypes -Raw

if ($current.Trim() -eq $generated.Trim()) {
    Write-Report '  L1 | PASS: database.types.ts identico a supabase gen types'
    $result.status = 'PASS'
    $result.detail = 'types frescos vs migraciones'
} else {
    Write-Report '  L1 | FAIL: database.types.ts ESTA DESACTUALIZADO (C1)'
    Write-Report "  L1 |   regenerar: npx supabase gen types typescript --local > $typesFile"
    # Diferencias resumidas: primeras lineas distintas
    $curLines = $current -split "`n"
    $genLines = $generated -split "`n"
    $diffs = 0
    for ($i = 0; $i -lt [Math]::Max($curLines.Count, $genLines.Count); $i++) {
        if ($diffs -ge 5) { break }
        if ($curLines[$i] -ne $genLines[$i]) {
            Write-Report ("  L1 |   diff linea {0}: actual='{1}' vs generado='{2}'" -f ($i + 1), $curLines[$i].Trim(), $genLines[$i].Trim())
            $diffs++
        }
    }
    $result.status = 'FAIL'
    $result.detail = 'database.types.ts stale vs migraciones - regenerar tipos'
    $result.checks += 'C1'
}

Remove-Item $tmpTypes -Force -ErrorAction SilentlyContinue
$result | ConvertTo-Json -Compress | Write-Output
if ($result.status -eq 'FAIL') { exit 1 } else { exit 0 }
