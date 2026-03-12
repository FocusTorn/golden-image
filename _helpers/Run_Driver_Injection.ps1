# Universal Driver Injector (Offline Servicing)
# This script mounts your WIM, adds all drivers in the 'Drivers' folder, and saves it.

$WimFile = "P:\Projects\golden-image\Thin_Agnostic_Master.wim"
$MountDir = "P:\Projects\golden-image\Mount"
$DriverDir = "P:\Projects\golden-image\Drivers_To_Inject"

# 1. Create Folders if they don't exist
if (!(Test-Path $MountDir)) { New-Item -ItemType Directory -Path $MountDir }
if (!(Test-Path $DriverDir)) { New-Item -ItemType Directory -Path $DriverDir }

Write-Host "--- MOUNTING IMAGE ---" -ForegroundColor Cyan
dism /Mount-Image /ImageFile:$WimFile /Index:1 /MountDir:$MountDir

Write-Host "--- INJECTING DRIVERS ---" -ForegroundColor Yellow
Write-Host "Searching in: $DriverDir"
dism /Image:$MountDir /Add-Driver /Driver:$DriverDir /Recurse

Write-Host "--- SAVING AND UNMOUNTING ---" -ForegroundColor Green
dism /Unmount-Image /MountDir:$MountDir /Commit

Write-Host "--- INJECTION COMPLETE! ---" -ForegroundColor Green
