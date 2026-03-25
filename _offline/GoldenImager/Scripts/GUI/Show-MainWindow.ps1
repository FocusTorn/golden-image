function Show-MainWindow {
    $xamlContent = Get-Content -Path $script:MainWindowSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
    try { $window = [System.Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }

    $script:GuiWindow = $window
    $scriptScope = @{ window = $window }
    
    # Auto-find all named elements in XAML and add them to scriptScope for easy access
    $xmlDoc = [xml]$xamlContent
    $nsMgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
    $nsMgr.AddNamespace("x", "http://schemas.microsoft.com/winfx/2006/xaml")
    
    # Use GetAttribute to safely retrieve Name or x:Name
    $xmlDoc.SelectNodes("//*[@Name]|//*[@x:Name]", $nsMgr) | ForEach-Object {
        $name = $_.GetAttribute('Name')
        if ([string]::IsNullOrEmpty($name)) {
            $name = $_.GetAttribute('Name', 'http://schemas.microsoft.com/winfx/2006/xaml')
        }
        if ($name) {
            $element = $window.FindName($name)
            if ($null -ne $element) {
                $scriptScope[$name] = $element
            }
        }
    }

    # Import GUI parts
    . "$PSScriptRoot/Parts/UiSetup.ps1"
    . "$PSScriptRoot/Parts/WindowManagement.ps1"
    . "$PSScriptRoot/Parts/TitleBarAndMenu.ps1"
    . "$PSScriptRoot/Parts/HomeTab.ps1"
    . "$PSScriptRoot/Parts/AppRemovalPanel.ps1"
    . "$PSScriptRoot/Parts/TweaksPanel.ps1"
    . "$PSScriptRoot/Parts/SearchLogic.ps1"
    . "$PSScriptRoot/Parts/NavigationAndWizard.ps1"
    . "$PSScriptRoot/Parts/AppProfileManagement.ps1"

    # Initial UI setup
    $usesDarkMode = GetSystemUsesDarkMode
    SetWindowThemeResources -window $window -usesDarkMode $usesDarkMode
    Apply-TypographyResources -window $window
    
    # Set window icon
    $hLarge = [IntPtr]::Zero; $hSmall = [IntPtr]::Zero
    if ([Shell32_Extract]::ExtractIconEx($script:TaskbarIcon.DllPath, $script:TaskbarIcon.IconIndex, [ref]$hLarge, [ref]$hSmall, 1) -gt 0) {
        $window.Icon = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($hLarge, [System.Windows.Int32Rect]::Empty, [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
    }

    # Load window bounds
    $windowBoundsPath = Join-Path $PSScriptRoot "../../Config/WindowBounds.json"
    if (Test-Path $windowBoundsPath) {
        try {
            $bounds = Get-Content $windowBoundsPath -Raw | ConvertFrom-Json
            if ($bounds.Left -ge 0) { $window.Left = $bounds.Left }
            if ($bounds.Top -ge 0) { $window.Top = $bounds.Top }
            if ($bounds.Width -gt 0) { $window.Width = $bounds.Width }
            if ($bounds.Height -gt 0) { $window.Height = $bounds.Height }
        } catch {}
    }

    # Initialize components
    Initialize-WindowResize -window $window
    Initialize-WindowClosing -window $window -windowBoundsPath $windowBoundsPath
    Initialize-TitleBarAndMenu -scriptScope $scriptScope -window $window -usesDarkMode $usesDarkMode
    Initialize-AppSearch -scriptScope $scriptScope -window $window
    Initialize-TweakSearch -scriptScope $scriptScope -window $window

    # Global variables for sorting
    $script:SortColumn = 'Name'; $script:SortAscending = $true
    $script:HeaderColName = $scriptScope.HeaderColName; $script:HeaderColDesc = $scriptScope.HeaderColDesc; $script:HeaderColId = $scriptScope.HeaderColId

    # Event Handlers
    if ($scriptScope.CloseBtn) { $scriptScope.CloseBtn.Add_Click({ $window.Close() }) }
    if ($scriptScope.MinimizeBtn) { $scriptScope.MinimizeBtn.Add_Click({ $window.WindowState = 'Minimized' }) }
    if ($scriptScope.MaximizeBtn) { $scriptScope.MaximizeBtn.Add_Click({ if ($window.WindowState -eq 'Maximized') { $window.WindowState = 'Normal' } else { $window.WindowState = 'Maximized' } }) }
    
    if ($scriptScope.HeaderColName) { $scriptScope.HeaderColName.Add_MouseLeftButtonDown({ SetSortColumn -column 'Name' -scriptScope $scriptScope }) }
    if ($scriptScope.HeaderColDesc) { $scriptScope.HeaderColDesc.Add_MouseLeftButtonDown({ SetSortColumn -column 'Description' -scriptScope $scriptScope }) }
    if ($scriptScope.HeaderColId) { $scriptScope.HeaderColId.Add_MouseLeftButtonDown({ SetSortColumn -column 'AppId' -scriptScope $scriptScope }) }

    if ($scriptScope.QuickSelectSafe) { $scriptScope.QuickSelectSafe.Add_Click({ foreach ($child in $scriptScope.AppSelectionPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.Visibility -eq 'Visible') { $dot = $child.Content.Children[0]; if ($dot.Fill.ToString() -eq '#FF4CAF50') { $child.IsChecked = $true } } }; UpdateAppSelectionStatus -scriptScope $scriptScope }) }
    if ($scriptScope.QuickSelectNone) { $scriptScope.QuickSelectNone.Add_Click({ foreach ($child in $scriptScope.AppSelectionPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.Visibility -eq 'Visible') { $child.IsChecked = $false } }; UpdateAppSelectionStatus -scriptScope $scriptScope }) }
    if ($scriptScope.QuickSelectAll) { $scriptScope.QuickSelectAll.Add_Click({ foreach ($child in $scriptScope.AppSelectionPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.Visibility -eq 'Visible') { $child.IsChecked = $true } }; UpdateAppSelectionStatus -scriptScope $scriptScope }) }
    if ($scriptScope.QuickSelectDefault) { $scriptScope.QuickSelectDefault.Add_Click({ foreach ($child in $scriptScope.AppSelectionPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.Visibility -eq 'Visible') { $child.IsChecked = $child.SelectedByDefault -eq $true } }; UpdateAppSelectionStatus -scriptScope $scriptScope }) }

    if ($scriptScope.OnlyInstalledAppsBox) {
        $scriptScope.OnlyInstalledAppsBox.Add_Checked({ $scriptScope.AppSelectionPanel.Children.Clear(); $scriptScope.LoadingAppsIndicator.Visibility = 'Visible'; LoadAppsWithList -scriptScope $scriptScope -window $window })
        $scriptScope.OnlyInstalledAppsBox.Add_Unchecked({ $scriptScope.AppSelectionPanel.Children.Clear(); $scriptScope.LoadingAppsIndicator.Visibility = 'Visible'; LoadAppsWithList -scriptScope $scriptScope -window $window })
    }
    if ($scriptScope.ShowAllNotListedBox) { $scriptScope.ShowAllNotListedBox.Add_Checked({ $scriptScope.AppSelectionPanel.Children.Clear(); $scriptScope.LoadingAppsIndicator.Visibility = 'Visible'; LoadAppsWithList -scriptScope $scriptScope -window $window }) }
    if ($scriptScope.ShowProvisionedNotListedBox) { $scriptScope.ShowProvisionedNotListedBox.Add_Checked({ $scriptScope.AppSelectionPanel.Children.Clear(); $scriptScope.LoadingAppsIndicator.Visibility = 'Visible'; LoadAppsWithList -scriptScope $scriptScope -window $window }) }
    if ($scriptScope.ShowUserNotListedBox) { $scriptScope.ShowUserNotListedBox.Add_Checked({ $scriptScope.AppSelectionPanel.Children.Clear(); $scriptScope.LoadingAppsIndicator.Visibility = 'Visible'; LoadAppsWithList -scriptScope $scriptScope -window $window }) }

    if ($scriptScope.AppProfileCombo) {
        $scriptScope.AppProfileCombo.Add_SelectionChanged({
            if ($scriptScope.AppProfileCombo.SelectedIndex -le 0) { return }
            $profileName = $scriptScope.AppProfileCombo.SelectedItem.Content
            $ids = Import-AppProfile -ProfileName $profileName
            Set-AppProfileToUi -AppIds $ids -Replace $true -scriptScope $scriptScope
        })
    }
    if ($scriptScope.AppProfileSaveBtn) {
        $scriptScope.AppProfileSaveBtn.Add_Click({
            $selected = @(); foreach ($child in $scriptScope.AppSelectionPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) { $selected += $child.Tag } }
            if ($selected.Count -eq 0) { Show-MessageBox -Message "No apps selected to save in profile." -Title "Save Profile" -Button 'OK' -Icon 'Warning'; return }
            $name = Show-InputDialog -Prompt "Enter profile name:" -Title "Save App Profile" -window $window
            if ($name) { Save-AppProfile -ProfileName $name -AppIds $selected; Update-AppProfileCombo -scriptScope $scriptScope; Show-MessageBox -Message "Profile '$name' saved." -Title "Save Profile" -Button 'OK' -Icon 'Information' }
        })
    }

    if ($scriptScope.UserSelectionCombo) {
        $scriptScope.UserSelectionCombo.Add_SelectionChanged({
            if ($scriptScope.OtherUserPanel) { $scriptScope.OtherUserPanel.Visibility = if ($scriptScope.UserSelectionCombo.SelectedIndex -eq 1) { 'Visible' } else { 'Collapsed' } }
            # Note: Sysprep warning is no longer in this XAML version, or named differently
            if ($scriptScope.UserSelectionCombo.SelectedIndex -eq 2) { $scriptScope.AppRemovalScopeCombo.SelectedIndex = 0; $scriptScope.AppRemovalScopeCombo.IsEnabled = $false } else { $scriptScope.AppRemovalScopeCombo.IsEnabled = $true }
            UpdateAppRemovalScopeDescription -scriptScope $scriptScope
        })
    }
    if ($scriptScope.AppRemovalScopeCombo) {
        $scriptScope.AppRemovalScopeCombo.Add_SelectionChanged({ UpdateAppRemovalScopeDescription -scriptScope $scriptScope })
    }

    if ($scriptScope.PreviousBtn) { $scriptScope.PreviousBtn.Add_Click({ if ($scriptScope.MainTabControl.SelectedIndex -gt 0) { $scriptScope.MainTabControl.SelectedIndex-- } }) }
    if ($scriptScope.NextBtn) {
        $scriptScope.NextBtn.Add_Click({
            if ($scriptScope.MainTabControl.SelectedIndex -eq 0) { if (-not (ValidateOtherUsername -scriptScope $scriptScope)) { return } }
            if ($scriptScope.MainTabControl.SelectedIndex -lt $scriptScope.MainTabControl.Items.Count - 1) { $scriptScope.MainTabControl.SelectedIndex++ }
        })
    }
    if ($scriptScope.MainTabControl) {
        $scriptScope.MainTabControl.Add_SelectionChanged({ if ($_.OriginalSource -eq $scriptScope.MainTabControl) { UpdateNavigationButtons -scriptScope $scriptScope } })
    }
    # Review & Apply Handlers
    $applyLogic = {
        if (-not (ValidateOtherUsername -scriptScope $scriptScope)) { $scriptScope.MainTabControl.SelectedIndex = 0; return }
        $changes = GenerateOverview -scriptScope $scriptScope
        if ($changes.Count -eq 0) {
            # Check if any Home tab modifications are selected
            $homeModSelected = $scriptScope.HomeModUltimatePerf.IsChecked -or $scriptScope.HomeModHyperVNFS.IsChecked -or 
                               $scriptScope.HomeModClearTemp.IsChecked -or $scriptScope.HomeModResetUpdates.IsChecked -or 
                               $scriptScope.HomeModCorruptionScan.IsChecked
            if (-not $homeModSelected) {
                Show-MessageBox -Message "No changes selected to apply." -Title "Apply Changes" -Button 'OK' -Icon 'Warning'; return 
            }
        }
        
        $script:Params = @{}
        foreach ($mappingKey in $script:UiControlMappings.Keys) {
            $control = $window.FindName($mappingKey); $mapping = $script:UiControlMappings[$mappingKey]
            if ($control -is [System.Windows.Controls.CheckBox]) { if ($mapping.IsSystemApplied) { if ($control.IsChecked -eq $true) { AddParameter -parameterName $mapping.FeatureId } elseif ($control.IsChecked -eq $false) { AddParameter -parameterName "Revert_$($mapping.FeatureId)" } } else { if ($control.IsChecked -eq $true) { AddParameter -parameterName $mapping.FeatureId } } }
            elseif ($control -is [System.Windows.Controls.ComboBox]) { if ($control.SelectedIndex -gt 0) { if ($mapping.Type -eq 'group') { $val = $mapping.Values[$control.SelectedIndex - 1]; foreach ($fid in $val.FeatureIds) { AddParameter -parameterName $fid } } elseif ($mapping.Type -eq 'feature') { AddParameter -parameterName $mapping.FeatureId } } }
        }
        
        # Handle Home Tab System Modifications
        if ($scriptScope.HomeModUltimatePerf.IsChecked) { AddParameter -parameterName "AddUltimatePerformancePlan" }
        if ($scriptScope.HomeModHyperVNFS.IsChecked) { AddParameter -parameterName "InstallFeatures" }
        if ($scriptScope.HomeModClearTemp.IsChecked) { AddParameter -parameterName "DeleteTemporaryFiles" }
        if ($scriptScope.HomeModResetUpdates.IsChecked) { AddParameter -parameterName "ResetWindowsUpdate" }
        if ($scriptScope.HomeModCorruptionScan.IsChecked) { AddParameter -parameterName "SystemCorruptionScan" }

        $selectedApps = @(); foreach ($child in $scriptScope.AppSelectionPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) { $selectedApps += $child.Tag } }
        if ($selectedApps.Count -gt 0) { AddParameter -parameterName "RemoveApps"; AddParameter -parameterName "Apps" -value ($selectedApps -join ',') }
        if ($scriptScope.RestorePointCheckBox.IsChecked) { AddParameter -parameterName "CreateRestorePoint" }
        if ($scriptScope.UserSelectionCombo.SelectedIndex -eq 1) { AddParameter -parameterName "User" -value ($scriptScope.OtherUsernameTextBox.Text.Trim()) }
        elseif ($scriptScope.UserSelectionCombo.SelectedIndex -eq 2) { AddParameter -parameterName "Sysprep" }
        if ($selectedApps.Count -gt 0) { $scopeContent = $scriptScope.AppRemovalScopeCombo.SelectedItem.Content; if ($scopeContent -eq 'Current user only') { AddParameter -parameterName 'AppRemovalTarget' -value 'CurrentUser' } elseif ($scopeContent -eq 'Target user only') { AddParameter -parameterName 'AppRemovalTarget' -value ($scriptScope.OtherUsernameTextBox.Text.Trim()) } else { AddParameter -parameterName 'AppRemovalTarget' -value 'AllUsers' } }
        
        $window.Hide()
        Show-ApplyModal -ParentWindow $window
        $window.Close()
    }

    if ($scriptScope.ReviewChangesBtn) { $scriptScope.ReviewChangesBtn.Add_Click({ ShowChangesOverview -scriptScope $scriptScope }) }
    if ($scriptScope.AppRemovalReviewBtn) { $scriptScope.AppRemovalReviewBtn.Add_Click({ ShowChangesOverview -scriptScope $scriptScope }) }
    if ($scriptScope.TweaksReviewBtn) { $scriptScope.TweaksReviewBtn.Add_Click({ ShowChangesOverview -scriptScope $scriptScope }) }

    if ($scriptScope.DeploymentApplyBtn) { $scriptScope.DeploymentApplyBtn.Add_Click($applyLogic) }
    if ($scriptScope.AppRemovalApplyBtn) { $scriptScope.AppRemovalApplyBtn.Add_Click($applyLogic) }
    if ($scriptScope.TweaksApplyBtn) { $scriptScope.TweaksApplyBtn.Add_Click($applyLogic) }

    if ($scriptScope.ToggleUnsafeAppsBtn) {
        $scriptScope.ToggleUnsafeAppsBtn.Add_Click({ Toggle-UnsafeApps -scriptScope $scriptScope })
    }

    if ($scriptScope.DeploymentExportCliBtn) {
        $scriptScope.DeploymentExportCliBtn.Add_Click({
            Show-MessageBox -Message "CLI Export functionality not fully implemented in this prototype yet." -Title "Export CLI" -Button 'OK' -Icon 'Information'
        })
    }

    function Get-CurrentTweakSettingsFromUi {
        $settings = @(); foreach ($mappingKey in $script:UiControlMappings.Keys) {
            $control = $window.FindName($mappingKey); $mapping = $script:UiControlMappings[$mappingKey]
            if ($control -is [System.Windows.Controls.CheckBox]) { if ($control.IsChecked -eq $true) { $settings += @{ Name = $mapping.FeatureId; Value = $true } } }
            elseif ($control -is [System.Windows.Controls.ComboBox]) { if ($control.SelectedIndex -gt 0) { if ($mapping.Type -eq 'group') { $settings += @{ Name = "Group_$($mapping.Label)"; Value = $control.SelectedIndex } } elseif ($mapping.Type -eq 'feature') { $settings += @{ Name = $mapping.FeatureId; Value = $control.SelectedIndex } } } }
        }
        return @{ Version = $script:Version; Settings = $settings }
    }

    $window.Add_SourceInitialized({ [PSAppID]::SetAppIdForWindow((New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle, "GoldenImager.GUI") })
    $window.Add_ContentRendered({
        DoEvents
        Initialize-HomeTab -scriptScope $scriptScope
        BuildDynamicTweaks -window $window -WinVersion $WinVersion -scriptScope $scriptScope
        Update-AppProfileCombo -scriptScope $scriptScope
        LoadAppsWithList -scriptScope $scriptScope -window $window
        UpdateNavigationButtons -scriptScope $scriptScope
    })

    $null = $window.ShowDialog()
}
