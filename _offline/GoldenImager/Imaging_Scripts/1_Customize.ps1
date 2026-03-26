<#
.SYNOPSIS
    Stage 1: Customization & Foundation.
    Optimizes the Windows environment for Golden Image creation, installs PWSH 7, 
    and configures essential developer/system tweaks.

.DESCRIPTION
    - Detects and labels the Staging Drive (Golden Imaging).
    - Configures Explorer (Hidden files, extensions).
    - Applies Dark Mode and OLED Black background.
    - Sets Display Resolution (1920x1080).
    - Debloats Taskbar/Desktop and persists Audit Mode.
    - Installs and configures PowerShell 7 as the system default.
    - Generates PWSH profiles and desktop shortcuts.
#>

#Requires -RunAsAdministrator
param([switch]$StartMenuOnly)

$ErrorActionPreference = "SilentlyContinue"

# ==============================================================================
# --- CONFIGURATION: ACTION TOGGLES ---
# Set to $false to skip an individual action.
# ==============================================================================
$Action_ShowHiddenFiles        = $false
$Action_ShowFileExtensions     = $false
$Action_ApplyDarkTheme         = $false
$Action_SetDisplayResolution   = $true
$Action_HideTaskbarSearch      = $false
$Action_HideTaskView           = $false
$Action_DisableWidgetsNews     = $false
$Action_ClearTaskbarDesktop    = $false
$Action_InstallPowerShell7     = $true
$Action_SetExecutionPolicy     = $true
$Action_SetTerminalDefault     = $true
$Action_GeneratePwshProfile    = $true
$Action_CreateDesktopShortcuts = $true
$Action_FinalizeDriveLetter    = $true
# ==============================================================================

# --- HELPER FUNCTIONS ---

function Invoke-ActionWithValidation {
    param(
        [Parameter(Mandatory=$true)] [string]$ActionDesc,
        [Parameter(Mandatory=$true)] [scriptblock]$Do,
        [Parameter(Mandatory=$true)] [scriptblock]$Verify
    )
    Write-Host "[>] $ActionDesc" -ForegroundColor Gray
    try { & $Do } catch { Write-Host "  [!] Action error: $_" -ForegroundColor Yellow }
    
    $ok = $false
    try { $ok = & $Verify } catch {}
    
    if ($ok) { 
        Write-Host "  [OK] Verified." -ForegroundColor Green 
    } else { 
        Write-Host "  [--] Verification pending (may require restart/refresh)." -ForegroundColor DarkGray 
    }
}

function Invoke-RegistryAction {
    param(
        [Parameter(Mandatory=$true)] [string]$ActionDesc,
        [Parameter(Mandatory=$true)] [string]$Path,
        [Parameter(Mandatory=$true)] [string]$Name,
        [Parameter(Mandatory=$true)] [object]$ExpectedValue,
        [string]$Type = "DWord"
    )
    Invoke-ActionWithValidation -ActionDesc $ActionDesc -Do {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $ExpectedValue -Type $Type -Force -ErrorAction Stop
    } -Verify {
        $v = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($null -ne $v) { $v.$Name.ToString() -eq $ExpectedValue.ToString() } else { $false }
    }
}

# --- ENVIRONMENT DISCOVERY ---

# Scripts are in _offline/GoldenImager/Imaging_Scripts, so VHD Root is typically three levels up.
$VhdRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$InstallersDir = Join-Path $VhdRoot "installers"
$OfflineDir = Join-Path $VhdRoot "_offline"

# Fallback: Search for "installers" folder on all drives if not found relative to script
if (-not (Test-Path $InstallersDir)) {
    foreach ($d in [char[]](90..65)) {
        if (Test-Path "${d}:\installers") {
            $VhdRoot = "${d}:\"
            $InstallersDir = "${d}:\installers"
            $OfflineDir = "${d}:\_offline"
            break
        }
    }
}

if (-not (Test-Path $InstallersDir)) {
    Write-Host "[FAIL] Could not locate 'installers' directory." -ForegroundColor Red
    exit 1
}

$VhdDrive = $VhdRoot
$Ps7Path = "C:\Program Files\PowerShell\7\pwsh.exe"

# 1. Staging Drive Discovery (From Config) - Used for persistence later
$OfflineConfigPath = Join-Path $OfflineDir "_offline_config.json"
if (-not (Test-Path $OfflineConfigPath)) {
    Write-Host "[FAIL] _offline_config.json not found in $OfflineDir." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$Cfg = Get-Content $OfflineConfigPath | ConvertFrom-Json
$TargetDrive = if ($Cfg.GuestStagingDrive) { $Cfg.GuestStagingDrive.ToString().Trim().TrimEnd(':')[0] } else { "F" }
$Label = if ($Cfg.StagingVolumeLabel) { $Cfg.StagingVolumeLabel } else { "Golden Imaging" }

# Extract current drive letter for persistence logic
$StagingDrive = $VhdRoot.TrimEnd('\').TrimEnd(':')

# 2. Path Initialization
$LogFile = Join-Path $OfflineDir "stage1_customize.log"

# --- HEADER & LOGGING ---

Clear-Host
$Header = @"
================================================================
            GOLDEN MASTER: CUSTOMIZATION & FOUNDATION
================================================================
"@
Write-Host $Header -ForegroundColor Cyan

"========================================================" | Out-File $LogFile
"STAGE 1 CUSTOMIZATION LOG - $(Get-Date)" | Out-File $LogFile -Append
"========================================================" | Out-File $LogFile -Append

# --- EXECUTION BLOCKS ---

# 1. UI & Explorer Tweaks
Write-Host "`n[ SECTION: UI & EXPLORER ]" -ForegroundColor Magenta
$explorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

if ($Action_ShowHiddenFiles) {
    Invoke-RegistryAction -ActionDesc "Show hidden files" -Path $explorerPath -Name Hidden -ExpectedValue 1
}

if ($Action_ShowFileExtensions) {
    Invoke-RegistryAction -ActionDesc "Show file extensions" -Path $explorerPath -Name HideFileExt -ExpectedValue 0
}

if ($Action_ApplyDarkTheme) {
    Invoke-ActionWithValidation -ActionDesc "Apply Dark Theme & OLED Black" -Do {
        # Set Black Background
        Set-ItemProperty -Path "HKCU:\Control Panel\Colors" -Name Background -Value "0 0 0" -Type String
        
        # Trigger Dark Mode via Theme file if available
        if (Test-Path "C:\Windows\Resources\Themes\dark.theme") {
            Start-Process "C:\Windows\Resources\Themes\dark.theme"
            Start-Sleep -Seconds 2
            Stop-Process -Name systemsettings -Force -ErrorAction SilentlyContinue
        }
    } -Verify {
        $cur = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name AppsUseLightTheme -ErrorAction SilentlyContinue
        $cur.AppsUseLightTheme -eq 0
    }
}

if ($Action_SetDisplayResolution) {
    Invoke-ActionWithValidation -ActionDesc "Set Display Resolution (1920x1080)" -Do {
        $dcModule = Join-Path $InstallersDir "DisplayConfig\5.2.1\DisplayConfig.psd1"
        if (Test-Path $dcModule) {
            Import-Module $dcModule -ErrorAction SilentlyContinue
            Set-DisplayResolution -DisplayId 1 -Width 1920 -Height 1080 -ErrorAction SilentlyContinue
        }
    } -Verify { $true }
}

# --- SECTION 4: DEBLOAT & PERSISTENCE ---
Write-Host "`n[ SECTION: DEBLOAT & PERSISTENCE ]" -ForegroundColor Magenta

if ($Action_HideTaskbarSearch) {
    Invoke-RegistryAction -ActionDesc "Hide Taskbar Search" -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name SearchboxTaskbarMode -ExpectedValue 0
}

if ($Action_HideTaskView) {
    Invoke-RegistryAction -ActionDesc "Hide Task View" -Path $explorerPath -Name ShowTaskViewButton -ExpectedValue 0
}

if ($Action_DisableWidgetsNews) {
    Invoke-ActionWithValidation -ActionDesc "Disable Widgets & News" -Do {
        $dshPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
        if (-not (Test-Path $dshPath)) { New-Item -Path $dshPath -Force | Out-Null }
        Set-ItemProperty -Path $dshPath -Name AllowNewsAndInterests -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $explorerPath -Name TaskbarMn -Value 0 -Type DWord -Force
    } -Verify { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Dsh").AllowNewsAndInterests -eq 0 }
}

if ($Action_ClearTaskbarDesktop) {
    Invoke-ActionWithValidation -ActionDesc "Clear Taskbar Pins & Desktop Shortcuts" -Do {
        Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Recurse -Force
        Remove-Item "$env:PUBLIC\Desktop\*.lnk", "$env:USERPROFILE\Desktop\*.lnk", "$env:USERPROFILE\Desktop\*.url" -Force
    } -Verify { $true }
}

# 3. PowerShell 7 & Terminal
Write-Host "`n[ SECTION: POWERSHELL 7 ]" -ForegroundColor Magenta

if ($Action_InstallPowerShell7) {
    if (-not (Test-Path $Ps7Path)) {
        Invoke-ActionWithValidation -ActionDesc "Install PowerShell 7" -Do {
            $msi = Get-ChildItem (Join-Path $InstallersDir "PowerShell-*.msi") | Select-Object -First 1
            if ($msi) {
                Start-Process "msiexec.exe" -ArgumentList "/i", "`"$($msi.FullName)`"", "/passive", "/norestart" -Wait
            } else { throw "MSI not found" }
        } -Verify { Test-Path $Ps7Path }
    }
}

if ($Action_SetExecutionPolicy) {
    Invoke-RegistryAction -ActionDesc "Set Global Execution Policy: Bypass" -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" -Name ExecutionPolicy -ExpectedValue "Bypass" -Type String
}

if ($Action_SetTerminalDefault) {
    Invoke-ActionWithValidation -ActionDesc "Set Windows Terminal Default to PWSH 7" -Do {
        $wtSettings = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        if (Test-Path $wtSettings) {
            $j = Get-Content $wtSettings -Raw | ConvertFrom-Json
            $pwshGuid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"
            $j.defaultProfile = $pwshGuid
            $j | ConvertTo-Json -Depth 100 | Set-Content $wtSettings -Force
        }
    } -Verify { $true }
}

# 4. Profiles & Shortcuts
Write-Host "`n[ SECTION: PROFILES & SHORTCUTS ]" -ForegroundColor Magenta
$profilePath = Join-Path $env:USERPROFILE "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"

if ($Action_GeneratePwshProfile) {
    Invoke-ActionWithValidation -ActionDesc "Generate PWSH 7 Profile" -Do {
        $profileDir = Split-Path $profilePath -Parent
        if (-not (Test-Path $profileDir)) { New-Item $profileDir -ItemType Directory -Force }
        $profileContent = @"
# --- GOLDEN MASTER RAPID COMMANDS ---
`$off = "$OfflineDir"
function db { & "`$off\GoldenImager.bat" }
if (Test-Path "`$off") { Set-Location "`$off" }
Write-Host "Golden Master Ready: db = Launch Dashboard" -ForegroundColor Cyan
"@
        $profileContent | Set-Content $profilePath -Encoding UTF8
    } -Verify { Test-Path $profilePath }
}

if ($Action_CreateDesktopShortcuts) {
    Invoke-ActionWithValidation -ActionDesc "Create Desktop Shortcuts" -Do {
        $shell = New-Object -ComObject WScript.Shell
        
        # Shortcut 1: _offline folder
        $s1 = $shell.CreateShortcut((Join-Path $env:USERPROFILE "Desktop\_offline.lnk"))
        $s1.TargetPath = $OfflineDir
        $s1.Save()

        # Shortcut 2: Golden Imager Dashboard
        $s2 = $shell.CreateShortcut((Join-Path $env:USERPROFILE "Desktop\Golden Imager.lnk"))
        $s2.TargetPath = Join-Path $OfflineDir "GoldenImager.bat"
        $s2.WorkingDirectory = $OfflineDir
        $s2.IconLocation = "C:\Windows\System32\imageres.dll,183"
        $s2.Save()

        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
    } -Verify { Test-Path (Join-Path $env:USERPROFILE "Desktop\Golden Imager.lnk") }
}

# 5. Drive Persistence
Write-Host "`n[ SECTION: DRIVE PERSISTENCE ]" -ForegroundColor Magenta

if ($Action_FinalizeDriveLetter) {
    if ($StagingDrive -ne $TargetDrive) {
        Invoke-ActionWithValidation -ActionDesc "Finalize Drive Letter: ${TargetDrive}:" -Do {
            $part = Get-Partition -DriveLetter $StagingDrive
            $part | Set-Partition -NewDriveLetter $TargetDrive
        } -Verify { (Get-Volume -DriveLetter $TargetDrive) -ne $null }
    }
}

# --- FINALIZATION ---

Write-Host "`n[ SECTION: REFRESH ]" -ForegroundColor Gray
Write-Host "[>] Restarting Explorer to apply registry changes..." -ForegroundColor Gray
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "[SUCCESS] Stage 1: Customization Complete." -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host "You can now launch the dashboard using the 'Golden Imager' shortcut on the desktop." -ForegroundColor Gray
Write-Host ""

$host.UI.RawUI.FlushInputBuffer()
Read-Host "Press Enter to exit"