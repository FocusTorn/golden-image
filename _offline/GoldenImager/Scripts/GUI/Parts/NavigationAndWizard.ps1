function UpdateSidebarState {
    param($scriptScope)
    $currentIndex = $scriptScope.MainTabControl.SelectedIndex
    
    # Reset all sidebar buttons
    $sideButtons = @("SideHomeBtn", "SideAppsBtn", "SideTweaksBtn", "SideSettingsBtn")
    foreach ($btnName in $sideButtons) {
        if ($null -ne $scriptScope[$btnName]) {
            $scriptScope[$btnName].Background = [System.Windows.Media.Brushes]::Transparent
            $scriptScope[$btnName].Opacity = 0.7
        }
    }

    # Highlight active button
    $activeBtn = switch($currentIndex) {
        0 { "SideHomeBtn" }
        1 { "SideAppsBtn" }
        2 { "SideTweaksBtn" }
        3 { "SideSettingsBtn" }
        default { "" }
    }

    if ($activeBtn -and $null -ne $scriptScope[$activeBtn]) {
        $scriptScope[$activeBtn].Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#20FFFFFF"))
        $scriptScope[$activeBtn].Opacity = 1.0
    }
}

function Set-Status {
    param([string]$Message, [string]$Icon = "&#xE73E;")
    # Attempt to find the elements in the window if the global scope is not set
    $statusText = $script:MainWindowScope.StatusText
    $statusIcon = $script:MainWindowScope.StatusBarIcon
    if ($null -ne $statusText) { $statusText.Text = $Message }
    if ($null -ne $statusIcon) { $statusIcon.Text = $Icon }
}

function Initialize-Navigation {
    param($scriptScope)
    
    # Set the global scope for Set-Status
    $script:MainWindowScope = $scriptScope

    # Sidebar Click Handlers (Using scriptScope to avoid closure issues)
    if ($null -ne $scriptScope.SideHomeBtn) { 
        $scriptScope.SideHomeBtn.Add_Click({ $scriptScope.MainTabControl.SelectedIndex = 0; UpdateSidebarState -scriptScope $scriptScope }) 
    }
    if ($null -ne $scriptScope.SideAppsBtn) { 
        $scriptScope.SideAppsBtn.Add_Click({ $scriptScope.MainTabControl.SelectedIndex = 1; UpdateSidebarState -scriptScope $scriptScope }) 
    }
    if ($null -ne $scriptScope.SideTweaksBtn) { 
        $scriptScope.SideTweaksBtn.Add_Click({ $scriptScope.MainTabControl.SelectedIndex = 2; UpdateSidebarState -scriptScope $scriptScope }) 
    }
    
    # Settings Sidebar Button
    if ($null -ne $scriptScope.SideSettingsBtn) { 
        $scriptScope.SideSettingsBtn.Add_Click({ $scriptScope.MainTabControl.SelectedIndex = 3; UpdateSidebarState -scriptScope $scriptScope }) 
    }
    
    # Settings Dashboard Buttons
    if ($null -ne $scriptScope.SettingsExportBtn) {
        $scriptScope.SettingsExportBtn.Add_Click({ 
            if ($scriptScope.MenuExportSettings) { $scriptScope.MenuExportSettings.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent)) }
        })
    }
    if ($null -ne $scriptScope.SettingsImportBtn) {
        $scriptScope.SettingsImportBtn.Add_Click({ 
            if ($scriptScope.MenuImportSettings) { $scriptScope.MenuImportSettings.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent)) }
        })
    }
    if ($null -ne $scriptScope.SettingsReviewAllBtn) {
        $scriptScope.SettingsReviewAllBtn.Add_Click({ 
            ShowChangesOverview -scriptScope $scriptScope -forceAll $true
        })
    }
    if ($null -ne $scriptScope.SettingsLogsBtn) {
        $scriptScope.SettingsLogsBtn.Add_Click({ 
            $scriptScope.window.FindName("MenuLogs")?.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.MenuItem]::ClickEvent))
            Set-Status -Message "Opening Logs..."
        })
    }

    # Main Apply Button
    if ($null -ne $scriptScope.DeploymentApplyBtn) {
        $scriptScope.DeploymentApplyBtn.Add_Click({ 
            Invoke-Deployment -scriptScope $scriptScope
        })
    }

    # Exit Button
    if ($null -ne $scriptScope.SideExitBtn) {
        $scriptScope.SideExitBtn.Add_Click({ $scriptScope.window.Close() })
    }

    # Tab Selection Change (Sync if something else changes the tab)
    $scriptScope.MainTabControl.Add_SelectionChanged({
        UpdateSidebarState -scriptScope $scriptScope
    })

    # Initial update
    Initialize-SettingsDashboard -scriptScope $scriptScope
    UpdateSidebarState -scriptScope $scriptScope
    Set-Status -Message "System Ready"
}

function Initialize-SettingsDashboard {
    param($scriptScope)
    
    # 1. Initialize Options (Hide Launcher)
    $opts = Get-GoldenOptions
    if ($scriptScope.HideLauncherToggle) {
        $scriptScope.HideLauncherToggle.IsChecked = $opts.HideLauncherWindow
        $scriptScope.HideLauncherToggle.Add_Click({
            $isChecked = $scriptScope.HideLauncherToggle.IsChecked -eq $true
            Set-GoldenOptions @{ HideLauncherWindow = $isChecked }
            Set-OptionHideLauncher -Hide $isChecked
            Set-Status -Message ("Launcher window " + $(if ($isChecked) { "hidden" } else { "visible" }))
        })
    }
}

function Invoke-Deployment {
    param($scriptScope)

    # 1. Validation
    if (-not (ValidateOtherUsername -scriptScope $scriptScope)) {
        Show-MessageBox -Message "Please enter a valid username." -Title "Invalid Username" -Button 'OK' -Icon 'Warning' | Out-Null
        return
    }

    # 2. Preparation
    ClearParameters
    
    # 3. Collect App Removals
    $selectedApps = @()
    if ($scriptScope.AppSelectionPanel) {
        foreach ($child in $scriptScope.AppSelectionPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                # In this fork, the Tag property usually holds the app ID
                if ($child.Tag) { $selectedApps += $child.Tag }
                elseif ($child.Name -match '^chk_(.+)$') { $selectedApps += $matches[1] }
            }
        }
    }
    
    if ($selectedApps.Count -gt 0) {
        AddParameter 'RemoveApps'
        AddParameter 'Apps' ($selectedApps -join ',')
        
        # App Removal Scope
        if ($scriptScope.AppRemovalScopeCombo) {
            switch ($scriptScope.AppRemovalScopeCombo.SelectedIndex) {
                0 { AddParameter 'AppRemovalTarget' 'AllUsers' }
                1 { AddParameter 'AppRemovalTarget' 'CurrentUser' }
                2 { AddParameter 'AppRemovalTarget' ($scriptScope.OtherUsernameTextBox.Text.Trim()) }
            }
        }
    }

    # 4. Collect Tweaks (from UiControlMappings)
    if ($script:UiControlMappings) {
        foreach ($mappingKey in $script:UiControlMappings.Keys) {
            $control = $scriptScope.window.FindName($mappingKey)
            $mapping = $script:UiControlMappings[$mappingKey]
            $isSelected = $false
            $selectedIndex = 0
            
            if ($control -is [System.Windows.Controls.CheckBox]) {
                $isSelected = $control.IsChecked -eq $true
            }
            elseif ($control -is [System.Windows.Controls.ComboBox]) {
                $isSelected = $control.SelectedIndex -gt 0
                $selectedIndex = $control.SelectedIndex
            }
            
            if ($control -and $isSelected) {
                if ($mapping.Type -eq 'group') {
                    if ($selectedIndex -gt 0 -and $selectedIndex -le $mapping.Values.Count) {
                        $selectedValue = $mapping.Values[$selectedIndex - 1]
                        foreach ($fid in $selectedValue.FeatureIds) { AddParameter $fid }
                    }
                }
                elseif ($mapping.Type -eq 'feature') {
                    AddParameter $mapping.FeatureId
                }
            }
            # Handle revert for 3-state if needed (skipped for now for simplicity as per legacy logic)
        }
    }

    # 5. Collect Performance & System Mods (Settings/Home Tab)
    if ($scriptScope.HomeModUltimatePerf -and $scriptScope.HomeModUltimatePerf.IsChecked) { AddParameter 'AddUltimatePerformancePlan' }
    if ($scriptScope.HomeModHyperVNFS -and $scriptScope.HomeModHyperVNFS.IsChecked) { AddParameter 'InstallFeatures' }
    if ($scriptScope.HomeModClearTemp -and $scriptScope.HomeModClearTemp.IsChecked) { AddParameter 'DeleteTemporaryFiles' }
    if ($scriptScope.HomeModResetUpdates -and $scriptScope.HomeModResetUpdates.IsChecked) { AddParameter 'ResetWindowsUpdate' }
    if ($scriptScope.HomeModCorruptionScan -and $scriptScope.HomeModCorruptionScan.IsChecked) { AddParameter 'SystemCorruptionScan' }
    
    # 6. Global Settings (Restore Point, Explorer, Hide Launcher)
    if ($scriptScope.RestorePointToggle -and $scriptScope.RestorePointToggle.IsChecked) { AddParameter 'CreateRestorePoint' }
    if ($scriptScope.HideLauncherToggle -and $scriptScope.HideLauncherToggle.IsChecked) { AddParameter 'HideLauncher' }
    
    $shouldRestartExplorer = if ($scriptScope.RestartExplorerToggle) { $scriptScope.RestartExplorerToggle.IsChecked -eq $true } else { $true }

    # 7. User Target Mode
    if ($scriptScope.UserSelectionCombo) {
        switch ($scriptScope.UserSelectionCombo.SelectedIndex) {
            1 { AddParameter 'User' ($scriptScope.OtherUsernameTextBox.Text.Trim()) }
            2 { AddParameter 'Sysprep' }
        }
    }

    # 8. Check if anything to do
    $actionableCount = 0
    foreach ($k in $script:Params.Keys) { if ($script:ControlParams -notcontains $k -and $k -ne 'Apps' -and $k -ne 'CreateRestorePoint') { $actionableCount++ } }
    if ($actionableCount -eq 0 -and -not $script:Params.ContainsKey('CreateRestorePoint')) {
        Show-MessageBox -Message "No changes have been selected. Please pick some options before applying." -Title "No Changes" -Button 'OK' -Icon 'Information' | Out-Null
        return
    }

    # 9. Execution
    SaveSettings
    Show-ApplyModal -Owner $scriptScope.window -RestartExplorer $shouldRestartExplorer
    
    # Note: Foundation's Show-ApplyModal might close the window.
    # In this fork, we might want to stay open unless the user closes it.
}

function ValidateOtherUsername {
    param($scriptScope)
    if ($scriptScope.userSelectionCombo.SelectedIndex -ne 1) { return $true }
    $username = $scriptScope.otherUsernameTextBox.Text.Trim()
    $errorBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#c42b1c"))
    $successBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#28a745"))
    if ($username.Length -eq 0) { $scriptScope.usernameValidationMessage.Text = "[X] Please enter a username"; $scriptScope.usernameValidationMessage.Foreground = $errorBrush; return $false }
    if ($username -eq $env:USERNAME) { $scriptScope.usernameValidationMessage.Text = "[X] Cannot enter your own username, use 'Current User' option instead"; $scriptScope.usernameValidationMessage.Foreground = $errorBrush; return $false }
    if (CheckIfUserExists -Username $username) { $scriptScope.usernameValidationMessage.Text = "[OK] User found: $username"; $scriptScope.usernameValidationMessage.Foreground = $successBrush; return $true }
    $scriptScope.usernameValidationMessage.Text = "[X] User not found, please enter a valid username"; $scriptScope.usernameValidationMessage.Foreground = $errorBrush; return $false
}

function GenerateOverview {
    param($scriptScope, $panelIndex = $null)
    $featuresJson = LoadJsonFile -filePath $script:FeaturesFilePath -expectedVersion "1.0"
    $changesList = @()
    
    # 1. App Removal Changes (Panel Index 1)
    if ($null -eq $panelIndex -or $panelIndex -eq 1) {
        $selectedAppsCount = 0
        foreach ($child in $scriptScope.AppSelectionPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) { $selectedAppsCount++ } }
        if ($selectedAppsCount -gt 0) { $changesList += "Remove $selectedAppsCount application(s)" }
        
        # Update sidebar state if we are on the App Removal panel
        if ($scriptScope.MainTabControl.SelectedIndex -eq 1) {
            if ($selectedAppsCount -gt 0) { 
                if ($scriptScope.userSelectionCombo.SelectedIndex -ne 2) { $scriptScope.appRemovalScopeCombo.IsEnabled = $true }; 
                $scriptScope.appRemovalScopeSection.Opacity = 1.0; 
                UpdateAppRemovalScopeDescription -scriptScope $scriptScope 
            }
            else { 
                $scriptScope.appRemovalScopeCombo.IsEnabled = $false; 
                $scriptScope.appRemovalScopeSection.Opacity = 0.5; 
                $scriptScope.appRemovalScopeDescription.Text = "No apps selected for removal." 
            }
        }
    }

    # 2. Tweaks Changes (Panel Index 2)
    if ($null -eq $panelIndex -or $panelIndex -eq 2) {
        if ($script:UiControlMappings) {
            foreach ($mappingKey in $script:UiControlMappings.Keys) {
                $control = $scriptScope.window.FindName($mappingKey); $mapping = $script:UiControlMappings[$mappingKey]; $isSelected = $false; $isRevert = $false
                if ($control -is [System.Windows.Controls.CheckBox]) { if ($mapping.IsSystemApplied) { $isSelected = $control.IsChecked -eq $true; $isRevert = $control.IsChecked -eq $false } else { $isSelected = $control.IsChecked -eq $true } }
                elseif ($control -is [System.Windows.Controls.ComboBox]) { $isSelected = $control.SelectedIndex -gt 0 -and (-not $mapping.IsSystemApplied -or $control.SelectedIndex -ne $mapping.AppliedIndex) }
                if ($control -and $isSelected) {
                    if ($mapping.Type -eq 'group') { $selectedValue = $mapping.Values[$control.SelectedIndex - 1]; foreach ($fid in $selectedValue.FeatureIds) { $feature = $featuresJson.Features | Where-Object { $_.FeatureId -eq $fid }; if ($feature) { $changesList += ($feature.Action + ' ' + $feature.Label) } } }
                    elseif ($mapping.Type -eq 'feature') { $feature = $featuresJson.Features | Where-Object { $_.FeatureId -eq $mapping.FeatureId } | Select-Object -First 1; if ($feature) { $changesList += ($feature.Action + ' ' + $feature.Label) } }
                }
                if ($control -and $isRevert -and $mapping.Type -eq 'feature') { $feature = $featuresJson.Features | Where-Object { $_.FeatureId -eq $mapping.FeatureId } | Select-Object -First 1; if ($feature -and $feature.RegistryUndoKey) { $changesList += ("Revert " + $feature.Action + ' ' + $feature.Label) } }
            }
        }
    }

    # 3. Settings / Home Changes (Panel Index 0 or 3)
    if ($null -eq $panelIndex -or $panelIndex -eq 3 -or $panelIndex -eq 0) {
        if ($scriptScope.HomeModUltimatePerf.IsChecked) { $changesList += "Add Ultimate Performance plan" }
        if ($scriptScope.HomeModHyperVNFS.IsChecked) { $changesList += "Install Hyper-V & NFS Features" }
        if ($scriptScope.HomeModClearTemp.IsChecked) { $changesList += "Clear Temporary Files" }
        if ($scriptScope.HomeModResetUpdates.IsChecked) { $changesList += "Reset Windows Updates" }
        if ($scriptScope.HomeModCorruptionScan.IsChecked) { $changesList += "System Corruption Scan" }
        
        # New Settings tab options
        if ($scriptScope.RestorePointToggle.IsChecked) { $changesList += "Create System Restore Point" }
        if ($scriptScope.RestartExplorerToggle.IsChecked) { $changesList += "Auto-Restart Explorer" }
        if ($scriptScope.HideLauncherToggle.IsChecked) { $changesList += "Hide Launcher Window" }
    }

    return $changesList
}

function ShowChangesOverview {
    param($scriptScope, [bool]$forceAll = $false)
    $currentIndex = $scriptScope.MainTabControl.SelectedIndex
    $totalTabs = $scriptScope.MainTabControl.Items.Count
    
    # If forced or on the settings page, show ALL changes. Otherwise filter to current panel.
    $filterIndex = if ($forceAll -or $currentIndex -eq 3) { $null } else { $currentIndex }
    
    $changesList = GenerateOverview -scriptScope $scriptScope -panelIndex $filterIndex
    if ($changesList.Count -eq 0) { Show-MessageBox -Message 'No changes have been selected for this section.' -Title 'Selected Changes' -Button 'OK' -Icon 'Information'; return }
    $message = ($changesList | ForEach-Object { "$([char]0x2022) $_" }) -join "`n"
    Show-MessageBox -Message $message -Title 'Selected Changes' -Button 'OK' -Icon 'None' -Width 600
}

function UpdateAppRemovalScopeDescription {
    param($scriptScope)
    $selectedItem = $scriptScope.appRemovalScopeCombo.SelectedItem
    if ($selectedItem) {
        switch ($selectedItem.Content) {
            "All users" { $scriptScope.appRemovalScopeDescription.Text = "Apps will be removed for all users and from the Windows image to prevent reinstallation for new users." }
            "Current user only" { $scriptScope.appRemovalScopeDescription.Text = "Apps will only be removed for the current user. Other users and new users will not be affected." }
            "Target user only" { $scriptScope.appRemovalScopeDescription.Text = "Apps will only be removed for the specified target user. Other users and new users will not be affected." }
        }
    }
}

function Show-CliExport {
    param($scriptScope)
    
    $cliCommand = Get-CliExportCommand -scriptScope $scriptScope
    
    $message = "Copy this command to run GoldenImager with your current settings:`n`n$cliCommand"
    $result = Show-MessageBox -Message $message -Title "Export CLI Command" -Button "OK" -Icon "Information" -Width 700
    
    try {
        [System.Windows.Clipboard]::SetText($cliCommand)
        Set-Status -Message "CLI Command copied to clipboard"
    } catch {
        Write-Warning "Failed to copy to clipboard: $_"
    }
}

function Get-CliExportCommand {
    param($scriptScope)
    
    $scriptPath = Join-Path $PSScriptRoot "GoldenImager.ps1"
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`"")
    
    # 1. Apps
    $selectedApps = @()
    if ($scriptScope.AppSelectionPanel) {
        foreach ($child in $scriptScope.AppSelectionPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                if ($child.Name -match '^chk_(.+)$') {
                    $selectedApps += $matches[1]
                }
            }
        }
    }
    if ($selectedApps.Count -gt 0) {
        [void]$sb.Append(" -RemoveApps -Apps `"$($selectedApps -join ',')`"")
        
        # App Removal Scope
        if ($scriptScope.AppRemovalScopeCombo.SelectedIndex -eq 1) {
            [void]$sb.Append(" -AppRemovalTarget `"$env:USERNAME`"")
        }
    }
    
    # 2. Tweaks (from UiControlMappings)
    if ($script:UiControlMappings) {
        foreach ($mappingKey in $script:UiControlMappings.Keys) {
            $control = $scriptScope.window.FindName($mappingKey)
            $mapping = $script:UiControlMappings[$mappingKey]
            
            if ($control -is [System.Windows.Controls.CheckBox] -and $control.IsChecked) {
                if ($mapping.Type -eq 'feature' -and $mapping.FeatureId) {
                    [void]$sb.Append(" -$($mapping.FeatureId)")
                }
            }
        }
    }
    
    # 3. Settings / Options
    if ($scriptScope.RestorePointCheckBox -and $scriptScope.RestorePointCheckBox.IsChecked) { [void]$sb.Append(" -CreateRestorePoint") }
    if ($scriptScope.RestartExplorerCheckBox -and $scriptScope.RestartExplorerCheckBox.IsChecked -eq $false) { [void]$sb.Append(" -NoRestartExplorer") }
    
    # 4. User Target
    if ($scriptScope.UserSelectionCombo) {
        if ($scriptScope.UserSelectionCombo.SelectedIndex -eq 1) {
            $targetUser = $scriptScope.OtherUsernameTextBox.Text.Trim()
            if ($targetUser) { [void]$sb.Append(" -User `"$targetUser`"") }
        } elseif ($scriptScope.UserSelectionCombo.SelectedIndex -eq 2) {
            [void]$sb.Append(" -Sysprep")
        }
    }
    
    return $sb.ToString()
}
