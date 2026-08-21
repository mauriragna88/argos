#Requires -Version 5.1
<#
.SYNOPSIS
AUDITOR DE REPOS - chequeo de seguridad de repositorios (skill auron-repo-audit).

.DESCRIPTION
Ejecuta sobre el repo actual (o el que se pase con -RepoPath) tres chequeos:
  1. Escaneo de secretos en archivos TRACKEADOS por git (lo que se publicaria).
     Amplia tests/scan-secrets.ps1 con mas patrones (JWT supabase, sb_secret_,
     conekta/mp, tokens commandcode/opencode, .env commiteados...).
  2. Verificacion de visibilidad del repositorio en GitHub (publico/privado)
     usando la API de GitHub (gh) leyendo el remote origin.
  3. Deteccion de archivos sensibles commiteados (.env) y de la presencia de
     claves hardcodeadas con valor largo.

Salida: PASS/FAIL por seccion + exit code 0 = limpio, 1 = hallazgos.

.USAGE
powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-audit.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-audit.ps1 -RepoPath "C:\path\otro-repo"
powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-audit.ps1 -SkipVisibility   # no llama gh
.EXAMPLE
# En CI/run-all se invoca sin args para auditar el repo del harness.
# Auron lo usa para emitir verdict de seguridad de cualquier repo remoto.
#>
param(
    [string]$RepoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')),
    [switch]$SkipVisibility,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$root = if ([System.IO.Path]::IsPathRooted($RepoPath)) { $RepoPath } else { (Join-Path $PWD $RepoPath) }
$root = (Resolve-Path $root).Path
$fail = $false

function Write-Fail { param([string]$Msg) Write-Host ("  [FALLA] {0}" -f $Msg) -ForegroundColor Red }
function Write-Info { param([string]$Msg) if (-not $Quiet) { Write-Host ("  . {0}" -f $Msg) -ForegroundColor Gray } }
function Write-Head { param([string]$Msg) Write-Host ("===== {0} =====" -f $Msg) -ForegroundColor Cyan }

# ============================================================
# 1. ESCANEO DE SECRETOS EN ARCHIVOS TRACKEADOS
# ============================================================
Write-Head '1. Secretos en archivos trackeados'
if (-not (Test-Path (Join-Path $root '.git'))) {
    Write-Fail "No es un repo git: $root"
    Write-Host '  RESULTADO 1: FAIL' -ForegroundColor Red
    $fail = $true
} else {
    $files = @(& git -C $root ls-files 2>$null) | Where-Object {
        $_ -notmatch '(^|/)(\.git|node_modules|dist|build)/' -and
        $_ -notmatch '\.(png|jpg|jpeg|gif|ico|woff2?|ttf|db|lock)$' -and
        $_ -notmatch '(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock)$' -and
        # Excluir los propios scripts de auditoría de secretos (definen los patrones)
        $_ -notmatch '(^|/)tests/(scan-secrets|repo-audit)\.ps1$'
    }

    $patterns = @(
        'sk-[A-Za-z0-9]{16,}',                                   # OpenAI/Anthropic-style
        'ghp_[A-Za-z0-9]{20,}',                                  # GitHub PAT
        'github_pat_[A-Za-z0-9_]{20,}',                          # GitHub fine-grained PAT
        'gho_[A-Za-z0-9]{20,}',                                  # GitHub OAuth token
        'AKIA[0-9A-Z]{16}',                                      # AWS access key
        'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY',                 # claves privadas
        'sb_secret_[A-Za-z0-9]{20,}',                            # Supabase service role (nuevo formato)
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',                 # Supabase JWT (anon/service)
        'key_(live|test)_[A-Za-z0-9]{10,}',                      # Conekta / Stripe
        'APP_USR-[A-Za-z0-9_-]{16,}',                            # MercadoPago app token
        'user_[A-Za-z0-9]{20,}',                                 # commandcode/opencode bearer
        '(?i)api_key["'']?\s*[:=]\s*["''][^"'']{16,}["'']',       # api_key con valor largo
        '(?i)secret\s*[:=]\s*["''][A-Za-z0-9]{20,}["'']',         # "secret": valor largo
        '(?i)password\s*[:=]\s*["''][^"'']{8,}["'']'              # password con valor (filtra placeholders)
    )

    $secretsFound = @()
    foreach ($rel in $files) {
        $path = Join-Path $root ($rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $content = Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        foreach ($pat in $patterns) {
            foreach ($m in [regex]::Matches($content, $pat)) {
                $val = $m.Value
                # Ignorar placeholders obvios y referencias a variables de entorno
                if ($val -match '(?i)xxxx|example|your_|your-key|tk_|REPLACE_|change_me|placeholder') { continue }
                if ($val -match '(?i)env\(|\[hidden\]|\[\*\*\*\]|\*\*\*|REDACTED|removed|omitido') { continue }
                # api_key: ignorar cuando el valor es un nombre de variable (env o mayusculas)
                if ($pat -match 'api_key' -and $val -match '(?i)env\(|[A-Z][A-Z_]{3,}') { continue }
                # password: ignorar literales cortos de validacion o calles de log
                if ($pat -match 'password' -and $val -match '(?i)requerid|required|obligat|tiene|hidden|es requ|contras|password es|contrase|\[hidden\]') { continue }
                $secretsFound += ("[{0}] {1} : {2}" -f $pat, $rel, ($val -replace '(?i)(sk-|ghp_|gho_|sb_secret_|key_(live|test)_|APP_USR-|user_|eyJ|AKIA)[A-Za-z0-9]{8,}', '$1***'))
            }
        }
    }

    # Archivos sensibles commiteados (sin valor real pero mal practica)
    $envFiles = @($files | Where-Object { $_ -match '(^|/)\.env$' })
    if ($envFiles.Count -gt 0) {
        foreach ($ef in $envFiles) { Write-Fail "Archivo .env commiteado: $ef" }
    }

    if ($secretsFound.Count -gt 0) {
        $fail = $true
        Write-Host '  Hallazgos de secretos:' -ForegroundColor Red
        $secretsFound | ForEach-Object { Write-Host ("    - {0}" -f $_) -ForegroundColor Yellow }
        Write-Host ("  RESULTADO 1: FAIL - {0} coincidencia(s)" -f $secretsFound.Count) -ForegroundColor Red
    } else {
        Write-Info "scanned $($files.Count) archivos trackeados"
        if ($envFiles.Count -eq 0) { Write-Host '  RESULTADO 1: PASS - sin secretos' -ForegroundColor Green }
        else {
            Write-Host ("  RESULTADO 1: FAIL - {0} .env commiteado(s)" -f $envFiles.Count) -ForegroundColor Red
        }
    }
}

# ============================================================
# 2. VISIBILIDAD DEL REPOSITORIO (publico/privado en GitHub)
# ============================================================
if (-not $SkipVisibility) {
    Write-Head '2. Visibilidad del repo en GitHub'
    $remoteUrl = ''
    # Capturar remoto sin dejar que git (exit != 0) dispare un NativeCommandError visible
    $remoteUrl = & { cmd /c "git -C `"$root`" remote get-url origin 2>nul" } | Select-Object -First 1
    if (-not $remoteUrl) {
        Write-Info 'Sin remote origin configurado (repo solo local).'
        Write-Host '  RESULTADO 2: SKIP (sin remote)' -ForegroundColor Yellow
    } else {
        # Extraer "owner/repo" de https://github.com/owner/repo.git
        $slug = if ($remoteUrl -match 'github\.com[:/]([^/\s]+)/([^/\s]+?)(\.git)?$') {
            "$($Matches[1])/$($Matches[2] -replace '\.git$','')"
        } else { $null }

        if (-not $slug) {
            Write-Info "Remote no apunta a github.com: $remoteUrl"
            Write-Host '  RESULTADO 2: SKIP (remote no-GitHub)' -ForegroundColor Yellow
        } else {
            $vis = $null
            try {
                $json = gh repo view $slug --json visibility,isPrivate,url 2>$null
                $o = $json | ConvertFrom-Json
                $vis = $o.visibility
                Write-Info "remote origin -> $slug"
                $private = if ($vis -eq 'PRIVATE' -or $vis -eq 'INTERNAL') { $true } else { $false }
                if ($private) {
                    Write-Host ("  RESULTADO 2: PASS - visible como {0} (privado)" -f $vis.ToUpper()) -ForegroundColor Green
                } else {
                    # Repos del harness (aprender) pueden quedarse publicos; pero se reporta por si acaso
                    Write-Host ("  ADVERTENCIA: repo PUBLICO ({0}) - verificar que documentacion/README no filtre secrets" -f $vis.ToUpper()) -ForegroundColor Yellow
                    Write-Host '  RESULTADO 2: PASS (se reporta pero no bloquea; decidir por dominio)' -ForegroundColor Green
                }
            } catch {
                Write-Info ("gh no disponible o sin auth. Salida: {0}" -f $_.Exception.Message)
                Write-Host '  RESULTADO 2: SKIP (no se pudo consultar visibilidad)' -ForegroundColor Yellow
            }
        }
    }
}

# ============================================================
# 3. RESUMEN
# ============================================================
Write-Host ''
if ($fail) {
    Write-Host '  AUDITORIA REPO: FAIL - revisar hallazgos y rotar/eliminar credenciales.' -ForegroundColor Red
    exit 1
}
Write-Host '  AUDITORIA REPO: PASS - sin hallazgos criticos.' -ForegroundColor Green
exit 0