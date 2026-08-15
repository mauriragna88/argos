#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS TARGET - selecciona y lanza el CLI de trabajo (OpenCode, Codex, Claude o Freebuff)
cargando el entorno ARNES (agentes/personas).

.DESCRIPTION
El puente entre ARNES y el CLI que quieras usar:
  opencode  -> sincroniza los 16 agentes con modelo propio (~/.config/opencode/agents) y abre opencode
  codex     -> despliega la persona Atlas a ~/.codex/AGENTS.md y abre codex
  claude    -> despliega la persona Atlas a ~/.claude/CLAUDE.md y abre claude
  freebuff  -> despliega la persona Atlas + roster del party a AGENTS.md del proyecto y abre freebuff
  dsh       -> despliega la persona Atlas a AGENTS.md del repo deepseek-harness, valida OSMA
               y arranca el servidor web de DeepSeek Harness (pnpm dsh web, http://127.0.0.1:3080).
               El modelo se elige por sesion dentro de la Web UI (Settings -> Models).

El default queda guardado en ~/.config/arnes/target.json (UNA vez por maquina).
Para opencode/codex/claude, el modelo lo gestiona el propio CLI; ARNES aporta
personas, agentes y memoria (.arnes/arnes.db accesible por archivo).

.EXAMPLE
.\argos-target.ps1                        # lanza el default (opencode si no hay config)
.\argos-target.ps1 -Target auto           # menu si hay varios CLIs instalados
.\argos-target.ps1 -Target codex -Quest "haz login con Zod"
.\argos-target.ps1 set codex              # fija el default
.\argos-target.ps1 show
.\argos-target.ps1 list
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('', 'launch', 'set', 'show', 'list')]
    [string]$Command = 'launch',

    [Parameter(Position = 1)]
    [ValidateSet('', 'opencode', 'codex', 'claude', 'freebuff', 'dsh', 'auto')]
    [string]$Target = '',

    [string]$Name = '',
    [string]$Quest = '',

    # Overrides para tests (hermetico)
    [string]$ConfigDir = '',
    [string]$TargetDir = '',
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$PersonaFile = Join-Path $Root 'core\atlas-player.agent.md'

if (-not $ConfigDir) { $ConfigDir = Join-Path $env:USERPROFILE '.config\arnes' }
if (-not $TargetDir) { $TargetDir = $ConfigDir }
$TargetFile = Join-Path $ConfigDir 'target.json'
# Ruta del checkout de DeepSeek Harness (default bajo el perfil del usuario)
$DshDir = (Join-Path $env:USERPROFILE 'deepseek-harness')

# ==== Targets disponibles ====
$TargetMeta = @{
    opencode = 'OpenCode (16 agentes + modelos por agente)'
    codex    = 'Codex CLI (persona Atlas en AGENTS.md)'
    claude   = 'Claude Code (persona Atlas en CLAUDE.md)'
    freebuff = 'Freebuff CLI (persona Atlas + party en AGENTS.md del proyecto)'
    dsh      = 'DeepSeek Harness (web en :3080, ARGOS/OSMA precargado)'
}

function Get-InstalledTargets {
    $result = @()
    if (Get-Command opencode -ErrorAction SilentlyContinue) { $result += 'opencode' }
    if (Get-Command codex -ErrorAction SilentlyContinue) { $result += 'codex' }
    if (Get-Command claude -ErrorAction SilentlyContinue) { $result += 'claude' }
    if (Get-Command freebuff -ErrorAction SilentlyContinue) { $result += 'freebuff' }
    if (Test-Path $DshDir) { $result += 'dsh' }
    return $result
}

# Read-Input local: devuelve vacio en modo NO interactivo (igual que argos.ps1)
function Read-Input {
    param([string]$Prompt = '')
    try { return Read-Host $Prompt } catch { return '' }
}

function Get-CurrentTarget {
    if (Test-Path $TargetFile) {
        try {
            $cfg = Get-Content $TargetFile -Raw | ConvertFrom-Json
            if ($cfg.target) { return [string]$cfg.target }
        } catch { }
    }
    return 'opencode'
}

function Write-AtlasPersona {
    param([string]$Target)
    if (-not (Test-Path $PersonaFile)) {
        Write-Host '  [!] No se encontro core/atlas-player.agent.md' -ForegroundColor Yellow
        return $false
    }
    $persona = Get-Content $PersonaFile -Raw
    $header = "# ARNES ARGOS - Atlas (entorno generado por 'argos target $Target')`n# Persona del orquestador. La memoria del proyecto vive en .arnes/ (arnes.db).`n`n"
    if ($Target -eq 'codex') {
        $out = Join-Path $TargetDir 'AGENTS.md'
    } else {
        $out = Join-Path $TargetDir 'CLAUDE.md'
    }
    if (-not (Test-Path (Split-Path $out -Parent))) { New-Item -ItemType Directory -Path (Split-Path $out -Parent) -Force | Out-Null }
    Set-Content -Path $out -Value ($header + $persona) -Encoding UTF8
    Write-Host ("  [OK] Persona Atlas desplegada: {0}" -f $out) -ForegroundColor Green
    return $true
}

function Get-AgentDisplayName {
    param([string]$Path)
    # Del titulo H1: "# VIVI — Mage (Frontend DPS)" -> "Vivi"
    $first = (Get-Content $Path -TotalCount 6 | Where-Object { $_ -match '^#' } | Select-Object -First 1)
    if ($first -and $first -match '^#\s+([^\s\-—–|]+)') {
        $raw = $Matches[1].Trim()
        # Capitalizar primera letra, resto en minusculas
        return ($raw.Substring(0, 1).ToUpper() + $raw.Substring(1).ToLower())
    }
    return [System.IO.Path]::GetFileNameWithoutExtension($Path).Replace('.agent', '')
}

function Get-AgentDescription {
    param([string]$Path)
    # Primeras lineas de la blockquote de identidad
    $desc = @()
    foreach ($line in (Get-Content $Path -TotalCount 12)) {
        $t = $line -replace '^>\s*', ''
        if ($t -and $t -notmatch '^\s*$') { $desc += $t }
        if ($desc.Count -ge 2) { break }
    }
    if ($desc.Count -eq 0) { return 'Agente del party ARNES' }
    return ($desc -join ' ').Substring(0, [Math]::Min(180, ($desc -join ' ').Length))
}

function Write-ClaudeParty {
    # Claude Code: subagentes en ~/.claude/agents/*.md con frontmatter name+description
    $agentsDir = Join-Path $TargetDir 'agents'
    New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
    $sources = @()
    $sources += Get-Item (Join-Path $Root 'core\atlas-player.agent.md') -ErrorAction SilentlyContinue
    $sources += Get-ChildItem (Join-Path $Root 'core\classes\*.agent.md') -ErrorAction SilentlyContinue
    $sources += Get-ChildItem (Join-Path $Root 'core\auditors\*.agent.md') -ErrorAction SilentlyContinue
    # El party canonico de 16 NO incluye varys-documentalist (igual que el sync de opencode)
    $sources = @($sources | Where-Object { $_.Name -notlike 'varys-documentalist*' })
    $count = 0
    $used = @()
    foreach ($src in $sources) {
        $display = Get-AgentDisplayName $src.FullName
        # Colision de nombre (ej: Varys vs Varys-Documentalist): usar el id del archivo
        if ($used -contains $display) {
            $display = [System.IO.Path]::GetFileNameWithoutExtension($src.Name).Replace('.agent', '')
        }
        $used += $display
        $desc = Get-AgentDescription $src.FullName
        $body = Get-Content $src.FullName -Raw
        $front = "---`nname: $display`ndescription: $desc`n---`n`n"
        $out = Join-Path $agentsDir "$display.md"
        Set-Content -Path $out -Value ($front + $body) -Encoding UTF8
        $count++
    }
    Write-Host ("  [OK] Party desplegado a Claude: {0} agentes en {1}" -f $count, $agentsDir) -ForegroundColor Green
    return $true
}

function Write-RosterBundle {
    # Codex/Freebuff: AGENTS.md jerarquico con persona Atlas + roster del party (sin subagentes con modelo)
    param([string]$Target, [string]$Out)
    $persona = Get-Content $PersonaFile -Raw
    $roster = @()
    $roster += Get-ChildItem (Join-Path $Root 'core\classes\*.agent.md') -ErrorAction SilentlyContinue
    $roster += Get-ChildItem (Join-Path $Root 'core\auditors\*.agent.md') -ErrorAction SilentlyContinue
    $rosterLines = foreach ($r in $roster) {
        $display = Get-AgentDisplayName $r.FullName
        $roleLine = (Get-Content $r.FullName -TotalCount 1) -replace '^#\s+', ''
        "  - **$display** - $roleLine"
    }
    $header = "# ARNES ARGOS - Atlas (entorno generado por 'argos target $Target')`n`n"
    $rosterBlock = "`n## Party ARNES (roles)`n`nSoy el orquestador de este party. Para tareas especializadas invoca el rol adecuado:`n`n" + ($rosterLines -join "`n") + "`n`nLa memoria del proyecto vive en .arnes/ (arnes.db, exports JSONL en .arnes/memory/export/). Consultala antes de decidir.`n`n"
    if (-not (Test-Path (Split-Path $Out -Parent))) { New-Item -ItemType Directory -Path (Split-Path $Out -Parent) -Force | Out-Null }
    Set-Content -Path $Out -Value ($header + $persona + $rosterBlock) -Encoding UTF8
    Write-Host ("  [OK] Entorno desplegado: {0}" -f $Out) -ForegroundColor Green
    return $true
}

switch ($Command) {
    'show' {
        $current = Get-CurrentTarget
        Write-Host ("  Target actual: {0} ({1})" -f $current, $TargetMeta[$current]) -ForegroundColor Cyan
        Write-Host '  Para cambiar: argos target set <opencode|codex|claude|freebuff|dsh>' -ForegroundColor DarkGray
        exit 0
    }
    'list' {
        Write-Host ''
        Write-Host '  ARNES ARGOS - TARGETS' -ForegroundColor Cyan
        $current = Get-CurrentTarget
        $installed = Get-InstalledTargets
        foreach ($k in @('opencode', 'codex', 'claude', 'freebuff', 'dsh')) {
            $mark = if ($k -eq $current) { ' *' } else { '  ' }
            $status = if ($k -in $installed) { 'instalado' } else { 'NO instalado' }
            Write-Host ("  {0} {1,-10} {2}  [{3}]" -f $mark, $k, $TargetMeta[$k], $status) -ForegroundColor White
        }
        Write-Host ''
        Write-Host '  Uso: argos target set <nombre> | argos target <nombre> [quest]' -ForegroundColor DarkGray
        Write-Host ''
        exit 0
    }
    'set' {
        if (-not $Name) {
            Write-Host '  Uso: argos target set <opencode|codex|claude|freebuff|dsh>' -ForegroundColor Yellow
            exit 1
        }
        if (-not $TargetMeta.ContainsKey($Name)) {
            Write-Host "  [!] Target invalido: $Name. Usa opencode, codex, claude, freebuff o dsh." -ForegroundColor Yellow
            exit 1
        }
        if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
        @{ target = $Name } | ConvertTo-Json | Set-Content -Path $TargetFile -Encoding UTF8
        Write-Host ("  [OK] Target default: {0} ({1})" -f $Name, $TargetMeta[$Name]) -ForegroundColor Green
        exit 0
    }
    default {
        # ==== LAUNCH ====
        $resolved = if ($Target) { $Target } else { Get-CurrentTarget }

        if ($resolved -eq 'auto') {
            # Si hay default persistido, usalo directo (sin preguntar)
            if (Test-Path $TargetFile) {
                $resolved = Get-CurrentTarget
                Write-Host ("  Usando target configurado: {0} ({1})" -f $resolved, $TargetMeta[$resolved]) -ForegroundColor DarkGray
                Write-Host '  Para cambiarlo: argos target set <nombre> | argos target list' -ForegroundColor DarkGray
            } else {
                $installed = Get-InstalledTargets
                if ($installed.Count -eq 0) {
                    Write-Host '  [!] No hay ningun CLI instalado (opencode/codex/claude/dsh).' -ForegroundColor Red
                    Write-Host '      Instala al menos uno y vuelve a intentar.' -ForegroundColor Yellow
                    exit 1
                }
                if ($installed.Count -eq 1) {
                    $resolved = $installed[0]
                } else {
                    Write-Host ''
                    Write-Host '  ARNES ARGOS - ELIGE TU ENTORNO' -ForegroundColor DarkRed
                    for ($i = 0; $i -lt $installed.Count; $i++) {
                        Write-Host ("  [{0}] {1} - {2}" -f ($i + 1), $installed[$i], $TargetMeta[$installed[$i]]) -ForegroundColor White
                    }
                    $sel = Read-Input ("  Elige (1-{0})" -f $installed.Count)
                    $idx = 0
                    if ([int]::TryParse($sel, [ref]$idx) -and $idx -ge 1 -and $idx -le $installed.Count) {
                        $resolved = $installed[$idx - 1]
                    } else {
                        Write-Host '  Usando default: opencode' -ForegroundColor Yellow
                        $resolved = 'opencode'
                    }
                }
            }
        }

        if (-not $TargetMeta.ContainsKey($resolved)) {
            Write-Host "  [!] Target invalido: $resolved" -ForegroundColor Yellow
            exit 1
        }

        Write-Host ''
        Write-Host ("  ARNES -> {0}  |  {1}" -f $resolved.ToUpper(), $TargetMeta[$resolved]) -ForegroundColor DarkRed
        Write-Host ''

        switch ($resolved) {
            'opencode' {
                # Reutiliza el flujo completo (mutex + sync + verificacion + launch)
                if ($Quest) {
                    & (Join-Path $PSScriptRoot 'argos-opencode.ps1') -Quest $Quest
                } else {
                    & (Join-Path $PSScriptRoot 'argos-opencode.ps1')
                }
            }
            'codex' {
                Write-Host '  [1/2] Desplegando entorno a Codex...' -ForegroundColor Cyan
                [void](Write-RosterBundle -Target 'codex' -Out (Join-Path $TargetDir 'AGENTS.md'))
                Write-Host '  [2/2] Abriendo Codex...' -ForegroundColor Cyan
                if ($NoLaunch) { exit 0 }
                if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
                    Write-Host '  [!] codex no encontrado. Instala: npm install -g @openai/codex' -ForegroundColor Red
                    exit 1
                }
                if ($Quest) {
                    & codex exec $Quest
                } else {
                    & codex
                }
            }
            'freebuff' {
                Write-Host '  [1/2] Desplegando entorno a Freebuff (AGENTS.md del proyecto)...' -ForegroundColor Cyan
                # Freebuff lee AGENTS.md del root donde corre: el proyecto actual (o -TargetDir en tests)
                $freebuffDir = if ($PSBoundParameters.ContainsKey('TargetDir')) { $TargetDir } else { (Get-Location).Path }
                $fbOut = Join-Path $freebuffDir 'AGENTS.md'
                # AGENTS.md del proyecto es territorio del usuario: respaldar antes de sobrescribir
                if (Test-Path $fbOut) {
                    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
                    $bak = Join-Path $freebuffDir "AGENTS.md.bak-$ts"
                    Copy-Item $fbOut $bak -Force
                    Write-Host ("  [~] AGENTS.md existente respaldado: {0}" -f (Split-Path $bak -Leaf)) -ForegroundColor DarkGray
                }
                [void](Write-RosterBundle -Target 'freebuff' -Out $fbOut)
                Write-Host '  [2/2] Abriendo Freebuff (gratis, sin API keys)...' -ForegroundColor Cyan
                if ($NoLaunch) { exit 0 }
                if (-not (Get-Command freebuff -ErrorAction SilentlyContinue)) {
                    Write-Host '  [!] freebuff no encontrado. Instala: npm install -g freebuff' -ForegroundColor Red
                    exit 1
                }
                if ($Quest) {
                    Write-Host '  Freebuff es una TUI interactiva: escribe tu quest dentro del CLI.' -ForegroundColor Yellow
                }
                & freebuff
            }
            'claude' {
                # Claude Code lee ~/.claude/CLAUDE.md + ~/.claude/agents/ (no ~/.config/arnes).
                # Si el usuario no paso -TargetDir (tests si lo pasan), usa ~/.claude.
                if (-not $PSBoundParameters.ContainsKey('TargetDir')) {
                    $TargetDir = Join-Path $env:USERPROFILE '.claude'
                }
                Write-Host '  [1/3] Persona Atlas a CLAUDE.md...' -ForegroundColor Cyan
                [void](Write-AtlasPersona -Target 'claude')
                Write-Host '  [2/3] Desplegando party a Claude agents...' -ForegroundColor Cyan
                [void](Write-ClaudeParty)
                Write-Host '  [3/3] Abriendo Claude...' -ForegroundColor Cyan
                if ($NoLaunch) { exit 0 }
                if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
                    Write-Host '  [!] claude no encontrado. Instala: npm install -g @anthropic-ai/claude-code' -ForegroundColor Red
                    exit 1
                }
                if ($Quest) {
                    & claude -p $Quest
                } else {
                    & claude
                }
            }
            'dsh' {
                # DeepSeek Harness: despliega persona Atlas, valida OSMA y arranca el servidor web.
                if (-not (Test-Path $DshDir)) {
                    Write-Host ('  [!] No se encontro DeepSeek Harness en: {0}' -f $DshDir) -ForegroundColor Red
                    Write-Host '      Clonalo: git clone https://github.com/deepseek-ai/deepseek-harness.git (HOME)/deepseek-harness' -ForegroundColor Yellow
                    exit 1
                }
                Write-Host '  [1/3] DeepSeek Harness · ARGOS/OSMA ya cargan via plugin (no se toca AGENTS.md del repo)...' -ForegroundColor Cyan
                Write-Host '  [2/3] Validando OSMA (memoria)...' -ForegroundColor Cyan
                . (Join-Path $PSScriptRoot 'osma-resolve.ps1')
                if (Get-OsmaBrain) {
                    Write-Host ('  [OK] OSMA resuelto: {0}' -f (Get-OsmaBrain)) -ForegroundColor Green
                } else {
                    Write-Host '  [!] OSMA no encontrado. Instala: osma/install.ps1 o clona https://github.com/mauriragna88/osma' -ForegroundColor Yellow
                }
                if ($NoLaunch) { exit 0 }
                Push-Location $DshDir
                try {
                    # Si ya hay un DSH activo en el puerto, NO lanzar otro (chocaria el puerto y se colgaria).
                    $alive = $false
                    try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:3080' -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop; $alive = ($r.StatusCode -eq 200) } catch { $alive = $false }
                    if ($alive) {
                        Write-Host '  [3/3] DeepSeek Harness YA esta activo en http://127.0.0.1:3080' -ForegroundColor Green
                        Write-Host '        Abriendo el navegador...'
                        Start-Process 'http://127.0.0.1:3080'
                        Write-Host '        (argos target dsh no abre un 2do servidor; reclama aqui DSH.)' -ForegroundColor DarkGray
                        Write-Host '        El modelo se elige por sesion en Settings -> Models.' -ForegroundColor DarkGray
                    } else {
                        Write-Host ('  [3/3] Arrancando DeepSeek Harness ({0}) -> http://127.0.0.1:3080 ...' -f $DshDir) -ForegroundColor Cyan
                        Write-Host '       El modelo se elige por sesion en la Web UI (Settings -> Models).' -ForegroundColor DarkGray
                        & pnpm dsh web
                    }
                } finally { Pop-Location }
            }
        }
    }
}
