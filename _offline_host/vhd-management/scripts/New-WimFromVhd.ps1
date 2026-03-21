<#
.SYNOPSIS
    Captures a WIM image from a sysprepped VHD/VHDX.
    Mounts the VHD read-only, runs DISM capture, then dismounts.
.PARAMETER NoPause
    Skip the end-of-operation pause.
#>
param([switch]$NoPause)

. (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\VhdUtils.ps1")

$Cfg = Get-Config
$VMName = $Cfg.VMName
$configuredOsVhd = if ($Cfg.OsVhdPath) { ($Cfg.OsVhdPath.ToString() -replace '/', '\').Trim() } else { "" }
$hostVhdPath = if ($Cfg.HostVhdPath) { ($Cfg.HostVhdPath.ToString() -replace '/', '\').Trim() } else { "" }
if ([string]::IsNullOrWhiteSpace($hostVhdPath)) { $hostVhdPath = if ($Cfg.VhdPath) { ($Cfg.VhdPath.ToString() -replace '/', '\').Trim() } else { "" } }

$wimDestination = $Cfg.WimDestination
if ([string]::IsNullOrWhiteSpace($wimDestination)) {
    # Fallback to defaultVMProfile's WimDestination so the master config value works even if active profile omits it.
    $LocalProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $master = Read-JsonCFile -Path (Join-Path $LocalProjectRoot "_master_config.json")
    $defaultProfile = $master.defaultVMProfile
    $wimDestination = $master.VMProfiles.$defaultProfile.VMDetails.WimDestination
}

function Test-HostVhdExistsAndCreate {
    param(
        [Parameter(Mandatory = $true)][string]$HostVhdPath,
        [Parameter(Mandatory = $true)][string]$HardwareTemplateKey
    )
    if ([string]::IsNullOrWhiteSpace($HostVhdPath)) {
        throw "HostVhdPath is empty; cannot ensure staging VHD exists."
    }
    if (Test-Path -LiteralPath $HostVhdPath) { return }

    $master = Read-JsonCFile -Path $MasterConfigPath
    if ($null -eq $master.VMProvisioningTemplates) {
        throw "VMProvisioningTemplates missing from _master_config.json (required to size HostVhdPath)."
    }
    if ($null -eq $master.VMProvisioningTemplates.PSObject.Properties[$HardwareTemplateKey]) {
        throw "VMProvisioningTemplates.$HardwareTemplateKey not found (required to size HostVhdPath)."
    }
    $tpl = $master.VMProvisioningTemplates.$HardwareTemplateKey
    $sizeGb = $tpl.NewOsVhdSizeGB
    if ($null -eq $sizeGb) {
        throw "VMProvisioningTemplates.$HardwareTemplateKey.NewOsVhdSizeGB missing; cannot create HostVhdPath."
    }

    Write-Host "[*] HostVhdPath missing; creating: $HostVhdPath" -ForegroundColor Yellow
    New-VHD -Path $HostVhdPath -SizeBytes ($sizeGb * 1GB) -Dynamic -ErrorAction Stop | Out-Null
}

# Find the VM's OS VHD: check attached drives first, then scan VM storage folder
$vmDrives = @(Get-VMHardDiskDrive -VMName $VMName -ErrorAction SilentlyContinue)
$stagingLeaf = if ($Cfg.VhdPath) { Split-Path $Cfg.VhdPath -Leaf } else { "" }
$osDrives = @($vmDrives | Where-Object { $_.Path -and (Split-Path $_.Path -Leaf) -ne $stagingLeaf })
$candidates = @()

if ($osDrives.Count -gt 0) {
    $candidates = @($osDrives | ForEach-Object { $_.Path })
} elseif ($vmDrives.Count -gt 0) {
    $candidates = @($vmDrives | ForEach-Object { $_.Path })
} else {
    # No drives attached -- scan the VM's storage folder for VHD files
    $vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    $vmVhdFolder = if ($vm) { Join-Path $vm.Path "Virtual Hard Disks" } else { $null }
    if ($vmVhdFolder -and (Test-Path $vmVhdFolder)) {
        $diskFiles = @(Get-ChildItem -Path $vmVhdFolder -Filter "*.vhdx" -File -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -ne $stagingLeaf } |
                       Sort-Object LastWriteTime -Descending)
        $candidates = @($diskFiles | ForEach-Object { $_.FullName })
    }
}

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "              WIM CAPTURE FROM VHD" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

if (-not [string]::IsNullOrWhiteSpace($configuredOsVhd)) {
    $attachedConfigured = @($osDrives | Where-Object { $_.Path -and ($_.Path -ieq $configuredOsVhd) })
    $attachedActive = @($osDrives | Where-Object { $_.Path })
    if ($attachedConfigured.Count -gt 0) {
        $VhdPath = $configuredOsVhd
        Write-Host "  OS VHD (configured/attached): $VhdPath" -ForegroundColor Gray
    }
    elseif ($attachedActive.Count -gt 0) {
        $VhdPath = $attachedActive[0].Path
        Write-Host "  OS VHD (attached active): $VhdPath" -ForegroundColor Gray
        Write-Host "  Note: configured OsVhdPath differs from currently attached disk (checkpoint chain may be active)." -ForegroundColor DarkYellow
    }
    else {
        $VhdPath = $configuredOsVhd
        if (-not (Test-Path $VhdPath)) {
            Write-Host "[ERROR] Configured VMDetails.OsVhdPath was not found: $VhdPath" -ForegroundColor Red
            Write-Host "        Fix _master_config.json or recreate VM with PV to refresh OsVhdPath." -ForegroundColor Yellow
            if (-not $NoPause) { Read-Host "Press Enter to continue" }
            return
        }
        Write-Host "  OS VHD (configured): $VhdPath" -ForegroundColor Gray
    }
}
elseif ($candidates.Count -eq 0) {
    Write-Host "  No VHDs found on VM or in storage folder." -ForegroundColor Yellow
    $manual = Read-Host "  Enter VHD path manually"
    if ([string]::IsNullOrWhiteSpace($manual)) {
        if (-not $NoPause) { Read-Host "Press Enter to continue" }
        return
    }
    $VhdPath = $manual.Trim('"')
} elseif ($candidates.Count -eq 1) {
    $VhdPath = $candidates[0]
    Write-Host "  OS VHD: $VhdPath" -ForegroundColor Gray
} else {
    Write-Host "`n  Available VHDs:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        $leaf = Split-Path $candidates[$i] -Leaf
        Write-Host "    $($i+1). $leaf" -ForegroundColor Gray
    }
    $sel = Read-Host "Select drive number [1]"
    if ([string]::IsNullOrWhiteSpace($sel)) { $sel = "1" }
    $idx = [int]$sel - 1
    if ($idx -lt 0 -or $idx -ge $candidates.Count) {
        Write-Host "[ERROR] Invalid selection." -ForegroundColor Red
        if (-not $NoPause) { Read-Host "Press Enter to continue" }
        return
    }
    $VhdPath = $candidates[$idx]
}

if (-not (Test-Path $VhdPath)) {
    Write-Host "[ERROR] VHD not found: $VhdPath" -ForegroundColor Red
    if (-not $NoPause) { Read-Host "Press Enter to continue" }
    return
}

$vhdDir = Split-Path $VhdPath -Parent
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($VhdPath)
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$defaultWimPath = Join-Path $vhdDir "$($baseName)_$timestamp.wim"
if (-not [string]::IsNullOrWhiteSpace($wimDestination)) {
    $defaultWimPath = ($wimDestination.ToString() -replace '/', '\').Trim()
}

Write-Host "  WIM:  $defaultWimPath" -ForegroundColor Gray
Write-Host ""

$wimPath = Read-Host "WIM output path [Enter for default]"
if ([string]::IsNullOrWhiteSpace($wimPath)) { $wimPath = $defaultWimPath }

$imageName = Read-Host "Image name [Enter for 'Golden Image']"
if ([string]::IsNullOrWhiteSpace($imageName)) { $imageName = "Golden Image" }

$wasAttachedToVm = @(
    Get-VMHardDiskDrive -VMName $VMName -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and ($_.Path -ieq $VhdPath) }
).Count -gt 0
$shouldReattachOnError = $false

function Restore-OsDiskAttachmentOnError {
    param(
        [string]$VmName,
        [string]$DiskPath,
        [bool]$ShouldReattach
    )
    if (-not $ShouldReattach) { return }
    try {
        Dismount-VHD -Path $DiskPath -ErrorAction SilentlyContinue
    } catch { }

    $attached = @(
        Get-VMHardDiskDrive -VMName $VmName -ErrorAction SilentlyContinue |
            Where-Object { $_.Path -and ($_.Path -ieq $DiskPath) }
    )
    if ($attached.Count -eq 0) {
        try {
            Add-VMHardDiskDrive -VMName $VmName -ControllerType SCSI -Path $DiskPath -ErrorAction Stop
            Write-Host "[*] Reattached OS disk to VM: $DiskPath" -ForegroundColor Yellow
        } catch {
            Write-Host "[WARN] Failed to reattach OS disk to VM: $_" -ForegroundColor Red
        }
    }
}

# Ensure VHD is released from VM and any existing host mount
if (-not [string]::IsNullOrWhiteSpace($hostVhdPath)) {
    Test-HostVhdExistsAndCreate -HostVhdPath $hostVhdPath -HardwareTemplateKey $Cfg.HardwareTemplateKey
}
Write-Host "`n[1/4] Releasing VHD from VM and existing mounts..." -ForegroundColor Yellow
Invoke-SmartRelease -VhdPath $VhdPath -VMName $VMName
$shouldReattachOnError = $wasAttachedToVm
Start-Sleep -Seconds 2

# Mount read-only on host
Write-Host "[2/4] Mounting VHD read-only..." -ForegroundColor Yellow
try {
    Mount-VHD -Path $VhdPath -ReadOnly -ErrorAction Stop
} catch {
    Write-Host "[ERROR] Failed to mount VHD: $_" -ForegroundColor Red
    Restore-OsDiskAttachmentOnError -VmName $VMName -DiskPath $VhdPath -ShouldReattach $shouldReattachOnError
    if (-not $NoPause) { Read-Host "Press Enter to continue" }
    return
}

# Find the drive letter of the mounted OS partition
$vhdInfo = Get-VHD -Path $VhdPath -ErrorAction SilentlyContinue
$driveLetter = $null
if ($null -ne $vhdInfo -and $null -ne $vhdInfo.DiskNumber) {
    $vol = Get-Partition -DiskNumber $vhdInfo.DiskNumber -ErrorAction SilentlyContinue |
           Get-Volume -ErrorAction SilentlyContinue |
           Where-Object { $_.DriveLetter -and $_.FileSystemType -eq 'NTFS' } |
           Sort-Object -Property SizeRemaining -Descending |
           Select-Object -First 1
    if ($vol) { $driveLetter = $vol.DriveLetter }
}

if (-not $driveLetter) {
    Write-Host "[ERROR] Could not determine drive letter of mounted VHD." -ForegroundColor Red
    Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
    Restore-OsDiskAttachmentOnError -VmName $VMName -DiskPath $VhdPath -ShouldReattach $shouldReattachOnError
    if (-not $NoPause) { Read-Host "Press Enter to continue" }
    return
}

$captureDir = "${driveLetter}:\"
Write-Host "  Mounted at: $captureDir" -ForegroundColor Gray

# Verify it looks like a Windows install
if (-not (Test-Path "${driveLetter}:\Windows\System32")) {
    Write-Host "[ERROR] $captureDir does not appear to contain a Windows installation." -ForegroundColor Red
    Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
    Restore-OsDiskAttachmentOnError -VmName $VMName -DiskPath $VhdPath -ShouldReattach $shouldReattachOnError
    if (-not $NoPause) { Read-Host "Press Enter to continue" }
    return
}

# Capture
Write-Host "[3/4] Capturing WIM (this may take 10-30 minutes)..." -ForegroundColor Yellow
Write-Host "  Source: $captureDir" -ForegroundColor Gray
Write-Host "  Dest:   $wimPath" -ForegroundColor Gray
Write-Host "  Name:   $imageName" -ForegroundColor Gray
Write-Host ""

$descr = "Golden Image captured $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$dismArgs = @(
    '/Capture-Image',
    "/ImageFile:$wimPath",
    "/CaptureDir:$captureDir",
    "/Name:$imageName",
    "/Description:$descr",
    '/Compress:maximum'
)

$startTime = Get-Date
& dism.exe @dismArgs
$exitCode = $LASTEXITCODE
$elapsed = (Get-Date) - $startTime

# Dismount
Write-Host "`n[4/4] Dismounting VHD..." -ForegroundColor Yellow
Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
Restore-OsDiskAttachmentOnError -VmName $VMName -DiskPath $VhdPath -ShouldReattach $shouldReattachOnError

# Result
Write-Host ""
if ($exitCode -eq 0 -and (Test-Path $wimPath)) {
    $wimSize = [math]::Round((Get-Item $wimPath).Length / 1GB, 2)
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "  WIM CAPTURE COMPLETE" -ForegroundColor Green
    Write-Host "  File: $wimPath" -ForegroundColor Gray
    Write-Host "  Size: ${wimSize} GB | Time: $([math]::Round($elapsed.TotalMinutes, 1)) min" -ForegroundColor Gray
    Write-Host "================================================================" -ForegroundColor Green
} else {
    Write-Host "[ERROR] DISM capture failed with exit code $exitCode" -ForegroundColor Red
}

if (-not $NoPause) { Read-Host "`nPress Enter to continue" }
