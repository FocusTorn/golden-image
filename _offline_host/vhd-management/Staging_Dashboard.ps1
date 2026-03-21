# Dashboard: ROG Strix VHD Infrastructure Manager
# ---------------------------------------------------------------------------
param([string]$Action)

. (Join-Path $PSScriptRoot "scripts\VhdUtils.ps1")

# --- GUEST SERVICES AUTO-ENABLE ---
function Enable-GuestServicesIfNeeded {
    param([string]$VMName)
    if (-not $VMName) { return }
    $vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if (-not $vm -or $vm.State -ne 'Running') { return }
    try {
        $guestSvc = Get-VMIntegrationService -VMName $VMName -Name "Guest Service Interface" -ErrorAction SilentlyContinue
        if ($guestSvc -and -not $guestSvc.Enabled) {
            Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface" -ErrorAction Stop
            Write-Host "[*] Guest Services enabled on $VMName" -ForegroundColor DarkGray
        }
    } catch { }
}

# --- AUTO-CONTINUE PAUSE ---
function Wait-AutoContinue {
    param([int]$Seconds = 10)
    Write-Host ""
    for ($i = $Seconds; $i -gt 0; $i--) {
        Write-Host "`r  Continuing in ${i}s... [Enter=now | Any key=hold]  " -NoNewline -ForegroundColor DarkGray
        $end = (Get-Date).AddSeconds(1)
        while ((Get-Date) -lt $end) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq 'Enter') { Write-Host ""; return }
                Write-Host "`r                                                    " -NoNewline
                Write-Host "`r  Timer paused." -ForegroundColor Yellow
                Read-Host "  Press Enter to continue"
                return
            }
            Start-Sleep -Milliseconds 50
        }
    }
    Write-Host ""
}

# --- UI HELPERS ---
function Show-VhdHeader {
    $Cfg = Get-Config
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

    $vmRunning = $vmObj -and $vmObj.State -eq 'Running'
    $vmStatus = if ($vmObj) { if ($vmRunning) { "Running" } else { "Stopped" } } else { "-" }
    $hostStatus = if ($hostLetter) { "$($hostLetter):" } else { "-" }
    $stagingStatus = if ($isAtVM) { "VM" } elseif ($hostLetter) { "Host" } else { "-" }
    
    $credsMode = if ($Cfg.UsePasswordCreds -eq $true -or $Cfg.UsePasswordCreds -eq "true") { "Password" } else { "Empty" }

    $headerWidth = 101
    $border = ("=" * $headerWidth)
    $profileLabel = if ($Cfg.ProfileKey) { $Cfg.ProfileKey } else { '(no profile key)' }
    $vhdLeaf = Split-Path $Cfg.VhdPath -Leaf

    $line1 = "VHDX INFRASTRUCTURE MANAGEMENT - $profileLabel"
    $line2 = "VM: $vmStatus | Host: $hostStatus | Staging: $stagingStatus"
    $line3 = "Creds: $credsMode | VHD: $vhdLeaf"

    $centerLine = {
        param(
            [string]$Text,
            [int]$Width
        )
        if ($null -eq $Text) { $Text = "" }
        $value = $Text.Trim()
        if ($value.Length -ge $Width) { return $value.Substring(0, $Width) }
        $padLeft = [Math]::Floor(($Width - $value.Length) / 2)
        return (" " * $padLeft) + $value
    }

    # --- Previous header (all three lines centered in 101 cols) — kept for reference ---
    # Write-Host $border -ForegroundColor Cyan
    # Write-Host (& $centerLine -Text $line1 -Width $headerWidth) -ForegroundColor Cyan
    # Write-Host (& $centerLine -Text $line2 -Width $headerWidth) -ForegroundColor DarkCyan
    # Write-Host (& $centerLine -Text $line3 -Width $headerWidth) -ForegroundColor DarkGray
    # Write-Host $border -ForegroundColor Cyan

    $leftPart = $line2
    $rightPart = $line3
    $padCount = $headerWidth - $leftPart.Length - $rightPart.Length

    Write-Host $border -ForegroundColor Cyan
    Write-Host (& $centerLine -Text $line1 -Width $headerWidth) -ForegroundColor Cyan
    Write-Host ""
    if ($padCount -ge 1) {
        $statusLine = $leftPart + (" " * $padCount) + $rightPart
        Write-Host $statusLine -ForegroundColor DarkCyan
    } else {
        $spaceForLeft = $headerWidth - $rightPart.Length - 1
        if ($spaceForLeft -lt 1) {
            $rightPart = $rightPart.Substring(0, [Math]::Max(1, $headerWidth - 4)) + "..."
            $spaceForLeft = $headerWidth - $rightPart.Length - 1
        }
        $trimmedLeft = if ($leftPart.Length -le $spaceForLeft) {
            $leftPart
        } else {
            $leftPart.Substring(0, [Math]::Max(0, $spaceForLeft - 3)) + "..."
        }
        $gap = $headerWidth - $trimmedLeft.Length - $rightPart.Length
        $statusLine = $trimmedLeft + (" " * [Math]::Max(1, $gap)) + $rightPart
        if ($statusLine.Length -gt $headerWidth) { $statusLine = $statusLine.Substring(0, $headerWidth) }
        Write-Host $statusLine -ForegroundColor DarkCyan
    }
    Write-Host $border -ForegroundColor Cyan
}

function Show-CommandHelp {
    param(
        [string]$GuestDrive,
        [string]$Command
    )
    if ($Command) { $Command = $Command.ToLower().Trim() }
    Write-Host ""
    if ($Command) {
        Write-Host "COMMAND HELP: $Command" -ForegroundColor Cyan
    } else {
        Write-Host "COMMAND HELP" -ForegroundColor Cyan
    }
    Write-Host "------------" -ForegroundColor Cyan
    Write-Host ""

    if ($Command) {
        switch ($Command) {
            "1" { Write-Host "1  Sync _offline" -ForegroundColor Magenta; Write-Host "Copies .\\_offline into the staging drive (VHD mounted on host or attached to VM)." -ForegroundColor Gray; return }
            "2" { Write-Host "2  Sync all" -ForegroundColor Magenta; Write-Host "Copies .\\_offline and .\\installers into the staging drive." -ForegroundColor Gray; return }
            "6" { Write-Host "6  Pull Shit" -ForegroundColor Magenta; Write-Host "Reads `${GuestDrive}:\\shit.txt from inside the VM using PowerShell Direct." -ForegroundColor Gray; return }
            "7" { Write-Host "7  Pull Logs" -ForegroundColor Magenta; Write-Host "Pulls remote logs from the VM into the host log location." -ForegroundColor Gray; return }
            "r" { Write-Host "R  Pull Return" -ForegroundColor Magenta; Write-Host "Pulls files from the VM return folder into .\\return." -ForegroundColor Gray; return }
            "d" { Write-Host "D  Disconnect All" -ForegroundColor Magenta; Write-Host "Detaches the VHD from the VM and dismounts it from the host (best-effort)." -ForegroundColor Gray; return }
            "h" { Write-Host "H  Connect Host" -ForegroundColor Magenta; Write-Host "Mounts the VHD on the host so you can access it via drive letter." -ForegroundColor Gray; return }
            "v" { Write-Host "V  Connect VM" -ForegroundColor Magenta; Write-Host "Attaches the VHD to the configured VM." -ForegroundColor Gray; return }
            "k" { Write-Host "K  Kill VDS" -ForegroundColor Magenta; Write-Host "Restarts the 'vds' service to clear stuck mount / disk management state." -ForegroundColor Gray; return }
            "z" { Write-Host "Z  Lock Diagnostics" -ForegroundColor Magenta; Write-Host "Runs lock diagnostics to help identify why a VHD is stuck 'in use'." -ForegroundColor Gray; return }
            "w" { Write-Host "W  Capture WIM from VHD" -ForegroundColor Magenta; Write-Host "Runs the WIM capture flow for the currently configured VHD (uses default output path rules)." -ForegroundColor Gray; return }
            "iw" { Write-Host "IW Capture WIM from VHD" -ForegroundColor Magenta; Write-Host "Runs New-WimFromVhd.ps1 capture flow. Default output comes from VMDetails.WimDestination (or timestamp default if unset)." -ForegroundColor Gray; return }
            "in" { Write-Host "IN Boot WIM in new VM" -ForegroundColor Magenta; Write-Host "Creates a NEW VM (unique name), applies the selected .wim to its blank OS VHD offline, and prepares boot (leaves VM off)." -ForegroundColor Gray; return }
            "pl" { Write-Host "PL  List" -ForegroundColor Magenta; Write-Host "Lists VM profiles from _master_config.json (key, VMName, Hostname)." -ForegroundColor Gray; return }
            "pf" { Write-Host "PF  Session profile" -ForegroundColor Magenta; Write-Host "Sets `$env:GOLDEN_IMAGE_VM_PROFILE for this PowerShell session (dashboard only)." -ForegroundColor Gray; return }
            "pd" { Write-Host "PD  Set default profile" -ForegroundColor Magenta; Write-Host "Writes defaultVMProfile in _master_config.json (persistent). Removes activeVMProfile so it does not override. Session env still wins when set." -ForegroundColor Gray; return }
            "pc" { Write-Host "PC  Clear env override" -ForegroundColor Magenta; Write-Host "Clears `$env:GOLDEN_IMAGE_VM_PROFILE so profile resolution falls back to master." -ForegroundColor Gray; return }
            "pm" { Write-Host "PM  Resolution" -ForegroundColor Magenta; Write-Host "Shows how the active profile key is resolved (env, activeVMProfile, defaultVMProfile, etc.)." -ForegroundColor Gray; return }
            "pv" { Write-Host "PV  New VM from template" -ForegroundColor Magenta; Write-Host "Creates a VM using the active VM profile for VM details, but a selected provisioning template for hardware/network." -ForegroundColor Gray; return }
            "ch" { Write-Host "CH  Set Config VHD" -ForegroundColor Magenta; Write-Host "Updates the active profile's VhdPath in _master_config.json." -ForegroundColor Gray; return }
            "cv" { Write-Host "CV  Set Config VM" -ForegroundColor Magenta; Write-Host "Updates the active profile's VMName in _master_config.json." -ForegroundColor Gray; return }
            "cg" { Write-Host "CG  Set Config Guest" -ForegroundColor Magenta; Write-Host "Updates GuestStagingDrive (shared + VMFileSystem) in _master_config.json." -ForegroundColor Gray; return }
            "ca" { Write-Host "CA  Toggle Creds" -ForegroundColor Magenta; Write-Host "Toggles UsePasswordCreds in _master_config.json (Password vs Empty/Audit)." -ForegroundColor Gray; return }
            "?" { break }
            "help" { break }
            Default { Write-Host "Unknown command '$Command'." -ForegroundColor Yellow; return }
        }
    }

    Write-Host "Sync operations:" -ForegroundColor Magenta
    Write-Host "  1  Sync _offline            Copy local _offline into the VHD/VM staging drive" -ForegroundColor Gray
    Write-Host "  2  Sync all                 Copy _offline + installers into the VHD/VM staging drive" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Pull (from VM):" -ForegroundColor Magenta
    Write-Host "  6  Pull Shit                Read \`$GuestDrive:\shit.txt from the VM" -ForegroundColor Gray
    Write-Host "  7  Pull Logs                Pull remote logs from the VM" -ForegroundColor Gray
    Write-Host "  R  Pull Return              Pull the VM return folder into .\\return" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Mount control:" -ForegroundColor Magenta
    Write-Host "  D  Disconnect All           Detach VHD from VM and dismount from host" -ForegroundColor Gray
    Write-Host "  H  Connect Host             Mount VHD on host (assign drive letter if available)" -ForegroundColor Gray
    Write-Host "  V  Connect VM               Attach VHD to VM" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Magenta
    Write-Host "  K  Kill VDS                 Restart Volume Shadow Copy / VDS service to clear stuck mounts" -ForegroundColor Gray
    Write-Host "  Z  Lock Diagnostics         Show lock diagnostics for a stuck VHD" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Imaging:" -ForegroundColor Magenta
    Write-Host "  IW Capture WIM from VHD      Capture a WIM image from the mounted VHD" -ForegroundColor Gray
    Write-Host "  IN Boot WIM in new VM        Apply the selected .wim to a new VM OS VHD (offline) and prepare boot (VM left off)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Profiles:" -ForegroundColor Magenta
    Write-Host "  PL List                     List VM profile keys from _master_config.json" -ForegroundColor Gray
    Write-Host "  PF Session profile          Set \`$env:GOLDEN_IMAGE_VM_PROFILE for this session only" -ForegroundColor Gray
    Write-Host "  PD Set default profile      Save defaultVMProfile in master (session env still overrides)" -ForegroundColor Gray
    Write-Host "  PC Clear env override       Clear \`$env:GOLDEN_IMAGE_VM_PROFILE for this session" -ForegroundColor Gray
    Write-Host "  PM Resolution               Show how the active profile key is resolved" -ForegroundColor Gray
    Write-Host "  PV New VM from template     Run New-MasterLikeVm.ps1 using the active profile + a selected provisioning template" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Config (_master_config.json):" -ForegroundColor Magenta
    Write-Host "  CH Set Config VHD          Update the active profile's VHD path in master config" -ForegroundColor Gray
    Write-Host "  CV Set Config VM           Update the active profile's VM name in master config" -ForegroundColor Gray
    Write-Host "  CG Set Config Guest        Update GuestStagingDrive in master config" -ForegroundColor Gray
    Write-Host "  CA Toggle Creds            Toggle UsePasswordCreds in master config" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Help:" -ForegroundColor Magenta
    Write-Host "  ? / help                    Show this help screen" -ForegroundColor Gray
    Write-Host "  <cmd> ? / <cmd> help        Show detailed help for a specific command (ex: 'k ?')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Exit: Ctrl+C" -ForegroundColor DarkGray
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
    $Cfg = Get-Config
    Enable-GuestServicesIfNeeded -VMName $Cfg.VMName
    Show-VhdHeader
    $scriptsDir = Join-Path $PSScriptRoot "scripts"
    $localReturnDir = Join-Path $LocalProjectRoot "return"
    $guestDrive = Get-GuestDriveLetter $Cfg.GuestStagingDrive

    $c2 = 38
    $c3 = 76
    $fmt3 = {
        param(
            [string]$Col1,
            [string]$Col2,
            [string]$Col3
        )
        if ($null -eq $Col1) { $Col1 = "" }
        if ($null -eq $Col2) { $Col2 = "" }
        if ($null -eq $Col3) { $Col3 = "" }
        $a = $Col1
        $b = $Col2
        $c = $Col3
        if ($a.Length -gt $c2) { $a = $a.Substring(0, $c2) }
        $pad12 = [Math]::Max(1, $c2 - $a.Length)
        $bMax = [Math]::Max(0, ($c3 - $c2))
        if ($b.Length -gt $bMax) { $b = $b.Substring(0, $bMax) }
        $pad23 = [Math]::Max(1, $c3 - ($a.Length + $pad12 + $b.Length))
        return $a + (" " * $pad12) + $b + (" " * $pad23) + $c
    }

    Write-Host ""
    Write-Host (& $fmt3 -Col1 "SYNC OPERATIONS:" -Col2 "Pull:" -Col3 "MOUNT CONTROL:") -ForegroundColor Magenta
    Write-Host (& $fmt3 -Col1 "  [1] Sync _offline" -Col2 "  [6] Pull Shit" -Col3 "  [D] Disconnect All") -ForegroundColor Gray
    Write-Host (& $fmt3 -Col1 "  [2] Sync all" -Col2 "  [7] Pull Logs" -Col3 "  [H] Connect Host") -ForegroundColor Gray
    Write-Host (& $fmt3 -Col1 "" -Col2 "  [R] Pull Return" -Col3 "  [V] Connect VM") -ForegroundColor Gray
    Write-Host ""
    Write-Host ""
    Write-Host (& $fmt3 -Col1 "VM PROFILE:" -Col2 "VM CREATION:" -Col3 "CONFIG:") -ForegroundColor Magenta
    Write-Host (& $fmt3 -Col1 "  [PL] List" -Col2 "  [PV] New VM from template" -Col3 "  [CH] Set Config VHD") -ForegroundColor Gray
    Write-Host (& $fmt3 -Col1 "  [PF] Session profile" -Col2 "" -Col3 "  [CV] Set Config VM") -ForegroundColor Gray
    Write-Host (& $fmt3 -Col1 "  [PC] Clear env override" -Col2 "" -Col3 "  [CG] Set Config Guest") -ForegroundColor Gray
    Write-Host (& $fmt3 -Col1 "  [PM] Resolution" -Col2 "" -Col3 "  [CA] Toggle Creds") -ForegroundColor Gray
    Write-Host ""
    Write-Host ""
    Write-Host (& $fmt3 -Col1 "TROUBLESHOOTING:" -Col2 "IMAGING:" -Col3 "") -ForegroundColor Magenta
    Write-Host (& $fmt3 -Col1 "  [K] Kill VDS" -Col2 "  [IW] Capture WIM from VHD" -Col3 "") -ForegroundColor Gray
    Write-Host (& $fmt3 -Col1 "  [Z] Lock Diagnostics" -Col2 "  [IN] Boot WIM in new VM" -Col3 "") -ForegroundColor Gray
    Write-Host ""
    Write-Host ""
    Write-Host "[?] Help | [<command> ?] Targeted Help" -ForegroundColor DarkGray
    $rawChoice = (Read-Host "Select Action")
    $tokens = @($rawChoice -split '\s+' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
    $choice = if ($tokens.Count -gt 0) { $tokens[0].ToLower().Trim() } else { "" }
    $helpTok = if ($tokens.Count -gt 1) { $tokens[1].ToLower().Trim() } else { "" }

    $ErrorActionPreference = "Stop"
    try {
        if ($choice -and ($helpTok -eq "?" -or $helpTok -eq "help")) {
            Show-CommandHelp -GuestDrive $guestDrive -Command $choice
            [void](Read-Host "Press Enter to continue")
            continue
        }
        switch ($choice) {
            "?" { Show-CommandHelp -GuestDrive $guestDrive; [void](Read-Host "Press Enter to continue") }
            "help" { Show-CommandHelp -GuestDrive $guestDrive; [void](Read-Host "Press Enter to continue") }
            "1" { & "$scriptsDir\Invoke-VhdSwoop.ps1" -Sources @("$LocalProjectRoot\_offline") -NoPause; Wait-AutoContinue }
            "2" { & "$scriptsDir\Invoke-VhdSwoop.ps1" -Sources @("$LocalProjectRoot\_offline", "$LocalProjectRoot\installers") -NoPause; Wait-AutoContinue }
            "6" { 
                $creds = Get-VMCreds $Cfg.VMUser $Cfg
                Invoke-Command -VMName $Cfg.VMName -Credential $creds -ScriptBlock { Get-Content "${using:guestDrive}:\shit.txt" }
                Wait-AutoContinue
            }
            "7" { & "$scriptsDir\Get-RemoteLog.ps1" -Category all; Wait-AutoContinue }
            "d" { Invoke-SmartRelease $Cfg.VhdPath $Cfg.VMName; Wait-AutoContinue }
            "h" { Invoke-VhdTransition -Target "Host" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName | Out-Null }
            "v" { Invoke-VhdTransition -Target "VM" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName | Out-Null }
            "k" { Restart-Service "vds" -Force; Write-Host "[OK] VDS Restarted." -ForegroundColor Green; Start-Sleep -Seconds 2 }
            "r" { & "$scriptsDir\Invoke-VhdPullReturn.ps1" -TargetHostDir $localReturnDir -NoPause; Wait-AutoContinue }
            "z" { & "$scriptsDir\Get-VhdLockDiagnostics.ps1"; Wait-AutoContinue }
            "w" { & "$scriptsDir\New-WimFromVhd.ps1" -NoPause; Wait-AutoContinue }
            "iw" { & "$scriptsDir\New-WimFromVhd.ps1" -NoPause; Wait-AutoContinue }
            "in" { & "$scriptsDir\Boot-WimInNewVm.ps1" -NoPause; Wait-AutoContinue }
            "ch" { $p = Read-Host "VHD Path"; if ($p) { Save-HostVmSettingsToMaster -VhdPath $p } }
            "cv" { $n = Read-Host "VM Name"; if ($n) { Save-HostVmSettingsToMaster -VMName $n } }
            "cg" { $dr = Read-Host "Drive Letter"; if ($dr) { Save-HostVmSettingsToMaster -GuestStagingDrive $dr[0] } }
            "ca" { 
                $newVal = -not ($Cfg.UsePasswordCreds -eq $true -or $Cfg.UsePasswordCreds -eq "true")
                Save-HostVmSettingsToMaster -UsePasswordCreds $newVal
                Write-Host "Credentials toggled to: $(if($newVal){'Password'}else{'Empty (Audit Mode)'})" -ForegroundColor Cyan
                Start-Sleep -Seconds 1 
            }
            "pl" {
                try {
                    $m = Read-JsonCFile -Path $MasterConfigPath
                    $names = Get-VmProfileNames -Master $m
                    Write-Host "`nVM profiles (_master_config):" -ForegroundColor Cyan
                    foreach ($n in $names) {
                        try {
                            $sec = Get-VmProfileSection -Master $m -ProfileKey $n
                            $vn = $sec.VMDetails.VMName
                            $vh = $sec.VMDetails.VMHostname
                            Write-Host "  $n" -ForegroundColor White -NoNewline
                            Write-Host "  -> VMName=$vn  Hostname=$vh" -ForegroundColor DarkGray
                        } catch {
                            Write-Host "  $n  (invalid section: $_)" -ForegroundColor Yellow
                        }
                    }
                    if ($names.Count -eq 0) { Write-Host "  (none — add VMProfiles in _master_config.json)" -ForegroundColor Yellow }
                } catch {
                    Write-Host "[ERROR] $_" -ForegroundColor Red
                }
                Wait-AutoContinue
            }
            "pf" {
                try {
                    $m = Read-JsonCFile -Path $MasterConfigPath
                    $names = Get-VmProfileNames -Master $m
                    Write-Host "`nSelect profile for this dashboard session only (`$env:GOLDEN_IMAGE_VM_PROFILE)." -ForegroundColor Cyan
                    for ($i = 0; $i -lt $names.Count; $i++) {
                        Write-Host ("  {0}. {1}" -f ($i + 1), $names[$i]) -ForegroundColor Gray
                    }
                    $sel = Read-Host "Number or profile key (blank = cancel)"
                    if ([string]::IsNullOrWhiteSpace($sel)) { break }
                    $sel = $sel.Trim()
                    $key = $null
                    if ($sel -match '^\d+$') {
                        $idx = [int]$sel - 1
                        if ($idx -ge 0 -and $idx -lt $names.Count) { $key = $names[$idx] }
                    } else {
                        $key = ($names | Where-Object { $_ -ieq $sel } | Select-Object -First 1)
                        if (-not $key -and ($names -contains $sel)) { $key = $sel }
                    }
                    if (-not $key) {
                        Write-Host "Unknown or invalid selection." -ForegroundColor Red
                    } else {
                        $env:GOLDEN_IMAGE_VM_PROFILE = $key
                        Write-Host "Session profile set to '$key'. New Get-Config calls use this until you exit or use PC." -ForegroundColor Green
                    }
                } catch {
                    Write-Host "[ERROR] $_" -ForegroundColor Red
                }
                Wait-AutoContinue
            }
            "pd" {
                try {
                    $m = Read-JsonCFile -Path $MasterConfigPath
                    $names = Get-VmProfileNames -Master $m
                    Write-Host "`nSet permanent default profile (writes defaultVMProfile in _master_config.json)." -ForegroundColor Cyan
                    Write-Host "`$env:GOLDEN_IMAGE_VM_PROFILE still overrides for this and other sessions when set." -ForegroundColor DarkGray
                    for ($i = 0; $i -lt $names.Count; $i++) {
                        Write-Host ("  {0}. {1}" -f ($i + 1), $names[$i]) -ForegroundColor Gray
                    }
                    $sel = Read-Host "Number or profile key (blank = cancel)"
                    if ([string]::IsNullOrWhiteSpace($sel)) { break }
                    $sel = $sel.Trim()
                    $key = $null
                    if ($sel -match '^\d+$') {
                        $idx = [int]$sel - 1
                        if ($idx -ge 0 -and $idx -lt $names.Count) { $key = $names[$idx] }
                    } else {
                        $key = ($names | Where-Object { $_ -ieq $sel } | Select-Object -First 1)
                        if (-not $key -and ($names -contains $sel)) { $key = $sel }
                    }
                    if (-not $key) {
                        Write-Host "Unknown or invalid selection." -ForegroundColor Red
                    } else {
                        Save-DefaultVmProfileToMaster -ProfileKey $key
                        Write-Host "Default profile is now '$key' (until changed with PD again)." -ForegroundColor Green
                    }
                } catch {
                    Write-Host "[ERROR] $_" -ForegroundColor Red
                }
                Wait-AutoContinue
            }
            "pc" {
                if ($env:GOLDEN_IMAGE_VM_PROFILE) {
                    Remove-Item -Path "Env:\GOLDEN_IMAGE_VM_PROFILE" -ErrorAction SilentlyContinue
                    Write-Host "Cleared `$env:GOLDEN_IMAGE_VM_PROFILE. Resolution falls back to master default/active." -ForegroundColor Green
                } else {
                    Write-Host "No session profile env override was set." -ForegroundColor DarkGray
                }
                Start-Sleep -Seconds 2
            }
            "pm" {
                try {
                    $s = Get-ProfileResolutionSummary
                    Write-Host "`nProfile resolution:" -ForegroundColor Cyan
                    Write-Host "  GOLDEN_IMAGE_VM_PROFILE (process): $($s.EnvGOLDEN_IMAGE_VM_PROFILE)" -ForegroundColor Gray
                    Write-Host "  master.activeVMProfile:            $($s.MasterActiveVMProfile)" -ForegroundColor Gray
                    Write-Host "  master.defaultVMProfile:          $($s.MasterDefaultVMProfile)" -ForegroundColor Gray
                    Write-Host "  Resolved profile key:              $($s.ResolvedProfileKey)" -ForegroundColor White
                } catch {
                    Write-Host "[ERROR] $_" -ForegroundColor Red
                }
                Wait-AutoContinue
            }
            "pv" {
                try {
                    $m = Read-JsonCFile -Path $MasterConfigPath
                    $activePk = Get-ActiveVmProfileKey -Master $m
                    $ctx = Build-MergedHostVmConfig -Master $m -ProfileKey $activePk

                    $defaultTpl = $ctx.HardwareTemplateKey
                    $tplNames = @()
                    if ($null -ne $m.VMProvisioningTemplates) {
                        $tplNames = @($m.VMProvisioningTemplates.PSObject.Properties | ForEach-Object { $_.Name })
                    }
                    if ($tplNames.Count -eq 0) { throw "VMProvisioningTemplates has no entries." }

                    Write-Host "`nCreate a NEW VM (VM details from active profile, hardware/network from provisioning template)." -ForegroundColor Yellow
                    Write-Host "Active VM profile: $activePk" -ForegroundColor DarkYellow
                    Write-Host "Default provisioning template: $defaultTpl" -ForegroundColor DarkYellow

                    for ($i = 0; $i -lt $tplNames.Count; $i++) {
                        Write-Host ("  {0}. {1}" -f ($i + 1), $tplNames[$i]) -ForegroundColor Gray
                    }

                    $sel = Read-Host "Number or template key (blank = default: $defaultTpl)"
                    $sel = $sel.Trim()
                    $tplKey = $null

                    if ([string]::IsNullOrWhiteSpace($sel)) {
                        $tplKey = $defaultTpl
                    } elseif ($sel -match '^\d+$') {
                        $idx = [int]$sel - 1
                        if ($idx -ge 0 -and $idx -lt $tplNames.Count) { $tplKey = $tplNames[$idx] }
                    } else {
                        $tplKey = ($tplNames | Where-Object { $_ -ieq $sel } | Select-Object -First 1)
                    }

                    if ([string]::IsNullOrWhiteSpace($tplKey)) {
                        Write-Host "Unknown or invalid selection." -ForegroundColor Red
                    } else {
                        $helper = Join-Path $scriptsDir "New-MasterLikeVm.ps1"
                        if (-not (Test-Path -LiteralPath $helper)) {
                            Write-Host "Script missing: $helper" -ForegroundColor Red
                        } else {
                            & $helper -VMProfile $activePk -ProvisioningTemplateKey $tplKey
                        }
                    }
                } catch {
                    Write-Host "[ERROR] $_" -ForegroundColor Red
                }
                Wait-AutoContinue
            }
            Default { Write-Host "Invalid option" -ForegroundColor Yellow; Start-Sleep -Seconds 1 }
        }
    } catch {
        Write-Host "`n[ERROR] Command failed: $($_.Exception.Message)" -ForegroundColor Red
        Wait-AutoContinue
    }
}
