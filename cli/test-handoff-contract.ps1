# test-handoff-contract.ps1 - Deterministic semantic validation for contract fixtures
#Requires -Version 5.1
[CmdletBinding()]
param([string]$Root = '')
$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path
$contractPath = Join-Path $Root 'core\protocols\atlas-context-handoff.schema.json'
$statePath = Join-Path $Root 'core\protocols\atlas-handoff-state.schema.json'
foreach ($path in @($contractPath, $statePath)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing schema: $path" }; $null = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json }

function Assert-Keys([hashtable]$Value, [string[]]$Required, [string[]]$Allowed, [string]$Name) {
    foreach ($key in $Required) { if (-not $Value.ContainsKey($key)) { throw "$Name missing $key" } }
    foreach ($key in $Value.Keys) { if ($key -notin $Allowed) { throw "$Name has extra property $key" } }
}
function ConvertTo-Hashtable([object]$Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [hashtable]) { return $Value }
    if ($Value -is [pscustomobject]) { $result = @{}; foreach ($property in $Value.PSObject.Properties) { $result[$property.Name] = ConvertTo-Hashtable $property.Value }; return $result }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) { return @($Value | ForEach-Object { ConvertTo-Hashtable $_ }) }
    return $Value
}
function Copy-Value([object]$Value) {
    if ($Value -is [hashtable]) { $copy = @{}; foreach ($key in $Value.Keys) { $copy[$key] = Copy-Value $Value[$key] }; return $copy }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) { return @($Value | ForEach-Object { Copy-Value $_ }) }
    return $Value
}
function Assert-Ref([hashtable]$Ref, [string]$QuestId, [string]$AttemptId, [string]$Name) {
    Assert-Keys $Ref @('path_or_id','quest_id','attempt_id') @('kind','path_or_id','quest_id','attempt_id','integrity_ref') $Name
    if ([string]::IsNullOrWhiteSpace($Ref.path_or_id) -or $Ref.quest_id -ne $QuestId -or $Ref.attempt_id -ne $AttemptId) { throw "$Name is not correlated to active quest/attempt" }
}
function Get-AttemptOrdinal([string]$AttemptId) {
    if ($AttemptId -notmatch '^A-([0-9]{3,})$') { throw 'invalid attempt format' }
    return [int64]$Matches[1]
}
function Assert-Contract([hashtable]$Value) {
    $top = @('schema_version','type','handoff_id','from_role','to_role','quest','objective','dependency_status','context_scope','evidence_refs','model_attribution','next_action','audit')
    Assert-Keys $Value @('schema_version','type','handoff_id','from_role','to_role','quest','objective','dependency_status','context_scope','evidence_refs','model_attribution','next_action') $top 'handoff'
    if ($Value.schema_version -ne '1.0' -or $Value.type -ne 'atlas_context_handoff' -or $Value.handoff_id -notmatch '^H-[A-Za-z0-9][A-Za-z0-9._-]*$') { throw 'invalid handoff identity or format' }
    Assert-Keys $Value.quest @('quest_id','attempt_id','status') @('quest_id','attempt_id','status') 'quest'
    if ($Value.quest.quest_id -notmatch '^Q-[0-9]{3,}$' -or $Value.quest.attempt_id -notmatch '^A-[0-9]{3,}$') { throw 'invalid quest or attempt format' }
    $flows = @('atlas>executor','executor>varys','varys>tywin','tywin>sam','sam>atlas'); $flow = "$($Value.from_role)>$($Value.to_role)"; if ($flow -notin $flows) { throw 'invalid role transition' }
    Assert-Keys $Value.context_scope @('summary','included_sections','memory_refs','full_history_included') @('summary','included_sections','memory_refs','full_history_included') 'context_scope'
    if ($Value.context_scope.full_history_included -ne $false -or @($Value.context_scope.included_sections).Count -eq 0) { throw 'unscoped or empty context' }
    $allowedByRecipient = @{ executor=@('objective','acceptance_criteria','dependencies','route'); varys=@('objective','acceptance_criteria','dependencies','evidence'); tywin=@('acceptance_criteria','evidence','remediation'); sam=@('evidence','remediation','historical_lessons'); atlas=@('dependencies','evidence','remediation','historical_lessons','route') }
    foreach ($section in @($Value.context_scope.included_sections)) { if ($section -notin $allowedByRecipient[$Value.to_role]) { throw "section $section is not allowed for $($Value.to_role)" } }
    foreach ($ref in @($Value.context_scope.memory_refs)) { Assert-Ref $ref $Value.quest.quest_id $Value.quest.attempt_id 'memory_ref' }
    foreach ($ref in @($Value.evidence_refs)) { Assert-Ref $ref $Value.quest.quest_id $Value.quest.attempt_id 'evidence_ref'; if ($ref.kind -notin @('evidence_pack','audit_request','verdict','remediation_brief','sam_counsel','atlas_decision','command_output','diff','memory')) { throw 'invalid evidence kind' } }
    Assert-Keys $Value.model_attribution @('agent','provider','model','route_reason','quest_id','attempt_id') @('agent','provider','model','route_reason','quest_id','attempt_id','request_ref') 'model_attribution'
    foreach ($key in @('agent','provider','model','route_reason')) { if ([string]::IsNullOrWhiteSpace($Value.model_attribution[$key])) { throw "missing model attribution: $key" } }
    if ($Value.model_attribution.quest_id -ne $Value.quest.quest_id -or $Value.model_attribution.attempt_id -ne $Value.quest.attempt_id) { throw 'model attribution is not correlated' }
    Assert-Keys $Value.next_action @('owner','action','success_criteria') @('owner','action','success_criteria') 'next_action'; if (@($Value.next_action.success_criteria).Count -lt 1) { throw 'next action has no success criteria' }
    if ($flow -eq 'varys>tywin' -and -not (@($Value.evidence_refs | Where-Object { $_.kind -eq 'evidence_pack' }).Count -eq 1)) { throw 'Varys to Tywin requires exactly one evidence_pack' }
    if ($flow -eq 'tywin>sam') {
        if (-not $Value.ContainsKey('audit')) { throw 'Tywin to Sam requires audit data' }
        Assert-Keys $Value.audit @('verdict_status','verdict_ref','remediation_ref') @('verdict_status','verdict_ref','remediation_ref') 'audit'
        if ($Value.audit.verdict_status -notin @('PASS','FAIL_PARTIAL','FAIL_TOTAL')) { throw 'invalid verdict status' }
        Assert-Ref $Value.audit.verdict_ref $Value.quest.quest_id $Value.quest.attempt_id 'verdict_ref'
        $verdictEvidence = @($Value.evidence_refs | Where-Object { $_.kind -eq 'verdict' }); if ($verdictEvidence.Count -ne 1 -or $verdictEvidence[0].path_or_id -ne $Value.audit.verdict_ref.path_or_id) { throw 'Sam must receive the audited verdict reference' }
        if ($Value.audit.verdict_status -eq 'PASS' -and $null -ne $Value.audit.remediation_ref) { throw 'PASS may not carry remediation' }
        if ($Value.audit.verdict_status -ne 'PASS') { if ($null -eq $Value.audit.remediation_ref) { throw 'FAIL requires remediation reference' }; Assert-Ref $Value.audit.remediation_ref $Value.quest.quest_id $Value.quest.attempt_id 'remediation_ref'; $remediationEvidence = @($Value.evidence_refs | Where-Object { $_.kind -eq 'remediation_brief' }); if ($remediationEvidence.Count -ne 1 -or $remediationEvidence[0].path_or_id -ne $Value.audit.remediation_ref.path_or_id) { throw 'Sam must receive the audited remediation reference on FAIL' } }
    }
}
function Assert-State([hashtable]$Value) {
    $allowed = @('schema_version','quest_id','current_attempt_id','objective','status','dependencies','handoff_refs','prior_attempt_refs','model_attribution','latest_evidence_refs','latest_decision_ref','next_action_summary','updated_at')
    Assert-Keys $Value @('schema_version','quest_id','current_attempt_id','objective','status','dependencies','handoff_refs','prior_attempt_refs','model_attribution','updated_at') $allowed 'state'
    if ($Value.schema_version -ne '1.0' -or $Value.quest_id -notmatch '^Q-[0-9]{3,}$' -or $Value.current_attempt_id -notmatch '^A-[0-9]{3,}$') { throw 'invalid state identity' }
    foreach ($route in @($Value.model_attribution)) { Assert-Keys $route @('agent','provider','model','quest_id','attempt_id') @('agent','provider','model','quest_id','attempt_id','route_reason') 'state attribution'; if ([string]::IsNullOrWhiteSpace($route.agent) -or [string]::IsNullOrWhiteSpace($route.provider) -or [string]::IsNullOrWhiteSpace($route.model) -or $route.quest_id -ne $Value.quest_id -or $route.attempt_id -ne $Value.current_attempt_id) { throw 'state attribution lacks continuity' } }
    foreach ($ref in @($Value.handoff_refs)) {
        Assert-Keys $ref @('handoff_id','from_role','to_role','path_or_id','quest_id','attempt_id') @('handoff_id','from_role','to_role','path_or_id','quest_id','attempt_id') 'handoff_ref'
        $flows = @('atlas>executor','executor>varys','varys>tywin','tywin>sam','sam>atlas')
        if ($ref.handoff_id -notmatch '^H-[A-Za-z0-9][A-Za-z0-9._-]*$' -or $ref.quest_id -ne $Value.quest_id -or $ref.attempt_id -ne $Value.current_attempt_id -or ("$($ref.from_role)>$($ref.to_role)") -notin $flows) { throw 'handoff ref lacks continuity or canonical transition' }
    }
    if ($Value.ContainsKey('latest_evidence_refs')) { foreach ($ref in @($Value.latest_evidence_refs)) { Assert-Ref $ref $Value.quest_id $Value.current_attempt_id 'state evidence ref' } }
    foreach ($ref in @($Value.prior_attempt_refs)) {
        Assert-Keys $ref @('path_or_id','quest_id','attempt_id') @('path_or_id','quest_id','attempt_id') 'prior_attempt_ref'
        if ([string]::IsNullOrWhiteSpace($ref.path_or_id) -or $ref.quest_id -ne $Value.quest_id -or (Get-AttemptOrdinal $ref.attempt_id) -ge (Get-AttemptOrdinal $Value.current_attempt_id)) { throw 'prior attempt ref must be same quest and genuinely earlier' }
    }
    if ($Value.status -eq 'retrying' -and @($Value.prior_attempt_refs).Count -lt 1) { throw 'retry must preserve prior attempt references' }
}

$base = @{ schema_version='1.0'; type='atlas_context_handoff'; handoff_id='H-Q-001-A-001-01'; from_role='atlas'; to_role='executor'; quest=@{quest_id='Q-001';attempt_id='A-001';status='in_progress'}; objective='Implement an isolated change.'; dependency_status=@(); context_scope=@{summary='Execution requirements only.';included_sections=@('objective','route');memory_refs=@();full_history_included=$false}; evidence_refs=@(); model_attribution=@{agent='vivi';provider='example-provider';model='example-model';route_reason='healthy preferred route';quest_id='Q-001';attempt_id='A-001'}; next_action=@{owner='executor';action='Execute and report artifacts.';success_criteria=@('Report evidence.')} }
Assert-Contract $base
$tywinFail = @{}; foreach($k in $base.Keys){$tywinFail[$k]=$base[$k]}; $tywinFail.from_role='tywin';$tywinFail.to_role='sam';$tywinFail.context_scope=@{summary='Audit result.';included_sections=@('evidence','remediation');memory_refs=@();full_history_included=$false};$tywinFail.evidence_refs=@(@{kind='verdict';path_or_id='runs/Q-001/A-001/verdict.json';quest_id='Q-001';attempt_id='A-001'},@{kind='remediation_brief';path_or_id='runs/Q-001/A-001/remediation.json';quest_id='Q-001';attempt_id='A-001'});$tywinFail.audit=@{verdict_status='FAIL_PARTIAL';verdict_ref=@{path_or_id='runs/Q-001/A-001/verdict.json';quest_id='Q-001';attempt_id='A-001'};remediation_ref=@{path_or_id='runs/Q-001/A-001/remediation.json';quest_id='Q-001';attempt_id='A-001'}}
Assert-Contract $tywinFail
$state=@{schema_version='1.0';quest_id='Q-001';current_attempt_id='A-001';objective='Implement an isolated change.';status='in_progress';dependencies=@();handoff_refs=@(@{handoff_id='H-Q-001-A-001-01';from_role='atlas';to_role='executor';path_or_id='handoffs/1.json';quest_id='Q-001';attempt_id='A-001'});prior_attempt_refs=@();model_attribution=@(@{agent='vivi';provider='example-provider';model='example-model';quest_id='Q-001';attempt_id='A-001'});updated_at='2026-08-02T00:00:00Z'}
Assert-State $state

$invalid = @(
 @{ name='full history'; mutate={param($x) $x.context_scope.full_history_included=$true} }, @{ name='recipient scope'; mutate={param($x) $x.context_scope.included_sections=@('historical_lessons')} }, @{ name='missing provider'; mutate={param($x) $x.model_attribution.provider=''} }, @{ name='bad role'; mutate={param($x) $x.from_role='sam';$x.to_role='executor'} }, @{ name='extra property'; mutate={param($x) $x.untrusted_history='no'} }, @{ name='format'; mutate={param($x) $x.quest.attempt_id='attempt-one'} }, @{ name='correlation'; mutate={param($x) $x.model_attribution.attempt_id='A-002'} }
)
foreach($case in $invalid){$candidate=Copy-Value $base;& $case.mutate $candidate;try{Assert-Contract $candidate;throw "$($case.name) unexpectedly accepted"}catch{if($_.Exception.Message -eq "$($case.name) unexpectedly accepted"){throw}}}
$varys=@{};foreach($k in $base.Keys){$varys[$k]=$base[$k]};$varys.from_role='varys';$varys.to_role='tywin';$varys.context_scope=@{summary='Evidence only.';included_sections=@('evidence');memory_refs=@();full_history_included=$false};try{Assert-Contract $varys;throw 'missing evidence pack unexpectedly accepted'}catch{if($_.Exception.Message -eq 'missing evidence pack unexpectedly accepted'){throw}}
$failNoRem=Copy-Value $tywinFail;$failNoRem.audit.remediation_ref=$null;$failNoRem.evidence_refs=@($failNoRem.evidence_refs|Where-Object{$_.kind -ne 'remediation_brief'});try{Assert-Contract $failNoRem;throw 'fail without remediation unexpectedly accepted'}catch{if($_.Exception.Message -eq 'fail without remediation unexpectedly accepted'){throw}}
$wrongVerdict=Copy-Value $tywinFail;$wrongVerdict.evidence_refs[0].path_or_id='runs/Q-001/A-001/other-verdict.json';try{Assert-Contract $wrongVerdict;throw 'wrong verdict reference unexpectedly accepted'}catch{if($_.Exception.Message -eq 'wrong verdict reference unexpectedly accepted'){throw}}
$retry=Copy-Value $state;$retry.status='retrying';$retry.current_attempt_id='A-002';$retry.handoff_refs=@();$retry.model_attribution=@(@{agent='vivi';provider='example-provider';model='example-model';quest_id='Q-001';attempt_id='A-002'});try{Assert-State $retry;throw 'retry without prior reference unexpectedly accepted'}catch{if($_.Exception.Message -eq 'retry without prior reference unexpectedly accepted'){throw}}
$validRetry=Copy-Value $retry;$validRetry.prior_attempt_refs=@(@{path_or_id='runs/Q-001/A-001/verdict.json';quest_id='Q-001';attempt_id='A-001'});Assert-State $validRetry
$wrongPrior=Copy-Value $validRetry;$wrongPrior.prior_attempt_refs=@(@{path_or_id='runs/Q-002/A-001/verdict.json';quest_id='Q-002';attempt_id='A-001'});try{Assert-State $wrongPrior;throw 'cross quest prior reference unexpectedly accepted'}catch{if($_.Exception.Message -eq 'cross quest prior reference unexpectedly accepted'){throw}}
$currentPrior=Copy-Value $validRetry;$currentPrior.prior_attempt_refs=@(@{path_or_id='runs/Q-001/A-002/verdict.json';quest_id='Q-001';attempt_id='A-002'});try{Assert-State $currentPrior;throw 'non prior attempt reference unexpectedly accepted'}catch{if($_.Exception.Message -eq 'non prior attempt reference unexpectedly accepted'){throw}}
$badStateFlow=Copy-Value $state;$badStateFlow.handoff_refs=@(@{handoff_id='H-Q-001-A-001-01';from_role='sam';to_role='executor';path_or_id='handoffs/1.json';quest_id='Q-001';attempt_id='A-001'});try{Assert-State $badStateFlow;throw 'noncanonical state handoff unexpectedly accepted'}catch{if($_.Exception.Message -eq 'noncanonical state handoff unexpectedly accepted'){throw}}
foreach($field in @('agent','model')){$badStateRoute=Copy-Value $state;$badStateRoute.model_attribution=@(@{agent='vivi';provider='example-provider';model='example-model';quest_id='Q-001';attempt_id='A-001'});$badStateRoute.model_attribution[0][$field]='';try{Assert-State $badStateRoute;throw "blank state $field unexpectedly accepted"}catch{if($_.Exception.Message -eq "blank state $field unexpectedly accepted"){throw}}}
Write-Host 'PASS hand-off contract: schemas parse; negative guards cover scope, evidence, remediation, correlation, extras, format, and retry continuity.' -ForegroundColor Green
