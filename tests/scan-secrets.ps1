# ============================================================
# ARNES - escaneo de secretos sobre el arbol de trabajo
#
# Busca patrones de claves en archivos TRACKEADOS por git
# (excluye .git, node_modules, backups locales ignorados).
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/scan-secrets.ps1
# Exit: 0 = limpio | 1 = se encontraron patrones sospechosos
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')

# Archivos rastreados por git (lo que realmente se publicaria)
$files = @(& git -C $Root ls-files) | Where-Object {
    $_ -notmatch '(^|/)(\.git|node_modules)/' -and
    $_ -notmatch '\.(png|jpg|jpeg|gif|ico|woff2?|ttf|db)$'
}

$patterns = @(
    'sk-[A-Za-z0-9]{16,}',                       # claves OpenAI/Anthropic-style
    'ghp_[A-Za-z0-9]{20,}',                      # GitHub PAT
    'github_pat_[A-Za-z0-9_]{20,}',              # GitHub fine-grained PAT
    'AKIA[0-9A-Z]{16}',                          # AWS access key
    'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY',     # claves privadas
    '(?i)api_key["'']?\s*[:=]\s*["''][^"'']{16,}["'']'  # api_key con valor largo
)

$fail = $false
$total = 0
foreach ($rel in $files) {
    $path = Join-Path $Root ($rel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $content = Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    foreach ($pat in $patterns) {
        $m = [regex]::Matches($content, $pat)
        if ($m.Count -gt 0) {
            $fail = $true
            $total += $m.Count
            Write-Host ("  SECRETO [{0}] en {1}" -f $pat, $rel) -ForegroundColor Red
        }
    }
}

if ($fail) {
    Write-Host ("`n  RESULTADO: FAIL - {0} coincidencia(s) de secretos." -f $total) -ForegroundColor Red
    exit 1
}
Write-Host '  RESULTADO: PASS - sin secretos en archivos rastreados.' -ForegroundColor Green
exit 0
