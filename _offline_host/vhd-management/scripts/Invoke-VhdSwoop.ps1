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

try {
    Write-Host ">>> SYNC OPERATION: $($Sources.Count) folders" -ForegroundColor Cyan
    Write-Host "[1/2] Connecting VHD to host..." -ForegroundColor Gray
    
    $vhd = Invoke-VhdTransition -Target "Host" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName
    $part = Get-Partition -DiskNumber $vhd.DiskNumber | Where-Object DriveLetter | Select-Object -First 1
    if (-not $part) { throw "No partition with drive letter found on VHD." }
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
        robocopy $Source $destination /MIR /MT:16 /R:2 /W:5 /NP /NDL /FFT /B /XF RDP-Tcp.reg
    }

    Write-Host "[2/2] Reconnecting VHD to VM..." -ForegroundColor Gray
    Invoke-VhdTransition -Target "VM" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName
    Write-Host "[SUCCESS] Sync complete and returned to VM." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Sync Failed: $($_.Exception.Message)" -ForegroundColor Red
    Invoke-VhdTransition -Target "VM" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName
}

if (-not $NoPause) { Read-Host "`nPress Enter to continue..." }
