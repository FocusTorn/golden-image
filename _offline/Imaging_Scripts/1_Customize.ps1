#Requires -RunAsAdministrator

param([switch]$StartMenuOnly)

$ErrorActionPreference = "SilentlyContinue"
$OfflineDir = Split-Path $PSScriptRoot -Parent
$LogFile = Join-Path $OfflineDir "stage0_deploy.log"
$Ps7Path = "C:\Program Files\PowerShell\7\pwsh.exe"

# --- STAGING DRIVE: 1) Label "Golden Imaging" 2) Fallback: Z..A reverse search for installers or _offline ---
$StagingDrive = $null
$StagingVolume = Get-Volume | Where-Object { $_.FileSystemLabel -eq "Golden Imaging" -and $_.DriveLetter -ne $null } | Select-Object -First 1
if ($StagingVolume) { $StagingDrive = $StagingVolume.DriveLetter }
if (-not $StagingDrive) {
    foreach ($d in [char[]](90..65)) {
        $root = "${d}:\"
        if ((Test-Path (Join-Path $root "installers")) -or (Test-Path (Join-Path $root "_offline"))) {
            $StagingDrive = $d
            break
        }
    }
}
if (-not $StagingDrive) {
    Write-Host "[FAIL] Staging drive not found (label 'Golden Imaging' or drive with installers/_offline)." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Set label; drive letter change happens at end (script uses current letter throughout)
$vol = Get-Volume -DriveLetter $StagingDrive -ErrorAction SilentlyContinue
if ($vol) { Set-Volume -DriveLetter $StagingDrive -NewFileSystemLabel "Golden Imaging" -ErrorAction SilentlyContinue }

$VhdDrive = "${StagingDrive}:\"
$OfflineDir = Join-Path $VhdDrive "_offline"
$LogFile = Join-Path $OfflineDir "stage0_deploy.log"
$InstallersDir = Join-Path $VhdDrive "installers"

 
#> 0. Header
Clear-Host
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "            GOLDEN MASTER: CUSTOMIZATION & FOUNDATION" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

"========================================================" | Out-File $LogFile
"STAGE 0 DEPLOYMENT LOG - $(Get-Date)" | Out-File $LogFile -Append
"========================================================" | Out-File $LogFile -Append

#<

#> 1. Admin check
$null = net session 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Must be run as Administrator." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

#<

#> 2. File Explorer
Write-Host "[>] Configuring File Explorer..." -ForegroundColor Gray

# Show File Extensions and hidden items
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Hidden -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name HideFileExt -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

#<

#> 3. Theme & display
Write-Host "[>] Applying Visual Styles..." -ForegroundColor Gray

# Set Dark Theme
if (Test-Path "C:\Windows\Resources\Themes\dark.theme") {
    Start-Process "C:\Windows\Resources\Themes\dark.theme"
    Start-Sleep -Seconds 2
    Stop-Process -Name systemsettings -Force -ErrorAction SilentlyContinue
}

# Set BG color to OLED black
Set-ItemProperty -Path "HKCU:\Control Panel\Colors" -Name Background -Value "0 0 0" -Force -ErrorAction SilentlyContinue

# # Remove default wallpaper
# $themeDir = Join-Path $env:APPDATA "Microsoft\Windows\Themes"
# Remove-Item (Join-Path $themeDir "TranscodedWallpaper") -Force -ErrorAction SilentlyContinue
# Remove-Item (Join-Path $themeDir "CachedFiles\*") -Force -Recurse -ErrorAction SilentlyContinue
# Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value "" -Force -ErrorAction SilentlyContinue
# Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class Wallpaper { [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni); }'
# [Wallpaper]::SystemParametersInfo(20, 0, "", 3) | Out-Null

# Set Display Resolution
if (Test-Path (Join-Path $InstallersDir "DisplayConfig\5.2.1\DisplayConfig.psd1")) {
    Import-Module (Join-Path $InstallersDir "DisplayConfig\5.2.1\DisplayConfig.psd1") -ErrorAction SilentlyContinue
    Set-DisplayResolution -DisplayId 1 -Width 1920 -Height 1080 -ErrorAction SilentlyContinue
}

#<

#> 4. Debloat Taskbar and Desktop
Write-Host "[>] Purging Bloat & Pins..." -ForegroundColor Gray

# Search Box
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name SearchboxTaskbarMode -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# Task Button
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowTaskViewButton -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# Disable Widgets (requires restart to take full effect)
$dshPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
if (-not (Test-Path $dshPath)) { New-Item -Path $dshPath -Force | Out-Null }
Set-ItemProperty -Path $dshPath -Name AllowNewsAndInterests -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarMn -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarDa -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# Taskbar pins
Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\*") -Force -ErrorAction SilentlyContinue

# Desktop cleanup
Remove-Item "$env:PUBLIC\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Desktop\*.url" -Force -ErrorAction SilentlyContinue

# Kill Sysprep Prompt and prevent it from reappearing on next boot
Stop-Process -Name sysprep -Force -ErrorAction SilentlyContinue
$setupPath = "HKLM:\SYSTEM\Setup"
Set-ItemProperty -Path $setupPath -Name "CmdLine" -Value "" -Type String -ErrorAction SilentlyContinue
@("AuditInProgress", "FactoryPreInstallInProgress", "MiniSetupInProgress", "SetupType", "SystemSetupInProgress") | ForEach-Object {
    Set-ItemProperty -Path $setupPath -Name $_ -Value 0 -Type DWord -ErrorAction SilentlyContinue
}

#<

#> 5. PowerShell 7 deployment
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

# Set execution policy
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" -Name ExecutionPolicy -Value "Bypass" -Force -ErrorAction SilentlyContinue

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

#<

#> 6. Windows Terminal default profile
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
                if (-not $j.profiles) { $j | Add-Member -NotePropertyName profiles -NotePropertyValue @{ defaults = @{}; list = @() } -Force }
                if (-not $j.profiles.list) { $j.profiles | Add-Member -NotePropertyName list -NotePropertyValue @() -Force }
                $profileList = @($j.profiles.list)

                $pwshProfile = $profileList | Where-Object {
                    $_.guid -eq $pwshGuid -or
                    $_.source -eq 'Windows.Terminal.PowershellCore' -or
                    ($_.commandline -and $_.commandline -match 'pwsh')
                } | Select-Object -First 1

                if ($pwshProfile) {
                    $j.defaultProfile = $pwshProfile.guid
                } else {
                    $newProfile = [PSCustomObject]@{
                        guid       = $pwshGuid
                        name       = "PowerShell 7"
                        commandline = $Ps7Path
                        hidden     = $false
                    }
                    $j.profiles.list = @($profileList) + $newProfile
                    $j.defaultProfile = $pwshGuid
                }
                $j | ConvertTo-Json -Depth 100 | Set-Content $wtSettings -Encoding UTF8 -Force
            } catch { }
        }
    }
}

#<

#> 7. PWSH Profile generation
Write-Host "[>] Updating PowerShell Profile..." -ForegroundColor Gray
$profileDir = Join-Path $env:USERPROFILE "Documents\PowerShell"
if (-not (Test-Path $profileDir)) { New-Item -Path $profileDir -ItemType Directory -Force | Out-Null }

$profileContent = @"
# --- GOLDEN MASTER RAPID COMMANDS ---
`$off = "$OfflineDir"

function db { & "`$off\GoldenImager.bat" }

if (Test-Path "`$off") { Set-Location "`$off" }
Write-Host "Golden Master Ready: menu | s0=Customize" -ForegroundColor Cyan
"@

$profileContent | Set-Content (Join-Path $profileDir "Microsoft.PowerShell_profile.ps1") -Encoding UTF8

#<

#> 8. Create Desktop Offline shortcut
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut((Join-Path $env:USERPROFILE "Desktop\_offline.lnk"))
$shortcut.TargetPath = $OfflineDir
$shortcut.Save()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null

#<

#> 9. Refresh
Write-Host "[>] Restarting Shell..." -ForegroundColor Gray
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue


# Start-Sleep -Seconds 2

# Use Process.Start to avoid passing working directory (which would open a File Explorer window)
# [void][System.Diagnostics.Process]::Start("explorer.exe")

#<

#> 10. Footer
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "[SUCCESS] System is Optimized & Customized." -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green

#<

#> 10b. PERSIST drive from config (GuestStagingDrive in _offline_config.json)
$configPath = Join-Path $OfflineDir "_offline_config.json"
$TargetDrive = 'E'
if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($cfg.PSObject.Properties['GuestStagingDrive'] -and $cfg.GuestStagingDrive) {
            $TargetDrive = $cfg.GuestStagingDrive.ToString().Trim().TrimEnd(':')[0]
        }
    } catch {}
}

if ($StagingDrive -ne $TargetDrive) {
    $part = Get-Partition -DriveLetter $StagingDrive -ErrorAction SilentlyContinue
    if ($part) {
        $targetVol = Get-Volume -DriveLetter $TargetDrive -ErrorAction SilentlyContinue
        if ($targetVol -and $targetVol.DriveLetter -ne $StagingDrive) {
            $targetPart = Get-Partition -DriveLetter $TargetDrive -ErrorAction SilentlyContinue
            if ($targetPart) { $targetPart | Remove-PartitionAccessPath -AccessPath "${TargetDrive}:\" -ErrorAction SilentlyContinue }
        }
        $part | Set-Partition -NewDriveLetter $TargetDrive -ErrorAction SilentlyContinue
        Write-Host "[*] Assigned ${TargetDrive}: to Golden Imaging (persists for future mounts)" -ForegroundColor Green
    }
}

# #> 10c. Share staging drive for host pull (HyperVGuestFileCopy.Pull uses \\VM\{drive}_DRIVE) - commented out
# $shareDrive = $TargetDrive
# $shareName = "${shareDrive}_DRIVE"
# $sharePath = "${shareDrive}:\"
# net share $shareName /delete 2>$null
# net share $shareName=$sharePath /GRANT:Everyone,FULL 2>$null
# if ($LASTEXITCODE -eq 0) { Write-Host "[*] Shared ${shareDrive}: as $shareName for host pull" -ForegroundColor Green }
# #<

#<

#> 12. Launch GUI
# Start-Sleep -Seconds 3

# Launch dashboard
# $launcher = Join-Path $OfflineDir "Launch_Dashboard.bat"
# Start-Process $launcher

#<
