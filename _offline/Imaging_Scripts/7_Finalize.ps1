# 🏁 Golden Image: ULTRA-THIN Zero-Hour Safety Script
# Run this script as ADMINISTRATOR inside the VM immediately before Sysprep.

Write-Host "--- STAGE 1: COMPONENT & STORAGE CLEANUP ---" -ForegroundColor Cyan

# 1. Component Store Cleanup (Takes 5-10 mins)
Write-Host "[*] Optimizing Windows Component Store (ResetBase)..."
dism.exe /online /cleanup-image /startcomponentcleanup /resetbase

# 2. Delete System Shadow Copies
Write-Host "[*] Deleting System Shadow Copies..."
vssadmin.exe delete shadows /all /quiet

# 3. Disable Hibernation and Fast Startup
Write-Host "[*] Disabling Hibernation..."
powercfg.exe /h off

# 4. Disable Windows Reserved Storage
Write-Host "[*] Disabling Reserved Storage..."
Set-WindowsReservedStorageState -State Disabled -ErrorAction SilentlyContinue

Write-Host "`n--- STAGE 2: DEVELOPER RUNTIME CLEANUP ---" -ForegroundColor Cyan

# 5. Clear Cargo (Rust) Cache
if (Get-Command cargo -ErrorAction SilentlyContinue) {
    Write-Host "[*] Clearing Cargo registry and git caches..."
    Remove-Item -Path "$env:USERPROFILE\.cargo\registry\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:USERPROFILE\.cargo\git\*" -Recurse -Force -ErrorAction SilentlyContinue
}

# 6. Clear Go Cache
if (Get-Command go -ErrorAction SilentlyContinue) {
    Write-Host "[*] Clearing Go build cache..."
    go clean -modcache -cache
}

# 7. Clear Scoop Cache
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "[*] Clearing Scoop download cache..."
    scoop cache rm *
}

Write-Host "`n--- STAGE 3: CACHE & LOG PURGE ---" -ForegroundColor Cyan

# 8. Clear all Windows Event Logs
Write-Host "[*] Clearing Event Logs..."
Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | ForEach-Object { [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($_.LogName) }

# 9. Clear Prefetch and Recent Items
Write-Host "[*] Clearing Prefetch and Recent File caches..."
Remove-Item -Path "C:\Windows\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\*" -Recurse -Force -ErrorAction SilentlyContinue

# 10. Empty Recycle Bin
Write-Host "[*] Emptying Recycle Bin..."
$Bin = (New-Object -ComObject Shell.Application).NameSpace(0x0a)
$Bin.Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "`n--- STAGE 4: TEMP FILE PURGE ---" -ForegroundColor Cyan

# 11. Final Deep Disk Cleanup
Write-Host "[*] Running Disk Cleanup (Silent)..."
cleanmgr.exe /verylowdisk

# 12. Clear User Temp Folders
Write-Host "[*] Clearing Temp folders..."
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n--- STAGE 5: FINAL VERIFICATION ---" -ForegroundColor Cyan

# 13. Verify Unattend.xml exists (copy from Z:\code\unattend.xml if missing, then recheck)
$UnattendPath = "C:\Windows\System32\Sysprep\unattend.xml"
$UnattendSource = "Z:\_offline\unattend.xml"
if (-not (Test-Path $UnattendPath) -and (Test-Path $UnattendSource)) {
    Copy-Item -LiteralPath $UnattendSource -Destination $UnattendPath -Force
    Write-Host "[*] Copied unattend.xml from Z:\code\unattend.xml to Sysprep folder." -ForegroundColor Gray
}
if (Test-Path $UnattendPath) {
    Write-Host "[SUCCESS] unattend.xml found in Sysprep folder." -ForegroundColor Green
} else {
    Write-Host "[CRITICAL] unattend.xml MISSING! Copy it to C:\Windows\System32\Sysprep\ or place at Z:\code\unattend.xml and re-run." -ForegroundColor Red
}






Write-Host "[!] Reverting Execution Policy for Production..." -ForegroundColor Yellow
Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope LocalMachine -Force






Write-Host "`n====================================================" -ForegroundColor Yellow
Write-Host " READY FOR IMAGE CAPTURE" -ForegroundColor Green
Write-Host "===================================================="
Write-Host "1. UNINSTALL VirtualBox Guest Additions (Now!)"
Write-Host "2. DISCONNECT the VM Internet connection."
Write-Host "3. OPEN Command Prompt (Admin) and type:"
Write-Host "   cd C:\Windows\System32\Sysprep"
Write-Host "   sysprep.exe /oobe /generalize /shutdown /unattend:unattend.xml"
Write-Host "===================================================="
