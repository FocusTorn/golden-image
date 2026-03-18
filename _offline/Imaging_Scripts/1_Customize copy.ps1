#Requires -RunAsAdministrator

param([switch]$StartMenuOnly)

$ErrorActionPreference = "SilentlyContinue"

function Invoke-ActionWithValidation {
    param([string]$ActionDesc, [scriptblock]$Do, [scriptblock]$Verify)
    Write-Host "[>] $ActionDesc" -ForegroundColor Gray
    try { & $Do } catch { Write-Host "  [!] Action error: $_" -ForegroundColor Yellow }
    $ok = $false
    try { $ok = & $Verify } catch {}
    if ($ok) { Write-Host "  [OK] Verified." -ForegroundColor Green } else { Write-Host "  [--] Could not verify (may need restart)." -ForegroundColor DarkGray }
}

function Invoke-RegistryAction {
    param([string]$ActionDesc, [string]$Path, [string]$Name, [object]$ExpectedValue, [string]$Type = "DWord")
    Invoke-ActionWithValidation -ActionDesc $ActionDesc -Do {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $ExpectedValue -Type $Type -Force -ErrorAction Stop
    } -Verify {
        $v = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($v) { $v.$Name.ToString() -eq $ExpectedValue.ToString() } else { $false }
    }
}
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
$explorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Invoke-RegistryAction -ActionDesc "Show hidden files" -Path $explorerPath -Name Hidden -ExpectedValue 1
Invoke-RegistryAction -ActionDesc "Show file extensions" -Path $explorerPath -Name HideFileExt -ExpectedValue 0

#<

#> 3. Theme & display
Invoke-ActionWithValidation -ActionDesc "Apply dark theme" -Do {
    if (Test-Path "C:\Windows\Resources\Themes\dark.theme") {
        Start-Process "C:\Windows\Resources\Themes\dark.theme"
        Start-Sleep -Seconds 2
        Stop-Process -Name systemsettings -Force -ErrorAction SilentlyContinue
    }
} -Verify {
    $cur = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name AppsUseLightTheme -ErrorAction SilentlyContinue
    $cur -and $cur.AppsUseLightTheme -eq 0
}

Invoke-RegistryAction -ActionDesc "Set background to OLED black" -Path "HKCU:\Control Panel\Colors" -Name Background -ExpectedValue "0 0 0" -Type String

Invoke-ActionWithValidation -ActionDesc "Set display resolution 1920x1080" -Do {
    if (Test-Path (Join-Path $InstallersDir "DisplayConfig\5.2.1\DisplayConfig.psd1")) {
        Import-Module (Join-Path $InstallersDir "DisplayConfig\5.2.1\DisplayConfig.psd1") -ErrorAction SilentlyContinue
        Set-DisplayResolution -DisplayId 1 -Width 1920 -Height 1080 -ErrorAction SilentlyContinue
    }
} -Verify { $true }

#<

#> 4. Debloat Taskbar and Desktop
Invoke-RegistryAction -ActionDesc "Hide Search box on taskbar" -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name SearchboxTaskbarMode -ExpectedValue 0
Invoke-RegistryAction -ActionDesc "Hide Task View button" -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowTaskViewButton -ExpectedValue 0

$dshPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
Invoke-ActionWithValidation -ActionDesc "Disable Widgets (News/Interests)" -Do {
    if (-not (Test-Path $dshPath)) { New-Item -Path $dshPath -Force | Out-Null }
    Set-ItemProperty -Path $dshPath -Name AllowNewsAndInterests -Value 0 -Type DWord -Force -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarMn -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarDa -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
} -Verify {
    (Get-ItemProperty -Path $dshPath -Name AllowNewsAndInterests -ErrorAction SilentlyContinue).AllowNewsAndInterests -eq 0
}

Invoke-ActionWithValidation -ActionDesc "Clear taskbar pins" -Do {
    Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\*") -Force -ErrorAction SilentlyContinue
} -Verify {
    $tb = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    -not (Test-Path $tb) -or (Get-ChildItem $tb -ErrorAction SilentlyContinue).Count -eq 0
}

Invoke-ActionWithValidation -ActionDesc "Clear desktop shortcuts" -Do {
    Remove-Item "$env:PUBLIC\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:USERPROFILE\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:USERPROFILE\Desktop\*.url" -Force -ErrorAction SilentlyContinue
} -Verify {
    $pub = (Get-ChildItem "$env:PUBLIC\Desktop\*.lnk" -ErrorAction SilentlyContinue).Count -eq 0
    $usr = (Get-ChildItem "$env:USERPROFILE\Desktop\*.lnk" -ErrorAction SilentlyContinue).Count -eq 0
    $pub -and $usr
}

Invoke-ActionWithValidation -ActionDesc "Kill Sysprep and clear setup flags" -Do {
    Stop-Process -Name sysprep -Force -ErrorAction SilentlyContinue
    $setupPath = "HKLM:\SYSTEM\Setup"
    Set-ItemProperty -Path $setupPath -Name "CmdLine" -Value "" -Type String -ErrorAction SilentlyContinue
    @("AuditInProgress", "FactoryPreInstallInProgress", "MiniSetupInProgress", "SetupType", "SystemSetupInProgress") | ForEach-Object {
        Set-ItemProperty -Path $setupPath -Name $_ -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
} -Verify {
    $v = Get-ItemProperty -Path "HKLM:\SYSTEM\Setup" -Name "AuditInProgress" -ErrorAction SilentlyContinue
    $v -and $v.AuditInProgress -eq 0
}

#<

#> 5. PowerShell 7 deployment
if (-not (Test-Path $Ps7Path)) {
    Invoke-ActionWithValidation -ActionDesc "Install PowerShell 7" -Do {
        $msi = Get-ChildItem (Join-Path $InstallersDir "PowerShell-*.msi") -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($msi) {
            $p = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$($msi.FullName)`"", "/passive", "/norestart" -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "Exit code $($p.ExitCode)" }
        } else { throw "MSI not found" }
    } -Verify { Test-Path $Ps7Path }
    if (-not (Test-Path $Ps7Path)) {
        Write-Host "[FAIL] PowerShell 7 installation failed." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Invoke-RegistryAction -ActionDesc "Set execution policy Bypass" -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" -Name ExecutionPolicy -ExpectedValue "Bypass" -Type String

Invoke-ActionWithValidation -ActionDesc "Associate .ps1 with PowerShell 7" -Do {
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
} -Verify {
    $cmd = (Get-ItemProperty "Registry::HKEY_CLASSES_ROOT\Microsoft.PowerShellScript.1\Shell\Open\Command" -Name "(default)" -ErrorAction SilentlyContinue)."(default)"
    $cmd -and $cmd -match "pwsh"
}

#<

#> 6. Windows Terminal default profile
if ($env:USERNAME -ne "SYSTEM") {
    Invoke-ActionWithValidation -ActionDesc "Set Windows Terminal default to PowerShell 7" -Do {
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
    } -Verify {
        $wtPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        if (-not (Test-Path $wtPath)) { return $true }
        $j = Get-Content $wtPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction SilentlyContinue
        $j -and $null -ne $j.defaultProfile
    }
}

#<

#> 7. PWSH Profile generation
$profilePath = Join-Path $env:USERPROFILE "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
Invoke-ActionWithValidation -ActionDesc "Create PowerShell 7 profile" -Do {
    $profileDir = Split-Path $profilePath -Parent
    if (-not (Test-Path $profileDir)) { New-Item -Path $profileDir -ItemType Directory -Force | Out-Null }
    $profileContent = @"
# --- GOLDEN MASTER RAPID COMMANDS ---
`$off = "$OfflineDir"

function db { & "`$off\GoldenImager.bat" }

if (Test-Path "`$off") { Set-Location "`$off" }
Write-Host "Golden Master Ready: menu | s0=Customize" -ForegroundColor Cyan
"@
    $profileContent | Set-Content $profilePath -Encoding UTF8
} -Verify { Test-Path $profilePath -and (Get-Content $profilePath -Raw -ErrorAction SilentlyContinue) -match "Golden Master" }

#<

#> 8. Create Desktop Offline shortcut
$shortcutPath = Join-Path $env:USERPROFILE "Desktop\_offline.lnk"
Invoke-ActionWithValidation -ActionDesc "Create Desktop _offline shortcut" -Do {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $OfflineDir
    $shortcut.Save()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
} -Verify { Test-Path $shortcutPath }

#<

#> 9. Refresh
Write-Host ""
Write-Host "[>] About to restart Explorer (shell). Press Enter to continue..." -ForegroundColor Yellow
$host.UI.RawUI.FlushInputBuffer()
$null = Read-Host
$host.UI.RawUI.FlushInputBuffer()
Write-Host "[>] Restarting Explorer..." -ForegroundColor Gray
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
    Invoke-ActionWithValidation -ActionDesc "Assign drive letter ${TargetDrive}: to Golden Imaging" -Do {
        $part = Get-Partition -DriveLetter $StagingDrive -ErrorAction SilentlyContinue
        if ($part) {
            $targetVol = Get-Volume -DriveLetter $TargetDrive -ErrorAction SilentlyContinue
            if ($targetVol -and $targetVol.DriveLetter -ne $StagingDrive) {
                $targetPart = Get-Partition -DriveLetter $TargetDrive -ErrorAction SilentlyContinue
                if ($targetPart) { $targetPart | Remove-PartitionAccessPath -AccessPath "${TargetDrive}:\" -ErrorAction SilentlyContinue }
            }
            $part | Set-Partition -NewDriveLetter $TargetDrive -ErrorAction SilentlyContinue
        }
    } -Verify { (Get-Volume -DriveLetter $TargetDrive -ErrorAction SilentlyContinue) -ne $null }
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
Write-Host ""
$host.UI.RawUI.FlushInputBuffer()
Write-Host "Press Enter to close..." -ForegroundColor Gray
$null = Read-Host
$host.UI.RawUI.FlushInputBuffer()

#> 12. Launch GUI
# Start-Sleep -Seconds 3

# Launch dashboard
# $launcher = Join-Path $OfflineDir "Launch_Dashboard.bat"
# Start-Process $launcher

#<
