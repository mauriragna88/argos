#Requires -Version 5.1
# ============================================================
# ARGOS - STACK VISUAL DE VIVI -> TODOS LOS RUNNERS
#
# Fuente canonica (repo): core/skills/v2/<skill> (propias ARGOS)
# y .agents/skills/taste-skill (externa adaptada). Impeccable se
# toma de ~/.config/opencode/skills/impeccable si existe.
#
# Destinos: cada CLI/entorno lee skills de SU directorio global.
# El stack se mantiene identico en todos para que Vivi cargue lo
# mismo sin importar desde donde se lance (DSH, claude, codex,
# opencode, gemini/agy, cmdc, Antigravity y el estandar ~/.agents,
# que es de donde tambien leen la app de ChatGPT/Codex).
#
# Uso (dot-source):
#   . (Join-Path $PSScriptRoot 'argos-skills-sync.ps1')
#   Sync-ViviDesignStack -Root $Root [-HomeBase <dir>] [-Quiet]
#
# -HomeBase permite el modo hermetico de los tests (TargetDir).
# Idempotente y barato: solo copia el bundle si el contenido cambio.
# ============================================================

function Get-ViviDesignStackNames {
    return @('vivi-visual-excellence', 'design-principles', 'content-copy', 'motion-design', 'visual-qa')
}

# Compara el bundle destino contra la fuente (SKILL.md + reference/ + cualquier archivo).
function Test-SkillBundleCurrent {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    if (-not (Test-Path -LiteralPath (Join-Path $Destination 'SKILL.md'))) { return $false }
    $srcFiles = @(Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction SilentlyContinue)
    if ($srcFiles.Count -eq 0) { return $false }
    foreach ($f in $srcFiles) {
        $rel = $f.FullName.Substring($Source.Length).TrimStart('\', '/')
        $dst = Join-Path $Destination $rel
        if (-not (Test-Path -LiteralPath $dst)) { return $false }
        if ((Get-Item -LiteralPath $dst).Length -ne $f.Length) { return $false }
        if ((Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash) { return $false }
    }
    return $true
}

# Reemplazo atomico a nivel de bundle: evita anidamiento y archivos obsoletos al repetir.
function Sync-SkillBundle {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    $parent = Split-Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

function Sync-ViviDesignStack {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$HomeBase = '',
        [switch]$Quiet
    )
    if (-not $HomeBase) { $HomeBase = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME } }

    # --- Fuentes ---
    $sources = @()
    foreach ($n in (Get-ViviDesignStackNames)) {
        $p = Join-Path $Root "core\skills\v2\$n"
        if (Test-Path -LiteralPath (Join-Path $p 'SKILL.md')) {
            $sources += @{ Name = $n; Source = $p }
        } elseif (-not $Quiet) {
            Write-Host ("  [!] Skill canonica ausente (se omite): {0}" -f $p) -ForegroundColor Yellow
        }
    }
    $taste = Join-Path $Root '.agents\skills\taste-skill'
    if (Test-Path -LiteralPath (Join-Path $taste 'SKILL.md')) {
        $sources += @{ Name = 'taste-skill'; Source = $taste }
    }
    $impeccable = Join-Path $HomeBase '.config\opencode\skills\impeccable'
    if (Test-Path -LiteralPath (Join-Path $impeccable 'SKILL.md')) {
        $sources += @{ Name = 'impeccable'; Source = $impeccable }
    } elseif (-not $Quiet) {
        Write-Host '  [!] Impeccable no encontrado (opcional): npx skills add pbakaus/impeccable' -ForegroundColor Yellow
    }

    # --- Destinos (directorio global de skills de cada entorno) ---
    $destinations = @(
        @{ Label = 'agents';   Path = (Join-Path $HomeBase '.agents\skills') }
        @{ Label = 'dsh';      Path = (Join-Path $HomeBase '.dsh\skills') }
        @{ Label = 'claude';   Path = (Join-Path $HomeBase '.claude\skills') }
        @{ Label = 'codex';    Path = (Join-Path $HomeBase '.codex\skills') }
        @{ Label = 'opencode'; Path = (Join-Path $HomeBase '.config\opencode\skills') }
        @{ Label = 'gemini';   Path = (Join-Path $HomeBase '.gemini\skills') }
        @{ Label = 'cmdc';     Path = (Join-Path $HomeBase '.commandcode\skills') }
        # Antigravity (codelab oficial): scope global de todos sus productos + scope global del CLI
        @{ Label = 'agy-global'; Path = (Join-Path $HomeBase '.gemini\config\skills') }
        @{ Label = 'agy-cli';    Path = (Join-Path $HomeBase '.gemini\antigravity-cli\skills') }
    )

    $updated = 0
    $total = 0
    foreach ($dest in $destinations) {
        foreach ($item in $sources) {
            $total++
            $target = Join-Path $dest.Path $item.Name
            if (Test-SkillBundleCurrent -Source $item.Source -Destination $target) { continue }
            Sync-SkillBundle -Source $item.Source -Destination $target
            $updated++
            if (-not $Quiet) {
                Write-Host ("  [OK] {0,-22} -> {1}" -f $item.Name, $target) -ForegroundColor Green
            }
        }
    }
    if (-not $Quiet) {
        if ($updated -eq 0) {
            Write-Host ("  [OK] Stack visual de Vivi al dia en los {0} entornos." -f $destinations.Count) -ForegroundColor DarkGray
        } else {
            Write-Host ("  [OK] Stack visual de Vivi sincronizado: {0} de {1} bundles actualizados." -f $updated, $total) -ForegroundColor Green
        }
    }
    return $updated
}
