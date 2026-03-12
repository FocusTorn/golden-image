# Win11Debloat config script - uncomment options to enable, comment to disable
# Edit the $Config block below: remove # from options you want, add # to disable
# Run elevated when applying. Use -WhatIf to preview. Use -UseLocal for local Win11Debloat.ps1

param(
    [switch]$WhatIf,      # Preview only - don't run Win11Debloat
    [switch]$UseLocal     # Use local Win11Debloat.ps1 in same folder (if present)
)

$ErrorActionPreference = "Stop"
$Win11DebloatUrl = "https://debloat.raphi.re/"
$Win11DebloatLocal = Join-Path $PSScriptRoot "Win11Debloat.ps1"

# =============================================================================
# CONFIG - Edit below. Uncomment (remove #) to enable, comment (add #) to disable.
# For mutually exclusive options (e.g. CombineTaskbar*), uncomment only ONE.
# =============================================================================
$Config = @"
# --- Run mode ---
# CreateRestorePoint
# Silent
# NoRestartExplorer
# Sysprep
# -User "username"
# -LogPath "C:\Logs"
# -AppRemovalTarget "AllUsers"

# --- App removal ---
# RemoveApps
# RemoveAppsCustom
# RemoveGamingApps
# RemoveCommApps
# RemoveHPApps
# RemoveW11Outlook
# ForceRemoveEdge
# -Apps "Microsoft.OneDrive,Microsoft.Whiteboard"

# --- Privacy & telemetry ---
# DisableTelemetry
# DisableSuggestions
# DisableLocationServices
# DisableFindMyDevice
# DisableSearchHistory
# DisableEdgeAds
# DisableSettings365Ads
# DisableBraveBloat

# --- Content & tips ---
# DisableDesktopSpotlight
# DisableLockscreenTips
# DisableSettingsHome

# --- Search ---
# DisableBing
# DisableStoreSearchSuggestions
# DisableSearchHighlights

# --- AI features ---
# DisableCopilot
# DisableRecall
# DisableClickToDo
# DisableAISvcAutoStart
# DisablePaintAI
# DisableNotepadAI
# DisableEdgeAI

# --- System ---
# DisableFastStartup
# DisableBitlockerAutoEncryption
# DisableModernStandbyNetworking
# DisableStorageSense
# DisableUpdateASAP
# PreventUpdateAutoReboot
# DisableDeliveryOptimization

# --- Appearance ---
# EnableDarkMode
# DisableTransparency
# DisableAnimations

# --- Start menu ---
# ClearStart
# ClearStartAllUsers
# DisableStartRecommended
# DisableStartAllApps
# DisableStartPhoneLink
# -ReplaceStart "path\to\layout.json"
# -ReplaceStartAllUsers "path\to\layout.json"

# --- Taskbar - alignment ---
# TaskbarAlignLeft

# --- Taskbar - combine (main) ---
# CombineTaskbarAlways
# CombineTaskbarWhenFull
# CombineTaskbarNever

# --- Taskbar - combine (secondary) ---
# CombineMMTaskbarAlways
# CombineMMTaskbarWhenFull
# CombineMMTaskbarNever

# --- Taskbar - multi-monitor ---
# MMTaskbarModeAll
# MMTaskbarModeMainActive
# MMTaskbarModeActive

# --- Taskbar - search ---
# HideSearchTb
# ShowSearchIconTb
# ShowSearchLabelTb
# ShowSearchBoxTb

# --- Taskbar - other ---
# HideTaskview
# DisableWidgets
# HideChat
# EnableEndTask
# EnableLastActiveClick

# --- File Explorer - default open ---
# ExplorerToHome
# ExplorerToThisPC
# ExplorerToDownloads
# ExplorerToOneDrive

# --- File Explorer - display ---
# ShowHiddenFolders
# ShowKnownFileExt
# HideDupliDrive
# AddFoldersToThisPC

# --- File Explorer - navigation ---
# HideHome
# HideGallery
# HideOnedrive
# Hide3dObjects
# HideMusic

# --- File Explorer - context menu ---
# HideIncludeInLibrary
# HideGiveAccessTo
# HideShare

# --- Window snapping ---
# DisableWindowSnapping
# DisableSnapAssist
# DisableSnapLayouts

# --- Alt+Tab tabs ---
# HideTabsInAltTab
# Show3TabsInAltTab
# Show5TabsInAltTab
# Show20TabsInAltTab

# --- Gaming ---
# DisableDVR
# DisableGameBarIntegration

# --- Other ---
# RevertContextMenu
# DisableDragTray
# DisableMouseAcceleration
# DisableStickyKeys

# --- Optional features ---
# EnableWindowsSandbox
# EnableWindowsSubsystemForLinux
"@

# =============================================================================
# Parse config and build params
# =============================================================================
$paramNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$stringParams = @{}

foreach ($line in ($Config -split "`r?`n")) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
    if ($trimmed.StartsWith('#')) { continue }

    if ($trimmed -match '^(-?\w+)\s+(.+)$') {
        $name = $Matches[1].TrimStart('-')
        $paramNames.Add($name) | Out-Null
        $val = $Matches[2].Trim().Trim('"').Trim("'")
        if ($val -and $val -ne '""') { $stringParams[$name] = $val }
        continue
    }

    if ($trimmed -match '^(-?\w+)\s*$') {
        $paramNames.Add($Matches[1].TrimStart('-')) | Out-Null
    }
}

$splat = @{}
foreach ($name in $paramNames) {
    $splat[$name] = if ($stringParams.ContainsKey($name)) { $stringParams[$name] } else { $true }
}

if (-not $splat.ContainsKey('Silent')) { $splat['Silent'] = $true }

$optionCount = ($splat.Keys | Where-Object { $_ -ne 'Silent' }).Count
if ($optionCount -eq 0) {
    Write-Host "No options selected. Edit the `$Config block above: remove # from options you want, then run again." -ForegroundColor Yellow
    exit 0
}

Write-Host "Win11Debloat Config - applying $optionCount options" -ForegroundColor Cyan
$splat.Keys | Sort-Object | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

if ($WhatIf) {
    Write-Host "`n[WhatIf] Would run Win11Debloat with above params. Run without -WhatIf to apply." -ForegroundColor Yellow
    exit 0
}

if ($UseLocal -and (Test-Path $Win11DebloatLocal)) {
    Write-Host "`nUsing local Win11Debloat.ps1" -ForegroundColor Green
    & $Win11DebloatLocal @splat
} else {
    Write-Host "`nDownloading and running Win11Debloat from $Win11DebloatUrl" -ForegroundColor Green
    $scriptBlock = [scriptblock]::Create((Invoke-RestMethod -Uri $Win11DebloatUrl -UseBasicParsing))
    & $scriptBlock @splat
}
