# Dashboard: GoldenImager v2 (Industrial Slab Edition) - v2.5 FINAL LOCK
# ---------------------------------------------------------------------------
param([string]$Action)

#>- CORE INITIALIZATION  ------------------------------------- 
$ProgressPreference = 'SilentlyContinue'
function Assert-NotNull {
    param($Value, $Name)
    if ($null -eq $Value -or ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value))) {
        throw "Critical variable '$Name' is null or empty. Check configuration and environment."
    }
}

function Assert-Path {
    param([string]$Path, [string]$Name)
    Assert-NotNull -Value $Path -Name $Name
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Path '$Name' does not exist (check drives/network): $Path"
    }
}

Assert-Path -Path $PSScriptRoot -Name "PSScriptRoot"
. (Join-Path $PSScriptRoot "scripts\VhdUtils.ps1")

Assert-Path -Path $MasterConfigPath -Name "MasterConfigPath"
$m = Read-JsonCFile -Path $MasterConfigPath
Assert-NotNull -Value $m -Name "MasterConfigObject"

$activePk = Get-ActiveVmProfileKey -Master $m
Assert-NotNull -Value $activePk -Name "ActiveProfileKey"

$Cfg = Build-MergedHostVmConfig -Master $m -ProfileKey $activePk
Assert-NotNull -Value $Cfg -Name "MergedConfig"

$ScriptsDir = Join-Path $PSScriptRoot "scripts"
Assert-Path -Path $ScriptsDir -Name "ScriptsDir"

$LocalProjectRoot = if ($m.LocalProjectRoot) { $m.LocalProjectRoot } elseif ($Cfg.LocalProjectRoot) { $Cfg.LocalProjectRoot } else { 
    $p1 = Split-Path $PSScriptRoot -Parent
    $p2 = if ($p1) { Split-Path $p1 -Parent }
    $p3 = if ($p2) { Split-Path $p2 -Parent }
    if (-not $p3) { throw "Could not resolve LocalProjectRoot from $PSScriptRoot depth." }
    $p3
}

Assert-Path -Path $LocalProjectRoot -Name "LocalProjectRoot"

#<


#------------------------------------------------------------ 
#---  PATHING   ---------------------------------------------
#------------------------------------------------------------

$OrriginalOSImage = "N:\OS_Images\Win11_25H2_English_x64.iso"

$FatVanillaOSImage = "N:\OS_Images\Win11_Vanilla_ZeroTouch.iso"

$SlimVanillaOSImage = "N:\OS_Images\Win11_Pro_Slim_Vanilla.iso"
$SlimMasterImage = "N:\OS_Images\Win11_Pro_Final_Master.iso"

$TinyVanillaOSImage = "N:\Win11_Pro_Tiny_Vanilla.iso"
$TinyMasterImage = "N:\Win11_Pro_Tiny_Master.iso"

$unattendXml = "N:\_autounattend\autounattend.xml"
$unattendIso = "N:\_autounattend\autounattend.iso"


#------------------------------------------------------------ 
#---  UI CONSTANTS   ----------------------------------------
#------------------------------------------------------------

$HeaderWidth = 101
$ColumnWidths = @(38, 76)

function Get-PaddedLine { #>
    param([string]$Left, [string]$Right, [int]$Width = $Global:HeaderWidth)
    $pad = $Width - ($Left.Length + $Right.Length)
    if ($pad -lt 1) { return "$Left $Right" }
    return "$Left" + (" " * $pad) + "$Right"
} #<

function Show-DashboardHeader { #>
    $currentCfg = Get-Config
    $vmObj = Get-VM -Name $currentCfg.VMName -ErrorAction SilentlyContinue
    $vhdExists = Test-Path $currentCfg.VhdPath
    $isAtVM = if ($vmObj) { Get-VmDriveForVhd -VhdPath $currentCfg.VhdPath -VMName $currentCfg.VMName }
    $hostLetter = "-"
    if ($vhdExists) {
        $vhdInfo = Get-VhdInfoSafe -VhdPath $currentCfg.VhdPath
        if ($vhdInfo -and $vhdInfo.Attached -and $null -ne $vhdInfo.DiskNumber) {
            $part = Get-Partition -DiskNumber $vhdInfo.DiskNumber | Get-Volume | Where-Object DriveLetter
            if ($part) { $hostLetter = "$($part.DriveLetter):" }
        }
    }
    $vmStatus = if ($vmObj) { if ($vmObj.State -eq 'Running') { "Running" } else { "Stopped" } } else { "-" }
    $stagingLoc = if ($isAtVM) { "VM" } elseif ($hostLetter -ne "-") { "Host" } else { "-" }
    $credsMode = if ($currentCfg.UsePasswordCreds -match "true|True") { "Password" } else { "Empty" }
    $border = "=" * $HeaderWidth
    $line1 = "VHDX INFRASTRUCTURE MANAGEMENT - $($currentCfg.ProfileKey)"
    $line2 = "VM: $vmStatus | Host: $hostLetter | Staging: $stagingLoc"
    $line3 = "Creds: $credsMode | VHD: $(Split-Path $currentCfg.VhdPath -Leaf)"
    Write-Host $border -ForegroundColor Cyan
    Write-Host ([string]::Format("{0," + ([Math]::Floor(($HeaderWidth + $line1.Length) / 2) ) + "}", $line1)) -ForegroundColor Cyan
    Write-Host ""
    Write-Host (Get-PaddedLine -Left $line2 -Right $line3) -ForegroundColor DarkCyan
    Write-Host $border -ForegroundColor Cyan
} #<

function Write-GridRow { #>
    param([string]$C1, [string]$C2, [string]$C3)
    $p1 = $ColumnWidths[0]; $p2 = $ColumnWidths[1]
    $s1 = if ($C1.Length -gt $p1) { $C1.Substring(0, $p1) } else { $C1.PadRight($p1) }
    $s2 = if ($C2.Length -gt ($p2-$p1)) { $C2.Substring(0, ($p2-$p1)) } else { $C2.PadRight($p2-$p1) }
    Write-Host "$s1$s2$C3" -ForegroundColor Gray
} #<


#------------------------------------------------------------ 
#---  PROCESS HELPERS   -------------------------------------
#------------------------------------------------------------

function Wait-AutoContinue { #>
    param([int]$Seconds = 10)
    Write-Host ""
    for ($i = $Seconds; $i -gt 0; $i--) {
        Write-Host "`r  Continuing in ${i}s... [Enter=now | Any key=hold]  " -NoNewline -ForegroundColor DarkGray
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'Enter') { break }
            Write-Host "`r  Timer paused. Press Enter to continue...          " -ForegroundColor Yellow
            [void](Read-Host)
            break
        }
        Start-Sleep -Milliseconds 1000
    }
} #<

function Invoke-ProtectedAction { #>
    param([Parameter(Mandatory)] [scriptblock]$Action, [string]$Label = "Action", [switch]$NoPause, [switch]$ShowProgress, [switch]$ManualPause)
    $ProgressPreference = if ($ShowProgress) { "Continue" } else { "SilentlyContinue" }
    try { & $Action; Write-Host "[OK] $Label completed." -ForegroundColor Green }
    catch { 
        $msg = $_.Exception.Message
        $line = $_.InvocationInfo.ScriptLineNumber
        $file = if ($_.InvocationInfo.ScriptName) { Split-Path $_.InvocationInfo.ScriptName -Leaf } else { "Internal" }
        Write-Host "`n[ERROR] $Label failed: $msg" -ForegroundColor Red
        Write-Host "        -> Location: $file : $line" -ForegroundColor DarkRed
        if ($_.InvocationInfo.PositionMessage) {
            Write-Host "        -> Context: $($_.InvocationInfo.PositionMessage.Trim() -replace "`n", " ") " -ForegroundColor Gray
        }
        if ($_.ScriptStackTrace) {
            Write-Host "        -> Trace: $($_.ScriptStackTrace.Split("`n")[0].Trim())" -ForegroundColor DarkGray
        }
        Read-Host "`n[!] CRITICAL ERROR: Press Enter to return to menu" 
        return
    }
    if ($ManualPause) { 
        Write-Host ""
        [void](Read-Host "[READY] Build complete. Audit the logs above, then press ENTER to return to menu")
    } elseif (-not $NoPause) { 
        Wait-AutoContinue 
    }
} #<


#------------------------------------------------------------ 
#---  EXECUTION ENGINES   -----------------------------------
#------------------------------------------------------------

function Invoke-AutomatedBake { #>
    try {
        $m = Read-JsonCFile -Path $MasterConfigPath
        $activePk = Get-ActiveVmProfileKey -Master $m
        $ctx = Build-MergedHostVmConfig -Master $m -ProfileKey $activePk
        Write-Host "`n>>> [BUILD ENGINE] Synchronizing VM Lifecycle..." -ForegroundColor White
        
        $vmObj = Get-VM -Name $ctx.VMName -ErrorAction SilentlyContinue
        $osPath = ($ctx.OsVhdPath -replace '/', '\')
        $vmFolder = Split-Path (Split-Path $osPath -Parent) -Parent 
        
        $envFound = if ($vmObj) { $true } elseif (Test-Path -LiteralPath $osPath) { $true } elseif (Test-Path -LiteralPath $vmFolder) { $true } else { $false }
        if ($envFound) {
            Write-Host "[!] Existing environment artifacts found at: $vmFolder" -ForegroundColor Red
            Write-Host "    [CONFIRM] Deep-wipe existing VM and Physical Storage? [Y/n]: " -NoNewline -ForegroundColor Yellow
            $resp = Read-Host
            if ([string]::IsNullOrWhiteSpace($resp) -or $resp -ieq 'y') {
                if ($vmObj) { Stop-VM -Name $ctx.VMName -Force -ErrorAction SilentlyContinue; Remove-VM -Name $ctx.VMName -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 }
                $locks = Get-Process | Where-Object { $_.Name -match "dism|robocopy|oscdimg" }
                if ($locks) { $locks | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1 }
                Dismount-VHD -Path $osPath -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1
                if (Test-Path -LiteralPath $osPath) { for ($i=0; $i -lt 5; $i++) { try { Remove-Item -LiteralPath $osPath -Force -ErrorAction Stop; break } catch { Start-Sleep -Seconds 1 } } }
                if (Test-Path -LiteralPath $vmFolder) { for ($i=0; $i -lt 5; $i++) { try { Remove-Item -LiteralPath $vmFolder -Recurse -Force -ErrorAction Stop; break } catch { Start-Sleep -Seconds 1 } } }
                Write-Host "    [OK] Deep wipe complete." -ForegroundColor Green
            } else { throw "Build aborted." }
        }
        Write-Host "`n>>> [BUILD ENGINE] Provisioning fresh environment..." -ForegroundColor White
        & "$ScriptsDir\New-MasterLikeVm.ps1" -VMProfile $activePk -ProvisioningTemplateKey $($ctx.HardwareTemplateKey) -NoConfigSave -SkipStagingVhd
        if ($LASTEXITCODE -ne 0) { throw "New-MasterLikeVm failed." }
        Set-VM -Name $ctx.VMName -AutomaticStartAction Nothing | Out-Null
        Start-Sleep -Seconds 3; Start-VM -Name $ctx.VMName -ErrorAction Stop
    } catch { 
        $msg = $_.Exception.Message
        $line = $_.InvocationInfo.ScriptLineNumber
        $file = if ($_.InvocationInfo.ScriptName) { Split-Path $_.InvocationInfo.ScriptName -Leaf } else { "Internal" }
        Write-Host "[ERROR] Bake failed: $msg" -ForegroundColor Red
        Write-Host "        -> Location: $file : $line" -ForegroundColor DarkRed
    }
} #<

function Invoke-MasteringStage { #>
    param([string]$Key, [string]$StepArg = "")

    $SlimMasterImageFileName = Split-Path -Path $SlimMasterImage -Leaf

    switch ($Key) {
        "S0" {  #>
            Assert-Path -Path $OrriginalOSImage -Name "OrriginalOSImage"
            & "$ScriptsDir\Optimize-SourceIso.ps1" -SourcePath $OrriginalOSImage -DestinationPath "N:\" -Tiny
        } #<
        "R0" {  #>
            Assert-Path -Path $OrriginalOSImage -Name "OrriginalOSImage"
            & "$ScriptsDir\Optimize-SourceIso.ps1" -SourcePath $OrriginalOSImage -DestinationPath "N:\" -Tiny -Interactive -Steps $StepArg
        } #<
        "S1" {  #>
            Assert-Path -Path $OrriginalOSImage -Name "OrriginalOSImage"
            & "$ScriptsDir\Optimize-SourceIso.ps1" -SourcePath $OrriginalOSImage -DestinationPath "N:\" 
        } #<
        "S2" {  #>
            Assert-Path -Path $unattendXml -Name "unattendXml"
            $isoPayload = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            $isoInstallers = New-Item -ItemType Directory -Path (Join-Path $isoPayload "installers") -Force
            Assert-Path -Path $isoInstallers.FullName -Name "isoInstallers"

            $ps7 = Get-ChildItem -Path "$PSScriptRoot\..\..\installers\PowerShell-7*.msi" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ps7) { 
                Write-Host "[*] Staging PS7 Payload: $($ps7.Name)" -ForegroundColor Cyan
                Copy-Item -Path $ps7.FullName -Destination $isoInstallers.FullName -Force 
            } else {
                Write-Host "[!] WARN: PS7 MSI not found in installers/ - ISO will skip payload." -ForegroundColor Yellow
            }
            try { 
                $worker = Join-Path $ScriptsDir "New-AutoUnattendIso.ps1"
                Assert-Path -Path $worker -Name "New-AutoUnattendIso script"
                & $worker -SourceFile $unattendXml -DestinationIso "N:\unattend.iso" -PayloadFolder $isoPayload 
                
                # --- ISO VERIFICATION LOOP ---
                Write-Host "`n>>> [BUILD AUDIT] Verifying ISO Payload Integrity..." -ForegroundColor White
                $mount = Mount-DiskImage -ImagePath "N:\unattend.iso" -PassThru -ErrorAction SilentlyContinue
                if ($mount) {
                    Start-Sleep -Seconds 1 # Settle
                    $vol = $mount | Get-Volume -ErrorAction SilentlyContinue
                    if ($vol) {
                        $drive = "$($vol.DriveLetter):\"
                        Write-Host "[*] Mounted as $drive - Reading Payload Tree:" -ForegroundColor Gray
                        Show-Tree -Path $drive
                    }
                    Dismount-DiskImage -ImagePath "N:\unattend.iso" -ErrorAction SilentlyContinue | Out-Null
                    Write-Host "[OK] Audit complete. ISO healthy and ready for deployment." -ForegroundColor Green
                }
            } finally { 
                if ($isoPayload -and (Test-Path $isoPayload)) {
                    Remove-Item -Path $isoPayload -Recurse -Force -ErrorAction SilentlyContinue 
                }
            }
        } #<
        "S3" {  #>
            Assert-Path -Path $SlimVanillaOSImage -Name "SlimVanillaOSImage"
            & "$ScriptsDir\Bake-FinalIso.ps1" -VanillaIsoPath $SlimVanillaOSImage -SourceXml $unattendXml -TargetName $SlimMasterImageFileName 
        } #<
        "SF" {  #>
            Assert-Path -Path $SlimVanillaOSImage -Name "SlimVanillaOSImage"
            & "$ScriptsDir\Bake-FinalIso.ps1" -VanillaIsoPath $SlimVanillaOSImage -SourceXml $unattendXml -TargetName $SlimMasterImageFileName 
        } #<
        "SI" {  #>
            Assert-Path -Path $SlimMasterImage -Name "SlimMasterImage"
            $env:GOLDEN_IMAGE_ISO_OVERRIDE = $SlimMasterImage; try { Invoke-AutomatedBake } finally { Remove-Item "Env:\GOLDEN_IMAGE_ISO_OVERRIDE" -ErrorAction SilentlyContinue } 
        } #<
        "SD" {  #>
            Assert-Path -Path $SlimVanillaOSImage -Name "SlimVanillaOSImage"
            $env:GOLDEN_IMAGE_ISO_OVERRIDE = $SlimVanillaOSImage; try { Invoke-AutomatedBake } finally { Remove-Item "Env:\GOLDEN_IMAGE_ISO_OVERRIDE" -ErrorAction SilentlyContinue } 
        } #<
        "TD" {  #>
            Assert-Path -Path $TinyVanillaOSImage -Name "TinyVanillaOSImage"
            $env:GOLDEN_IMAGE_ISO_OVERRIDE = $TinyVanillaOSImage; try { Invoke-AutomatedBake } finally { Remove-Item "Env:\GOLDEN_IMAGE_ISO_OVERRIDE" -ErrorAction SilentlyContinue } 
        } #<
    }
} #<

function Show-Tree { #>
    param([string]$Path, [string]$Indent = "")
    $items = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt $items.Count; $i++) {
        $item = $items[$i]
        $isLast = ($i -eq $items.Count - 1)
        
        # PS 5.1 compatible branch logic
        $branch = "├── "
        if ($isLast) { $branch = "└── " }
        
        Write-Host "$Indent$branch$($item.Name)" -ForegroundColor Gray
        if ($item.PSIsContainer) {
            # PS 5.1 compatible indent logic
            $p = "│   "
            if ($isLast) { $p = "    " }
            $newIndent = $Indent + $p
            Show-Tree -Path $item.FullName -Indent $newIndent
        }
    }
} #<



#-------------------------------------------------------------------------------- 
#---  MAIN CAPTURE & LOOP  ------------------------------------------------------
#--------------------------------------------------------------------------------

# Capture parameter once, then explicitly kill the variable in the script scope
$CapturedCLIAction = $Action
$Action = $null 

try {
    while ($true) {
        # Total Flush of input buffer to prevent "Phantom Echoes"
        if ($Host.UI.RawUI.KeyAvailable) { [void]$Host.UI.RawUI.FlushInputBuffer() }
        
        Clear-Host
        $currentCfg = Get-Config
        Show-DashboardHeader
        
        Write-Host "`nSYNC OPERATIONS:                              PULL:                           MOUNT CONTROL:" -ForegroundColor Magenta
        Write-GridRow -C1 "  [1] Sync _offline"       -C2 "  [6] Pull Shit"            -C3 "  [D] Disconnect All"
        Write-GridRow -C1 "  [2] Sync all"           -C2 "  [7] Pull Logs"            -C3 "  [H] Connect Host"
        Write-GridRow -C1 "  [E] Edit Exclusions"    -C2 "  [R] Pull Return"          -C3 "  [V] Connect VM"
        
        Write-Host "`nSLIMPRO MASTERING:                            VM PROFILE:                          CONFIG:" -ForegroundColor Magenta
        Write-GridRow -C1 "  [S0] Bake Tiny-OS ISO"   -C2 "  [PL] List"                -C3 "  [CH] Set Path (VHD)"
        Write-GridRow -C1 "  [R0] Resume / Interactive" -C2 "  [PF] Session Profile"     -C3 "  [CV] Set Name (VM)"
        Write-GridRow -C1 "  [S1] Bake Slim-OS ISO"   -C2 " [PC] Clear Env"            -C3 "  [CG] Set Guest Drive"
        Write-GridRow -C1 "  [S2] Bake unattend.iso"  -C2 "  [PF] Session Profile"     -C3 "  [CV] Set Name (VM)"
        Write-GridRow -C1 "  [S3] Bake injected ISO"  -C2 "  [PC] Clear Env"           -C3 "  [CG] Set Guest Drive"
        Write-GridRow -C1 "  [SF] Bake Slimpro (Final ISO)" -C2 "  [PM] Resolution"     -C3 "  [CA] Toggle Creds"
        Write-GridRow -C1 "  [SI] Single ISO Install" -C2 "  [PV] New from Template"   -C3 ""
        Write-GridRow -C1 "  [SD] Dual ISO Install"   -C2 "  [PA] Original Engine (PA)" -C3 ""
        Write-GridRow -C1 "  [TD] Dual Tiny ISO Install"   -C2 ""                            -C3 ""

        Write-Host "`n[?] Help | [X] Exit Dashboard" -ForegroundColor DarkGray
        
        $choice = if ($CapturedCLIAction) { 
            $tmp = $CapturedCLIAction; $CapturedCLIAction = $null; 
            Write-Host ">>> [CLI] Executing Capture: $tmp" -ForegroundColor Cyan; $tmp 
        } else { (Read-Host "Select Action") }

        if ([string]::IsNullOrWhiteSpace($choice)) { continue }
        $choice = $choice.ToLower().Trim()

        switch -Wildcard ($choice) {
            "1"  { Invoke-ProtectedAction -Label "Sync" -Action { Invoke-SyncAction -Sources @((Join-Path $LocalProjectRoot $currentCfg.OfflinePath)) }; break }
            "2"  { Invoke-ProtectedAction -Label "Full" -Action { Invoke-SyncAction -Sources @((Join-Path $LocalProjectRoot $currentCfg.OfflinePath), (Join-Path $LocalProjectRoot $currentCfg.InstallersPath)) }; break }
            "e"  { Invoke-Item (Join-Path $PSScriptRoot ".syncignore"); break }
            "d"  { Invoke-ProtectedAction -Label "Release" -Action { Invoke-SmartRelease $currentCfg.VhdPath $currentCfg.VMName }; break }
            "h"  { Invoke-ProtectedAction -Label "Host"   -Action { Invoke-VhdTransitionAction -Target "Host" } -NoPause; break }
            "v"  { Invoke-ProtectedAction -Label "VM"     -Action { Invoke-VhdTransitionAction -Target "VM" } -NoPause; break }
            "pl" { Invoke-ProtectedAction -Label "List"   -Action { $names = Get-VmProfileNames -Master (Read-JsonCFile $MasterConfigPath); foreach($n in $names){Write-Host "  $n"} }; break }
            "pf" { Action-ProfileSelect -Perm $false; break }
            "pd" { Action-ProfileSelect -Perm $true; break }
            "pc" { if($env:GOLDEN_IMAGE_VM_PROFILE){Remove-Item "Env:\GOLDEN_IMAGE_VM_PROFILE"}; break }
            "ch" { Action-UpdateConfig -Target "VHD"; break }
            "cv" { Action-UpdateConfig -Target "VM"; break }
            "cg" { Action-UpdateConfig -Target "Guest"; break }
            "ca" { $nv=-not($currentCfg.UsePasswordCreds -match "true"); Save-HostVmSettingsToMaster -UsePasswordCreds $nv; break }
            "s0" { Invoke-ProtectedAction -Label "S0" -Action { Invoke-MasteringStage -Key "S0" } -ShowProgress -ManualPause; break }
            "r0" { Invoke-ProtectedAction -Label "R0" -Action { Invoke-MasteringStage -Key "R0" -StepArg $arg } -ShowProgress; break }
            "s1" { Invoke-ProtectedAction -Label "S1" -Action { Invoke-MasteringStage -Key "S1" } -ShowProgress -ManualPause; break }
            "s2" { Invoke-ProtectedAction -Label "S2" -Action { Invoke-MasteringStage -Key "S2" } -ShowProgress; break }
            "s3" { Invoke-ProtectedAction -Label "S3" -Action { Invoke-MasteringStage -Key "S3" } -ShowProgress; break }
            "sf" { Invoke-ProtectedAction -Label "SF" -Action { Invoke-MasteringStage -Key "SF" } -ShowProgress; break }
            "si" { Invoke-ProtectedAction -Label "SI" -Action { Invoke-MasteringStage -Key "SI" }; break }
            "sd" { Invoke-ProtectedAction -Label "SD" -Action { Invoke-MasteringStage -Key "SD" }; break }
            "td" { Invoke-ProtectedAction -Label "TD" -Action { Invoke-MasteringStage -Key "TD" } -ShowProgress; break }
            "pa" { Invoke-ProtectedAction -Label "PA" -Action { Invoke-AutomatedBake }; break }
            "x"  { exit 0 }
            "?"  { & "$ScriptsDir\Show-DashboardHelp.ps1"; [void](Read-Host "Press Enter"); break }
            "*"  { if($choice){Write-Host "Unknown: $choice"; Start-Sleep -Seconds 1}; break }
        }
    }
} finally { }
