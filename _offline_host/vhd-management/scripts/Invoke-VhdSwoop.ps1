<#
.SYNOPSIS
    Syncs local project folders (_offline, installers) to the staging VHD.
#>
param(
    [Parameter(Mandatory=$true)] [string[]]$Sources,
    [switch]$NoPause
)

. (Join-Path $PSScriptRoot "VhdUtils.ps1")
$Cfg = Get-Config

# For sync operations, ensure the staging VHD exists before attempting SmartRelease/Mount.
if ($null -eq $Cfg.VhdPath -or [string]::IsNullOrWhiteSpace($Cfg.VhdPath.ToString())) {
    throw "VhdPath missing from config (Get-Config -Target Host)."
}
if (-not (Test-Path -LiteralPath $Cfg.VhdPath)) {
    if ([string]::IsNullOrWhiteSpace($Cfg.HardwareTemplateKey)) {
        throw "VhdPath missing on disk and HardwareTemplateKey is empty; cannot size/create VHD."
    }
    $master = Read-JsonCFile -Path $MasterConfigPath
    if ($null -eq $master.VMProvisioningTemplates) {
        throw "VMProvisioningTemplates missing from _master_config.json (required to size VhdPath)."
    }
    if ($null -eq $master.VMProvisioningTemplates.PSObject.Properties[$Cfg.HardwareTemplateKey]) {
        throw "VMProvisioningTemplates.$($Cfg.HardwareTemplateKey) not found (required to size VhdPath)."
    }
    $tpl = $master.VMProvisioningTemplates.$($Cfg.HardwareTemplateKey)
    $sizeGb = $tpl.NewOsVhdSizeGB
    if ($null -eq $sizeGb) {
        throw "VMProvisioningTemplates.$($Cfg.HardwareTemplateKey).NewOsVhdSizeGB missing; cannot create VhdPath."
    }

    Write-Host "[*] Staging VHD missing; creating: $($Cfg.VhdPath)" -ForegroundColor Yellow
    New-VHD -Path $Cfg.VhdPath -SizeBytes ($sizeGb * 1GB) -Dynamic -ErrorAction Stop | Out-Null
}

try {
    Write-Host ">>> SYNC OPERATION: $($Sources.Count) folders" -ForegroundColor Cyan
    Write-Host "[1/2] Connecting VHD to host..." -ForegroundColor Gray
    
    $vhd = Invoke-VhdTransition -Target "Host" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName
    $diskNumber = $vhd.DiskNumber
    $partAll = Get-Partition -DiskNumber $diskNumber -ErrorAction SilentlyContinue
    $part = $partAll | Where-Object DriveLetter | Select-Object -First 1

    # If the VHD was just created, it may be RAW/empty with no partitions.
    if (-not $part) {
        if (-not $partAll -or $partAll.Count -eq 0) {
            $disk = Get-Disk -Number $diskNumber -ErrorAction SilentlyContinue
            if ($disk -and $disk.PartitionStyle -eq 'RAW') {
                Initialize-Disk -Number $diskNumber -PartitionStyle GPT -ErrorAction Stop | Out-Null
            }

            $part = New-Partition -DiskNumber $diskNumber -UseMaximumSize -AssignDriveLetter -ErrorAction Stop
            Format-Volume -Partition $part -FileSystem NTFS -NewFileSystemLabel $Cfg.StagingVolumeLabel -Confirm:$false -Force -ErrorAction Stop | Out-Null
        } else {
            # Partitions exist but none have drive letters; attach a free one.
            $usedLetters = @(Get-Volume | Where-Object DriveLetter | Select-Object -ExpandProperty DriveLetter)
            $freeLetter = ($usedLetters | ForEach-Object { $_ }) | Out-Null
            $freeLetter = $null
            foreach ($candidate in ([char[]]'FGHIJKLMNOPQRSTUVWXYZ')) {
                if ($null -eq $candidate) { continue }
                if ($usedLetters -notcontains $candidate.ToString()) { $freeLetter = $candidate.ToString(); break }
            }
            if (-not $freeLetter) {
                throw "No free drive letter found on host to assign to staging VHD."
            }

            $firstPart = $partAll | Select-Object -First 1
            Set-Partition -DiskNumber $diskNumber -PartitionNumber $firstPart.PartitionNumber -NewDriveLetter $freeLetter -ErrorAction Stop | Out-Null
        }

        $partAll = Get-Partition -DiskNumber $diskNumber -ErrorAction SilentlyContinue
        $part = $partAll | Where-Object DriveLetter | Select-Object -First 1
    }

    if (-not $part) { throw "No partition with drive letter found on VHD (disk #$diskNumber)." }
    $driveLetter = $part.DriveLetter
    $drive = "${driveLetter}:"
    Write-Host "[DEBUG] Found Drive: $drive" -ForegroundColor DarkGray

    # Ensure label matches config
    if ($Cfg.StagingVolumeLabel) { Set-Volume -DriveLetter $driveLetter -NewFileSystemLabel $Cfg.StagingVolumeLabel -ErrorAction SilentlyContinue }


    foreach ($Source in $Sources) {
        $sourceLeaf = Split-Path $Source -Leaf
        $destFolder = if ($sourceLeaf -eq "_offline") { $Cfg.OfflinePath } elseif ($sourceLeaf -eq "installers") { $Cfg.InstallersPath } else { $sourceLeaf }
        $destination = Join-Path $drive $destFolder
        Write-Host "[Syncing] $Source -> $destination" -ForegroundColor Yellow
        robocopy $Source $destination /MIR /MT:16 /R:2 /W:5 /NP /NDL /FFT /XF RDP-Tcp.reg /XD .git
    }

    Write-Host "[2/2] Reconnecting VHD to VM..." -ForegroundColor Gray
    Invoke-VhdTransition -Target "VM" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName
    Write-Host "[SUCCESS] Sync complete and returned to VM." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Sync Failed: $($_.Exception.Message)" -ForegroundColor Red
    Invoke-VhdTransition -Target "VM" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName
}

if (-not $NoPause) { Read-Host "`nPress Enter to continue..." }
