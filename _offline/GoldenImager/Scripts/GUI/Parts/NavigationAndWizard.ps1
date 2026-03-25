function UpdateNavigationButtons {
    param($scriptScope)
    $tabControl = $scriptScope.MainTabControl
    if ($null -eq $tabControl) { return }
    
    $currentIndex = $tabControl.SelectedIndex
    $totalTabs = $tabControl.Items.Count
    $homeIndex = 0
    $overviewIndex = $totalTabs - 1
    
    # Update Back/Next buttons at the bottom
    if ($null -ne $scriptScope.NextBtn -and $null -ne $scriptScope.PreviousBtn) {
        if ($currentIndex -eq $homeIndex) {
            $scriptScope.NextBtn.Visibility = 'Visible'
            $scriptScope.PreviousBtn.Visibility = 'Collapsed'
        }
        elseif ($currentIndex -eq $overviewIndex) {
            $scriptScope.NextBtn.Visibility = 'Collapsed'
            $scriptScope.PreviousBtn.Visibility = 'Visible'
        }
        else {
            $scriptScope.NextBtn.Visibility = 'Visible'
            $scriptScope.PreviousBtn.Visibility = 'Visible'
        }
    }
    
    $blueColor = "#0067c0"
    $greyColor = "#808080"
    
    # Update progress indicators (illumination)
    if ($null -ne $scriptScope.ProgressIndicator1) { $scriptScope.ProgressIndicator1.Fill = $(if ($currentIndex -eq 0) { $blueColor } else { $greyColor }) }
    if ($null -ne $scriptScope.ProgressIndicator2) { $scriptScope.ProgressIndicator2.Fill = $(if ($currentIndex -eq 1) { $blueColor } else { $greyColor }) }
    if ($null -ne $scriptScope.ProgressIndicator3) { $scriptScope.ProgressIndicator3.Fill = $(if ($currentIndex -eq 2) { $blueColor } else { $greyColor }) }
    if ($null -ne $scriptScope.ProgressIndicator4) { $scriptScope.ProgressIndicator4.Fill = $(if ($currentIndex -eq 3) { $blueColor } else { $greyColor }) }
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

    # 3. Deployment / Home Changes (Panel Index 0 or 3)
    if ($null -eq $panelIndex -or $panelIndex -eq 3 -or $panelIndex -eq 0) {
        if ($scriptScope.HomeModUltimatePerf.IsChecked) { $changesList += "Add Ultimate Performance plan" }
        if ($scriptScope.HomeModHyperVNFS.IsChecked) { $changesList += "Install Hyper-V & NFS Features" }
        if ($scriptScope.HomeModClearTemp.IsChecked) { $changesList += "Clear Temporary Files" }
        if ($scriptScope.HomeModResetUpdates.IsChecked) { $changesList += "Reset Windows Updates" }
        if ($scriptScope.HomeModCorruptionScan.IsChecked) { $changesList += "System Corruption Scan" }
        
        if ($null -eq $panelIndex -or $panelIndex -eq 3) {
            if ($scriptScope.RestorePointCheckBox.IsChecked) { $changesList += "Create System Restore Point" }
            if ($scriptScope.RestartExplorerCheckBox.IsChecked) { $changesList += "Restart Windows Explorer" }
        }
    }

    return $changesList
}

function ShowChangesOverview {
    param($scriptScope)
    $currentIndex = $scriptScope.MainTabControl.SelectedIndex
    $totalTabs = $scriptScope.MainTabControl.Items.Count
    
    # If not the last panel, filter to current panel's changes
    $filterIndex = if ($currentIndex -lt $totalTabs - 1) { $currentIndex } else { $null }
    
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
