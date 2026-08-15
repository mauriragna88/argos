#Requires -Version 5.1
<#
.SYNOPSIS
ARGOS INTERACTION - Modos de interaccion + retroalimentacion post-trabajo

.DESCRIPTION
Define los 3 modos de ARNES ARGOS:
  AUTO       - Trabajo por horas sin retroalimentacion entre tareas. Pide permisos al inicio.
               Solo reporta al final (reporte resumido).
  EDUCATIVO  - Para quien aprende: retroalimentacion tras cada trabajo, explica conceptos,
               responde dudas (Supabase, Next, frameworks...), planea en base al chat.
  MIXTO      - Balance: retroalimentacion resumida tras cada quest, sin detalle didactico
               salvo que el usuario pregunte.

Configuracion: .arnes/preferences.json (mode: auto|educativo|mixto)
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('get-mode', 'set-mode', 'feedback', 'permissions', 'wizard')]
    [string]$Command = 'get-mode',

    [ValidateSet('auto', 'educativo', 'mixto')]
    [string]$Mode,

    [string]$QuestResult = 'PASS',
    [string]$QuestType = 'general',
    [string]$QuestSummary = ''
)

$ErrorActionPreference = 'Stop'
$ProjectDir = (Get-Location).Path
$ArnesDir = Join-Path $ProjectDir '.arnes'
$PrefPath = Join-Path $ArnesDir 'preferences.json'

# Forzar UTF-8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# Lectura segura (no interactivo: vacio en vez de crashear)
function Read-Input {
    param([string]$Prompt)
    try { return Read-Host $Prompt } catch { return '' }
}

function Get-Preferences {
    $defaults = [ordered]@{
        version = '1.0'
        mode = 'mixto'   # auto | educativo | mixto
        updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        auto = [ordered]@{
            report_interval = 'final'   # final | cada_n_quests
            n_quests = 5
            requires_permission = $true
            grant_read = $false
            grant_write = $false
        }
        educativo = [ordered]@{
            explain_concepts = $true
            answer_questions = $true
            plan_from_chat = $true
        }
        mixto = [ordered]@{
            feedback_per_quest = $true
            detailed_only_on_ask = $true
        }
    }
    if (Test-Path $PrefPath) {
        return Get-Content $PrefPath -Raw | ConvertFrom-Json
    }
    return $defaults
}

function Save-Preferences {
    param($Data)
    $Data | ConvertTo-Json -Depth 8 | Set-Content -Path $PrefPath -Encoding UTF8
}

# === FEEDBACK RESUMIDO post-trabajo ===
function Show-Feedback {
    param(
        [string]$Result,
        [string]$Type,
        [string]$Summary,
        [string]$ModeName
    )

    Write-Host ''
    Write-Host '  ────────────────────────────────────────────────' -ForegroundColor DarkGray
    $color = if ($Result -eq 'PASS') { 'Green' } else { 'Yellow' }
    Write-Host ("  [RETRO] Quest {0} ({1})" -f $Result, $Type) -ForegroundColor $color

    if ($ModeName -eq 'auto') {
        # AUTO: solo resumen final, sin detalle
        Write-Host ("  {0}" -f $Summary) -ForegroundColor White
        Write-Host '  (modo AUTO: reporte final al terminar la sesion de trabajo)' -ForegroundColor DarkGray
    }
    elseif ($ModeName -eq 'educativo') {
        # EDUCATIVO: resumen + invitacion a preguntar + explicar concepto si aplica
        Write-Host ("  {0}" -f $Summary) -ForegroundColor White
        Write-Host '  ¿Quieres que te explique algo de este trabajo?' -ForegroundColor Cyan
        Write-Host '  (ej: "que es Supabase?", "por que usamos Next?", "como funciona Zod?")' -ForegroundColor DarkGray
    }
    else {
        # MIXTO: resumen breve, detalle solo si pregunta
        Write-Host ("  {0}" -f $Summary) -ForegroundColor White
        Write-Host '  (modo MIXTO: dime si quieres mas detalle)' -ForegroundColor DarkGray
    }
    Write-Host '  ────────────────────────────────────────────────' -ForegroundColor DarkGray
    Write-Host ''
}

# === PERMISOS para modo AUTO (trabajo por horas) ===
function Show-PermissionsWizard {
    Write-Host ''
    Write-Host '  ╔══════════════════════════════════════════════════════════╗' -ForegroundColor DarkRed
    Write-Host '  ║   PERMISOS - Modo AUTO (trabajo por horas)              ║' -ForegroundColor White
    Write-Host '  ╚══════════════════════════════════════════════════════════╝' -ForegroundColor DarkRed
    Write-Host ''
    Write-Host '  El modo AUTO trabaja por horas sin preguntarte entre cada tarea.' -ForegroundColor White
    Write-Host '  Para eso necesita permisos de acceso a tu proyecto:' -ForegroundColor White
    Write-Host ''
    Write-Host '  [1] Solo lectura (recomendado para revisar/analizar)' -ForegroundColor White
    Write-Host '  [2] Lectura + escritura (para implementar features)' -ForegroundColor White
    Write-Host '  [3] Lectura + escritura + bash (instalar, correr tests, git)' -ForegroundColor White
    Write-Host '  [Q] Cancelar' -ForegroundColor White
    Write-Host ''
    $choice = Read-Input '  Elige nivel de permiso'
    $prefs = Get-Preferences
    switch ($choice) {
        '1' { $prefs.auto.grant_read = $true; $prefs.auto.grant_write = $false; Write-Host '  [OK] Permiso: SOLO LECTURA' -ForegroundColor Green }
        '2' { $prefs.auto.grant_read = $true; $prefs.auto.grant_write = $true; Write-Host '  [OK] Permiso: LECTURA + ESCRITURA' -ForegroundColor Green }
        '3' { $prefs.auto.grant_read = $true; $prefs.auto.grant_write = $true; $prefs.auto.grant_bash = $true; Write-Host '  [OK] Permiso: LECTURA + ESCRITURA + BASH' -ForegroundColor Green }
        'q' { Write-Host '  Permisos no otorgados.' -ForegroundColor Yellow; exit 0 }
        'Q' { Write-Host '  Permisos no otorgados.' -ForegroundColor Yellow; exit 0 }
        default { Show-PermissionsWizard; return }
    }
    $prefs.auto.requires_permission = $false
    $prefs.updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Save-Preferences $prefs
    Write-Host '  Guardado en .arnes/preferences.json' -ForegroundColor DarkGray
}

# === WIZARD DE MODO ===
function Show-ModeWizard {
    Write-Host ''
    Write-Host '  ╔══════════════════════════════════════════════════════════╗' -ForegroundColor DarkRed
    Write-Host '  ║   MODO DE INTERACCION - Como trabajas con ARNES ARGOS   ║' -ForegroundColor White
    Write-Host '  ╚══════════════════════════════════════════════════════════╝' -ForegroundColor DarkRed
    Write-Host ''
    Write-Host '  1. AUTO      - Trabajo por horas sin retroalimentacion entre' -ForegroundColor White
    Write-Host '                tareas. Reporta solo al final. Pide permisos.' -ForegroundColor DarkGray
    Write-Host '                Ideal: tareas grandes, tu confias en el harness.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  2. EDUCATIVO - Retroalimentacion tras cada trabajo.' -ForegroundColor White
    Write-Host '                Explica conceptos (Supabase, Next, Zod...),' -ForegroundColor DarkGray
    Write-Host '                responde dudas, planea en base al chat.' -ForegroundColor DarkGray
    Write-Host '                Ideal: aprendes mientras trabajas.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  3. MIXTO     - Retroalimentacion resumida tras cada quest,' -ForegroundColor White
    Write-Host '                detalle solo si preguntas.' -ForegroundColor DarkGray
    Write-Host '                Ideal: balance entre velocidad y control.' -ForegroundColor DarkGray
    Write-Host ''
    $choice = Read-Input '  Elige tu modo [1/2/3]'
    $prefs = Get-Preferences
    switch ($choice) {
        '1' {
            $prefs.mode = 'auto'
            Save-Preferences $prefs
            Write-Host '  [OK] Modo AUTO activado.' -ForegroundColor Green
            if ($prefs.auto.requires_permission) {
                Write-Host '  El modo AUTO necesita permisos de trabajo:' -ForegroundColor Yellow
                Show-PermissionsWizard
            }
        }
        '2' {
            $prefs.mode = 'educativo'
            Save-Preferences $prefs
            Write-Host '  [OK] Modo EDUCATIVO activado.' -ForegroundColor Green
        }
        '3' {
            $prefs.mode = 'mixto'
            Save-Preferences $prefs
            Write-Host '  [OK] Modo MIXTO activado.' -ForegroundColor Green
        }
        default { Write-Host '  Sin cambios.' -ForegroundColor Yellow }
    }
}

# === MAIN ===
switch ($Command) {
    'get-mode' {
        $prefs = Get-Preferences
        Write-Output $prefs.mode
    }
    'set-mode' {
        if (-not $Mode) { throw 'Falta -Mode (auto|educativo|mixto)' }
        $prefs = Get-Preferences
        $prefs.mode = $Mode
        $prefs.updated_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Save-Preferences $prefs
        Write-Host "  [OK] Modo '$Mode' guardado." -ForegroundColor Green
        if ($Mode -eq 'auto' -and $prefs.auto.requires_permission) {
            Write-Host '  El modo AUTO necesita permisos:' -ForegroundColor Yellow
            Show-PermissionsWizard
        }
    }
    'feedback' {
        $prefs = Get-Preferences
        Show-Feedback -Result $QuestResult -Type $QuestType -Summary $QuestSummary -ModeName $prefs.mode
    }
    'permissions' {
        Show-PermissionsWizard
    }
    'wizard' {
        Show-ModeWizard
    }
}
