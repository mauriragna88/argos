$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$ext = Join-Path $root 'pi/extensions/argos-core.ts'
# Modelo determinista (los default de opencode-go pueden estar limitados por cuota)
$model = 'nvidia/nvidia/llama-3.3-nemotron-super-49b-v1.5'
$out = & pi --no-session --model $model -e $ext -p "Responde unicamente: OK" 2>&1
if ($LASTEXITCODE -ne 0) { Write-Host "FAIL boot: $out" -ForegroundColor Red; exit 1 }
if ($out -match 'OK') { Write-Host 'PASS boot-smoke' -ForegroundColor Green; exit 0 }
Write-Host "FAIL boot (sin OK): $out" -ForegroundColor Red; exit 1
