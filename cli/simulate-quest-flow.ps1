# simulate-quest-flow.ps1
# Simulates a complete quest cycle through the upgraded memory architecture:
# TURN 4: Vivi completes quest, Varys writes to blackboard + write-back vivi-memory
# TURN 5: Varys evidence_pack
# TURN 6: Tywin verdict (PASS)
# TURN 7: Sam reads blackboard, generates new sam-digest.json
# TURN 0.5 NEXT: Atlas reads the new digest and shows recommendations

param(
  [string]$ArnesRoot = "$PSScriptRoot\..",
  [string]$QuestId = "Q-023",
  [string]$QuestType = "frontend",
  [string]$Party = "vivi,eiko",
  [string]$Verdict = "PASS",
  [int]$Tokens = 1200,
  [string]$Learning = "Tailwind v4 container queries work better than card media queries for responsive dashboard grids. Reusable for future dashboard quests."
)

$ErrorActionPreference = "Stop"
$bbPath = Join-Path $ArnesRoot ".arnes\shared-blackboard.json"
$dgPath = Join-Path $ArnesRoot ".arnes\sam-digest.json"
$samArchive = Join-Path $ArnesRoot ".arnes\memory\sam-archive.jsonl"
$samRecs = Join-Path $ArnesRoot ".arnes\memory\sam-recommendations.jsonl"
$samTrust = Join-Path $ArnesRoot ".arnes\memory\sam-trust-scores.jsonl"
$varysLog = Join-Path $ArnesRoot ".arnes\memory\varys-turn-log.jsonl"
$viviMem = Join-Path $ArnesRoot ".arnes\memory\vivi-memory.jsonl"
$ts = (Get-Date).ToString("o")

Write-Host "=== QUEST $QuestId SIMULATION ===" -ForegroundColor Cyan
Write-Host "Type:   $QuestType" -ForegroundColor Gray
Write-Host "Party:  $Party"     -ForegroundColor Gray
Write-Host "Verdict: $Verdict"   -ForegroundColor Gray
Write-Host ""

# TURN 4: Varys observes, writes to blackboard
Write-Host "[TURN 4] Varys writes to shared-blackboard.json" -ForegroundColor Yellow
$bb = Get-Content $bbPath -Raw | ConvertFrom-Json
$before = $bb.patterns.Count

# Add a pattern (if Vivi learned something new)
$patId = "pat-$($before + 1)"
$newPattern = [PSCustomObject]@{
  id = $patId
  pattern = $Learning
  discovered_by = "vivi"
  quest_id = $QuestId
  type = "pattern"
  success_rate = 1.0
  last_used = $QuestId
  tags = @($QuestType, "tailwind", "responsive")
}
$bb.patterns += $newPattern

# Add agent learning for Vivi (cross-agent visible)
$bb.agent_learnings.vivi += [PSCustomObject]@{
  quest = $QuestId
  learning = $Learning
  type = "pattern"
  timestamp = $ts
}

# Update blackboard metadata
$bb.updated_at = $ts
$bb.updated_by = "varys"
$bb.last_quest_id = $QuestId

# Save blackboard
$bb | ConvertTo-Json -Depth 10 | Set-Content -Path $bbPath -Encoding UTF8 -NoNewline
Write-Host "  -> Pattern $patId added ($($bb.patterns.Count) total)" -ForegroundColor Green
Write-Host "  -> agent_learnings.vivi updated" -ForegroundColor Green

# TURN 5: Varys write-back to per-agent memory
Write-Host "[TURN 5] Varys write-back to vivi-memory.jsonl" -ForegroundColor Yellow
$writeBack = [PSCustomObject]@{
  title = "$QuestId $Verdict + learning"
  type = "pattern"
  quest_id = $QuestId
  timestamp = $ts
  content = "$QuestId PASS by vivi. Learning: $Learning"
} | ConvertTo-Json -Compress
Add-Content -Path $viviMem -Value $writeBack -Encoding UTF8
Write-Host "  -> Write-back to vivi-memory.jsonl" -ForegroundColor Green

# TURN 5: Varys writes own log
Write-Host "[TURN 5] Varys appends to varys-turn-log.jsonl" -ForegroundColor Yellow
$logEntry = [PSCustomObject]@{
  title = "$QuestId observation"
  type = "action"
  quest_id = $QuestId
  timestamp = $ts
  content = "$QuestId observed: $Party executed, $Verdict, $Tokens tokens, pattern discovered: $Learning"
} | ConvertTo-Json -Compress
Add-Content -Path $varysLog -Value $logEntry -Encoding UTF8
Write-Host "  ->_LOGENTRY" -ForegroundColor Green

# TURN 6: Tywin emits verdict (PASS, no remediation)
Write-Host "[TURN 6] Tywin emits verdict: $Verdict" -ForegroundColor Yellow
Write-Host "  -> Verdict: $Verdict ($QuestId)" -ForegroundColor Green
if ($Verdict -ne "PASS") {
  Write-Host "  -> Remediation brief would be added to blackboard here" -ForegroundColor Gray
}

# TURN 7: Sam reads blackboard, generates new digest
Write-Host "[TURN 7] Sam generates new sam-digest.json" -ForegroundColor Yellow
$nextQuest = "Q-024"

# Calculate trust score update based on verdict
$bb = Get-Content $bbPath -Raw | ConvertFrom-Json
$viviScore = [math]::Min(1.0, $bb.trust_scores.vivi.score + 0.005)
$bb.trust_scores.vivi.score = $viviScore
$bb.trust_scores.vivi.quests_with_party = $bb.trust_scores.vivi.quests_with_party + 1
$bb.trust_scores.vivi.quests_since_last_fail = $bb.trust_scores.vivi.quests_since_last_fail + 1
$bb.trust_scores.vivi.recent_fail_count = 0

# Update party config history
$foundConfig = $false
foreach ($p in $bb.party_config_history) {
  if ($p.quest_type -eq $QuestType -and ($p.party -join ",") -eq ($Party -split "," -join ",")) {
    $p.total_quests = $p.total_quests + 1
    $p.last_used_quest = $QuestId
    $p.success_rate = [math]::Round($p.success_rate * 0.95 + 1.0 * 0.05, 3)
    $foundConfig = $true
    break
  }
}
if (-not $foundConfig) {
  $bb.party_config_history += [PSCustomObject]@{
    quest_type = $QuestType
    party = $Party -split ","
    success_rate = 1.0
    total_quests = 1
    last_used_quest = $QuestId
  }
}
$bb | ConvertTo-Json -Depth 10 | Set-Content -Path $bbPath -Encoding UTF8 -NoNewline
Write-Host "  -> Blackboard trust scores + party history updated" -ForegroundColor Green

# Generate new sam-digest.json (atomic overwrite)
$newDigest = [PSCustomObject]@{
  schema = "1.0"
  generated_at = $ts
  generated_after_quest = $QuestId
  atlas_read_before_quest = $nextQuest
  top_recommendations = @(
    [PSCustomObject]@{
      priority = 1
      recommendation = "Vivi+Eiko continues at $($viviScore) trust ($QuestType, $($bb.party_config_history[0].total_quests) quests, $($bb.party_config_history[0].success_rate) success). Safe default."
      based_on = @("party_config_history", "trust_scores:vivi")
      expires_after_quest = $null
      severity = "info"
    },
    [PSCustomObject]@{
      priority = 2
      recommendation = "Pattern discovered in ${QuestId}: container queries for responsive grids. Reuse for future dashboard quests."
      based_on = @($patId)
      expires_after_quest = $null
      severity = "info"
    },
    [PSCustomObject]@{
      priority = 3
      recommendation = "Ansem remains at 0.5 trust (circuit breaker Q-002). Pair with Auron or Eiko for any backend quest."
      based_on = @("trust_scores:ansem")
      expires_after_quest = $null
      severity = "medium"
    }
  )
  agent_trust_scores = [PSCustomObject]@{
    vivi = [PSCustomObject]@{ score = $viviScore; trend = "stable" }
    eiko = [PSCustomObject]@{ score = 1.0; trend = "stable" }
    ansem = [PSCustomObject]@{ score = 0.5; trend = "falling" }
    kuja = [PSCustomObject]@{ score = 1.0; trend = "stable" }
    amarant = [PSCustomObject]@{ score = 1.0; trend = "n/a" }
    eremez = [PSCustomObject]@{ score = 1.0; trend = "n/a" }
    auron = [PSCustomObject]@{ score = 1.0; trend = "n/a" }
  }
  risk_alerts = @(
    [PSCustomObject]@{
      alert = "Ansem still at 0.5 trust. Do not assign solo backend."
      severity = "medium"
      agent = "ansem"
      action = "pair with Auron or Eiko"
    }
  )
  lessons_from_last_quest = @(
    "$QuestId PASS by Vivi. Tokens: $Tokens. Pattern discovered: container queries for responsive grids.",
    "Trust score vivi: $($bb.trust_scores.vivi.quests_with_party) quests total, $($bb.trust_scores.vivi.quests_since_last_fail) since last fail."
  )
  party_config_recommendation = [PSCustomObject]@{
    for_quest_type = $QuestType
    recommended_party = @("vivi", "eiko")
    rationale = "$($bb.party_config_history[0].success_rate) success rate over $($bb.party_config_history[0].total_quests) quests. Default safe config."
    historical_success_rate = $bb.party_config_history[0].success_rate
  }
  anti_repetition_warnings = @()
}
$newDigest | ConvertTo-Json -Depth 10 | Set-Content -Path $dgPath -Encoding UTF8 -NoNewline
Write-Host "  -> sam-digest.json regenerated (quest bridge to $nextQuest)" -ForegroundColor Green

# Sam memory persistence (append to JSONL)
$archiveEntry = [PSCustomObject]@{
  title = "$QuestId $Verdict"
  type = "action"
  quest_id = $QuestId
  agent = "vivi"
  verdict = $Verdict
  tokens = $Tokens
  timestamp = $ts
  content = "Quest $QuestId completed by vivi. Verdict: $Verdict. Tokens: $Tokens. Pattern discovered."
} | ConvertTo-Json -Compress
Add-Content -Path $samArchive -Value $archiveEntry -Encoding UTF8

$recEntry = [PSCustomObject]@{
  title = "$QuestId post-quest counsel"
  type = "recommendation"
  quest_id = $QuestId
  timestamp = $ts
  content = "$QuestId PASS. Vivi continues at $($viviScore) trust. Recommend continuing Vivi+Eiko. Pattern: container queries reusable."
} | ConvertTo-Json -Compress
Add-Content -Path $samRecs -Value $recEntry -Encoding UTF8

$trustStr = "vivi:$viviScore(stable,$($bb.trust_scores.vivi.quests_with_party)q) eiko:1.0 ansem:0.5(falling) kuja:1.0"
$trustEntry = [PSCustomObject]@{
  title = "Trust scores as of $QuestId"
  type = "pattern"
  timestamp = $ts
  content = $trustStr
} | ConvertTo-Json -Compress
Add-Content -Path $samTrust -Value $trustEntry -Encoding UTF8
Write-Host "  -> sam-archive/recs/trust JSONL appended" -ForegroundColor Green

# TURN 0.5 NEXT QUEST: Atlas reads digest before party select
Write-Host ""
Write-Host "[TURN 0.5 NEXT QUEST $nextQuest] Atlas reads sam-digest.json" -ForegroundColor Green
$readDigest = Get-Content $dgPath -Raw | ConvertFrom-Json
Write-Host "  Atlas Decision Context:" -ForegroundColor Cyan
Write-Host "  +========================================+"
Write-Host "  | ATLAS - SAM DIGEST READ (pre-party)   |"
Write-Host "  | Quest $nextQuest -- should pick party now   |"
Write-Host "  +========================================+"
$readDigest.top_recommendations | Sort-Object priority | ForEach-Object {
  Write-Host "  | [P$($_.priority)] $($_.recommendation)" -ForegroundColor White
}
Write-Host "  |"
Write-Host "  | Trust Scores:" -ForegroundColor Cyan
$readDigest.agent_trust_scores.PSObject.Properties | ForEach-Object {
  $s = $_.Value.score
  $t = $_.Value.trend
  Write-Host "  |   $($_.Name): $s ($t)" -ForegroundColor Gray
}
Write-Host "  |"
Write-Host "  | Risk Alerts:" -ForegroundColor Cyan
$readDigest.risk_alerts | ForEach-Object {
  Write-Host "  |   [$_.severity] $($_.alert)" -ForegroundColor Yellow
}
Write-Host "  |"
Write-Host "  | Party Config Recommendation:" -ForegroundColor Cyan
$pcr = $readDigest.party_config_recommendation
Write-Host "  |   $($pcr.recommended_party -join ',') for $($pcr.for_quest_type)"
Write-Host "  |   rationale: $($pcr.rationale)"
Write-Host "  +========================================+"
# LEDGER UPDATE: Append quest entry and update stats
$ledgerPath = Join-Path $ArnesRoot ".arnes\quest-ledger.json"
Write-Host "[LEDGER] Updating quest-ledger.json" -ForegroundColor Yellow
$ledger = Get-Content $ledgerPath -Raw | ConvertFrom-Json
$leadAgent = ($Party -split ",")[0].Trim()

$newEntry = [PSCustomObject]@{
  agent = $leadAgent
  verdict = $Verdict
  tokens_used = $Tokens
  quest_id = $QuestId
  timestamp = $ts
}
$ledger.quests += $newEntry

$ledger.stats.total_quests = $ledger.stats.total_quests + 1
$ledger.stats.total_tokens_used = $ledger.stats.total_tokens_used + $Tokens

$ledger | ConvertTo-Json -Depth 10 | Set-Content -Path $ledgerPath -Encoding UTF8 -NoNewline
Write-Host "  -> Quest $QuestId appended by $leadAgent ($Tokens tokens)" -ForegroundColor Green
Write-Host "  -> stats.total_quests = $($ledger.stats.total_quests)" -ForegroundColor Green
Write-Host "  -> stats.total_tokens_used = $($ledger.stats.total_tokens_used)" -ForegroundColor Green

Write-Host ""
Write-Host "=== QUEST $QuestId SIMULATION COMPLETE ===" -ForegroundColor Cyan
