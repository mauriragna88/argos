# model-router.ps1 - B3 Route models per agent based on subscription + quest type
# =============================================
# Reads .arnes/config.json (subscription), quest_type, and assigns models per agent.
# Writes result to .arnes/model-assignments.json.
#
# POLITICA DEL USUARIO (2026-08-16): TODOS los agentes usan exclusivamente
# opencode-go/deepseek-v4-flash. Prohibido GPT, Claude, GLM, MiniMax, Qwen,
# Kimi, MiMo y cualquier otro modelo. Sin fallbacks ni promociones.
#
# Usage:
#   .\model-router.ps1 -Platform opencode -Tier pro -QuestType frontend -Json
#   .\model-router.ps1 -Platform codex -Tier plus -QuestType boss

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("opencode","codex","claude")]
    [string]$Platform = "opencode",

    [string]$Tier = "pro",

    [ValidateSet("trivial","feature","frontend","backend","architecture","boss","fix","research","devops")]
    [string]$QuestType = "feature",

    [string]$ArnesDir = "",

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

# === Politica del usuario: un solo modelo para todos ===
$ONLY_MODEL = "deepseek-v4-flash"

$routes = @{
    "opencode" = @{
        "free" = @{
            "atlas"=$ONLY_MODEL; "vivi"=$ONLY_MODEL; "eiko"=$ONLY_MODEL
            "ansem"=$ONLY_MODEL; "kuja"=$ONLY_MODEL; "amarant"=$ONLY_MODEL
            "eremez"=$ONLY_MODEL; "auron"=$ONLY_MODEL
            "bran"=$ONLY_MODEL; "quina"=$ONLY_MODEL; "varys"=$ONLY_MODEL
            "tywin"=$ONLY_MODEL; "sam"=$ONLY_MODEL
        }
        "pro" = @{
            "atlas"=$ONLY_MODEL; "vivi"=$ONLY_MODEL; "eiko"=$ONLY_MODEL
            "ansem"=$ONLY_MODEL; "kuja"=$ONLY_MODEL; "amarant"=$ONLY_MODEL
            "eremez"=$ONLY_MODEL; "auron"=$ONLY_MODEL
            "bran"=$ONLY_MODEL; "quina"=$ONLY_MODEL; "varys"=$ONLY_MODEL
            "tywin"=$ONLY_MODEL; "sam"=$ONLY_MODEL
        }
    }
    "codex" = @{
        "free" = @{
            "atlas"=$ONLY_MODEL; "vivi"=$ONLY_MODEL; "eiko"=$ONLY_MODEL
            "ansem"=$ONLY_MODEL; "kuja"=$ONLY_MODEL; "amarant"=$ONLY_MODEL
            "eremez"=$ONLY_MODEL; "auron"=$ONLY_MODEL
            "bran"=$ONLY_MODEL; "quina"=$ONLY_MODEL; "varys"=$ONLY_MODEL
            "tywin"=$ONLY_MODEL; "sam"=$ONLY_MODEL
        }
        "plus" = @{
            "atlas"=$ONLY_MODEL; "vivi"=$ONLY_MODEL; "eiko"=$ONLY_MODEL
            "ansem"=$ONLY_MODEL; "kuja"=$ONLY_MODEL; "amarant"=$ONLY_MODEL
            "eremez"=$ONLY_MODEL; "auron"=$ONLY_MODEL
            "bran"=$ONLY_MODEL; "quina"=$ONLY_MODEL; "varys"=$ONLY_MODEL
            "tywin"=$ONLY_MODEL; "sam"=$ONLY_MODEL
        }
        "pro" = @{
            "atlas"=$ONLY_MODEL; "vivi"=$ONLY_MODEL; "eiko"=$ONLY_MODEL
            "ansem"=$ONLY_MODEL; "kuja"=$ONLY_MODEL; "amarant"=$ONLY_MODEL
            "eremez"=$ONLY_MODEL; "auron"=$ONLY_MODEL
            "bran"=$ONLY_MODEL; "quina"=$ONLY_MODEL; "varys"=$ONLY_MODEL
            "tywin"=$ONLY_MODEL; "sam"=$ONLY_MODEL
        }
    }
    "claude" = @{
        "free" = @{
            "atlas"=$ONLY_MODEL; "vivi"=$ONLY_MODEL; "eiko"=$ONLY_MODEL
            "ansem"=$ONLY_MODEL; "kuja"=$ONLY_MODEL; "amarant"=$ONLY_MODEL
            "eremez"=$ONLY_MODEL; "auron"=$ONLY_MODEL
            "bran"=$ONLY_MODEL; "quina"=$ONLY_MODEL; "varys"=$ONLY_MODEL
            "tywin"=$ONLY_MODEL; "sam"=$ONLY_MODEL
        }
        "pro" = @{
            "atlas"=$ONLY_MODEL; "vivi"=$ONLY_MODEL; "eiko"=$ONLY_MODEL
            "ansem"=$ONLY_MODEL; "kuja"=$ONLY_MODEL; "amarant"=$ONLY_MODEL
            "eremez"=$ONLY_MODEL; "auron"=$ONLY_MODEL
            "bran"=$ONLY_MODEL; "quina"=$ONLY_MODEL; "varys"=$ONLY_MODEL
            "tywin"=$ONLY_MODEL; "sam"=$ONLY_MODEL
        }
        "max" = @{
            "atlas"=$ONLY_MODEL; "vivi"=$ONLY_MODEL; "eiko"=$ONLY_MODEL
            "ansem"=$ONLY_MODEL; "kuja"=$ONLY_MODEL; "amarant"=$ONLY_MODEL
            "eremez"=$ONLY_MODEL; "auron"=$ONLY_MODEL
            "bran"=$ONLY_MODEL; "quina"=$ONLY_MODEL; "varys"=$ONLY_MODEL
            "tywin"=$ONLY_MODEL; "sam"=$ONLY_MODEL
        }
    }
}

if (-not $routes.ContainsKey($Platform)) {
    Write-Error "Unknown platform: $Platform"
    exit 1
}
if (-not $routes[$Platform].ContainsKey($Tier)) {
    Write-Error "Unknown tier '$Tier' for platform $Platform"
    exit 1
}

$assignments = @{}
foreach ($k in $routes[$Platform][$Tier].Keys) {
    $assignments[$k] = $routes[$Platform][$Tier][$k]
}

# === Quest type overrides ===
# Politica del usuario: NO hay overrides de modelo. Todo queda en deepseek-v4-flash.
$overrides = @{
    "boss" = @()
    "frontend" = @()
    "backend" = @()
    "trivial" = @()
}

# === Build result ===
$result = @{
    platform = $Platform
    tier = $Tier
    quest_type = $QuestType
    policy = "deepseek-only (2026-08-16): todos los agentes usan opencode-go/deepseek-v4-flash"
    assignments = $assignments
    timestamp = (Get-Date).ToString("o")
}

# === Persist to .arnes/model-assignments.json ===
if (-not (Test-Path $ArnesDir)) {
    New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null
}
$outFile = Join-Path $ArnesDir "model-assignments.json"
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $outFile -Encoding UTF8

if ($Json) {
    $result | ConvertTo-Json -Depth 4
    exit 0
}

Write-Host ""
Write-Host "  MODEL ROUTER" -ForegroundColor Cyan
Write-Host "  ============" -ForegroundColor Cyan
Write-Host "  Platform:   $Platform" -ForegroundColor White
Write-Host "  Tier:       $Tier" -ForegroundColor White
Write-Host "  Quest type: $QuestType" -ForegroundColor White
Write-Host "  Policy:     deepseek-only (deepseek-v4-flash para todos)" -ForegroundColor Green
Write-Host ""
foreach ($a in @($assignments.Keys | Sort-Object)) {
    Write-Host ("  {0,-10} -> {1}" -f $a, $assignments[$a]) -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Saved to: $outFile" -ForegroundColor DarkGray
Write-Host ""
