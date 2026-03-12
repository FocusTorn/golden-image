# Push_Fast_Offline.ps1
# Run this on Host (Admin PowerShell) to push the _offline folder INSTANTLY to D:
# Uses Guest Services (no VM shutdown required).

Write-Host "--- FAST PUSH: _OFFLINE FOLDER (TO D:) ---" -ForegroundColor Cyan

$vmName = "Windows 11 Master"
$projectRoot = "P:\Projects\golden-image"

$offlinePath = Join-Path $projectRoot "_offline"
Get-ChildItem -Path $offlinePath -File | ForEach-Object {
    $dest = "D:\_offline\$($_.Name)"
    # Note: Copy-VMFile requires Guest Services enabled in VM Settings
    Copy-VMFile -Name $vmName -SourcePath $_.FullName -DestinationPath $dest -FileSource Host -Force
}

Write-Host "[SUCCESS] _offline folder synced to D:\_offline" -ForegroundColor Green



