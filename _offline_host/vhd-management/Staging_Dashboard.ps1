# Dashboard: ROG Strix VHD Infrastructure Manager
# ---------------------------------------------------------------------------

#> === BLOCK 1: CONFIGURATION & PERSISTENCE ===
$ConfigPath = Join-Path $PSScriptRoot "config.json"

function Get-Config {
    $default = @{ 
        VhdPath = "N:\VHD\MasterInstallers.vhdx"; 
        VMName  = "Windows 11 Master";
        VMUser  = "Administrator"
    }
    if (Test-Path $ConfigPath) { 
        $current = Get-Content $ConfigPath | ConvertFrom-Json 
        # Merge properties
        foreach ($key in $default.Keys) {
            if (-not $current.psobject.Properties[$key]) { $current | Add-Member -MemberType NoteProperty -Name $key -Value $default[$key] }
        }
        return $current
    }
    $default | ConvertTo-Json | Set-Content $ConfigPath
    return $default | ConvertTo-Json | ConvertFrom-Json # Return as object
}

function Save-Config($Cfg) { $Cfg | ConvertTo-Json | Set-Content $ConfigPath }

# Helper to get credentials (with fallback to prompt)
function Get-VMCreds {
    Param([string]$User)
    $pass = New-Object System.Security.SecureString
    return New-Object System.Management.Automation.PSCredential($User, $pass)
}

# Helper to mount VHD with retry logic (handles 0x80070020 file-in-use errors)
function Mount-VhdWithRetry {
    Param([string]$Path)
    $maxRetries = 5
    $retryCount = 0
    $vhd = $null

    while ($retryCount -lt $maxRetries) {
        try {
            $vhd = Mount-VHD -Path $Path -Passthru -ErrorAction Stop
            return $vhd
        } catch {
            $retryCount++
            if ($_.Exception.Message -like "*used by another process*") {
                Write-Host "    [!] VHD is locked. Retrying ($retryCount/$maxRetries)..." -ForegroundColor Yellow
                Start-Sleep -Seconds (2 * $retryCount)
            } else {
                throw $_
            }
        }
    }
    throw "Failed to mount VHD after $maxRetries attempts."
}

function Get-AttachedDiskNumber {
    Param([string]$VhdPath)
    $vhdInfo = Get-VHD -Path $VhdPath -ErrorAction SilentlyContinue
    if ($vhdInfo -and $vhdInfo.Attached -and $null -ne $vhdInfo.DiskNumber) {
        return $vhdInfo.DiskNumber
    }
    return $null
}

#< === END BLOCK 1 ===

#> === BLOCK 2: SMART RELEASE LOGIC (ACTION 0) ===
function Invoke-SmartRelease {
    Param([string]$VhdPath, [string]$VMName)
    Write-Host "[*] Action 0: Disconnecting all controllers..." -ForegroundColor DarkGray
    
    # 1. Release from VM
    $vmDrive = Get-VMHardDiskDrive -VMName $VMName -ErrorAction SilentlyContinue | Where-Object Path -eq $VhdPath
    if ($vmDrive) {
        Write-Host "    -> Releasing from VM: $VMName" -ForegroundColor Yellow
        $vmDrive | Remove-VMHardDiskDrive -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2 # Give Hyper-V time to release file handle
    }

    # 2. Release from Host (only when actually host-mounted; Attached is true for VM too)
    $vhdInfo = Get-VHD -Path $VhdPath -ErrorAction SilentlyContinue
    if ($vhdInfo.Attached -and $null -ne $vhdInfo.DiskNumber) {
        Write-Host "    -> Dismounting from Host" -ForegroundColor Yellow
        Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
}
#< === END BLOCK 2 ===

#> === BLOCK 3: STATE PERSISTENCE & SYNC FUNCTIONS ===
function Get-VhdState {
    Param([string]$VhdPath, [string]$VMName)
    $vmDrive = Get-VMHardDiskDrive -VMName $VMName -ErrorAction SilentlyContinue | Where-Object Path -eq $VhdPath
    $vhdInfo = Get-VHD -Path $VhdPath -ErrorAction SilentlyContinue
    return @{
        WasAtVM = $null -ne $vmDrive
        WasAtHost = $vhdInfo.Attached
    }
}

function Restore-VhdState {
    Param([string]$VhdPath, [string]$VMName, $State)
    # ALWAYS return to VM at the end of sync/pull operations (4, 5, 6)
    Write-Host "[*] Finalizing: Reconnecting VHD to VM: $VMName" -ForegroundColor DarkGray
    Invoke-SmartRelease -VhdPath $VhdPath -VMName $VMName
    
    $maxRetries = 3
    $count = 0
    while ($count -lt $maxRetries) {
        try {
            Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -Path $VhdPath -ErrorAction Stop
            return
        } catch {
            $count++
            Write-Host "    [!] VM drive attach failed. Retrying ($count/$maxRetries)..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
}

function Invoke-MasterSwoop {
    Param([string[]]$Sources, [string]$VhdPath, [string]$VMName, [switch]$NoPause)
    $State = Get-VhdState -VhdPath $VhdPath -VMName $VMName
    try {
        Write-Host ">>> SYNC OPERATION: $($Sources.Count) folders" -ForegroundColor Cyan
        
        # 1. Identify Disk Number
        $targetDiskNumber = Get-AttachedDiskNumber -VhdPath $VhdPath
        
        # 2. If not attached to Host or couldn't identify, force a mount
        if ($null -eq $targetDiskNumber) {
            Invoke-SmartRelease -VhdPath $VhdPath -VMName $VMName
            $vhd = Mount-VhdWithRetry -Path $VhdPath
            $targetDiskNumber = $vhd.DiskNumber
        }
        
        Start-Sleep -Seconds 1

        if ($null -eq $targetDiskNumber) { throw "Could not identify Disk Number for VHD." }

        $driveLetter = (Get-Partition -DiskNumber $targetDiskNumber | Get-Volume | Where-Object DriveLetter).DriveLetter
        if (-not $driveLetter) { throw "No Host Drive Letter assigned." }

        foreach ($Source in $Sources) {
            $destination = Join-Path "$($driveLetter):" (Split-Path $Source -Leaf)
            Write-Host "[Syncing] $Source -> $destination" -ForegroundColor Yellow
            robocopy $Source $destination /MIR /MT:16 /R:2 /W:5 /NP /NDL /FFT
        }
        
        Restore-VhdState -VhdPath $VhdPath -VMName $VMName -State $State
        Write-Host "[SUCCESS] Sync complete and returned to VM." -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Sync Failed: $($_.Exception.Message)" -ForegroundColor Red
        Restore-VhdState -VhdPath $VhdPath -VMName $VMName -State $State
    }
    if (-not $NoPause) { Write-Host "`nPress any key..."; $null = [System.Console]::ReadKey($true) }
}

function Invoke-ReverseSwoop {
    Param([string]$TargetHostDir, [string]$VhdPath, [string]$VMName, [switch]$NoPause)
    
    $Cfg = Get-Config
    $Creds = Get-VMCreds $Cfg.VMUser
    $State = Get-VhdState -VhdPath $VhdPath -VMName $VMName

    try {
        Write-Host ">>> ACTION 6: PULL RETURN" -ForegroundColor Cyan
        
        # 1. Remote Harvest
        # ... (harvest logic same as before) ...
        # 2. Identify Disk Number
        $targetDiskNumber = Get-AttachedDiskNumber -VhdPath $VhdPath

        # 3. If not at Host or couldn't identify, swap to Host
        if ($null -eq $targetDiskNumber) {
            Invoke-SmartRelease -VhdPath $VhdPath -VMName $VMName
            $vhd = Mount-VhdWithRetry -Path $VhdPath
            $targetDiskNumber = $vhd.DiskNumber
        }
        
        Start-Sleep -Seconds 1
        if ($null -eq $targetDiskNumber) { throw "Could not identify Disk Number for VHD." }

        $driveLetter = (Get-Partition -DiskNumber $targetDiskNumber | Get-Volume | Where-Object DriveLetter).DriveLetter

        if ($driveLetter) {
            $vhdReturnSource = "$($driveLetter):\return"
            Write-Host "[3/4] Pulling: $vhdReturnSource -> $TargetHostDir" -ForegroundColor Yellow
            robocopy $vhdReturnSource $TargetHostDir /MIR /MT:16 /R:2 /W:5 /NP /NDL
        }
        
        Restore-VhdState -VhdPath $VhdPath -VMName $VMName -State $State
        Write-Host "[4/4] Pull Complete and returned to VM." -ForegroundColor Green
        $Latest = Get-ChildItem $TargetHostDir -Filter "dd_bootstrapper*.log" | Sort-Object LastWriteTime -Desc | Select-Object -First 1
        if ($Latest) { Start-Process $Latest.FullName }

    } catch { 
        Write-Host "[ERROR] Action 6 Failed: $($_.Exception.Message)" -ForegroundColor Red 
        Restore-VhdState -VhdPath $VhdPath -VMName $VMName -State $State
    }
    if (-not $NoPause) { Write-Host "`nPress any key..."; $null = [System.Console]::ReadKey($true) }
}
#< === END BLOCK 3 ===

#> === BLOCK 4: UI & MENU ===
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
    $hostStagingColor = if ($hostLetter) { "Green" } else { "Red" }
    $vmStagingColor   = if ($isAtVM) { "Green" } else { "Red" }

    Write-Host "STATUS: [VM] " -NoNewline; Write-Host "($($vmObj.State)) " -NoNewline -ForegroundColor $vmStatusColor
    Write-Host "[Host Staging] " -NoNewline -ForegroundColor $hostStagingColor
    Write-Host "[VM Staging]" -ForegroundColor $vmStagingColor
    Write-Host "VHD: $($Cfg.VhdPath)" -NoNewline -ForegroundColor DarkGray
    if ($hostLetter) { Write-Host " [$($hostLetter):]" -ForegroundColor Magenta } else { Write-Host "" }
    Write-Host $bar -ForegroundColor Cyan
}

:MainLoop while ($true) {
    Show-VhdHeader
    $Cfg = Get-Config
    $localProjectRoot = "P:\Projects\golden-image"
    $hostReturnDir = Join-Path $localProjectRoot "return"
    
    Write-Host "VHD CONTROL:" -ForegroundColor Magenta
    Write-Host "  0. Disconnect All" -ForegroundColor Yellow
    Write-Host "  1. Connect Host"
    Write-Host "  2. Connect VM"
    Write-Host ""
    Write-Host "SYNC OPERATIONS:" -ForegroundColor Magenta
    Write-Host "  4. Sync All"
    Write-Host "  5. Sync _offline"
    Write-Host "  6. Pull Return" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[R] Refresh [H] Set VHD [V] Set VM [U] Set User [X] Exit" -ForegroundColor DarkGray
    
    $choice = Read-Host "Select Action"
    switch ($choice) {
        "0" { Invoke-SmartRelease $Cfg.VhdPath $Cfg.VMName; Start-Sleep 1 }
        "1" { Invoke-SmartRelease $Cfg.VhdPath $Cfg.VMName; Mount-VHD $Cfg.VhdPath; Start-Sleep 1 }
        "2" { Invoke-SmartRelease $Cfg.VhdPath $Cfg.VMName; Add-VMHardDiskDrive -VMName $Cfg.VMName -ControllerType SCSI -Path $Cfg.VhdPath; Start-Sleep 1 }
        "4" { 
            Invoke-MasterSwoop @("$localProjectRoot\_offline", "$localProjectRoot\installers") $Cfg.VhdPath $Cfg.VMName 
        }
        "5" { Invoke-MasterSwoop @("$localProjectRoot\_offline") $Cfg.VhdPath $Cfg.VMName }
        "6" { 
            if (!(Test-Path $hostReturnDir)) { New-Item $hostReturnDir -ItemType Directory | Out-Null }
            Invoke-ReverseSwoop $hostReturnDir $Cfg.VhdPath $Cfg.VMName 
        }
        "h" { $Cfg.VhdPath = Read-Host "Path"; Save-Config $Cfg }
        "v" { $Cfg.VMName = Read-Host "VM Name"; Save-Config $Cfg }
        "u" { $Cfg.VMUser = Read-Host "VM User (default: Administrator)"; Save-Config $Cfg }
        "x" { break MainLoop }
    }
}
#< === END BLOCK 4 ===
