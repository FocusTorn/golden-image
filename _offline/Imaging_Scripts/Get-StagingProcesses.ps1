# Run INSIDE the VM to find processes that may be holding the staging drive open.
# Use when sync fails with "VHD is locked" - a process in the VM might have files open.
param([string]$Drive = "")

# Auto-detect drive when not specified: 1) Label "Golden Imaging" 2) Fallback: Z..A reverse search
if (-not $Drive) {
    $StagingVolume = Get-Volume | Where-Object { $_.FileSystemLabel -eq "Golden Imaging" -and $_.DriveLetter -ne $null } | Select-Object -First 1
    if ($StagingVolume) { $Drive = $StagingVolume.DriveLetter }
    if (-not $Drive) {
        foreach ($d in [char[]](90..65)) {
            if ((Test-Path "${d}:\installers") -or (Test-Path "${d}:\_offline")) { $Drive = $d; break }
        }
    }
    if (-not $Drive) {
        Write-Host "[ERROR] Staging drive not found (label 'Golden Imaging' or drive with installers/_offline). Use -Drive X to specify." -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n=== GUEST: Processes using $($Drive):\ ===" -ForegroundColor Cyan
Write-Host ""

$procs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -and (
        $_.Path.StartsWith("${Drive}:\", [StringComparison]::OrdinalIgnoreCase) -or
        $_.Path -like "*_offline*" -or
        $_.Path -like "*\installers\*"
    )
}
if ($procs) {
    $procs | Format-Table Name, Id, Path -AutoSize
} else {
    Write-Host "No processes found with path under ${Drive}:\" -ForegroundColor Gray
}

Write-Host "Common lock sources:" -ForegroundColor Yellow
Write-Host "  - Explorer with $($Drive):\ open; Chrome/VS Code with project folder" -ForegroundColor Gray
Write-Host "  - PowerShell/pwsh in $($Drive):\_offline; msiexec (installers)" -ForegroundColor Gray
Write-Host "  - SearchIndexer indexing the drive" -ForegroundColor Gray
Write-Host ""
