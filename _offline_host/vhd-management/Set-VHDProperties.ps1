
$vhdPath = "N:\VHD\MasterInstallers.vhdx"
$fileSystemLabel = "Staging"




# 1. Mount it briefly to the Host
$mounter = Mount-VHD -Path $vhdPath -Passthru
Start-Sleep -Seconds 2

# 2. Find the drive letter it just got
$driveLetter = ($mounter | Get-Disk | Get-Partition | Get-Volume).DriveLetter | Select-Object -First 1

# 3. Apply the "Staging" label
if ($driveLetter) {
    Set-Volume -DriveLetter $driveLetter -NewFileSystemLabel $fileSystemLabel
    Write-Host "[SUCCESS] VHD is now labeled 'Staging' on Drive $driveLetter`:" -ForegroundColor Green
}

# 4. Clean up
Dismount-VHD -Path $vhdPath