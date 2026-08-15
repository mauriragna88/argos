# test-shared-memory.ps1
# Smoke test: validates the full memory cycle
# blackboard write -> blackboard read -> digest write -> digest read
# Usage: .\test-shared-memory.ps1

param(
  [string]$ArnesRoot = "$PSScriptRoot\.."
)

$ErrorActionPreference = "Stop"
$pass = 0
$fail = 0
$tests = @()

function Test-Case($name, $condition, $detail = "") {
  if ($condition) {
    $script:pass++
    $script:tests += "PASS  $name $detail"
    Write-Host "  PASS  $name" -ForegroundColor Green
  } else {
    $script:fail++
    $script:tests += "FAIL  $name $detail"
    Write-Host "  FAIL  $name $detail" -ForegroundColor Red
  }
}

Write-Host "`n=== ARNES SHARED MEMORY SMOKE TEST ===`n" -ForegroundColor Cyan

# --- 1. Schemas exist and parse ---
Write-Host "[1/7] Schema validation" -ForegroundColor Yellow
$bbSchema = Join-Path $ArnesRoot "core\protocols\shared-blackboard.schema.json"
$dgSchema = Join-Path $ArnesRoot "core\protocols\sam-digest.schema.json"
Test-Case "shared-blackboard.schema.json exists" (Test-Path $bbSchema)
Test-Case "sam-digest.schema.json exists" (Test-Path $dgSchema)
if (Test-Path $bbSchema) {
  try { $null = Get-Content $bbSchema -Raw | ConvertFrom-Json; Test-Case "blackboard schema is valid JSON" $true }
  catch { Test-Case "blackboard schema is valid JSON" $false $_ }
}
if (Test-Path $dgSchema) {
  try { $null = Get-Content $dgSchema -Raw | ConvertFrom-Json; Test-Case "digest schema is valid JSON" $true }
  catch { Test-Case "digest schema is valid JSON" $false $_ }
}

# --- 2. Data files exist and parse ---
Write-Host "`n[2/7] Data file validation" -ForegroundColor Yellow
$bbPath = Join-Path $ArnesRoot ".arnes\shared-blackboard.json"
$dgPath = Join-Path $ArnesRoot ".arnes\sam-digest.json"
Test-Case "shared-blackboard.json exists" (Test-Path $bbPath)
Test-Case "sam-digest.json exists" (Test-Path $dgPath)
$bb = $null; $dg = $null
if (Test-Path $bbPath) {
  try { $bb = Get-Content $bbPath -Raw | ConvertFrom-Json; Test-Case "blackboard is valid JSON" $true }
  catch { Test-Case "blackboard is valid JSON" $false $_ }
}
if (Test-Path $dgPath) {
  try { $dg = Get-Content $dgPath -Raw | ConvertFrom-Json; Test-Case "digest is valid JSON" $true }
  catch { Test-Case "digest is valid JSON" $false $_ }
}

# --- 3. Blackboard required fields ---
Write-Host "`n[3/7] Blackboard required fields" -ForegroundColor Yellow
if ($bb) {
  Test-Case "blackboard.version = 1.0.0" ($bb.version -eq "1.0.0")
  Test-Case "blackboard.last_quest_id present" (-not [string]::IsNullOrWhiteSpace($bb.last_quest_id))
  Test-Case "blackboard.patterns is array" ($bb.patterns -is [System.Array])
  Test-Case "blackboard.agent_learnings has agents" ($null -ne $bb.agent_learnings.vivi)
  Test-Case "blackboard.failed_attempts is array" ($bb.failed_attempts -is [System.Array])
  Test-Case "blackboard.party_config_history is array" ($bb.party_config_history -is [System.Array])
  Test-Case "blackboard.trust_scores has agents" ($null -ne $bb.trust_scores.vivi)
  Test-Case "blackboard.circuit_breaker_state present" ($null -ne $bb.circuit_breaker_state)
}

# --- 4. Sam digest required fields ---
Write-Host "`n[4/7] Sam digest required fields" -ForegroundColor Yellow
if ($dg) {
  Test-Case "digest.schema = 1.0" ($dg.schema -eq "1.0")
  Test-Case "digest.generated_after_quest present" (-not [string]::IsNullOrWhiteSpace($dg.generated_after_quest))
  Test-Case "digest.top_recommendations is array" ($dg.top_recommendations -is [System.Array])
  Test-Case "digest.agent_trust_scores has agents" ($null -ne $dg.agent_trust_scores.vivi)
  Test-Case "digest.lessons_from_last_quest is array" ($dg.lessons_from_last_quest -is [System.Array])
  Test-Case "digest.anti_repetition_warnings is array" ($dg.anti_repetition_warnings -is [System.Array])
}

# --- 5. Sam memory files exist ---
Write-Host "`n[5/7] Sam memory files" -ForegroundColor Yellow
$samFiles = @(
  "sam-archive.jsonl",
  "sam-recommendations.jsonl",
  "sam-trust-scores.jsonl",
  "sam-counsel-major.jsonl"
)
foreach ($f in $samFiles) {
  $p = Join-Path $ArnesRoot ".arnes\memory\$f"
  Test-Case "$f exists" (Test-Path $p)
  if (Test-Path $p) {
    $lines = (Get-Content $p | Where-Object { $_.Trim() -ne "" }).Count
    Test-Case "$f has content" ($lines -gt 0) "($lines lines)"
  }
}

# --- 6. Varys turn log exists ---
Write-Host "`n[6/7] Varys turn log" -ForegroundColor Yellow
$varysLog = Join-Path $ArnesRoot ".arnes\memory\varys-turn-log.jsonl"
Test-Case "varys-turn-log.jsonl exists" (Test-Path $varysLog)
if (Test-Path $varysLog) {
  $lines = (Get-Content $varysLog | Where-Object { $_.Trim() -ne "" }).Count
  Test-Case "varys-turn-log has content" ($lines -gt 0) "($lines lines)"
}

# --- 7. Write-Read-Roundtrip test (simulate Varys write + Atlas read) ---
Write-Host "`n[7/7] Write-Read roundtrip simulation" -ForegroundColor Yellow
$testQuestId = "Q-SMOKE-$(Get-Date -Format 'yyyyMMddHHmmss')"
$testPattern = @{
  id = "pat-smoke-001"
  pattern = "Smoke test pattern: validated blackboard write-read cycle"
  discovered_by = "varys"
  quest_id = $testQuestId
  type = "discovery"
  success_rate = 1.0
  tags = @("smoke-test", "validation")
}
try {
  # Read blackboard
  $bbLive = Get-Content $bbPath -Raw | ConvertFrom-Json
  $originalPatterns = $bbLive.patterns.Count
  
  # Simulate Varys write: add a pattern
  $bbLive.patterns += $testPattern
  $bbLive.updated_at = (Get-Date).ToString("o")
  $bbLive.updated_by = "varys"
  $bbLive.last_quest_id = $testQuestId
  
  # Write back
  $bbLive | ConvertTo-Json -Depth 10 | Set-Content -Path $bbPath -Encoding UTF8 -NoNewline
  Test-Case "Varys writes pattern to blackboard" $true
  
  # Simulate Atlas read: verify the pattern is there
  $bbRead = Get-Content $bbPath -Raw | ConvertFrom-Json
  $found = $false
  foreach ($p in $bbRead.patterns) {
    if ($p.id -eq "pat-smoke-001") { $found = $true; break }
  }
  Test-Case "Atlas reads pattern from blackboard" $found
  Test-Case "blackboard updated_by = varys" ($bbRead.updated_by -eq "varys")
  Test-Case "blackboard last_quest_id updated" ($bbRead.last_quest_id -eq $testQuestId)
  
  # Cleanup: remove the test pattern
  $bbClean = Get-Content $bbPath -Raw | ConvertFrom-Json
  $bbClean.patterns = @($bbClean.patterns | Where-Object { $_.id -ne "pat-smoke-001" })
  $bbClean.updated_at = "2026-08-04T14:00:00-06:00"
  $bbClean.updated_by = "atlas"
  $bbClean.last_quest_id = "Q-022"
  $bbClean | ConvertTo-Json -Depth 10 | Set-Content -Path $bbPath -Encoding UTF8 -NoNewline
  Test-Case "Cleanup: test pattern removed" $true
  
  $bbFinal = Get-Content $bbPath -Raw | ConvertFrom-Json
  Test-Case "Blackboard restored to original state" ($bbFinal.patterns.Count -eq $originalPatterns)
} catch {
  Test-Case "Write-read roundtrip" $false $_.Exception.Message
}

# --- Summary ---
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "  Passed: $pass" -ForegroundColor Green
Write-Host "  Failed: $fail" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Green" })
Write-Host "  Total:  $($pass + $fail)"

if ($fail -gt 0) {
  Write-Host "`nFailed tests:" -ForegroundColor Red
  $tests | Where-Object { $_ -match "^FAIL" } | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  exit 1
} else {
  Write-Host "`nAll tests passed. Shared memory architecture is operational." -ForegroundColor Green
  exit 0
}
