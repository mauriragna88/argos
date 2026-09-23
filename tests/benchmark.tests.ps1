# ============================================================
# ARNES - benchmark interno del harness (Fase 6): benchmark.ps1
#
# Hermetico: ArnesDir temporal, sin APIs ni OSMA.
# Verifica: record (baseline/argos + metricas), validaciones, report -Json con
# stats por modelo y veredicto del criterio central (argos >= baseline en PASS
# rate), y list/sin datos.
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/benchmark.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$PSExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
$Cli = Join-Path $Root 'cli\benchmark.ps1'
$work = Join-Path $Root ('.benchmark-test-' + [guid]::NewGuid().ToString('N'))
$empty = Join-Path $Root ('.benchmark-empty-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$log = Join-Path $work 'benchmarks.jsonl'

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Invoke-Bench {
    param([string[]]$BenchArgs, [switch]$AllowFail)
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $text = (& $PSExe -NoProfile -ExecutionPolicy Bypass -File $Cli @BenchArgs 2>&1 | Out-String)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousEap
    }
    if ($code -ne 0 -and -not $AllowFail) { throw "benchmark fallo (exit $code): $($text.Trim())" }
    return @{ text = $text; code = $code }
}

function Parse-Json { param([string]$Text) return ($Text | ConvertFrom-Json) }

try {
    # 1. record: baseline FAIL y argos PASS del mismo modelo
    $null = Invoke-Bench @('-Action','record','-Model','opencode-go/deepseek-v4-flash','-Config','baseline','-QuestId','Q-900','-Verdict','FAIL_PARTIAL','-Tokens','9000','-CostUsd','0.02','-LatencyMs','45000','-Loops','3','-ArnesDir',$work)
    $null = Invoke-Bench @('-Action','record','-Model','opencode-go/deepseek-v4-flash','-Config','argos','-QuestId','Q-900','-Verdict','PASS','-Tokens','6000','-CostUsd','0.01','-LatencyMs','30000','-Loops','1','-FirstPass','-ArnesDir',$work)
    $runs = @(Get-Content -LiteralPath $log | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
    Assert-That ($runs.Count -eq 2) "2 corridas registradas (obtenidas $($runs.Count))"
    Assert-That ($runs[0].config -eq 'baseline' -and $runs[1].config -eq 'argos') 'config baseline/argos'
    Assert-That ($runs[1].first_pass -eq $true) 'first_pass registrado'
    Assert-That ([int]$runs[0].tokens -eq 9000) 'tokens registrados'

    # 2. record sin -Model / sin -Config -> exit 1
    $bad1 = Invoke-Bench @('-Action','record','-Config','argos','-Verdict','PASS','-ArnesDir',$work) -AllowFail
    Assert-That ($bad1.code -eq 1) "record sin modelo -> exit 1 (obtenido $($bad1.code))"
    $bad2 = Invoke-Bench @('-Action','record','-Model','x/y','-Verdict','PASS','-ArnesDir',$work) -AllowFail
    Assert-That ($bad2.code -eq 1) "record sin config -> exit 1 (obtenido $($bad2.code))"

    # 3. report -Json: stats y veredicto central
    $rep = Parse-Json (Invoke-Bench @('-Action','report','-Json','-ArnesDir',$work)).text
    Assert-That ([int]$rep.total_runs -eq 2) "total_runs 2 (obtenido $($rep.total_runs))"
    $m = @($rep.models)[0]
    Assert-That ($m.model -eq 'opencode-go/deepseek-v4-flash') 'modelo en el reporte'
    Assert-That ([int]$m.baseline.pass_rate_pct -eq 0) "baseline pass 0% (obtenido $($m.baseline.pass_rate_pct))"
    Assert-That ([int]$m.argos.pass_rate_pct -eq 100) "argos pass 100% (obtenido $($m.argos.pass_rate_pct))"
    Assert-That ([int]$m.argos.avg_tokens -eq 6000) "avg_tokens argos 6000 (obtenido $($m.argos.avg_tokens))"
    Assert-That ($m.verdict -like 'argos>=baseline*') "veredicto central cumplido (obtenido $($m.verdict))"

    # 4. argos peor que baseline -> veredicto de revision
    $work2 = Join-Path $Root ('.benchmark-test2-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work2 -Force | Out-Null
    $null = Invoke-Bench @('-Action','record','-Model','m/x','-Config','baseline','-Verdict','PASS','-ArnesDir',$work2)
    $null = Invoke-Bench @('-Action','record','-Model','m/x','-Config','argos','-Verdict','FAIL_TOTAL','-ArnesDir',$work2)
    $rep2 = Parse-Json (Invoke-Bench @('-Action','report','-Json','-ArnesDir',$work2)).text
    Assert-That ((@($rep2.models)[0].verdict) -like 'argos<baseline*') 'argos peor -> veredicto de revision'

    # 5. list y report sin datos
    $list = Parse-Json (Invoke-Bench @('-Action','list','-Json','-ArnesDir',$work)).text
    Assert-That (@($list).Count -eq 2) "list devuelve 2 (obtenido $(@($list).Count))"
    New-Item -ItemType Directory -Path $empty -Force | Out-Null
    $repEmpty = Parse-Json (Invoke-Bench @('-Action','report','-Json','-ArnesDir',$empty)).text
    Assert-That ([int]$repEmpty.total -eq 0) 'report sin datos -> total 0'

    Write-Output 'PASS benchmark: record baseline/argos, validaciones, report con criterio central y list'
    exit 0
} finally {
    foreach ($d in @($work, $empty, (Join-Path $Root '.benchmark-test2-'))) {
        Get-ChildItem -Path (Join-Path $Root '.benchmark-test2-*') -Directory -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
        if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
    }
}
