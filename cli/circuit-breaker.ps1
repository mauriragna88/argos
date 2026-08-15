# circuit-breaker.ps1 - Agent failure tracking and auto-blocking
# B1 - Implements the circuit breaker pattern for Atlas Harness.
# Config: 3 fails in 60 min -> block 30 min.
# Persistent state in .arnes/circuit-breaker.json.

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("record-fail","record-pass","check","reset","status","purge")]
    [string]$Action = "status",

    [string]$Agent = "",

    [string]$ArnesDir = "",

    [int]$Threshold = 3,

    [int]$WindowMinutes = 60,

    [int]$CooldownMinutes = 30
)

$ErrorActionPreference = "Continue"
. (Join-Path $PSScriptRoot 'osma-resolve.ps1')

# === Resolver ArnesDir ===
if (-not $ArnesDir) {
    $cwd = (Get-Location).Path
    if (Test-Path (Join-Path $cwd ".arnes\config.json")) {
        $ArnesDir = Join-Path $cwd ".arnes"
    } else {
        $ArnesDir = ".arnes"
    }
}

$StateFile = Join-Path $ArnesDir "circuit-breaker.json"

# Get/Create state as hashtable (works in PS 5.1)
function Get-State {
    if (Test-Path $StateFile) {
        try {
            $raw = Get-Content -LiteralPath $StateFile -Raw -Encoding UTF8
            $h = $raw | ConvertFrom-Json
            # Convert to hashtable for safety
            $state = @{}
            $state["version"] = $h.version
            $state["threshold"] = [int]$h.threshold
            $state["window_minutes"] = [int]$h.window_minutes
            $state["cooldown_minutes"] = [int]$h.cooldown_minutes
            $agentsHt = @{}
            if ($h.agents) {
                foreach ($p in $h.agents.PSObject.Properties) {
                    $name = $p.Name
                    if ($name -in @('Count','Keys','Values','IsReadOnly','IsFixedSize','SyncRoot','IsSynchronized')) { continue }
                    $v = $p.Value
                    $agentsHt[$name] = @{
                        fails = @($v.fails)
                        fail_count = [int]$v.fail_count
                        blocked_until = $v.blocked_until
                        status = $v.status
                        first_seen = $v.first_seen
                    }
                }
            }
            $state["agents"] = $agentsHt
            return $state
        } catch {
            # corrupt file, fresh state
        }
    }
    return @{
        version = "1.0.0"
        threshold = $Threshold
        window_minutes = $WindowMinutes
        cooldown_minutes = $CooldownMinutes
        agents = @{}
    }
}

function Save-State($state) {
    if (-not (Test-Path $ArnesDir)) {
        New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null
    }
    $state | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StateFile -Encoding UTF8
}

function Purge-Expired($state) {
    $now = Get-Date
    foreach ($agentName in @($state.agents.Keys)) {
        $entry = $state.agents[$agentName]
        if ($entry.blocked_until) {
            try {
                $blockedUntil = [DateTime]::Parse($entry.blocked_until)
                if ($now -gt $blockedUntil) {
                    $entry.blocked_until = $null
                    $entry.status = "active"
                    $entry.fail_count = 0
                }
            } catch {}
        }
        if ($entry.fails) {
            $windowStart = $now - [TimeSpan]::FromMinutes($state.window_minutes)
            $recent = @()
            foreach ($f in $entry.fails) {
                if ($f -and $f.timestamp) {
                    try {
                        $ts = [DateTime]::Parse($f.timestamp)
                        if ($ts -gt $windowStart) {
                            $recent += @{ timestamp = $f.timestamp; reason = $f.reason }
                        }
                    } catch {}
                }
            }
            $entry.fails = $recent
            $entry.fail_count = $recent.Count
        }
    }
    return $state
}

function Record-Fail($agentName, $state) {
    $now = (Get-Date).ToString("o")
    if (-not $state.agents.ContainsKey($agentName)) {
        $state.agents[$agentName] = @{
            fails = @()
            fail_count = 0
            blocked_until = $null
            status = "active"
            first_seen = $now
        }
    }
    $entry = $state.agents[$agentName]
    $entry.fails += @(@{ timestamp = $now; reason = "quest_failed" })
    $entry.fail_count = $entry.fails.Count

    if ($entry.fail_count -ge $state.threshold) {
        $blockedUntil = (Get-Date).AddMinutes($state.cooldown_minutes).ToString("o")
        $entry.blocked_until = $blockedUntil
        $entry.status = "blocked"
        Write-Host "  [BREAKER] $agentName blocked until $blockedUntil (cooldown $($state.cooldown_minutes) min)" -ForegroundColor Red
        # Memoria propia: registrar el bloqueo en arnes.db
        try {
            $memScript = (Get-OsmaMemoryCli)
            if (Test-Path $memScript) {
                & $memScript save -Agent $agentName -Topic "circuit-breaker/breach" -Type "bugfix" -Content "Agent blocked for $($state.cooldown_minutes)min after $($entry.fail_count) fails in window." 2>$null
            }
        } catch {}
    } else {
        Write-Host "  [WARN] $agentName fail $($entry.fail_count)/$($state.threshold)" -ForegroundColor Yellow
    }
    return $state
}

function Record-Pass($agentName, $state) {
    if ($state.agents.ContainsKey($agentName)) {
        $entry = $state.agents[$agentName]
        $entry.fails = @()
        $entry.fail_count = 0
    }
    return $state
}

function Reset-Agent($agentName, $state) {
    if ($state.agents.ContainsKey($agentName)) {
        $entry = $state.agents[$agentName]
        $entry.fails = @()
        $entry.fail_count = 0
        $entry.blocked_until = $null
        $entry.status = "active"
    }
    return $state
}

# === Main ===
$state = Get-State
$state = Purge-Expired $state

switch ($Action) {
    "record-fail" {
        if (-not $Agent) { Write-Error "Agent required"; exit 1 }
        $state = Record-Fail $Agent $state
        Save-State $state
    }
    "record-pass" {
        if (-not $Agent) { Write-Error "Agent required"; exit 1 }
        $state = Record-Pass $Agent $state
        Save-State $state
        Write-Host "  [OK] $Agent pass recorded." -ForegroundColor Green
    }
    "check" {
        if (-not $Agent) { Write-Error "Agent required"; exit 1 }
        if (-not $state.agents.ContainsKey($Agent)) {
            Write-Host "  [ACTIVE] $Agent - fails: 0/$($state.threshold)" -ForegroundColor Green
            exit 0
        }
        $entry = $state.agents[$Agent]
        if ($entry.status -eq "blocked") {
            Write-Host "  [BLOCKED] $Agent blocked until $($entry.blocked_until)" -ForegroundColor Red
            exit 1
        }
        Write-Host "  [ACTIVE] $Agent - fails: $($entry.fail_count)/$($state.threshold)" -ForegroundColor Green
        exit 0
    }
    "reset" {
        if (-not $Agent) { Write-Error "Agent required"; exit 1 }
        $state = Reset-Agent $Agent $state
        Save-State $state
        Write-Host "  [OK] $Agent reset" -ForegroundColor Green
    }
    "status" {
        Write-Host ""
        Write-Host "  CIRCUIT BREAKER STATUS" -ForegroundColor Cyan
        Write-Host "  Threshold: $($state.threshold) fails / $($state.window_minutes) min" -ForegroundColor DarkGray
        Write-Host "  Cooldown: $($state.cooldown_minutes) min" -ForegroundColor DarkGray
        Write-Host ""
        $count = @($state.agents.Keys).Count
        if ($count -eq 0) {
            Write-Host "  No agents tracked yet." -ForegroundColor DarkGray
        } else {
            foreach ($agentName in @($state.agents.Keys)) {
                $entry = $state.agents[$agentName]
                $statusVal = if ($entry.status) { $entry.status } else { "active" }
                $failCountVal = if ($entry.fail_count) { $entry.fail_count } else { 0 }
                $statusColor = if ($statusVal -eq "blocked") { "Red" } else { "Green" }
                Write-Host ("  [{0}] {1} - fails: {2}/{3}" -f $statusVal.ToUpper(), $agentName, $failCountVal, $state.threshold) -ForegroundColor $statusColor
                if ($entry.blocked_until) {
                    Write-Host "         blocked until: $($entry.blocked_until)" -ForegroundColor DarkGray
                }
            }
        }
        Write-Host ""
    }
    "purge" {
        $state = Purge-Expired $state
        Save-State $state
        Write-Host "  [OK] Expired entries purged" -ForegroundColor Green
    }
}
