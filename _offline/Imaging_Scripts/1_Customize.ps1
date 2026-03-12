#Requires -RunAsAdministrator
# 1_Customize.ps1 - Golden Master: Customization & Foundation
# Consolidated from 1_Customize.bat + Configure_Customize.ps1
# -StartMenuOnly: Run only Start menu MDM/registry (for scheduled task as SYSTEM)

param([switch]$StartMenuOnly)

$ErrorActionPreference = "SilentlyContinue"
$OfflineDir = $PSScriptRoot
$LogFile = Join-Path $OfflineDir "stage0_deploy.log"
$Ps7Path = "C:\Program Files\PowerShell\7\pwsh.exe"
$InstallersDir = Join-Path (Split-Path $OfflineDir -Parent) "installers"

if ($StartMenuOnly) {
    # Run only Start menu MDM/registry (invoked as SYSTEM by scheduled task)
    $props = @('AllowPinnedFolderSettings', 'AllowPinnedFolderFileExplorer')
    $parentIDs = @('./Vendor/MSFT/Policy/Config', './Device/Vendor/MSFT/Policy/Config')
    $instanceID = 'Start'
    $ns = 'root\cimv2\mdm\dmmap'
    $className = 'MDM_Policy_Config01_Start02'
    $value = 0
    foreach ($parentID in $parentIDs) {
        foreach ($prop in $props) {
            try {
                $existing = Get-CimInstance -Namespace $ns -ClassName $className -Filter "ParentID='$parentID' and InstanceID='$instanceID'" -ErrorAction SilentlyContinue
                if ($existing) {
                    $existing.$prop = $value
                    Set-CimInstance -InputObject $existing -ErrorAction SilentlyContinue
                } else {
                    New-CimInstance -Namespace $ns -ClassName $className -Property @{ InstanceID = $instanceID; ParentID = $parentID; $prop = $value } -ErrorAction SilentlyContinue
                }
            } catch { }
        }
    }
    $regPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    Set-ItemProperty -Path $regPath -Name AllowPinnedFolderSettings -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name AllowPinnedFolderSettings_ProviderSet -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name AllowPinnedFolderFileExplorer -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name AllowPinnedFolderFileExplorer_ProviderSet -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    $regPathDefault = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\device\Start"
    if (-not (Test-Path $regPathDefault)) { New-Item -Path $regPathDefault -Force | Out-Null }
    Set-ItemProperty -Path $regPathDefault -Name AllowPinnedFolderSettings -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPathDefault -Name AllowPinnedFolderSettings_ProviderSet -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPathDefault -Name AllowPinnedFolderFileExplorer -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPathDefault -Name AllowPinnedFolderFileExplorer_ProviderSet -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue
    exit 0
}

# --- Header ---
Clear-Host
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "            GOLDEN MASTER: CUSTOMIZATION & FOUNDATION" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

"========================================================" | Out-File $LogFile
"STAGE 0 DEPLOYMENT LOG - $(Get-Date)" | Out-File $LogFile -Append
"========================================================" | Out-File $LogFile -Append

# --- 1. Admin check (Requires handles this, but double-check) ---
$null = net session 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Must be run as Administrator." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# --- 2. Core system tweaks ---
Write-Host "[>] Configuring System Environment..." -ForegroundColor Gray
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" -Name ExecutionPolicy -Value "Bypass" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Hidden -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name HideFileExt -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name SearchboxTaskbarMode -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowTaskViewButton -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarDa -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
# Disable Widgets (requires restart to take full effect)
$dshPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
if (-not (Test-Path $dshPath)) { New-Item -Path $dshPath -Force | Out-Null }
Set-ItemProperty -Path $dshPath -Name AllowNewsAndInterests -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarMn -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# --- 3. Theme & display ---
Write-Host "[>] Applying Visual Styles..." -ForegroundColor Gray
if (Test-Path "C:\Windows\Resources\Themes\dark.theme") {
    Start-Process "C:\Windows\Resources\Themes\dark.theme"
    Start-Sleep -Seconds 2
    Stop-Process -Name systemsettings -Force -ErrorAction SilentlyContinue
}

$themeDir = Join-Path $env:APPDATA "Microsoft\Windows\Themes"
Remove-Item (Join-Path $themeDir "TranscodedWallpaper") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $themeDir "CachedFiles\*") -Force -Recurse -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Control Panel\Colors" -Name Background -Value "0 0 0" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value "" -Force -ErrorAction SilentlyContinue
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class Wallpaper { [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni); }'
[Wallpaper]::SystemParametersInfo(20, 0, "", 3) | Out-Null
if (Test-Path "F:\installers\DisplayConfig\5.2.1\DisplayConfig.psd1") {
    Import-Module "F:\installers\DisplayConfig\5.2.1\DisplayConfig.psd1" -ErrorAction SilentlyContinue
    Set-DisplayResolution -DisplayId 1 -Width 1920 -Height 1080 -ErrorAction SilentlyContinue
}

# --- 4. Aggressive debloat ---
Write-Host "[>] Purging Bloat & Pins..." -ForegroundColor Gray
Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartPage" -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Pins" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

$pinnedStartMenu = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu"
@("Microsoft Edge.lnk", "File Explorer.lnk", "Settings.lnk") | ForEach-Object {
    Remove-Item (Join-Path $pinnedStartMenu $_) -Force -ErrorAction SilentlyContinue
}

$shellDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Shell"
if (-not (Test-Path $shellDir)) { New-Item -Path $shellDir -ItemType Directory -Force | Out-Null }
'{"pinnedList": []}' | Set-Content (Join-Path $shellDir "LayoutModification.json") -Encoding UTF8 -Force

$startData = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
Remove-Item (Join-Path $startData "start2.bin") -Force -ErrorAction SilentlyContinue

Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue

# Start menu folder row - hide Settings and File Explorer
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Start_ShowFileExplorer -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Start_ShowSettings -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# Taskbar pins
Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\*") -Force -ErrorAction SilentlyContinue

# Desktop cleanup
Stop-Process -Name sysprep -Force -ErrorAction SilentlyContinue
Remove-Item "$env:PUBLIC\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Desktop\*.url" -Force -ErrorAction SilentlyContinue

# --- 5. PowerShell 7 deployment ---
if (-not (Test-Path $Ps7Path)) {
    Write-Host "[>] Installing PowerShell 7..." -ForegroundColor Gray
    $msi = Get-ChildItem (Join-Path $InstallersDir "PowerShell-*.msi") -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($msi) {
        $p = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$($msi.FullName)`"", "/passive", "/norestart" -Wait -PassThru
        if ($p.ExitCode -ne 0) {
            Write-Host "[FAIL] Installation failed." -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit 1
        }
    } else {
        Write-Host "[FAIL] MSI not found in $InstallersDir" -ForegroundColor Red
    }
}

# Associate .ps1 with PS7
Write-Host "[>] Configuring File Associations..." -ForegroundColor Gray
$ps7Reg = $Ps7Path -replace '\\', '\\\\'
$regContent = @"
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\Microsoft.PowerShellScript.1\Shell\Open\Command]
@="\`"$ps7Reg\`" \`"-File\`" \`"`%1\`" `%*"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\pwsh.exe]
@="`"$ps7Reg`""
"Path"="C:\\Program Files\\PowerShell\\7\\"
"@
$regFile = Join-Path $env:TEMP "ps7_defaults.reg"
$regContent | Set-Content $regFile -Encoding ASCII
Start-Process -FilePath "reg.exe" -ArgumentList "import", "`"$regFile`"" -Wait -NoNewWindow
Remove-Item $regFile -Force -ErrorAction SilentlyContinue

# --- 6. Windows Terminal default profile + Start menu (MDM, PolicyManager, Default user) ---
Write-Host "[>] Configuring Windows Terminal & Start menu..." -ForegroundColor Gray

if ($env:USERNAME -ne "SYSTEM") {
    $wtPaths = @(
        (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
        (Join-Path "C:\Users\Default\AppData\Local" "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json")
    )
    $pwshGuid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"

    foreach ($wtSettings in $wtPaths) {
        if (Test-Path $wtSettings) {
            try {
                $j = Get-Content $wtSettings -Raw -Encoding UTF8 | ConvertFrom-Json
                $profileList = $j.profiles.list
                $pwshProfile = $profileList | Where-Object { $_.commandline -match 'pwsh' } | Select-Object -First 1

                if ($pwshProfile -and $pwshProfile.guid) {
                    $j.defaultProfile = $pwshProfile.guid
                } else {
                    $existing = $profileList | Where-Object { $_.guid -eq $pwshGuid }
                    if (-not $existing) {
                        $newProfile = [PSCustomObject]@{
                            guid = $pwshGuid
                            name = "PowerShell 7"
                            commandline = "C:\Program Files\PowerShell\7\pwsh.exe"
                            hidden = $false
                        }
                        $j.profiles.list = @($profileList) + $newProfile
                    }
                    $j.defaultProfile = $pwshGuid
                }
                $j | ConvertTo-Json -Depth 100 | Set-Content $wtSettings -Encoding UTF8 -Force
            } catch { }
        }
    }
}

# MDM WMI Bridge
$props = @('AllowPinnedFolderSettings', 'AllowPinnedFolderFileExplorer')
$parentIDs = @('./Vendor/MSFT/Policy/Config', './Device/Vendor/MSFT/Policy/Config')
$instanceID = 'Start'
$ns = 'root\cimv2\mdm\dmmap'
$className = 'MDM_Policy_Config01_Start02'
$value = 0

foreach ($parentID in $parentIDs) {
    foreach ($prop in $props) {
        try {
            $existing = Get-CimInstance -Namespace $ns -ClassName $className -Filter "ParentID='$parentID' and InstanceID='$instanceID'" -ErrorAction SilentlyContinue
            if ($existing) {
                $existing.$prop = $value
                Set-CimInstance -InputObject $existing -ErrorAction SilentlyContinue
            } else {
                New-CimInstance -Namespace $ns -ClassName $className -Property @{ InstanceID = $instanceID; ParentID = $parentID; $prop = $value } -ErrorAction SilentlyContinue
            }
        } catch { }
    }
}

# PolicyManager registry - hide Settings and File Explorer from Start folder row
# ProviderSet=1 enforces the policy so user cannot override
$regPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start"
if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
Set-ItemProperty -Path $regPath -Name AllowPinnedFolderSettings -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $regPath -Name AllowPinnedFolderSettings_ProviderSet -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $regPath -Name AllowPinnedFolderFileExplorer -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $regPath -Name AllowPinnedFolderFileExplorer_ProviderSet -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

# Also set default policy so it persists
$regPathDefault = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\device\Start"
if (-not (Test-Path $regPathDefault)) { New-Item -Path $regPathDefault -Force | Out-Null }
Set-ItemProperty -Path $regPathDefault -Name AllowPinnedFolderSettings -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $regPathDefault -Name AllowPinnedFolderSettings_ProviderSet -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $regPathDefault -Name AllowPinnedFolderFileExplorer -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $regPathDefault -Name AllowPinnedFolderFileExplorer_ProviderSet -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

# Restart StartMenuExperienceHost to apply policy changes
Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue

# Default user
$defaultNtuser = "C:\Users\Default\NTUSER.DAT"
if (Test-Path $defaultNtuser) {
    try {
        Start-Process -FilePath "reg.exe" -ArgumentList "load", "HKU\DefaultUser", "`"$defaultNtuser`"" -Wait -NoNewWindow
        Set-ItemProperty -Path "Registry::HKEY_USERS\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Start_ShowFileExplorer -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "Registry::HKEY_USERS\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Start_ShowSettings -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    } finally {
        Start-Process -FilePath "reg.exe" -ArgumentList "unload", "HKU\DefaultUser" -Wait -NoNewWindow -ErrorAction SilentlyContinue
    }
}

# Run Start menu MDM as SYSTEM
$taskTr = "`"$Ps7Path`" -NoProfile -File `"$OfflineDir\1_Customize.ps1`" -StartMenuOnly"
schtasks /create /tn "GoldenImage_StartMenu" /tr $taskTr /sc once /st 00:00 /ru SYSTEM /f 2>$null
schtasks /run /tn "GoldenImage_StartMenu" 2>$null
Start-Sleep -Seconds 4
schtasks /delete /tn "GoldenImage_StartMenu" /f 2>$null

# --- 7. Profile generation ---
Write-Host "[>] Updating PowerShell Profile..." -ForegroundColor Gray
$profileDir = Join-Path $env:USERPROFILE "Documents\PowerShell"
if (-not (Test-Path $profileDir)) { New-Item -Path $profileDir -ItemType Directory -Force | Out-Null }

$profileContent = @"
# --- GOLDEN MASTER RAPID COMMANDS ---
`$off = "$OfflineDir"
function menu { & "`$off\VM_Dashboard.ps1" }
if (Test-Path "`$off") { Set-Location "`$off" }
Write-Host "Golden Master Ready: menu | s0=Customize" -ForegroundColor Cyan
"@
$profileContent | Set-Content (Join-Path $profileDir "Microsoft.PowerShell_profile.ps1") -Encoding UTF8

# Create Offline shortcut
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut((Join-Path $env:USERPROFILE "Desktop\_offline.lnk"))
$shortcut.TargetPath = $OfflineDir
$shortcut.Save()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null

# --- 8. Refresh ---
Write-Host "[>] Restarting Shell..." -ForegroundColor Gray
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
# Use Process.Start to avoid passing working directory (which would open a File Explorer window)
[void][System.Diagnostics.Process]::Start("explorer.exe")
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "[SUCCESS] System is Optimized & Customized." -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host "[NOTE] Widgets: A full restart may be needed for the change to take effect." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# Launch dashboard
$launcher = Join-Path $OfflineDir "Launch_Dashboard.bat"
Start-Process $launcher
