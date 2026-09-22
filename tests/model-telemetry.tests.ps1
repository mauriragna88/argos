# ============================================================
# ARNES - telemetria de modelos (Fase 1): model-telemetry.ps1
#
# Hermetico: ArnesDir temporal, sin APIs ni OSMA.
# Verifica: record (campos completos, derivacion provider/route, reward por
# verdict), append-only en orden, stats -Json (success_pct/avg_tokens/quest_types),
# filtro por modelo, linea corrupta ignorada y stats vacio.
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/model-telemetry.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$PSExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
$Cli = Join-Path $Root 'cli\model-telemetry.ps1'
$work = Join-Path $Root ('.model-telemetry-test-' + [guid]::NewGuid().ToString('N'))
$fresh = Join-Path $Root ('.model-telemetry-empty-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$log = Join-Path $work 'model-runs.jsonl'

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Get-Runs {
    if (-not (Test-Path -LiteralPath $log)) { return @() }
    return @(Get-Content -LiteralPath $log -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
}

function Invoke-Telemetry {
    param([string[]]$TeleArgs, [switch]$AllowFail)
    # EAP local en Continue: con Stop, el stderr de un proceso nativo capturado con 2>&1
    # se promueve a error terminante y rompe el helper antes de leer el exit code.
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $text = (& $PSExe -NoProfile -ExecutionPolicy Bypass -File $Cli @TeleArgs 2>&1 | Out-String)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousEap
    }
    if ($code -ne 0 -and -not $AllowFail) { throw "model-telemetry fallo (exit $code): $($text.Trim())" }
    return @{ text = $text; code = $code }
}

try {
    # 1. record: todos los campos, con derivaciones desactivadas (todo explicito)
    $first = Invoke-Telemetry @('-Action','record','-Agent','vivi','-Model','opencode-go/deepseek-v4-flash','-Provider','opencode','-QuestId','Q-001','-QuestType','frontend','-Difficulty','3','-Route','pro','-Party','vivi,eiko','-TokensUsed','4500','-Verdict','PASS','-ArnesDir',$work)
    $runs = @(Get-Runs)
    Assert-That ($runs.Count -eq 1) "record escribe 1 linea (obtenidas $($runs.Count)); salida: $($first.text.Trim())"
    $r = $runs[0]
    Assert-That ($r.event -eq 'model_run') 'event = model_run'
    Assert-That ($r.agent -eq 'vivi') 'agent registrado'
    Assert-That ($r.model -eq 'opencode-go/deepseek-v4-flash') 'model registrado'
    Assert-That ($r.provider -eq 'opencode') 'provider registrado'
    Assert-That ($r.quest_id -eq 'Q-001') 'quest_id registrado'
    Assert-That ($r.quest_type -eq 'frontend') 'quest_type registrado'
    Assert-That ([int]$r.difficulty -eq 3) 'difficulty registrada'
    Assert-That ($r.route -eq 'pro') 'route registrada'
    Assert-That ($r.party -eq 'vivi,eiko') 'party registrado'
    Assert-That ([int]$r.tokens_used -eq 4500) 'tokens_used registrado'
    Assert-That ($r.verdict -eq 'PASS') 'verdict registrado'
    Assert-That ([double]$r.reward -eq 0.9) "PASS sin reward explicito -> 0.9 (obtenido $($r.reward))"
    Assert-That ([bool][datetime]::Parse([string]$r.ts)) 'ts parseable'

    # 2. derivaciones: provider del prefijo del modelo y route por dificultad
    $null = Invoke-Telemetry @('-Action','record','-Model','nvidia/deepseek-ai/deepseek-v4-flash','-QuestId','Q-002','-QuestType','backend','-Difficulty','5','-TokensUsed','1200','-Verdict','FAIL_PARTIAL','-ArnesDir',$work)
    $r2 = @(Get-Runs)[1]
    Assert-That ($r2.provider -eq 'nvidia') "provider derivado del modelo (obtenido $($r2.provider))"
    Assert-That ($r2.route -eq 'highest') "route derivada de D5 (obtenido $($r2.route))"
    Assert-That ($r2.agent -eq 'atlas') "agent default atlas (obtenido $($r2.agent))"
    Assert-That ([double]$r2.reward -eq 0.3) "FAIL_PARTIAL -> reward 0.3 (obtenido $($r2.reward))"

    # 3. FAIL_TOTAL -> reward negativo
    $null = Invoke-Telemetry @('-Action','record','-Model','nvidia/deepseek-ai/deepseek-v4-pro','-QuestId','Q-003','-QuestType','backend','-Difficulty','4','-TokensUsed','900','-Verdict','FAIL_TOTAL','-ArnesDir',$work)
    Assert-That ([double]@(Get-Runs)[2].reward -eq -0.8) 'FAIL_TOTAL -> reward -0.8'

    # 4. record sin -Model: exit 1 y no escribe
    $before = @(Get-Runs).Count
    $bad = Invoke-Telemetry @('-Action','record','-QuestId','Q-004','-ArnesDir',$work) -AllowFail
    Assert-That ($bad.code -eq 1) "record sin modelo -> exit 1 (obtenido $($bad.code))"
    Assert-That (@(Get-Runs).Count -eq $before) 'record invalido no escribe linea'

    # 5. append-only: el orden de insercion se conserva
    $questIds = (@(Get-Runs) | ForEach-Object { $_.quest_id }) -join ','
    Assert-That ($questIds -eq 'Q-001,Q-002,Q-003') "orden append-only preservado (obtenido $questIds)"

    # 6. stats -Json: agregados por model x route
    $stats = Invoke-Telemetry @('-Action','stats','-Json','-ArnesDir',$work)
    Assert-That ($stats.code -eq 0) 'stats exit 0'
    $json = $stats.text | ConvertFrom-Json
    Assert-That ([int]$json.total -eq 3) "stats total 3 (obtenido $($json.total))"
    $nvidiaFlash = @(@($json.by_model) | Where-Object { $_.model -match '^nvidia/deepseek-ai/deepseek-v4-flash' })[0]
    Assert-That ($null -ne $nvidiaFlash) 'stats incluye el modelo nvidia flash'
    Assert-That ([int]$nvidiaFlash.count -eq 1) 'count 1 para el flash'
    Assert-That ([int]$nvidiaFlash.pass -eq 0 -and [int]$nvidiaFlash.fail -eq 1) 'pass/fail del flash'
    Assert-That ([int]$nvidiaFlash.success_pct -eq 0) 'success_pct 0 para el fail'
    Assert-That ([int]$nvidiaFlash.avg_tokens -eq 1200) "avg_tokens 1200 (obtenido $($nvidiaFlash.avg_tokens))"
    Assert-That ([int]$nvidiaFlash.quest_types.backend -eq 1) 'quest_types.backend contado'

    # 7. stats -Model filtra
    $f = Invoke-Telemetry @('-Action','stats','-Json','-Model','nvidia/deepseek-ai/deepseek-v4-pro','-ArnesDir',$work)
    $fj = $f.text | ConvertFrom-Json
    Assert-That ([int]$fj.total -eq 1) "filtro por modelo -> total 1 (obtenido $($fj.total))"

    # 8. linea corrupta: no rompe stats y no se cuenta
    Add-Content -LiteralPath $log -Value 'esto-no-es-json{{{' -Encoding UTF8
    $c = Invoke-Telemetry @('-Action','stats','-Json','-ArnesDir',$work)
    Assert-That ($c.code -eq 0) 'stats tolera linea corrupta (exit 0)'
    Assert-That (([int](($c.text | ConvertFrom-Json).total)) -eq 3) 'la linea corrupta no se cuenta'

    # 9. stats sin datos: total 0 y exit 0
    New-Item -ItemType Directory -Path $fresh -Force | Out-Null
    $e = Invoke-Telemetry @('-Action','stats','-Json','-ArnesDir',$fresh)
    Assert-That ($e.code -eq 0) 'stats sin datos exit 0'
    Assert-That (([int](($e.text | ConvertFrom-Json).total)) -eq 0) 'stats sin datos total 0'

    Write-Output 'PASS model-telemetry: record (campos/derivaciones/reward), append-only, stats, filtro, tolerancia'
    exit 0
} finally {
    foreach ($d in @($work, $fresh)) {
        if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
    }
}
