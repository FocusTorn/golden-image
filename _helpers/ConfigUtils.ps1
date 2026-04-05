<##
.SYNOPSIS
    Workspace-wide configuration management utilities.
    Loads JSONC master config, resolves VM profiles, and syncs derived JSON files.

.NOTES
    Host VM settings (Get-Config -Target Host) come only from _master_config.json (JSONC):
      VM profile (VMProfiles.<key> or legacy top-level profile) + VMFileSystem + VMCredentials + shared/offline_host fallbacks.

    Active profile: $env:GOLDEN_IMAGE_VM_PROFILE, else master.activeVMProfile, else master.defaultVMProfile,
    else first VMProfiles entry, else 'Windows 11 Master' if present.
##>

$LocalProjectRoot = Split-Path $PSScriptRoot -Parent
$MasterConfigPath = Join-Path $LocalProjectRoot "_master_config.yaml"
$GuestConfigPath = Join-Path $LocalProjectRoot "_offline\_offline_config.json"

$script:ReservedMasterKeys = @(
    'shared', '_offline', 'offline_host', 'ahk',
    'VMDetails', 'VMFileSystem', 'VMCredentials', 'VMProvisioning',
    'defaultVMProfile', 'activeVMProfile', 'VMProfiles', 'VMProfile',
    'VMProvisioningTemplates', 'MasterPaths', 'LocalProjectRoot'
)

function Read-JsonCFile {
    [CmdletBinding()]
    param([string]$Path)
    if ($Path -like "*.yaml") {
        return Read-MasterConfig -Path $Path
    }
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }
    $raw = Get-Content $Path -Raw
    # Strip comments for basic JSON compatibility if needed
    $clean = $raw -replace '(?m)^\s*//.*$', '' -replace '(?m)\s*//.*$', ''
    try { return $clean | ConvertFrom-Json } catch { throw "Failed to parse $Path logic. Error: $($_.Exception.Message)" }
}

function Test-IsLikelyVmProfileObject { #>
    param($Node)
    return $null -ne $Node -and ($Node -is [PSCustomObject]) -and $null -ne $Node.PSObject.Properties['VMDetails']
} #<

# --- YAML ENGINE (Zero-G Pure-PS Parser) ---

function ConvertFrom-Yaml {
    [CmdletBinding()]
    param([string]$Yaml)
    
    $obj = [PSCustomObject]@{}
    $lines = $Yaml -split "`r?`n"
    $context = New-Object System.Collections.Generic.Stack[object]
    $context.Push(@{ Indent = -1; Node = $obj })
    
    foreach ($lineRaw in $lines) {
        $trimmed = $lineRaw.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) { continue }
        
        $indent = $lineRaw.IndexOf($trimmed[0])
        $line = $trimmed
        
        if ($line -match "^([^:]+):\s*(.*)$") {
            $key = $Matches[1].Trim("- ").Trim().Trim('"').Trim("'")
            $val = $Matches[2].Trim()
            
            # Pop context until we find the parent (indent must be strictly less)
            while ($context.Count -gt 1 -and $context.Peek().Indent -ge $indent) {
                [void]$context.Pop()
            }
            
            $target = $context.Peek().Node
            if ($val -eq "") {
                $newObj = [PSCustomObject]@{}
                $target | Add-Member -MemberType NoteProperty -Name $key -Value $newObj -Force
                $context.Push(@{ Indent = $indent; Node = $newObj })
            } else {
                $cleanVal = $val.Trim('"').Trim("'")
                # Simple type detection
                $typedVal = if($cleanVal -eq 'true'){$true} elseif($cleanVal -eq 'false'){$false} elseif($cleanVal -match '^\d+$'){$cleanVal -as [int]} else {$cleanVal}
                $target | Add-Member -MemberType NoteProperty -Name $key -Value $typedVal -Force
            }
        }
    }
    return $obj
}

function Assert-Path {
    param($Path, $Name = "Value")
    if (-not (Test-Path $Path)) { throw "Critical: Required Path '$Path' ($Name) not found." }
}

function Read-MasterConfig {
    param([string]$Path = $MasterConfigPath)
    if (-not (Test-Path $Path)) { throw "Config not found: $Path" }
    $raw = Get-Content $Path -Raw
    return ConvertFrom-Yaml -Yaml $raw
}

function Get-FirstNonEmpty { #>
    param([object[]]$Candidates)
    foreach ($c in $Candidates) {
        if ($null -eq $c) { continue }
        if ($c -is [string]) {
            if ($c.Trim().Length -gt 0) { return $c }
        } else {
            return $c
        }
    }
    return $null
} #<

function Get-VmProfileSection { #>
    param(
        [Parameter(Mandatory = $true)]$Master,
        [Parameter(Mandatory = $true)][string]$ProfileKey
    )
    if ($Master.VMProfiles -and $Master.VMProfiles.PSObject.Properties[$ProfileKey]) {
        return $Master.VMProfiles.$ProfileKey
    }
    if ($Master.PSObject.Properties[$ProfileKey] -and (Test-IsLikelyVmProfileObject $Master.$ProfileKey)) {
        return $Master.$ProfileKey
    }
    throw "Unknown VM profile '$ProfileKey'. Define it under VMProfiles or as a legacy top-level profile object."
} #<

function Get-ActiveVmProfileKey { #>
    param($Master)
    if ($env:GOLDEN_IMAGE_VM_PROFILE -and $env:GOLDEN_IMAGE_VM_PROFILE.Trim().Length -gt 0) {
        return $env:GOLDEN_IMAGE_VM_PROFILE.Trim()
    }
    $candidates = @(
        $Master.activeVMProfile
        $Master.defaultVMProfile
    )
    foreach ($c in $candidates) {
        if ($c -is [string] -and $c.Trim().Length -gt 0) { return $c.Trim() }
    }
    if ($Master.VMProfiles) {
        $names = @($Master.VMProfiles.PSObject.Properties | ForEach-Object Name)
        if ($names -contains 'Windows 11 Master') { return 'Windows 11 Master' }
        if ($names.Count -gt 0) { return $names[0] }
    }
    foreach ($p in $Master.PSObject.Properties) {
        if ($script:ReservedMasterKeys -icontains $p.Name) { continue }
        if ($p.Name -like '---*') { continue }
        if (Test-IsLikelyVmProfileObject $p.Value) { return $p.Name }
    }
    throw "Could not determine active VM profile. Set defaultVMProfile, VMProfiles, or `$env:GOLDEN_IMAGE_VM_PROFILE."
} #<

function Get-VmProfileNames { #>
    param(
        $Master = $null
    )
    if (-not $Master) {
        $Master = Read-MasterConfig -Path $MasterConfigPath
    }
    $ordered = [System.Collections.Generic.List[string]]::new()
    $seen = @{}
    if ($Master.VMProfiles) {
        foreach ($p in $Master.VMProfiles.PSObject.Properties) {
            if (-not $seen.ContainsKey($p.Name)) {
                $ordered.Add($p.Name)
                $seen[$p.Name] = $true
            }
        }
    }
    foreach ($prop in $Master.PSObject.Properties) {
        if ($script:ReservedMasterKeys -icontains $prop.Name) { continue }
        if ($prop.Name -like '---*') { continue }
        if (-not (Test-IsLikelyVmProfileObject $prop.Value)) { continue }
        if (-not $seen.ContainsKey($prop.Name)) {
            $ordered.Add($prop.Name)
            $seen[$prop.Name] = $true
        }
    }
    return @($ordered)
} #<

function Get-ProfileResolutionSummary { #>
    param($Master = $null)
    if (-not $Master) {
        $Master = Read-MasterConfig -Path $MasterConfigPath
    }
    $resolved = Get-ActiveVmProfileKey -Master $Master
    [PSCustomObject]@{
        EnvGOLDEN_IMAGE_VM_PROFILE = $env:GOLDEN_IMAGE_VM_PROFILE
        MasterActiveVMProfile      = $Master.activeVMProfile
        MasterDefaultVMProfile     = $Master.defaultVMProfile
        ResolvedProfileKey         = $resolved
    }
} #<

function Build-MergedHostVmConfig { #>
    param(
        [Parameter(Mandatory = $true)]$Master,
        [Parameter(Mandatory = $true)][string]$ProfileKey
    )
    $prof = Get-VmProfileSection -Master $Master -ProfileKey $ProfileKey
    $vd = $prof.VMDetails
    
    if (-not $vd) { throw "Profile '$ProfileKey' is missing VMDetails." }

    $hwTemplateKey = Get-FirstNonEmpty @($prof.HardwareTemplate)

    $fs = $Master.VMFileSystem
    $cred = $Master.VMCredentials
    $legacy = $Master.VMDetails
    $oh = $Master.offline_host
    $sh = $Master.shared

    $vhd = Get-FirstNonEmpty @(
        $vd.VhdPath
        $(if ($fs) { $fs.HostVhdPath })
        $(if ($legacy) { $legacy.VhdPath })
        $(if ($oh) { $oh.VhdPath })
    )
    $vmName = Get-FirstNonEmpty @($vd.VMName, $(if ($oh) { $oh.VMName }))
    $vmHostName = Get-FirstNonEmpty @($vd.VMHostname, $(if ($legacy) { $legacy.VMHostname }), $(if ($sh) { $sh.VMHostname }))

    $guestDrive = Get-FirstNonEmpty @(
        $(if ($fs) { $fs.GuestStagingDrive })
        $(if ($sh) { $sh.GuestStagingDrive })
        'E'
    )
    $stagingLabel = Get-FirstNonEmpty @($(if ($fs) { $fs.StagingVolumeLabel }), $(if ($sh) { $sh.StagingVolumeLabel }))
    $offline = Get-FirstNonEmpty @($(if ($fs) { $fs.OfflinePath }), $(if ($sh) { $sh.OfflinePath }), '_offline')
    $installers = Get-FirstNonEmpty @($(if ($fs) { $fs.InstallersPath }), $(if ($sh) { $sh.InstallersPath }), 'installers')
    $returnPath = Get-FirstNonEmpty @($(if ($fs) { $fs.ReturnPath }), $(if ($sh) { $sh.ReturnPath }), 'return')

    $vmUser = Get-FirstNonEmpty @($(if ($cred) { $cred.VMUser }), $(if ($oh) { $oh.VMUser }), 'Administrator')
    $vmPass = Get-FirstNonEmpty @($(if ($cred) { $cred.VMPassword }), $(if ($oh) { $oh.VMPassword }))
    $usePass = if ($null -ne $cred -and $null -ne $cred.UsePasswordCreds) { $cred.UsePasswordCreds }
    elseif ($null -ne $oh -and $null -ne $oh.UsePasswordCreds) { $oh.UsePasswordCreds }
    else { $false }

    $cfg = [PSCustomObject]@{
        ProfileKey          = $ProfileKey
        HardwareTemplateKey = $hwTemplateKey
        VhdPath             = ($vhd -replace '\\', '/')
        WimDestination      = $(if ($vd.WimDestination) { ($vd.WimDestination -replace '\\', '/') } else { $null })
        HostVhdPath         = $(if ($fs -and $fs.HostVhdPath) { ($fs.HostVhdPath -replace '\\', '/') } else { $null })
        OsVhdPath           = $(if ($vd.OsVhdPath) { ($vd.OsVhdPath -replace '\\', '/') } else { $null })
        VMName              = $vmName
        VMHostname          = $vmHostName
        GuestStagingDrive   = $guestDrive.ToString().Trim().TrimEnd(':')[0]
        StagingVolumeLabel  = $stagingLabel
        OfflinePath         = $offline
        InstallersPath      = $installers
        ReturnPath          = $returnPath
        VMUser              = $vmUser
        VMPassword          = $vmPass
        UsePasswordCreds    = [bool]$usePass
        OSImagePath         = $vd.OSImagePath
        UnattendIsoPath     = $vd.UnattendIsoPath
        MasterPaths         = $null
    }

    # --- HIERARCHICAL MASTER PATHS RESOLUTION ---
    $globalMasterPaths = $Master.MasterPaths
    $profileMasterPaths = $prof.MasterPaths
    
    $mergedMasterPaths = @{}
    # 1. Start with Global Defaults
    if ($globalMasterPaths) {
        foreach ($prop in $globalMasterPaths.psobject.Properties) {
            $mergedMasterPaths[$prop.Name] = $prop.Value
        }
    }
    # 2. Layer Profile Overrides
    if ($profileMasterPaths) {
        foreach ($prop in $profileMasterPaths.psobject.Properties) {
            $mergedMasterPaths[$prop.Name] = $prop.Value
        }
    }
    
    # 3. Add to clean PSCustomObject
    $finalPaths = [PSCustomObject]@{}
    foreach ($k in $mergedMasterPaths.Keys) {
        $finalPaths | Add-Member -MemberType NoteProperty -Name $k -Value ($mergedMasterPaths[$k] -replace '\\', '/')
    }
    
    $cfg.MasterPaths = $finalPaths
    return $cfg
} #<




# --- Mutable master JSON (comments in file are stripped on save; use PS 7+ JsonNode or Newtonsoft) ---

function Read-MasterJsonEditable { #>
    if (-not (Test-Path -LiteralPath $MasterConfigPath)) {
        throw "Master config not found: $MasterConfigPath"
    }
    $raw = Get-Content -LiteralPath $MasterConfigPath -Raw -Encoding UTF8
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $docOpts = [System.Text.Json.JsonDocumentOptions]::new()
        $docOpts.CommentHandling = [System.Text.Json.JsonCommentHandling]::Skip
        $docOpts.AllowTrailingCommas = $true
        $root = [System.Text.Json.Nodes.JsonNode]::Parse($raw, $null, $docOpts)
        return @{ Kind = 'Node'; Root = $root }
    }
    Ensure-NewtonsoftJsonLoaded
    $ls = New-Object Newtonsoft.Json.Linq.JsonLoadSettings
    $ls.CommentHandling = [Newtonsoft.Json.Linq.CommentHandling]::Ignore
    $root = [Newtonsoft.Json.Linq.JObject]::Parse($raw, $ls)
    return @{ Kind = 'JObject'; Root = $root }
} #<

function Write-MasterJsonEditable { #>
    param([hashtable]$Doc)
    $tmp = "$MasterConfigPath.tmp"
    if ($Doc.Kind -eq 'Node') {
        $opt = [System.Text.Json.JsonSerializerOptions]::new()
        $opt.WriteIndented = $true
        $text = $Doc.Root.ToJsonString($opt)
    } else {
        $text = $Doc.Root.ToString([Newtonsoft.Json.Formatting]::Indented)
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tmp, $text, $utf8NoBom)
    Move-Item -LiteralPath $tmp -Destination $MasterConfigPath -Force
} #<




function Get-ProfileVmDetailsEditable { #>
    param(
        $Doc,
        [string]$ProfileKey
    )
    if ($Doc.Kind -eq 'Node') {
        $r = $Doc.Root
        $pfs = $r['VMProfiles']
        if ($null -ne $pfs -and $null -ne $pfs[$ProfileKey]) {
            $vd = $pfs[$ProfileKey]['VMDetails']
            if ($null -eq $pfs[$ProfileKey]['VMDetails']) {
                $pfs[$ProfileKey]['VMDetails'] = [System.Text.Json.Nodes.JsonObject]::Create()
            }
            return , $pfs[$ProfileKey]['VMDetails']
        }
        if ($null -ne $r[$ProfileKey]) {
            if ($null -eq $r[$ProfileKey]['VMDetails']) {
                $r[$ProfileKey]['VMDetails'] = [System.Text.Json.Nodes.JsonObject]::Create()
            }
            return , $r[$ProfileKey]['VMDetails']
        }
        throw "Profile '$ProfileKey' not found under VMProfiles or as a top-level profile object."
    }
    $jo = $Doc.Root
    $vmProfiles = $jo['VMProfiles']
    if ($null -ne $vmProfiles -and $null -ne $vmProfiles[$ProfileKey]) {
        $prof = $vmProfiles[$ProfileKey]
        if ($null -eq $prof['VMDetails']) { $prof['VMDetails'] = New-Object Newtonsoft.Json.Linq.JObject }
        return , $prof['VMDetails']
    }
    if ($null -ne $jo[$ProfileKey]) {
        $prof = $jo[$ProfileKey]
        if ($null -eq $prof['VMDetails']) { $prof['VMDetails'] = New-Object Newtonsoft.Json.Linq.JObject }
        return , $prof['VMDetails']
    }
    throw "Profile '$ProfileKey' not found under VMProfiles or as a top-level profile object."
} #<

function Save-HostVmSettingsToMaster { #>
    <##
    .SYNOPSIS
        Writes host-oriented settings into _master_config.json for the active (or specified) VM profile.
    .NOTES
        Saving re-serializes JSON; // comments in the master file are removed. Prefer PS 7+ or keep edits in Git.
    ##>
    param(
        [string]$VMProfileKey,
        [string]$VhdPath,
        [string]$OsVhdPath,
        [string]$VMName,
        [string]$GuestStagingDrive,
        [Nullable[bool]]$UsePasswordCreds
    )
    $doc = Read-MasterJsonEditable
    $masterPs = Read-JsonCFile -Path $MasterConfigPath
    $pk = if ($VMProfileKey) { $VMProfileKey.Trim() } else { Get-ActiveVmProfileKey -Master $masterPs }
    $vdNode = Get-ProfileVmDetailsEditable -Doc $doc -ProfileKey $pk

    if ($PSBoundParameters.ContainsKey('VhdPath') -and $null -ne $VhdPath) {
        $norm = ($VhdPath.Trim() -replace '\\', '/')
        if ($doc.Kind -eq 'Node') { $vdNode['VhdPath'] = [System.Text.Json.Nodes.JsonValue]::Create($norm) }
        else { $vdNode['VhdPath'] = $norm }
    }
    if ($PSBoundParameters.ContainsKey('OsVhdPath') -and $null -ne $OsVhdPath) {
        $norm = ($OsVhdPath.Trim() -replace '\\', '/')
        if ($doc.Kind -eq 'Node') { $vdNode['OsVhdPath'] = [System.Text.Json.Nodes.JsonValue]::Create($norm) }
        else { $vdNode['OsVhdPath'] = $norm }
    }
    if ($PSBoundParameters.ContainsKey('VMName') -and $null -ne $VMName) {
        $n = $VMName.Trim()
        if ($doc.Kind -eq 'Node') { $vdNode['VMName'] = [System.Text.Json.Nodes.JsonValue]::Create($n) }
        else { $vdNode['VMName'] = $n }
    }
    if ($PSBoundParameters.ContainsKey('GuestStagingDrive') -and $null -ne $GuestStagingDrive) {
        $ch = $GuestStagingDrive.ToString().Trim().TrimEnd(':')[0].ToString()
        $r = $doc.Root
        if ($doc.Kind -eq 'Node') {
            if ($null -eq $r['VMFileSystem']) { $r['VMFileSystem'] = [System.Text.Json.Nodes.JsonObject]::Create() }
            $r['VMFileSystem']['GuestStagingDrive'] = [System.Text.Json.Nodes.JsonValue]::Create($ch)
            if ($null -eq $r['shared']) { $r['shared'] = [System.Text.Json.Nodes.JsonObject]::Create() }
            $r['shared']['GuestStagingDrive'] = [System.Text.Json.Nodes.JsonValue]::Create($ch)
        } else {
            if ($null -eq $r['VMFileSystem']) { $r['VMFileSystem'] = New-Object Newtonsoft.Json.Linq.JObject }
            $r['VMFileSystem']['GuestStagingDrive'] = $ch
            if ($null -eq $r['shared']) { $r['shared'] = New-Object Newtonsoft.Json.Linq.JObject }
            $r['shared']['GuestStagingDrive'] = $ch
        }
    }
    if ($PSBoundParameters.ContainsKey('UsePasswordCreds') -and $null -ne $UsePasswordCreds) {
        $b = [bool]$UsePasswordCreds
        $r = $doc.Root
        if ($doc.Kind -eq 'Node') {
            if ($null -eq $r['VMCredentials']) { $r['VMCredentials'] = [System.Text.Json.Nodes.JsonObject]::Create() }
            $r['VMCredentials']['UsePasswordCreds'] = [System.Text.Json.Nodes.JsonValue]::Create($b)
        } else {
            if ($null -eq $r['VMCredentials']) { $r['VMCredentials'] = New-Object Newtonsoft.Json.Linq.JObject }
            $r['VMCredentials']['UsePasswordCreds'] = [Newtonsoft.Json.Linq.JToken]::FromObject($b)
        }
    }

    Write-MasterJsonEditable -Doc $doc
    Write-Host "Updated _master_config.json (profile '$pk'). Note: JSONC comments in that file were removed by this save." -ForegroundColor Yellow
} #<

function Save-DefaultVmProfileToMaster { #>
    <##
    .SYNOPSIS
        Persists the default VM profile key in _master_config.json (defaultVMProfile).
    .NOTES
        Removes activeVMProfile from the root object if present so it cannot override defaultVMProfile.
        Resolution order is unchanged: $env:GOLDEN_IMAGE_VM_PROFILE still wins when set.
        Saving re-serializes JSON; // comments in the master file are removed.
    ##>
    param(
        [Parameter(Mandatory = $true)][string]$ProfileKey
    )
    $pk = $ProfileKey.Trim()
    if ($pk.Length -eq 0) { throw "ProfileKey is empty." }
    $masterPs = Read-JsonCFile -Path $MasterConfigPath
    $null = Get-VmProfileSection -Master $masterPs -ProfileKey $pk

    $doc = Read-MasterJsonEditable
    $r = $doc.Root
    if ($doc.Kind -eq 'Node') {
        $r['defaultVMProfile'] = [System.Text.Json.Nodes.JsonValue]::Create($pk)
        $rootObj = $r.AsObject()
        if ($rootObj.ContainsKey('activeVMProfile')) { [void]$rootObj.Remove('activeVMProfile') }
    } else {
        $r['defaultVMProfile'] = $pk
        [void]$r.Remove('activeVMProfile')
    }

    Write-MasterJsonEditable -Doc $doc
    Write-Host "Saved default VM profile '$pk' in _master_config.json (defaultVMProfile). `$env:GOLDEN_IMAGE_VM_PROFILE still overrides when set. JSONC comments were removed by this save." -ForegroundColor Yellow
} #<

function Sync-Configs { #>
    if (-not (Test-Path $MasterConfigPath)) { return }
    $master = Read-JsonCFile -Path $MasterConfigPath

    $offCfg = if (Test-Path $GuestConfigPath) { Get-Content $GuestConfigPath | ConvertFrom-Json } else { [PSCustomObject]@{} }
    foreach ($section in @($master.shared, $master._offline)) {
        if ($null -eq $section) { continue }
        foreach ($prop in $section.psobject.Properties) {
            $offCfg | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
        }
    }
    $offCfg | ConvertTo-Json -Depth 10 | Set-Content $GuestConfigPath
} #<

function Get-Config { #>
    Param(
        [ValidateSet("Host", "Guest")][string]$Target = "Host",
        [string]$VMProfileKey
    )
    if ($Target -eq "Host") {
        $master = Read-MasterConfig -Path $MasterConfigPath
        $pk = if ($VMProfileKey) { $VMProfileKey } else { Get-ActiveVmProfileKey -Master $master }
        return (Build-MergedHostVmConfig -Master $master -ProfileKey $pk)
    }
    if (Test-Path $GuestConfigPath) { return Get-Content $GuestConfigPath | ConvertFrom-Json }
    return @{}
} #<

function Get-VMCreds { #>
    Param([string]$User, [object]$Config)
    if (-not $User) { $User = "Administrator" }
    $usePass = $Config.UsePasswordCreds -eq $true -or $Config.UsePasswordCreds -eq "true"
    $pass = if ($usePass -and $Config.VMPassword) {
        ConvertTo-SecureString $Config.VMPassword.ToString() -AsPlainText -Force
    } else { New-Object System.Security.SecureString }
    return New-Object System.Management.Automation.PSCredential($User, $pass)
} #<

function Get-GuestDriveLetter { #>
    param($val)
    if (-not $val) { return 'F' }
    $s = if ($val -is [string]) { $val } elseif ($val.value) { $val.value } else { $val.ToString() }
    if ($s) { return $s.ToString().Trim().TrimEnd(':')[0] } else { return 'F' }
} #<
