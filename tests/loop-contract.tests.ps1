# ============================================================
# ARNES - loop contract (Fase 3): contrato + intentos + causa
#
# Hermetico: ArnesDir temporal, sin APIs ni OSMA.
# Verifica: create (todos los campos), attempt (failure_signature/root_cause/
# remediation/strategy_delta), clasificador de causa por senales (6 casos),
# retry de UNA variable, FAIL sin remediation invalido, senales desconocidas,
# causes (agregado + firmas repetidas) y check (limites).
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/loop-contract.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$PSExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
$Cli = Join-Path $Root 'cli\loop-contract.ps1'
$work = Join-Path $Root ('.loop-contract-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$log = Join-Path $work 'loop-attempts.jsonl'

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Invoke-Contract {
    param([string[]]$ContractArgs, [switch]$AllowFail)
    # EAP local en Continue: con Stop, el stderr de un proceso nativo capturado con 2>&1
    # se promueve a error terminante y rompe el helper antes de leer el exit code.
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $text = (& $PSExe -NoProfile -ExecutionPolicy Bypass -File $Cli @ContractArgs 2>&1 | Out-String)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousEap
    }
    if ($code -ne 0 -and -not $AllowFail) { throw "loop-contract fallo (exit $code): $($text.Trim())" }
    return @{ text = $text; code = $code }
}

function Get-Attempts {
    if (-not (Test-Path -LiteralPath $log)) { return @() }
    return @(Get-Content -LiteralPath $log -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
}

try {
    # 1. create: el contrato persiste con todos los campos
    $null = Invoke-Contract @('-Action','create','-QuestId','Q-900','-Prompt','crea login con zod','-MaxIterations','3','-TokenBudget','8000','-ArnesDir',$work)
    $cFile = Join-Path $work 'loop-contracts\Q-900.json'
    Assert-That (Test-Path -LiteralPath $cFile) 'create escribe loop-contracts/Q-900.json'
    $c = Get-Content -LiteralPath $cFile -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-That ($c.type -eq 'loop_contract') 'type loop_contract'
    Assert-That ($c.quest_id -eq 'Q-900') 'quest_id'
    Assert-That (@($c.acceptance_criteria).Count -ge 1) 'acceptance_criteria presentes'
    Assert-That (@($c.verification).Count -ge 1) 'verification presentes'
    Assert-That ([int]$c.max_iterations -eq 3) 'max_iterations'
    Assert-That ([int]$c.token_budget -eq 8000) 'token_budget'
    Assert-That ($c.retry_policy.change_one_variable -eq $true) 'retry_policy.change_one_variable'
    Assert-That (@($c.stop_conditions).Count -ge 1) 'stop_conditions'

    # 2. attempt FAIL: registra firma/causa/remediacion/delta
    $null = Invoke-Contract @('-Action','attempt','-QuestId','Q-900','-Attempt','1','-Verdict','FAIL_PARTIAL','-FailureSignature','login 500','-Signals','code_defect','-Remediation','validar email en el form','-ArnesDir',$work)
    $a = @(Get-Attempts)
    Assert-That ($a.Count -eq 1) "attempt escribe 1 linea (obtenidas $($a.Count))"
    Assert-That ($a[0].failure_signature -eq 'login 500') 'failure_signature registrada'
    Assert-That ($a[0].root_cause -eq 'implementacion') "causa clasificada desde code_defect (obtenida $($a[0].root_cause))"
    Assert-That ($a[0].remediation -eq 'validar email en el form') 'remediation registrada'
    Assert-That ($a[0].strategy_delta -eq 'implementation') 'strategy_delta sugerido por causa'
    Assert-That ($a[0].strategy_delta_source -eq 'classifier') 'delta source classifier'

    # 3. clasificador: 6 casos sinteticos (precedencia incluida)
    $cases = @(
        @{ s = 'tool_error';        c = 'tool' },
        @{ s = 'env_issue';         c = 'entorno' },
        @{ s = 'spec_gap';          c = 'spec' },
        @{ s = 'context_missing';   c = 'contexto' },
        @{ s = 'code_defect';       c = 'implementacion' },
        @{ s = '';                  c = 'modelo' }
    )
    foreach ($case in $cases) {
        $classifyArgs = @('-Action','classify','-Json','-ArnesDir',$work)
        if ($case.s) { $classifyArgs = @('-Action','classify','-Signals',$case.s,'-Json','-ArnesDir',$work) }
        $r = Invoke-Contract $classifyArgs
        $j = $r.text | ConvertFrom-Json
        Assert-That ($j.cause -eq $case.c) "clasificador: '$($case.s)' -> $($case.c) (obtenido $($j.cause))"
    }
    $rPrec = Invoke-Contract @('-Action','classify','-Signals','context_missing,tool_error','-Json','-ArnesDir',$work)
    Assert-That ((($rPrec.text | ConvertFrom-Json).cause) -eq 'tool') 'precedencia: tool > contexto'

    # 4. strategy_delta: UNA variable; multiple -> exit 1
    $multi = Invoke-Contract @('-Action','attempt','-QuestId','Q-900','-Verdict','FAIL_PARTIAL','-Remediation','x','-StrategyDelta','model,context','-ArnesDir',$work) -AllowFail
    Assert-That ($multi.code -eq 1) "strategy_delta multiple -> exit 1 (obtenido $($multi.code))"
    Assert-That (@(Get-Attempts).Count -eq 1) 'attempt invalido no escribe'
    $one = Invoke-Contract @('-Action','attempt','-QuestId','Q-900','-Attempt','2','-Verdict','FAIL_PARTIAL','-Remediation','recompilar contexto','-StrategyDelta','model','-ArnesDir',$work)
    Assert-That ($one.code -eq 0) 'strategy_delta unico -> exit 0'

    # 5. FAIL sin remediation -> invalido (regla Tywin)
    $noRem = Invoke-Contract @('-Action','attempt','-QuestId','Q-900','-Verdict','FAIL_TOTAL','-ArnesDir',$work) -AllowFail
    Assert-That ($noRem.code -eq 1) "FAIL sin remediation -> exit 1 (obtenido $($noRem.code))"

    # 6. senal desconocida -> invalido
    $badSig = Invoke-Contract @('-Action','attempt','-QuestId','Q-900','-Verdict','FAIL_PARTIAL','-Remediation','x','-Signals','magia_negra','-ArnesDir',$work) -AllowFail
    Assert-That ($badSig.code -eq 1) "senal desconocida -> exit 1 (obtenido $($badSig.code))"

    # 7. causes: agrega por causa y detecta firmas repetidas
    $null = Invoke-Contract @('-Action','attempt','-QuestId','Q-901','-Attempt','1','-Verdict','FAIL_PARTIAL','-FailureSignature','login 500','-Signals','code_defect','-Remediation','otra vez','-ArnesDir',$work)
    $causes = Invoke-Contract @('-Action','causes','-Json','-ArnesDir',$work)
    $cj = $causes.text | ConvertFrom-Json
    Assert-That ([int]$cj.fails -eq 3) "causes: 3 FAIL (obtenido $($cj.fails))"
    $impl = @(@($cj.by_cause) | Where-Object { $_.cause -eq 'implementacion' })[0]
    Assert-That ([int]$impl.count -eq 2) "implementacion x2 (obtenido $($impl.count))"
    $sig = @(@($cj.repeated_signatures) | Where-Object { $_.signature -eq 'login 500' })[0]
    Assert-That ($null -ne $sig -and [int]$sig.count -eq 2) 'firma repetida detectada x2'

    # 8. check: limites del contrato
    $in = Invoke-Contract @('-Action','check','-QuestId','Q-900','-Attempt','2','-TokensUsed','5000','-Json','-ArnesDir',$work)
    $ij = $in.text | ConvertFrom-Json
    Assert-That ($ij.within_limits -eq $true) 'check dentro de limites'
    $out = Invoke-Contract @('-Action','check','-QuestId','Q-900','-Attempt','9','-TokensUsed','9000','-Json','-ArnesDir',$work)
    $oj = $out.text | ConvertFrom-Json
    Assert-That ($oj.within_limits -eq $false) 'check fuera de limites'
    Assert-That (@($oj.issues).Count -ge 2) 'check reporta ambos issues'

    # 9. attempt PASS: sin remediation y root_cause success
    $null = Invoke-Contract @('-Action','attempt','-QuestId','Q-900','-Attempt','3','-Verdict','PASS','-ArnesDir',$work)
    $last = @(Get-Attempts)[-1]
    Assert-That ($last.verdict -eq 'PASS') 'intento PASS registrado'
    Assert-That ($last.root_cause -eq 'success') 'PASS -> root_cause success'
    Assert-That ([string]::IsNullOrEmpty([string]$last.remediation)) 'PASS sin remediation'

    Write-Output 'PASS loop-contract: contrato, intentos con causa, clasificador, retry de una variable y agregados'
    exit 0
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
