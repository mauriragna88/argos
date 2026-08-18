# cache-prefix.ps1 - Cache Prefix estable (optimizacion de tokens)
# =========================================================================
# Refuerza el prompt caching: separa el contexto en ESTABLE (prefix) y
# DINAMICO (por quest). El prefix se paga una vez y los turnos siguientes
# solo pagan la parte dinamica (precio de cache ~10% del costo normal).
#
# El prefix DEBE ser byte-identico entre turnos para que el proveedor lo
# cachee. cache-prefix genera el bloque estable versionado y VERIFICA que
# no haya cambiado entre turnos (si cambio, el cache se invalida y hay que
# recargar).
#
# Fuentes estables (lo que NO cambia entre quests del mismo harness):
#   1. identidad  -> bloque corto (core/atlas-player.agent.md, seccion identidad)
#   2. principles -> .arnes/principles/ (general + los que apliquen por dominio)
#   3. skills     -> metadata de skills (progressive disclosure, sin cuerpos)
#
# Acciones:
#   build   -> arma el prefix, calcula hash SHA-256, guarda .arnes/cache-prefix.json
#   verify  -> rebuilds y compara con el guardado (detecta invalidacion de cache)
#   stats   -> tamano del prefix + ahorro estimado con caching en N turnos
#
# Uso:
#   .\cli\cache-prefix.ps1 -Action build
#   .\cli\cache-prefix.ps1 -Action verify
#   .\cli\cache-prefix.ps1 -Action stats -Turns 10
#   .\cli\cache-prefix.ps1 -Action build -Json

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("build","verify","stats")]
    [string]$Action = "build",
    [int]$Turns = 10,          # stats: cuantos turnos para estimar el ahorro
    [string]$QuestType = "",   # build/verify: dominio para principios (default: general)
    [switch]$Json,
    [string]$ArnesDir = ""
)

$ErrorActionPreference = "Continue"

if (-not $ArnesDir) {
    $cwd = (Get-Location).Path
    if (Test-Path (Join-Path $cwd ".arnes\config.json")) {
        $ArnesDir = Join-Path $cwd ".arnes"
    } else {
        $ArnesDir = ".arnes"
    }
}

# Encoding-robust: UTF-8 antes de cualquier salida (mismo patron que el resto
# del harness; sin esto los pipes consumidores UTF-8 reciben bytes OEM).
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$stateFile = Join-Path $ArnesDir "cache-prefix.json"

# === Fuentes estables ===
function Get-IdentityBlock {
    $agentFile = Join-Path $Root "core\atlas-player.agent.md"
    if (-not (Test-Path $agentFile)) { return "# ARNES ARGOS - Atlas" }
    $content = Get-Content -LiteralPath $agentFile -Raw -Encoding UTF8
    # Solo el bloque de identidad (primeras secciones) - estable por definicion
    $lines = $content -split "`n"
    $block = @()
    foreach ($line in $lines) {
        if ($line -match "^## ") { break }   # corta en la primera seccion pesada
        $block += $line
    }
    return (($block -join "`n").Trim())
}

function Get-PrinciplesBlock {
    param([string]$Type)
    $principlesDir = Join-Path $ArnesDir "principles"
    if (-not (Test-Path $principlesDir)) { return "" }
    $files = @()
    $general = Join-Path $principlesDir "general.md"
    if (Test-Path $general) { $files += $general }
    $dom = Join-Path $principlesDir "$Type.md"
    if ($Type -and $Type -ne "general" -and (Test-Path $dom)) { $files += $dom }
    $out = @()
    foreach ($f in $files) {
        $out += "### " + (Split-Path $f -Leaf)
        $out += (Get-Content -LiteralPath $f -Raw -Encoding UTF8).Trim()
    }
    return ($out -join "`n`n")
}

function Get-SkillsMetaBlock {
    $skillsScript = Join-Path $PSScriptRoot "argos-skills.ps1"
    if (-not (Test-Path $skillsScript)) { return "" }
    try {
        $out = (& $skillsScript -Action meta -Json 2>$null) | Out-String
        $data = $out.Trim() | ConvertFrom-Json
        $lines = @()
        foreach ($s in $data.skills) {
            $lines += "- $($s.name): $($s.description)"
        }
        return ($lines -join "`n")
    } catch { return "" }
}

function Get-TextTokens([string]$Text) {
    if (-not $Text) { return 0 }
    return [math]::Max(1, [int][math]::Ceiling($Text.Length / 4))
}

# === BUILD ===
if ($Action -eq "build" -or $Action -eq "verify") {
    $identity = Get-IdentityBlock
    $principles = Get-PrinciplesBlock -Type $QuestType
    $skills = Get-SkillsMetaBlock

    $sections = [ordered]@{
        identity   = $identity
        principles = $principles
        skills     = $skills
    }

    # El prefix es la concatenacion EXACTA (byte a byte) de las secciones.
    # Un solo espacio distinto entre turnos invalida el cache del proveedor.
    $prefix = ""
    foreach ($k in $sections.Keys) {
        if (-not $sections[$k]) { continue }
        if ($prefix) { $prefix += "`n`n" }
        $prefix += ("== ARGOS CACHE PREFIX - section: " + $k + " ==" + "`n" + $sections[$k])
    }

    $tokens = Get-TextTokens $prefix
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($prefix))).Replace("-","").ToLower().Substring(0, 16)
    $sha.Dispose()

    $now = Get-Date
    $entry = [ordered]@{
        version      = (Get-Date -Format "yyyyMMddHHmm")
        hash         = $hash
        prefix_tokens = $tokens
        sections     = @($sections.Keys | Where-Object { $sections[$_] })
        quest_type   = $QuestType
        built_at     = $now.ToString("o")
        prefix_preview = $prefix.Substring(0, [Math]::Min(120, $prefix.Length))
    }

    if ($Action -eq "build") {
        $entry | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $stateFile -Encoding UTF8
        if ($Json) {
            @{ action = "build"; ok = $true; version = $hash; prefix_tokens = $tokens; prefix_preview = $entry.prefix_preview } | ConvertTo-Json -Depth 3
            exit 0
        }
        Write-Host ""
        Write-Host "  CACHE PREFIX - build" -ForegroundColor Cyan
        Write-Host "  ====================" -ForegroundColor Cyan
        Write-Host ("  Version (hash):  {0}" -f $hash) -ForegroundColor Yellow
        Write-Host ("  Prefix tokens:   {0} (~{1} KB)" -f $tokens, [math]::Round($prefix.Length/1024, 1)) -ForegroundColor White
        Write-Host ("  Secciones:       {0}" -f ($entry.sections -join ', ')) -ForegroundColor DarkGray
        Write-Host "  Este bloque es el cacheable: identico entre turnos mientras el harness no cambie." -ForegroundColor DarkGray
        Write-Host "  Guardado en .arnes/cache-prefix.json" -ForegroundColor DarkGray
        Write-Host ""
        exit 0
    }

    # === VERIFY ===
    $prev = $null
    if (Test-Path $stateFile) {
        try { $prev = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    }
    $stable = $true
    $changedSections = @()
    if ($prev) {
        if ($prev.hash -ne $hash) {
            $stable = $false
            if ($prev.sections) {
                # detectar que seccion cambio (reconstruccion por seccion)
                foreach ($k in $sections.Keys) {
                    if (-not $sections[$k]) { continue }
                    if (-not $prev.sections -contains $k) { $changedSections += "$k (nueva)"; continue }
                }
                if ($changedSections.Count -eq 0) { $changedSections += "contenido (identidad/principios/skills)" }
            } else {
                $changedSections += "contenido"
            }
        }
    } else {
        $stable = $false
        $changedSections += "(sin build previo)"
    }

    if ($Json) {
        @{ action = "verify"; stable = $stable; version = $hash; previous_version = if ($prev) { $prev.hash } else { "" }; changed = $changedSections; prefix_tokens = $tokens } | ConvertTo-Json -Depth 3
        exit 0
    }
    Write-Host ""
    Write-Host "  CACHE PREFIX - verify" -ForegroundColor Cyan
    Write-Host "  =====================" -ForegroundColor Cyan
    if ($stable) {
        Write-Host ("  ESTABLE: {0} (igual al turno anterior)" -f $hash) -ForegroundColor Green
        Write-Host "  El proveedor puede reusar el cache del prefix -> solo pagas la parte dinamica." -ForegroundColor DarkGray
    } else {
        Write-Host ("  CAMBIO: {0} != anterior {1}" -f $hash, $(if ($prev) { $prev.hash } else { "-" })) -ForegroundColor Yellow
        Write-Host ("  Secciones que cambiaron: {0}" -f ($changedSections -join ', ')) -ForegroundColor Yellow
        Write-Host "  El cache del prefix se invalida -> el proximo turno paga el prefix completo." -ForegroundColor DarkGray
        Write-Host "  Ejecuta 'argos cache build' para regenerar y estabilizar." -ForegroundColor DarkGray
    }
    Write-Host ""
    exit 0
}

# === STATS ===
if ($Action -eq "stats") {
    $prev = $null
    if (Test-Path $stateFile) {
        try { $prev = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    }
    if (-not $prev) {
        if ($Json) { @{ action = "stats"; ok = $false; reason = "no build previo; ejecuta argos cache build" } | ConvertTo-Json; exit 0 }
        Write-Host "  [CACHE] Sin build previo. Ejecuta: argos cache build" -ForegroundColor Yellow
        exit 0
    }
    $prefixTokens = [int]$prev.prefix_tokens
    $dynamicTokens = 500   # estimado de la parte dinamica por turno (quest + evidencia)
    # Costo modelo normal ~= prefix + dynamic por turno. Con cache: prefix una vez + dynamic * 0.1
    $noCache = ($prefixTokens + $dynamicTokens) * $Turns
    $withCache = $prefixTokens + ($dynamicTokens * $Turns)   # dynamic a precio normal
    # (el ahorro real adicional del proveedor en dynamic es marginal; el grande es el prefix)
    $saved = $noCache - $withCache
    $savedPct = if ($noCache -gt 0) { [math]::Round(($saved / $noCache) * 100, 1) } else { 0 }

    if ($Json) {
        @{
            action = "stats"; ok = $true; prefix_tokens = $prefixTokens; dynamic_tokens_est = $dynamicTokens
            turns = $Turns; tokens_without_cache = $noCache; tokens_with_cache = $withCache
            tokens_saved = $saved; saved_pct = $savedPct; version = $prev.hash
        } | ConvertTo-Json -Depth 3
        exit 0
    }
    Write-Host ""
    Write-Host "  CACHE PREFIX - stats" -ForegroundColor Cyan
    Write-Host "  ====================" -ForegroundColor Cyan
    Write-Host ("  Prefix:        {0} tokens (version {1})" -f $prefixTokens, $prev.hash) -ForegroundColor White
    Write-Host ("  Dinamico/quest: ~{0} tokens (estimado)" -f $dynamicTokens) -ForegroundColor DarkGray
    Write-Host ("  En {0} turnos:" -f $Turns) -ForegroundColor Yellow
    Write-Host ("    sin cache:  {0} tokens" -f $noCache) -ForegroundColor White
    Write-Host ("    con cache:  {0} tokens" -f $withCache) -ForegroundColor Green
    Write-Host ("    ahorro:     {0} tokens ({1}%)" -f $saved, $savedPct) -ForegroundColor Green
    Write-Host ""
    exit 0
}
