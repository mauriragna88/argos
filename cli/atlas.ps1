# arnes activate - CLI Final Atlas Harness RPG
# =============================================
# Uso: atlas (desde cualquier carpeta). El antiguo entry point .\cli\activate.ps1 vive en legacy/
# Detecta plataforma, sync agentes a OpenCode, lanza OpenCode con Atlas como primary
# 12 agentes: Atlas + 6 party + 3 auditores + 3 pending

#Requires -Version 5.1
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'osma-resolve.ps1')

$ROOT = Resolve-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$ConfigDir = Join-Path $ROOT ".arnes"
$ConfigFile = Join-Path $ConfigDir "config.json"
$AtlasPromptFile = Join-Path $ROOT "core\atlas-player.agent.md"

# Detectar shell disponible: pwsh (PS7+) si esta instalado, sino powershell (PS 5.1)
$AtlasShell = & {
    $c = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($c) { $c.Source } else { 'powershell' }
}

# === Parsear CLI flags (--lean, --full-party, --boss-party, --auto) ===
# Los flags controlan el tier de party que Bran recomienda. Se persisten en .arnes/config.json.
$partyOverride = $null      # lean | medium | standard | boss | full | null (=auto)
$filteredArgs = @()
foreach ($a in $args) {
    switch -Regex ($a) {
        '^--lean$'         { $partyOverride = 'lean' }
        '^--medium$'       { $partyOverride = 'medium' }
        '^--standard$'     { $partyOverride = 'standard' }
        '^--boss$|--boss-party$' { $partyOverride = 'boss' }
        '^--full-party$'   { $partyOverride = 'full' }
        '^--auto$'         { $partyOverride = $null }
        '^--sync$'         { $syncOnly = $true }
        default            { $filteredArgs += $a }
    }
}
# Reasignar $args sin los flags (para que el quest inicial no incluya los flags)
$args = $filteredArgs

# Aplicar override a .arnes/config.json si existe (lo lee Bran al cargar)
if ($partyOverride -and (Test-Path $ConfigFile)) {
    try {
        $cfg = Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json
        if (-not $cfg.PSObject.Properties['repo_root']) {
            $cfg | Add-Member -NotePropertyName repo_root -NoteValueType NoteProperty -Value ([PSCustomObject]@{
                override_tier = $null
                override_party_size = $null
                override_model_tier = $null
            })
        }
        $cfg.repo_root.override_tier           = if ($partyOverride -in @('lean','medium','standard','boss')) { $partyOverride } else { $null }
        $cfg.repo_root.override_party_size     = if ($partyOverride -eq 'full') { 6 } elseif ($partyOverride -eq 'lean') { 2 } elseif ($partyOverride -eq 'boss') { 6 } else { $null }
        $cfg.repo_root.override_model_tier     = if ($partyOverride -eq 'lean') { 'free' } elseif ($partyOverride -eq 'boss') { 'highest' } elseif ($partyOverride -eq 'full') { 'pro' } else { $null }
        $cfg | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ConfigFile -Encoding UTF8
    } catch {
        Write-Host "  [!] No se pudo aplicar override a config.json: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

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
    # Mapear los archivos que REALMENTE existen en core/ y core/classes/
    $agents = @{}
    if (Test-Path (Join-Path $ROOT "core\atlas-player.agent.md")) {
        $agents["atlas-player"] = "core\atlas-player.agent.md"
    }
    # Mapeo de agente -> archivos posibles (busca el primero que exista)
    $candidateMap = @{
        "vivi"    = @("core\classes\mage.agent.md", "core\classes\vivi.agent.md")
        "eiko"    = @("core\classes\eiko.agent.md")
        "ansem"   = @("core\classes\paladin.agent.md")
        "kuja"    = @("core\classes\rogue.agent.md")
        "amarant" = @("core\classes\monk.agent.md")
        "eremez"  = @("core\classes\ranger.agent.md")
        "bard"    = @("core\classes\bard.agent.md")
        "tidus"   = @("core\classes\tidus.agent.md")
        "ragnarok" = @("core\classes\ragnarok.agent.md")
    }
    foreach ($k in $candidateMap.Keys) {
        foreach ($cand in $candidateMap[$k]) {
            if (Test-Path (Join-Path $ROOT $cand)) {
                $agents[$k] = $cand
                break
            }
        }
    }
    # Auditores opcionales
    $auditors = @("varys", "tywin", "sam", "auron", "bran", "quina")
    foreach ($a in $auditors) {
        $cand = "core\auditors\$a.agent.md"
        if (Test-Path (Join-Path $ROOT $cand)) {
            $agents[$a] = $cand
        }
    }
    $count = 0
    foreach ($k in $agents.Keys) {
        $s = Join-Path $ROOT $agents[$k]
        Copy-Item $s -Destination (Join-Path $t "$k.md") -Force
        $count++
    }
    OK "$count agentes sincronizados a $t"
    # Re-aplicar modelos configurados (agent-models.json GLOBAL o local) para no perder el frontmatter
    $modelsFile = Join-Path (Get-Location) '.arnes\agent-models.json'
    if (-not (Test-Path $modelsFile)) { $modelsFile = Join-Path $ROOT '.arnes\agent-models.json' }
    if (-not (Test-Path $modelsFile)) { $modelsFile = Join-Path $env:USERPROFILE '.config\arnes\agent-models.json' }
    if (Test-Path $modelsFile) {
        & (Join-Path $PSScriptRoot 'argos-models-apply.ps1') -ModelsPath $modelsFile -SkipBackup
    }
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
    Line "Primera vez en esta carpeta project. Te ayudo a configurar Atlas en 2 pasos rapidos."
    Write-Host ""

    # --- Paso 1: Provider de IA ---
    Header "PASO 1/2: PROVIDER DE IA"
    Minor "Atlas usara este provider para todos los agentes del party."
    Write-Host ""
    $providers = Get-OpenCodeProviders
    $provKeys = @($providers.Keys)
    for ($i = 0; $i -lt $provKeys.Count; $i++) {
        $key = $provKeys[$i]
        Write-Host ("  [" + ($i+1) + "] " + $providers[$key]) -ForegroundColor $WHITE
    }
    Write-Host ""
    $provSel = Read-Host "Elige (1-$($provKeys.Count) or Enter=1)"
    $idx = if (-not $provSel) { 0 } else { [int]$provSel - 1 }
    if ($idx -lt 0 -or $idx -ge $provKeys.Count) { $idx = 0; Warn "Seleccion invalida - usando opcion 1" }
    $chosenProvider = $provKeys[$idx]
    OK "$($providers[$chosenProvider])"


    # --- Paso 2: Modo (principiante o avanzado) ---
    Write-Host ""
    Header "PASO 2/2: MODO DE USO"
    Minor "Atlas puede configurar los modelos automaticamente (ideal para empezar ya) o puedes elegirlos uno por uno."
    Write-Host ""
    Write-Host "  [1] Modo principiante (autoconfiguracion, ideal para empezar YA)"
    Write-Host "  [2] Modo avanzado (tu elijes cada modelo, conocer la oferta)"
    Write-Host "  [3] Salir, yo despues"
    Write-Host ""
    $modeSel = Read-Host "Elige (1-3, default=1)"
    if ($modeSel -eq "3") {
        write-host ""
        Write-Host "  Adios. Cuando quieras, vuelve con 'atlas' para configurar." -ForegroundColor DarkGray
        exit 0
    }
    $isAdvanced = ($modeSel -eq "2")


    # === Pre-cargar recomendacion Base ===
    $recoFile = Join-Path $ConfigDir "model-recommendations.json"
    $defaultParty = [ordered]@{
        atlas   = "auto"
        vivi    = "auto"
        eiko    = "auto"
        paladin = "auto"
        rogue   = "auto"
        monk    = "auto"
        ranger  = "auto"
        tywin   = "auto"
        auron   = "auto"
    }
    $providerToReco = @{
        "opencode-go"           = "opencode"
        "opencode"              = "opencode"
        "nvidia"                = "opencode"
        "z-ai"                  = "opencode"
        "minimax-coding-plan"   = "opencode"
        "anthropic"             = "claude"
        "openai"                = "codex"
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
                    foreach ($prop in $planObj.PSObject.Properties) {
                        $defaultParty[$prop.Name] = $prop.Value
                    }
                }
            }
        } catch { Warn "No pude leer model-recommendations.json: $($_.Exception.Message)" }
    }
    $providerPrefix = "$chosenProvider/"
    foreach ($k in $defaultParty.Keys) {
        $v = $defaultParty[$k]
        if ($v -ne "auto" -and $v -notmatch "^$chosenProvider/" -and $v -notmatch "^[a-z]+/") {
            $defaultParty[$k] = "$providerPrefix$v"
        }
    }


    $chosenModels = @{}
    $qualityMode = "balance"

    # === Si beginner: auto-asignar todo, saltar la config por modelo
    if (-not $isAdvanced) {
        Write-Host ""
        Write-Host "  Modo principiante elegido. Configurando automaticamente:" -ForegroundColor Cyan
        $qualityMode = "balance"
        foreach ($k in $defaultParty.Keys) {
            $chosenModels[$k] = $defaultParty[$k]  # todos "auto" excepto los pre-cargados
            Minor "  $k -> autoconfig"
        }
        OK "Configuracion automatica completa."
    }

    # === Si ES avanzado: igual que antes, pero omitimos listar modelos masivos
    if ($isAdvanced) {
        $availableModels = Get-ProviderModels -ProviderId $chosenProvider
        if ($availableModels.Count -eq 0) { $availableModels = @("auto") }
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
        foreach ($a in $agents) {
            $df = $defaultParty[$a.key]
            Write-Host ""
            Write-Host "  $($a.role) ($($a.key))" -ForegroundColor $YELLOW
            Minor "  default: $df"
            $sel = Read-Host "  Modelo (Enter=default, 'list' para ver, o escribe)"
            if ($sel -eq "list") {
                for ($i = 0; $i -lt [Math]::Min(10, $availableModels.Count); $i++) {
                    Write-Host ("      " + $availableModels[$i]) -ForegroundColor DarkGray
                }
                Write-Host "      ... busca modelos con 'opencode models'" -ForegroundColor DarkGray
                $sel = Read-Host "  escribe modelo o Enter para default"
            }
            $chosenModels[$a.key] = if ($sel) { $sel } else { $df }
        }
        Write-Host ""
        Header "PASO 3/3: CALIDAD VS ECONOMIA"
        Line " [1] Ahorrar tokens (modelos flash/mini)"
        Line " [2] Balance (default)"
        Line " [3] Maxima calidad (modelos pro/ultra)"
        $qSel = Read-Host "Elige (1-3)"
        $qualityMode = switch ($qSel) {
            "1" { "economy" }
            "3" { "premium" }
            default { "balance" }
        }
        OK "Modo: $qualityMode"
    }

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

    # Inicializar entorno Atlas en el proyecto actual (idempotente)
    $initScript = Join-Path $ROOT "cli\atlas-init.ps1"
    if (Test-Path $initScript) {
        Minor "  Ejecutando atlas-init.ps1 para sincronizar entorno..."
        & $AtlasShell -NoProfile -File $initScript 2>&1 | ForEach-Object { Write-Host "      $_" }
        Write-Host ""
    }

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

# === LANZAR CODEX CON ATLAS ===
function Launch-CodexAtlas {
    param([string]$Quest)

    $cx = Get-Command codex -EA SilentlyContinue
    if (-not $cx) {
        Warn "codex no encontrado en PATH."
        Line "  - Abre Codex manualmente e invoca: @atlas-player <tu quest>"
        EvenatanFallback
        return
    }

    $cxExe = $cx.Source
    $projectPath = (Get-Location).Path

    # Verificar que el spec de Atlas existe
    if (-not (Test-Path $AtlasPromptFile)) {
        Warn "No encontre el spec de Atlas en: $AtlasPromptFile"
        EvenatanFallback
        return
    }

    # Inicializar entorno Atlas en el proyecto actual (idempotente)
    $initScript = Join-Path $ROOT "cli\atlas-init.ps1"
    if (Test-Path $initScript) {
        Minor "  Ejecutando atlas-init.ps1 para sincronizar entorno..."
        & $AtlasShell -NoProfile -File $initScript 2>&1 | ForEach-Object { Write-Host "      $_" }
        Write-Host ""
    }

    Line "Levantando Codex con Atlas como orquestador..."
    Minor "  Spec: $AtlasPromptFile"
    Write-Host ""

    # Codex CLI acepta -c key=value para overrides runtime.
    # Usamos model_instructions_file (mecanismo nativo de Codex) SIN editar ~/.codex/config.toml.
    # Esto solo aplica durante esta sesion.
    $specPathEscaped = $AtlasPromptFile.Replace('\', '\\')
    $codexArgs = @(
        $projectPath,
        "-c", "model_instructions_file=`"$specPathEscaped`""
    )
    if ($Quest -and $Quest -ne "") {
        Write-Host "Abriendo Codex con Atlas y quest: $Quest"
        & $cxExe @codexArgs $Quest
    } else {
        Write-Host "Abriendo Codex con Atlas (sin quest - modo standby)"
        & $cxExe @codexArgs
    }
}

# === LANZAR CLAUDE CON ATLAS ===
function Launch-ClaudeAtlas {
    param([string]$Quest)

    $cl = Get-Command claude -EA SilentlyContinue
    if (-not $cl) {
        Warn "claude no encontrado en PATH."
        Line "  - Abre Claude Code manualmente e invoca: @atlas-player <tu quest>"
        EvenatanFallback
        return
    }

    $clExe = $cl.Source
    $projectPath = (Get-Location).Path

    # Inicializar entorno Atlas en el proyecto actual (idempotente)
    $initScript = Join-Path $ROOT "cli\atlas-init.ps1"
    if (Test-Path $initScript) {
        Minor "  Ejecutando atlas-init.ps1 para sincronizar entorno..."
        & $AtlasShell -NoProfile -File $initScript 2>&1 | ForEach-Object { Write-Host "      $_" }
        Write-Host ""
    }

    # Claude soporta --agent flag y --append-system-prompt
    Line "Levantando Claude con Atlas como orquestador..."
    Write-Host ""

    $claudeArgs = @("--agent", "atlas-player", "--add-dir", $projectPath)
    if ($Quest -and $Quest -ne "") {
        Write-Host "Abriendo Claude con Atlas y quest: $Quest"
        & $clExe @claudeArgs $Quest
    } else {
        Write-Host "Abriendo Claude con Atlas (sin quest - modo standby)"
        & $clExe @claudeArgs
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
        Minor "Commands: /party /audit /audit-docs /skills /status /pause /resume /save /quit"
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
            "^/audit-docs" {
                Line "VARYS-DOC: Mis pajaritos estan volando sobre el repo..."
                Minor "  Triggering Varys Documentalist audit..."
                $varysDocAgent = Join-Path $ROOT "core\auditors\varys-documentalist.agent.md"
                if (Test-Path $varysDocAgent) {
                    Minor "  (Offline mode - no real scan. Para audit real:)"
                    Minor "    abre OpenCode y usa @varys-documentalist"
                    Minor "    o corre: pwsh -File cli\smoke-test.ps1 -Json"
                } else {
                    Warn "  varys-documentalist.agent.md no encontrado en $varysDocAgent"
                }
            }
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
# Modo sync-only (headless, para instaladores): sincroniza agentes y sale
if ($syncOnly) {
    SyncAgents
    SyncSkillTrees
    Load-ArnesMemory
    exit 0
}

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
    Launch-CodexAtlas -Quest $initialQuest
} elseif ($platform -eq "Claude") {
    Launch-ClaudeAtlas -Quest $initialQuest
} elseif ($platform -eq "Freebuff") {
    # Freebuff: reutiliza el target probado (despliega AGENTS.md con Atlas + party y abre el CLI)
    & (Join-Path $PSScriptRoot 'argos-target.ps1') -Target freebuff -Quest $initialQuest
} else {
    EvenatanFallback
}