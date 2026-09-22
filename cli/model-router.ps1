# model-router.ps1 - B3 Route models per agent based on role + quest type
# =============================================
# Reads .arnes/config.json (subscription), quest_type, and RECOMMENDS models per agent.
#
# REGLA DE NO-AUTOMATICO (2026-09-12): este script es INFORMATIVO. NUNCA cambia,
# asigna ni aplica ningun modelo. Solo escribe .arnes/model-assignments.json si el
# usuario lo pide explicitamente con -SaveOut (persistencia opt-in); el switch de
# modelo siempre lo hace el usuario (UI, -Model, argos connect-agent, etc).
#
# POLITICA (2026-09-12): multi-modelo. El router RECOMIENDA, no bloquea:
#   - flash   -> deepseek-v4.1-flash / glm-5.3-flash   (tareas repetitivas, volumen alto)
#   - pro     -> gpt-5.6-luna / gpt-5.6-terra          (complejo: multi-archivo, bug de raiz no evidente)
#   - highest -> gpt-6-astra / gpt-5.6-sol             (planeacion, arquitectura, boss)
# Los ids son canonicos (sin prefijo): el prefijo del proveedor (opencode-go/,
# openai-codex/, nvidia/...) se resuelve en runtime segun las conexiones
# activas (agent-model-resolver.ps1 / model-route-status.ps1).
#
# Usage:
#   .\model-router.ps1 -Platform opencode -Tier pro -QuestType frontend -Json
#   .\model-router.ps1 -Platform codex -Tier plus -QuestType boss
#   .\model-router.ps1 -QuestType boss -SaveOut   # persiste la recomendacion (opt-in)

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("opencode","codex","claude")]
    [string]$Platform = "opencode",

    [string]$Tier = "pro",

    [ValidateSet("trivial","feature","frontend","backend","architecture","boss","fix","research","devops")]
    [string]$QuestType = "feature",

    [string]$ArnesDir = "",

    # Opt-in: sin este flag NO se escribe ningun archivo (recomendacion de solo lectura)
    [switch]$SaveOut,

    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not $ArnesDir) {
    $cwd = (Get-Location).Path
    if (Test-Path (Join-Path $cwd ".arnes\config.json")) {
        $ArnesDir = Join-Path $cwd ".arnes"
    } else {
        $ArnesDir = ".arnes"
    }
}

# === Catalogo multi-modelo por tier (recomendacion, no exclusividad) ===
$TIER_MODEL = @{
    flash   = 'deepseek-v4.1-flash'
    pro     = 'gpt-5.6-luna'
    highest = 'gpt-6-astra'
}
$TIER_ALT = @{
    flash   = @('glm-5.3-flash')
    pro     = @('gpt-5.6-terra', 'glm-5.3-flash')
    highest = @('gpt-5.6-sol', 'gpt-5.6-luna')
}

# Tier base por rol: orquestadores/estrategas/seguridad/verificacion razonan mas;
# builders y agentes de volumen van en flash. El tipo de quest sube el piso.
$ROLE_TIER = @{
    atlas    = 'pro'      # orquestador: delega y decide
    vivi     = 'flash'    # frontend: volumen alto
    ansem    = 'flash'    # backend: volumen alto
    kuja     = 'pro'      # QA: edge cases, razonamiento
    eiko     = 'flash'    # devops: velocidad
    amarant  = 'highest'  # arquitectura: maximo razonamiento, bajo volumen
    eremez   = 'flash'    # research: rapido, cita fuentes
    auron    = 'pro'      # seguridad: L0, OWASP
    bran     = 'flash'    # analista: metricas
    quina    = 'flash'    # tokens: barato siempre
    varys    = 'flash'    # tracker: observacion
    tywin    = 'pro'      # verificador: PASS/FAIL con criterio
    sam      = 'pro'      # consejero: memoria historica
    bard     = 'flash'    # mejora continua
    tidus    = 'flash'    # infra: barato
    ragnarok = 'pro'      # compras/investigacion de skills
}

# Boost por tipo de quest: planeacion/boss exigen tier alto en todo el party.
$questBoost = switch ($QuestType) {
    'boss'         { 2 }
    'architecture' { 1 }
    default        { 0 }
}

$tierRank  = @{ flash = 0; pro = 1; highest = 2 }
$rankOrder = @('flash', 'pro', 'highest')

$assignments = [ordered]@{}
foreach ($role in ($ROLE_TIER.Keys | Sort-Object)) {
    $rank = [Math]::Min($tierRank[$ROLE_TIER[$role]] + $questBoost, 2)
    $assignments[$role] = $TIER_MODEL[$rankOrder[$rank]]
}

# === Build result ===
$result = @{
    platform = $Platform
    tier = $Tier
    quest_type = $QuestType
    policy = "multi-model (2026-09-12): recomendacion por rol + tipo de quest; sin modelo exclusivo"
    assignments = $assignments
    alternatives = $TIER_ALT
    timestamp = (Get-Date).ToString("o")
}

# === Persist SOLO con -SaveOut (opt-in): el modelo siempre lo elige el usuario ===
if ($SaveOut) {
    if (-not (Test-Path $ArnesDir)) {
        New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null
    }
    $outFile = Join-Path $ArnesDir "model-assignments.json"
    $result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $outFile -Encoding UTF8
}

if ($Json) {
    $result | ConvertTo-Json -Depth 4
    exit 0
}

Write-Host ""
Write-Host "  MODEL ROUTER" -ForegroundColor Cyan
Write-Host "  ============" -ForegroundColor Cyan
Write-Host "  Platform:   $Platform" -ForegroundColor White
Write-Host "  Tier:       $Tier" -ForegroundColor White
Write-Host "  Quest type: $QuestType (boost +$questBoost)" -ForegroundColor White
Write-Host "  Policy:     multi-model: flash=deepseek-v4.1-flash/glm-5.3-flash | pro=gpt-5.6-luna/terra | highest=gpt-6-astra/sol" -ForegroundColor Green
Write-Host ""
foreach ($a in @($assignments.Keys | Sort-Object)) {
    Write-Host ("  {0,-10} -> {1}" -f $a, $assignments[$a]) -ForegroundColor Yellow
}
Write-Host ""
if ($SaveOut) {
    Write-Host "  Saved to: $outFile" -ForegroundColor DarkGray
} else {
    Write-Host "  (recomendacion informativa: no se escribe ningun archivo; usa -SaveOut para persistir)" -ForegroundColor DarkGray
}
Write-Host ""
