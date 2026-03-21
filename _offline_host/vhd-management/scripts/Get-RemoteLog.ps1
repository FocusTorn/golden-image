# Get-RemoteLog.ps1
# Pulls the latest installation log from the VM for a specific category.
# Usage: .\Get-RemoteLog.ps1 scoop
#        .\Get-RemoteLog.ps1 -Category all -VMName "Windows 11 Master"

Param(
    [Parameter(Position = 0)]
    [ValidateSet("scoop", "apps", "rust", "msvc", "bootstrapper", "all")]
    [string]$Category = "rust",

    [string]$VMName,
    [PSCredential]$Credential,
    [string]$ReturnPath
)

$LocalProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $LocalProjectRoot "_helpers\ConfigUtils.ps1")
$hc = Get-Config -Target Host
if ([string]::IsNullOrWhiteSpace($VMName)) { $VMName = $hc.VMName }
if ([string]::IsNullOrWhiteSpace($ReturnPath)) {
    $gd = Get-GuestDriveLetter $hc.GuestStagingDrive
    $rp = if ($hc.ReturnPath) { $hc.ReturnPath.Trim().TrimStart('/').TrimStart('\') } else { 'return' }
    $ReturnPath = Join-Path "$gd`:" $rp
}

# Map category to log file naming patterns (msvc = vs_setup* & dd_bootstrapper*)
$Script:PatternMap = @{
    "scoop"        = @("Install_Stage_1_Scoop_*.log")
    "msvc"         = @("vs_setup*.log", "dd_bootstrapper_*.log")
    "bootstrapper" = @("dd_bootstrapper_*.log")
    "apps"         = @("Install_Stage_3_Apps_*.log")
    "rust"         = @("Install_Stage_4_Rust_*.log")
}

if (-not $Credential) {
    $Credential = Get-VMCreds -User $hc.VMUser -Config $hc
}

$categoriesToRun = if ($Category -eq "all") { @("scoop", "msvc", "apps", "rust") } else { @($Category) }

Write-Host "--- ROG STRIX: HARVESTING LOG(S) FROM VM [$VMName] ---" -ForegroundColor Cyan

$ScriptBlock = {
    param($Filters, $LogReturnPath)
    foreach ($f in $Filters) {
        $Filter = $f.Filter
        $Label = $f.Label
        $latest = Get-ChildItem -Path $LogReturnPath -Filter $Filter -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1

        if ($latest) {
            Write-Host "`n>>> [$Label] $($latest.FullName)" -ForegroundColor Yellow
            Write-Host ("-" * 64) -ForegroundColor Gray
            Get-Content -Path $latest.FullName
            Write-Host ("-" * 64) -ForegroundColor Gray
        } else {
            Write-Host "[!] No logs matching '$Filter' found in $LogReturnPath" -ForegroundColor Red
        }
    }
}

$argList = @()
foreach ($cat in $categoriesToRun) {
    $patterns = $Script:PatternMap[$cat]
    if ($patterns -is [array]) {
        foreach ($p in $patterns) { $argList += @{ Filter = $p; Label = $cat } }
    } else {
        $argList += @{ Filter = $patterns; Label = $cat }
    }
}
Invoke-Command -VMName $VMName -Credential $Credential -ScriptBlock $ScriptBlock -ArgumentList (,$argList), $ReturnPath
