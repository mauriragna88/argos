# fix-encoding-v2.ps1 - Fast single-pass fix UTF-8 mojibake
$files = Get-ChildItem -Path "core\classes\*.agent.md", "core\auditors\*.agent.md", "core\atlas-player.agent.md" | ForEach-Object { $_.FullName }

$patterns = @(
    ,@( [byte]0xE2,[byte]0x80,[byte]0x94, [char]0x2014 )
    ,@( [byte]0xE2,[byte]0x80,[byte]0x99, [char]0x2019 )
    ,@( [byte]0xE2,[byte]0x80,[byte]0x9C, [char]0x201C )
    ,@( [byte]0xE2,[byte]0x80,[byte]0x9D, [char]0x201D )
    ,@( [byte]0xC3,[byte]0xA1, [char]0x00E1 )
    ,@( [byte]0xC3,[byte]0xA9, [char]0x00E9 )
    ,@( [byte]0xC3,[byte]0xAD, [char]0x00ED )
    ,@( [byte]0xC3,[byte]0xB3, [char]0x00F3 )
    ,@( [byte]0xC3,[byte]0xBA, [char]0x00FA )
    ,@( [byte]0xC3,[byte]0xB1, [char]0x00F1 )
    ,@( [byte]0xC3,[byte]0x89, [char]0x00C9 )
    ,@( [byte]0xC3,[byte]0x81, [char]0x00C1 )
    ,@( [byte]0xE2,[byte]0x86,[byte]0x92, [char]0x2192 )
    ,@( [byte]0xE2,[byte]0x80,[byte]0xA6, [char]0x2026 )
)

$totalFixes = 0
foreach ($f in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($f)
    $newBytes = New-Object 'System.Collections.Generic.List[byte]'
    $fileFixes = 0
    $i = 0
    while ($i -lt $bytes.Length) {
        $matched = $false
        foreach ($p in $patterns) {
            $seq = $p[0..($p.Count - 2)]
            $replacement = $p[$p.Count - 1]
            $seqLen = $seq.Count
            if (($i + $seqLen) -le $bytes.Length) {
                $isMatch = $true
                for ($j = 0; $j -lt $seqLen; $j++) {
                    if ($bytes[$i + $j] -ne $seq[$j]) { $isMatch = $false; break }
                }
                if ($isMatch) {
                    $charBytes = [System.Text.Encoding]::UTF8.GetBytes($replacement)
                    foreach ($b in $charBytes) { $newBytes.Add($b) }
                    $i += $seqLen
                    $fileFixes++
                    $matched = $true
                    break
                }
            }
        }
        if (-not $matched) {
            $newBytes.Add($bytes[$i])
            $i++
        }
    }
    if ($fileFixes -gt 0) {
        [System.IO.File]::WriteAllBytes($f, $newBytes.ToArray())
        Write-Host "  [FIXED] $f ($fileFixes)"
        $totalFixes += $fileFixes
    }
}
Write-Host "Total: $totalFixes"
