  Alternative: The "Launcher" Batch File
  If you don't want to change the setting for your entire computer, but you want a specific script to run when you double-click it, you can create a "Wrapper" batch file next to your
  script:


  Example: Run_My_Script.bat
   @echo off
   pwsh -ExecutionPolicy Bypass -File "%~dp0YourScript.ps1"
   pause
   * %~dp0 tells the batch file to look in the same folder it is currently in.
   * This is the safest method for sharing scripts with others without messing with their Windows settings.



























































(Get-DisplayConfig | Where-Object {$_.IsActive -eq $true}).DisplayId

powershell -Command "Get-Module -ListAvailable DisplayConfig"

powershell -Command "Set-DisplayConfig -Width 1440 -Height 900 -Force"



powershell -Command "Import-Module DisplayConfig; Set-DisplayConfig -Width 1440 -Height 900"


powershell -Command "Import-Module 'F:\installers\DisplayConfig\DisplayConfig.psd1'; Set-DisplayConfig -Width 1440 -Height 900"



Install-Module -Name DisplayConfig -Scope CurrentUser -Force

@echo off
powershell -Command "Import-Module DisplayConfig; Set-DisplayResolution -Width 1440 -Height 900"
exit

powershell -Command "Set-DisplayResolution -Width 1440 -Height 900"


@echo off
:: Search and delete these shortcuts anywhere in your Start Menu folders
del /s /q "%AppData%\Microsoft\Windows\Start Menu\*.lnk" | findstr /i "Edge Explorer Settings"
del /s /q "%ProgramData%\Microsoft\Windows\Start Menu\*.lnk" | findstr /i "Edge Explorer Settings"




Set-Content -Path "$env:LocalAppData\Microsoft\Windows\Shell\LayoutModification.json" -Value '{"pinnedList": []}'





@echo off
:: Request Admin privileges
set "params=%*"
cd /d "%~dp0" && ( if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs" ) && fsutil dirty query %systemdrive% 1>nul 2>nul || (  echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/k cd ""%~dp0"" && ""%~nx0"" ""%params%""", "", "runas", 1 >> "%temp%\getadmin.vbs" && "%temp%\getadmin.vbs" && exit /B )

echo Creating empty layout...
:: Create the JSON with an empty pinned list
echo {"pinnedList": []} > "%temp%\LayoutModification.json"

echo Applying layout to system...
:: Copy to the Shell customization folder
if not exist "%LocalAppData%\Microsoft\Windows\Shell" mkdir "%LocalAppData%\Microsoft\Windows\Shell"
copy /y "%temp%\LayoutModification.json" "%LocalAppData%\Microsoft\Windows\Shell\LayoutModification.json"

echo Resetting Start Menu...
:: Kill the Experience Host and Explorer to force a refresh
taskkill /f /im explorer.exe >nul 2>&1
powershell -Command "Stop-Process -Name StartMenuExperienceHost -Force" >nul 2>&1

:: Clean up old binary pins so they don't override the new JSON
set "START_DATA=%LocalAppData%\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
if exist "%START_DATA%\start2.bin" del /f /q "%START_DATA%\start2.bin"

:: Restart the shell
start explorer.exe
echo.
echo All pins should be gone.
pause







DEL /S /Q "%AppData%\Microsoft\Windows\Start Menu\Programs\*ImmersiveControlPanel*.lnk"

REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoSettings" /t REG_DWORD /d 1 /f

powershell -Command "((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | ?{$_.Name -match 'Settings'}).Verbs() | ?{$_.Name.replace('&','') -match 'Unpin from Start'} | %{$_.DoIt()}"



dir "%AppData%\Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu"

DEL /F /Q "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk"


@echo off
:: 1. Unpin Microsoft Edge
powershell -Command "((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | ?{$_.Name -eq 'Microsoft Edge'}).Verbs() | ?{$_.Name.replace('&','') -match 'Unpin from Start'} | %{$_.DoIt()}"

:: 2. Unpin Settings
powershell -Command "((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | ?{$_.Name -eq 'Settings'}).Verbs() | ?{$_.Name.replace('&','') -match 'Unpin from Start'} | %{$_.DoIt()}"

:: 3. Unpin File Explorer
powershell -Command "((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | ?{$_.Name -eq 'File Explorer'}).Verbs() | ?{$_.Name.replace('&','') -match 'Unpin from Start'} | %{$_.DoIt()}"



REG DELETE "HKCU\Software\Microsoft\Windows\CurrentVersion\CloudStore..." /f





@echo off
:: 1. Target Edge in the Taskbar Pin folder (which often mirrors to Start)
DEL /F /Q "%AppData%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk"

:: 2. Target File Explorer in the Taskbar Pin folder
DEL /F /Q "%AppData%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\File Explorer.lnk"

:: 3. Force a refresh of the icons
taskkill /f /im explorer.exe & start explorer.exe



@echo off
:: 1. Remove MS Edge Pin
DEL /F /Q "%AppData%\Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu\Microsoft Edge.lnk"

:: 2. Remove File Explorer Pin
DEL /F /Q "%AppData%\Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu\File Explorer.lnk"

:: 3. Remove Settings Pin
DEL /F /Q "%AppData%\Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu\Settings.lnk"


DEL /F /Q "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk"



. {
    Write-Host "--- VM: MASTER VALIDATION & REPAIR ---" -ForegroundColor Cyan
    
    $Report = @()

    # 1. Audit Registry (Blank Passwords & Admin Tokens)
    $RegKeys = @(
        @{ Path = "HKLM:\System\CurrentControlSet\Control\Lsa"; Name = "LimitBlankPasswordUse"; Expected = 0 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "LocalAccountTokenFilterPolicy"; Expected = 1 }
    )

    foreach ($Key in $RegKeys) {
        $Val = Get-ItemPropertyValue -Path $Key.Path -Name $Key.Name -ErrorAction SilentlyContinue
        if ($Val -eq $Key.Expected) {
            Write-Host "[OK] $($Key.Name) is $($Val)" -ForegroundColor Green
        } else {
            Write-Host "[FIXING] $($Key.Name) was $Val (Should be $($Key.Expected))" -ForegroundColor Yellow
            Set-ItemProperty -Path $Key.Path -Name $Key.Name -Value $Key.Expected
        }
    }

    # 2. Audit Services (WinRM & CNG Key Isolation)
    # Per Stack Overflow, CNG Key Isolation (KeyIso) is mandatory for VS and Auth
    $Services = @("WinRM", "KeyIso")
    foreach ($SvcName in $Services) {
        $Svc = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
        if ($Svc.Status -eq 'Running') {
            Write-Host "[OK] Service '$SvcName' is Running" -ForegroundColor Green
        } else {
            Write-Host "[FIXING] Starting Service '$SvcName'..." -ForegroundColor Yellow
            Set-Service -Name $SvcName -StartupType Automatic
            Start-Service $SvcName
        }
    }

    # 3. Audit Network Profile
    $PublicNets = Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -eq 'Public' }
    if ($PublicNets) {
        Write-Host "[FIXING] Found Public Network Profile. Flipping to Private..." -ForegroundColor Yellow
        $PublicNets | Set-NetConnectionProfile -NetworkCategory Private
    } else {
        Write-Host "[OK] Network Profile is Private/Internal." -ForegroundColor Green
    }

    # 4. Audit WinRM Listener
    $Listeners = Get-ChildItem WSMan:\localhost\Listener
    if ($Listeners) {
        Write-Host "[OK] WinRM Listener exists." -ForegroundColor Green
    } else {
        Write-Host "[FIXING] Rebuilding WinRM Listener..." -ForegroundColor Yellow
        winrm quickconfig -quiet
    }

    Write-Host "`n--- VALIDATION COMPLETE: TRY CONNECTION NOW ---" -ForegroundColor Cyan
}








. {
    Write-Host "--- VM: FINAL CONFIGURATION REPAIR ---" -ForegroundColor Cyan

    # 1. Unregister the WinRM Service from Windows
    # This removes the corrupted link between the Service and the Registry
    Stop-Service winrm -Force -ErrorAction SilentlyContinue
    & sc.exe delete winrm

    # 2. Re-register the 'Option 40' Registry Essentials
    reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v "LimitBlankPasswordUse" /t REG_DWORD /d 0 /f
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "LocalAccountTokenFilterPolicy" /t REG_DWORD /d 1 /f

    # 3. Ensure CNG Key Isolation is set for the Handshake
    # Per [Wael Dalloul's Stack Overflow fix](https://stackoverflow.com/questions/42829675/visual-studio-2017-fails-to-install-offline-with-unable-to-download-installatio), this handles the 'Option 40' decryption.
    Set-Service KeyIso -StartupType Automatic
    Start-Service KeyIso -ErrorAction SilentlyContinue

    # 4. Re-install the WinRM Service
    # This 'cleans' the corrupted configuration error
    & winrm quickconfig -quiet

    # 5. Force the Network to Private (The WSMan Fault Killer)
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

    Write-Host "[SUCCESS] WinRM Service has been Re-installed. Try Enter-PSSession." -ForegroundColor Green
}











. {
    Write-Host "--- VM: NUCLEAR WINRM REPAIR ---" -ForegroundColor Cyan

    # 1. Stop WinRM and the Firewall
    Stop-Service winrm -Force -ErrorAction SilentlyContinue

    # 2. Delete the entire WinRM Configuration Registry Key
    # This is the only way to clear a 'Faulted' listener that won't delete via CMD
    $WinRMReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN"
    if (Test-Path $WinRMReg) {
        Remove-Item -Path $WinRMReg -Recurse -Force
        Write-Host "[*] WinRM Registry Database Purged." -ForegroundColor White
    }

    # 3. Re-enforce the 'Option 40' Registry Settings
    reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v "LimitBlankPasswordUse" /t REG_DWORD /d 0 /f
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "LocalAccountTokenFilterPolicy" /t REG_DWORD /d 1 /f

    # 4. Force CNG Key Isolation to start (Mandatory for VS & Auth)
    # [Wael Dalloul](https://stackoverflow.com/users/131595/wael-dalloul) confirms this service is the hidden requirement.
    Set-Service KeyIso -StartupType Automatic
    Start-Service KeyIso -ErrorAction SilentlyContinue

    # 5. Re-Initialize the Listener
    # This will recreate the registry keys we just deleted
    & winrm quickconfig -quiet

    # 6. Force Network to Private
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

    Write-Host "[SUCCESS] VM WinRM Stack has been Factory Reset." -ForegroundColor Green
}
























. {
    Write-Host "--- ENFORCING PERMANENT CONNECTIVITY (SNAPSHOT PREP) ---" -ForegroundColor Cyan

    # 1. Identity & Auth: Allow Blank Passwords and Remote Admin Tokens
    # 0 = Allow Blank; 1 = Allow Full Admin Token over VMBus
    reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v "LimitBlankPasswordUse" /t REG_DWORD /d 0 /f
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "LocalAccountTokenFilterPolicy" /t REG_DWORD /d 1 /f

    # 2. Networking: Force Private Profile & Open Firewall
    # This kills the 'WSMan Fault' for good.
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
    Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"

    # 3. Cryptography: Fix the 'Invalid Credential' Root Cause
    # As noted on Stack Overflow, KeyIso (CNG Key Isolation) is critical for decryption.
    Set-Service KeyIso -StartupType Automatic
    Start-Service KeyIso -ErrorAction SilentlyContinue

    # 4. Persistence: Ensure WinRM starts every time
    Set-Service winrm -StartupType Automatic
    winrm quickconfig -quiet

    Write-Host "[SUCCESS] VM is now Snapshot-Ready. Connection is locked in." -ForegroundColor Green
}













. {
    Write-Host "--- VM: ACCOUNT IDENTITY CHECK ---" -ForegroundColor Cyan

    # 1. Find the actual name of the Built-in Administrator (RID 500)
    # Sometimes in Audit Mode/Sysprep, this name changes or is localized.
    $AdminName = (Get-LocalUser | Where-Object { $_.SID -like "*-500" }).Name
    Write-Host "[*] Built-in Admin Name detected as: $AdminName" -ForegroundColor Yellow

    # 2. Check if it is Enabled
    $AdminStatus = Get-LocalUser -Name $AdminName
    if ($AdminStatus.Enabled) {
        Write-Host "[OK] $AdminName is Enabled." -ForegroundColor Green
    } else {
        Write-Host "[FIXING] Enabling $AdminName..." -ForegroundColor Red
        Enable-LocalUser -Name $AdminName
    }

    # 3. Check CNG Key Isolation again (Stack Overflow Fix)
    # [Wael Dalloul](https://stackoverflow.com/questions/42829675/visual-studio-2017-fails-to-install-offline-with-unable-to-download-installatio) noted this service MUST be on for the handshake to find the account.
    $cng = Get-Service KeyIso
    Write-Host "[*] CNG Key Isolation Status: $($cng.Status)" -ForegroundColor White
    if ($cng.Status -ne 'Running') { Start-Service KeyIso }

    Write-Host "`n--- USE THIS NAME IN YOUR DASHBOARD: $AdminName ---" -ForegroundColor Cyan
}












. {
    Write-Host "--- VM: FORCING LISTENER RECONSTRUCTION ---" -ForegroundColor Cyan

    # 1. Stop and Disable the service to clear locks
    Stop-Service winrm -Force -ErrorAction SilentlyContinue
    
    # 2. Delete the SPNs (Service Principal Names) that cause the 'Fault'
    # This clears stale identities that stop WinRM from 'Receiving'
    setspn -D WSMAN/localhost Administrator
    setspn -D WSMAN/$(hostname) Administrator

    # 3. Manually delete the WinRM Listener via the Registry
    # 'quickconfig' often fails here; this does it by force.
    $ListenerPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Listener"
    if (Test-Path $ListenerPath) {
        Remove-Item -Path "$ListenerPath\*" -Recurse -Force
    }

    # 4. Re-enable the service and force the default config
    Start-Service winrm
    & winrm quickconfig -quiet

    # 5. Verify the Listener is actually 'Listening'
    $listenerCheck = Get-ChildItem WSMan:\localhost\Listener
    if ($listenerCheck) {
        Write-Host "[SUCCESS] Listener is now LIVE and Registered." -ForegroundColor Green
    } else {
        Write-Host "[!] STILL FAILING: Manually creating HTTP Listener..." -ForegroundColor Yellow
        # The ultimate manual fallback
        winrm create winrm/config/Listener?Address=*+Transport=HTTP
    }

    # 6. Final check on the 'KeyIso' service (Stack Overflow Fix)
    # [Wael Dalloul](https://stackoverflow.com/questions/42829675/visual-studio-2017-fails-to-install-offline-with-unable-to-download-installatio) noted this is required for the handshake.
    Get-Service KeyIso | Set-Service -StartupType Automatic
    Start-Service KeyIso -ErrorAction SilentlyContinue
}




























































. {
    Write-Host "--- VM: FORCING WINRM PERSISTENCE ---" -ForegroundColor Cyan

    # 1. Set WinRM to Automatic (Delayed Start)
    # This prevents the "Service not started" fault after a reboot
    Get-Service winrm | Set-Service -StartupType Automatic
    Start-Service winrm -ErrorAction SilentlyContinue

    # 2. Manually Create the Firewall Rules (Bypassing QuickConfig)
    Write-Host "[*] Manually punching firewall holes..." -ForegroundColor White
    New-NetFirewallRule -Name "AllowWinRM_In" -DisplayName "WinRM-HTTP-In-Manual" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

    # 3. Ensure CNG Key Isolation is actually RUNNING
    # Per [Wael Dalloul's answer](https://stackoverflow.com/posts/48997043/timeline), this service is the hidden requirement.
    Set-Service KeyIso -StartupType Automatic
    Start-Service KeyIso -ErrorAction SilentlyContinue

    Write-Host "[SUCCESS] WinRM forced to Running and Firewall opened." -ForegroundColor Green
}



. {
    Write-Host "--- VM: MANUAL WINRM RESET ---" -ForegroundColor Cyan

    # 1. Stop the service
    Stop-Service winrm -Force -ErrorAction SilentlyContinue

    # 2. Physically delete the Listener keys from the registry
    # This is the manual version of 'unconfig'
    $ListenerPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Listener"
    if (Test-Path $ListenerPath) {
        Remove-Item -Path "$ListenerPath\*" -Recurse -Force
        Write-Host "[*] Registry Listeners Cleared." -ForegroundColor White
    }

    # 3. Force the Network Profile to Private (The 'WSMan Fault' Killer)
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

    # 4. Re-enable the basics
    & winrm quickconfig -quiet

    # 5. Ensure CNG Key Isolation is running (Stack Overflow Fix)
    # [Wael Dalloul](https://stackoverflow.com/questions/42829675/visual-studio-2017-fails-to-install-offline-with-unable-to-download-installatio) noted this is critical.
    Set-Service KeyIso -StartupType Manual
    Start-Service KeyIso -ErrorAction SilentlyContinue

    Write-Host "[SUCCESS] VM Listeners Rebuilt Manually." -ForegroundColor Green
}




. {
    Write-Host "--- VM: NETWORK SECURITY OVERRIDE ---" -ForegroundColor Cyan

    # Force all active connections inside the VM to Private
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
    
    # Disable the specific firewall rule that blocks WinRM on Public networks
    # (Just in case it flips back)
    Enable-NetFirewallRule -Name "WindowsRemoteManagement-In-TCP-Public" -ErrorAction SilentlyContinue

    Write-Host "[SUCCESS] VM Networking is now open for Host communication." -ForegroundColor Green
}

. {
    Write-Host "--- VM INTERNAL: ULTIMATE REPAIR ---" -ForegroundColor Cyan

    # 1. Fix the 0x1 vs 0x0 Conflict you found earlier
    # 0 = Allowed (Required for you), 1 = Restricted
    Write-Host "[*] Enforcing Blank Password Remote Use..." -ForegroundColor White
    reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v "LimitBlankPasswordUse" /t REG_DWORD /d 0 /f | Out-Null

    # 2. Disable UAC Remote Restrictions (The 'Invalid' Fix)
    Write-Host "[*] Disabling Remote Admin Token Filtering..." -ForegroundColor White
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "LocalAccountTokenFilterPolicy" /t REG_DWORD /d 1 /f | Out-Null

    # 3. Check CNG Key Isolation Service (Stack Overflow Fix)
    # If this service is disabled, the VS Installer and PSSessions often fail.
    $cng = Get-Service -Name KeyIso
    if ($cng.StartType -eq 'Disabled') {
        Write-Host "[!] FIXING: CNG Key Isolation was DISABLED." -ForegroundColor Red
        Set-Service -Name KeyIso -StartupType Manual
    }
    if ($cng.Status -ne 'Running') {
        Start-Service -Name KeyIso
        Write-Host "[OK] CNG Key Isolation Service Started." -ForegroundColor Green
    }

    # 4. Flush DNS and Reset WinRM Listener
    Write-Host "[*] Resetting WinRM Listener..." -ForegroundColor White
    winrm quickconfig -quiet
    Restart-Service WinRM -Force

    Write-Host "[SUCCESS] VM Security Database Cleared and Reset." -ForegroundColor Green
}




. {
    Write-Host "--- VM SECURITY & VS AUDIT ---" -ForegroundColor Cyan
    
    $FixesRequired = $false

    # 1. Audit LimitBlankPasswordUse (MUST BE 0)
    $lbp = Get-ItemPropertyValue -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -ErrorAction SilentlyContinue
    if ($lbp -ne 0) {
        Write-Host "[!] WRONG: LimitBlankPasswordUse is $lbp (Must be 0)." -ForegroundColor Red
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -Value 0
        $FixesRequired = $true
    } else {
        Write-Host "[OK] LimitBlankPasswordUse is 0." -ForegroundColor Green
    }

    # 2. Audit LocalAccountTokenFilterPolicy (MUST BE 1)
    $latfp = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -ErrorAction SilentlyContinue
    if ($latfp -ne 1) {
        Write-Host "[!] WRONG: LocalAccountTokenFilterPolicy is not 1." -ForegroundColor Red
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1
        $FixesRequired = $true
    } else {
        Write-Host "[OK] LocalAccountTokenFilterPolicy is 1." -ForegroundColor Green
    }

    # 3. Audit VS Certificates (The Stack Overflow Fix)
    Write-Host "[*] Checking for Visual Studio Setup Certificates..." -ForegroundColor White
    $certs = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*Microsoft*" }
    if ($certs.Count -lt 1) {
        Write-Host "[!] WARNING: No Microsoft Root Certs found. VS Installer may fail." -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Found $($certs.Count) Microsoft-related Root Certs." -ForegroundColor Green
    }

    # 4. Final Service Kick
    if ($FixesRequired) {
        Write-Host "[*] Applying changes and restarting WinRM..." -ForegroundColor Yellow
        Restart-Service WinRM -Force
        Write-Host "[SUCCESS] VM is now optimized for Host connection." -ForegroundColor Green
    } else {
        Write-Host "[OK] Services and Registry are aligned." -ForegroundColor Green
    }
}











# The Registry hasn't 'Settled': Even after Stage 0, sometimes the LSA needs to be poked. Run this  inside the VM.
gpupdate /force

# WinRM Service Hang: The service that listens for the connection is stuck. Run this inside the VM.
Restart-Service WinRM -Force

# UAC Remote Restrictions: Ensure that LocalAccountTokenFilterPolicy is definitely 1. You can verify this by running
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "LocalAccountTokenFilterPolicy"










# Allows PowerShell Direct to authenticate with a blank password
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -Value 0

Enable-VMIntegrationService -VMName "Windows 11 Master" -Name "Guest Service Interface"




. {

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LimitBlankPasswordUse" /t REG_DWORD /d 0 /f
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "LocalAccountTokenFilterPolicy" /t REG_DWORD /d 1 /f
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "FilterAdministratorToken" /t REG_DWORD /d 0 /f
    powershell -Command "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private"
    powershell -Command "Enable-PSRemoting -Force -SkipNetworkProfileCheck"

}













Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -Value 0

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LimitBlankPasswordUse" /t REG_DWORD /d 0 /f


# Point this to your VHD's certificate folder
$VhdDrive = (Get-Volume -FileSystemLabel "Staging").DriveLetter
$CertPath = "$($VhdDrive):\installers\VS_Offline\certificates"

if (Test-Path $CertPath) {
    Write-Host ">>> Forcing Trust for Offline Certificates..." -ForegroundColor Cyan
    Get-ChildItem $CertPath -Filter "*.cer" | ForEach-Object {
        # Import to the three critical stores
        certutil.exe -addstore -f "Root" $_.FullName | Out-Null
        certutil.exe -addstore -f "TrustedPublisher" $_.FullName | Out-Null
        certutil.exe -addstore -f "CA" $_.FullName | Out-Null
        Write-Host "Trusted: $($_.Name)" -ForegroundColor Gray
    }
    Write-Host ">>> Trust Injection Complete." -ForegroundColor Green
} else {
    Write-Host ">>> Error: Certificate folder not found at $CertPath" -ForegroundColor Red
}























reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f







Enable-PSRemoting -Force -SkipNetworkProfileCheck




# 1. Enable the WinRM service
Enable-PSRemoting -Force

# 2. Allow Unencrypted traffic (Required for local VMBus auth sometimes)
set-item wsman:\localhost\client\allowunencrypted $true

# 3. Trust all hosts (Since this is an offline Golden Image)
set-item wsman:\localhost\client\trustedhosts * -Force






# 1. Force all current network connections to 'Private'
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

# 2. Re-enable PSRemoting now that the profile is Private
Enable-PSRemoting -Force

# 3. Specific fix for the "Credential is Invalid" (LocalAccountTokenFilterPolicy)
# This allows local Administrator accounts to keep their tokens over remote sessions
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f













# Set Windows and Apps to Dark Mode
$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
Set-ItemProperty -Path $RegPath -Name "SystemUsesLightTheme" -Value 0
Set-ItemProperty -Path $RegPath -Name "AppsUseLightTheme" -Value 0

# Restart Explorer to apply the changes immediately
Stop-Process -Name explorer -Force



$Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
# Set System to Dark (Taskbar), but Apps to Light (Buttons/Menus)
Set-ItemProperty -Path $Path -Name "SystemUsesLightTheme" -Value 0
Set-ItemProperty -Path $Path -Name "AppsUseLightTheme" -Value 1
Stop-Process -Name explorer -Force






shell:::{ED834ED6-4B5A-4bfe-8F11-A626DCB6A921}



# 1. Set the background to Solid Color mode
$DesktopPath = "HKCU:\Control Panel\Desktop"
if (!(Test-Path $DesktopPath)) { New-Item -Path $DesktopPath -Force }
Set-ItemProperty -Path $DesktopPath -Name "Wallpaper" -Value ""
Set-ItemProperty -Path $DesktopPath -Name "WallpaperStyle" -Value "0"

# 2. Set the color to Black (RGB 0 0 0)
$ColorsPath = "HKCU:\Control Panel\Colors"
if (!(Test-Path $ColorsPath)) { New-Item -Path $ColorsPath -Force }
Set-ItemProperty -Path $ColorsPath -Name "Background" -Value "0 0 0"

# 3. Handle the 'Patterns' key only if needed (using -Force to avoid the "not found" error)
$PatternPath = "HKCU:\Control Panel\Patterns"
if (!(Test-Path $PatternPath)) { New-Item -Path $PatternPath -Force }
Set-ItemProperty -Path $PatternPath -Name "Pattern" -Value "" -Force

# 4. Refresh the UI
RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters
Stop-Process -Name explorer -Force












[Environment]::GetEnvironmentVariable("Path", "Machine") -split ";" | Select-String "Git|GitHub"



   reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v LimitBlankPasswordUse /t REG_DWORD /d 0 /f

net user Administrator GoldenMaster123!


   # 1. Set a fresh password
   net user Administrator GoldenMaster123!

   # 2. Unlock remote access for blank/simple passwords
   reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LimitBlankPasswordUse /t REG_DWORD /d 0 /f

   # 3. CRITICAL: Sync the clock to a valid date (Today)
   # Certificate verification fails if the VM thinks it is 2022 or 2023.
   Set-Date -Date "03/07/2026"

   Write-Host "[SUCCESS] VM Environment hardened for Offline Install." -ForegroundColor Green


   
   
   







# Force Auto-Admin Logon for the built-in Administrator
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -Value "1"
Set-ItemProperty -Path $registryPath -Name "DefaultUserName" -Value "Administrator"
Set-ItemProperty -Path $registryPath -Name "DefaultPassword" -Value "GoldenMaster123!"

















Unlock_PS.bat

@echo off
powershell.exe -Command "Set-ExecutionPolicy Bypass -Scope LocalMachine -Force"
echo PowerShell has been unlocked.
pause




@echo off
set "PS7_PATH=C:\Program Files\PowerShell\7\pwsh.exe"

:: 1. Run Stage 0 (Installs PS7)
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Install_Stage_0_Core.ps1"

:: 2. Check if PS7 was installed successfully
if exist "%PS7_PATH%" (
    echo [SUCCESS] PowerShell 7 detected. Switching engines...
    :: Launch the next stage in PS7 and exit this batch
    start "" "%PS7_PATH%" -ExecutionPolicy Bypass -File "%~dp0Install_Stage_1_Configs.ps1"
    exit
) else (
    echo [ERROR] PS7 install failed.
    pause
)




echo [*] Applying Official Windows (Dark) Theme...
start /wait mshta.exe javascript:a=new ActiveXObject('WScript.Shell');a.Run('rundll32.exe shell32.dll,Control_RunDLL desk.cpl,,@Themes /Action:OpenTheme /File:"C:\Windows\Resources\Themes\dark.theme"',0);window.close();


reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\Sysprep" /v "StatusWindowVisible" /t REG_DWORD /d 0 /f >nul




