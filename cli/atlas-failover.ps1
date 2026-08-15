#Requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('status','next','record-failure','record-success')][string]$Action='status',[string]$Message='')
$ErrorActionPreference='Stop'; $root=Resolve-Path (Join-Path $PSScriptRoot '..'); $dir=Join-Path $root '.arnes'; $chainPath=Join-Path $dir 'model-chain.json'; $statePath=Join-Path $dir 'model-failover-state.json'
$chain=Get-Content $chainPath -Raw|ConvertFrom-Json
$state=if(Test-Path $statePath){Get-Content $statePath -Raw|ConvertFrom-Json}else{[pscustomobject]@{version='1.0';models=@{}}}
function Save-State{$state|ConvertTo-Json -Depth 8|Set-Content $statePath -Encoding UTF8}
function Is-Transient([string]$text){$patterns=@('internal server','internal_error','reconnecting','connection reset','connection refused','timeout','rate limit','429','502','503'); return $patterns|Where-Object{$text -match [regex]::Escape($_)}|Select-Object -First 1}
function Candidates { $live=@(cmd /c 'opencode models' 2>&1|Where-Object{$_ -match '^[\w-]+/.+'}|ForEach-Object{$_.Trim()}); $now=Get-Date; foreach($m in @($chain.models|Sort-Object slot)){ $s=$state.models.($m.full_id); $cool=$s -and $s.cooldown_until -and ([datetime]$s.cooldown_until -gt $now); if(($m.full_id -in $live) -and -not $cool){$m} } }
if($Action -eq 'record-failure'){if(-not(Is-Transient $Message)){throw 'El mensaje no es un error transitorio reconocido.'}; $m=(Candidates|Select-Object -First 1); if(-not $m){throw 'No hay modelo elegible.'}; if(-not $state.models.PSObject.Properties[$m.full_id]){$state.models|Add-Member NoteProperty $m.full_id ([pscustomobject]@{failures=0;cooldown_until=$null})}; $entry=$state.models.($m.full_id); $entry.failures++; if($entry.failures -ge 3){$entry.cooldown_until=(Get-Date).AddMinutes(30).ToString('o');$entry.failures=0}; Save-State; Write-Host "Fallo registrado: $($m.full_id)"; exit 0}
if($Action -eq 'record-success'){ $m=(Candidates|Select-Object -First 1); if($m -and $state.models.PSObject.Properties[$m.full_id]){$state.models.($m.full_id).failures=0;Save-State}; exit 0 }
if($Action -eq 'next'){ $m=(Candidates|Select-Object -First 1); if(-not $m){throw 'No hay modelo disponible.'}; $m.full_id; exit 0 }
Write-Host '  FAILOVER ATLAS FF' -ForegroundColor Cyan; foreach($m in @($chain.models|Sort-Object slot)){ $s=$state.models.($m.full_id);$fails=if($s){$s.failures}else{0};$cool=if($s){$s.cooldown_until}else{$null};Write-Host "  $($m.slot). $($m.full_id) | fallos=$fails | cooldown=$cool"}; $next=(Candidates|Select-Object -First 1);Write-Host "  Siguiente elegible: $($next.full_id)" -ForegroundColor Green
