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
#< === END BLOCK 1 ===

#> === BLOCK 2: SMART RELEASE LOGIC (ACTION 0) ===
function Invoke-SmartRelease {
    Param([string]$VhdPath, [string]$VMName)
    Write-Host "[*] Action 0: Disconnecting all controllers..." -ForegroundColor DarkGray
    
    # 1. Release from VM
    $vmDrive = Get-VMHardDiskDrive -VMName $VMName | Where-Object Path -eq $VhdPath
    if ($vmDrive) {
        Write-Host "    -> Releasing from VM: $VMName" -ForegroundColor Yellow
        $vmDrive | Remove-VMHardDiskDrive -ErrorAction SilentlyContinue
    }

    # 2. Release from Host
    $vhdInfo = Get-VHD -Path $VhdPath -ErrorAction SilentlyContinue
    if ($vhdInfo.Attached) {
        Write-Host "    -> Dismounting from Host" -ForegroundColor Yellow
        Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
    }
    
    Start-Sleep -Seconds 1
}
#< === END BLOCK 2 ===

#> === BLOCK 3: SYNC FUNCTIONS (4, 5, 6) ===
function Invoke-MasterSwoop {
    Param([string]$Source, [string]$VhdPath, [string]$VMName, [switch]$NoPause)
    try {
        Write-Host ">>> SYNC: $(Split-Path $Source -Leaf)" -ForegroundColor Cyan
        Invoke-SmartRelease -VhdPath $VhdPath -VMName $VMName
        
        $vhd = Mount-VHD -Path $VhdPath -Passthru
        Start-Sleep -Seconds 1
        $driveLetter = (Get-Partition -DiskNumber $vhd.DiskNumber | Get-Volume | Where-Object DriveLetter).DriveLetter
        if (-not $driveLetter) { throw "No Host Drive Letter assigned." }

        $destination = Join-Path "$($driveLetter):" (Split-Path $Source -Leaf)
        Write-Host "[Syncing] $Source -> $destination" -ForegroundColor Yellow
        robocopy $Source $destination /MIR /MT:16 /R:2 /W:5 /NP /NDL /FFT
        
        Dismount-VHD -Path $VhdPath
        Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -Path $VhdPath
        Write-Host "[SUCCESS] VHD returned to VM." -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Sync Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    if (-not $NoPause) { Write-Host "`nPress any key..."; $null = [System.Console]::ReadKey($true) }
}

function Invoke-ReverseSwoop {
    Param([string]$TargetHostDir, [string]$VhdPath, [string]$VMName, [switch]$NoPause)
    
    $Cfg = Get-Config
    $Creds = Get-VMCreds $Cfg.VMUser

    try {
        Write-Host ">>> ACTION 6: PULL RETURN" -ForegroundColor Cyan
        
        # 1. Remote Harvest
        Write-Host "[1/4] Harvesting logs from VM..." -ForegroundColor Yellow
        $harvestScript = {
            $VhdReturn = "F:\return" 
            $TempPath = $env:TEMP

            # A. THE JANITOR: Stop VS processes to unlock log files
            $VSProcs = "vs_setup", "setup", "vs_installer", "vs_installershell"
            Get-Process -Name $VSProcs -ErrorAction SilentlyContinue | Stop-Process -Force
            Start-Sleep -Seconds 1

            # B. PREP: Ensure the return folder on the VHD exists
            if (-not (Test-Path $VhdReturn)) { 
                New-Item $VhdReturn -ItemType Directory | Out-Null 
            }

            # C. HARVEST: Move logs from %TEMP% to the Staging VHD
            $LogPatterns = @("dd_*.log", "vs_setup*.log")
            foreach ($p in $LogPatterns) {
                Get-ChildItem -Path $TempPath -Filter $p | 
                    Move-Item -Destination $VhdReturn -Force -ErrorAction SilentlyContinue
            }
        }

        try {
            Invoke-Command -VMName $VMName -Credential $Creds -ScriptBlock $harvestScript -ErrorAction Stop
        } catch {
            $msg = $_.Exception.Message
            if ($msg -like "*credential is invalid*" -or $msg -like "*incorrect format*") {
                Write-Host "`n[!] PS-DIRECT BLOCKED: Remote local admin access is restricted." -ForegroundColor Red
                Write-Host "[*] EMERGENCY FIX (Run INSIDE VM as Admin, then REBOOT):" -ForegroundColor Cyan
                Write-Host "    reg add `"HKLM\SYSTEM\CurrentControlSet\Control\Lsa`" /v `"LimitBlankPasswordUse`" /t REG_DWORD /d 0 /f" -ForegroundColor White
                Write-Host "    reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`" /v `"LocalAccountTokenFilterPolicy`" /t REG_DWORD /d 1 /f" -ForegroundColor White
                Write-Host "    reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`" /v `"FilterAdministratorToken`" /t REG_DWORD /d 0 /f" -ForegroundColor White
                Write-Host "    powershell -Command `"Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private`"" -ForegroundColor White
                Write-Host "    powershell -Command `"Enable-PSRemoting -Force -SkipNetworkProfileCheck`"" -ForegroundColor White
                
                Write-Host "`n[*] HOST FIX (Run on your PHYSICAL machine as Admin):" -ForegroundColor Yellow
                Write-Host "    powershell -Command `"Enable-PSRemoting -Force -SkipNetworkProfileCheck`"" -ForegroundColor White
                Write-Host "    powershell -Command `"Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force`"" -ForegroundColor White
                
                Write-Host "`nAttempting manual fallback..." -ForegroundColor DarkGray
                $Creds = Get-Credential -UserName $Cfg.VMUser -Message "Enter VM Password (leave blank if none)"
                Invoke-Command -VMName $VMName -Credential $Creds -ScriptBlock $harvestScript -ErrorAction Stop
            } else {
                throw $_
            }
        }

        # 2. Swap to Host
        Invoke-SmartRelease -VhdPath $VhdPath -VMName $VMName
        $vhd = Mount-VHD -Path $VhdPath -Passthru
        Start-Sleep -Seconds 1
        $driveLetter = (Get-Partition -DiskNumber $vhd.DiskNumber | Get-Volume | Where-Object DriveLetter).DriveLetter

        if ($driveLetter) {
            $vhdReturnSource = "$($driveLetter):\return"
            Write-Host "[3/4] Pulling: $vhdReturnSource -> $TargetHostDir" -ForegroundColor Yellow
            robocopy $vhdReturnSource $TargetHostDir /MIR /MT:16 /R:2 /W:5 /NP /NDL
        }
        
        Dismount-VHD -Path $VhdPath
        Write-Host "[4/4] Pull Complete." -ForegroundColor Green
        $Latest = Get-ChildItem $TargetHostDir -Filter "dd_bootstrapper*.log" | Sort-Object LastWriteTime -Desc | Select-Object -First 1
        if ($Latest) { Start-Process $Latest.FullName }

    } catch { Write-Host "[ERROR] Action 6 Failed: $($_.Exception.Message)" -ForegroundColor Red }
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
            Invoke-MasterSwoop "$localProjectRoot\_offline" $Cfg.VhdPath $Cfg.VMName -NoPause
            Invoke-MasterSwoop "$localProjectRoot\installers" $Cfg.VhdPath $Cfg.VMName 
        }
        "5" { Invoke-MasterSwoop "$localProjectRoot\_offline" $Cfg.VhdPath $Cfg.VMName }
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