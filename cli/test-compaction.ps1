#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS COGNITIVE COMPACTION - Test de calidad

.DESCRIPTION
Benchmark del spec: simula una sesion con quest + 10 tareas completadas + 5 pendientes
+ 4 decisiones + 2 blockers + 1 skill + 10 archivos + 30 outputs de ruido.
Verifica: quest/goal/completed/pending/decisions/blockers/skill/next_action preservados,
continuidad 100% y ruido descartado (sin reconstruir el plan desde cero).
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'osma-resolve.ps1')
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$MemCli = (Get-OsmaMemoryCli)
$TestDir = Join-Path $env:TEMP 'opencode\arnes-compaction-test'
if (Test-Path $TestDir) { Remove-Item $TestDir -Recurse -Force }
New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

Write-Host ''
Write-Host '  ARGOS COGNITIVE COMPACTION - TEST DE CALIDAD' -ForegroundColor Cyan
Write-Host '  ============================================' -ForegroundColor Cyan

Push-Location $TestDir
try {
    # 1. Inicializar memoria del proyecto de prueba
    & $MemCli init -Quiet | Out-Null

    # 2. Guardar 30 outputs de ruido (tool noise, trivials)
    for ($i = 1; $i -le 30; $i++) {
        & $MemCli save -Agent kuja -Topic ("kuja/tool-noise/" + $i) -Type discovery -Content ("output del tool " + $i + ": " + ('x' * 40)) -Quiet | Out-Null
    }

    # 3. Guardar 10 experiencias episodicas (trabajo real)
    for ($i = 1; $i -le 10; $i++) {
        & $MemCli save -Agent ansem -Topic "ansem/episodio-$i" -Type action -Content "Ansem modifico auth.ts paso $i" -Score 2 -Quiet | Out-Null
    }

    # 4. Crear el COGNITIVE CHECKPOINT completo
    $cp = (& $MemCli checkpoint -Create -QuestId AUTH-024 -Agent argos-ansem `
        -Goal "Implementar refresh-token auth" -Phase implement `
        -Completed @("Supabase client","middleware","login endpoint","token service","session store","error boundary","api client","refresh hook","types","tests setup") `
        -Pending @("refresh token test","RLS verification","cleanup","docs","monitoring") `
        -Files @("src/lib/supabase.ts","middleware.ts","src/auth/token.ts","src/auth/session.ts","src/api/client.ts","src/hooks/useAuth.ts","tests/auth/refresh.spec.ts","tests/auth/login.spec.ts","src/types/auth.ts","src/lib/errors.ts") `
        -ModifiedFiles @("src/lib/supabase.ts","middleware.ts") `
        -Decisions @(184,201,224,300) `
        -Skill systematic-debugging -Stage "hypothesis-verification" `
        -Blockers @("profiles RLS unverified","refresh token expira en 1h") `
        -Errors @("401 en refresh") `
        -TestState "27 PASS, 2 pending" -BuildState "OK" -GitState "feature/auth-refresh" `
        -NextAction "Run tests/auth/refresh.spec.ts e investigar el fallo de RLS" -Quiet) | ConvertFrom-Json

    Write-Host ("  Checkpoint #{0} creado (continuidad {1})" -f $cp.id, $cp.continuity_score)

    # 5. Consolidar reciente (pre-compaction) -> el ruido debe morir
    $cons = (& $MemCli consolidate-recent -Hours 24 -Quiet) | ConvertFrom-Json
    Write-Host ("  Consolidacion: {0} clasificadas (noise={1} semantic={2})" -f $cons.classified, $cons.noise, $cons.semantic)

    # 6. Verificaciones
    $capsule = (& $MemCli capsule -Id $cp.id -Quiet) | ConvertFrom-Json
    $ok = 0; $fail = 0
    function Check($name, $cond) {
        if ($cond) { $script:ok++; Write-Host ("  [OK]   {0}" -f $name) -ForegroundColor Green }
        else { $script:fail++; Write-Host ("  [FAIL] {0}" -f $name) -ForegroundColor Red }
    }
    Check "Quest preservado (AUTH-024)" ($capsule.capsule -match 'Quest: AUTH-024')
    Check "Goal preservado" ($capsule.capsule -match 'Goal: Implementar refresh-token auth')
    Check "Agent preservado (argos-ansem)" ($capsule.capsule -match 'Agent: argos-ansem')
    Check "Completed preservadas (dentro del cap de capsule)" ($capsule.capsule -match 'Supabase client' -and $capsule.capsule -match 'error boundary')
    Check "Pending (5) preservadas" ($capsule.capsule -match 'refresh token test' -and $capsule.capsule -match 'monitoring')
    Check "Decisiones (#184 #201 #224 #300)" ($capsule.capsule -match '#184' -and $capsule.capsule -match '#300')
    Check "Skill + stage preservados" ($capsule.capsule -match 'systematic-debugging' -and $capsule.capsule -match 'hypothesis-verification')
    Check "Blocker preservado" ($capsule.capsule -match 'profiles RLS unverified')
    Check "NEXT ACTION exacta" ($capsule.capsule -match 'Run tests/auth/refresh.spec.ts')
    Check "Continuidad 100% (8/8)" ($cp.continuity_score -eq 1.0)
    Check "Ruido descartado (no en contexto)" ($cons.noise -ge 25)

    Write-Host ''
    Write-Host ("  ═══════════════════════════════════════════════" ) -ForegroundColor Cyan
    Write-Host ("  TEST COMPACTION: {0} OK / {1} FAIL | continuidad {2}" -f $ok, $fail, $cp.continuity_score) -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
    Write-Host '  ═══════════════════════════════════════════════' -ForegroundColor Cyan

    # Metrica para A/B contra Pi vanilla: tokens de la capsule + contexto conservado
    $capsuleChars = $capsule.capsule.Length
    $capsuleTokens = [Math]::Ceiling($capsuleChars / 4)
    $noiseRemoved = $cons.noise
    Write-Host ''
    Write-Host '  Benchmark A/B (ARGOS Cognitive Compaction vs Pi vanilla):' -ForegroundColor Cyan
    Write-Host ("    Recovery Capsule:  {0} caracteres ≈ {1} tokens" -f $capsuleChars, $capsuleTokens) -ForegroundColor White
    Write-Host ("    Campos criticos:    {0}/8 (continuidad {1})" -f (($cp.continuity_score * 8)), $cp.continuity_score) -ForegroundColor White
    Write-Host ("    Ruido descartado:   {0} observaciones" -f $noiseRemoved) -ForegroundColor White
    Write-Host ("    Contexto guardado:  ~{0} tokens (vs el transcript completo de Pi)" -f $capsuleTokens) -ForegroundColor White
    Write-Host '    Esperado Pi vanilla: transcript completo re-sumado (miles de tokens, sin continuidad garantizada)' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host ''
    Write-Host "  Recovery Capsule (resultado):" -ForegroundColor Cyan
    Write-Host ''
    Write-Host "  $($capsule.capsule)" -ForegroundColor White
    Write-Host ''
} finally {
    Pop-Location
}
