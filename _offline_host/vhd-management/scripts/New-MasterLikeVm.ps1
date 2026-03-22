#Requires -RunAsAdministrator
#Requires -Modules Hyper-V
<#
.SYNOPSIS
    Creates a brand-new Hyper-V VM from a VM profile in _master_config.json (JSONC).

.DESCRIPTION
    Does NOT copy an existing OS VHD. Creates a new dynamic VHD, attaches optional Windows ISO from the profile,
    provisions hardware/network from `VMProvisioningTemplates` (selected via `VMProfiles.<key>.HardwareTemplate` or `-ProvisioningTemplateKey`),
    attaches the shared staging VHD,
    enables integration services, disables automatic checkpoints.

    IMPORTANT: This script is provisioning-driven. It does not mirror any separately-existing template VM.

.PARAMETER VMProfile
    Key under VMProfiles (e.g. TrialVM, Windows 11 Master).

.PARAMETER TemplateHardwareProfile
    (Deprecated) Kept for compatibility. Not used by this implementation.

.PARAMETER ConfigPath
    Path to _master_config.json (default: repo root).

.EXAMPLE
    .\New-MasterLikeVm.ps1 -VMProfile TrialVM
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$VMProfile,
    [string]$TemplateHardwareProfile,
    [string]$ConfigPath,
    [string]$ProvisioningTemplateKey,
    [string]$VMNameOverride,
    [string]$VmMachinePathOverride,
    [switch]$NoConfigSave,
    [switch]$SkipStagingVhd,
    [switch]$SkipDvd
)

$ErrorActionPreference = 'Stop'

try {
    # Resolve project root relative to this script
    $LocalProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent

    . (Join-Path $LocalProjectRoot "_helpers\ConfigUtils.ps1")

    if (-not $ConfigPath) { $ConfigPath = Join-Path $LocalProjectRoot '_master_config.json' }

    $master = Read-JsonCFile -Path $ConfigPath

    $pk = if ($VMProfile) { $VMProfile.Trim() } else { Get-ActiveVmProfileKey -Master $master }
    $ctx = Build-MergedHostVmConfig -Master $master -ProfileKey $pk

    $tplKey = $ProvisioningTemplateKey
    if ([string]::IsNullOrWhiteSpace($tplKey)) {
        $tplKey = $ctx.HardwareTemplateKey
    }
    if ([string]::IsNullOrWhiteSpace($tplKey)) {
        throw "Provisioning template key is required. Set VMProfiles.<key>.HardwareTemplate or pass -ProvisioningTemplateKey."
    }
    if ($null -eq $master.VMProvisioningTemplates) {
        throw "VMProvisioningTemplates missing from _master_config.json."
    }
    $tplProp = $master.VMProvisioningTemplates.PSObject.Properties[$tplKey]
    if ($null -eq $tplProp) {
        throw "VMProvisioningTemplates.$tplKey not found."
    }
    $prov = $tplProp.Value

    $newName = $ctx.VMName
    if (-not [string]::IsNullOrWhiteSpace($VMNameOverride)) {
        $newName = $VMNameOverride.Trim()
    }
    if ([string]::IsNullOrWhiteSpace($newName)) {
        throw "Profile '$pk' VMDetails.VMName is empty."
    }
    if (Get-VM -Name $newName -ErrorAction SilentlyContinue) {
        throw "A VM named '$newName' already exists. Remove it or use a different profile."
    }

    $requiredNonNull = @(
        'NewOsVhdSizeGB',
        'VmMachinePath',
        'AttachStagingVhd',
        'EnableGuestServices',
        'EnableEnhancedSession',
        'DisableAutomaticCheckpoints',
        'Generation',
        'DynamicMemoryEnabled',
        'EnableSecureBoot',   # validated only when gen>=2
        'SecureBootTemplate', # validated only when gen>=2
        'TpmEnabled'         # validated only when gen>=2
    )

    foreach ($k in $requiredNonNull) {
        if (-not $prov -or -not $prov.PSObject.Properties[$k] -or $null -eq $prov.$k) {
            # Only enforce secure-boot/tpm keys when the VM generation will use them.
            if ($k -in @('EnableSecureBoot', 'SecureBootTemplate', 'TpmEnabled')) {
                # Defer validation until after $gen is known.
                continue
            }
            throw "VMProvisioningTemplates.$tplKey.$k is required but was not found (or is null). Update _master_config.json VMProvisioningTemplates."
        }
    }

    if (-not (($prov.PSObject.Properties['ProcessorCount'] -and $null -ne $prov.ProcessorCount) -or ($prov.PSObject.Properties['ProcCount'] -and $null -ne $prov.ProcCount))) {
        throw "VMProvisioningTemplates.$tplKey.ProcessorCount (or ProcCount) is required but was not found."
    }

    if (-not ($prov.PSObject.Properties['SwitchName'] -or $prov.PSObject.Properties['VMSwitch'])) {
        throw "VMProvisioningTemplates.$tplKey.SwitchName (or VMSwitch) key is required."
    }

    $sizeGb = [long]$prov.NewOsVhdSizeGB
    
    # Resolve VmMachinePath: Template -> Override -> Host Default
    $rawVmPath = if ($prov.PSObject.Properties['VmMachinePath']) { $prov.VmMachinePath.ToString().Trim() } else { "" }
    if (-not [string]::IsNullOrWhiteSpace($VmMachinePathOverride)) {
        $rawVmPath = $VmMachinePathOverride.Trim()
    }
    
    if ([string]::IsNullOrWhiteSpace($rawVmPath) -or $rawVmPath -ieq "default") {
        try {
            $hostPath = (Get-VMHost).VirtualMachinePath
            if ([string]::IsNullOrWhiteSpace($hostPath)) { throw "Hyper-V Host VirtualMachinePath is empty." }
            $vmMachinePath = ($hostPath -replace '/', '\')
            Write-Host "[*] Using Hyper-V host default path: $vmMachinePath" -ForegroundColor DarkGray
        } catch {
            throw "VmMachinePath is not specified in template/override, and failed to retrieve Hyper-V host default: $($_.Exception.Message)"
        }
    } else {
        $vmMachinePath = ($rawVmPath -replace '/', '\')
    }

    if ($vmMachinePath.Trim().Length -eq 0) { throw "VMProvisioningTemplates.$tplKey.VmMachinePath could not be resolved (template/override/host-default all empty)." }

    $attachStaging = $false
    if (-not $SkipStagingVhd) {
        $attachStaging = [bool]$prov.AttachStagingVhd
    }
    $stagingPath = ($ctx.VhdPath -replace '/', '\')

    $isoPath = $null
    if (-not $SkipDvd -and $ctx.OSImagePath) {
        $isoPath = ($ctx.OSImagePath.ToString() -replace '/', '\')
        if (-not (Test-Path -LiteralPath $isoPath)) {
            Write-Warning "OS ISO not found: $isoPath — continuing without DVD."
            $isoPath = $null
        }
    }

    $gen = [int]$prov.Generation

    if ($gen -ge 2) {
        foreach ($k in @('EnableSecureBoot', 'SecureBootTemplate', 'TpmEnabled')) {
            if (-not $prov.PSObject.Properties[$k] -or $null -eq $prov.$k) {
                throw "VMProvisioningTemplates.$tplKey.$k is required when Generation >= 2."
            }
        }
    }

    function ConvertTo-Bytes {
        param([Parameter(Mandatory = $true)]$Value)
        if ($null -eq $Value) { return $null }
        if ($Value -is [int] -or $Value -is [long] -or $Value -is [double]) { return [long]$Value }
        $s = $Value.ToString().Trim()
        if ($s -match '^\s*([\d\.]+)\s*(b|kb|mb|gb)\s*$') {
            $n = [double]$Matches[1]
            $u = $Matches[2].ToLower()
            switch ($u) {
                'b' { return [long]$n }
                'kb' { return [long]($n * 1KB) }
                'mb' { return [long]($n * 1MB) }
                'gb' { return [long]($n * 1GB) }
            }
        }
        if ($s -match '^\d+$') { return [long]$s }
        return $null
    }

    $memStartup = $null
    if ($prov.PSObject.Properties['MemoryStartupBytes'] -and $null -ne $prov.MemoryStartupBytes) { $memStartup = ConvertTo-Bytes $prov.MemoryStartupBytes }
    elseif ($prov.PSObject.Properties['MemoryStartupGB'] -and $null -ne $prov.MemoryStartupGB) { $memStartup = ConvertTo-Bytes $prov.MemoryStartupGB }
    elseif ($prov.PSObject.Properties['MemoryStartupMB'] -and $null -ne $prov.MemoryStartupMB) { $memStartup = ConvertTo-Bytes $prov.MemoryStartupMB }
    else { throw "VMProvisioningTemplates.$tplKey.MemoryStartupBytes (or MemoryStartupGB/MB) is required." }
    if ($null -eq $memStartup) { throw "VMProvisioningTemplates.$tplKey.MemoryStartup value could not be parsed to bytes." }

    $procCount = if ($prov.PSObject.Properties['ProcessorCount'] -and $null -ne $prov.ProcessorCount) { [int]$prov.ProcessorCount } else { [int]$prov.ProcCount }

    $rawSwitchName = if ($prov.PSObject.Properties['SwitchName']) { $prov.SwitchName } else { $prov.VMSwitch }
    if ($null -eq $rawSwitchName) { $switchName = 'Not Connected' } else { $switchName = $rawSwitchName.ToString().Trim() }
    if ([string]::IsNullOrWhiteSpace($switchName)) { $switchName = 'Not Connected' }

    $isNotConnected = ($switchName -ieq 'Not Connected')

    # --- Path Validation ---
    if (-not (Test-Path -LiteralPath $vmMachinePath)) {
        throw "VmMachinePath does not exist: $vmMachinePath (Check VMProvisioningTemplates.$tplKey.VmMachinePath in _master_config.json)"
    }
    # Ensure we can write to the directory
    $testFile = Join-Path $vmMachinePath ".GI_Write_Test_$(Get-Random).tmp"
    try {
        New-Item -ItemType File -Path $testFile -Force | Out-Null
        Remove-Item -Path $testFile -Force | Out-Null
    } catch {
        throw "VmMachinePath exists but is not writeable by this script: $vmMachinePath`n  Error: $($_.Exception.Message)"
    }

    $osFileName = "$($newName -replace '[^\w\-]', '_')_OS.vhdx"

    Write-Host ""
    Write-Host "=== New VM from profile ===" -ForegroundColor Cyan
    Write-Host "  Profile:      $pk" -ForegroundColor Gray
    Write-Host "  VM name:      $newName" -ForegroundColor Gray
    Write-Host "  OS VHD:       ${sizeGb} GB (new dynamic)" -ForegroundColor Gray
    Write-Host "  ISO:          $(if ($isoPath) { $isoPath } else { '(none)' })" -ForegroundColor DarkGray
    Write-Host "  Provisioning: gen=$gen vCPU=$procCount RAMStartup=$memStartup Switch=$switchName" -ForegroundColor DarkGray
    Write-Host "  Path:         $vmMachinePath" -ForegroundColor DarkGray
    Write-Host ""

    if (-not $PSCmdlet.ShouldProcess($newName, "Create new VM from profile '$pk'")) { return }

    $newVmParams = @{
        Name               = $newName
        Path               = $vmMachinePath
        Generation         = $gen
        MemoryStartupBytes = $memStartup
        NoVHD              = $true
        ErrorAction        = 'Stop'
    }
    if ($switchName -and -not $isNotConnected) { $newVmParams['SwitchName'] = $switchName }
    
    Write-Host "[*] Creating VM '$newName'..." -ForegroundColor DarkGray
    foreach ($k in $newVmParams.Keys) {
        Write-Debug "    Parameter: $k = $($newVmParams[$k])"
    }

    try {
        New-VM @newVmParams | Out-Null
    } catch {
        $ex = $_.Exception
        $errorDetail = "New-VM failed with message: $($ex.Message)"
        if ($ex.InnerException) {
            $errorDetail += "`n  Inner Exception: $($ex.InnerException.Message)"
        }
        
        $errorDetail += "`n`n  Context Info:"
        $errorDetail += "`n    VM Name:   $newName"
        $errorDetail += "`n    VM Path:   $vmMachinePath"
        $errorDetail += "`n    Gen:       $gen"
        $errorDetail += "`n    RAM:       $memStartup"
        $errorDetail += "`n    Switch:    $switchName"
        
        if ($null -ne $_.FullyQualifiedErrorId) {
            $errorDetail += "`n    ErrorId:   $($_.FullyQualifiedErrorId)"
        }
        
        # If it's a "Failed to create a new virtual machine" error, it's often a permission issue or a path issue.
        if ($ex.Message -like "*Failed to create a new virtual machine*") {
            $errorDetail += "`n`n  Troubleshooting Tip: This generic Hyper-V error often means the service account (Virtual Machines) doesn't have permissions to the Path, or the Path is on a drive that doesn't support Hyper-V (e.g. some network shares or compressed drives)."
        }
        
        throw $errorDetail
    }

    $vmPath = (Get-VM -Name $newName).Path
    $vhdFolder = Join-Path $vmPath 'Virtual Hard Disks'
    if (-not (Test-Path -LiteralPath $vhdFolder)) {
        New-Item -ItemType Directory -Path $vhdFolder -Force | Out-Null
    }
    $osVhd = Join-Path $vhdFolder $osFileName
    
    Write-Host "[*] Creating OS VHD: $osVhd" -ForegroundColor DarkGray
    New-VHD -Path $osVhd -SizeBytes ($sizeGb * 1GB) -Dynamic -ErrorAction Stop | Out-Null

    if ($gen -ge 2) {
        Add-VMHardDiskDrive -VMName $newName -Path $osVhd -ControllerType SCSI | Out-Null
    } else {
        Add-VMHardDiskDrive -VMName $newName -Path $osVhd -ControllerType IDE | Out-Null
    }

    Set-VMProcessor -VMName $newName -Count $procCount
    if ($prov -and $null -ne $prov.ExposeVirtualizationExtensions) {
        try {
            Set-VMProcessor -VMName $newName -ExposeVirtualizationExtensions ([bool]$prov.ExposeVirtualizationExtensions) -ErrorAction SilentlyContinue
        } catch { }
    }

    try {
        $dynamicEnabled = [bool]$prov.DynamicMemoryEnabled
        if ($dynamicEnabled) {
            $dynStartup = if ($prov.PSObject.Properties['DynamicMemoryStartupBytes'] -and $null -ne $prov.DynamicMemoryStartupBytes) { ConvertTo-Bytes $prov.DynamicMemoryStartupBytes }
                elseif ($prov.PSObject.Properties['DynamicMemoryStartupGB'] -and $null -ne $prov.DynamicMemoryStartupGB) { ConvertTo-Bytes $prov.DynamicMemoryStartupGB }
                elseif ($prov.PSObject.Properties['DynamicMemoryStartupMB'] -and $null -ne $prov.DynamicMemoryStartupMB) { ConvertTo-Bytes $prov.DynamicMemoryStartupMB }
                else { $null }
            if ($null -eq $dynStartup) { throw "VMProvisioningTemplates.$tplKey.DynamicMemoryStartupBytes (or GB/MB) is required when DynamicMemoryEnabled=true." }

            $dynMin = if ($prov.PSObject.Properties['DynamicMemoryMinimumBytes'] -and $null -ne $prov.DynamicMemoryMinimumBytes) { ConvertTo-Bytes $prov.DynamicMemoryMinimumBytes }
                elseif ($prov.PSObject.Properties['DynamicMemoryMinimumGB'] -and $null -ne $prov.DynamicMemoryMinimumGB) { ConvertTo-Bytes $prov.DynamicMemoryMinimumGB }
                elseif ($prov.PSObject.Properties['DynamicMemoryMinimumMB'] -and $null -ne $prov.DynamicMemoryMinimumMB) { ConvertTo-Bytes $prov.DynamicMemoryMinimumMB }
                else { $null }
            if ($null -eq $dynMin) { throw "VMProvisioningTemplates.$tplKey.DynamicMemoryMinimumBytes (or GB/MB) is required when DynamicMemoryEnabled=true." }

            $dynMax = if ($prov.PSObject.Properties['DynamicMemoryMaximumBytes'] -and $null -ne $prov.DynamicMemoryMaximumBytes) { ConvertTo-Bytes $prov.DynamicMemoryMaximumBytes }
                elseif ($prov.PSObject.Properties['DynamicMemoryMaximumGB'] -and $null -ne $prov.DynamicMemoryMaximumGB) { ConvertTo-Bytes $prov.DynamicMemoryMaximumGB }
                elseif ($prov.PSObject.Properties['DynamicMemoryMaximumMB'] -and $null -ne $prov.DynamicMemoryMaximumMB) { ConvertTo-Bytes $prov.DynamicMemoryMaximumMB }
                else { $null }
            if ($null -eq $dynMax) { throw "VMProvisioningTemplates.$tplKey.DynamicMemoryMaximumBytes (or GB/MB) is required when DynamicMemoryEnabled=true." }

            Set-VMMemory -VMName $newName -DynamicMemoryEnabled $true -StartupBytes $dynStartup -MinimumBytes $dynMin -MaximumBytes $dynMax -ErrorAction SilentlyContinue
        } else {
            Set-VMMemory -VMName $newName -DynamicMemoryEnabled $false -StartupBytes $memStartup -ErrorAction SilentlyContinue
        }

        if ($prov -and $null -ne $prov.MemoryPriority) {
            Set-VMMemory -VMName $newName -Priority $prov.MemoryPriority -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Warning "Set-VMMemory: $_"
    }

    if ($gen -ge 2) {
        try {
            $enableSecureBoot = [bool]$prov.EnableSecureBoot
            $secureBootTemplate = $prov.SecureBootTemplate.ToString().Trim()
            if ($secureBootTemplate.Length -eq 0) { throw "VMProvisioningTemplates.$tplKey.SecureBootTemplate must be non-empty." }
            $secureBootOnOff = if ($enableSecureBoot) { [Microsoft.HyperV.PowerShell.OnOffState]::On } else { [Microsoft.HyperV.PowerShell.OnOffState]::Off }
            Set-VMFirmware -VMName $newName -EnableSecureBoot $secureBootOnOff -SecureBootTemplate $secureBootTemplate -ErrorAction Stop
        } catch {
            Write-Warning "Set-VMFirmware: $_"
        }
        try {
            $tpmEnabled = [bool]$prov.TpmEnabled
            $tpmOnOff = if ($tpmEnabled) { [Microsoft.HyperV.PowerShell.OnOffState]::On } else { [Microsoft.HyperV.PowerShell.OnOffState]::Off }
            Set-VMSecurity -VMName $newName -TpmEnabled $tpmOnOff -ErrorAction SilentlyContinue
        } catch { }
    }

    if (-not $isNotConnected -and $switchName) {
        Get-VMNetworkAdapter -VMName $newName -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.SwitchName -ne $switchName) {
                Connect-VMNetworkAdapter -VMName $newName -Name $_.Name -SwitchName $switchName
            }
        }
    }

    if ($isoPath) {
        Add-VMDvdDrive -VMName $newName -Path $isoPath
        try {
            $dvd = Get-VMDvdDrive -VMName $newName | Select-Object -First 1
            $hdd = Get-VMHardDiskDrive -VMName $newName | Select-Object -First 1
            if ($dvd -and $hdd) {
                Set-VMFirmware -VMName $newName -BootOrder @($dvd, $hdd)
            }
        } catch {
            Write-Warning "Boot order (DVD first): $_"
        }
    }

    if ($attachStaging) {
        if (-not (Test-Path -LiteralPath $stagingPath)) {
            Write-Warning "Staging VHD not found: $stagingPath"
        } else {
            Add-VMHardDiskDrive -VMName $newName -Path $stagingPath -ControllerType SCSI
            Write-Host "[*] Staging VHD attached: $stagingPath" -ForegroundColor Green
        }
    }

    $enableGuest = [bool]$prov.EnableGuestServices
    $enableEnh = [bool]$prov.EnableEnhancedSession

    if ($enableGuest) {
        foreach ($svc in Get-VMIntegrationService -VMName $newName -ErrorAction SilentlyContinue) {
            if ($svc.Enabled) { continue }
            try {
                Enable-VMIntegrationService -VMName $newName -Name $svc.Name -ErrorAction Stop
            } catch {
                Write-Warning "Integration service '$($svc.Name)': $_"
            }
        }
    }

    if ($enableEnh) {
        try {
            Set-VMHost -EnableEnhancedSessionMode $true -ErrorAction SilentlyContinue
            Set-VM -VMName $newName -EnhancedSessionTransportType HvSocket -ErrorAction SilentlyContinue
        } catch { }
    }

    $disableAutoCp = [bool]$prov.DisableAutomaticCheckpoints
    if ($disableAutoCp) {
        try {
            Set-VM -VMName $newName -AutomaticCheckpointsEnabled $false -ErrorAction Stop
        } catch {
            Write-Warning "Automatic checkpoints: $_"
        }
    }

    Get-VMSnapshot -VMName $newName -ErrorAction SilentlyContinue | Remove-VMSnapshot -IncludeAllChildSnapshots -ErrorAction SilentlyContinue

    if (-not $NoConfigSave) {
        try {
            Save-HostVmSettingsToMaster -VMProfileKey $pk -OsVhdPath $osVhd
        } catch {
            Write-Warning "Could not save VMDetails.OsVhdPath to _master_config.json: $_"
        }
    }

    Write-Host ""
    Write-Host "Done. VM '$newName' created (blank OS disk — install from ISO if attached)." -ForegroundColor Green
    Write-Host "  OS VHD: $osVhd" -ForegroundColor Gray
    Write-Host "  Point tools at this profile: `$env:GOLDEN_IMAGE_VM_PROFILE = '$pk'" -ForegroundColor DarkYellow
    if ($NoConfigSave) {
        Write-Host "  Config writes skipped (-NoConfigSave)." -ForegroundColor DarkGray
    } else {
        Write-Host "  Update config in _master_config.json (dashboard CH/CV/CG/CA) or set `$env:GOLDEN_IMAGE_VM_PROFILE." -ForegroundColor DarkGray
    }
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to create virtual machine." -ForegroundColor Red
    Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Yellow
    if ($_.ScriptStackTrace) {
        Write-Host "  Location: $($_.ScriptStackTrace.Split("`n")[0])" -ForegroundColor DarkGray
    }
    Write-Host ""
    exit 1
}

