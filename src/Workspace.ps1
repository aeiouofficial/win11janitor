# Prevent project-created files from following an NTFS junction/symlink outside D:.
function Assert-JanitorWorkspacePath {
    param([string]$Path, [string]$AllowedRoot)
    $full=[IO.Path]::GetFullPath($Path)
    $base=[IO.Path]::GetFullPath($AllowedRoot).TrimEnd('\')
    if (-not ($full -ieq $base -or
        $full.StartsWith($base + '\',[StringComparison]::OrdinalIgnoreCase))) {
        throw 'Project file path escapes the approved workspace.'
    }
    $walk=$full
    while ($walk -and $walk.Length -ge 3) {
        if (Test-Path -LiteralPath $walk) {
            $item=Get-Item -LiteralPath $walk -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse-point path refused: $walk"
            }
        }
        $parent=[IO.Path]::GetDirectoryName($walk.TrimEnd('\'))
        if (-not $parent -or $parent -ieq $walk) { break }
        $walk=$parent
    }
    return $full
}
