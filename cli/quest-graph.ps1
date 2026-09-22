# quest-graph.ps1 - FASE 4: Quest Graph (gate de Bran + nodos con estados)
# ==========================================================================
# El quest graph NO es un motor nuevo: es la evolucion en-repo de
# autonomous_tasks (el brain OSMA es repo externo; patron ADR-012/017/019).
# Bran decide con `justify` si el quest merece graph; si no, queda lineal.
#
# Acciones:
#   justify    -> gate de Bran: graph|linear + razones (graph_justification)
#   create     -> crear el grafo de un quest desde tareas con deps
#   status     -> estado del grafo (nodos + counts)
#   next       -> nodos READY (deps en pass, no pausados)
#   set        -> transicionar un nodo (pending|ready|running|verifying|pass|fail|blocked|paused) + evidence
#   invalidate -> invalidar un nodo y TODOS sus dependientes downstream (recursivo)
#   fork       -> duplicar un nodo como variante (sin colision de id)
#   pause      -> pausar un nodo (o el grafo completo con -All)
#
# Uso:
#   .\cli\quest-graph.ps1 -Action justify -Prompt "migrar auth + dashboard + api" -Features 3 -Dependencies 4
#   .\cli\quest-graph.ps1 -Action create -QuestId Q-900 -Tasks '[{"id":"n1","title":"schema","deps":[]},{"id":"n2","title":"api","deps":["n1"]}]'
#   .\cli\quest-graph.ps1 -Action next -QuestId Q-900
#   .\cli\quest-graph.ps1 -Action set -QuestId Q-900 -Node n1 -Status pass -Evidence "tests ok"
#   .\cli\quest-graph.ps1 -Action invalidate -QuestId Q-900 -Node n1
#   .\cli\quest-graph.ps1 -Action fork -QuestId Q-900 -Node n2 -Variant alt
#   .\cli\quest-graph.ps1 -Action pause -QuestId Q-900 -Node n2

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("justify","create","status","next","set","invalidate","fork","pause")]
    [string]$Action = "status",
    [string]$QuestId = "",
    [string]$Prompt = "",
    [string]$Tasks = "",
    [string]$TasksFile = "",
    [string]$Node = "",
    [ValidateSet("","pending","ready","running","verifying","pass","fail","blocked","paused")]
    [string]$Status = "",
    [string]$Evidence = "",
    [string]$Variant = "",
    [switch]$All,
    [switch]$Json,
    # --- justify (senales del gate de Bran) ---
    [int]$Features = 0,
    [int]$Dependencies = 0,
    [switch]$ParallelFrontBack,
    [switch]$Migrations,
    [int]$Integrations = 0,
    [switch]$NewProject,
    [int]$LongTasks = 0,
    [string]$ArnesDir = ""
)

$ErrorActionPreference = "Continue"

if (-not $ArnesDir) {
    $cwd = (Get-Location).Path
    if (Test-Path (Join-Path $cwd ".arnes\config.json")) { $ArnesDir = Join-Path $cwd ".arnes" } else { $ArnesDir = ".arnes" }
}

$graphDir = Join-Path $ArnesDir "quest-graph"

function Get-GraphFile([string]$qid) { return (Join-Path $graphDir ("{0}.json" -f $qid)) }

function Read-Graph([string]$qid) {
    $f = Get-GraphFile $qid
    if (-not (Test-Path -LiteralPath $f)) { return $null }
    try { return (Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

function Write-Graph($g) {
    if (-not (Test-Path $graphDir)) { New-Item -ItemType Directory -Path $graphDir -Force | Out-Null }
    $g | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Get-GraphFile $g.quest_id) -Encoding UTF8
}

function Get-Dependents($g, [string]$nodeId, [string[]]$seen = @()) {
    # dependientes directos e indirectos (recursivo, con guard anti-ciclo)
    $result = @()
    foreach ($n in @($g.nodes)) {
        if (@($n.deps) -contains $nodeId -and ($seen -notcontains $n.id)) {
            $seen += $n.id
            $result += $n.id
            $result += (Get-Dependents $g $n.id $seen)
        }
    }
    return @($result | Select-Object -Unique)
}

# === JUSTIFY (gate de Bran, ADR-022) ===
if ($Action -eq "justify") {
    $reasons = @()
    if ($Dependencies -ge 2) { $reasons += "dependencias entre tareas ($Dependencies)" }
    if ($Features -ge 2 -and $ParallelFrontBack) { $reasons += "frontend/backend en paralelo con $Features features" }
    if ($Migrations) { $reasons += "migraciones (orden no conmutable)" }
    if ($Integrations -ge 2) { $reasons += "integraciones multiples ($Integrations)" }
    if ($NewProject) { $reasons += "proyecto nuevo (fan-out inicial)" }
    if ($LongTasks -ge 2) { $reasons += "tareas largas ($LongTasks) recuperables por nodo" }
    if ($Features -ge 3) { $reasons += "fan-out de features ($Features)" }

    $verdict = if (@($reasons).Count -gt 0) { "graph" } else { "linear" }
    $justification = [ordered]@{
        event = "graph_justification"
        ts = (Get-Date).ToString("o")
        quest = $Prompt
        signals = [ordered]@{
            features = $Features; dependencies = $Dependencies; parallel_front_back = [bool]$ParallelFrontBack
            migrations = [bool]$Migrations; integrations = $Integrations; new_project = [bool]$NewProject; long_tasks = $LongTasks
        }
        verdict = $verdict
        reasons = $reasons
    }
    if (-not (Test-Path $ArnesDir)) { New-Item -ItemType Directory -Path $ArnesDir -Force | Out-Null }
    Add-Content -LiteralPath (Join-Path $ArnesDir "graph-justifications.jsonl") -Value (($justification | ConvertTo-Json -Compress -Depth 6)) -Encoding UTF8

    if ($Json) { $justification | ConvertTo-Json -Depth 6 }
    else { Write-Host ("  [GRAPH] veredicto: {0}" -f $verdict) -ForegroundColor $(if ($verdict -eq "graph") { "Green" } else { "DarkGray" }); foreach ($r in $reasons) { Write-Host ("          - {0}" -f $r) -ForegroundColor DarkGray } }
    exit 0
}

# === CREATE ===
if ($Action -eq "create") {
    if (-not $QuestId) { Write-Error "create requiere -QuestId"; exit 1 }
    if (-not $Tasks -and $TasksFile) {
        if (-not (Test-Path -LiteralPath $TasksFile)) { Write-Error "TasksFile no existe: $TasksFile"; exit 1 }
        $Tasks = [System.IO.File]::ReadAllText($TasksFile)
    }
    if (-not $Tasks) { Write-Error "create requiere -Tasks (JSON) o -TasksFile (ruta)"; exit 1 }
    try { $parsed = $Tasks | ConvertFrom-Json } catch { Write-Error "Tasks no es JSON valido: $($_.Exception.Message)"; exit 1 }
    if (@($parsed).Count -eq 0) { Write-Error "Tasks vacio"; exit 1 }

    $nodes = @()
    foreach ($t in @($parsed)) {
        if (-not $t.id) { Write-Error "nodo sin id"; exit 1 }
        $nodes += [ordered]@{
            id = "$($t.id)"
            title = "$($t.title)"
            deps = @($t.deps)
            status = "pending"
            evidence = ""
            updated_at = (Get-Date).ToString("o")
        }
    }
    $g = [ordered]@{ quest_id = $QuestId; created_at = (Get-Date).ToString("o"); paused = $false; nodes = $nodes }
    Write-Graph $g
    if ($Json) { $g | ConvertTo-Json -Depth 8 } else { Write-Host ("  [GRAPH] {0}: {1} nodos creados" -f $QuestId, @($nodes).Count) -ForegroundColor Green }
    exit 0
}

# === STATUS ===
if ($Action -eq "status") {
    $g = Read-Graph $QuestId
    if (-not $g) {
        if ($Json) { @{ quest_id = $QuestId; exists = $false } | ConvertTo-Json; exit 0 }
        Write-Host ("  [GRAPH] {0}: no existe (crear con -Action create)" -f $QuestId) -ForegroundColor Yellow
        exit 0
    }
    $counts = @{}
    foreach ($n in @($g.nodes)) { $s = "$($n.status)"; if (-not $counts.ContainsKey($s)) { $counts[$s] = 0 }; $counts[$s]++ }
    if ($Json) {
        @{ quest_id = $g.quest_id; paused = [bool]$g.paused; counts = $counts; nodes = @($g.nodes) } | ConvertTo-Json -Depth 8
        exit 0
    }
    Write-Host ""
    Write-Host ("  QUEST GRAPH {0}{1}" -f $g.quest_id, $(if ($g.paused) { " (PAUSADO)" } else { "" })) -ForegroundColor Cyan
    Write-Host "  ==================" -ForegroundColor Cyan
    foreach ($n in @($g.nodes)) {
        $color = switch ("$($n.status)") { "pass" { "Green" } "fail" { "Red" } "running" { "Yellow" } "paused" { "DarkYellow" } "verifying" { "Magenta" } default { "White" } }
        Write-Host ("    {0,-14} {1,-9} deps=[{2}] {3}" -f $n.id, $n.status, (@($n.deps) -join ','), $n.title) -ForegroundColor $color
    }
    Write-Host ""
    exit 0
}

# === NEXT (nodos READY: deps en pass, nodo pending/ready y grafo no pausado) ===
if ($Action -eq "next") {
    $g = Read-Graph $QuestId
    if (-not $g) { if ($Json) { @{ quest_id = $QuestId; exists = $false; ready = @() } | ConvertTo-Json } else { Write-Host ("  [GRAPH] {0}: no existe" -f $QuestId) -ForegroundColor Yellow }; exit 0 }
    $ready = @()
    if (-not $g.paused) {
        foreach ($n in @($g.nodes)) {
            if ("$($n.status)" -notin @("pending","ready")) { continue }
            $depsOk = $true
            foreach ($dep in @($n.deps)) {
                $depNode = @($g.nodes | Where-Object { $_.id -eq $dep })[0]
                if (-not $depNode -or "$($depNode.status)" -ne "pass") { $depsOk = $false; break }
            }
            if ($depsOk) { $ready += $n }
        }
    }
    if ($Json) { @{ quest_id = $QuestId; paused = [bool]$g.paused; ready = @($ready | ForEach-Object { $_.id }) } | ConvertTo-Json; exit 0 }
    if (@($ready).Count -eq 0) { Write-Host "  [GRAPH] Sin nodos READY." -ForegroundColor Yellow; exit 0 }
    Write-Host "  [GRAPH] READY:" -ForegroundColor Green
    foreach ($n in $ready) { Write-Host ("    {0} - {1}" -f $n.id, $n.title) -ForegroundColor White }
    exit 0
}

# === SET (transicion de estado + evidence) ===
if ($Action -eq "set") {
    if (-not $QuestId -or -not $Node -or -not $Status) { Write-Error "set requiere -QuestId -Node -Status"; exit 1 }
    $g = Read-Graph $QuestId
    if (-not $g) { Write-Error "grafo $QuestId no existe"; exit 1 }
    $target = @($g.nodes | Where-Object { $_.id -eq $Node })[0]
    if (-not $target) { Write-Error "nodo '$Node' no existe en $QuestId"; exit 1 }
    $target.status = $Status
    if ($Evidence) { $target.evidence = $Evidence }
    $target.updated_at = (Get-Date).ToString("o")
    Write-Graph $g
    if ($Json) { $target | ConvertTo-Json -Depth 6 } else { Write-Host ("  [GRAPH] {0}/{1} -> {2}" -f $QuestId, $Node, $Status) -ForegroundColor Green }
    exit 0
}

# === INVALIDATE (nodo + dependientes downstream, recursivo - ADR-023) ===
if ($Action -eq "invalidate") {
    if (-not $QuestId -or -not $Node) { Write-Error "invalidate requiere -QuestId -Node"; exit 1 }
    $g = Read-Graph $QuestId
    if (-not $g) { Write-Error "grafo $QuestId no existe"; exit 1 }
    $target = @($g.nodes | Where-Object { $_.id -eq $Node })[0]
    if (-not $target) { Write-Error "nodo '$Node' no existe en $QuestId"; exit 1 }
    $affected = @($Node) + (Get-Dependents $g $Node)
    foreach ($id in $affected) {
        $n = @($g.nodes | Where-Object { $_.id -eq $id })[0]
        $n.status = "pending"
        $n.evidence = "invalidado por cambio en '$Node'"
        $n.updated_at = (Get-Date).ToString("o")
    }
    Write-Graph $g
    if ($Json) { @{ quest_id = $QuestId; invalidated = $affected } | ConvertTo-Json; exit 0 }
    Write-Host ("  [GRAPH] {0}: invalidados {1} nodos: {2}" -f $QuestId, @($affected).Count, ($affected -join ', ')) -ForegroundColor Yellow
    exit 0
}

# === FORK (variante de un nodo, sin colision) ===
if ($Action -eq "fork") {
    if (-not $QuestId -or -not $Node -or -not $Variant) { Write-Error "fork requiere -QuestId -Node -Variant"; exit 1 }
    $g = Read-Graph $QuestId
    if (-not $g) { Write-Error "grafo $QuestId no existe"; exit 1 }
    $target = @($g.nodes | Where-Object { $_.id -eq $Node })[0]
    if (-not $target) { Write-Error "nodo '$Node' no existe en $QuestId"; exit 1 }
    $newId = "$Node-$Variant"
    if (@($g.nodes | Where-Object { $_.id -eq $newId }).Count -gt 0) { Write-Error "variante '$newId' ya existe"; exit 1 }
    $g.nodes = @($g.nodes) + @([ordered]@{
        id = $newId
        title = "$($target.title) (variante $Variant)"
        deps = @($target.deps)
        status = "pending"
        evidence = ""
        updated_at = (Get-Date).ToString("o")
    })
    Write-Graph $g
    if ($Json) { @{ quest_id = $QuestId; forked = $newId } | ConvertTo-Json; exit 0 }
    Write-Host ("  [GRAPH] {0}: fork {1} -> {2}" -f $QuestId, $Node, $newId) -ForegroundColor Green
    exit 0
}

# === PAUSE (nodo o grafo completo) ===
if ($Action -eq "pause") {
    if (-not $QuestId) { Write-Error "pause requiere -QuestId"; exit 1 }
    $g = Read-Graph $QuestId
    if (-not $g) { Write-Error "grafo $QuestId no existe"; exit 1 }
    if ($All) {
        $g.paused = $true
        Write-Graph $g
        Write-Host ("  [GRAPH] {0}: grafo pausado" -f $QuestId) -ForegroundColor Yellow
        exit 0
    }
    if (-not $Node) { Write-Error "pause requiere -Node o -All"; exit 1 }
    $target = @($g.nodes | Where-Object { $_.id -eq $Node })[0]
    if (-not $target) { Write-Error "nodo '$Node' no existe en $QuestId"; exit 1 }
    $target.status = "paused"
    $target.updated_at = (Get-Date).ToString("o")
    Write-Graph $g
    Write-Host ("  [GRAPH] {0}/{1} pausado (los nodos independientes siguen)" -f $QuestId, $Node) -ForegroundColor Yellow
    exit 0
}
