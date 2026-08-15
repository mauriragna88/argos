#Requires -Version 5.1
<#
.SYNOPSIS
Persistent health, retry and soft-budget state for dynamic model routing.

.DESCRIPTION
This module is intentionally provider-agnostic: callers execute providers and
report outcomes here.  It never calls OpenCode and it never changes the legacy
atlas-failover.ps1 state.  `record-failure` returns the deterministic action a
router should take: retry after 2s, retry after 8s, or rotate after a 30 minute
cooldown.  Provider budgets are soft distribution caps, not provider quotas.
#>
[CmdletBinding()]
param(
    [ValidateSet('status','can-use','record-failure','record-success','record-usage')]
    [string]$Action = 'status',
    [string]$Agent = '',
    [string]$Provider = '',
    [string]$Model = '',
    [string]$Capability = '',
    [ValidateSet('transient','quota','stuck')]
    [string]$FailureKind = 'transient',
    [string]$Message = '',
    [int]$TimeoutSec = 90,
    [int]$TokensUsed = 0,
    [string]$QuestId = '',
    [string]$ArnesDir = '',
    [string]$StatePath = '',
    [string]$LedgerPath = '',
    [datetime]$Now = (Get-Date)
)

$ErrorActionPreference = 'Stop'

function Get-WeekStartUtc([datetime]$Date) {
    $utc = $Date.ToUniversalTime()
    $days = (([int]$utc.DayOfWeek + 6) % 7) # Monday = 0
    return $utc.Date.AddDays(-$days).ToString('yyyy-MM-dd')
}
function Save-Json($Value, [string]$Path) {
    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}
function New-State {
    [ordered]@{
        version = '1.0.0'; purpose = 'Per agent/model/provider health and soft budget state'
        retry_policy = [ordered]@{ retry_delays_seconds=@(2,8); failures_before_cooldown=3; cooldown_minutes=30; default_stuck_timeout_seconds=90 }
        week_start_utc = Get-WeekStartUtc $Now; records=@(); provider_usage=@()
    }
}
function Get-Record($State, [string]$RecordAgent, [string]$RecordProvider, [string]$RecordModel) {
    $State.records | Where-Object { $_.agent -eq $RecordAgent -and $_.provider -eq $RecordProvider -and $_.model -eq $RecordModel } | Select-Object -First 1
}
function Ensure-Record($State, [string]$RecordAgent, [string]$RecordProvider, [string]$RecordModel) {
    $found = Get-Record $State $RecordAgent $RecordProvider $RecordModel
    if ($null -ne $found) { return $found }
    $item = [pscustomobject][ordered]@{ agent=$RecordAgent; provider=$RecordProvider; model=$RecordModel; consecutive_transient_failures=0; cooldown_until=$null; last_failure_kind=$null; last_failure_at=$null; last_success_at=$null; stuck_timeout_count=0; last_stuck_timeout_seconds=$null }
    $State.records = @($State.records) + @($item); return $item
}
function Ensure-Usage($State) {
    # Budget distribution is provider-level. Capability remains in the ledger
    # attribution, because one provider can expose more than one capability.
    $found = @($State.provider_usage | Where-Object { $_.provider -eq $Provider } | Select-Object -First 1)
    if ($found.Count -gt 0) { return $found[0] }
    $item = [pscustomobject][ordered]@{ provider=$Provider; tokens_used=0 }
    $State.provider_usage = @($State.provider_usage) + @($item); return $item
}
function Get-ProviderCapPercent {
    param($Policy, [string]$BudgetProvider)
    if (-not $Policy -or -not $Policy.provider_budget_defaults -or -not $Policy.provider_budget_defaults.caps_percent_by_provider) { return $null }
    $p = $Policy.provider_budget_defaults.caps_percent_by_provider.PSObject.Properties[$BudgetProvider]
    if ($null -eq $p) { return $null }; return [int]$p.Value
}
function Get-Budget($State, $Policy, $Ledger) {
    # Capability is evidence metadata; provider policy is the only budget key.
    $percent = Get-ProviderCapPercent $Policy $Provider
    $weekly = if ($Ledger -and $Ledger.limits) { [int64]$Ledger.limits.weekly_tokens_budget } else { 0 }
    $usage = @($State.provider_usage | Where-Object { $_.provider -eq $Provider } | Measure-Object -Property tokens_used -Sum).Sum
    if ($null -eq $usage) { $usage = 0 }
    $cap = if ($null -ne $percent -and $weekly -gt 0) { [int64][math]::Floor($weekly * $percent / 100) } else { $null }
    [ordered]@{ provider=$Provider; capability=$Capability; tokens_used=[int64]$usage; cap_percent=$percent; soft_cap_tokens=$cap; status=if ($null -ne $cap -and $usage -ge $cap) {'deprioritized'} else {'within_soft_cap'} }
}

try {
    if (-not $ArnesDir) { $ArnesDir = Join-Path (Get-Location) '.arnes' }
    if (-not $StatePath) { $StatePath = Join-Path $ArnesDir 'model-health-state.json' }
    if (-not $LedgerPath) { $LedgerPath = Join-Path $ArnesDir 'quest-ledger.json' }
    $policyPath = Join-Path $ArnesDir 'model-routing-policy.json'
    $state = if (Test-Path -LiteralPath $StatePath) { Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json } else { New-State }
    if ($state.week_start_utc -ne (Get-WeekStartUtc $Now)) { $state.week_start_utc = Get-WeekStartUtc $Now; $state.provider_usage = @() }
    if ($null -eq $state.records) { $state.records=@() }; if ($null -eq $state.provider_usage) { $state.provider_usage=@() }
    # Coalesce early development state to provider scope for backwards-safe reads.
    $usageByProvider = @{}
    foreach ($oldUsage in @($state.provider_usage)) {
        if (-not $oldUsage.provider) { continue }
        if (-not $usageByProvider.ContainsKey([string]$oldUsage.provider)) { $usageByProvider[[string]$oldUsage.provider] = 0 }
        $usageByProvider[[string]$oldUsage.provider] += [int64]$oldUsage.tokens_used
    }
    $state.provider_usage = @($usageByProvider.Keys | Sort-Object | ForEach-Object { [pscustomobject][ordered]@{ provider=$_; tokens_used=$usageByProvider[$_] } })
    $policy = if (Test-Path -LiteralPath $policyPath) { Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json } else { $null }
    $ledger = if (Test-Path -LiteralPath $LedgerPath) { Get-Content -LiteralPath $LedgerPath -Raw | ConvertFrom-Json } else { $null }

    if ($Action -ne 'status' -and (-not $Agent -or -not $Provider -or -not $Model)) { throw 'Agent, Provider y Model son requeridos para esta accion.' }
    if ($Action -eq 'record-usage' -and -not $Capability) { throw 'Capability es requerida para atribuir presupuesto.' }

    if ($Action -eq 'status') {
        [ordered]@{ status='ok'; state_path=$StatePath; week_start_utc=$state.week_start_utc; records=@($state.records); provider_usage=@($state.provider_usage) } | ConvertTo-Json -Depth 12; exit 0
    }

    $record = Ensure-Record $state $Agent $Provider $Model
    if ($Action -eq 'can-use') {
        $cooldown = $record.cooldown_until -and ([datetime]$record.cooldown_until -gt $Now)
        $budget = Get-Budget $state $policy $ledger
        [ordered]@{ status='ok'; eligible=(-not $cooldown); routing_priority=if($budget.status -eq 'deprioritized'){'deprioritized'}else{'normal'}; cooldown_until=$record.cooldown_until; budget=$budget } | ConvertTo-Json -Depth 8; exit 0
    }
    if ($Action -eq 'record-success') {
        $record.consecutive_transient_failures=0; $record.cooldown_until=$null; $record.last_success_at=$Now.ToString('o')
        Save-Json $state $StatePath
        [ordered]@{ status='ok'; action='continue'; retry_delay_seconds=0; record=$record } | ConvertTo-Json -Depth 8; exit 0
    }
    if ($Action -eq 'record-failure') {
        $record.consecutive_transient_failures = [int]$record.consecutive_transient_failures + 1
        $record.last_failure_kind=$FailureKind; $record.last_failure_at=$Now.ToString('o')
        if ($FailureKind -eq 'stuck') { $record.stuck_timeout_count=[int]$record.stuck_timeout_count+1; $record.last_stuck_timeout_seconds=$TimeoutSec }
        $count=[int]$record.consecutive_transient_failures
        # Quota failures never benefit from a retry. A second stuck stream is
        # also a rotation signal; ordinary transient failures rotate on third.
        $mustRotate = $FailureKind -eq 'quota' -or ($FailureKind -eq 'stuck' -and [int]$record.stuck_timeout_count -ge 2) -or $count -ge 3
        if ($mustRotate) { $record.cooldown_until=$Now.AddMinutes(30).ToString('o'); $next='rotate'; $delay=0 } else { $next='retry'; $delay=@(2,8)[$count-1] }
        Save-Json $state $StatePath
        [ordered]@{ status='ok'; action=$next; retry_delay_seconds=$delay; failure_number=$count; cooldown_until=$record.cooldown_until; failure_kind=$FailureKind; message=$Message; record=$record } | ConvertTo-Json -Depth 8; exit 0
    }
    # record-usage is deliberately separate from execution: a caller reports actual or estimated tokens once.
    if ($TokensUsed -lt 0) { throw 'TokensUsed no puede ser negativo.' }
    $usage=Ensure-Usage $state; $usage.tokens_used=[int64]$usage.tokens_used + [int64]$TokensUsed
    if ($ledger) {
        if ($null -eq $ledger.model_usage) { $ledger | Add-Member -NotePropertyName model_usage -NotePropertyValue @() }
        $ledger.model_usage = @($ledger.model_usage) + @([pscustomobject][ordered]@{ quest_id=$QuestId; agent=$Agent; provider=$Provider; model=$Model; capability=$Capability; tokens_used=$TokensUsed; timestamp=$Now.ToString('o') })
        Save-Json $ledger $LedgerPath
    }
    Save-Json $state $StatePath
    [ordered]@{ status='ok'; action='attributed'; budget=(Get-Budget $state $policy $ledger) } | ConvertTo-Json -Depth 8
} catch {
    [ordered]@{ status='error'; message=$_.Exception.Message } | ConvertTo-Json -Depth 6
    exit 1
}
