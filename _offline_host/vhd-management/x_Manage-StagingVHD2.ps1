<#
.SYNOPSIS
    Manages the attachment of the MasterInstallers VHDX to the Windows 11 Master VM.
.DESCRIPTION
    Provides three levels of attachment: Standard, Force (dismounts host), and Nuke (restarts VDS).
.EXAMPLE
    .\Manage-VMDisk.ps1 -Mode force
#>
Param(
    [ValidateSet("standard", "force", "nuke")]
    [string]$Mode = "standard",
    
    [Alias("h","?")]
    [Switch]$Help,

    [string]$VMName = "Windows 11 Master",
    [string]$VhdPath = "N:\VHD\MasterInstallers.vhdx"
)

# --- HELP MENU ---
if ($Help) {
    Write-Host "`n--- VM DISK MANAGER HELP ---" -ForegroundColor Cyan
    Write-Host "Usage:" -ForegroundColor Gray
    Write-Host "  .\Manage-VMDisk.ps1 [[-Mode] <mode>]`n"
    
    $helpTable = @(
        @{Mode="standard"; Desc="Default. Attempts to attach VHD. Fails if Host has a lock."},
        @{Mode="force"   ; Desc="Breaks Host handles, dismounts VHD from Host, then attaches."},
        @{Mode="nuke"    ; Desc="Restarts the Virtual Disk Service (VDS). Use if file is 'hard' locked."}
    )
    
    foreach ($row in $helpTable) {
        Write-Host ("  {0,-10} : {1}" -f $row.Mode, $row.Desc) -ForegroundColor Yellow
    }
    
    Write-Host "`nExample:" -ForegroundColor Gray
    Write-Host "  .\Manage-VMDisk.ps1 force" -ForegroundColor White
    exit
}

Write-Host "--- VM DISK MANAGER: Mode [$($Mode.ToUpper())] ---" -ForegroundColor Cyan

# --- ESCALATION LOGIC ---
if ($Mode -eq "force") {
    Write-Host "[!] Escalating: Forcing Host Dismount..." -ForegroundColor Yellow
    Get-Disk | Where-Object { $_.FriendlyName -like "*Virtual*" } | Set-Disk -IsOffline $true -ErrorAction SilentlyContinue
    Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}
elseif ($Mode -eq "nuke") {
    Write-Host "[!!!] NUCLEAR OPTION: Restarting Virtual Disk Service..." -ForegroundColor Red
    Restart-Service -Name "vds" -Force
    Start-Sleep -Seconds 3
}

# --- ATTACHMENT LOGIC ---
Write-Host "[*] Attempting to attach $VhdPath to $VMName..." -ForegroundColor Gray

$existing = Get-VMHardDiskDrive -VMName $VMName | Where-Object { $_.Path -eq $VhdPath }

if ($existing) {
    Write-Host "[OK] Drive is already attached to the VM." -ForegroundColor Green
} else {
    try {
        Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -Path $VhdPath -ErrorAction Stop
        Write-Host "[SUCCESS] VHD attached to VM." -ForegroundColor Green
        
        
        
        # Inside the Attach Logic, add a Step 7 (The Guest Handshake)
Invoke-Command -VMName $VMName -ScriptBlock {
    # 1. Rescan to see the new hardware
    Write-Output rescan | diskpart
    
    # 2. Find the disk by its label or unique size
    # We look for the partition on the VHDX and force it to F: (Staging drive)
    $partition = Get-Partition | Where-Object { $_.DriveLetter -ne 'C' -and $_.Type -eq 'Basic' } | Sort-Object Size -Descending | Select-Object -First 1
    
    if ($partition) {
        # Remove any existing letter and force F:
        Get-Partition -DriveLetter $partition.DriveLetter | Remove-PartitionAccessPath -AccessPath "$($partition.DriveLetter):" -ErrorAction SilentlyContinue
        Set-Partition -NewDriveLetter F -InputObject $partition -ErrorAction SilentlyContinue
        Write-Host "Successfully mounted as F:" -ForegroundColor Green
    }
} -ErrorAction SilentlyContinue
        
        
        
    }
    catch {
        Write-Warning "Failed to attach: $($_.Exception.Message)"
        Write-Host "`n[TIP] If it says 'In Use', try running: .\Manage-VMDisk.ps1 force" -ForegroundColor Cyan
    }
}

# Trigger Guest Rescan
Invoke-Command -VMName $VMName -ScriptBlock { Update-HostStorageCache; Write-Output rescan | diskpart } -ErrorAction SilentlyContinue