<#
.SYNOPSIS
    Workspace-wide configuration management utilities.
    Handles syncing of _master_config.json into environment-specific files.
#>

# Resolve project root relative to this script's location (_helpers folder)
$LocalProjectRoot = Split-Path $PSScriptRoot -Parent
$MasterConfigPath = Join-Path $LocalProjectRoot "_master_config.json"

# Target config paths
$HostConfigPath = Join-Path $LocalProjectRoot "_offline_host\_offline_host_config.json"
$GuestConfigPath = Join-Path $LocalProjectRoot "_offline\_offline_config.json"

function Sync-Configs {
    if (-not (Test-Path $MasterConfigPath)) { return }
    $master = Get-Content $MasterConfigPath | ConvertFrom-Json

    # Only initialize host config if it's missing or empty
    if (-not (Test-Path $HostConfigPath)) {
        $hostCfg = [PSCustomObject]@{}
        foreach ($section in @($master.shared, $master.offline_host)) {
            if ($null -eq $section) { continue }
            foreach ($prop in $section.psobject.Properties) {
                $hostCfg | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value
            }
        }
        $hostCfg | ConvertTo-Json | Set-Content $HostConfigPath
    }

    # Always ensure guest config is updated (it's the target for syncing to VM)
    $offCfg = if (Test-Path $GuestConfigPath) { Get-Content $GuestConfigPath | ConvertFrom-Json } else { [PSCustomObject]@{} }
    foreach ($section in @($master.shared, $master._offline)) {
        if ($null -eq $section) { continue }
        foreach ($prop in $section.psobject.Properties) {
            $offCfg | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
        }
    }
    $offCfg | ConvertTo-Json | Set-Content $GuestConfigPath
}

function Get-Config {
    Param([ValidateSet("Host", "Guest")][string]$Target = "Host")
    Sync-Configs
    $path = if ($Target -eq "Host") { $HostConfigPath } else { $GuestConfigPath }
    if (Test-Path $path) { return Get-Content $path | ConvertFrom-Json }
    return @{}
}

function Get-VMCreds {
    Param([string]$User, [object]$Config)
    if (-not $User) { $User = "Administrator" }
    $usePass = $Config.UsePasswordCreds -eq $true -or $Config.UsePasswordCreds -eq "true"
    $pass = if ($usePass -and $Config.VMPassword) {
        ConvertTo-SecureString $Config.VMPassword.ToString() -AsPlainText -Force
    } else { New-Object System.Security.SecureString }
    return New-Object System.Management.Automation.PSCredential($User, $pass)
}

function Get-GuestDriveLetter {
    param($val)
    if (-not $val) { return 'F' }
    $s = if ($val -is [string]) { $val } elseif ($val.value) { $val.value } else { $val.ToString() }
    if ($s) { return $s.ToString().Trim().TrimEnd(':')[0] } else { return 'F' }
}
