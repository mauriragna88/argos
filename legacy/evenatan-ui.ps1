# evenatan-ui.ps1 - Interactive RPG UI for Atlas Harness
# =============================================
# T6.6 - Ventana interactiva RPG con interfaz rojo y negro.
# Muestra el party, HP/MP bars, quest log, y slash commands.
# No requiere IA conectada - es la UI standalone.
#
# [!] LEGADO/DEPRECADO: el CLI activo del harness es `argos`
#     (cli/argos.ps1). Este script se mantiene por compatibilidad
#     con activate.ps1/atlas.ps1 y no recibe features nuevas.
#
# Uso: .\cli\evenatan-ui.ps1
#      .\cli\evenatan-ui.ps1 -Quest "crea login form"
#      .\cli\evenatan-ui.ps1 -NoColor

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Quest = "",
    [switch]$NoColor,
    [switch]$OneShot
)

$ErrorActionPreference = "Stop"

# === Resolver ROOT ===
$ScriptDir = $PSScriptRoot
if (Test-Path (Join-Path $ScriptDir "..\core\atlas-player.agent.md")) {
    $ROOT = Resolve-Path (Join-Path $ScriptDir "..")
} else {
    $homeArnes = Join-Path $HOME "arnes"
    if (Test-Path (Join-Path $homeArnes "core\atlas-player.agent.md")) {
        $ROOT = Resolve-Path $homeArnes
    } else {
        Write-Error "No encuentro el repo arnes."
        exit 1
    }
}
$ArnesDir = Join-Path $ROOT ".arnes"

# === Cargar config ===
$ConfigFile = Join-Path $ArnesDir "config.json"
$LedgerFile = Join-Path $ArnesDir "quest-ledger.json"
$ProfileFile = Join-Path $ArnesDir "repo-profile.json"
$SaveDir = Join-Path $ArnesDir "save"

$cfg = $null
if (Test-Path $ConfigFile) {
    try { $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json } catch { }
}
$ledger = $null
if (Test-Path $LedgerFile) {
    try { $ledger = Get-Content $LedgerFile -Raw | ConvertFrom-Json } catch { }
}
$repoProfile = $null
if (Test-Path $ProfileFile) {
    try { $repoProfile = Get-Content $ProfileFile -Raw | ConvertFrom-Json } catch { }
}

# === Colores ===
$UseColor = -not $NoColor
function C($text, [ConsoleColor]$color = [ConsoleColor]::White) {
    if ($UseColor) {
        Write-Host $text -ForegroundColor $color
    } else {
        Write-Host $text
    }
}

$RED = [ConsoleColor]::Red
$DARK = [ConsoleColor]::DarkGray
$WHITE = [ConsoleColor]::White
$YELLOW = [ConsoleColor]::Yellow
$CYAN = [ConsoleColor]::Cyan
$GREEN = [ConsoleColor]::Green
$MAGENTA = [ConsoleColor]::Magenta

# === Party data ===
$Party = @(
    @{ Name = "Vivi";    Class = "Mage";   Role = "Frontend DPS";   HP = 25; MaxHP = 25; MP = 8;  MaxMP = 8;  Color = $YELLOW },
    @{ Name = "Eiko";    Class = "Cleric"; Role = "Healer / DevOps"; HP = 50; MaxHP = 50; MP = 6;  MaxMP = 6;  Color = $MAGENTA },
    @{ Name = "Ansem";   Class = "Paladin"; Role = "Backend Tank";  HP = 60; MaxHP = 60; MP = 10; MaxMP = 10; Color = $CYAN },
    @{ Name = "Kuja";    Class = "Rogue";  Role = "QA / Security";  HP = 30; MaxHP = 30; MP = 5;  MaxMP = 5;  Color = $MAGENTA },
    @{ Name = "Amarant"; Class = "Monk";   Role = "Architecture";   HP = 35; MaxHP = 35; MP = 12; MaxMP = 12; Color = $YELLOW },
    @{ Name = "Eremez";  Class = "Ranger"; Role = "Research";       HP = 20; MaxHP = 20; MP = 3;  MaxMP = 3;  Color = $GREEN }
)

$Auditors = @(
    @{ Name = "Varys";  Role = "Tracker / Hand-off" },
    @{ Name = "Tywin";  Role = "Verifier (PASS/FAIL)" },
    @{ Name = "Sam";    Role = "Elder Counselor" }
)

$Specials = @(
    @{ Name = "Auron"; Role = "Security Warden" },
    @{ Name = "Bran";  Role = "Seer / Strategist" },
    @{ Name = "Quina"; Role = "Token Banker" }
)

# === UI Helpers ===
function Header {
    param([string]$Title)
    $bar = "=" * 64
    C ""
    C $bar $RED
    C "  $Title" $RED
    C $bar $RED
}

function HPBar($current, $max, [ConsoleColor]$color = [ConsoleColor]::Green) {
    $width = 20
    $ratio = if ($max -gt 0) { $current / $max } else { 0 }
    $filled = [int]($ratio * $width)
    $empty = $width - $filled
    $bar = ("#" * $filled) + ("-" * $empty)
    return "[$bar] $current/$max"
}

function ShowParty {
    C ""
    C "  == PARTY MEMBERS ==" $RED
    foreach ($m in $Party) {
        $line = "  {0,-8} ({1,-7}) {2,-20}" -f $m.Name, $m.Class, $m.Role
        C $line $WHITE
        C "    HP $($m.HP)/$($m.MaxHP)  MP $($m.MP)/$($m.MaxMP)" $DARK
    }
}

function ShowAuditors {
    C ""
    C "  == AUDITORES ==" $RED
    foreach ($a in $Auditors) {
        C ("  {0,-8} {1}" -f $a.Name, $a.Role) $WHITE
    }
    C ""
    C "  == ESPECIALES ==" $RED
    foreach ($s in $Specials) {
        C ("  {0,-8} {1}" -f $s.Name, $s.Role) $WHITE
    }
}

function ShowStatus {
    C ""
    C "  == STATUS ==" $RED
    if ($cfg) {
        $sub = ($cfg.subscription.PSObject.Properties | Where-Object { $_.Value } | Select-Object -First 1).Name
        C "  Subscription: $sub" $WHITE
        C "  Theme: $($cfg.preferences.theme)" $DARK
    }
    if ($ledger) {
        $qCount = $ledger.stats.total_quests
        $tCount = $ledger.stats.total_tokens_used
        C "  Quests completados: $qCount" $WHITE
        C "  Tokens usados: $tCount" $WHITE
        $weeklyRem = $ledger.limits.weekly_tokens_remaining
        $weeklyTotal = $ledger.limits.weekly_tokens_budget
        C "  Budget semanal: $weeklyRem / $weeklyTotal tokens" $DARK
    }
    if ($repoProfile) {
        C "  Repo tier: $($repoProfile.repo_tier)" $YELLOW
        C "  Recommended party size: $($repoProfile.recommended_party_size)" $DARK
    }
}

function ShowSkills {
    C ""
    C "  == SKILLS RESUMEN ==" $RED
    C "  Vivi (Mage):    Fireball, Flare, Inferno, Meteor Shower, Design Mastery" $YELLOW
    C "  Eiko (Cleric):  Mend, Esuna, Cura, Protect, Shell, Mass Heal" $MAGENTA
    C "  Ansem (Paladin): Smite, Divine Shield, Holy Ground, Judgment, Bulwark" $CYAN
    C "  Kuja (Rogue):   Backstab, Poison Tipped, Detect Traps, Shadow Clone, Eviscerate" $MAGENTA
    C "  Amarant (Monk): Foresight, Inner Peace, Mantra, Meditation, Zen Architecture" $YELLOW
    C "  Eremez (Ranger): Mark, Tracker, Scout, Swarm, Wide Net" $GREEN
}

function ShowAuditDocs {
    C ""
    C "  == VARYS DOCUMENTALIST - AUDIT ==" $RED
    C "  Mis pajaritos estan volando sobre el repo..." $WHITE
    C "  (Auditoria offline - no real scan)" $DARK
    C "  Para audit real: abre OpenCode y usa @varys-documentalist" $DARK
}

function ShowHelp {
    C ""
    C "  == COMANDOS DISPONIBLES ==" $RED
    C "  /party     - Ver party members" $WHITE
    C "  /audit     - Ver auditores" $WHITE
    C "  /special   - Ver especiales" $WHITE
    C "  /skills    - Ver skills tree" $WHITE
    C "  /status    - Ver status del proyecto" $WHITE
    C "  /audit-docs- Audit de documentacion (Varys Documentalist)" $WHITE
    C "  /save      - Guardar estado" $WHITE
    C "  /pause     - Pausar loop" $WHITE
    C "  /resume    - Reanudar" $WHITE
    C "  /help      - Esta ayuda" $WHITE
    C "  /quit      - Salir" $WHITE
    C ""
    C "  O escribe un QUEST directamente:" $DARK
    C "    > crea login form con Zod, tests Vitest, deploy Vercel" $DARK
}

function SaveState {
    if (-not (Test-Path $SaveDir)) {
        New-Item -ItemType Directory -Path $SaveDir -Force | Out-Null
    }
    $state = @{
        saved_at = (Get-Date -Format "o")
        party_hp = $Party | ForEach-Object { @{ name = $_.Name; hp = $_.HP; mp = $_.MP } }
    }
    $stateFile = Join-Path $SaveDir "quest-state.json"
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $stateFile -Encoding UTF8
    C "  Estado guardado en $stateFile" $GREEN
}

# === MAIN ===
Header "ATLAS HARNESS RPG - EVENATAN UI"
C "  Rojo & Negro, Atlas de la Liga MX" $RED
C ""

if ($cfg) {
    $pName = $cfg.player.name
    C "  Player: $pName" $WHITE
}
if ($repoProfile) {
    C "  Repo tier: $($repoProfile.repo_tier) (party size: $($repoProfile.recommended_party_size))" $YELLOW
}

ShowParty
ShowAuditors

if ($Quest) {
    C ""
    C "  == QUEST INICIAL ==" $RED
    C "  > $Quest" $YELLOW
    C "  (Para ejecutar: abre OpenCode y usa @atlas-player con este quest)" $DARK
}

if ($OneShot) {
    C ""
    C "  Modo one-shot. Saliendo." $DARK
    exit 0
}

ShowHelp

# === Loop interactivo ===
while ($true) {
    C ""
    $prompt = "ATLAS> "
    if ($UseColor) {
        Write-Host -NoNewline $prompt -ForegroundColor $RED
    } else {
        Write-Host -NoNewline $prompt
    }
    $inp = Read-Host
    if ([string]::IsNullOrWhiteSpace($inp)) { continue }

    switch -Regex ($inp) {
        '^/quit|^/exit' {
            C "  Cerrando ATLAS." $WHITE
            break
        }
        '^/party'    { ShowParty }
        '^/audit$'   { ShowAuditors }
        '^/special'  { ShowAuditors }
        '^/skills'   { ShowSkills }
        '^/status'   { ShowStatus }
        '^/audit-docs' { ShowAuditDocs }
        '^/save'     { SaveState }
        '^/pause'    { C "  PAUSE. Escribe /resume." $YELLOW }
        '^/resume'   { C "  RESUMED!" $GREEN }
        '^/help'     { ShowHelp }
        '^/'         { C "  Comando no reconocido. Usa /help" $YELLOW }
        default {
            C "  [QUEST RECEIVED]" $WHITE
            C "  > $inp" $DARK
            C "  (Para ejecutar: abre OpenCode y usa @atlas-player)" $DARK
        }
    }
    if ($inp -match '^/quit|^/exit') { break }
}

C ""
C "  ATLAS session cerrada." $RED
