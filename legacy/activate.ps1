# arnes activate - CLI Final Atlas Harness RPG
# =============================================
# Uso: atlas (desde cualquier carpeta) o .\cli\activate.ps1
# Detecta plataforma, sync agentes a OpenCode, lanza OpenCode con Atlas como primary
# 12 agentes: Atlas + 6 party + 3 auditores + 3 pending

#Requires -Version 5.1
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'osma-resolve.ps1')

$ROOT = Resolve-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$ConfigDir = Join-Path $ROOT ".arnes"
$ConfigFile = Join-Path $ConfigDir "config.json"
$AtlasPromptFile = Join-Path $ROOT "core\atlas-player.agent.md"

$RED   = [ConsoleColor]::Red
$DARK  = [ConsoleColor]::DarkGray
$WHITE = [ConsoleColor]::White
$YELLOW = [ConsoleColor]::Yellow
$CYAN  = [ConsoleColor]::Cyan
$GREEN = [ConsoleColor]::Green

function Header($Txt) { $bar="="*64; Write-Host ""; Write-Host $bar -ForegroundColor $RED; Write-Host "  $Txt" -ForegroundColor $RED; Write-Host $bar -ForegroundColor $RED }
function Line($Txt) { Write-Host "  $Txt" -ForegroundColor $WHITE }
function Minor($Txt) { Write-Host "  $Txt" -ForegroundColor $DARK }
function OK($Txt) { Write-Host "  [OK] $Txt" -ForegroundColor $GREEN }
function Warn($Txt) { Write-Host "  [!] $Txt" -ForegroundColor $YELLOW }

# === DETECTAR PLATAFORMA ===
function DetectPlatform {
    $d=@()
    if (Test-Path "$env:USERPROFILE\.config\opencode") { $d+="OpenCode" }
    if (Get-Command codex -EA SilentlyContinue) { $d+="Codex" }
    if ((Test-Path "$env:USERPROFILE\.claude") -or (Get-Command claude -EA SilentlyContinue)) { $d+="Claude" }
    if (Get-Command freebuff -EA SilentlyContinue) { $d+="Freebuff" }
    if ($d.Count -eq 1) { return $d[0] }
    if ($d.Count -gt 1) {
        Write-Host "  Detectadas varias plataformas:" -ForegroundColor $WHITE
        for ($i=0;$i -lt $d.Count;$i++) { Write-Host "  [$($i+1)] $($d[$i])" -ForegroundColor $WHITE }
        $sel = Read-Host "Elige"
        return $d[[int]$sel-1]
    }
    Write-Host "  [1] OpenCode  [2] Codex  [3] Claude  [4] Freebuff" -ForegroundColor $WHITE
    return @("OpenCode","Codex","Claude","Freebuff")[[int](Read-Host "Elige")-1]
}

# === SYNC AGENTES A OPENCODE ===
function SyncAgents {
    $t = "$env:USERPROFILE\.config\opencode\agents"
    if (-not (Test-Path $t)) { New-Item -ItemType Directory -Path $t -Force | Out-Null }
    $c = Join-Path $ROOT "core"
    $agents = @{
        "atlas-player"= "atlas-player.agent.md"
        "vivi"="classes/vivi.agent.md"; "eiko"="classes/eiko.agent.md"
        "ansem"="classes/paladin.agent.md"; "kuja"="classes/rogue.agent.md"
        "amarant"="classes/monk.agent.md"; "eremez"="classes/ranger.agent.md"
        "varys"="auditors/varys.agent.md"; "tywin"="auditors/tywin.agent.md"
        "sam"="auditors/sam.agent.md"
        "auron"="auditors/auron.agent.md"; "bran"="auditors/bran.agent.md"
        "quina"="auditors/quina.agent.md"
    }
    $count = 0
    $agents.GetEnumerator() | ForEach-Object {
        $s = Join-Path $ROOT $_.Value
        if (Test-Path $s) { Copy-Item $s -Destination (Join-Path $t "$($_.Key).md") -Force; $count++ }
    }
    OK "$count agentes sincronizados a $t"
}

# === Copiar skill trees a opencode/skills/atlas/ ===
function SyncSkillTrees {
    $t = "$env:USERPROFILE\.config\opencode\skills\atlas"
    if (-not (Test-Path $t)) { New-Item -ItemType Directory -Path $t -Force | Out-Null }
    $s = Join-Path $ROOT "core\skills"
    if (-not (Test-Path $s)) { Warn "No hay skill trees en $s"; return }
    $count = 0
    Get-ChildItem $s -Filter "*.json" | ForEach-Object {
        Copy-Item $_.FullName -Destination (Join-Path $t $_.Name) -Force
        $count++
    }
    OK "$count skill trees copiados a $t"
}

# === DESCUBRIR PROVIDERS DISPONIBLES EN OPENCODE ===
function Get-OpenCodeProviders {
    # Parsea salida de `opencode auth list` para extraer provider IDs
    try {
        $ocExe = (Get-Command opencode -EA SilentlyContinue).Source
        if (-not $ocExe) { $ocExe = "C:\Users\LapOne Mx\AppData\Roaming\npm\opencode.ps1" }
        $raw = & $ocExe auth list 2>&1 | Out-String
        $providers = [ordered]@{}
        # Patrones conocidos
        $known = @(
            @{ id = "opencode";      label = "OpenCode (free tier)";        match = "opencode/" }
            @{ id = "opencode-go";   label = "OpenCode Go (Pro)";           match = "opencode-go/" }
            @{ id = "nvidia";        label = "NVIDIA NIM API";              match = "nvidia/" }
            @{ id = "anthropic";     label = "Anthropic (Claude)";         match = "anthropic/" }
            @{ id = "openai";        label = "OpenAI (Codex/GPT)";          match = "openai" }
            @{ id = "z-ai";          label = "Z.AI Coding Plan";            match = "zai" }
            @{ id = "minimax-coding-plan"; label = "MiniMax Coding Plan";   match = "minimax-?coding" }
            @{ id = "mistral";       label = "Mistral";                    match = "mistral" }
            @{ id = "deepseek";      label = "DeepSeek";                   match = "deepseek" }
            @{ id = "groq";          label = "Groq";                       match = "groq" }
            @{ id = "google";        label = "Google Gemini";               match = "google" }
            @{ id = "openrouter";    label = "OpenRouter";                 match = "openrouter" }
        )
        foreach ($p in $known) {
            if ($raw -match $p.match) {
                $providers[$p.id] = $p.label
            }
        }
        # Si no encontramos nada, devolver defaults
        if ($providers.Count -eq 0) {
            $providers["opencode-go"] = "OpenCode Go (default)"
            $providers["nvidia"] = "NVIDIA NIM API"
        }
        return $providers
    } catch {
        Warn "No pude leer providers de OpenCode: $($_.Exception.Message)"
        return [ordered]@{ "opencode-go" = "OpenCode Go (default)" }
    }
}

# === LISTAR MODELOS DE UN PROVIDER ===
function Get-ProviderModels {
    param([string]$ProviderId)
    try {
        $ocExe = (Get-Command opencode -EA SilentlyContinue).Source
        if (-not $ocExe) { $ocExe = "C:\Users\LapOne Mx\AppData\Roaming\npm\opencode.ps1" }
        $raw = & $ocExe models 2>&1 | Out-String
        $lines = $raw -split "`n"
        $models = @()
        foreach ($line in $lines) {
            $t = $line.Trim()
            if ($t -match "^$ProviderId/") {
                $models += $t
            } elseif ($ProviderId -eq "openai" -and $t -match "^(gpt-|o[0-9]|codex)") {
                $models += "openai/$t"
            }
        }
        return $models
    } catch {
        return @()
    }
}

# === ONBOARDING (TURN 0) - MEJORADO ===
function Run-Onboarding {
    if (Test-Path $ConfigFile) {
        # Ya configurado - mostrar resumen y seguir
        try {
            $c = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            Minor "Config existente: subscription=$($c.subscription | ConvertTo-Json -Compress)"
        } catch {}
        return
    }

    Write-Host ""
    Line "Primera vez detectada. Necesito configurar tu party."
    Write-Host ""

    # --- Paso 1: Provider de IA principal ---
    Header "PASO 1/3: PROVIDER DE IA"
    Line "Que provider quieres usar como principal para Atlas?"
    Write-Host ""
    $providers = Get-OpenCodeProviders
    $provKeys = @($providers.Keys)
    for ($i = 0; $i -lt $provKeys.Count; $i++) {
        $key = $provKeys[$i]
        Write-Host ("  [" + ($i+1) + "] " + $providers[$key] + " (provider: $key)") -ForegroundColor $WHITE
    }
    Write-Host ""
    $provSel = Read-Host "Elige (1-$($provKeys.Count))"
    $idx = [int]$provSel - 1
    if ($idx -lt 0 -or $idx -ge $provKeys.Count) {
        Warn "Seleccion invalida - usando OpenCode Go por defecto"
        $idx = 0
    }
    $chosenProvider = $provKeys[$idx]
    OK "Provider elegido: $chosenProvider ($($providers[$chosenProvider]))"

    # --- Paso 2: Modelo para cada agente del party ---
    Write-Host ""
    Header "PASO 2/3: ASIGNACION DE MODELOS"
    Line "Listando modelos disponibles para $chosenProvider..."
    $availableModels = Get-ProviderModels -ProviderId $chosenProvider
    if ($availableModels.Count -eq 0) {
        Warn "No pude listar modelos. Atlas usara 'auto' y OpenCode elegira."
        $availableModels = @("auto")
    } else {
        Minor "$($availableModels.Count) modelos disponibles"
        # Mostrar primeros 15
        for ($i = 0; $i -lt [Math]::Min(15, $availableModels.Count); $i++) {
            Write-Host ("    " + $availableModels[$i]) -ForegroundColor $DARK
        }
        if ($availableModels.Count -gt 15) {
            Minor "  ... y $($availableModels.Count - 15) mas"
        }
    }
    Write-Host ""

    # Recomendacion pre-cargada si existe model-recommendations.json
    $recoFile = Join-Path $ConfigDir "model-recommendations.json"
    $defaultParty = [ordered]@{}
    # Mapeo de provider_id -> subclave en model-recommendations.json
    $providerToReco = @{
        "opencode-go"           = "opencode"
        "opencode"              = "opencode"
        "nvidia"                 = "opencode"
        "z-ai"                   = "opencode"
        "minimax-coding-plan"    = "opencode"
        "anthropic"              = "claude"
        "openai"                 = "codex"
    }
    $recoKey = if ($providerToReco.ContainsKey($chosenProvider)) { $providerToReco[$chosenProvider] } else { "opencode" }
    if (Test-Path $recoFile) {
        try {
            $reco = Get-Content $recoFile -Raw | ConvertFrom-Json
            if ($reco.platforms.PSObject.Properties.Name -contains $recoKey) {
                $plans = $reco.platforms.$recoKey.recommended_party
                $firstPlan = if ($plans.PSObject.Properties.Name -contains "pro") { "pro" } else { $plans.PSObject.Properties.Name | Select-Object -First 1 }
                if ($firstPlan) {
                    $planObj = $plans.$firstPlan
                    # Convertir PSCustomObject a OrderedDictionary para acceso consistente
                    foreach ($prop in $planObj.PSObject.Properties) {
                        $defaultParty[$prop.Name] = $prop.Value
                    }
                }
            }
        } catch {
            Warn "No pude leer model-recommendations.json: $($_.Exception.Message)"
        }
    }
    # Mapear modelos sugeridos al prefijo del provider elegido
    $providerPrefix = "$chosenProvider/"
    $prefixedParty = [ordered]@{}
    foreach ($k in $defaultParty.Keys) {
        $v = $defaultParty[$k]
        if ($v -ne "auto" -and $v -notmatch "^$chosenProvider/" -and $v -notmatch "^[a-z]+/") {
            $prefixedParty[$k] = "$providerPrefix$v"
        } else {
            $prefixedParty[$k] = $v
        }
    }
    $defaultParty = $prefixedParty

    $agents = @(
        @{ key="atlas";   role="Orquestador (mejor modelo)" }
        @{ key="vivi";    role="Frontend/Mage" }
        @{ key="eiko";    role="Healer/DevOps" }
        @{ key="paladin"; role="Backend/Paladin" }
        @{ key="rogue";   role="QA/Rogue" }
        @{ key="monk";    role="Arquitecto/Monk" }
        @{ key="ranger";  role="Research/Ranger" }
        @{ key="tywin";   role="Verifier" }
        @{ key="auron";   role="Security" }
    )

    $chosenModels = @{}
    foreach ($a in $agents) {
        $defaultModel = "auto"
        if ($defaultParty -is [System.Collections.IDictionary]) {
            if ($defaultParty.Contains($a.key)) { $defaultModel = $defaultParty[$a.key] }
        } else {
            if ($defaultParty.PSObject.Properties.Name -contains $a.key) { $defaultModel = $defaultParty.$($a.key) }
        }
        Write-Host ""
        Write-Host "  $($a.role) ($($a.key))" -ForegroundColor $YELLOW
        Write-Host "  Default sugerido: $defaultModel" -ForegroundColor $DARK
        $sel = Read-Host "  Modelo (Enter=default, 'list' para ver todos, o escribe el ID)"
        if ($sel -eq "list") {
            for ($i = 0; $i -lt $availableModels.Count; $i++) {
                Write-Host ("    [$i] " + $availableModels[$i]) -ForegroundColor $DARK
            }
            $sel2 = Read-Host "  Elige numero o escribe el ID completo"
            if ($sel2 -match "^\d+$") {
                $i = [int]$sel2
                if ($i -ge 0 -and $i -lt $availableModels.Count) {
                    $chosenModels[$a.key] = $availableModels[$i]
                } else {
                    $chosenModels[$a.key] = $defaultModel
                }
            } else {
                $chosenModels[$a.key] = if ($sel2) { $sel2 } else { $defaultModel }
            }
        } elseif ([string]::IsNullOrWhiteSpace($sel)) {
            $chosenModels[$a.key] = $defaultModel
        } else {
            $chosenModels[$a.key] = $sel
        }
        OK "  $($a.key) -> $($chosenModels[$a.key])"
    }

    # --- Paso 3: Preferencia de calidad vs economia ---
    Write-Host ""
    Header "PASO 3/3: PREFERENCIA"
    Line "Prefieres economia de tokens o maxima calidad?"
    Line "  [1] Ahorrar tokens (modelos flash/mini)"
    Line "  [2] Balance (default)"
    Line "  [3] Maxima calidad (modelos pro/ultra)"
    $qSel = Read-Host "Elige (1-3)"
    $qualityMode = switch ($qSel) {
        "1" { "economy" }
        "3" { "premium" }
        default { "balance" }
    }
    OK "Modo: $qualityMode"

    # --- Generar config.json ---
    $config = [ordered]@{
        version = "1.0.0"
        codename = "atlas-harness-rpg"
        configured_at = (Get-Date -Format "o")
        player = [ordered]@{
            name = "Atlas"
            role = "Player / Orchestrator"
            model = $chosenModels["atlas"]
            colors = @("#C8102E","#1A1A1A")
            tagline = "Rojo y Negro como el Atlas de la Liga MX"
        }
        provider = [ordered]@{
            primary = $chosenProvider
            quality_mode = $qualityMode
        }
        models = $chosenModels
        preferences = [ordered]@{
            default_party_size = 4
            auto_loop = $true
            show_tokens = $true
            show_hp_mp = $true
            theme = "atlas-rojo-negro"
            language = "es-MX"
        }
        characters = [ordered]@{}
    }

    # Guardar
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
    $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ConfigFile -Encoding UTF8
    Write-Host ""
    Line "Configuracion guardada en $ConfigFile"
    Line "Listo! Lanzando Atlas..."
    Write-Host ""
}

# === LANZAR OPENCODE CON ATLAS ===
function Launch-OpenCodeAtlas {
    param([string]$Quest)

    $oc = Get-Command opencode -EA SilentlyContinue
    if (-not $oc) {
        $oc = Get-Command "C:\Users\LapOne Mx\AppData\Roaming\npm\opencode.ps1" -EA SilentlyContinue
    }
    if (-not $oc) {
        Warn "opencode no encontrado en PATH. Sigue estos pasos:"
        Line "  - Abre OpenCode manualmente"
        Line "  - Invoca: @atlas-player <tu quest>"
        EvenatanFallback
        return
    }

    $ocExe = $oc.Source

    # Leer config para elegir el modelo de Atlas
    $atlasModel = "auto"
    if (Test-Path $ConfigFile) {
        try {
            $c = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            if ($c.player.model -and $c.player.model -ne "auto") {
                $atlasModel = $c.player.model
            }
        } catch {}
    }

    $projectPath = (Get-Location).Path

    Line "Levantando OpenCode con Atlas como orquestador..."
    if ($atlasModel -ne "auto") {
        Minor "  Modelo Atlas: $atlasModel"
    }
    Write-Host ""

    # opencode --agent atlas-player lanza el agente primary configurado
    # El prompt inicial se pasa como argumento posicional
    $args = @( "--agent", "atlas-player", $projectPath )
    if ($atlasModel -ne "auto") {
        $args = @("-m", $atlasModel) + $args
    }
    if ($Quest -and $Quest -ne "") {
        Write-Host "Abriendo OpenCode con Atlas y quest: $Quest"
        & $ocExe @args $Quest
    } else {
        Write-Host "Abriendo OpenCode con Atlas (sin quest - modo standby)"
        # Con --agent atlas-player, el prompt es el configurado en opencode.json
        # No pasamos --prompt; Atlas lee su spec automáticamente
        & $ocExe @args
    }
}

# === FALLBACK: CLI Evenatan sin IA ===
function EvenatanFallback {
    Write-Host ""
    Header "EVENATAN - Terminal RPG (modo offline)"
    Line "Party: Vivi, Eiko, Ansem, Kuja, Amarant, Eremez"
    Line "Audit: Varys (Tracker), Tywin (Verifier), Sam (Archivist)"
    Line "Especiales: Auron (Security), Bran (Seer), Quina (Banker)"
    Write-Host ""
    Minor "Commands: /party /audit /skills /status /pause /resume /save /quit"
    Write-Host ""
    Write-Host ("="*64) -ForegroundColor $RED
    Write-Host "  MODO OFFLINE - solo info. Sin IA conectada." -ForegroundColor $RED
    Write-Host ("="*64) -ForegroundColor $RED
    Write-Host ""
    while ($true) {
        Write-Host -NoNewline "ATLAS> " -ForegroundColor $RED
        $inp = Read-Host
        if ([string]::IsNullOrWhiteSpace($inp)) { continue }
        switch -Regex ($inp) {
            "^/quit|^/exit" { Line "Cerrando ATLAS."; return }
            "^/party"  { Line "VIVI(Mage) EIKO(Cleric) ANSEM(Paladin) KUJA(Rogue) AMARANT(Monk) EREMEZ(Ranger)" }
            "^/audit"  { Line "VARYS(Tracker) TYWIN(Verifier) SAM(Archivist)" }
            "^/special" { Line "AURON(Warden) BRAN(Seer) QUINA(Banker)" }
            "^/skills" { Line "Vivi: Fireball/Flare/Inferno/Meteor | Eiko: Mend/Esuna/Cura/Mass Heal" }
            "^/status" { Minor "HP: 85/120 MP: 12K/18K  Streak: 10" }
            "^/save"   { Minor "Estado guardado .arnes/save/quest-state.json" }
            "^/pause"  { Line "PAUSE. Escribe /resume." }
            "^/resume" { Line "RESUMED!" }
            default   { Line "[QUEST RECEIVED]" ; Minor "  (Sin IA offline. Abre OpenCode y usa @atlas-player)" }
        }
    }
}

# === VERIFICAR MEMORIA PROPIA (arnes.db, sin servidor externo) ===
function Load-ArnesMemory {
    $mem = (Get-OsmaMemoryCli)
    if (Test-Path $mem) {
        $db = Join-Path $ROOT ".arnes\arnes.db"
        if (Test-Path $db) {
            OK "Memoria propia activa (arnes.db)"
        } else {
            Minor "Memoria propia lista (arnes.db se crea al primer uso)"
        }
    } else {
        Warn "No se encontro OSMA (osma-memory.ps1)"
    }
}

# === MAIN ===
Header "BIENVENIDO A ATLAS HARNESS RPG"
Line "Rojo & Negro, Atlas de la Liga MX"
Write-Host ""

$platform = DetectPlatform
OK ("Plataforma: $platform")

SyncAgents
SyncSkillTrees
Load-ArnesMemory

Run-Onboarding

# Si pasaron args al script, usarlos como quest inicial
$initialQuest = if ($args -and $args.Count -gt 0) { $args -join " " } else { "" }

if ($platform -eq "OpenCode") {
    Launch-OpenCodeAtlas -Quest $initialQuest
} elseif ($platform -eq "Codex") {
    Warn "Codex launch pendiente. Lanza codex manualmente e invoca @atlas-player."
    EvenatanFallback
} elseif ($platform -eq "Claude") {
    Warn "Claude launch pendiente. Lanza claude manualmente e invoca @atlas-player."
    EvenatanFallback
} elseif ($platform -eq "Freebuff") {
    # Freebuff: reutiliza el target probado (despliega AGENTS.md con Atlas + party y abre el CLI)
    & (Join-Path $PSScriptRoot 'argos-target.ps1') -Target freebuff -Quest $initialQuest
} else {
    EvenatanFallback
}