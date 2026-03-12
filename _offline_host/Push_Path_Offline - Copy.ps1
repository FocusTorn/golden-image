# Push_Path_Offline.ps1
# Usage: .\Push_Path_Offline.ps1 -Path "P:\Projects\golden-image\installers\file.msi"
# Replaces "P:\Projects\golden-image" with "D:" in the destination.

Param(
    [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
    [string]$Path
)

$vmName = "Windows 11 Master"
$projectRoot = "P:\Projects\golden-image"

# 1. Clean and Resolve Path (Handles quotes, relative paths, and full absolute paths)
$cleanPath = $Path.Trim().Trim('"')
if (Test-Path $cleanPath) {
    $fullSourcePath = (Get-Item $cleanPath).FullName
} else {
    throw "Source path not found: $cleanPath"
}

# 2. Transform the path: Replace project root with D:
$escapedRoot = [regex]::Escape($projectRoot)
$destPath = $fullSourcePath -replace $escapedRoot, "D:"

# Safety check: if the path didn't contain the project root, it won't map correctly to D:
if ($destPath -eq $fullSourcePath) {
    Write-Host "[WARN] Source path is outside project root ($projectRoot). Pushing to D:\Backup..." -ForegroundColor Yellow
    $destPath = Join-Path "D:\Backup" (Split-Path $fullSourcePath -Leaf)
}

Write-Host "--- SURGICAL PUSH (TO D:) ---" -ForegroundColor Cyan
Write-Host "[*] Source: $fullSourcePath" -ForegroundColor Gray
Write-Host "[*] Destination: $destPath" -ForegroundColor Gray







# 3. Push using Guest Services (No shutdown required)
if (Test-Path $fullSourcePath -PathType Container) {
    # It's a folder: Push all files inside
    Get-ChildItem -Path $fullSourcePath -File | ForEach-Object {
        $fileDest = Join-Path $destPath $_.Name
        Copy-VMFile -Name $vmName -SourcePath $_.FullName -DestinationPath $fileDest -FileSource Host -Force
    }
} else {
    # It's a file: Push directly
    Copy-VMFile -Name $vmName -SourcePath $fullSourcePath -DestinationPath $destPath -FileSource Host -Force
}

Write-Host "[SUCCESS] Path pushed straight to VM." -ForegroundColor Green
