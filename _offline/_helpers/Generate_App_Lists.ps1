# Comprehensive App Auditor (5-Category Version)
# Professional Grade: Now includes "Sysprep Integrity Check" to detect 0x80073cf2 errors.

Param(
    [switch]$ts,      
    [int[]]$open      
)

# --- CONFIGURATION ---
# Use same drive as script (hardcoded Z: may not exist on guest VM)
$scriptRoot = (Resolve-Path $PSScriptRoot).Path
$driveLetter = [System.IO.Path]::GetPathRoot($scriptRoot).TrimEnd('\:')
if (-not $driveLetter) { $driveLetter = 'C' }
$OutputDir = "${driveLetter}:\output\golden-master"
# $SystemName = "Golden_Master"
# $IncludeVersion = $true  
$BloatPatterns = @("*Bing*", "*Xbox*", "*Teams*", "*News*", "*Weather*", "*GetHelp*", "*Feedback*", "*Clipchamp*", "*Solitaire*", "*Zune*", "*Outlook*", "*YourPhone*", "*CrossDevice*", "*DevHome*")
# ---------------------

# --- SYSPREP EXCLUSION LIST (Safe Apps that are NOT provisioned) ---
$SysprepSafeApps = @(
    "1527c705-839a*", "c5e2524a*", "E2A4F912*", "F46D4000*", 
    "*AccountsControl*", "*AsyncTextService*", "*BioEnrollment*", "*CredDialogHost*",
    "*ECApp*", "*LockApp*", "*Win32WebViewHost*", "*CloudExperienceHost*",
    "*ShellExperienceHost*", "*StartMenuExperienceHost*", "*immersivecontrolpanel*",
    "*PrintDialog*", "*Client.CBS*", "*Client.FileExp*", "*Client.OOBE*", "*Client.Photon*",
    "*NET.Native*", "*VCLibs*", "*UI.Xaml*", "*WinAppRuntime*"
)

# (Previous Health and Meta Functions remain same...)
function Get-DetailedAppHealth { param($Name, $Source, $InstallLocation, $ExeName); $Status = @(); if ($InstallLocation) { $CleanPath = $InstallLocation.Replace('"','').Trim(); if (Test-Path $CleanPath) { $Status += "REG" } }; if ($Name -like "*Visual C++*" -or $Name -like "*WebView2*") { $Status += "REG" }; if ($ExeName) { if (Get-Command $ExeName -ErrorAction SilentlyContinue) { $Status += "PATH" } }; $LnkDirs = @("C:\ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"); if (Get-ChildItem -Path $LnkDirs -Filter "*$Name*" -Recurse -ErrorAction SilentlyContinue) { $Status += "LNK" }; if ($Status.Count -eq 0) { return "!! BROKEN !!" }; return ($Status -join "+") }
function Get-Purpose($Name) { if ($Name -like "*VCLibs*") { return "C++ Runtime Library (Required)" }; if ($Name -like "*NET.Native*") { return ".NET Runtime Engine (Required)" }; if ($Name -like "*UI.Xaml*") { return "UI Design Engine (Required)" }; if ($Name -like "*WinAppRuntime*") { return "Windows App SDK Runtime (Required)" }; if ($Name -like "*VideoExtension*" -or $Name -like "*ImageExtension*") { return "Media Codec/Extension (Required)" }; if ($Name -like "*MicrosoftWindows.Client*") { return "Core Win11 Shell UI (Required)" }; return "Unknown System Component" }
function Get-SurvivalFate($Name, $isProvisioned) { if ($isProvisioned) { return "MASTER: Deploys to EVERY new user" }; return "PURGE: Destroyed with Audit Profile" }
function Get-DesktopSource($App) { if ($App.InstallLocation -like "*\WinGet\Packages*") { return "WinGet" } ; if ($App.UninstallString -like "*winget*") { return "WinGet" } ; if ($App.DisplayName -like "*UniGetUI*") { return "WinGet" }; return "Manual" }
function Get-DetailedScope($Path) { if ($Path -like "*HKEY_LOCAL_MACHINE*") { return "Global" }; if ($Path -like "*HKEY_CURRENT_USER*") { if ($env:USERNAME -eq "Administrator") { return "Admin" } ; return $env:USERNAME }; return "null" }
function Build-FormattedString { param($Data, $Properties); if (-not $Data) { return "" }; $widths = @{}; foreach ($p in $Properties) { $max = ($Data | ForEach-Object { if ($_.$p) { $_.$p.ToString().Length } else { 0 } } | Measure-Object -Maximum).Maximum; if ($null -eq $max) { $max = 0 }; $widths[$p] = [Math]::Max($max, $p.Length) }; $headerLine = ""; $separatorLine = ""; foreach ($p in $Properties) { $headerLine += "{0,-$($widths[$p])}  " -f $p; $separatorLine += ("-" * $widths[$p]) + "  " }; $rows = foreach ($row in $Data) { $line = ""; foreach ($p in $Properties) { $val = if ($row.$p) { $row.$p } else { "" }; $line += "{0,-$($widths[$p])}  " -f $val }; $line.TrimEnd() }; return (($headerLine.TrimEnd(), $separatorLine.TrimEnd()) + $rows) -join "`r`n" }

# Paths
if (!(Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
$Prefix = if ($ts) { "$(Get-Date -Format 'yyyyMMdd_HHmm')_" } else { "" }
$pathInstalled = Join-Path $OutputDir "${Prefix}1_ALL_INSTALLED_APPS.txt"; $pathProvisioned = Join-Path $OutputDir "${Prefix}2_MASTER_TEMPLATE_APPS.txt"; $pathUnique = Join-Path $OutputDir "${Prefix}3_AUDIT_MODE_EXTRAS.txt"; $pathDesktop = Join-Path $OutputDir "${Prefix}4_ALL_DESKTOP_PROGRAMS.txt"; $pathAttention = Join-Path $OutputDir "${Prefix}5_NEEDS_ATTENTION.txt"

Write-Host "Gathering system data with Sysprep Integrity Checks..." -ForegroundColor Cyan

$installed = Get-AppxPackage -AllUsers | Select-Object Name, PackageFullName
$provisioned = Get-AppxProvisionedPackage -Online | Select-Object DisplayName, PackageName
$provisionedNames = $provisioned.DisplayName

# 1. Store Lists (Files 1-3)
$allInstalledData = $installed | Select-Object Name, @{Name="Purpose"; Expression={Get-Purpose $_.Name}}, @{Name="Survival_Fate"; Expression={Get-SurvivalFate $_.Name ($provisionedNames -contains $_.Name)}}, PackageFullName
$allProvisionedData = $provisioned | Select-Object @{Name="Name"; Expression={$_.DisplayName}}, @{Name="Purpose"; Expression={Get-Purpose $_.DisplayName}}, @{Name="Survival_Fate"; Expression={"MASTER: Deploys to EVERY user"}}, @{Name="PackageFullName"; Expression={$_.PackageName}}
$uniqueAppsData = $installed | Where-Object { $provisionedNames -notcontains $_.Name } | Select-Object Name, @{Name="Purpose"; Expression={Get-Purpose $_.Name}}, @{Name="Survival_Fate"; Expression={Get-SurvivalFate $_.Name $false}}, PackageFullName

Build-FormattedString -Data $allInstalledData -Properties @("Name", "Purpose", "Survival_Fate", "PackageFullName") | Out-File $pathInstalled -Encoding utf8
Build-FormattedString -Data $allProvisionedData -Properties @("Name", "Purpose", "Survival_Fate", "PackageFullName") | Out-File $pathProvisioned -Encoding utf8
Build-FormattedString -Data $uniqueAppsData -Properties @("Name", "Purpose", "Survival_Fate", "PackageFullName") | Out-File $pathUnique -Encoding utf8

# 2. Desktop Apps (File 4)
$RegPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "Registry::HKEY_USERS\*\Software\Microsoft\Windows\CurrentVersion\Uninstall\*")
$DesktopApps = Get-ItemProperty $RegPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -ne $null } | Select-Object @{Name="Scope"; Expression={Get-DetailedScope $_.PSPath}}, DisplayName, Publisher, @{Name="Source"; Expression={Get-DesktopSource $_}}, @{Name="Health"; Expression={Get-DetailedAppHealth $_.DisplayName (Get-DesktopSource $_) $_.InstallLocation ""}}, InstallLocation | Sort-Object DisplayName -Unique
$desktopProps = @("Scope", "DisplayName", "Source", "Health", "Publisher", "InstallLocation")
$GroupedApps = $DesktopApps | Group-Object Source | Sort-Object Name
$desktopOutput = ""; foreach ($Group in $GroupedApps) { $Header = "`n" + ("=" * 100) + "`n SOURCE: " + $Group.Name.ToUpper() + "`n" + ("=" * 100) + "`n"; $desktopOutput += $Header + (Build-FormattedString -Data $Group.Group -Properties $desktopProps) + "`n" }
$desktopOutput | Out-File $pathDesktop -Encoding utf8

# 3. Needs Attention (File 5 - THE SYSPREP INTEGRITY LIST)
$AttentionItems = New-Object System.Collections.Generic.List[PSObject]

# A. DETECT SYSPREP KILLERS (0x80073cf2 Detectors)
foreach ($uApp in $uniqueAppsData) {
    $isSafe = $false
    foreach ($safe in $SysprepSafeApps) { if ($uApp.Name -like $safe) { $isSafe = $true; break } }
    
    if (!$isSafe) {
        $AttentionItems.Add([PSCustomObject]@{Issue="CRITICAL: SYSPREP KILLER"; App=$uApp.Name; Recommendation="App is in user profile but NOT provisioned. Uninstall now!"})
    }
}

foreach ($app in $provisioned) { foreach ($p in $BloatPatterns) { if ($app.DisplayName -like $p) { $AttentionItems.Add([PSCustomObject]@{Issue="ACTION: BLOAT IN MASTER TEMPLATE"; App=$app.DisplayName; Recommendation="Purge template."}); break } } }
foreach ($app in $DesktopApps) { if ($app.Scope -ne "Global" -and $app.DisplayName -notlike "*Microsoft Visual C++*" -and $app.DisplayName -notlike "*Edge WebView2*") { $AttentionItems.Add([PSCustomObject]@{Issue="ACTION: USER-ONLY INSTALL"; App=$app.DisplayName; Recommendation="Reinstall global."}) } }

if ($AttentionItems.Count -gt 0) {
    $Header = "================================================================================`n !!! ACTION REQUIRED: SYSPREP INTEGRITY CHECK !!!`n================================================================================`n"
    ($Header + (Build-FormattedString -Data ($AttentionItems | Sort-Object Issue) -Properties @("Issue", "App", "Recommendation"))) | Out-File $pathAttention -Encoding utf8
} else { "CONGRATULATIONS: No Sysprep conflicts found!" | Out-File $pathAttention -Encoding utf8 }

Write-Host "`nSuccess! Review File 5 for SYSPREP KILLERS." -ForegroundColor Green
if ($open) { foreach ($num in $open) { switch ($num) { 1 { Invoke-Item $pathInstalled } 2 { Invoke-Item $pathProvisioned } 3 { Invoke-Item $pathUnique } 4 { Invoke-Item $pathDesktop } 5 { Invoke-Item $pathAttention } } } }
