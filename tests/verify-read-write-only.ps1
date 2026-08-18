# ============================================================
# ARNES - verificacion: skills SOLO read + write
#
# Verifica que los archivos de instruccion de skills/prompts NO
# instruyan el uso de herramientas distintas a `read` y `write`:
#   - sin CLI PowerShell (.ps1 / powershell / Get-Content)
#   - sin bash
#   - sin edit
#   - sin tools de terceros (mem_save/mem_search/mem_get/delegate/task())
#   - sin comandos de proyecto (npm/vitest/playwright/tsc)
#   - sin tools no soportadas (grep/find/ls/cat/sed/webfetch/websearch)
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/verify-read-write-only.ps1
# Exit: 0 = PASS (limpio) | 1 = FAIL (se encontraron referencias)
# ============================================================
$ErrorActionPreference = 'Stop'

$targets = @(
    (Resolve-Path 'core/skills/*/SKILL.md'),
    (Resolve-Path 'core/classes/*.agent.md'),
    (Resolve-Path 'core/auditors/*.agent.md'),
    (Resolve-Path 'core/atlas-player.agent.md'),
    (Resolve-Path 'opencode.json')
)

$forbidden = @(
    '\.ps1',               # CLI PowerShell
    'powershell',          # bloques powershell
    'Get-Content',         # lectura por comando
    '\bbash\b',            # tool bash
    '\bedit\b',            # tool edit
    '\bdelegate\b',        # tool delegate
    'task\(',              # tool task()
    'mem_save',            # plugin memoria terceros
    'mem_search',
    'mem_get',
    'mem_context',
    '\bwebfetch\b',        # tools web no soportadas
    '\bwebsearch\b',
    '\bcontext7\b',
    'npm run',             # ejecucion de comandos del proyecto
    'npm test',
    '\btsc\b',
    '\bvitest\b',
    '\bplaywright\b',
    'Get-CimInstance',     # medicion de sistema
    'Get-PSDrive',
    '\bgrep\b',            # tools de archivo no soportadas
    '\bfind\b',
    '\bls\b',
    '\bcat\b',
    '\bsed\b'
)

$fail = $false
$totalIssues = 0

foreach ($pattern in $forbidden) {
    $regex = [regex]$pattern
    foreach ($target in $targets) {
        foreach ($file in $target) {
            $content = Get-Content -LiteralPath $file -Raw -Encoding UTF8
            $matches = $regex.Matches($content)
            if ($matches.Count -gt 0) {
                $fail = $true
                foreach ($m in $matches) {
                    $totalIssues++
                    $lineNo = ($content.Substring(0, $m.Index) -split "`n").Count
                    Write-Host ("FAIL  [{0}] patron '{1}' en linea {2}: {3}" -f (Split-Path $file -Leaf), $pattern, $lineNo, $m.Value) -ForegroundColor Red
                }
            }
        }
    }
}

if ($fail) {
    Write-Host ("`nRESULTADO: FAIL - {0} referencias a tools no permitidas." -f $totalIssues) -ForegroundColor Red
    Write-Host 'Regla: las skills usan SOLO `read` y `write` (sin edit, sin bash, sin CLI, sin tools no soportadas).' -ForegroundColor Red
    exit 1
}
else {
    Write-Host 'RESULTADO: PASS - ninguna referencia a tools no permitidas.' -ForegroundColor Green
    exit 0
}
