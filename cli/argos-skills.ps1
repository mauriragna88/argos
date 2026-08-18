# argos-skills.ps1 - RAGNAROK: Procurement & Research Warden (servicio real)
# ==========================================================================
# Convierte el rol de compras de Ragnarok en un servicio ejecutable:
# busca skills en repos externos (npx skills find), muestra candidatos,
# instala con confirmacion en .agents/skills/ y las registra en el skill
# registry de ARNES. Evidencia antes de comprar: nunca instala sin ver.
#
# Acciones:
#   find <query>      -> busca skills externas (npx skills find)
#   list [repo]       -> preview de skills de un repo (npx skills add --list)
#   add <repo> <skill>-> instala UNA skill en .agents/skills/ (pide confirmacion)
#   installed         -> skills instaladas en .agents/skills/ + propias core/skills/v2
#   meta              -> metadata de skills (name/description/trigger) SIN cargar
#                        el SKILL.md completo (progressive disclosure, Fase 2)
#
# Uso:
#   .\cli\argos-skills.ps1 -Action find -Query "testing"
#   .\cli\argos-skills.ps1 -Action list -Repo "obra/superpowers"
#   .\cli\argos-skills.ps1 -Action add -Repo "obra/superpowers" -Skill "systematic-debugging"
#   .\cli\argos-skills.ps1 -Action installed
#   .\cli\argos-skills.ps1 -Action meta -Json

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("find","list","add","installed","meta")]
    [string]$Action = "find",
    [string]$Query = "",
    [string]$Repo = "",
    [string]$Skill = "",
    [switch]$Yes,     # add: saltar la confirmacion
    [switch]$Json,
    [string]$Root = ""
)

$ErrorActionPreference = "Continue"

if (-not $Root) {
    $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$skillsDir = Join-Path $Root ".agents\skills"
$ownSkillsDir = Join-Path $Root "core\skills\v2"

# Encoding-robust: UTF-8 antes de cualquier salida (humana o JSON).
# Sin esto, -Json sale en OEM y los consumidores UTF-8 fallan al parsear.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Invoke-Npx {
    param([string[]]$NpxArgs)
    # npx puede requerir install: usar --yes para no quedarse colgado en prompt
    $all = @("--yes", "skills") + $NpxArgs
    try {
        $out = & npx @all 2>&1
        return @($out)
    } catch {
        return @("NPX_ERROR: $($_.Exception.Message)")
    }
}

# === FIND: buscar skills externas ===
if ($Action -eq "find") {
    if (-not $Query) { Write-Error "find requiere -Query"; exit 1 }
    $out = Invoke-Npx @("find", $Query)
    if ($Json) {
        @{ action = "find"; query = $Query; raw = $out } | ConvertTo-Json -Depth 4
        exit 0
    }
    Write-Host ""
    Write-Host "  RAGNAROK SCOUT - buscar skills externas" -ForegroundColor Cyan
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host ("  Query: {0}" -f $Query) -ForegroundColor Yellow
    Write-Host ""
    foreach ($line in $out) {
        $trimmed = "$line".Trim()
        if ($trimmed) { Write-Host "  $trimmed" -ForegroundColor White }
    }
    Write-Host ""
    Write-Host "  Para ver skills de un repo:  argos skills list -Repo <owner/repo>" -ForegroundColor DarkGray
    Write-Host "  Para instalar una:           argos skills add -Repo <owner/repo> -Skill <nombre>" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# === LIST: preview de skills de un repo ===
if ($Action -eq "list") {
    if (-not $Repo) { Write-Error "list requiere -Repo (ej: obra/superpowers)"; exit 1 }
    $out = Invoke-Npx @("add", $Repo, "--list")
    if ($Json) {
        @{ action = "list"; repo = $Repo; raw = $out } | ConvertTo-Json -Depth 4
        exit 0
    }
    Write-Host ""
    Write-Host "  RAGNAROK - skills disponibles en $Repo" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor Cyan
    foreach ($line in $out) {
        $trimmed = "$line".Trim()
        if ($trimmed) { Write-Host "  $trimmed" -ForegroundColor White }
    }
    Write-Host ""
    Write-Host "  Instalar: argos skills add -Repo $Repo -Skill <nombre>" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# === ADD: instalar con confirmacion ===
if ($Action -eq "add") {
    if (-not $Repo -or -not $Skill) { Write-Error "add requiere -Repo y -Skill"; exit 1 }
    if (-not $Yes) {
        Write-Host ("  RAGNAROK WAR CRY - instalar skill: {0} de {1}" -f $Skill, $Repo) -ForegroundColor Yellow
        Write-Host "  Las skills comunitarias no estan verificadas por ARNES." -ForegroundColor DarkGray
        Write-Host "  Auron (seguridad) revisa el contenido despues de instalar." -ForegroundColor DarkGray
        $ans = Read-Host "  Confirmas la compra? (s/n)"
        if ($ans -notmatch '^(s|si|sí|yes|y)$') {
            Write-Host "  [RAGNAROK] Compra cancelada. Nada se instalo." -ForegroundColor Yellow
            exit 0
        }
    }
    $out = Invoke-Npx @("add", $Repo, "--skill", $Skill, "--yes")
    if ($Json) {
        @{ action = "add"; repo = $Repo; skill = $Skill; installed_to = $skillsDir; raw = $out } | ConvertTo-Json -Depth 4
        exit 0
    }
    Write-Host ""
    Write-Host "  RAGNAROK - resultado de la instalacion" -ForegroundColor Cyan
    foreach ($line in $out) {
        $trimmed = "$line".Trim()
        if ($trimmed) { Write-Host "  $trimmed" -ForegroundColor White }
    }
    # Verificar que quedo instalada
    $target = Join-Path $skillsDir $Skill
    if (Test-Path (Join-Path $target "SKILL.md")) {
        Write-Host ""
        Write-Host "  [RAGNAROK] Skill instalada en .agents/skills/$Skill" -ForegroundColor Green
        Write-Host "  Nota: Auron debe auditar el contenido antes de usarla en produccion." -ForegroundColor DarkGray
    } else {
        Write-Host ""
        Write-Host "  [RAGNAROK] No se encontro SKILL.md en .agents/skills/$Skill - revisa la salida." -ForegroundColor Yellow
    }
    Write-Host ""
    exit 0
}

# === META: metadata sin cargar SKILL.md (progressive disclosure) ===
if ($Action -eq "meta") {
    $all = @()
    # propias core/skills/v2 + externas .agents/skills + pi/skills
    $roots = @($ownSkillsDir, $skillsDir, (Join-Path $Root "pi\skills"))
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        $dirs = @(Get-ChildItem -Directory -Path $root | Where-Object { Test-Path (Join-Path $_.FullName "SKILL.md") })
        foreach ($d in $dirs) {
            $skPath = Join-Path $d.FullName "SKILL.md"
            $meta = [ordered]@{ name = $d.Name; description = ""; trigger = ""; source = Split-Path $root -Leaf }
            try {
                # Solo frontmatter (bloque entre ---): nunca el cuerpo de la skill.
                # Soporta YAML folded (description: > + lineas indentadas).
                $head = Get-Content -LiteralPath $skPath -TotalCount 60 -Encoding UTF8
                $inFm = $false
                $curKey = $null
                $foldBuf = @()
                foreach ($line in $head) {
                    if ($line -match '^---\s*$') {
                        if ($inFm) { break }
                        $inFm = $true
                        continue
                    }
                    if (-not $inFm) { continue }
                    if ($line -match '^\s{2,}(.+)$') {
                        # linea indentada: continua el valor folded del key actual
                        if ($curKey -and $foldBuf.Count -lt 6) { $foldBuf += $Matches[1].Trim() }
                        continue
                    }
                    if ($line -match '^([a-zA-Z_]+):\s*(.*)$') {
                        $curKey = $Matches[1].ToLower()
                        $val = $Matches[2].Trim()
                        if ($val -and $val -notin @('>','|','>-','|-')) {
                            $meta[$curKey] = $val
                            $foldBuf = @()
                        } else {
                            $foldBuf = @()
                        }
                        continue
                    }
                }
                if ($foldBuf.Count -gt 0 -and $curKey -and $meta.Contains($curKey) -and -not $meta[$curKey]) {
                    $meta[$curKey] = ($foldBuf -join ' ')
                }
                if (-not $meta.description) { $meta.description = "(sin description en frontmatter)" }
            } catch {}
            $all += $meta
        }
    }
    if ($Json) {
        @{ action = "meta"; count = $all.Count; skills = @($all) } | ConvertTo-Json -Depth 5
        exit 0
    }
    Write-Host ""
    Write-Host "  RAGNAROK - metadata de skills (progressive disclosure)" -ForegroundColor Cyan
    Write-Host "  ====================================================" -ForegroundColor Cyan
    Write-Host ("  {0} skills (solo metadata; SKILL.md se carga al activarse)" -f $all.Count) -ForegroundColor Yellow
    foreach ($s in $all) {
        Write-Host ("  - {0} [{1}]" -f $s.name, $s.source) -ForegroundColor White
        if ($s.description) { Write-Host ("      {0}" -f $s.description) -ForegroundColor DarkGray }
        if ($s.trigger) { Write-Host ("      trigger: {0}" -f $s.trigger) -ForegroundColor DarkGray }
    }
    Write-Host ""
    exit 0
}

# === INSTALLED: inventario ===
if ($Action -eq "installed") {
    $external = @()
    if (Test-Path $skillsDir) {
        $external = @(Get-ChildItem -Directory -Path $skillsDir | Where-Object { Test-Path (Join-Path $_.FullName "SKILL.md") } | ForEach-Object { $_.Name })
    }
    $own = @()
    if (Test-Path $ownSkillsDir) {
        $own = @(Get-ChildItem -Directory -Path $ownSkillsDir | Where-Object { Test-Path (Join-Path $_.FullName "SKILL.md") } | ForEach-Object { $_.Name })
    }
    if ($Json) {
        @{
            action = "installed"
            external_skills = $external
            own_skills = $own
            external_dir = $skillsDir
            total_external = $external.Count
            total_own = $own.Count
        } | ConvertTo-Json -Depth 4
        exit 0
    }
    Write-Host ""
    Write-Host "  RAGNAROK - inventario de skills" -ForegroundColor Cyan
    Write-Host "  ===============================" -ForegroundColor Cyan
    Write-Host ("  Skills externas (.agents/skills): {0}" -f $external.Count) -ForegroundColor Yellow
    if ($external.Count -gt 0) {
        foreach ($s in $external) { Write-Host ("    - {0}" -f $s) -ForegroundColor White }
    } else {
        Write-Host "    (ninguna - usa 'argos skills find' para buscar)" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host ("  Skills propias ARNES (core/skills/v2): {0}" -f $own.Count) -ForegroundColor Yellow
    if ($own.Count -gt 0) {
        foreach ($s in $own) { Write-Host ("    - {0}" -f $s) -ForegroundColor White }
    }
    Write-Host ""
    Write-Host '  Buscar:  argos skills find "<query>"' -ForegroundColor DarkGray
    Write-Host '  Listar:  argos skills list -Repo <owner/repo>' -ForegroundColor DarkGray
    Write-Host '  Agregar: argos skills add -Repo <owner/repo> -Skill <nombre>' -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}
