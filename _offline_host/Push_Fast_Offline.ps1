# Push_Fast_Offline.ps1
# Run this on Host (Admin PowerShell) to push the _offline folder INSTANTLY to resolved guest drive
# Uses Guest Services (no VM shutdown required).




$ConfigPath = Join-Path $PSScriptRoot "_offline_host_config.json"

$cfg = if (Test-Path $ConfigPath) { Get-Content $ConfigPath | ConvertFrom-Json } else { @{} }

$vmName = if ($cfg.VMName) { $cfg.VMName } else { "Windows 11 Master" }
$projectRoot = "P:\Projects\golden-image"
$guestDrive = if ($cfg.GuestStagingDrive) { $cfg.GuestStagingDrive.Trim().TrimEnd(':')[0] } else { 'F' }
$offlineFolder = if ($cfg.OfflinePath) { $cfg.OfflinePath } else { "_offline" }

Write-Host "--- FAST PUSH: _OFFLINE FOLDER to [$vmName] ---" -ForegroundColor Cyan
Write-Host "[*] Target Guest Drive: $($guestDrive):\$offlineFolder" -ForegroundColor Gray

$offlinePath = Join-Path $projectRoot $offlineFolder
if (-not (Test-Path $offlinePath)) {
    Write-Error "Source folder not found: $offlinePath"
    exit 1
}

Get-ChildItem -Path $offlinePath -File | ForEach-Object {
    $dest = "$($guestDrive):\$offlineFolder\$($_.Name)"
    # Note: Copy-VMFile requires Guest Services enabled in VM Settings
    try {
        Copy-VMFile -Name $vmName -SourcePath $_.FullName -DestinationPath $dest -FileSource Host -Force -ErrorAction Stop
        Write-Host "    [OK] $($_.Name)" -ForegroundColor DarkGray
    } catch {
        Write-Warning "    [FAIL] $($_.Name): $($_.Exception.Message)"
    }
}

Write-Host "[SUCCESS] _offline folder synced to $($guestDrive):\$offlineFolder" -ForegroundColor Green
