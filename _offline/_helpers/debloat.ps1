# 🏆 Universal Agnostic Windows Debloater (Golden Master Edition)
# Targets both standard bloat and items discovered in the 2026 Audit.
# Run as ADMINISTRATOR inside the VM.

$Targets = @(
    # --- New Discoveries from 2026 Audit ---
    "*BingNews*", "*OutlookForWindows*", "*Todos*", "*YourPhone*", "*CrossDevice*",
    "*DevHome*", "*WindowsAlarms*", "*SoundRecorder*", "*StickyNotes*", "*WindowsCamera*",
    
    # --- General Bloatware ---
    "*Clipchamp*", "*BingSearch*", "*BingWeather*", "*GamingApp*", "*GetHelp*",
    "*SolitaireCollection*", "*PowerAutomateDesktop*", "*FeedbackHub*", "*ZuneMusic*",
    "*ZuneVideo*", "*Teams*", "*Xbox*", "*QuickAssist*", "*WebExperience*",
    "*ContentDeliveryManager*", "*ParentalControls*", "*SecureAssessmentBrowser*",
    "*NarratorQuickStart*", "*AugLoop.CBS*", "*WidgetsPlatformRuntime*",

    # --- Hardware Specific (Ensures Image is Agnostic) ---
    "*ASUS*", "*NVIDIAControl*", "*RealtekAudio*"
)

Write-Host "--- PHASE 1: PURGING TEMPLATES & APPS ---" -ForegroundColor Cyan

foreach ($App in $Targets) {
    Write-Host "Processing: $App" -ForegroundColor Yellow
    
    # 1. Kill background processes to unlock files
    Get-Process | Where-Object {$_.Path -like "*$App*"} | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # 2. Wipe from Provisioned (New User Template) - CRITICAL for Golden Image
    $Prov = Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -like $App}
    if ($Prov) { 
        Write-Host "  -> Removing from Master Template..." -ForegroundColor Gray
        Remove-AppxProvisionedPackage -Online -PackageName $Prov.PackageName -ErrorAction SilentlyContinue 
    }
    
    # 3. Remove from All Current Users
    Write-Host "  -> Removing from current profiles..." -ForegroundColor Gray
    Get-AppxPackage -Name $App -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
}

# --- PHASE 2: REGISTRY TWEAKS ---
Write-Host "`n--- PHASE 2: HIDING SYSTEM ADS ---" -ForegroundColor Cyan
# Disable "Suggested Apps" (Start Menu Ads)
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SystemPaneSuggestionsEnabled" /t REG_DWORD /d 0 /f 2>$null

Write-Host "`n--- PHASE 3: VALIDATION ---" -ForegroundColor Cyan
$StillPresent = Get-AppxProvisionedPackage -Online | Where-Object { 
    $name = $_.DisplayName
    $Targets | Where-Object { $name -like $_ }
}

if ($StillPresent) {
    Write-Host "WARNING: The following items remain in the template:" -ForegroundColor Red
    $StillPresent | Select-Object DisplayName
} else {
    Write-Host "VERIFICATION PASSED: All targets purged from Master Template." -ForegroundColor Green
}

Write-Host "`nReady for Zero-Hour Cleanup." -ForegroundColor White
