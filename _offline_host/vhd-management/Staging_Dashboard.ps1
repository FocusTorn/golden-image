# Dashboard: ROG Strix VHD Infrastructure Manager
# ---------------------------------------------------------------------------
param([string]$Action)

. (Join-Path $PSScriptRoot "scripts\VhdUtils.ps1")

# --- UI HELPERS ---
function Show-VhdHeader {
    $Cfg = Get-Config
    $vmObj = Get-VM -Name $Cfg.VMName -ErrorAction SilentlyContinue
    $vhdExists = Test-Path $Cfg.VhdPath
    $isAtVM = if ($vmObj) { Get-VmDriveForVhd -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName }
    
    $hostLetter = ""
    if ($vhdExists) {
        $vhdInfo = Get-VhdInfoSafe -VhdPath $Cfg.VhdPath
        if ($vhdInfo -and $vhdInfo.Attached -and $vhdInfo.DiskNumber -ne $null) { 
            $hostLetter = (Get-Partition -DiskNumber $vhdInfo.DiskNumber | Get-Volume | Where-Object DriveLetter).DriveLetter
        }
    }

    $vmRunning = $vmObj -and $vmObj.State -eq 'Running'
    $vmStatus = if ($vmObj) { if ($vmRunning) { "Running" } else { "Stopped" } } else { "-" }
    $hostStatus = if ($hostLetter) { "$($hostLetter):" } else { "-" }
    $stagingStatus = if ($isAtVM) { "VM" } elseif ($hostLetter) { "Host" } else { "-" }
    
    $credsMode = if ($Cfg.UsePasswordCreds -eq $true -or $Cfg.UsePasswordCreds -eq "true") { "Password" } else { "Empty" }
    
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                VHDX INFRASTRUCTURE MANAGEMENT                  " -ForegroundColor Cyan
    Write-Host "  VM: $vmStatus | Host: $hostStatus | Staging: $stagingStatus" -ForegroundColor DarkCyan
    Write-Host "  Creds: $credsMode | VHD: $(Split-Path $Cfg.VhdPath -Leaf)" -ForegroundColor DarkGray
    Write-Host "================================================================" -ForegroundColor Cyan
}

# --- NON-INTERACTIVE HANDLER ---
if ($Action -eq 'ConnectVM') {
    $Cfg = Get-Config
    if (-not (Get-VmDriveForVhd -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName)) {
        Invoke-VhdTransition -Target "VM" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName | Out-Null
    }
    exit 0
}

# --- MAIN EXECUTION LOOP ---
while ($true) {
    Clear-Host
    Show-VhdHeader
    $Cfg = Get-Config
    $scriptsDir = Join-Path $PSScriptRoot "scripts"
    $localReturnDir = Join-Path $LocalProjectRoot "return"
    $guestDrive = Get-GuestDriveLetter $Cfg.GuestStagingDrive
    $ConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) "_offline_host_config.json"

    Write-Host "`nSYNC OPERATIONS:" -ForegroundColor Magenta
    Write-Host "  1. Sync _offline | 2. Sync all"
    Write-Host "`nREMOTE TOOLS:" -ForegroundColor Magenta
    Write-Host "  6. Pull Shit | 7. Pull Logs | L. Shortcut"
    Write-Host "`nVHD CONTROL:" -ForegroundColor Magenta
    Write-Host "  D. Disconnect All | H. Connect Host | V. Connect VM | K. Kill VDS | R. Pull Return | Z. Lock Diagnostics"
    Write-Host "`nCONFIG:" -ForegroundColor DarkGray
    Write-Host "  [SH] Set VHD  [SV] Set VM  [SG] Set Guest ($guestDrive)  [P] Toggle Creds  [X] Exit"

    $choice = (Read-Host "`nSelect Action").ToLower().Trim()
    if ($choice -eq "x") { exit 0 }

    $ErrorActionPreference = "Stop"
    try {
        switch ($choice) {
            "1" { & "$scriptsDir\Invoke-VhdSwoop.ps1" -Sources @("$LocalProjectRoot\_offline") }
            "2" { & "$scriptsDir\Invoke-VhdSwoop.ps1" -Sources @("$LocalProjectRoot\_offline", "$LocalProjectRoot\installers") }
            "6" { 
                $creds = Get-VMCreds $Cfg.VMUser $Cfg
                Invoke-Command -VMName $Cfg.VMName -Credential $creds -ScriptBlock { Get-Content "${using:guestDrive}:\shit.txt" }
                Read-Host "`nPress Enter..."
            }
            "7" { & "$scriptsDir\Get-RemoteLog.ps1" -Category all; Read-Host "`nPress Enter..." }
            "d" { Invoke-SmartRelease $Cfg.VhdPath $Cfg.VMName; Read-Host "`nPress Enter..." }
            "h" { Invoke-VhdTransition -Target "Host" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName | Out-Null }
            "v" { Invoke-VhdTransition -Target "VM" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName | Out-Null }
            "k" { Restart-Service "vds" -Force; Write-Host "[OK] VDS Restarted." -ForegroundColor Green; Start-Sleep -Seconds 2 }
            "r" { & "$scriptsDir\Invoke-VhdPullReturn.ps1" -TargetHostDir $localReturnDir }
            "z" { & "$scriptsDir\Get-VhdLockDiagnostics.ps1"; Read-Host "`nPress Enter..." }
            "l" { & "$scriptsDir\Invoke-VmShortcut.ps1" }
            "sh" { $Cfg.VhdPath = Read-Host "VHD Path"; $Cfg | ConvertTo-Json | Set-Content $ConfigPath }
            "sv" { $Cfg.VMName = Read-Host "VM Name"; $Cfg | ConvertTo-Json | Set-Content $ConfigPath }
            "sg" { $dr = Read-Host "Drive Letter"; if($dr){ $Cfg.GuestStagingDrive = $dr[0]; $Cfg | ConvertTo-Json | Set-Content $ConfigPath } }
            "p" { 
                $newVal = -not $Cfg.UsePasswordCreds
                $Cfg.UsePasswordCreds = [boolean]$newVal
                $Cfg | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath
                Write-Host "Credentials toggled to: $(if($Cfg.UsePasswordCreds){'Password'}else{'Empty (Audit Mode)'})" -ForegroundColor Cyan
                Start-Sleep -Seconds 1 
            }
            Default { Write-Host "Invalid option" -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
        }
    } catch {
        Write-Host "`n[ERROR] Command failed: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to reload dashboard..."
    }
}
