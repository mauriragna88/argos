<#
.SYNOPSIS
ARNES SYNC SKILLS - fusion bidireccional de skills entre harnesses.

Conecta los skills de superpowers y de arnes entre Pi (argos) y OpenCode:

  superpowers (14, repo obra/superpowers clonado por Pi)
      |
      +---> Pi (via package git)                      [ya configurado]
      +---> OpenCode ~/.config/opencode/skills/       [copia dirs originales]

  arnes (25 v1 + 16 v2, repo arnes/core/skills)
      |
      +---> Pi (via settings.json "skills")           [ya configurado]
      +---> OpenCode ~/.config/opencode/skills/       [copia dirs originales]

IDEMPOTENTE: solo copia lo que falta (no pisa skills existentes, no pisa
las renombradas superpowers-* / tdd-workflow que ya estan en OpenCode).
Sin BOM: escribe UTF-8 sin marca de orden de bytes (EF BB BF), que rompe
el parser JSON de Pi y otros.

USO:
  powershell -ExecutionPolicy Bypass -File argos-sync-skills.ps1
#>
[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$user = $env:USERPROFILE

# ---------------------------------------------------------------- fuentes
$superpowersRepo = Join-Path $user '.pi\agent\git\github.com\obra\superpowers\skills'
$arnesRepo      = 'C:\Users\LapOne Mx\Documents\GitHub\arnes\core\skills'
$ocSkills       = Join-Path $user '.config\opencode\skills'
$piSettings     = Join-Path $user '.pi\agent\settings.json'

$copied   = [System.Collections.Generic.List[string]]::new()
$skipped  = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Write-Note($msg)  { Write-Host ('  [SYNC] ' + $msg) -ForegroundColor DarkGray }
function Write-Add($msg)   { Write-Host ('  [SYNC] + ' + $msg) -ForegroundColor Green }
function Write-Skip($msg)  { Write-Host ('  [SYNC] = ' + $msg) -ForegroundColor DarkGray }
function Write-Warn($msg)  { Write-Host ('  [SYNC] ! ' + $msg) -ForegroundColor Yellow }

# ------------------------------------------------------------- helpers
function Test-Bom($path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
}

# Copia una skill (directorio) al destino si no existe ya. Si existe, reporta.
# Tambien sane: si el SKILL.md destino tiene BOM, lo limpia (reescribe UTF-8 sin BOM).
function Copy-Skill([string]$src, [string]$name) {
    $destDir = Join-Path $ocSkills $name
    $srcSkill = Join-Path $src 'SKILL.md'
    $destSkill = Join-Path $destDir 'SKILL.md'

    if (-not (Test-Path $destDir)) {
        if ($DryRun) { Write-Add "$name (dry-run)" ; return }
        Copy-Item -Path $src -Destination $destDir -Recurse -Force
        $copied.Add($name)
        # sanear BOM en el SKILL.md recien copiado (el repo arnes lo tiene)
        $newSkill = Join-Path $destDir 'SKILL.md'
        if (Test-Path $newSkill -and (Test-Bom $newSkill)) {
            $content = [System.IO.File]::ReadAllText($newSkill)
            $clean = $content.TrimStart([char]0xFEFF)
            [System.IO.File]::WriteAllText($newSkill, $clean, [System.Text.UTF8Encoding]::new($false))
            $warnings.Add("BOM removido en $name/SKILL.md (nuevo)")
            Write-Warn "BOM removido en $name/SKILL.md (nuevo)"
        }
        Write-Add $name
        return
    }

    # ya existe -> solo sanitizar BOM si lo tiene
    if (Test-Path $destSkill) {
        if (Test-Bom $destSkill) {
            if (-not $DryRun) {
                $content = [System.IO.File]::ReadAllText($destSkill)
                $clean = $content.TrimStart([char]0xFEFF)
                [System.IO.File]::WriteAllText($destSkill, $clean, [System.Text.UTF8Encoding]::new($false))
            }
            $warnings.Add("BOM removido en $name/SKILL.md")
            Write-Warn "BOM removido en $name/SKILL.md"
        } else {
            Write-Skip "$name (ya existe, sin BOM)"
        }
        $skipped.Add($name)
        return
    }

    if ($DryRun) { Write-Add "$name (SKILL.md faltante, dry-run)"; return }
    # el dir existe pero sin SKILL.md -> copiar solo el SKILL.md (no pisa assets)
    Copy-Item -Path $srcSkill -Destination $destSkill -Force
    $copied.Add($name)
    Write-Add "$name (SKILL.md)"
}

# ------------------------------------------------------------- 1) superpowers -> opencode
Write-Host '  [SYNC] superpowers (repo obra/superpowers) -> OpenCode' -ForegroundColor Cyan
if (Test-Path $superpowersRepo) {
    Get-ChildItem -Path $superpowersRepo -Directory | ForEach-Object {
        Copy-Skill $_.FullName $_.Name
    }
} else {
    Write-Warn "No encontre el repo superpowers en $superpowersRepo (corre 'pi list' o reinstala el package)."
}

# ------------------------------------------------------------- 2) arnes -> opencode
Write-Host ''
Write-Host '  [SYNC] arnes (repo arnes/core/skills) -> OpenCode' -ForegroundColor Cyan
if (Test-Path $arnesRepo) {
    # v1: skills directas (arnes-*)
    Get-ChildItem -Path $arnesRepo -Directory | Where-Object { $_.Name -ne 'v2' } | ForEach-Object {
        Copy-Skill $_.FullName $_.Name
    }
    # v2: skills de agentes (excluir 'template' que es plantilla, no skill real)
    $v2 = Join-Path $arnesRepo 'v2'
    if (Test-Path $v2) {
        Get-ChildItem -Path $v2 -Directory | Where-Object { $_.Name -ne 'template' } | ForEach-Object {
            Copy-Skill $_.FullName $_.Name
        }
    }
} else {
    Write-Warn "No encontre el repo arnes en $arnesRepo."
}

# ------------------------------------------------------------- 3) pi settings: skills array
Write-Host ''
Write-Host '  [SYNC] Pi settings.json -> skills de arnes' -ForegroundColor Cyan
if (Test-Path $piSettings) {
    $json = Get-Content $piSettings -Raw | ConvertFrom-Json
    $arnesPath = 'C:/Users/LapOne Mx/Documents/GitHub/arnes/core/skills'
    $has = $json.skills -contains $arnesPath
    if ($has) {
        Write-Skip 'arnes/core/skills ya en settings.json "skills"'
    } else {
        if ($DryRun) { Write-Add 'arnes/core/skills -> settings.json (dry-run)' }
        else {
            if (-not $json.skills) { $json | Add-Member -NotePropertyName skills -NotePropertyValue @() -Force }
            $json.skills = @($json.skills) + $arnesPath
            $json | ConvertTo-Json -Depth 10 | Set-Content $piSettings -Encoding UTF8 -NoNewline
            $copied.Add('settings.json + skills')
            Write-Add 'arnes/core/skills -> settings.json'
        }
    }
} else {
    Write-Warn "No encontre settings.json en $piSettings"
}

# ------------------------------------------------------------- resumen
Write-Host ''
Write-Host '============================================================' -ForegroundColor Red
Write-Host ('  [SYNC] Nuevos:  ' + $copied.Count) -ForegroundColor Green
Write-Host ('  [SYNC] Existentes (skip): ' + $skipped.Count) -ForegroundColor DarkGray
Write-Host ('  [SYNC] Avisos: ' + $warnings.Count) -ForegroundColor Yellow
Write-Host '  [SYNC] Recarga: /reload en Pi  |  reinicia OpenCode si estaba abierto' -ForegroundColor Gray
Write-Host '============================================================' -ForegroundColor Red

if ($warnings.Count -gt 0) {
    $warnings | ForEach-Object { Write-Host ('  [SYNC]   - ' + $_) -ForegroundColor Yellow }
}
