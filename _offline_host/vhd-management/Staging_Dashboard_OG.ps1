# Dashboard: ROG Strix VHD Infrastructure Manager
# ---------------------------------------------------------------------------

#> === BLOCK 1: CONFIGURATION & PERSISTENCE ===
$ConfigPath = Join-Path $PSScriptRoot "config.json"

function Get-Config {
    if (Test-Path $ConfigPath) { return Get-Content $ConfigPath | ConvertFrom-Json }
    $default = @{ VhdPath = "N:\VHD\MasterInstallers.vhdx"; VMName = "Windows 11 Master" }
    $default | ConvertTo-Json | Set-Content $ConfigPath
    return $default
}

function Save-Config($Cfg) { $Cfg | ConvertTo-Json | Set-Content $ConfigPath }
#< === END BLOCK 1 ===

#> === BLOCK 2: SWOOP FUNCTIONS (30, 31, 40) ===
function Invoke-MasterSwoop {
    Param([string]$Source, [string]$VhdPath, [string]$VMName, [switch]$NoPause)
    try {
        Write-Host ">>> STARTING MASTER SWOOP: $(Split-Path $Source -Leaf)" -ForegroundColor Cyan
        
        # MANUAL CHECK: Ensure not at VM
        if (Get-VMHardDiskDrive -VMName $VMName | Where-Object Path -eq $VhdPath) {
            throw "VHD is still attached to VM. Run Action 22 first."
        }

        # 1. Mount to Host
        $vhd = Mount-VHD -Path $VhdPath -Passthru
        Start-Sleep -Seconds 1
        $driveLetter = (Get-Partition -DiskNumber $vhd.DiskNumber | Get-Volume | Where-Object DriveLetter).DriveLetter
        if (-not $driveLetter) { throw "No Host Drive Letter assigned." }

        # 2. Sync
        $destination = Join-Path "$($driveLetter):" (Split-Path $Source -Leaf)
        Write-Host "[Syncing] $Source -> $destination" -ForegroundColor White
        robocopy $Source $destination /MIR /MT:16 /R:2 /W:5 /NP /NDL /FFT
        
        # 3. Hand back to VM
        Dismount-VHD -Path $VhdPath
        Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -Path $VhdPath
        Write-Host "[SUCCESS] Sync Complete." -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Swoop Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    if (-not $NoPause) { Write-Host "`nPress any key..."; $null = [System.Console]::ReadKey($true) }
}

function Invoke-ReverseSwoop {
    Param([string]$TargetHostDir, [string]$VhdPath, [string]$VMName, [switch]$NoPause)
    
    $VMUser = "Administrator"; $VMPass = New-Object System.Security.SecureString 
    $Creds = New-Object System.Management.Automation.PSCredential($VMUser, $VMPass)

    try {
        Write-Host ">>> ACTION 40: PULL RETURN" -ForegroundColor Cyan
        
        # 1. Harvest inside VM
        Invoke-Command -VMName $VMName -Credential $Creds -ScriptBlock {
            $VhdReturn = "F:\return"; $TempPath = $env:TEMP
            Get-Process -Name "vs_setup","setup","vs_installer" -ErrorAction SilentlyContinue | Stop-Process -Force
            if (-not (Test-Path $VhdReturn)) { New-Item $VhdReturn -ItemType Directory | Out-Null }
            Get-ChildItem -Path $TempPath -Filter "dd_*.log" | Move-Item -Destination $VhdReturn -Force -ErrorAction SilentlyContinue
        }

        # 2. Release VM, Mount Host
        Get-VMHardDiskDrive -VMName $VMName | Where-Object Path -eq $VhdPath | Remove-VMHardDiskDrive
        $vhd = Mount-VHD -Path $VhdPath -Passthru
        Start-Sleep -Seconds 1
        $driveLetter = (Get-Partition -DiskNumber $vhd.DiskNumber | Get-Volume | Where-Object DriveLetter).DriveLetter

        # 3. Pull to Host
        if ($driveLetter) {
            $vhdReturnSource = "$($driveLetter):\return"
            robocopy $vhdReturnSource $TargetHostDir /MIR /MT:16 /R:2 /W:5 /NP /NDL
        }
        
        Dismount-VHD -Path $VhdPath
        Write-Host "[SUCCESS] Logs pulled to Host." -ForegroundColor Green
    } catch { Write-Host "[ERROR] Action 40 Failed: $($_.Exception.Message)" -ForegroundColor Red }
    if (-not $NoPause) { Write-Host "`nPress any key..."; $null = [System.Console]::ReadKey($true) }
}
#< === END BLOCK 2 ===

#> === BLOCK 3: UI & MENU ===
function Show-VhdHeader {
    $Cfg = Get-Config
    Clear-Host
    $bar = "================================================================"
    Write-Host $bar -ForegroundColor Cyan
    Write-Host "                VHDX INFRASTRUCTURE MANAGEMENT                  " -ForegroundColor Cyan
    
    $vmObj = Get-VM -Name $Cfg.VMName -ErrorAction SilentlyContinue
    $vhdExists = Test-Path $Cfg.VhdPath
    $isAtVM = if ($vmObj) { Get-VMHardDiskDrive -VMName $Cfg.VMName | Where-Object Path -eq $Cfg.VhdPath }
    
    $hostLetter = ""
    if ($vhdExists) {
        $vhdInfo = Get-VHD -Path $Cfg.VhdPath -ErrorAction SilentlyContinue
        if ($vhdInfo.Attached -and $null -ne $vhdInfo.DiskNumber) { 
            $hostLetter = (Get-Partition -DiskNumber $vhdInfo.DiskNumber | Get-Volume | Where-Object DriveLetter).DriveLetter
        }
    }

    $vmStatusColor    = if ($vmObj.State -eq 'Running') { "Green" } else { "Red" }
    $hostStagingColor = if ($hostLetter) { "Green" } else { "Gray" }
    $vmStagingColor   = if ($isAtVM) { "Green" } else { "Gray" }

    Write-Host "STATUS: [VM] " -NoNewline; Write-Host "($($vmObj.State)) " -NoNewline -ForegroundColor $vmStatusColor
    Write-Host "[Host Staging] " -NoNewline -ForegroundColor $hostStagingColor
    Write-Host "[VM Staging]" -ForegroundColor $vmStagingColor
    Write-Host "VHD: $($Cfg.VhdPath)" -ForegroundColor White
    Write-Host $bar -ForegroundColor Cyan
}

:MainLoop while ($true) {
    Show-VhdHeader
    $Cfg = Get-Config
    $localProjectRoot = "P:\Projects\golden-image"
    
    Write-Host "SYNC OPERATIONS:" -ForegroundColor Cyan
    Write-Host "  30. Sync ALL (Swoop)"
    Write-Host "  31. Sync _offline"
    Write-Host "  40. PULL Logs (Reverse Swoop)"
    Write-Host ""
    Write-Host "HOST CONTROL:" -ForegroundColor Cyan
    Write-Host "  11. Mount to Host"
    Write-Host "  12. Dismount from Host"
    Write-Host ""
    Write-Host "VM CONTROL:" -ForegroundColor Cyan
    Write-Host "  21. Mount to VM"
    Write-Host "  22. Dismount from VM"
    Write-Host ""
    Write-Host "[X] Exit" -ForegroundColor White
    
    $choice = Read-Host "Select Action"
    switch ($choice) {
        "11" { Mount-VHD $Cfg.VhdPath; Start-Sleep 1 }
        "12" { Dismount-VHD $Cfg.VhdPath; Start-Sleep 1 }
        "21" { Add-VMHardDiskDrive -VMName $Cfg.VMName -ControllerType SCSI -Path $Cfg.VhdPath; Start-Sleep 1 }
        "22" { Get-VMHardDiskDrive -VMName $Cfg.VMName | Where-Object Path -eq $Cfg.VhdPath | Remove-VMHardDiskDrive; Start-Sleep 1 }
        "30" { Invoke-MasterSwoop "$localProjectRoot\_offline" $Cfg.VhdPath $Cfg.VMName -NoPause; Invoke-MasterSwoop "$localProjectRoot\installers" $Cfg.VhdPath $Cfg.VMName }
        "31" { Invoke-MasterSwoop "$localProjectRoot\_offline" $Cfg.VhdPath $Cfg.VMName }
        "40" { Invoke-ReverseSwoop (Join-Path $localProjectRoot "return") $Cfg.VhdPath $Cfg.VMName }
        "x"  { break MainLoop }
    }
}
#< === END BLOCK 3 ===