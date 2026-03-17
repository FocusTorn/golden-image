<#
.SYNOPSIS
    Resolves the guest drive letter for the staging volume by its label.
    Uses Invoke-Command to query the VM; falls back to config letter if WinRM fails.
.PARAMETER VMName
    VM friendly name.
.PARAMETER VolumeLabel
    Volume label to find (e.g. "Golden Imaging").
.PARAMETER FallbackLetter
    Drive letter to return if label lookup fails.
.OUTPUTS
    Drive letter (e.g. "F") or $null.
#>
param(
    [string]$VMName,
    [string]$VolumeLabel,
    [string]$FallbackLetter = "F",
    [PSCredential]$Credential
)

# $ConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config.json" #
$ConfigPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "_offline_host_config.json"

if (Test-Path $ConfigPath) {
    $cfg = Get-Content $ConfigPath | ConvertFrom-Json
    if (-not $VMName) { $VMName = $cfg.VMName }
    if (-not $VolumeLabel -and $cfg.StagingVolumeLabel) { $VolumeLabel = $cfg.StagingVolumeLabel }
    if (-not $VolumeLabel) { $VolumeLabel = "Golden Imaging" }
    if (-not $FallbackLetter -and $cfg.GuestStagingDrive) {
        $raw = $cfg.GuestStagingDrive
        $s = if ($raw -is [string]) { $raw } elseif ($raw.value) { $raw.value } else { $raw.ToString() }
        if ($s) { $FallbackLetter = $s.ToString().Trim().TrimEnd(':')[0] }
    }
}
if (-not $FallbackLetter) { $FallbackLetter = "F" }

if (-not $Credential) {
    $user = ".\Administrator"
    if (Test-Path $ConfigPath) {
        $c = Get-Content $ConfigPath | ConvertFrom-Json
        if ($c.VMUser) { $user = ".\$($c.VMUser)" }
    }
    $Credential = New-Object System.Management.Automation.PSCredential($user, (New-Object System.Security.SecureString))
}

try {
    $letter = Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock {
        param($label)
        $v = Get-Volume -FileSystemLabel $label -ErrorAction SilentlyContinue
        if ($v -and $v.DriveLetter) { return $v.DriveLetter }
        return $null
    } -ArgumentList $VolumeLabel -ErrorAction Stop
    if ($letter) { Write-Output $letter; exit }
} catch { }
Write-Output $FallbackLetter


