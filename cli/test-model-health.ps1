#Requires -Version 5.1
$ErrorActionPreference='Stop'
$script=Join-Path $PSScriptRoot 'model-health.ps1'; $tmp=Join-Path ([IO.Path]::GetTempPath()) ('arnes-health-'+[guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  $policy = @{ provider_budget_defaults=@{ caps_percent_by_provider=@{ tokenrouter=30 } } } | ConvertTo-Json -Depth 8
  Set-Content (Join-Path $tmp 'model-routing-policy.json') $policy -Encoding UTF8
  @{ limits=@{ weekly_tokens_budget=1000 }; quests=@() } | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $tmp 'quest-ledger.json') -Encoding UTF8
  $base=[datetime]'2026-08-03T12:00:00Z'
  function Call([string]$Action,[string]$Kind='',[string]$Cap='',[int]$Tokens=0,[string]$Quest='',[int]$Timeout=90,[datetime]$At=$base,[string]$ModelName='tokenrouter/kimi-k3-free') { $params=@{Action=$Action;ArnesDir=$tmp;Agent='vivi';Provider='tokenrouter';Model=$ModelName;Now=$At;TimeoutSec=$Timeout}; if($Kind){$params.FailureKind=$Kind};if($Cap){$params.Capability=$Cap};if($Tokens){$params.TokensUsed=$Tokens};if($Quest){$params.QuestId=$Quest}; $raw=& $script @params; if($LASTEXITCODE -ne 0){throw "health command failed: $raw"}; return $raw|ConvertFrom-Json }
  $one=Call 'record-failure' 'transient'; if($one.action -ne 'retry' -or $one.retry_delay_seconds -ne 2){throw 'first transient failure must retry after 2s'}
  $two=Call 'record-failure' 'stuck' '' 0 '' 90 $base.AddSeconds(2); if($two.action -ne 'retry' -or $two.retry_delay_seconds -ne 8 -or $two.record.stuck_timeout_count -ne 1){throw 'second/stuck failure metadata incorrect'}
  $three=Call 'record-failure' 'quota' '' 0 '' 90 $base.AddSeconds(10) 'tokenrouter/quota-model'; if($three.action -ne 'rotate' -or ([datetime]$three.cooldown_until -ne $base.AddSeconds(10).AddMinutes(30))){throw 'quota must rotate immediately with an exact 30 minute cooldown'}
  $firstFreshStuck=Call 'record-failure' 'stuck' '' 0 '' 90 $base.AddSeconds(11) 'tokenrouter/stuck-model'; if($firstFreshStuck.action -ne 'retry'){throw 'first stuck timeout must retry'}
  $secondStuck=Call 'record-failure' 'stuck' '' 0 '' 90 $base.AddSeconds(12) 'tokenrouter/stuck-model'; if($secondStuck.action -ne 'rotate' -or ([datetime]$secondStuck.cooldown_until -ne $base.AddSeconds(12).AddMinutes(30))){throw 'second stuck timeout must rotate with an exact 30 minute cooldown'}
  $blocked=Call 'can-use' '' 'kimi_k3' 0 '' 90 $base.AddMinutes(1) 'tokenrouter/stuck-model'; if($blocked.eligible){throw 'cooldown must make model ineligible'}
  $ok=Call 'record-success' '' '' 0 '' 90 $base.AddMinutes(31); if($ok.record.consecutive_transient_failures -ne 0){throw 'success must reset failures'}
  $used=Call 'record-usage' '' 'kimi_k3' 200 'Q-test' 90 $base.AddMinutes(32); if($used.budget.status -ne 'within_soft_cap'){throw 'initial provider use must remain within cap'}
  $providerAggregate=Call 'record-usage' '' 'glm_5_2' 101 'Q-test-2' 90 $base.AddMinutes(33) 'tokenrouter/glm-5.2'; if($providerAggregate.budget.tokens_used -ne 301 -or $providerAggregate.budget.status -ne 'deprioritized' -or $providerAggregate.budget.soft_cap_tokens -ne 300){throw 'budget must aggregate by provider while retaining capability attribution'}
  $ledger=Get-Content (Join-Path $tmp 'quest-ledger.json') -Raw|ConvertFrom-Json; if(@($ledger.model_usage).Count -ne 2 -or $ledger.model_usage[1].capability -ne 'glm_5_2'){throw 'ledger model attribution missing'}
  Write-Host 'PASS model-health: transient retries, quota/stuck rotation, exact cooldown, provider cap and ledger attribution' -ForegroundColor Green
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
