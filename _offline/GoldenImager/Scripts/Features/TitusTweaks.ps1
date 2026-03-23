function Invoke-DeleteTemporaryFiles {
    Write-Host "Deleting temporary files..."
    Remove-Item -Path "$Env:Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$Env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
}

function Invoke-DisableHibernation {
    Write-Host "Disabling hibernation..."
    powercfg.exe /hibernate off
}

function Invoke-RunDiskCleanup {
    Write-Host "Running Disk Cleanup..."
    if (Test-Path "$env:SystemRoot\System32\cleanmgr.exe") {
        Start-Process -FilePath cleanmgr.exe -ArgumentList "/d C: /VERYLOWDISK" -Wait -NoNewWindow
    }
    # Clean up component store
    Start-Process -FilePath Dism.exe -ArgumentList "/online /Cleanup-Image /StartComponentCleanup /ResetBase" -Wait -NoNewWindow
}

function Invoke-SetServicesToManual {
    Write-Host "Setting non-essential services to Manual startup..."
    $services = @(
        "DiagTrack", "WapnService", "WSearch", "SysMain", "MapsBroker", "Spooler", "PrintNotify", "Fax", 
        "WbioSrvc", "WerSvc", "TouchKeyboard", "TabletInputService"
    )
    foreach ($svc in $services) {
        if (Get-Service $svc -ErrorAction SilentlyContinue) {
            Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-AdobeNetworkBlock {
    Write-Host "Blocking Adobe network connections in HOSTS file..."
    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $adobeDomains = @(
        "127.0.0.1 lmlicenses.wip4.adobe.com",
        "127.0.0.1 lm.licenses.adobe.com",
        "127.0.0.1 na1r.services.adobe.com",
        "127.0.0.1 hlrcv.stage.adobe.com",
        "127.0.0.1 practivate.adobe.com",
        "127.0.0.1 activate.adobe.com"
    )
    
    if (-not (Test-Path $hostsPath)) { New-Item -Path $hostsPath -ItemType File -Force | Out-Null }
    
    $currentHosts = Get-Content $hostsPath -Raw
    $newContent = $currentHosts
    if ($null -eq $newContent) { $newContent = "" }
    
    foreach ($domain in $adobeDomains) {
        if ($newContent -notmatch [regex]::Escape($domain)) {
            $newContent += "`r`n$domain"
        }
    }
    Set-Content -Path $hostsPath -Value $newContent -Force
}

function Invoke-DisableIPv6 {
    Write-Host "Disabling IPv6..."
    Get-NetAdapter | ForEach-Object {
        Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
    }
}

function Invoke-DisableTeredo {
    Write-Host "Disabling Teredo..."
    netsh interface teredo set state disabled
}

function Invoke-SetDisplayForPerformance {
    Write-Host "Optimizing display settings for performance..."
    # Visual Effects: Adjust for best performance
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    Set-ItemProperty -Path $regPath -Name "VisualFXSetting" -Value 3 -ErrorAction SilentlyContinue
    
    # UserPreferencesMask (complicated binary value, skipping for safety in non-interactive/audit mode unless strictly defined)
    # Instead, we set specific keys that control animations
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Type Binary -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Force -ErrorAction SilentlyContinue
}

function Invoke-AddUltimatePerformancePlan {
    Write-Host "Adding and activating Ultimate Performance power plan..."
    $guid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    # Duplicate the Ultimate Performance scheme
    powercfg -duplicatescheme $guid
    # Set as active
    powercfg -setactive $guid
}

function Invoke-InstallHyperVAndNFS {
    Write-Host "Installing Hyper-V and NFS features..."
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
    Enable-WindowsOptionalFeature -Online -FeatureName ServicesForNFS-ClientOnly -All -NoRestart
    Enable-WindowsOptionalFeature -Online -FeatureName ClientForNFS-Infrastructure -All -NoRestart
}

function Invoke-SetUpAutologin {
    Write-Host "Configuring Autologin..."
    # Note: Requires user password, which we don't have. 
    # CTT usually prompts or uses Sysinternals Autologon.
    # We will set the registry keys to prompt for it or enable the capability.
    # Setting AutoAdminLogon = 1
    $path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $path -Name "AutoAdminLogon" -Value "1" -Force
    Set-ItemProperty -Path $path -Name "DefaultUserName" -Value $env:USERNAME -Force
    # We cannot set DefaultPassword securely here without prompting. 
    Write-Warning "Autologin enabled for $env:USERNAME. You may need to enter credentials or configure DefaultPassword manually."
}

function Invoke-SystemCorruptionScan {
    Write-Host "Running System Corruption Scan (DISM & SFC)..."
    Start-Process -FilePath Dism.exe -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -NoNewWindow
    Start-Process -FilePath sfc.exe -ArgumentList "/scannow" -Wait -NoNewWindow
}

function Invoke-ResetWindowsUpdate {
    Write-Host "Resetting Windows Update components..."
    Stop-Service -Name wuauserv, bits, cryptsvc -Force -ErrorAction SilentlyContinue
    $sdPath = "$env:SystemRoot\SoftwareDistribution"
    if (Test-Path $sdPath) {
        Remove-Item -Path "$sdPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    Start-Service -Name wuauserv, bits, cryptsvc -ErrorAction SilentlyContinue
}

function Invoke-WinGetReinstall {
    Write-Host "Reinstalling WinGet..."
    # Using the AppxBundle logic if available, or just registering
    $wingetPackage = Get-AppxPackage -AllUsers *Microsoft.DesktopAppInstaller*
    if ($wingetPackage) {
        Add-AppxPackage -Register "$($wingetPackage.InstallLocation)\AppxManifest.xml" -DisableDevelopmentMode -ForceApplicationShutdown
    } else {
        Write-Warning "WinGet package not found to reinstall."
    }
}
