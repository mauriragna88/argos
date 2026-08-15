#Requires -Version 5.1
<#
.SYNOPSIS
Helper de unlocks de skills por nivel para ARGOS XP.

.DESCRIPTION
Dot-sourcable (`. cli\skill-unlocks.ps1`). Lee los skill trees de
`core\skills\*.json` y expone funciones para saber que skills tiene
desbloqueadas un agente segun su nivel.

Soporta dos formatos JSON:
  - Shape A: clave top-level variable (spells/skills/abilities/heals) con
    entrada `name` + `level`.
  - Shape B: clave top-level `tree` con entrada `skill` + `level`.

Funciones:
  Get-AgentSkillFile <agente>   -> ruta del archivo de skills ('' si no existe)
  Get-SkillsForLevel <agente> <nivel> -> nombres de skills que se desbloquean en ese nivel
  Get-SkillCounts <agente> <nivel>    -> [Total, Unlocked] para el resumen de ranking

.EXAMPLE
. (Join-Path $PSScriptRoot 'skill-unlocks.ps1')
Get-SkillsForLevel 'vivi' 1
#>

# ==== Mapeo agente -> archivo de skills ====
function Get-AgentSkillFile {
    [CmdletBinding()]
    param([string]$AgentName)

    $key = ($AgentName).ToLower()
    $map = @{
        'vivi'    = 'mage-spells.json'
        'ansem'   = 'paladin-skills.json'
        'kuja'    = 'rogue-abilities.json'
        'eiko'    = 'cleric-heals.json'
        'amarant' = 'monk-skills.json'
        'eremez'  = 'ranger-skills.json'
        'auron'   = 'auron-skills.json'
        'bran'    = 'bran-skills.json'
        'quina'   = 'quina-skills.json'
    }

    if (-not $map.ContainsKey($key)) { return '' }
    return (Join-Path $PSScriptRoot ('..\core\skills\' + $map[$key]))
}

# ==== Cargar lista de skills (nombre + nivel de unlock) de un agente ====
function Get-AgentSkillList {
    [CmdletBinding()]
    param([string]$AgentName)

    $file = Get-AgentSkillFile $AgentName
    if (-not $file -or -not (Test-Path $file)) { return @() }

    $data = Get-Content $file -Raw | ConvertFrom-Json

    # Shape B usa la clave 'tree'; Shape A usa la primera propiedad que sea array.
    $list = @()
    if ($data.PSObject.Properties['tree']) {
        $list = @($data.tree)
    }
    else {
        foreach ($prop in $data.PSObject.Properties) {
            if ($prop.Value -is [System.Array]) { $list = @($prop.Value); break }
        }
    }
    if ($list.Count -eq 0) { return @() }

    # Si las entradas traen 'level'/'unlock_level' se usa el campo; si no,
    # formula: unlocks en niveles 1, 3, 5, 7, 10 distribuidos en la lista.
    $hasLevelField = ($null -ne $list[0].level) -or ($null -ne $list[0].unlock_level)
    $unlockLevels = @(1, 3, 5, 7, 10)

    $skills = @()
    for ($i = 0; $i -lt $list.Count; $i++) {
        $s = $list[$i]

        $name = ''
        if ($s.PSObject.Properties['name']) { $name = [string]$s.name }
        elseif ($s.PSObject.Properties['skill']) { $name = [string]$s.skill }

        $unlock = 0
        if ($hasLevelField) {
            if ($null -ne $s.level) { $unlock = [int]$s.level }
            elseif ($null -ne $s.unlock_level) { $unlock = [int]$s.unlock_level }
        }
        else {
            $idx = [math]::Min($i, $unlockLevels.Count - 1)
            $unlock = $unlockLevels[$idx]
        }

        $skills += [pscustomobject]@{ Name = $name; Level = $unlock }
    }

    return $skills
}

# ==== Skills desbloqueadas EN un nivel dado ====
function Get-SkillsForLevel {
    [CmdletBinding()]
    param(
        [string]$AgentName,
        [int]$Level
    )

    $result = @()
    foreach ($s in @(Get-AgentSkillList $AgentName)) {
        if ($s.Level -eq $Level -and $s.Name) { $result += $s.Name }
    }
    return $result
}

# ==== Resumen para ranking: total y desbloqueadas hasta el nivel actual ====
function Get-SkillCounts {
    [CmdletBinding()]
    param(
        [string]$AgentName,
        [int]$Level
    )

    $list = @(Get-AgentSkillList $AgentName)
    $total = $list.Count
    $unlocked = 0
    foreach ($s in $list) {
        if ($s.Level -le $Level) { $unlocked++ }
    }
    return [pscustomobject]@{ Total = $total; Unlocked = $unlocked }
}
