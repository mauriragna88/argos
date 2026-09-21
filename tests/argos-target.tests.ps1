# ============================================================
# ARNES - verificacion del selector de entorno (argos target)
#
# Hermetico: usa ConfigDir/TargetDir temporales y -NoLaunch.
# Verifica: list, set, show, despliegue de AGENTS.md/CLAUDE.md (incluye target freebuff),
# y el sync del stack visual de Vivi a todos los runners (HOME hermetico).
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

    # 4. launch codex -NoLaunch despliega su bundle ligero de dominio.
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File $TargetCli -Target codex -NoLaunch -ConfigDir $work -TargetDir $work | Out-Null
    Assert-That (Test-Path (Join-Path $work 'AGENTS.md')) 'codex: AGENTS.md desplegado'
    $agents = Get-Content (Join-Path $work 'AGENTS.md') -Raw
    Assert-That ($agents -match 'ARNES ARGOS - Bundle ligero \(target: codex\)') 'codex: AGENTS.md contiene bundle ligero'
    Assert-That ($agents -match 'Backend/APIs/Supabase -> Ansem') 'codex: AGENTS.md contiene agente de dominio'
    Assert-That ($agents -match 'stack visual instalado en el hogar') 'codex: AGENTS.md apunta al stack visual de Vivi'

    # 5. launch claude -NoLaunch despliega CLAUDE.md + subagentes de dominio resolubles.
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File $TargetCli -Target claude -NoLaunch -ConfigDir $work -TargetDir $work | Out-Null
    Assert-That (Test-Path (Join-Path $work 'CLAUDE.md')) 'CLAUDE.md desplegado'
    $claudeAgents = @(Get-ChildItem (Join-Path $work 'agents\*.md') -ErrorAction SilentlyContinue)
    Assert-That ($claudeAgents.Count -eq 2) "claude agents = 2 (obtenido $($claudeAgents.Count))"
    foreach ($ca in $claudeAgents) {
        $c = Get-Content $ca.FullName -Raw
        Assert-That ($c -match '^---\r?\nname:') "frontmatter valido en $($ca.Name)"
    }

    # 6. launch freebuff -NoLaunch despliega el bundle ligero frontend/devops.
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File $TargetCli -Target freebuff -NoLaunch -ConfigDir $work -TargetDir $work | Out-Null
    Assert-That (Test-Path (Join-Path $work 'AGENTS.md')) 'freebuff: AGENTS.md desplegado'
    $fbAgents = Get-Content (Join-Path $work 'AGENTS.md') -Raw
    Assert-That ($fbAgents -match 'ARNES ARGOS - Bundle ligero \(target: freebuff\)') 'freebuff: AGENTS.md contiene bundle ligero'
    Assert-That ($fbAgents -match 'Frontend/UI/React -> Vivi') 'freebuff: AGENTS.md contiene agente de dominio'
    Assert-That ($fbAgents -match '~/.agents/skills/') 'freebuff: AGENTS.md apunta al stack visual de Vivi'

    # 7. launch dsh -NoLaunch instala las tres skills en un HOME hermetico bajo TargetDir.
    $impeccableSource = Join-Path $work '.config\opencode\skills\impeccable'
    New-Item -ItemType Directory -Path $impeccableSource -Force | Out-Null
    $impeccableFixture = "---`nname: impeccable`ndescription: Fixture hermetico de Impeccable.`nuser-invocable: false`n---`n`n# Impeccable fixture`n"
    [System.IO.File]::WriteAllText((Join-Path $impeccableSource 'SKILL.md'), $impeccableFixture, (New-Object System.Text.UTF8Encoding($false)))

    & $PSExe -NoProfile -ExecutionPolicy Bypass -File $TargetCli -Target dsh -NoLaunch -ConfigDir $work -TargetDir $work | Out-Null
    # Repetir prueba que la sincronizacion es idempotente y no anida bundles.
    & $PSExe -NoProfile -ExecutionPolicy Bypass -File $TargetCli -Target dsh -NoLaunch -ConfigDir $work -TargetDir $work | Out-Null

    $dshSkills = Join-Path $work '.dsh\skills'
    $viviSkill = Join-Path $dshSkills 'vivi-visual-excellence\SKILL.md'
    $tasteSkill = Join-Path $dshSkills 'taste-skill\SKILL.md'
    $impeccableSkill = Join-Path $dshSkills 'impeccable\SKILL.md'
    Assert-That (Test-Path -LiteralPath $viviSkill) 'dsh: vivi-visual-excellence instalada'
    Assert-That (Test-Path -LiteralPath $tasteSkill) 'dsh: taste-skill instalada'
    Assert-That (Test-Path -LiteralPath $impeccableSkill) 'dsh: impeccable instalada desde fixture hermetico'
    $viviContent = Get-Content -LiteralPath $viviSkill -Raw
    $tasteContent = Get-Content -LiteralPath $tasteSkill -Raw
    $impeccableContent = Get-Content -LiteralPath $impeccableSkill -Raw
    Assert-That ($viviContent -eq (Get-Content -LiteralPath (Join-Path $Root 'core\skills\v2\vivi-visual-excellence\SKILL.md') -Raw)) 'dsh: contenido de vivi-visual-excellence copiado completo'
    Assert-That ($tasteContent -eq (Get-Content -LiteralPath (Join-Path $Root '.agents\skills\taste-skill\SKILL.md') -Raw)) 'dsh: contenido de taste-skill copiado completo'
    Assert-That ($impeccableContent -eq $impeccableFixture) 'dsh: contenido de impeccable copiado desde fixture'
    Assert-That ($viviContent -match '(?m)^user-invocable:\s*false\s*$') 'dsh: vivi-visual-excellence es model-only'
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $dshSkills 'vivi-visual-excellence\vivi-visual-excellence'))) 'dsh: repeticion no anida vivi-visual-excellence'
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $dshSkills 'taste-skill\taste-skill'))) 'dsh: repeticion no anida taste-skill'
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $dshSkills 'impeccable\impeccable'))) 'dsh: repeticion no anida impeccable'

    # 7b. Las skills del pipeline de diseno de Vivi viajan a DSH (origen core/skills/v2).
    foreach ($skill in @('design-principles', 'content-copy', 'motion-design', 'visual-qa')) {
        $dest = Join-Path $dshSkills "$skill\SKILL.md"
        $src = Join-Path $Root "core\skills\v2\$skill\SKILL.md"
        Assert-That (Test-Path -LiteralPath $dest) "dsh: $skill instalada"
        Assert-That ((Get-Content -LiteralPath $dest -Raw) -eq (Get-Content -LiteralPath $src -Raw)) "dsh: contenido de $skill copiado completo"
        Assert-That ((Get-Content -LiteralPath $dest -Raw) -match '(?m)^user-invocable:\s*false\s*$') "dsh: $skill es model-only"
        Assert-That (-not (Test-Path -LiteralPath (Join-Path $dshSkills "$skill\$skill"))) "dsh: repeticion no anida $skill"
    }
    Assert-That (Test-Path -LiteralPath (Join-Path $dshSkills 'design-principles\reference\devogatec.md')) 'dsh: design-principles lleva reference/devogatec.md'
    Assert-That (Test-Path -LiteralPath (Join-Path $dshSkills 'visual-qa\reference\evidence-tooling.md')) 'dsh: visual-qa lleva reference/evidence-tooling.md'

    # 7c. El stack visual de Vivi viaja a TODOS los runners (HOME hermetico bajo TargetDir).
    $stackNames = @('vivi-visual-excellence', 'design-principles', 'content-copy', 'motion-design', 'visual-qa')
    $agentsSkills = Join-Path $work '.agents\skills'
    $claudeSkills = Join-Path $work '.claude\skills'
    $codexSkills = Join-Path $work '.codex\skills'
    $opencodeSkills = Join-Path $work '.config\opencode\skills'
    $geminiSkills = Join-Path $work '.gemini\skills'
    $cmdcSkills = Join-Path $work '.commandcode\skills'
    $stackDests = @(
        @{ L = 'agents'; P = $agentsSkills }, @{ L = 'dsh'; P = $dshSkills }, @{ L = 'claude'; P = $claudeSkills }
        @{ L = 'codex'; P = $codexSkills }, @{ L = 'opencode'; P = $opencodeSkills }, @{ L = 'gemini'; P = $geminiSkills }
        @{ L = 'cmdc'; P = $cmdcSkills }
    )
    foreach ($d in $stackDests) {
        foreach ($n in $stackNames) {
            $dest = Join-Path $d.P "$n\SKILL.md"
            $src = Join-Path $Root "core\skills\v2\$n\SKILL.md"
            Assert-That (Test-Path -LiteralPath $dest) "stack: $n instalada en $($d.L)"
            Assert-That ((Get-Content -LiteralPath $dest -Raw) -eq (Get-Content -LiteralPath $src -Raw)) "stack: contenido de $n en $($d.L)"
            Assert-That ((Get-Content -LiteralPath $dest -Raw) -match '(?m)^user-invocable:\s*false\s*$') "stack: $n model-only en $($d.L)"
            Assert-That (-not (Test-Path -LiteralPath (Join-Path $d.P "$n\$n"))) "stack: repeticion no anida $n en $($d.L)"
        }
    }
    Assert-That (Test-Path -LiteralPath (Join-Path $cmdcSkills 'design-principles\reference\devogatec.md')) 'stack: cmdc lleva reference/devogatec.md'
    Assert-That (Test-Path -LiteralPath (Join-Path $cmdcSkills 'visual-qa\reference\evidence-tooling.md')) 'stack: cmdc lleva reference/evidence-tooling.md'
    Assert-That (Test-Path -LiteralPath (Join-Path $claudeSkills 'taste-skill\SKILL.md')) 'stack: claude lleva taste-skill'
    Assert-That (Test-Path -LiteralPath (Join-Path $codexSkills 'impeccable\SKILL.md')) 'stack: codex lleva impeccable (fixture)'
    Assert-That ((Get-Content -LiteralPath (Join-Path $codexSkills 'impeccable\SKILL.md') -Raw) -eq $impeccableFixture) 'stack: impeccable copiado desde fixture'

    # 8. scripts parsean en PowerShell 5.1 (dispatch + target DSH).
    foreach ($script in @('cli\argos.ps1', 'cli\argos-target.ps1')) {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Root $script), [ref]$tokens, [ref]$errors) | Out-Null
        Assert-That ($errors.Count -eq 0) "$script parsea sin errores"
    }

    Write-Output 'PASS argos-target: list/set/show y despliegue AGENTS.md/CLAUDE.md/Freebuff/DSH skills'
    exit 0
} finally {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
