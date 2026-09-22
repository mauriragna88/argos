# ============================================================
# ARNES - auto-inyeccion de skills por agente (Get-AgentSkills)
#
# Hermetico: extrae la funcion Get-AgentSkills de argos-code/argos-party
# via AST y la ejecuta con un HOME y un repo temporales (sin llamadas a APIs).
# Verifica: el mapa de vivi (incluye impeccable), la resolucion
# repo -> core/skills/v2 -> hogar (~/.agents/skills y ~/.config/opencode/skills),
# que el frontmatter se elimina y que una skill sin fuente se omite sin romper.
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/agent-skills.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$work = Join-Path $Root ('.agent-skills-test-' + [guid]::NewGuid().ToString('N'))
$fakeHome = Join-Path $work 'home'
$fakeRepo = Join-Path $work 'repo'
$emptyHome = Join-Path $work 'home-vacio'
$emptyRepo = Join-Path $work 'repo-vacio'
$previousHome = $env:USERPROFILE

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Write-Fixture {
    param([string]$Path, [string]$Marker)
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $content = "---`nname: fixture`ndescription: Fixture hermetico`n---`n`n# Fixture`n$Marker`n"
    [System.IO.File]::WriteAllText($Path, $content, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-SkillsFunctionText {
    param([string]$ScriptPath)
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$errors)
    Assert-That ($errors.Count -eq 0) "$ScriptPath parsea sin errores"
    $fns = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-AgentSkills' }, $true))
    Assert-That ($fns.Count -eq 1) "Get-AgentSkills encontrada en $ScriptPath (obtenidas $($fns.Count))"
    return $fns[0].Extent.Text
}

function Invoke-AgentSkills {
    param([string]$ScriptPath, [string]$RepoRoot, [string]$HomePath, [string]$Key = 'vivi')
    $fnText = Get-SkillsFunctionText -ScriptPath $ScriptPath
    $sb = [scriptblock]::Create($fnText + "`n Get-AgentSkills -Key '$Key'")
    $env:USERPROFILE = $HomePath
    try {
        return (& { $Root = $RepoRoot; & $sb })
    } finally {
        $env:USERPROFILE = $previousHome
    }
}

try {
    # Fixtures: repo (.agents/skills + core/skills/v2) y hogar (~/.agents/skills + ~/.config/opencode/skills)
    Write-Fixture -Path (Join-Path $fakeRepo '.agents\skills\taste-skill\SKILL.md') -Marker 'MARCA_TASTE'
    Write-Fixture -Path (Join-Path $fakeRepo 'core\skills\v2\design-principles\SKILL.md') -Marker 'MARCA_PRINCIPIOS'
    Write-Fixture -Path (Join-Path $fakeHome '.agents\skills\impeccable\SKILL.md') -Marker 'MARCA_IMPECCABLE'
    Write-Fixture -Path (Join-Path $fakeHome '.config\opencode\skills\ui-ux-pro-max\SKILL.md') -Marker 'MARCA_UIUX'

    foreach ($script in @('cli\argos-code.ps1', 'cli\argos-party.ps1')) {
        $path = Join-Path $Root $script
        $out = Invoke-AgentSkills -ScriptPath $path -RepoRoot $fakeRepo -HomePath $fakeHome

        Assert-That ($out -match [regex]::Escape('SKILL: impeccable')) "$script : impeccable inyectada desde el hogar (~/.agents/skills)"
        Assert-That ($out -match 'MARCA_IMPECCABLE') "$script : impeccable trae el cuerpo completo"
        Assert-That (-not ($out -match 'description: Fixture hermetico')) "$script : frontmatter eliminado del cuerpo"
        Assert-That ($out -match [regex]::Escape('SKILL: taste-skill')) "$script : taste-skill resuelta desde el repo (.agents/skills)"
        Assert-That ($out -match 'MARCA_TASTE') "$script : taste-skill con cuerpo"
        Assert-That ($out -match [regex]::Escape('SKILL: design-principles')) "$script : design-principles resuelta desde core/skills/v2"
        Assert-That ($out -match 'MARCA_PRINCIPIOS') "$script : design-principles con cuerpo"
        Assert-That ($out -match [regex]::Escape('SKILL: ui-ux-pro-max')) "$script : ui-ux-pro-max resuelta desde ~/.config/opencode/skills"
        Assert-That ($out -match 'MARCA_UIUX') "$script : ui-ux-pro-max con cuerpo"
        Assert-That (-not ($out -match [regex]::Escape('SKILL: content-copy'))) "$script : skill sin fuente se omite sin romper"

        $raw = [System.IO.File]::ReadAllText($path)
        Assert-That ($raw -match "'vivi'\s+= @\([^)]*'impeccable'[^)]*\)") "$script : el mapa de vivi declara impeccable"
    }

    # Sin fuentes: la inyeccion queda vacia y no lanza excepcion.
    New-Item -ItemType Directory -Path $emptyHome, $emptyRepo -Force | Out-Null
    $outEmpty = Invoke-AgentSkills -ScriptPath (Join-Path $Root 'cli\argos-code.ps1') -RepoRoot $emptyRepo -HomePath $emptyHome
    Assert-That ([string]::IsNullOrWhiteSpace($outEmpty)) 'sin fuentes: la inyeccion queda vacia sin romper'

    Write-Output 'PASS agent-skills: mapa de vivi con impeccable, resolucion repo/core/hogar y frontmatter fuera'
    exit 0
} finally {
    $env:USERPROFILE = $previousHome
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
