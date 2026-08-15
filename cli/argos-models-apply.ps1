#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS MODELS APPLY - Aplica .arnes/agent-models.json a los agentes instalados de OpenCode

.DESCRIPTION
Cada agente del party (vivi, ansem, auron, kuja...) se define como subagente en
~/.config/opencode/agents/<name>.md. Sin frontmatter de modelo, el subagente usa
el modelo del agente primario que lo invoca (hoy: qwen3.8-max de Atlas, por eso
todo el trabajo cae en un solo modelo y no se ve uso por modelo).

Este script inyecta `model: <modelo>` en el frontmatter de cada agente instalado,
para que cada uno use SU modelo al delegar. Es el eslabon que conecta
argos configure (que escribe agent-models.json) con los agentes reales.

.EXAMPLE
.\argos-models-apply.ps1
.\argos-models-apply.ps1 -ModelsPath C:\ruta\.arnes\agent-models.json
#>
[CmdletBinding()]
param(
    [string]$ModelsPath = '',
    [switch]$SkipBackup
)

$ErrorActionPreference = 'Stop'
$AgentsDir = Join-Path $env:USERPROFILE '.config\opencode\agents'
$BackupDir = Join-Path $env:USERPROFILE '.config\arnes\backups'
# Modelos GLOBALES de la maquina (una vez por computadora)
$GlobalConfigDir = Join-Path $env:USERPROFILE '.config\arnes'
$DefaultModelsPath = Join-Path $GlobalConfigDir 'agent-models.json'
# Migracion: si el global no existe pero hay un agent-models local del proyecto, se migra
if (-not (Test-Path $DefaultModelsPath)) {
    $local = Join-Path (Get-Location) '.arnes\agent-models.json'
    if (Test-Path $local) {
        if (-not (Test-Path $GlobalConfigDir)) { New-Item -ItemType Directory -Path $GlobalConfigDir -Force | Out-Null }
        Copy-Item $local $DefaultModelsPath -Force
        Write-Host '  [OK] agent-models migrado a config GLOBAL de la maquina.' -ForegroundColor Green
    }
}

if (-not $ModelsPath) { $ModelsPath = $DefaultModelsPath }
if (-not (Test-Path $ModelsPath)) {
    Write-Host "  [!] No encontre $ModelsPath. Primero: argos configure" -ForegroundColor Yellow
    exit 1
}
$am = Get-Content $ModelsPath -Raw | ConvertFrom-Json
if (-not $am.agents) {
    Write-Host '  [!] agent-models.json no tiene seccion agents.' -ForegroundColor Yellow
    exit 1
}
if (-not (Test-Path $AgentsDir)) {
    Write-Host "  [!] No existe $AgentsDir. Corre primero: atlas sync (SyncAgents)" -ForegroundColor Yellow
    exit 1
}

# === Leer agente con reparacion de mojibake cp1252->UTF-8 (em-dash "â€"" -> "—") ===
function Read-AgentFile {
    param([string]$Path, [ref]$HasBom, [ref]$RawText)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $HasBom.Value = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $text = [System.IO.File]::ReadAllText($Path)  # UTF-8 con deteccion de BOM
    $RawText.Value = $text  # Contenido actual en disco (para saltarse escrituras identicas)
    # Reparacion por LINEA: si la linea es el mojibake cp1252 de un UTF-8 valido, restaurarla.
    # Seguro: solo aplica si el round-trip inverso devuelve la linea original.
    try {
        $cp1252 = [System.Text.Encoding]::GetEncoding(1252)
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $lines = $text -split "`n"
        $fixed = foreach ($line in $lines) {
            try {
                $cand = $utf8NoBom.GetString($cp1252.GetBytes($line))
                $chk = $cp1252.GetString($utf8NoBom.GetBytes($cand))
                if ($chk -eq $line -and $cand -ne $line) { $cand } else { $line }
            } catch { $line }
        }
        $text = $fixed -join "`n"
    } catch {}
    return $text
}

# === Inyectar (o crear) frontmatter con model en un archivo de agente ===
function Set-ModelFrontmatter {
    param([string]$Path, [string]$Model, [string]$Description)

    # Atlas es el ORQUESTADOR: debe ser primary (no subagent) para poder abrir opencode como agente inicial
    $leafName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $isAtlas = $leafName -match '^(atlas|atlas-player)$'
    $mode = if ($isAtlas) { 'primary' } else { 'subagent' }

    $hasBom = $false
    $existing = $null
    $content = Read-AgentFile -Path $Path -HasBom ([ref]$hasBom) -RawText ([ref]$existing)

    # Derivar description del primer H1 si no se pasa
    if (-not $Description) {
        $m = [regex]::Match($content, '(?m)^#\s+(.+)$')
        if ($m.Success) { $Description = $m.Groups[1].Value.Trim() }
    }
    if (-not $Description) { $Description = (Split-Path $Path -LeafBase) }

    if ($content -match '(?s)^\s*---\r?\n(.*?)\r?\n---') {
        # Frontmatter existente: reemplazar o agregar model y mode
        $fm = $Matches[1]
        $fmLines = @($fm -split "`r?`n" | Where-Object { $_ -notmatch '^\s*(model|mode|description):' })
        $fmLines = @("mode: $mode", "model: $Model", "description: $Description") + $fmLines
        $newFm = $fmLines -join "`n"
        $content = $content -replace '(?s)^\s*---\r?\n(.*?)\r?\n---', ("---`n" + $newFm + "`n---")
    } else {
        # Sin frontmatter: prepender
        $header = "---`nmode: $mode`nmodel: $Model`ndescription: $Description`n---`n`n"
        $content = $header + $content
    }

    # Solo escribir si el contenido generado difiere del existente:
    # evita reescribir agentes intactos en cada 'argos --sync' y acorta ventanas de lock.
    if ($content -ne $existing) {
        $encoding = New-Object System.Text.UTF8Encoding($hasBom)
        [System.IO.File]::WriteAllText($Path, $content, $encoding)
    }
}

# === MAIN ===
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$applied = @()
$skipped = @()
$omoApplied = @()

if (-not $SkipBackup -and -not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

# Destinos de sincronizacion (ademas de agents/*.md):
# 1) oh-my-opencode.jsonc -> agents.<name>.model  (JSONC con comentarios, edicion por regex)
# 2) opencode.json        -> agent.<name>.model   (JSON plano, edicion por regex)
$OmoConfigPath = Join-Path $env:USERPROFILE '.config\opencode\oh-my-opencode.jsonc'
$OpencodeConfigPath = Join-Path $env:USERPROFILE '.config\opencode\opencode.json'

foreach ($prop in $am.agents.PSObject.Properties) {
    $name = $prop.Name
    $model = $prop.Value
    if ([string]::IsNullOrWhiteSpace($model)) { continue }
    # Alias: la config usa 'atlas' pero el agente instalado en opencode es 'atlas-player'
    $targetName = $name
    if ($name -eq 'atlas' -and -not (Test-Path (Join-Path $AgentsDir 'atlas.md'))) {
        $targetName = 'atlas-player'
    }
    $target = Join-Path $AgentsDir "$targetName.md"
    if (Test-Path $target) {
        if (-not $SkipBackup) {
            Copy-Item $target (Join-Path $BackupDir "$targetName.md.bak-$ts") -Force
        }
        Set-ModelFrontmatter -Path $target -Model $model
        $applied += "$name -> $model"
    } else {
        $skipped += "$name (sin $targetName.md en agents)"
    }

    # Sincronizar a oh-my-opencode.jsonc (si el agente esta definido ahi)
    if (Test-Path $OmoConfigPath) {
        $omoText = [System.IO.File]::ReadAllText($OmoConfigPath)
        # Pattern: "name": { ... "model": "..." ... }  -> reemplazar SOLO el model de ese agente
        $pat = '("' + [regex]::Escape($name) + '"\s*:\s*\{[^}]*?"model"\s*:\s*")[^"]+(")'
        if ($omoText -match $pat) {
            if (-not $SkipBackup) {
                Copy-Item $OmoConfigPath (Join-Path $BackupDir "oh-my-opencode.jsonc.bak-$ts") -Force
            }
            $newOmo = [regex]::Replace($omoText, $pat, ('${1}' + $model + '${2}'))
            if ($newOmo -ne $omoText) {
                [System.IO.File]::WriteAllText($OmoConfigPath, $newOmo, (New-Object System.Text.UTF8Encoding($true)))
                $omoApplied += "$name -> $model (oh-my-opencode.jsonc)"
            }
        }
    }

    # Sincronizar a opencode.json (si el agente esta definido con model)
    if (Test-Path $OpencodeConfigPath) {
        $ocText = [System.IO.File]::ReadAllText($OpencodeConfigPath)
        $pat2 = '("' + [regex]::Escape($name) + '"\s*:\s*\{[^}]*?"model"\s*:\s*")[^"]+(")'
        if ($ocText -match $pat2) {
            if (-not $SkipBackup) {
                Copy-Item $OpencodeConfigPath (Join-Path $BackupDir "opencode.json.bak-$ts") -Force
            }
            $newOc = [regex]::Replace($ocText, $pat2, ('${1}' + $model + '${2}'))
            if ($newOc -ne $ocText) {
                [System.IO.File]::WriteAllText($OpencodeConfigPath, $newOc, (New-Object System.Text.UTF8Encoding($true)))
                $omoApplied += "$name -> $model (opencode.json)"
            }
        }
    }
}

Write-Host ''
Write-Host '  ARNES ARGOS - MODELOS APLICADOS A AGENTES' -ForegroundColor Cyan
Write-Host '  ========================================' -ForegroundColor Cyan
foreach ($line in $applied) { Write-Host "  [OK] $line" -ForegroundColor Green }
if ($omoApplied.Count -gt 0) {
    Write-Host ''
    Write-Host '  Sincronizado tambien a:' -ForegroundColor Cyan
    foreach ($line in $omoApplied) { Write-Host "  [OK] $line" -ForegroundColor Green }
}
if ($skipped.Count -gt 0) {
    Write-Host ''
    Write-Host "  Omitidos (sin archivo de agente instalado):" -ForegroundColor Yellow
    foreach ($s in $skipped) { Write-Host "    $s" -ForegroundColor Yellow }
}
Write-Host ''
Write-Host "  [OK] $($applied.Count) agentes con modelo propio (frontmatter) + $($omoApplied.Count) sincronizaciones a configs OMO." -ForegroundColor Green
Write-Host '  Reinicia la sesion de argos/opencode para que los agentes tomen su modelo.' -ForegroundColor DarkGray
