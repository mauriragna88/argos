# ============================================================
# ARNES - regression factory (Fase 5): regression.ps1
#
# Hermetico: ArnesDir temporal, sin APIs ni OSMA.
# Verifica: suggest (candidata persistida con guard_type inferido + dedup),
# create (trazabilidad, missing_file, no-duplicacion, params obligatorios),
# list (solo guards, filtra sugerencias) y check (existe/no existe).
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/regression.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$PSExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
$Cli = Join-Path $Root 'cli\regression.ps1'
$work = Join-Path $Root ('.regression-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$log = Join-Path $work 'regressions.jsonl'
$guardFile = Join-Path $work 'guard-404.test.ts'

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Invoke-Regression {
    param([string[]]$RegArgs, [switch]$AllowFail)
    # EAP local en Continue: con Stop, el stderr de un proceso nativo capturado con 2>&1
    # se promueve a error terminante y rompe el helper antes de leer el exit code.
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $text = (& $PSExe -NoProfile -ExecutionPolicy Bypass -File $Cli @RegArgs 2>&1 | Out-String)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousEap
    }
    if ($code -ne 0 -and -not $AllowFail) { throw "regression fallo (exit $code): $($text.Trim())" }
    return @{ text = $text; code = $code }
}

function Get-Log {
    if (-not (Test-Path -LiteralPath $log)) { return @() }
    return @(Get-Content -LiteralPath $log -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
}

try {
    # 1. suggest: candidata persistida con guard_type inferido (contract)
    $null = Invoke-Regression @('-Action','suggest','-QuestId','Q-901','-Verdict','PASS','-Prompt','fix schema api contract drift','-ArnesDir',$work)
    $items = @(Get-Log)
    Assert-That ($items.Count -eq 1) "suggest persiste 1 linea (obtenidas $($items.Count))"
    Assert-That ($items[0].event -eq 'regression_suggestion') 'event regression_suggestion'
    Assert-That ($items[0].guard_type -eq 'contract') "guard_type inferido contract (obtenido $($items[0].guard_type))"
    Assert-That (-not [string]::IsNullOrWhiteSpace([string]$items[0].failure_signature)) 'failure_signature presente'

    # 2. suggest: dedup por quest + firma
    $null = Invoke-Regression @('-Action','suggest','-QuestId','Q-901','-Verdict','PASS','-Prompt','fix schema api contract drift','-ArnesDir',$work)
    Assert-That (@(Get-Log).Count -eq 1) 'suggest duplicada no se repite'

    # 3. suggest infiere security para RLS
    $null = Invoke-Regression @('-Action','suggest','-QuestId','Q-902','-Verdict','PASS','-Prompt','rls policy faltante en supabase','-ArnesDir',$work)
    $sec = @(Get-Log) | Where-Object { $_.quest_id -eq 'Q-902' }
    Assert-That ($sec.guard_type -eq 'security') "RLS -> guard_type security (obtenido $($sec.guard_type))"

    # 4. create: guard con archivo existente -> active + trazabilidad
    Set-Content -LiteralPath $guardFile -Value 'test("404", () => {})' -Encoding UTF8
    $null = Invoke-Regression @('-Action','create','-QuestId','Q-901','-GuardType','unit','-GuardPath',$guardFile,'-FailureSignature','404 route','-ArnesDir',$work)
    $guard = @(Get-Log) | Where-Object { $_.event -eq 'regression_guard' }
    Assert-That ($null -ne $guard) 'guard registrado'
    Assert-That ($guard.status -eq 'active') "guard con archivo -> active (obtenido $($guard.status))"
    Assert-That ($guard.guard_exists -eq $true) 'guard_exists true'
    Assert-That ($guard.failure_signature -eq '404 route') 'failure_signature del guard'
    Assert-That ($guard.created_by -eq 'kuja') 'created_by kuja (default)'

    # 5. create: guard sin archivo -> missing_file
    $null = Invoke-Regression @('-Action','create','-QuestId','Q-903','-GuardType','unit','-GuardPath',(Join-Path $work 'no-existe.test.ts'),'-FailureSignature','otro bug','-ArnesDir',$work)
    $missing = @(Get-Log) | Where-Object { $_.quest_id -eq 'Q-903' -and $_.event -eq 'regression_guard' }
    Assert-That ($missing.status -eq 'missing_file') "guard sin archivo -> missing_file (obtenido $($missing.status))"

    # 6. create: no-duplicacion (misma firma + tipo + quest)
    $before = @(@(Get-Log) | Where-Object { $_.event -eq 'regression_guard' }).Count
    $dup = Invoke-Regression @('-Action','create','-QuestId','Q-901','-GuardType','unit','-GuardPath',$guardFile,'-FailureSignature','404 route','-Json','-ArnesDir',$work)
    $dj = $dup.text | ConvertFrom-Json
    Assert-That ($dj.ok -eq $false -and $dj.reason -eq 'duplicate') 'create duplicado -> ok=false duplicate'
    Assert-That (@(@(Get-Log) | Where-Object { $_.event -eq 'regression_guard' }).Count -eq $before) 'duplicado no escribe'

    # 7. create sin parametros -> exit 1
    $bad = Invoke-Regression @('-Action','create','-QuestId','Q-901','-ArnesDir',$work) -AllowFail
    Assert-That ($bad.code -eq 1) "create incompleto -> exit 1 (obtenido $($bad.code))"

    # 8. list: solo guards (no suggestions) + filtro por quest
    # PS 5.1 no desenrolla arrays de ConvertFrom-Json en pipeline: se asigna a variable y se envuelve.
    $list = Invoke-Regression @('-Action','list','-Json','-ArnesDir',$work)
    $parsedList = $list.text | ConvertFrom-Json
    $lj = @($parsedList)
    $guardCount = @(@(Get-Log) | Where-Object { $_.event -eq 'regression_guard' }).Count
    Assert-That ($lj.Count -eq $guardCount) "list devuelve solo guards ($guardCount) (obtenido $($lj.Count))"
    Assert-That (@($lj | Where-Object { $_.quest_id -eq 'Q-903' }).Count -eq 1) 'list filtrable por quest'
    $one = Invoke-Regression @('-Action','list','-Json','-QuestId','Q-901','-ArnesDir',$work)
    $parsedOne = $one.text | ConvertFrom-Json
    $oj = @($parsedOne)
    Assert-That ($oj.Count -eq 1 -and $oj[0].guard_path -eq $guardFile) 'list -QuestId filtra correctamente'

    # 9. check: existe / no existe
    $chk = Invoke-Regression @('-Action','check','-GuardPath',$guardFile,'-Json','-ArnesDir',$work)
    Assert-That ((($chk.text | ConvertFrom-Json).exists) -eq $true) 'check: guard existe'
    $chk2 = Invoke-Regression @('-Action','check','-GuardPath',(Join-Path $work 'nope.test.ts'),'-Json','-ArnesDir',$work)
    Assert-That ((($chk2.text | ConvertFrom-Json).exists) -eq $false) 'check: guard no existe'

    Write-Output 'PASS regression: suggest (persistida + dedup + tipo), create (active/missing/duplicado), list (solo guards) y check'
    exit 0
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
