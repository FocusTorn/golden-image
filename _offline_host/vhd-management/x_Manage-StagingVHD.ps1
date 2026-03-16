<#
.SYNOPSIS
    Manages the attachment of the MasterInstallers VHDX to the Windows 11 Master VM.
.DESCRIPTION
    Provides three levels of attachment: Standard, Force (dismounts host), and Nuke (restarts VDS).
.EXAMPLE
    .\Manage-StagingVHD.ps1 -Mode force
    
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
        $volLabel = "Golden Imaging"
        $cfgPath = Join-Path $PSScriptRoot "config.json"
        if (Test-Path $cfgPath) {
            $cfg = Get-Content $cfgPath | ConvertFrom-Json
            if ($cfg.StagingVolumeLabel) { $volLabel = $cfg.StagingVolumeLabel }
        }
$res = Invoke-Command -VMName $VMName -ScriptBlock {
    param($label)
    # 1. Rescan to see the new hardware
    Write-Output rescan | diskpart
    Start-Sleep -Seconds 2
    # 2. Find by volume label first, else by size (non-C, Basic)
    $vol = Get-Volume -FileSystemLabel $label -ErrorAction SilentlyContinue
    $partition = $null
    if ($vol -and $vol.DriveLetter) {
        $partition = Get-Partition -DriveLetter $vol.DriveLetter -ErrorAction SilentlyContinue
    }
    if (-not $partition) {
        $partition = Get-Partition | Where-Object { $_.DriveLetter -ne 'C' -and $_.Type -eq 'Basic' } | Sort-Object Size -Descending | Select-Object -First 1
    }
    if ($partition) {
        # Remove any existing letter and force F:
        Get-Partition -DriveLetter $partition.DriveLetter | Remove-PartitionAccessPath -AccessPath "$($partition.DriveLetter):" -ErrorAction SilentlyContinue
        Set-Partition -NewDriveLetter F -InputObject $partition -ErrorAction SilentlyContinue
        Write-Output "F"
    } else {
        Write-Output "NONE"
    }
} -ArgumentList $volLabel -ErrorAction SilentlyContinue

# Update config.json with the resolved letter if possible
if ($res -and $res -match "^[a-zA-Z]$") {
    $cfg.GuestStagingDrive = $res
    $cfg | ConvertTo-Json | Set-Content $cfgPath
    Write-Host "[CONFIG] Updated GuestStagingDrive to $res in config.json" -ForegroundColor Cyan
} elseif ($res -eq "NONE") {
    Write-Warning "Could not find partition with label '$volLabel' or any secondary Basic partition."
}
        
        
        
    }
    catch {
        Write-Warning "Failed to attach: $($_.Exception.Message)"
        Write-Host "`n[TIP] If it says 'In Use', try running: .\Manage-VMDisk.ps1 force" -ForegroundColor Cyan
    }
}

# Trigger Guest Rescan
Invoke-Command -VMName $VMName -ScriptBlock { Update-HostStorageCache; Write-Output rescan | diskpart } -ErrorAction SilentlyContinue