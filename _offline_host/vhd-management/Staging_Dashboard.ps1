# Dashboard: ROG Strix VHD Infrastructure Manager
# ---------------------------------------------------------------------------
param([string]$Action)

# #region agent log
$DebugLogDir = Join-Path (Split-Path $PSScriptRoot -Parent) "logs"
$DebugLogPath = Join-Path $DebugLogDir "debug-ba5e25.log"
if (-not (Test-Path $DebugLogDir)) { New-Item -ItemType Directory -Path $DebugLogDir -Force | Out-Null }
if (Test-Path $DebugLogPath) { Remove-Item $DebugLogPath -Force -ErrorAction SilentlyContinue }
function Debug-Log { param($msg,$data,$hyp) $j = @{sessionId="ba5e25";location="Staging_Dashboard.ps1";message=$msg;data=$data;hypothesisId=$hyp;timestamp=[int](Get-Date -UFormat %s)*1000} | ConvertTo-Json -Compress; Add-Content -Path $DebugLogPath -Value $j -ErrorAction SilentlyContinue }
# #endregion

#> === BLOCK 1: CONFIGURATION & PERSISTENCE ===
$ConfigPath = Join-Path $PSScriptRoot "config.json"

function Get-Config {
    $default = @{ 
        VhdPath = "N:\VHD\MasterInstallers.vhdx"; 
        VMName  = "Windows 11 Master";
        VMUser  = "Administrator";
        GuestStagingDrive = "F";
        StagingVolumeLabel = "Golden Imaging"
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

# Helper to get credentials (empty password for Audit-mode VM Administrator)
function Get-VMCreds {
    Param([string]$User)
    if (-not $User) { $User = "Administrator" }
    $pass = New-Object System.Security.SecureString
    return New-Object System.Management.Automation.PSCredential($User, $pass)
}

# Helper to detect VHD lock errors (checks full Exception + InnerException chain + ErrorRecord)
function Test-IsVhdLockError {
    Param($ErrorRecord)
    # Accept ErrorRecord ($_) or Exception; build full message from all sources
    $combined = ""
    if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) {
        $combined += " " + $ErrorRecord.ToString()
        $ErrorRecord = $ErrorRecord.Exception
    }
    $e = $ErrorRecord
    while ($e) {
        $combined += " " + $e.Message
        $e = $e.InnerException
    }
    return ($combined -like "*used by another process*" -or $combined -like "*in use*" -or $combined -like "*0x80070020*" -or $combined -like "*cannot access the file*")
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
            if (Test-IsVhdLockError $_) {
                Write-Host "    [!] VHD is locked. Retrying ($retryCount/$maxRetries)..." -ForegroundColor Yellow
                Write-Host "    [*] Running force escalation (Set-Disk offline, Dismount-VHD)..." -ForegroundColor DarkGray
                Get-Disk | Where-Object { $_.FriendlyName -like "*Virtual*" } | Set-Disk -IsOffline $true -ErrorAction SilentlyContinue
                Dismount-VHD -Path $Path -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
            } else {
                throw $_
            }
        }
    }
    # Final escalation: restart VDS and try once more
    Write-Host "    [!!!] Restarting Virtual Disk Service (VDS)..." -ForegroundColor Red
    try {
        Restart-Service -Name "vds" -Force -ErrorAction Stop
        Start-Sleep -Seconds 4
        $vhd = Mount-VHD -Path $Path -Passthru -ErrorAction Stop
        return $vhd
    } catch {
        throw "Failed to mount VHD after $maxRetries attempts and VDS restart. The VHD may still be in use."
    }
}

function Add-VMHardDiskDriveWithRetry {
    Param([string]$VhdPath, [string]$VMName)
    $maxRetries = 5
    $retryCount = 0

    while ($retryCount -lt $maxRetries) {
        try {
            Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -Path $VhdPath -ErrorAction Stop
            return
        } catch {
            $retryCount++
            if (Test-IsVhdLockError $_) {
                Write-Host "    [!] VHD is locked. Retrying ($retryCount/$maxRetries)..." -ForegroundColor Yellow
                Write-Host "    [*] Running force escalation (Set-Disk offline, Dismount-VHD)..." -ForegroundColor DarkGray
                Get-Disk | Where-Object { $_.FriendlyName -like "*Virtual*" } | Set-Disk -IsOffline $true -ErrorAction SilentlyContinue
                Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
            } else {
                throw $_
            }
        }
    }
    # Final escalation: restart VDS and try once more
    Write-Host "    [!!!] Restarting Virtual Disk Service (VDS)..." -ForegroundColor Red
    try {
        Restart-Service -Name "vds" -Force -ErrorAction Stop
        Start-Sleep -Seconds 4
        Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -Path $VhdPath -ErrorAction Stop
        return
    } catch {
        throw "Failed to attach VHD to VM after $maxRetries attempts and VDS restart. The VHD may still be in use."
    }
}

function Get-AttachedDiskNumber {
    Param([string]$VhdPath)
    $vhdInfo = Get-VhdInfoSafe -VhdPath $VhdPath
    if ($vhdInfo -and $vhdInfo.Attached -and $null -ne $vhdInfo.DiskNumber) {
        return $vhdInfo.DiskNumber
    }
    return $null
}

#< === END BLOCK 1 ===

#> === BLOCK 2: SMART RELEASE LOGIC (ACTION 0) ===
function Get-VhdInfoSafe {
    Param([string]$VhdPath, [int]$TimeoutSeconds = 3)
    $job = Start-Job { param($p) Import-Module Hyper-V -ErrorAction SilentlyContinue; Get-VHD -Path $p -ErrorAction SilentlyContinue } -ArgumentList $VhdPath
    $done = Wait-Job $job -Timeout $TimeoutSeconds
    if ($done) { $r = Receive-Job $job; Remove-Job $job -Force; return $r }
    Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue
    return $null
}

function Test-VhdPathMatch {
    Param([string]$PathA, [string]$PathB)
    if (-not $PathA -or -not $PathB) { return $false }
    if ($PathA -eq $PathB) { return $true }
    try {
        $a = [System.IO.Path]::GetFullPath($PathA.TrimEnd('\'))
        $b = [System.IO.Path]::GetFullPath($PathB.TrimEnd('\'))
        return $a -eq $b
    } catch { return $false }
}

function Get-VmDriveForVhd {
    Param([string]$VhdPath, [string]$VMName)
    $all = Get-VMHardDiskDrive -VMName $VMName -ErrorAction SilentlyContinue
    $match = $all | Where-Object { Test-VhdPathMatch $_.Path $VhdPath } | Select-Object -First 1
    if ($match) { return $match }
    $leaf = Split-Path $VhdPath -Leaf
    $match = $all | Where-Object { $_.Path -and (Split-Path $_.Path -Leaf) -eq $leaf } | Select-Object -First 1
    if ($match) { return $match }
    # Differencing disks: MasterInstallers_6D72AAA6-....avhdx chains from MasterInstallers.vhdx
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($VhdPath)
    if ($baseName) {
        $all | Where-Object { $_.Path -and (Split-Path $_.Path -Leaf) -like "${baseName}*" } | Select-Object -First 1
    }
}

function Invoke-SmartRelease {
    Param([string]$VhdPath, [string]$VMName)
    # Get VM drives - use robust path match (Get-VHD can hang on locked files, returning null)
    $vmDrive = Get-VmDriveForVhd -VhdPath $VhdPath -VMName $VMName
    $vhdInfo = Get-VhdInfoSafe -VhdPath $VhdPath
    $isAtVM = $null -ne $vmDrive
    $isAtHost = $vhdInfo -and $vhdInfo.Attached -and $null -ne $vhdInfo.DiskNumber
    # #region agent log
    $att = if ($vhdInfo) { $vhdInfo.Attached } else { $null }; $dn = if ($vhdInfo) { $vhdInfo.DiskNumber } else { $null }
    $caller = (Get-PSCallStack)[1..3] | ForEach-Object { "$($_.Command):$($_.ScriptLineNumber)" }
    Debug-Log "Invoke-SmartRelease entry" @{hasVmDrive=($null -ne $vmDrive);vhdInfoAttached=$att;vhdInfoDiskNumber=$dn;isAtHost=$isAtHost;caller=$caller} "A"
    # #endregion
    # Do NOT early-exit when vhdInfo is null: Get-VHD may have timed out (file locked) - we must try force escalation
    if (-not $isAtVM -and -not $isAtHost -and $null -ne $vhdInfo) {
        Write-Host "[*] VHD not attached to VM or Host. Nothing to disconnect." -ForegroundColor DarkGray
        return
    }
    if (-not $isAtVM -and $null -eq $vhdInfo) {
        Write-Host "[*] VHD status unknown (possible lock). Running force escalation..." -ForegroundColor DarkGray
    }
    $maxRetries = 5
    $retryCount = 0
    $printedHeader = $false
    $printedVmRelease = $false

    while ($retryCount -lt $maxRetries) {
        try {
            if ($retryCount -gt 0) {
                Write-Host "    [*] Retry attempt $retryCount/$maxRetries..." -ForegroundColor DarkGray
            }
            # 1. Release from VM (re-fetch in case path match improves after escalation)
            $vmDrive = Get-VmDriveForVhd -VhdPath $VhdPath -VMName $VMName
            if ($vmDrive) {
                if (-not $printedHeader) {
                    Write-Host "[*] Disconnecting all controllers..." -ForegroundColor DarkGray
                    $printedHeader = $true
                }
                if (-not $printedVmRelease) {
                    Write-Host "    -> Releasing from VM: $VMName" -ForegroundColor Yellow
                    $printedVmRelease = $true
                }
                $vmDrive | Remove-VMHardDiskDrive -ErrorAction Stop
                Start-Sleep -Seconds 2 # Give Hyper-V time to release file handle
            }

            # 2. Release from Host (only when actually host-mounted; Attached is true for VM too)
            $vhdInfo = Get-VhdInfoSafe -VhdPath $VhdPath
            # #region agent log
            $att2 = if ($vhdInfo) { $vhdInfo.Attached } else { $null }; $dn2 = if ($vhdInfo) { $vhdInfo.DiskNumber } else { $null }
            Debug-Log "After VM release, before host check" @{vhdInfoAttached=$att2;vhdInfoDiskNumber=$dn2;willDismountHost=($vhdInfo -and $vhdInfo.Attached -and $null -ne $vhdInfo.DiskNumber)} "B"
            # #endregion
            if ($vhdInfo -and $vhdInfo.Attached -and $null -ne $vhdInfo.DiskNumber) {
                if (-not $printedHeader) {
                    Write-Host "[*] Disconnecting all controllers..." -ForegroundColor DarkGray
                    $printedHeader = $true
                }
                Write-Host "    -> Dismounting from Host" -ForegroundColor Yellow
                Dismount-VHD -Path $VhdPath -ErrorAction Stop
                Start-Sleep -Seconds 1
            }

            # 3. When vhdInfo was null (timeout/lock), run force escalation to clear any stale state
            if ($null -eq $vhdInfo -or ($vhdInfo -and -not $vhdInfo.Attached)) {
                Get-Disk | Where-Object { $_.FriendlyName -like "*Virtual*" } | Set-Disk -IsOffline $true -ErrorAction SilentlyContinue
                Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
            return
        } catch {
            $retryCount++
            if (Test-IsVhdLockError $_) {
                Write-Host "    [!] VHD is locked. Retrying ($retryCount/$maxRetries)..." -ForegroundColor Yellow
                Write-Host "    [*] Running force escalation (Set-Disk offline, Dismount-VHD)..." -ForegroundColor DarkGray
                Get-Disk | Where-Object { $_.FriendlyName -like "*Virtual*" } | Set-Disk -IsOffline $true -ErrorAction SilentlyContinue
                Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
            } else {
                throw $_
            }
        }
    }
    # Final escalation: restart VDS and try once more
    Write-Host "    [!!!] Restarting Virtual Disk Service (VDS)..." -ForegroundColor Red
    try {
        Restart-Service -Name "vds" -Force -ErrorAction Stop
        Start-Sleep -Seconds 4
        Get-Disk | Where-Object { $_.FriendlyName -like "*Virtual*" } | Set-Disk -IsOffline $true -ErrorAction SilentlyContinue
        Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
        return
    } catch {
        throw "Failed to disconnect VHD after $maxRetries attempts and VDS restart. The VHD may still be in use."
    }
}
#< === END BLOCK 2 ===

#> === BLOCK 3: STATE PERSISTENCE & SYNC FUNCTIONS ===
function Get-VhdState {
    Param([string]$VhdPath, [string]$VMName)
    $vmDrive = Get-VmDriveForVhd -VhdPath $VhdPath -VMName $VMName
    $vhdInfo = Get-VhdInfoSafe -VhdPath $VhdPath
    return @{
        WasAtVM = $null -ne $vmDrive
        WasAtHost = ($vhdInfo -and $vhdInfo.Attached -and $null -ne $vhdInfo.DiskNumber)
    }
}

function Restore-VhdState {
    Param([string]$VhdPath, [string]$VMName, $State)
    # Check if already attached to VM - skip if we never moved it (e.g. sync failed before mount)
    $alreadyAtVM = Get-VmDriveForVhd -VhdPath $VhdPath -VMName $VMName
    if ($alreadyAtVM) {
        Write-Host "[*] VHD already attached to VM. No action needed." -ForegroundColor DarkGray
        return
    }
    Write-Host "[*] Finalizing: Reconnecting VHD to VM: $VMName" -ForegroundColor DarkGray
    Invoke-SmartRelease -VhdPath $VhdPath -VMName $VMName

    # Only attach if it was on VM originally (State.WasAtVM). After SmartRelease, nothing is attached.
    if (-not $State.WasAtVM) {
        Write-Host "[*] VHD was not on VM originally. Skipping reattach." -ForegroundColor DarkGray
        return
    }

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

        $vol = Get-Partition -DiskNumber $targetDiskNumber | Get-Volume | Where-Object DriveLetter
        $driveLetter = $vol.DriveLetter
        if (-not $driveLetter) { throw "No Host Drive Letter assigned." }
        $label = (Get-Config).StagingVolumeLabel
        if ($label -and $vol.FileSystemLabel -ne $label) {
            Set-Volume -DriveLetter $driveLetter -NewFileSystemLabel $label -ErrorAction SilentlyContinue
        }

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
    if (-not $NoPause) { Write-Host "`nPress Enter to continue..."; $null = Read-Host; $host.UI.RawUI.FlushInputBuffer() }
}

function Invoke-ReverseSwoop {
    Param([string]$TargetHostDir, [string]$VhdPath, [string]$VMName, [switch]$NoPause)
    
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
    if (-not $NoPause) { Write-Host "`nPress Enter to continue..."; $null = Read-Host; $host.UI.RawUI.FlushInputBuffer() }
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
    $isAtVM = if ($vmObj) { Get-VmDriveForVhd -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName }
    
    $hostLetter = ""
    if ($vhdExists) {
        $vhdInfo = Get-VhdInfoSafe -VhdPath $Cfg.VhdPath
        if ($vhdInfo -and $vhdInfo.Attached -and $null -ne $vhdInfo.DiskNumber) { 
            $hostLetter = (Get-Partition -DiskNumber $vhdInfo.DiskNumber | Get-Volume | Where-Object DriveLetter).DriveLetter
        }
    }

    $guestServicesEnabled = $false
    if ($vmObj) {
        $gs = Get-VMIntegrationService -VMName $Cfg.VMName -Name "Guest Service Interface" -ErrorAction SilentlyContinue
        $guestServicesEnabled = $gs -and $gs.Enabled
    }
    $vmStatusColor    = if ($vmObj.State -eq 'Running') { "Green" } else { "Red" }
    $hostStagingColor = if ($hostLetter) { "Green" } else { "Red" }
    $vmStagingColor   = if (-not $isAtVM) { "Red" } elseif ($guestServicesEnabled) { "Green" } else { "Yellow" }

    Write-Host "               (VM) " -NoNewline
    Write-Host "($($vmObj.State)) " -NoNewline -ForegroundColor $vmStatusColor
    Write-Host "[Host Staging] " -NoNewline -ForegroundColor $hostStagingColor
    Write-Host "[VM Staging]" -ForegroundColor $vmStagingColor
    Write-Host ""
    Write-Host $bar -ForegroundColor Cyan
    Write-Host "VHD: $($Cfg.VhdPath)" -NoNewline -ForegroundColor DarkGray
    if ($hostLetter) { Write-Host " [$($hostLetter):]" -ForegroundColor Magenta } else { Write-Host "" }
    if ($isAtVM) {
        $volLabel = if ($Cfg.StagingVolumeLabel) { $Cfg.StagingVolumeLabel } else { "Golden Imaging" }
        $fallback = if ($Cfg.GuestStagingDrive) { $Cfg.GuestStagingDrive.Trim().TrimEnd(':')[0] } else { 'F' }
        $guestLetter = & (Join-Path $PSScriptRoot "scripts\Get-GuestStagingDrive.ps1") -VMName $Cfg.VMName -VolumeLabel $volLabel -FallbackLetter $fallback
        if ($guestLetter -and $guestLetter -ne $Cfg.GuestStagingDrive) {
            $Cfg.GuestStagingDrive = $guestLetter
            Save-Config $Cfg
        }
        Write-Host "VM drive: $volLabel ($($guestLetter):)" -ForegroundColor DarkGray
    }
}

# Non-interactive: ensure VHD is connected to VM (for AHK/other scripts that need F: in guest)
if ($Action -eq 'ConnectVM') {
    $Cfg = Get-Config
    $atVM = Get-VmDriveForVhd -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName
    if ($atVM) { exit 0 }
    Invoke-SmartRelease -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName
    Add-VMHardDiskDriveWithRetry -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName
    exit 0
}

:MainLoop while ($true) {
    Show-VhdHeader
    $Cfg = Get-Config
    $localProjectRoot = "P:\Projects\golden-image"
    $hostReturnDir = Join-Path $localProjectRoot "return"
    $logScript = Join-Path $PSScriptRoot "scripts\Get-RemoteLog.ps1"
    $creds = Get-VMCreds $Cfg.VMUser

    Write-Host ""
    Write-Host "SYNC OPERATIONS:" -ForegroundColor Magenta
    Write-Host "  1. Sync"
    Write-Host "   11. Sync _offline"
    Write-Host "   12. Sync installers"
    Write-Host ""
    $guestDrive = if ($Cfg.GuestStagingDrive) { $Cfg.GuestStagingDrive.Trim().TrimEnd(':')[0] } else { 'F' }
    $returnPath = "${guestDrive}:\return"
    Write-Host "PULL LOGS:" -ForegroundColor Magenta
    Write-Host "  6. Pull Shit (F:\shit.txt from VM)"
    Write-Host "  7. Pull Most Recent Logs (from VM $returnPath)"
    Write-Host "   71. Only for Scoop"
    Write-Host "   72. Only for MSVC (vs_setup* & dd_bootstrapper*)"
    Write-Host "   73. Only for Apps"
    Write-Host "   74. Only for Rust"
    Write-Host ""
    Write-Host "VHD CONTROL:" -ForegroundColor Magenta
    Write-Host "  D: Disconnect All" -ForegroundColor Yellow
    Write-Host "  H: Connect Host"
    Write-Host "  V: Connect VM"
    Write-Host ""
    Write-Host "ADDITIONAL:" -ForegroundColor Magenta
    Write-Host "  K: Kill VDS (restart Virtual Disk Service to release hard locks)" -ForegroundColor Yellow
    Write-Host "  R: Pull Return" -ForegroundColor Cyan
    Write-Host "  Z: VHD lock diagnostics (what is holding the file open?)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[SH] Set VHD  [SV] Set VM  [SG] Set Guest drive ($guestDrive)  [U] Set User  [X] Exit (Ctrl+C)" -ForegroundColor DarkGray
    
    try {
        $choice = Read-Host "Select Action"
    } catch {
        if ($_.Exception.GetType().Name -eq 'PipelineStoppedException') { break MainLoop }
        throw
    }
    try {
        switch ($choice) {
            "1" { Invoke-MasterSwoop @("$localProjectRoot\_offline", "$localProjectRoot\installers") $Cfg.VhdPath $Cfg.VMName }
            "11" { Invoke-MasterSwoop @("$localProjectRoot\_offline") $Cfg.VhdPath $Cfg.VMName }
            "12" { Invoke-MasterSwoop @("$localProjectRoot\installers") $Cfg.VhdPath $Cfg.VMName }
            "6" {
                $creds = Get-VMCreds $Cfg.VMUser
                Write-Host "--- Pull Shit (VM $($Cfg.VMName)) ---" -ForegroundColor Cyan
                Invoke-Command -VMName $Cfg.VMName -Credential $creds -ScriptBlock {
                    $path = "${using:guestDrive}:\shit.txt"
                    if (Test-Path $path) {
                        Get-Content -Path $path
                    } else {
                        Write-Host "[!] File not found: $path" -ForegroundColor Yellow
                    }
                }
                Write-Host "`nPress Enter to continue..."; $null = Read-Host; $host.UI.RawUI.FlushInputBuffer()
            }
            "7" { & $logScript -Category all -VMName $Cfg.VMName -Credential $creds -ReturnPath $returnPath; Write-Host "`nPress Enter to continue..."; $null = Read-Host; $host.UI.RawUI.FlushInputBuffer() }
            "71" { & $logScript -Category scoop -VMName $Cfg.VMName -Credential $creds -ReturnPath $returnPath; Write-Host "`nPress Enter to continue..."; $null = Read-Host; $host.UI.RawUI.FlushInputBuffer() }
            "72" { & $logScript -Category msvc -VMName $Cfg.VMName -Credential $creds -ReturnPath $returnPath; Write-Host "`nPress Enter to continue..."; $null = Read-Host; $host.UI.RawUI.FlushInputBuffer() }
            "73" { & $logScript -Category apps -VMName $Cfg.VMName -Credential $creds -ReturnPath $returnPath; Write-Host "`nPress Enter to continue..."; $null = Read-Host; $host.UI.RawUI.FlushInputBuffer() }
            "74" { & $logScript -Category rust -VMName $Cfg.VMName -Credential $creds -ReturnPath $returnPath; Write-Host "`nPress Enter to continue..."; $null = Read-Host; $host.UI.RawUI.FlushInputBuffer() }
            { $_ -in 'd','D' } { Invoke-SmartRelease $Cfg.VhdPath $Cfg.VMName; Start-Sleep 1 }
            { $_ -in 'h','H' } { Invoke-SmartRelease $Cfg.VhdPath $Cfg.VMName; $null = Mount-VhdWithRetry -Path $Cfg.VhdPath; Start-Sleep 1 }
            { $_ -in 'v','V' } { Invoke-SmartRelease $Cfg.VhdPath $Cfg.VMName; Add-VMHardDiskDriveWithRetry -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName; Start-Sleep 1 }
            "k" {
                Write-Host "[!!!] Restarting Virtual Disk Service (VDS)..." -ForegroundColor Red
                Restart-Service -Name "vds" -Force -ErrorAction Stop
                Start-Sleep -Seconds 3
                Write-Host "[OK] VDS restarted. Try sync again." -ForegroundColor Green
                Start-Sleep 1
            }
            "K" {
                Write-Host "[!!!] Restarting Virtual Disk Service (VDS)..." -ForegroundColor Red
                Restart-Service -Name "vds" -Force -ErrorAction Stop
                Start-Sleep -Seconds 3
                Write-Host "[OK] VDS restarted. Try sync again." -ForegroundColor Green
                Start-Sleep 1
            }
            "z" { & (Join-Path $PSScriptRoot "scripts\Get-VhdLockDiagnostics.ps1") -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName; Write-Host "`nPress Enter to continue..."; $null = Read-Host; $host.UI.RawUI.FlushInputBuffer() }
            "Z" { & (Join-Path $PSScriptRoot "scripts\Get-VhdLockDiagnostics.ps1") -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName; Write-Host "`nPress Enter to continue..."; $null = Read-Host; $host.UI.RawUI.FlushInputBuffer() }
            "r" {
                if (!(Test-Path $hostReturnDir)) { New-Item $hostReturnDir -ItemType Directory | Out-Null }
                Invoke-ReverseSwoop $hostReturnDir $Cfg.VhdPath $Cfg.VMName 
            }
            "R" {
                if (!(Test-Path $hostReturnDir)) { New-Item $hostReturnDir -ItemType Directory | Out-Null }
                Invoke-ReverseSwoop $hostReturnDir $Cfg.VhdPath $Cfg.VMName 
            }
            "sh" { $Cfg.VhdPath = Read-Host "VHD path"; Save-Config $Cfg }
            "SH" { $Cfg.VhdPath = Read-Host "VHD path"; Save-Config $Cfg }
            "sv" { $Cfg.VMName = Read-Host "VM name"; Save-Config $Cfg }
            "SV" { $Cfg.VMName = Read-Host "VM name"; Save-Config $Cfg }
            "sg" { $dr = Read-Host "Guest staging drive letter (e.g. F)"; if ($dr) { $Cfg.GuestStagingDrive = $dr.Trim().TrimEnd(':')[0].ToString(); Save-Config $Cfg } }
            "SG" { $dr = Read-Host "Guest staging drive letter (e.g. F)"; if ($dr) { $Cfg.GuestStagingDrive = $dr.Trim().TrimEnd(':')[0].ToString(); Save-Config $Cfg } }
            "u" { $Cfg.VMUser = Read-Host "VM User (default: Administrator)"; Save-Config $Cfg }
            "U" { $Cfg.VMUser = Read-Host "VM User (default: Administrator)"; Save-Config $Cfg }
            { $_ -in 'x','X' } { break MainLoop }
        }
    } catch {
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nPress Enter to continue..."; $null = Read-Host; $host.UI.RawUI.FlushInputBuffer()
    }
}
#< === END BLOCK 4 ===
