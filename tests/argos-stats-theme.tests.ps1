# ============================================================
# ARNES - verificacion de argos stats (F3) y argos theme (F2)
#
# Crea un proyecto temporal con quest-ledger conocido y verifica
# el dashboard de stats y el round-trip del tema en config.json.
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/argos-stats-theme.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$StatsCli = Join-Path $Root 'cli\argos-stats.ps1'
$ThemeCli = Join-Path $Root 'cli\argos-theme.ps1'
$work = Join-Path $Root ('.arnes-stats-test-' + [guid]::NewGuid().ToString('N'))
$workArnes = Join-Path $work '.arnes'

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

New-Item -ItemType Directory -Path $workArnes -Force | Out-Null
try {
    # Ledger conocido: 5 quests en 3 dias consecutivos + 1 dia suelto.
    # Dias: hoy, ayer, antier (3 consecutivos) + hace 5 dias (suelto).
    # Mejor racha = 3, racha actual = 3 (si hoy cuenta) o 2 si hoy no activity.
    # Aqui hoy tiene quests -> racha actual = 3, mejor = 3.
    $today = (Get-Date).Date
    $ledger = [ordered]@{
        quests = @(
            [ordered]@{ agent = 'vivi';  verdict = 'PASS'; tokens_used = 100; quest_id = 'T-1'; timestamp = $today.AddDays(-5).ToString('o') },
            [ordered]@{ agent = 'ansem'; verdict = 'PASS'; tokens_used = 200; quest_id = 'T-2'; timestamp = $today.AddDays(-2).ToString('o') },
            [ordered]@{ agent = 'kuja';  verdict = 'PASS'; tokens_used = 300; quest_id = 'T-3'; timestamp = $today.AddDays(-1).ToString('o') },
            [ordered]@{ agent = 'eiko';   verdict = 'PASS'; tokens_used = 150; quest_id = 'T-4'; timestamp = $today.ToString('o') },
            [ordered]@{ agent = 'vivi';  verdict = 'FAIL'; tokens_used = 250; quest_id = 'T-5'; timestamp = $today.ToString('o') }
        )
    } | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath (Join-Path $workArnes 'quest-ledger.json') -Value $ledger -Encoding UTF8

    Push-Location $work
    try {
        # ==== STATS ====
        $stats = (& powershell -NoProfile -ExecutionPolicy Bypass -File $StatsCli | Out-String)
        Assert-That ($stats -match 'Quests:\s+5') "stats: 5 quests -> $stats"
        Assert-That ($stats -match 'Tasa de exito:\s+80%') "stats: 4/5 PASS = 80% -> $stats"
        Assert-That ($stats -match 'Tokens usados:\s+1000') "stats: tokens 1000 -> $stats"
        Assert-That ($stats -match 'Racha actual:\s+3 dias') "stats: racha actual 3 -> $stats"
        Assert-That ($stats -match 'Mejor racha:\s+3 dias') "stats: mejor racha 3 -> $stats"

        # ==== THEME ====
        $setOut = (& powershell -NoProfile -ExecutionPolicy Bypass -File $ThemeCli set -Name vivi | Out-String)
        Assert-That ($setOut -match "Tema cambiado a 'vivi'") "theme set vivi -> $setOut"
        $cfg = Get-Content (Join-Path $workArnes 'config.json') -Raw | ConvertFrom-Json
        Assert-That ([string]$cfg.theme -eq 'vivi') "config.json theme == vivi (obtenido $($cfg.theme))"
        $showOut = (& powershell -NoProfile -ExecutionPolicy Bypass -File $ThemeCli show | Out-String)
        Assert-That ($showOut -match 'vivi') "theme show refleja vivi -> $showOut"

        Write-Output 'PASS argos-stats-theme: dashboard, racha actual + mejor racha, y tema persiste'
        exit 0
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
