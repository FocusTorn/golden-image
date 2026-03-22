#Requires -RunAsAdministrator
#Requires -Modules Hyper-V
<#
.SYNOPSIS
    Apply a captured WIM into a NEW blank VM OS VHD and prepare boot (offline).

.DESCRIPTION
    `[IN]` workflow helper for the staging dashboard:
    - Create a unique VM using the active VM profile (hardware/network from provisioning template).
    - Detach the OS VHD from the VM.
    - Partition (UEFI), apply WIM offline via DISM, and run bcdboot.
    - Reattach the OS VHD to the VM.

    The VM is left OFF ("prepare only").
#>
[CmdletBinding(SupportsShouldProcess = $false)]
param(
    [switch]$NoPause,
    [int]$WimIndex = 1
)

$ErrorActionPreference = 'Stop'

# Resolve repo root relative to this script
$LocalProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $LocalProjectRoot "_helpers\ConfigUtils.ps1")
. (Join-Path $PSScriptRoot "VhdUtils.ps1")

$Cfg = Get-Config
 $master = Read-JsonCFile -Path (Join-Path $LocalProjectRoot "_master_config.json")

function Resolve-WimPath {
    param(
        [Parameter(Mandatory = $true)][string]$WimDestination
    )
    $wd = $WimDestination.Trim()
    if ([string]::IsNullOrWhiteSpace($wd)) {
        throw "VMDetails.WimDestination is empty. Set it in _master_config.json (under VMProfiles.<key>.VMDetails)."
    }

    # If the configured file exists, use it.
    if (Test-Path -LiteralPath $wd) { return $wd }

    # Otherwise, scan the directory for any *.wim and pick the newest.
    $dir = Split-Path $wd -Parent
    if (-not $dir -or -not (Test-Path -LiteralPath $dir)) {
        throw "WimDestination not found: $wd (and directory doesn't exist: $dir)."
    }

    $wims = @(Get-ChildItem -Path $dir -Filter "*.wim" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending)

    if ($wims.Count -eq 0) {
        throw "No .wim files found in directory: $dir"
    }
    return $wims[0].FullName
}

$wimDestination = $Cfg.WimDestination
if ([string]::IsNullOrWhiteSpace($wimDestination)) {
    # Fallback: use the default profile's WimDestination if the active profile doesn't define one.
    $defaultProfile = $master.defaultVMProfile
    $wimDestination = $master.VMProfiles.$defaultProfile.VMDetails.WimDestination
}

$wimPath = Resolve-WimPath -WimDestination $wimDestination
$wimPath = ($wimPath.ToString() -replace '/', '\').Trim()
$wimPath = $wimPath.Trim('"').Trim()
$tplKey = $Cfg.HardwareTemplateKey
$pk = $Cfg.ProfileKey

$baseName = $Cfg.VMName
$safeBase = ($baseName -replace '[^\w\-]', '_').Trim()
$newVmName = "${safeBase}_WimBoot"

# Determine controller type from provisioning template generation.
$provTpl = $master.VMProvisioningTemplates.$tplKey
if ($null -eq $provTpl) { throw "VMProvisioningTemplates.$tplKey not found in _master_config.json." }
$gen = [int]$provTpl.Generation
$controllerType = if ($gen -ge 2) { 'SCSI' } else { 'IDE' }

Write-Host ""
Write-Host "=== Boot WIM in new VM (offline apply) ===" -ForegroundColor Cyan
Write-Host "  Profile:            $pk" -ForegroundColor Gray
Write-Host "  Provisioning tpl:  $tplKey" -ForegroundColor Gray
Write-Host "  WIM:                $wimPath" -ForegroundColor Gray
Write-Host "  WIM index:         $WimIndex" -ForegroundColor Gray
Write-Host "  New VM name:      $newVmName" -ForegroundColor Gray
Write-Host ""

$scriptsDir = $PSScriptRoot
$helper = Join-Path $scriptsDir "New-MasterLikeVm.ps1"
if (-not (Test-Path -LiteralPath $helper)) { throw "Script missing: $helper" }

if (-not $PSCmdlet.ShouldProcess($newVmName, "Create VM + apply WIM offline")) { return }

# Use Hyper-V Manager's configured VM storage location (virtual machine path).
$vmStoragePath = $null
try {
    $vmHost = Get-VMHost -ErrorAction SilentlyContinue
    if ($vmHost -and $vmHost.VirtualMachinePath) { $vmStoragePath = $vmHost.VirtualMachinePath }
} catch { }
if ([string]::IsNullOrWhiteSpace($vmStoragePath)) {
    $vmStoragePath = 'N:\VM' # user-provided manager default
}

# Create or reuse the blank VM without touching config.
$vm = Get-VM -Name $newVmName -ErrorAction SilentlyContinue
if ($vm) {
    if ($vm.State -ne 'Off') {
        Write-Host "[*] VM exists but is not Off; stopping VM: $newVmName" -ForegroundColor Yellow
        Stop-VM -Name $newVmName -Force -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Seconds 3
    }
} else {
    & $helper -VMProfile $pk `
        -ProvisioningTemplateKey $tplKey `
        -SkipStagingVhd -SkipDvd `
        -VMNameOverride $newVmName `
        -VmMachinePathOverride $vmStoragePath `
        -NoConfigSave

    $vm = Get-VM -Name $newVmName -ErrorAction Stop
}
$stagingVhdLeaf = if ($Cfg.VhdPath) { (Split-Path $Cfg.VhdPath -Leaf) } else { '' }
$stagingVhdLeaf = if ($stagingVhdLeaf) { $stagingVhdLeaf } else { '' }
$hdds = @(Get-VMHardDiskDrive -VMName $newVmName -ErrorAction SilentlyContinue)
if (-not $hdds -or $hdds.Count -eq 0) {
    throw "No hard disks found on VM '$newVmName'. Expected at least the OS VHD."
}
$osVhd = $null
if ($stagingVhdLeaf) {
    $osCandidate = @($hdds | Where-Object {
        $leaf = if ($_.Path) { (Split-Path -Path $_.Path -Leaf) } else { '' }
        -not [string]::IsNullOrWhiteSpace($leaf) -and ($leaf -ine $stagingVhdLeaf)
    } | Select-Object -First 1)
    if ($osCandidate -and $osCandidate.Path) { $osVhd = $osCandidate.Path }
}
if (-not $osVhd) {
    $osVhd = ($hdds | Select-Object -First 1).Path
}
if (-not (Test-Path -LiteralPath $osVhd)) {
    throw "OS VHD missing on disk: $osVhd"
}

Write-Host "`n[1/5] Detaching OS VHD from VM..." -ForegroundColor Yellow
Invoke-SmartRelease -VhdPath $osVhd -VMName $newVmName

$reattachNeeded = $true
try {
    Write-Host "[2/5] Mounting OS VHD..." -ForegroundColor Yellow
    Mount-VHD -Path $osVhd -ErrorAction Stop | Out-Null

    try {
        $vhdInfo = Get-VHD -Path $osVhd -ErrorAction Stop
        $diskNumber = $vhdInfo.DiskNumber

    # Pick free drive letters for EFI + Windows.
    $usedLetters = @((Get-Volume | Where-Object DriveLetter).DriveLetter | ForEach-Object { $_.ToString().ToUpper() })
    function Get-FreeLetter([string[]]$Preferred) {
        foreach ($p in $Preferred) {
            $u = $p.ToUpper()
            if ($u -and ($usedLetters -notcontains $u)) { return $u }
        }
        return $null
    }
    $sysLetter = Get-FreeLetter @('S','T','U','V')
    $winLetter = Get-FreeLetter @('W','X','Y','Z')
    if ([string]::IsNullOrWhiteSpace($sysLetter) -or [string]::IsNullOrWhiteSpace($winLetter)) {
        throw "Could not find free drive letters for EFI/Windows partitions on host."
    }

    Write-Host "  EFI letter:      $sysLetter" -ForegroundColor DarkGray
    Write-Host "  Windows letter: $winLetter" -ForegroundColor DarkGray

    # Partition the mounted disk (UEFI GPT).
        $dp = @"
select disk $diskNumber
clean
convert gpt
create partition efi size=100
format quick fs=fat32 label="System"
assign letter=$sysLetter
create partition msr size=16
create partition primary size=500
format quick fs=ntfs label="Recovery"
set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac"
gpt attributes=0x8000000000000001
create partition primary
format quick fs=ntfs label="Windows"
assign letter=$winLetter
exit
"@
        $dpPath = Join-Path $env:TEMP ("diskpart_wim_$PID.txt")
        Set-Content -LiteralPath $dpPath -Value $dp -Encoding ASCII
        try {
            diskpart /s $dpPath | Out-Null
        } finally {
            if (Test-Path $dpPath) { Remove-Item -LiteralPath $dpPath -Force | Out-Null }
        }

    # Validate WIM indexes so we fail with a clear message (instead of DISM exit 87).
    $wimInfoOut = & dism.exe /Get-WimInfo "/WimFile:$wimPath" 2>&1
        $exitInfo = $LASTEXITCODE
        if ($exitInfo -ne 0) {
            throw "DISM /Get-WimInfo failed (exit code $exitInfo). Output:`n$wimInfoOut"
        }
    $foundIndexes = New-Object 'System.Collections.Generic.List[int]'
        foreach ($line in $wimInfoOut) {
            if ($line -match 'Index\s*:\s*(\d+)') {
            [void]$foundIndexes.Add([int]$Matches[1])
            }
        }
    $foundIndexes = @($foundIndexes | Sort-Object -Unique)
        if ($foundIndexes.Count -gt 0 -and ($foundIndexes -notcontains $WimIndex)) {
            Write-Host "WIM index $WimIndex not found. Available indexes: $($foundIndexes -join ', '). Using first index." -ForegroundColor DarkYellow
            $WimIndex = $foundIndexes[0]
        }

        Write-Host "[3/5] Applying WIM offline (DISM)..." -ForegroundColor Yellow
        $dismArgs = @(
            '/Apply-Image',
        "/ImageFile:$wimPath",
            "/Index:$WimIndex",
            "/ApplyDir:$winLetter`:\"
        )
        $dismOut = & dism.exe @dismArgs 2>&1
        $exitCodeApply = $LASTEXITCODE
        if ($exitCodeApply -ne 0) {
            throw "DISM Apply-Image failed with exit code $exitCodeApply. Output:`n$dismOut"
        }

        Write-Host "[4/5] Writing UEFI boot (bcdboot)..." -ForegroundColor Yellow
        & bcdboot "$winLetter`:\Windows" /s "$sysLetter`:" /f UEFI | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "bcdboot failed with exit code $LASTEXITCODE"
        }

        # --- Drive Letter Persistence (First-Boot Script) ---
        Write-Host "[*] Injecting drive letter configuration (C, D, E)..." -ForegroundColor Yellow
        $mainOS = if ($Cfg.MainOSDrive) { $Cfg.MainOSDrive.ToString().ToUpper()[0] } else { 'C' }
        $dvdLetter = if ($Cfg.DVDBootDrive) { $Cfg.DVDBootDrive.ToString().ToUpper()[0] } else { 'D' }
        $stagingLetter = if ($Cfg.GuestStagingDrive) { $Cfg.GuestStagingDrive.ToString().ToUpper()[0] } else { 'E' }
        $stagingLabel = if ($Cfg.StagingVolumeLabel) { $Cfg.StagingVolumeLabel } else { 'Golden Imaging' }

        # Create the GI_Scripts directory on the applied OS
        $giScriptsDir = Join-Path "${winLetter}:\" "GI_Scripts"
        if (-not (Test-Path $giScriptsDir)) { New-Item -ItemType Directory -Path $giScriptsDir -Force | Out-Null }

        # Create a PS1 script that runs on first boot to fix drive letters
        $setupDrivesScript = @"
# Golden Image: First-Boot Drive Letter Assignment
# Log all output
Start-Transcript -Path "C:\GI_Scripts\SetupDrives.log" -Append

Write-Host "[*] Assigning drive letters..."
# 1. Identify the Staging VHD by its volume label
`$stagingVol = Get-Volume | Where-Object { `$_.FileSystemLabel -eq '$stagingLabel' }
if (`$stagingVol) {
    if (`$stagingVol.DriveLetter -ne '$stagingLetter') {
        Write-Host "    Found staging volume '$stagingLabel'. Reassigning to $stagingLetter`:..."
        # If the target letter is taken, move it away first
        `$targetVol = Get-Volume -DriveLetter '$stagingLetter' -ErrorAction SilentlyContinue
        if (`$targetVol) { Set-Partition -DriveLetter '$stagingLetter' -NewDriveLetter (Get-Volume | Where-Object { -not `$_.DriveLetter } | Select-Object -First 1).DriveLetter -ErrorAction SilentlyContinue }
        
        Set-Partition -InputObject (`$stagingVol | Get-Partition) -NewDriveLetter '$stagingLetter'
    }
}

# 2. Identify the DVD drive and move to D:
`$dvd = Get-Volume | Where-Object { `$_.DriveType -eq 'CD-ROM' } | Select-Object -First 1
if (`$dvd) {
    if (`$dvd.DriveLetter -ne '$dvdLetter') {
        Write-Host "    Found DVD drive. Reassigning to $dvdLetter`:..."
        # If target is taken, move it
        `$targetVol = Get-Volume -DriveLetter '$dvdLetter' -ErrorAction SilentlyContinue
        if (`$targetVol) { Set-Partition -DriveLetter '$dvdLetter' -NewDriveLetter (Get-Volume | Where-Object { -not `$_.DriveLetter } | Select-Object -First 1).DriveLetter -ErrorAction SilentlyContinue }
        
        Set-Partition -InputObject (`$dvd | Get-Partition) -NewDriveLetter '$dvdLetter'
    }
}

Stop-Transcript
"@
        Set-Content -LiteralPath (Join-Path $giScriptsDir "SetupDrives.ps1") -Value $setupDrivesScript -Encoding UTF8

        try {
            # Register the script to run once in the SOFTWARE hive
            $softHive = Join-Path "${winLetter}:\" "Windows\System32\config\SOFTWARE"
            if (Test-Path $softHive) {
                reg load "HKLM\GI_SOFTWARE" $softHive | Out-Null
                $cmd = 'powershell.exe -ExecutionPolicy Bypass -File C:\GI_Scripts\SetupDrives.ps1'
                reg add "HKLM\GI_SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "SetupGIDrives" /t REG_SZ /d $cmd /f | Out-Null
                reg unload "HKLM\GI_SOFTWARE" | Out-Null
                Write-Host "  First-boot drive setup registered in RunOnce." -ForegroundColor DarkGray
            }
        } catch {
            Write-Warning "Failed to register first-boot drive setup: $_"
            if (reg query "HKLM\GI_SOFTWARE" 2>$null) { reg unload "HKLM\GI_SOFTWARE" | Out-Null }
        }
    }
    finally {
        Write-Host "[5/5] Dismounting VHD..." -ForegroundColor Yellow
        try { Dismount-VHD -Path $osVhd -ErrorAction SilentlyContinue | Out-Null } catch { }
    }
}
finally {
    if ($reattachNeeded) {
        try {
            $stillAttached = @(Get-VMHardDiskDrive -VMName $newVmName -ErrorAction SilentlyContinue |
                Where-Object { $_.Path -and ($_.Path -ieq $osVhd) })
            if ($stillAttached.Count -eq 0) {
                Write-Host "Reattaching OS VHD to VM..." -ForegroundColor Yellow
                Add-VMHardDiskDrive -VMName $newVmName -ControllerType $controllerType -Path $osVhd -ErrorAction Stop | Out-Null
            }
        } catch {
            Write-Host "[WARN] Failed to reattach OS VHD after operation: $_" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Done. VM prepared (left OFF): $newVmName" -ForegroundColor Green
Write-Host "  OS VHD: $osVhd" -ForegroundColor Gray
Write-Host "  WIM:    $wimPath" -ForegroundColor Gray
Write-Host ""

if (-not $NoPause) { Read-Host "Press Enter to continue" }

