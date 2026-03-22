#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$CLI,
    [switch]$Silent,
    [switch]$Sysprep,
    [string]$LogPath,
    [string]$User,
    [switch]$NoRestartExplorer,
    [switch]$CreateRestorePoint,
    [switch]$RunAppsListGenerator,
    [switch]$RunDefaults,
    [switch]$RunDefaultsLite,
    [switch]$RunSavedSettings,
    [string]$Apps,
    [string]$AppRemovalTarget,
    [switch]$RemoveApps,
    [switch]$RemoveAppsCustom,
    [switch]$RemoveGamingApps,
    [switch]$RemoveCommApps,
    [switch]$RemoveHPApps,
    [switch]$RemoveW11Outlook,
    [switch]$ForceRemoveEdge,
    [switch]$DisableDVR,
    [switch]$DisableGameBarIntegration,
    [switch]$EnableWindowsSandbox,
    [switch]$EnableWindowsSubsystemForLinux,
    [switch]$DisableTelemetry,
    [switch]$DisableSearchHistory,
    [switch]$DisableFastStartup,
    [switch]$DisableBitlockerAutoEncryption,
    [switch]$DisableModernStandbyNetworking,
    [switch]$DisableStorageSense,
    [switch]$DisableUpdateASAP,
    [switch]$PreventUpdateAutoReboot,
    [switch]$DisableDeliveryOptimization,
    [switch]$DisableBing,
    [switch]$DisableStoreSearchSuggestions,
    [switch]$DisableSearchHighlights,
    [switch]$DisableDesktopSpotlight,
    [switch]$DisableLockscreenTips,
    [switch]$DisableSuggestions,
    [switch]$DisableLocationServices,
    [switch]$DisableFindMyDevice,
    [switch]$DisableEdgeAds,
    [switch]$DisableBraveBloat,
    [switch]$DisableSettings365Ads,
    [switch]$DisableSettingsHome,
    [switch]$ShowHiddenFolders,
    [switch]$ShowKnownFileExt,
    [switch]$HideDupliDrive,
    [switch]$EnableDarkMode,
    [switch]$DisableTransparency,
    [switch]$DisableAnimations,
    [switch]$TaskbarAlignLeft,
    [switch]$CombineTaskbarAlways, [switch]$CombineTaskbarWhenFull, [switch]$CombineTaskbarNever,
    [switch]$CombineMMTaskbarAlways, [switch]$CombineMMTaskbarWhenFull, [switch]$CombineMMTaskbarNever,
    [switch]$MMTaskbarModeAll, [switch]$MMTaskbarModeMainActive, [switch]$MMTaskbarModeActive,
    [switch]$HideSearchTb, [switch]$ShowSearchIconTb, [switch]$ShowSearchLabelTb, [switch]$ShowSearchBoxTb,
    [switch]$HideTaskview,
    [switch]$DisableStartRecommended,
    [switch]$DisableStartAllApps,
    [switch]$DisableStartPhoneLink,
    [switch]$DisableCopilot,
    [switch]$DisableRecall,
    [switch]$DisableClickToDo,
    [switch]$DisableAISvcAutoStart,
    [switch]$DisablePaintAI,
    [switch]$DisableNotepadAI,
    [switch]$DisableEdgeAI,
    [switch]$DisableWidgets,
    [switch]$HideChat,
    [switch]$EnableEndTask,
    [switch]$EnableLastActiveClick,
    [switch]$ClearStart,
    [string]$ReplaceStart,
    [switch]$ClearStartAllUsers,
    [string]$ReplaceStartAllUsers,
    [switch]$RevertContextMenu,
    [switch]$DisableDragTray,
    [switch]$DisableMouseAcceleration,
    [switch]$DisableStickyKeys,
    [switch]$DisableWindowSnapping,
    [switch]$DisableSnapAssist,
    [switch]$DisableSnapLayouts,
    [switch]$HideTabsInAltTab, [switch]$Show3TabsInAltTab, [switch]$Show5TabsInAltTab, [switch]$Show20TabsInAltTab,
    [switch]$HideHome,
    [switch]$HideGallery,
    [switch]$ExplorerToHome,
    [switch]$ExplorerToThisPC,
    [switch]$ExplorerToDownloads,
    [switch]$ExplorerToOneDrive,
    [switch]$AddFoldersToThisPC,
    [switch]$HideOnedrive,
    [switch]$Hide3dObjects,
    [switch]$HideMusic,
    [switch]$HideIncludeInLibrary,
    [switch]$HideGiveAccessTo,
    [switch]$HideShare
)

# Define script-level variables & paths
$script:SourceRoot = Join-Path $PSScriptRoot 'Foundation/Win11Debloat'
if (-not $script:SourceRoot -or -not (Test-Path $script:SourceRoot)) {
    $displayPath = if ($script:SourceRoot) { $script:SourceRoot } else { "(empty - check script path)" }
    Write-Host "[ERROR] Foundation not found at: $displayPath" -ForegroundColor Red
    Write-Host "        Run 'Sync _offline' (11) from the Staging Dashboard to copy Foundation to the VHD." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

$script:Version = "2026.03.22"
$script:AuditDelaySeconds = 2
$script:SpinnerStyle = "OldWinBars1"
$script:AppsListFilePath = "$script:SourceRoot/Config/Apps.json"
$script:DefaultSettingsFilePath = "$script:SourceRoot/Config/DefaultSettings.json"
$script:FeaturesFilePath = "$script:SourceRoot/Config/Features.json"
$script:SavedSettingsFilePath = "$script:SourceRoot/Config/LastUsedSettings.json"
$script:CustomAppsListFilePath = "$script:SourceRoot/Config/CustomAppsList"
$script:OverlayAppsListFilePath = "$PSScriptRoot/Config/Apps.json"
$script:LoadAppsDetailsScriptPath = "$PSScriptRoot/Scripts/FileIO/LoadAppsDetailsFromJson.ps1"
$script:RegfilesPath = "$script:SourceRoot/Regfiles"
$script:AssetsPath = "$script:SourceRoot/Assets"
$script:AppSelectionSchema = "$script:SourceRoot/Schemas/AppSelectionWindow.xaml"
$script:MessageBoxSchema = "$script:SourceRoot/Schemas/MessageBoxWindow.xaml"
$script:AboutWindowSchema = "$script:SourceRoot/Schemas/AboutWindow.xaml"
$script:ApplyChangesWindowSchema = "$script:SourceRoot/Schemas/ApplyChangesWindow.xaml"
$script:SharedStylesSchema = "$script:SourceRoot/Schemas/SharedStyles.xaml"

# GuiFork: use our MainWindow.xaml with profile UI and default "installed only"
$script:MainWindowSchema = Join-Path $PSScriptRoot "Schemas/MainWindow.xaml"
$script:AppProfilesPath = Join-Path $PSScriptRoot "Config\AppProfiles"
$script:TweakProfilesPath = Join-Path $PSScriptRoot "Config\TweakProfiles"
$script:DefaultLogPath = Join-Path $PSScriptRoot "Logs\GoldenImager.log"

$script:ControlParams = 'WhatIf', 'Confirm', 'Verbose', 'Debug', 'LogPath', 'Silent', 'Sysprep', 'User', 'NoRestartExplorer', 'RunDefaults', 'RunDefaultsLite', 'RunSavedSettings', 'RunAppsListGenerator', 'CLI', 'AppRemovalTarget'

# Script-level variables for GUI elements
$script:GuiWindow = $null
$script:CancelRequested = $false
$script:ApplyProgressCallback = $null
$script:ApplySubStepCallback = $null

##################################################################################################################
#                                          COMPONENT IMPORTS                                                     #
##################################################################################################################

# Load configuration components
. "$PSScriptRoot/Scripts/Config/Typography.ps1"

# Initialize script (Logging, Pre-flight checks, Feature loading, WinGet check)
. "$PSScriptRoot/Scripts/Core/Initialize.ps1"

# Load Core & Utility functions
. "$PSScriptRoot/Scripts/Utils/SystemUtils.ps1"
. "$PSScriptRoot/Scripts/Utils/WpfUtils.ps1"
. "$PSScriptRoot/Scripts/Core/UserProfiles.ps1"
. "$PSScriptRoot/Scripts/Core/ExecutionLogic.ps1"

# Load app removal functions
. "$script:SourceRoot/Scripts/AppRemoval/ForceRemoveEdge.ps1"
. "$PSScriptRoot/Scripts/AppRemoval/RemoveApps.ps1"
. "$PSScriptRoot/Scripts/AppRemoval/GetInstalledApps.ps1"

# Load CLI functions
. "$PSScriptRoot/Scripts/CLI/AwaitKeyToExit.ps1"
. "$script:SourceRoot/Scripts/CLI/ShowCLILastUsedSettings.ps1"  
. "$script:SourceRoot/Scripts/CLI/ShowCLIDefaultModeAppRemovalOptions.ps1"
. "$script:SourceRoot/Scripts/CLI/ShowCLIDefaultModeOptions.ps1"
. "$script:SourceRoot/Scripts/CLI/ShowCLIAppRemoval.ps1"
. "$script:SourceRoot/Scripts/CLI/ShowCLIMenuOptions.ps1"
. "$script:SourceRoot/Scripts/CLI/PrintPendingChanges.ps1"
. "$script:SourceRoot/Scripts/CLI/PrintHeader.ps1"

# Load Feature functions
. "$script:SourceRoot/Scripts/Features/CreateSystemRestorePoint.ps1"
. "$script:SourceRoot/Scripts/Features/DisableStoreSearchSuggestions.ps1"
. "$script:SourceRoot/Scripts/Features/EnableWindowsFeature.ps1"
. "$script:SourceRoot/Scripts/Features/ImportRegistryFile.ps1"
. "$PSScriptRoot/Scripts/Features/ImportRegistryFileForRevert.ps1"
. "$script:SourceRoot/Scripts/Features/ReplaceStartMenu.ps1"
. "$script:SourceRoot/Scripts/Features/RestartExplorer.ps1"

# Load GUI functions
. "$script:SourceRoot/Scripts/GUI/GetSystemUsesDarkMode.ps1"
. "$script:SourceRoot/Scripts/GUI/SetWindowThemeResources.ps1"
. "$script:SourceRoot/Scripts/GUI/AttachShiftClickBehavior.ps1"
. "$PSScriptRoot/Scripts/GUI/ApplySettingsToUiControls.ps1"
. "$script:SourceRoot/Scripts/GUI/Show-MessageBox.ps1"
. "$script:SourceRoot/Scripts/GUI/Show-ApplyModal.ps1"
. "$script:SourceRoot/Scripts/GUI/Show-AppSelectionWindow.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-MainWindow.ps1"
. "$script:SourceRoot/Scripts/GUI/Show-AboutDialog.ps1"

# Load File I/O functions
. "$script:SourceRoot/Scripts/FileIO/LoadJsonFile.ps1"
. "$script:SourceRoot/Scripts/FileIO/SaveSettings.ps1"
. "$script:SourceRoot/Scripts/FileIO/LoadSettings.ps1"
. "$script:SourceRoot/Scripts/FileIO/SaveCustomAppsListToFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/ValidateAppslist.ps1"
. "$script:SourceRoot/Scripts/FileIO/LoadAppsFromFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/LoadAppsDetailsFromJson.ps1"

##################################################################################################################
#                                                  SCRIPT START                                                  #
##################################################################################################################

# Get current Windows build version
$WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

# Check if the machine supports Modern Standby
$script:ModernStandbySupported = CheckModernStandbySupport

$script:Params = $PSBoundParameters

# Add default Apps parameter when RemoveApps is requested and Apps was not explicitly provided
if ((-not $script:Params.ContainsKey("Apps")) -and $script:Params.ContainsKey("RemoveApps")) {
    $script:Params.Add('Apps', 'Default')
}

$controlParamsCount = 0
foreach ($Param in $script:ControlParams) {
    if ($script:Params.ContainsKey($Param)) {
        $controlParamsCount++
    }
}

# Hide progress bars for app removal, as they block Golden Imager's output
if (-not ($script:Params.ContainsKey("Verbose"))) {
    $ProgressPreference = 'SilentlyContinue'
}
else {
    Write-Host "Verbose mode is enabled"
    Write-Output ""
    Write-Output "Press any key to continue..."
    $null = [System.Console]::ReadKey()
    $ProgressPreference = 'Continue'
}

if ($script:Params.ContainsKey("Sysprep")) {
    $null = GetUserDirectory -userName "Default"
    if ($WinVersion -lt 22000) {
        Write-Error "Golden Imager Sysprep mode is not supported on Windows 10"
        AwaitKeyToExit
    }
}

# Ensure that target user exists, if User or AppRemovalTarget parameter was provided
if ($script:Params.ContainsKey("User")) {
    $userPath = GetUserDirectory -userName $script:Params.Item("User")
}
if ($script:Params.ContainsKey("AppRemovalTarget")) {
    $userPath = GetUserDirectory -userName $script:Params.Item("AppRemovalTarget")
}

# Remove LastUsedSettings.json file if it exists and is empty
if ((Test-Path $script:SavedSettingsFilePath) -and ([String]::IsNullOrWhiteSpace((Get-content $script:SavedSettingsFilePath)))) {
    Remove-Item -Path $script:SavedSettingsFilePath -recurse
}

# Only run the app selection form if the 'RunAppsListGenerator' parameter was passed to the script
if ($RunAppsListGenerator) {
    PrintHeader "Custom Apps List Generator"
    $result = Show-AppSelectionWindow
    if ($result -ne $true) {
        Write-Host "Application selection window was closed without saving." -ForegroundColor Red
    }
    else {
        Write-Output "Your app selection was saved to the 'CustomAppsList' file, found at:"
        Write-Host "$script:SourceRoot" -ForegroundColor Yellow
    }
    AwaitKeyToExit
}

# Change script execution based on provided parameters or user input
if ((-not $script:Params.Count) -or $RunDefaults -or $RunDefaultsLite -or $RunSavedSettings -or ($controlParamsCount -eq $script:Params.Count)) {
    if ($RunDefaults -or $RunDefaultsLite) {
        ShowCLIDefaultModeOptions
    }
    elseif ($RunSavedSettings) {
        if (-not (Test-Path $script:SavedSettingsFilePath)) {
            PrintHeader 'Custom Mode'
            Write-Error "Unable to find LastUsedSettings.json file, no changes were made"
            AwaitKeyToExit
        }
        ShowCLILastUsedSettings
    }
    else {
        if ($CLI) {
            $Mode = ShowCLIMenuOptions 
        }
        elseif (-not (Test-WpfAvailable)) {
            Write-Host "WPF GUI is not available in this environment. Using CLI mode." -ForegroundColor Yellow
            if (-not $Silent) {
                Write-Host ""
                Write-Host "Press any key to continue..."
                $null = [System.Console]::ReadKey()
            }
            $Mode = ShowCLIMenuOptions
        }
        else {
            try {
                $result = Show-MainWindow
                Stop-Transcript -ErrorAction SilentlyContinue
                Copy-LogToReturnPath
                Exit
            }
            catch {
                Write-Warning "Unable to load WPF GUI: $($_.Exception.Message). Falling back to CLI mode."
                if (-not $Silent) {
                    Write-Host ""
                    Write-Host "Press any key to continue..."
                    $null = [System.Console]::ReadKey()
                }
                $Mode = ShowCLIMenuOptions
            }
        }
    }

    # Add execution parameters based on the mode
    switch ($Mode) {
        '1' { ShowCLIDefaultModeOptions }
        '2' { ShowCLIAppRemoval }
        '3' { ShowCLILastUsedSettings }
    }
}
else {
    PrintHeader 'Configuration'
}

# Exit if no modifications/changes were selected
if (($controlParamsCount -eq $script:Params.Keys.Count) -or ($script:Params.Keys.Count -eq 1 -and ($script:Params.Keys -contains 'CreateRestorePoint' -or $script:Params.Keys -contains 'Apps'))) {
    Write-Output "The script completed without making any changes."
    AwaitKeyToExit
}

# Execute all selected/provided parameters
ExecuteAllChanges
RestartExplorer

Write-Output ""
Write-Output ""
Write-Output ""
Write-Output "Script completed! Please check above for any errors."

AwaitKeyToExit
