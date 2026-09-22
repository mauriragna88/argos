# ============================================================
# ARNES - quest graph (Fase 4): gate de Bran + nodos con estados
#
# Hermetico: ArnesDir temporal, sin APIs ni OSMA.
# Verifica: justify (linear vs graph + razones persistidas), create,
# next (deps en pass), set con evidence, invalidacion downstream recursiva
# sin tocar nodos independientes, fork sin colision y pause por nodo/grafo.
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/quest-graph.tests.ps1
# Exit: 0 = PASS | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$PSExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
$Cli = Join-Path $Root 'cli\quest-graph.ps1'
$work = Join-Path $Root ('.quest-graph-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Invoke-Graph {
    param([string[]]$GraphArgs, [switch]$AllowFail)
    # EAP local en Continue: con Stop, el stderr de un proceso nativo capturado con 2>&1
    # se promueve a error terminante y rompe el helper antes de leer el exit code.
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $text = (& $PSExe -NoProfile -ExecutionPolicy Bypass -File $Cli @GraphArgs 2>&1 | Out-String)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousEap
    }
    if ($code -ne 0 -and -not $AllowFail) { throw "quest-graph fallo (exit $code): $($text.Trim())" }
    return @{ text = $text; code = $code }
}

# PS 5.1 no desenrolla arrays de ConvertFrom-Json en pipeline: asignar a variable antes de envolver.
function Parse-Json {
    param([string]$Text)
    return ($Text | ConvertFrom-Json)
}

function Get-Status {
    $r = Invoke-Graph @('-Action','status','-QuestId','Q-900','-Json','-ArnesDir',$work)
    return (Parse-Json $r.text)
}

function Get-NodeStatus {
    param([string]$Id)
    $g = Get-Status
    return (@($g.nodes | Where-Object { $_.id -eq $Id })[0]).status
}

try {
    # El JSON inline se rompe al pasar por la linea de comandos de Windows: usar TasksFile.
    $tasksFile = Join-Path $work 'tasks.json'
    $tasks = '[{"id":"n1","title":"schema","deps":[]},{"id":"n2","title":"api","deps":["n1"]},{"id":"n3","title":"ui","deps":["n2"]},{"id":"n9","title":"docs","deps":[]}]'
    [System.IO.File]::WriteAllText($tasksFile, $tasks, (New-Object System.Text.UTF8Encoding($false)))

    # 1. justify sin senales -> linear
    $lin = Invoke-Graph @('-Action','justify','-Prompt','arreglar un boton','-Json','-ArnesDir',$work)
    $linJson = Parse-Json $lin.text
    Assert-That ($linJson.verdict -eq 'linear') "sin senales -> linear (obtenido $($linJson.verdict))"
    Assert-That (@($linJson.reasons).Count -eq 0) 'linear sin razones'

    # 2. justify con senales -> graph + razones persistidas
    $gra = Invoke-Graph @('-Action','justify','-Prompt','migrar auth + api + ui','-Features','3','-Dependencies','4','-ParallelFrontBack','-Migrations','-Json','-ArnesDir',$work)
    $graJson = Parse-Json $gra.text
    Assert-That ($graJson.verdict -eq 'graph') "multi-dependencia -> graph (obtenido $($graJson.verdict))"
    Assert-That (@($graJson.reasons).Count -ge 2) "razones presentes ($(@($graJson.reasons).Count))"
    $justLog = Join-Path $work 'graph-justifications.jsonl'
    Assert-That (Test-Path -LiteralPath $justLog) 'justify persiste graph-justifications.jsonl'
    Assert-That (@(Get-Content -LiteralPath $justLog).Count -eq 2) 'dos justificaciones registradas'

    # 3. create: nodos con deps y estado pending
    $null = Invoke-Graph @('-Action','create','-QuestId','Q-900','-TasksFile',$tasksFile,'-ArnesDir',$work)
    $g = Get-Status
    Assert-That (@($g.nodes).Count -eq 4) "4 nodos creados (obtenidos $(@($g.nodes).Count))"
    Assert-That ((Get-NodeStatus 'n2') -eq 'pending') 'n2 pending'
    Assert-That ((@($g.nodes | Where-Object { $_.id -eq 'n2' })[0].deps) -contains 'n1') 'n2 depende de n1'

    # 4. next: sin deps -> [n1, n9]; n2/n3 no (deps sin pass)
    $next1 = Parse-Json (Invoke-Graph @('-Action','next','-QuestId','Q-900','-Json','-ArnesDir',$work)).text
    $ready1 = @($next1.ready)
    Assert-That ($ready1 -contains 'n1' -and $ready1 -contains 'n9') "READY inicial [n1,n9] (obtenido $($ready1 -join ','))"
    Assert-That (-not ($ready1 -contains 'n2')) 'n2 no READY antes de n1'

    # 5. set n1 -> pass + evidence
    $null = Invoke-Graph @('-Action','set','-QuestId','Q-900','-Node','n1','-Status','pass','-Evidence','typecheck+migracion ok','-ArnesDir',$work)
    $g = Get-Status
    $n1 = @($g.nodes | Where-Object { $_.id -eq 'n1' })[0]
    Assert-That ($n1.status -eq 'pass') 'n1 pass'
    Assert-That ($n1.evidence -eq 'typecheck+migracion ok') 'evidence persistida por nodo'

    # 6. next tras pass: n2 ahora READY
    $next2 = Parse-Json (Invoke-Graph @('-Action','next','-QuestId','Q-900','-Json','-ArnesDir',$work)).text
    $ready2 = @($next2.ready)
    Assert-That ($ready2 -contains 'n2') "n2 READY tras n1 pass (obtenido $($ready2 -join ','))"

    # 7. invalidate n1: n1+n2+n3 a pending; n9 intacto
    $inv = Parse-Json (Invoke-Graph @('-Action','invalidate','-QuestId','Q-900','-Node','n1','-Json','-ArnesDir',$work)).text
    $affected = @($inv.invalidated)
    Assert-That ($affected.Count -eq 3) "invalidacion propaga a 3 nodos (obtenidos $($affected.Count))"
    Assert-That ($affected -contains 'n3') 'downstream indirecto (n3) invalidado'
    Assert-That ((Get-NodeStatus 'n1') -eq 'pending' -and (Get-NodeStatus 'n2') -eq 'pending' -and (Get-NodeStatus 'n3') -eq 'pending') 'cadena completa a pending'
    $g = Get-Status
    $n9 = @($g.nodes | Where-Object { $_.id -eq 'n9' })[0]
    Assert-That ($n9.evidence -eq '') 'nodo independiente (n9) intacto'

    # 8. fork n2: variante sin colision + duplicado rechazado
    $null = Invoke-Graph @('-Action','fork','-QuestId','Q-900','-Node','n2','-Variant','alt','-ArnesDir',$work)
    $g = Get-Status
    $alt = @($g.nodes | Where-Object { $_.id -eq 'n2-alt' })[0]
    Assert-That ($null -ne $alt) 'fork crea n2-alt'
    Assert-That ((@($alt.deps) -contains 'n1')) 'variante conserva deps del original'
    $dup = Invoke-Graph @('-Action','fork','-QuestId','Q-900','-Node','n2','-Variant','alt','-ArnesDir',$work) -AllowFail
    Assert-That ($dup.code -eq 1) "fork duplicado -> exit 1 (obtenido $($dup.code))"

    # 9. pause por nodo y grafo
    $null = Invoke-Graph @('-Action','pause','-QuestId','Q-900','-Node','n2','-ArnesDir',$work)
    Assert-That ((Get-NodeStatus 'n2') -eq 'paused') 'n2 pausado'
    $next3 = Parse-Json (Invoke-Graph @('-Action','next','-QuestId','Q-900','-Json','-ArnesDir',$work)).text
    $ready3 = @($next3.ready)
    Assert-That (-not ($ready3 -contains 'n2')) 'nodo pausado no es READY'
    Assert-That ($ready3 -contains 'n1' -and $ready3 -contains 'n9') 'nodos independientes siguen READY con n2 pausado'
    $null = Invoke-Graph @('-Action','pause','-QuestId','Q-900','-All','-ArnesDir',$work)
    $next4 = Parse-Json (Invoke-Graph @('-Action','next','-QuestId','Q-900','-Json','-ArnesDir',$work)).text
    Assert-That ($next4.paused -eq $true -and @($next4.ready).Count -eq 0) 'grafo pausado -> sin READY'

    Write-Output 'PASS quest-graph: gate de Bran, next por deps, evidence, invalidacion downstream, fork y pause'
    exit 0
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
