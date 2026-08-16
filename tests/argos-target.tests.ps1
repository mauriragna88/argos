# ============================================================
# ARNES - verificacion del selector de entorno (argos target)
#
# Hermetico: usa ConfigDir/TargetDir temporales y -NoLaunch.
# Verifica: list, set, show, y despliegue de AGENTS.md/CLAUDE.md (incluye target freebuff).
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/argos-target.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$PSExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
$TargetCli = Join-Path $Root 'cli\argos-target.ps1'
$work = Join-Path $Root ('.argos-target-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

try {
    # 1. list no falla y lista los 3 targets
    $list = (& $PSExe -NoProfile -ExecutionPolicy Bypass -File $TargetCli list -ConfigDir $work | Out-String)
    Assert-That ($list -match 'opencode') 'list muestra opencode'
    Assert-That ($list -match 'codex') 'list muestra codex'
    Assert-That ($list -match 'claude') 'list muestra claude'
    Assert-That ($list -match 'freebuff') 'list muestra freebuff'

    # 2. set persiste el default
    $set = (& $PSExe -NoProfile -ExecutionPolicy Bypass -File $TargetCli set -Name codex -ConfigDir $work | Out-String)
    Assert-That ($set -match "Target default: codex") "set codex -> $set"
    $cfg = Get-Content (Join-Path $work 'target.json') -Raw | ConvertFrom-Json
    Assert-That ([string]$cfg.target -eq 'codex') "target.json == codex (obtenido $($cfg.target))"

    # 3. show refleja el default
    $show = (& $PSExe -NoProfile -ExecutionPolicy Bypass -File $TargetCli show -ConfigDir $work | Out-String)
    Assert-That ($show -match 'Target actual: codex') "show refleja codex -> $show"

    # 4. launch codex -NoLaunch despliega AGENTS.md con roster
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File $TargetCli -Target codex -NoLaunch -ConfigDir $work -TargetDir $work | Out-Null
    Assert-That (Test-Path (Join-Path $work 'AGENTS.md')) 'AGENTS.md desplegado'
    $agents = Get-Content (Join-Path $work 'AGENTS.md') -Raw
    Assert-That ($agents -match 'ARNES ARGOS - Atlas') 'AGENTS.md contiene la persona Atlas'
    Assert-That ($agents -match 'Party ARNES') 'AGENTS.md contiene el roster del party'

    # 5. launch claude -NoLaunch despliega CLAUDE.md + party completo de 16
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File $TargetCli -Target claude -NoLaunch -ConfigDir $work -TargetDir $work | Out-Null
    Assert-That (Test-Path (Join-Path $work 'CLAUDE.md')) 'CLAUDE.md desplegado'
    $claudeAgents = @(Get-ChildItem (Join-Path $work 'agents\*.md') -ErrorAction SilentlyContinue)
    Assert-That ($claudeAgents.Count -eq 16) "claude agents = 16 (obtenido $($claudeAgents.Count))"
    foreach ($ca in $claudeAgents) {
        $c = Get-Content $ca.FullName -Raw
        Assert-That ($c -match '^---\r?\nname:') "frontmatter valido en $($ca.Name)"
    }

    # 6. launch freebuff -NoLaunch despliega AGENTS.md del proyecto (persona + roster)
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File $TargetCli -Target freebuff -NoLaunch -ConfigDir $work -TargetDir $work | Out-Null
    Assert-That (Test-Path (Join-Path $work 'AGENTS.md')) 'freebuff: AGENTS.md desplegado'
    $fbAgents = Get-Content (Join-Path $work 'AGENTS.md') -Raw
    Assert-That ($fbAgents -match 'ARNES ARGOS - Atlas') 'freebuff: AGENTS.md contiene la persona Atlas'
    Assert-That ($fbAgents -match 'Party ARNES') 'freebuff: AGENTS.md contiene el roster del party'

    # 7. argos.ps1 parsea (dispatch agregado)
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'cli\argos.ps1'), [ref]$tokens, [ref]$errors) | Out-Null
    Assert-That ($errors.Count -eq 0) 'argos.ps1 parsea con el case target'

    Write-Output 'PASS argos-target: list/set/show y despliegue AGENTS.md/CLAUDE.md/Freebuff'
    exit 0
} finally {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
