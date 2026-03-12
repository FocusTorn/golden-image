# --- CONFIGURATION ---
$vhdPath = "N:\VHD\MasterInstallers.vhdx"
$sourceFolders = @(
    "P:\Projects\golden-image\_offline",
    "P:\Projects\golden-image\installers"
)

# 1. Create the VHDX (10GB Max, Dynamically Expanding)
Write-Host "[*] Creating 10GB Dynamically Expanding VHDX..." -ForegroundColor Cyan
$vhd = New-VHD -Path $vhdPath -SizeBytes 10GB -Dynamic -Confirm:$false

# 2. Mount and Initialize
Write-Host "[*] Mounting and Formatting..." -ForegroundColor Gray
$disk = Mount-VHD -Path $vhdPath -Passthru | Initialize-Disk -PartitionStyle GPT -Passthru
$partition = $disk | New-Partition -AssignDriveLetter -UseMaximumSize
$driveLetter = $partition.DriveLetter
Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -NewFileSystemLabel "Installers" -Confirm:$false

# 3. Sync Folders (Robocopy is best for preserving MSVC structures)
Write-Host "[*] Syncing files to VHDX (Drive $driveLetter`:)..." -ForegroundColor Yellow
foreach ($folder in $sourceFolders) {
    $dest = Join-Path "$($driveLetter):\" (Split-Path $folder -Leaf)
    # /E = subdirectories, /MT = multi-threaded (fast), /R:0 = no retries on busy files
    robocopy $folder $dest /E /MT /R:0 /W:0
}

# 4. Detach from Host (Crucial: VM cannot boot it if Host still has it)
Write-Host "[*] Detaching from Host... Ready for VM." -ForegroundColor Green
Dismount-VHD -Path $vhdPath