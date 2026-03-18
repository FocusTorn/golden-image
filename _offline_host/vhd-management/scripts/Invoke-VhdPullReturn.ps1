<#
.SYNOPSIS
    Pulls the 'return' folder from the VHD back to the host project directory.
#>
param(
    [Parameter(Mandatory=$true)] [string]$TargetHostDir,
    [switch]$NoPause
)

. (Join-Path $PSScriptRoot "VhdUtils.ps1")
$Cfg = Get-Config

try {
    Write-Host ">>> PULL RETURN" -ForegroundColor Cyan
    if (-not (Test-Path $TargetHostDir)) { New-Item -Path $TargetHostDir -ItemType Directory -Force | Out-Null }

    Write-Host "[1/2] Connecting VHD to host..." -ForegroundColor Gray
    $vhd = Invoke-VhdTransition -Target "Host" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName
    $part = Get-Partition -DiskNumber $vhd.DiskNumber | Where-Object DriveLetter | Select-Object -First 1
    if (-not $part) { throw "No partition with drive letter found on VHD." }
    $driveLetter = $part.DriveLetter
    $sourcePath = Join-Path "${driveLetter}:" "return"
    if (-not (Test-Path $sourcePath)) {
        Write-Host "[!] Source missing on VHD: $sourcePath" -ForegroundColor Yellow
    } else {
        Write-Host "[*] Pulling: $sourcePath -> $TargetHostDir" -ForegroundColor Yellow
        robocopy $sourcePath $TargetHostDir /MIR /MT:16 /R:2 /W:5 /NP /NDL
    }

    Write-Host "[2/2] Reconnecting VHD to VM..." -ForegroundColor Gray
    Invoke-VhdTransition -Target "VM" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName
    Write-Host "[SUCCESS] Pull complete." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Pull Failed: $($_.Exception.Message)" -ForegroundColor Red
    Invoke-VhdTransition -Target "VM" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName
}

if (-not $NoPause) { Read-Host "`nPress Enter to continue..." }
