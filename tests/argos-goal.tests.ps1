# ============================================================
# ARNES - verificacion del modo autonomo por objetivo (argos goal)
#
# Hermetico: usa un stub de arnes-cycle (sin llamadas a APIs).
# Verifica: flujo FAIL->remediation->GOAL_COMPLETE, stop flag,
# limite de iteraciones y resume.
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/argos-goal.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$GoalCli = Join-Path $Root 'cli\argos-goal.ps1'
$Stub = Join-Path $Root 'tests\stubs\fake-cycle.ps1'
$work = Join-Path $Root ('.argos-goal-test-' + [guid]::NewGuid().ToString('N'))
$workArnes = Join-Path $work '.arnes'
New-Item -ItemType Directory -Path $workArnes -Force | Out-Null

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Get-GoalState {
    Get-Content (Join-Path $workArnes 'goal-state.json') -Raw | ConvertFrom-Json
}

try {
    Push-Location $work
    try {
        # ==== 1. Flujo completo: FAIL -> remediation como siguiente prompt -> GOAL_COMPLETE ====
        & powershell -NoProfile -ExecutionPolicy Bypass -File $GoalCli -Goal "plataforma escolar" -MaxIterations 5 -PauseSeconds 0 -CycleCommand $Stub | Out-Null
        $code = $LASTEXITCODE
        Assert-That ($code -eq 0) "goal completa con exit 0 (obtenido $code)"
        $state = Get-GoalState
        Assert-That ($state.status -eq 'done') "estado done (obtenido $($state.status))"
        Assert-That ($state.last_decision -eq 'GOAL_COMPLETE') "decision final GOAL_COMPLETE"
        Assert-That ($state.iteration -eq 2) "2 iteraciones (obtenido $($state.iteration))"
        Assert-That ($state.next_prompt -match 'login') "el siguiente prompt heredo la remediation ('login')"
        Assert-That ($state.history.Count -eq 2) "historial con 2 entradas (obtenido $($state.history.Count))"
        Assert-That ($state.history[0].remediation -match 'login') "historial[0] guarda la remediation"
        Assert-That ([string]$state.history[0].sequence -match '\[atlas\]') "historial[0] guarda la secuencia (bitacora)"

        # ==== 2. Stop flag detiene en la siguiente iteracion ====
        Remove-Item (Join-Path $workArnes 'stub-count.txt') -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $workArnes 'goal-state.json') -Force -ErrorAction SilentlyContinue
        Set-Content -Path (Join-Path $workArnes 'autowork-stop') -Value 'stop' -Encoding UTF8
        & powershell -NoProfile -ExecutionPolicy Bypass -File $GoalCli -Goal "otro objetivo" -MaxIterations 5 -PauseSeconds 0 -CycleCommand $Stub | Out-Null
        $state = Get-GoalState
        Assert-That ($state.status -eq 'stopped') "stop flag -> status stopped (obtenido $($state.status))"
        Assert-That (-not (Test-Path (Join-Path $workArnes 'autowork-stop'))) 'stop flag consumido'

        # ==== 3. Limite de iteraciones (stub siempre FAIL) ====
        Remove-Item (Join-Path $workArnes 'goal-state.json') -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $workArnes 'stub-count.txt') -Force -ErrorAction SilentlyContinue
        $env:ARNES_FAKE_ALWAYS_FAIL = '1'
        try {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $GoalCli -Goal "objetivo imposible" -MaxIterations 2 -PauseSeconds 0 -CycleCommand $Stub | Out-Null
        } finally {
            Remove-Item Env:\ARNES_FAKE_ALWAYS_FAIL -ErrorAction SilentlyContinue
        }
        $state = Get-GoalState
        Assert-That ($state.status -eq 'running') "limite -> status running (obtenido $($state.status))"
        Assert-That ($state.iteration -eq 2) "limite en iteracion 2 (obtenido $($state.iteration))"

        # ==== 4. Resume continua desde donde quedo ====
        $env:ARNES_FAKE_ALWAYS_FAIL = '1'
        try {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $GoalCli -Goal "objetivo imposible" -MaxIterations 5 -PauseSeconds 0 -CycleCommand $Stub -Resume | Out-Null
        } finally {
            Remove-Item Env:\ARNES_FAKE_ALWAYS_FAIL -ErrorAction SilentlyContinue
        }
        $state = Get-GoalState
        Assert-That ($state.iteration -ge 3) "resume continua desde iteracion 3+ (obtenido $($state.iteration))"

        # ==== 5. arnes-cycle mantiene el contrato Goal/EmitJson/MemoryContext ====
        $cycle = Get-Content (Join-Path $Root 'cli\argos-cycle.ps1') -Raw
        Assert-That ($cycle -match '\[string\]\$Goal') 'arnes-cycle: param Goal presente'
        Assert-That ($cycle -match '\[switch\]\$EmitJson') 'arnes-cycle: param EmitJson presente'
        Assert-That ($cycle -match 'GOAL_COMPLETE') 'arnes-cycle: detecta GOAL_COMPLETE'
        Assert-That ($cycle -match '\[string\]\$MemoryContext') 'arnes-cycle: param MemoryContext presente'
        Assert-That ($cycle -match 'CONTEXTO DE MEMORIA') 'arnes-cycle: inyecta el contexto en la decision de Atlas'
        Assert-That ($cycle -match 'atlas/debriefs/') 'arnes-cycle: guarda debrief a memoria'
        Assert-That ($cycle -match 'varys/evidence-packs/') 'arnes-cycle: Varys guarda la bitacora de secuencia'
        Assert-That ($cycle -match 'Bitacora de secuencia') 'arnes-cycle: compila la bitacora ordenada'

        Write-Output 'PASS argos-goal: autowork (remediation->next prompt, stop, limite, resume)'
        exit 0
    } finally { Pop-Location }
} finally {
    Remove-Item Env:\ARNES_FAKE_ALWAYS_FAIL -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
