# ============================================================
# ARNES - verificacion del grafo de relaciones (arnes-graph)
#
# Prueba el CLI del grafo real (osma-graph.ps1, resuelto via
# Get-OsmaGraphCli) contra un arnes.db SQLite real en un
# proyecto temporal: add / query / neighbors / path / stats.
#
# Si OSMA no esta instalado (CI), el test hace SKIP limpio (exit 0)
# con aviso, en vez de fallar.
#
# Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File tests/arnes-graph.tests.ps1
# Exit: 0 = PASS (o SKIP) | 1 = FAIL
# ============================================================
$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
. (Join-Path $Root 'cli\osma-resolve.ps1')

$graphCli = Get-OsmaGraphCli
$memCli = Get-OsmaMemoryCli

if (-not $graphCli -or -not $memCli -or -not (Test-OsmaInstalled)) {
    Write-Host 'SKIP  OSMA no instalado - se omite el test del grafo (instala OSMA para activarlo).' -ForegroundColor Yellow
    exit 0
}

$fail = $false
function Assert-Match {
    param([string]$Name, [string]$Pattern, [string]$Actual)
    if ($Actual -notmatch $Pattern) {
        $script:fail = $true
        Write-Host ("FAIL  {0}: output no contiene '{1}'" -f $Name, $Pattern) -ForegroundColor Red
        Write-Host ("      --- output ---") -ForegroundColor DarkGray
        $Actual -split "`n" | ForEach-Object { Write-Host ("      {0}" -f $_) -ForegroundColor DarkGray }
    } else {
        Write-Host ("PASS  {0}" -f $Name) -ForegroundColor Green
    }
}

# --- Fixture: proyecto temporal con .arnes/ ---
$proj = Join-Path ([System.IO.Path]::GetTempPath()) ("arnes-graph-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $proj '.arnes') -Force | Out-Null

try {
    Push-Location $proj
    try {
        # 1. Inicializar el cerebro (crea arnes.db con agentes y FTS5)
        $initOut = & $memCli init 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "init fallo: $initOut" }

        # 2. Registrar edges reales
        $a1 = & $graphCli add -NodeA 'Login.tsx' -NodeB 'zod' -Relation 'uses' -Agent 'vivi' *>&1 | Out-String
        Assert-Match 'add edge 1 (Login.tsx -> zod)' 'Edge registrado' $a1
        $a2 = & $graphCli add -NodeA 'Login.tsx' -NodeB 'auth' -Relation 'depends-on' -Agent 'ansem' *>&1 | Out-String
        Assert-Match 'add edge 2 (Login.tsx -> auth)' 'Edge registrado' $a2
        $a3 = & $graphCli add -NodeA 'auth' -NodeB 'supabase' -Relation 'uses' -Agent 'ansem' *>&1 | Out-String
        Assert-Match 'add edge 3 (auth -> supabase)' 'Edge registrado' $a3

        # 3. query: relaciones de un nodo
        $q = & $graphCli query -Node 'Login.tsx' *>&1 | Out-String
        Assert-Match 'query Login.tsx' "Relaciones de 'Login.tsx': 2" $q
        Assert-Match 'query muestra edge a zod' 'zod' $q

        # 4. neighbors con profundidad
        $n = & $graphCli neighbors -Node 'Login.tsx' -Depth 2 *>&1 | Out-String
        Assert-Match 'neighbors depth 2' 'Vecinos' $n
        Assert-Match 'neighbors alcanza supabase' 'supabase' $n

        # 5. path: existe camino Login.tsx -> supabase
        $p = & $graphCli path -Start 'Login.tsx' -End 'supabase' *>&1 | Out-String
        Assert-Match 'path Login.tsx -> supabase' 'Camino' $p

        # 6. stats: el grafo registra 3 edges
        $s = & $graphCli stats *>&1 | Out-String
        Assert-Match 'stats ARNES GRAPH' 'ARNES GRAPH - STATS' $s
        Assert-Match 'stats 3 edges' 'Edges:\s+3' $s

        # 7. El db es SQLite real (header 'SQLite format 3')
        $dbFile = Join-Path $proj '.arnes\arnes.db'
        if (Test-Path $dbFile) {
            $fs = [System.IO.File]::OpenRead($dbFile)
            try {
                $head = New-Object byte[] 16
                $null = $fs.Read($head, 0, 16)
                $header = [System.Text.Encoding]::ASCII.GetString($head)
                Assert-Match 'arnes.db es SQLite real' 'SQLite format 3' $header
            } finally { $fs.Dispose() }
        } else {
            $script:fail = $true
            Write-Host 'FAIL  arnes.db no fue creado por init' -ForegroundColor Red
        }
    } finally {
        Pop-Location
    }
} finally {
    Remove-Item -LiteralPath $proj -Recurse -Force -ErrorAction SilentlyContinue
}

if ($fail) {
    Write-Host "`nRESULTADO: FAIL - grafo de relaciones." -ForegroundColor Red
    exit 1
}
Write-Host "`nRESULTADO: PASS - grafo de relaciones contra SQLite real." -ForegroundColor Green
exit 0
