# artifact-integrity.ps1 - Sellos SHA-256 para artefactos del harness

function Write-ArtifactHash([Parameter(Mandatory)][string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Artifact not found: $Path" }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash | Set-Content -LiteralPath "$Path.sha256" -Encoding ASCII
    if (-not $env:ARNES_ARTIFACT_HMAC_KEY) { throw "ARNES_ARTIFACT_HMAC_KEY is required to sign artifacts." }
    $key = [Text.Encoding]::UTF8.GetBytes($env:ARNES_ARTIFACT_HMAC_KEY)
    $bytes = [IO.File]::ReadAllBytes($Path)
    $hmac = New-Object Security.Cryptography.HMACSHA256(,$key)
    ([BitConverter]::ToString($hmac.ComputeHash($bytes)) -replace '-', '') | Set-Content -LiteralPath "$Path.sig" -Encoding ASCII
}

function Test-ArtifactHash([Parameter(Mandatory)][string]$Path) {
    $seal = "$Path.sha256"
    if (-not (Test-Path -LiteralPath $seal -PathType Leaf)) { return $false }
    $expected = (Get-Content -LiteralPath $seal -Raw -Encoding ASCII).Trim()
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($expected -ne $actual -or -not $env:ARNES_ARTIFACT_HMAC_KEY -or -not (Test-Path -LiteralPath "$Path.sig" -PathType Leaf)) { return $false }
    $key = [Text.Encoding]::UTF8.GetBytes($env:ARNES_ARTIFACT_HMAC_KEY)
    $bytes = [IO.File]::ReadAllBytes($Path)
    $hmac = New-Object Security.Cryptography.HMACSHA256(,$key)
    $expectedSig = (Get-Content -LiteralPath "$Path.sig" -Raw -Encoding ASCII).Trim()
    $actualSig = ([BitConverter]::ToString($hmac.ComputeHash($bytes)) -replace '-', '')
    return $expectedSig -eq $actualSig
}
