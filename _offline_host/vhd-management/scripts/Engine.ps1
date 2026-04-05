<#
.SYNOPSIS
    Core Engine for Golden Image Environment Management (Foundational edition).
    Implements standardized naming and reliable VHD/artifact transitions.
#>

# --- VHD ENGINE ---

function Invoke-VhdRelease {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$VhdPath,
        [string]$VMName
    )
    Write-Host "[*] VHD RELEASE: $(Split-Path $VhdPath -Leaf)" -ForegroundColor Gray
    
    # 1. Release from VM if provided
    if ($VMName) {
        $vmDrive = Get-VMHardDiskDrive -VMName $VMName -ErrorAction SilentlyContinue | 
                   Where-Object { $_.Path -and ($_.Path -eq $VhdPath) } | Select-Object -First 1
        if ($vmDrive) {
            Write-Host "    -> Detaching from VM: $VMName" -ForegroundColor Yellow
            $vmDrive | Remove-VMHardDiskDrive -ErrorAction SilentlyContinue
        }
    }

    # 2. Release from Host
    try {
        Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
        Write-Host "    -> Dismounted from Host" -ForegroundColor DarkGray
    } catch { }

    # 3. Final Sanitize (Bring Offline)
    Get-Disk | Where-Object { $_.FriendlyName -like "*Virtual*" } | Set-Disk -IsOffline $true -ErrorAction SilentlyContinue
}

function Get-VhdInfoSafe {
    [CmdletBinding()]
    param([string]$VhdPath, [int]$TimeoutSeconds = 3)
    $job = Start-Job { param($p) Import-Module Hyper-V; Get-VHD -Path $p } -ArgumentList $VhdPath
    if (Wait-Job $job -Timeout $TimeoutSeconds) { $r = Receive-Job $job; Remove-Job $job -Force; return $r }
    Stop-Job $job; Remove-Job $job -Force; return $null
}

function Get-VmDriveForVhd {
    [CmdletBinding()]
    param([string]$VhdPath, [string]$VMName)
    $all = Get-VMHardDiskDrive -VMName $VMName -ErrorAction SilentlyContinue
    $match = $all | Where-Object { $_.Path -and (($_.Path -replace '/', '\' -eq ($VhdPath -replace '/', '\')) -or ((Split-Path $_.Path -Leaf) -eq (Split-Path $VhdPath -Leaf))) } | Select-Object -First 1
    if ($match) { return $match }
    
    # Fallback to fuzzy match (for differencing disks/snapshots)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($VhdPath)
    $all | Where-Object { $_.Path -and (Split-Path $_.Path -Leaf) -like "${baseName}*" } | Select-Object -First 1
}

function Get-VhdAttachmentStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$VhdPath,
        [Parameter(Mandatory=$true)] [string]$VMName
    )
    # Check VM
    if (Get-VmDriveForVhd -VhdPath $VhdPath -VMName $VMName) { return "VM" }
    
    # Check Host
    $vhd = Get-VHD -Path $VhdPath -ErrorAction SilentlyContinue
    if ($vhd.Attached) { return "HOST" }
    
    return "NONE"
}

function Invoke-VhdTransition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [ValidateSet("Host", "VM")] [string]$Target,
        [Parameter(Mandatory=$true)] [string]$VhdPath,
        [Parameter(Mandatory=$true)] [string]$VMName
    )
    
    $current = Get-VhdAttachmentStatus -VhdPath $VhdPath -VMName $VMName
    if ($current -eq $Target.ToUpper()) {
        Write-Host "[!] ALREADY ATTACHED: $Target" -ForegroundColor Yellow
        return $true
    }

    # Always start from a clean slate if mismatch
    Invoke-VhdRelease -VhdPath $VhdPath -VMName $VMName
    
    if ($Target -eq "Host") {
        Write-Host "[*] MOUNTING TO HOST: $(Split-Path $VhdPath -Leaf)" -ForegroundColor Cyan
        Mount-VHD -Path $VhdPath -ErrorAction Stop
        
        # Settle & Identify
        Start-Sleep -Seconds 1
        $vhd = Get-VHD -Path $VhdPath
        if ($vhd.Attached -and $vhd.DiskNumber -ne $null) {
            $vol = Get-Partition -DiskNumber $vhd.DiskNumber | Get-Volume | Where-Object DriveLetter | Select-Object -First 1
            if ($vol) {
                Write-Host "    -> Mounted on $($vol.DriveLetter):" -ForegroundColor Green
                return "${vol.DriveLetter}:"
            }
        }
        throw "ABORT: VHD mounted but no drive letter found."
    } else {
        Write-Host "[*] ATTACHING TO VM: $VMName" -ForegroundColor Cyan
        Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -Path $VhdPath -ErrorAction Stop
        Write-Host "    -> Attached to VM successfully." -ForegroundColor Green
        return $true
    }
}


# --- ARTIFACT & SYNC ENGINE ---

function Invoke-ArtifactPull {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $Config,
        [Parameter(Mandatory=$true)] [ValidateSet("Wim", "Logs", "Registry", "All")] [string]$Category
    )
    
    Write-Host "`n>>> [ARTIFACT ENGINE] Starting Pull: $Category..." -ForegroundColor White
    $vhdLine = if ($Config.OsVhdPath) { $Config.OsVhdPath } else { $Config.VhdPath }
    
    try {
        # 1. Bring VHD to Host for high-speed file IO
        $hostDrive = Invoke-VhdTransition -Target "Host" -VhdPath $vhdLine -VMName $Config.VMName
        
        # 2. Identify Source Categories
        $sourceMap = @{
            "Wim"      = Join-Path $hostDrive "\"
            "Logs"     = Join-Path $hostDrive "Windows\Logs"
            "Registry" = Join-Path $hostDrive "Windows\System32\config"
        }
        
        # 3. Pull Operation (Using Robocopy for reliability & logs)
        $destRoot = Join-Path $Config.LocalProjectRoot "return"
        if (-not (Test-Path $destRoot)) { New-Item -ItemType Directory -Path $destRoot -Force | Out-Null }
        
        $pullList = if ($Category -eq "All") { $sourceMap.Keys } else { ,$Category }
        
        foreach ($cat in $pullList) {
            $src = $sourceMap[$cat]
            if (-not (Test-Path $src)) { Write-Host "    [!] WARN: Path $src not found. Skipping $cat." -ForegroundColor Red; continue }
            
            $dst = Join-Path $destRoot $cat
            Write-Host "[*] Pulling $cat -> $dst..." -ForegroundColor DarkGray
            
            # Atomic Robocopy (R:3 = 3 retries, W:5 = 5s wait)
            robocopy $src $dst /S /R:3 /W:5 /NDL /NFL /NJH /NJS /MT:8
        }
        
        Write-Host "[OK] Pull complete." -ForegroundColor Green
        
    } finally {
        # 4. Always ensure release
        Invoke-VhdRelease -VhdPath $vhdLine -VMName $Config.VMName
    }
}

function Invoke-MasterSync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $Config,
        [switch]$All
    )
    
    Write-Host "`n>>> [SYNC ENGINE] Starting Update..." -ForegroundColor White
    $destBase = Join-Path $Config.VhdPath "Staging" # Placeholder for VHD mount discovery
    
    # Ensure VHD is on Host for syncing
    try {
        $drive = Invoke-VhdTransition -Target "Host" -VhdPath $Config.VhdPath -VMName $Config.VMName
        $targetRoot = Join-Path $drive $Config.OfflinePath
        if (-not (Test-Path $targetRoot)) { New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null }
        
        $sources = @(@{ Path = Join-Path $Config.LocalProjectRoot $Config.OfflinePath; Dest = "" })
        if ($All) { $sources += @{ Path = Join-Path $Config.LocalProjectRoot $Config.InstallersPath; Dest = "installers" } }
        
        foreach ($s in $sources) {
            if (-not (Test-Path $s.Path)) { continue }
            $dest = if ($s.Dest) { Join-Path $targetRoot $s.Dest } else { $targetRoot }
            if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
            
            Write-Host "[*] Syncing: $(Split-Path $s.Path -Leaf) -> $dest" -ForegroundColor Gray
            robocopy $s.Path $dest /S /R:2 /W:2 /MT:8 /NDL /NFL /NJH /NJS
        }
        Write-Host "[OK] Sync complete." -ForegroundColor Green
    } finally {
        Invoke-VhdRelease -VhdPath $Config.VhdPath -VMName $Config.VMName
    }
}

function Invoke-EnvironmentProvisioning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $Config,
        [string]$ScriptsDir
    )
    
    Write-Host "`n>>> [PROVISIONING ENGINE] Initializing New Environment..." -ForegroundColor Yellow
    
    $master = Read-MasterConfig
    $tplKey = $Config.HardwareTemplateKey
    if (-not $master.VMProvisioningTemplates.PSObject.Properties[$tplKey]) { throw "Provisioning Template '$tplKey' not found in config." }
    $tpl = $master.VMProvisioningTemplates.$tplKey
    
    $vmName = $Config.VMName
    if (Get-VM -Name $vmName -ErrorAction SilentlyContinue) { throw "ABORT: VM '$vmName' already exists." }
    
    # 1. Create VM
    Write-Host "[*] Creating VM: $vmName (Gen $($tpl.Generation))..." -ForegroundColor Cyan
    $vmPath = if ($tpl.VmMachinePath -eq "default") { (Get-VMHost).VirtualMachinePath } else { $tpl.VmMachinePath }
    
    $newParams = @{
        Name = $vmName
        Path = $vmPath
        Generation = $tpl.Generation
        MemoryStartupBytes = if ($tpl.MemoryStartupGB) { [long]$tpl.MemoryStartupGB * 1GB } else { 4GB }
        NoVHD = $true
    }
    if ($tpl.SwitchName -and $tpl.SwitchName -ne "Not Connected") { $newParams["SwitchName"] = $tpl.SwitchName }
    
    New-VM @newParams | Out-Null
    
    # 2. Configure Processor & Memory
    Set-VMProcessor -VMName $vmName -Count $tpl.ProcessorCount
    if ($tpl.DynamicMemoryEnabled) {
        Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $true -MinimumBytes 1GB -MaximumBytes $newParams.MemoryStartupBytes
    }
    
    # 3. Security (Gen2)
    if ($tpl.Generation -ge 2) {
        Set-VMFirmware -VMName $vmName -EnableSecureBoot ([Microsoft.HyperV.PowerShell.OnOffState]::On) -SecureBootTemplate $tpl.SecureBootTemplate
        if ($tpl.TpmEnabled) { Set-VMSecurity -VMName $vmName -TpmEnabled ([Microsoft.HyperV.PowerShell.OnOffState]::On) }
    }
    
    # 4. OS VHD Creation
    $osVhdFolder = Join-Path $vmPath $vmName "Virtual Hard Disks"
    if (-not (Test-Path $osVhdFolder)) { New-Item -ItemType Directory -Path $osVhdFolder -Force | Out-Null }
    $osVhdPath = Join-Path $osVhdFolder "$($vmName)_OS.vhdx"
    
    Write-Host "[*] Provisioning OS VHD ($($tpl.NewOsVhdSizeGB)GB)..." -ForegroundColor DarkGray
    New-VHD -Path $osVhdPath -SizeBytes ([long]$tpl.NewOsVhdSizeGB * 1GB) -Dynamic | Out-Null
    
    $controller = if ($tpl.Generation -ge 2) { "SCSI" } else { "IDE" }
    Add-VMHardDiskDrive -VMName $vmName -Path $osVhdPath -ControllerType $controller | Out-Null
    
    # 5. Attach Media (ISO)
    if ($Config.OSImagePath -and (Test-Path $Config.OSImagePath)) {
        Write-Host "    -> Attaching OS ISO: $(Split-Path $Config.OSImagePath -Leaf)" -ForegroundColor DarkGray
        $dvd = Add-VMDvdDrive -VMName $vmName -Path $Config.OSImagePath -PassThru
        if ($tpl.Generation -ge 2) { Set-VMFirmware -VMName $vmName -FirstBootDevice $dvd }
    }
    
    # 6. Finalization
    Set-VM -VMName $vmName -AutomaticCheckpointsEnabled (!$tpl.DisableAutomaticCheckpoints)
    if ($tpl.EnableGuestServices) {
        Get-VMIntegrationService -VMName $vmName | ForEach-Object {
            try { Enable-VMIntegrationService -VMName $vmName -Name $_.Name -ErrorAction SilentlyContinue } catch {}
        }
    }

    Write-Host "[OK] Provisioning Complete. VM is ready for first boot." -ForegroundColor Green
}
