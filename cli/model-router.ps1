# model-router.ps1 - B3 Route models per agent based on subscription + quest type
# =============================================
# Reads .arnes/config.json (subscription), quest_type, and assigns models per agent.
# Writes result to .arnes/model-assignments.json.
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

# === Base routing tables (from core/model-router.agent.md) ===
$routes = @{
    "opencode" = @{
        "free" = @{
            "atlas"="deepseek-v4-flash"; "vivi"="qwen-3.6-plus"; "eiko"="qwen-3.6-plus"
            "ansem"="deepseek-v4-flash"; "kuja"="glm-5.2"; "amarant"="deepseek-v4-flash"
            "eremez"="deepseek-v4-flash"; "auron"="deepseek-v4-flash"
            "bran"="deepseek-v4-flash"; "quina"="glm-5.2"; "varys"="qwen-3.6-plus"
            "tywin"="deepseek-v4-flash"; "sam"="deepseek-v4-flash"
        }
        "pro" = @{
            "atlas"="mimo-v2.5-pro"; "vivi"="mimo-v2.5-pro"; "eiko"="qwen-3.6-plus"
            "ansem"="deepseek-v4-pro"; "kuja"="glm-5.2"; "amarant"="kimi-k2.6"
            "eremez"="deepseek-v4-flash"; "auron"="deepseek-v4-pro"
            "bran"="kimi-k2.6"; "quina"="glm-5.2"; "varys"="qwen-3.6-plus"
            "tywin"="deepseek-v4-pro"; "sam"="kimi-k2.6"
        }
    }
    "codex" = @{
        "free" = @{
            "atlas"="gpt-5.4"; "vivi"="gpt-5.4"; "eiko"="gpt-5.4-mini"
            "ansem"="gpt-5.4"; "kuja"="gpt-5.4-mini"; "amarant"="gpt-5.4"
            "eremez"="gpt-5.4-mini"; "auron"="gpt-5.4"
            "bran"="gpt-5.4"; "quina"="gpt-5.4-mini"; "varys"="gpt-5.4-mini"
            "tywin"="gpt-5.4"; "sam"="gpt-5.4"
        }
        "plus" = @{
            "atlas"="gpt-5.6-terra"; "vivi"="gpt-5.6-luna"; "eiko"="gpt-5.5"
            "ansem"="gpt-5.6-terra"; "kuja"="gpt-5.6-luna"; "amarant"="gpt-5.6-terra"
            "eremez"="gpt-5.5"; "auron"="gpt-5.6-terra"
            "bran"="gpt-5.6-terra"; "quina"="gpt-5.5"; "varys"="gpt-5.5"
            "tywin"="gpt-5.6-terra"; "sam"="gpt-5.6-terra"
        }
        "pro" = @{
            "atlas"="gpt-5.6-sol"; "vivi"="gpt-5.6-luna"; "eiko"="gpt-5.6-terra"
            "ansem"="gpt-5.6-sol"; "kuja"="gpt-5.6-sol"; "amarant"="gpt-5.6-sol"
            "eremez"="gpt-5.6-terra"; "auron"="gpt-5.6-sol"
            "bran"="gpt-5.6-sol"; "quina"="gpt-5.6-terra"; "varys"="gpt-5.6-terra"
            "tywin"="gpt-5.6-sol"; "sam"="gpt-5.6-sol"
        }
    }
    "claude" = @{
        "free" = @{
            "atlas"="claude-sonnet-4.5"; "vivi"="claude-sonnet-4.5"; "eiko"="claude-haiku-4.5"
            "ansem"="claude-sonnet-4.5"; "kuja"="claude-haiku-4.5"; "amarant"="claude-sonnet-4.5"
            "eremez"="claude-haiku-4.5"; "auron"="claude-sonnet-4.5"
            "bran"="claude-sonnet-4.5"; "quina"="claude-haiku-4.5"; "varys"="claude-haiku-4.5"
            "tywin"="claude-sonnet-4.5"; "sam"="claude-sonnet-4.5"
        }
        "pro" = @{
            "atlas"="claude-opus-4.8"; "vivi"="claude-opus-4.8"; "eiko"="claude-sonnet-5"
            "ansem"="claude-sonnet-5"; "kuja"="claude-sonnet-5"; "amarant"="claude-opus-4.8"
            "eremez"="claude-sonnet-5"; "auron"="claude-opus-4.8"
            "bran"="claude-opus-4.8"; "quina"="claude-sonnet-5"; "varys"="claude-sonnet-5"
            "tywin"="claude-opus-4.8"; "sam"="claude-opus-4.8"
        }
        "max" = @{
            "atlas"="claude-opus-5"; "vivi"="claude-opus-5"; "eiko"="claude-sonnet-5"
            "ansem"="claude-opus-4.8"; "kuja"="claude-opus-5"; "amarant"="claude-opus-5"
            "eremez"="claude-sonnet-5"; "auron"="claude-opus-5"
            "bran"="claude-opus-5"; "quina"="claude-sonnet-5"; "varys"="claude-sonnet-5"
            "tywin"="claude-opus-5"; "sam"="claude-opus-5"
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
$overrides = @{
    "boss" = @("atlas","amarant","tywin","sam","auron")
    "frontend" = @("vivi","eiko")
    "backend" = @("ansem","auron")
    "trivial" = @()
}

# For boss, promote key agents to highest available
if ($QuestType -eq "boss") {
    $highest = @{
        "opencode" = "kimi-k2.6"
        "codex" = "gpt-5.6-sol"
        "claude" = "claude-opus-5"
    }
    foreach ($a in $overrides["boss"]) {
        if ($assignments.ContainsKey($a)) {
            $assignments[$a] = $highest[$Platform]
        }
    }
}

# For trivial, prefer cheap models
if ($QuestType -eq "trivial") {
    $cheapest = @{
        "opencode" = "deepseek-v4-flash"
        "codex" = "gpt-5.4-mini"
        "claude" = "claude-haiku-4.5"
    }
    foreach ($k in @($assignments.Keys)) {
        $assignments[$k] = $cheapest[$Platform]
    }
}

# === Build result ===
$result = @{
    platform = $Platform
    tier = $Tier
    quest_type = $QuestType
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
Write-Host ""
foreach ($a in @($assignments.Keys | Sort-Object)) {
    Write-Host ("  {0,-10} -> {1}" -f $a, $assignments[$a]) -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Saved to: $outFile" -ForegroundColor DarkGray
Write-Host ""
