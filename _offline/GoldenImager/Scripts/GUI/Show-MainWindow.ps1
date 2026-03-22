function Show-MainWindow {
    $xaml = Get-Content -Path $script:MainWindowSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try { $window = [System.Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }

    $script:GuiWindow = $window
    $scriptScope = @{ window = $window }
    
    # Auto-find all named elements in XAML and add them to scriptScope for easy access
    $xaml.SelectNodes("//*[@Name]|//*[@x:Name]") | ForEach-Object {
        $name = $_.Attributes['Name'].Value
        if (-not $name) { $name = $_.Attributes['x:Name'].Value }
        if ($name) { $scriptScope[$name] = $window.FindName($name) }
    }

    # Import GUI parts
    . "$PSScriptRoot/Parts/UiSetup.ps1"
    . "$PSScriptRoot/Parts/WindowManagement.ps1"
    . "$PSScriptRoot/Parts/TitleBarAndMenu.ps1"
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
    $script:HeaderColName = $scriptScope.headerColName; $script:HeaderColDesc = $scriptScope.headerColDesc; $script:HeaderColId = $scriptScope.headerColId

    # Event Handlers
    $scriptScope.closeBtn.Add_Click({ $window.Close() })
    $scriptScope.minimizeBtn.Add_Click({ $window.WindowState = 'Minimized' })
    $scriptScope.maximizeBtn.Add_Click({ if ($window.WindowState -eq 'Maximized') { $window.WindowState = 'Normal' } else { $window.WindowState = 'Maximized' } })
    
    $scriptScope.headerColName.Add_MouseLeftButtonDown({ SetSortColumn -column 'Name' -scriptScope $scriptScope })
    $scriptScope.headerColDesc.Add_MouseLeftButtonDown({ SetSortColumn -column 'Description' -scriptScope $scriptScope })
    $scriptScope.headerColId.Add_MouseLeftButtonDown({ SetSortColumn -column 'AppId' -scriptScope $scriptScope })

    $scriptScope.quickSelectSafe.Add_Click({ foreach ($child in $scriptScope.appsPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.Visibility -eq 'Visible') { $dot = $child.Content.Children[0]; if ($dot.Fill.ToString() -eq '#FF4CAF50') { $child.IsChecked = $true } } }; UpdateAppSelectionStatus -scriptScope $scriptScope })
    $scriptScope.quickSelectNone.Add_Click({ foreach ($child in $scriptScope.appsPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.Visibility -eq 'Visible') { $child.IsChecked = $false } }; UpdateAppSelectionStatus -scriptScope $scriptScope })
    $scriptScope.quickSelectAll.Add_Click({ foreach ($child in $scriptScope.appsPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.Visibility -eq 'Visible') { $child.IsChecked = $true } }; UpdateAppSelectionStatus -scriptScope $scriptScope })
    $scriptScope.quickSelectDefault.Add_Click({ foreach ($child in $scriptScope.appsPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.Visibility -eq 'Visible') { $child.IsChecked = $child.SelectedByDefault -eq $true } }; UpdateAppSelectionStatus -scriptScope $scriptScope })

    $scriptScope.onlyInstalledAppsBox.Add_Checked({ $scriptScope.appsPanel.Children.Clear(); $scriptScope.loadingAppsIndicator.Visibility = 'Visible'; LoadAppsWithList -scriptScope $scriptScope -window $window })
    $scriptScope.onlyInstalledAppsBox.Add_Unchecked({ $scriptScope.appsPanel.Children.Clear(); $scriptScope.loadingAppsIndicator.Visibility = 'Visible'; LoadAppsWithList -scriptScope $scriptScope -window $window })
    $scriptScope.showAllNotListedBox.Add_Checked({ $scriptScope.appsPanel.Children.Clear(); $scriptScope.loadingAppsIndicator.Visibility = 'Visible'; LoadAppsWithList -scriptScope $scriptScope -window $window })
    $scriptScope.showProvisionedNotListedBox.Add_Checked({ $scriptScope.appsPanel.Children.Clear(); $scriptScope.loadingAppsIndicator.Visibility = 'Visible'; LoadAppsWithList -scriptScope $scriptScope -window $window })
    $scriptScope.showUserNotListedBox.Add_Checked({ $scriptScope.appsPanel.Children.Clear(); $scriptScope.loadingAppsIndicator.Visibility = 'Visible'; LoadAppsWithList -scriptScope $scriptScope -window $window })

    $scriptScope.appProfileCombo.Add_SelectionChanged({
        if ($scriptScope.appProfileCombo.SelectedIndex -le 0) { return }
        $profileName = $scriptScope.appProfileCombo.SelectedItem.Content
        $ids = Import-AppProfile -ProfileName $profileName
        Set-AppProfileToUi -AppIds $ids -Replace $true -scriptScope $scriptScope
    })
    $scriptScope.saveAppProfileBtn.Add_Click({
        $selected = @(); foreach ($child in $scriptScope.appsPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) { $selected += $child.Tag } }
        if ($selected.Count -eq 0) { Show-MessageBox -Message "No apps selected to save in profile." -Title "Save Profile" -Button 'OK' -Icon 'Warning'; return }
        $name = Show-InputDialog -Prompt "Enter profile name:" -Title "Save App Profile" -window $window
        if ($name) { Save-AppProfile -ProfileName $name -AppIds $selected; Update-AppProfileCombo -scriptScope $scriptScope; Show-MessageBox -Message "Profile '$name' saved." -Title "Save Profile" -Button 'OK' -Icon 'Information' }
    })

    $scriptScope.userSelectionCombo.Add_SelectionChanged({
        $scriptScope.otherUsernameGroup.Visibility = if ($scriptScope.userSelectionCombo.SelectedIndex -eq 1) { 'Visible' } else { 'Collapsed' }
        $scriptScope.sysprepWarning.Visibility = if ($scriptScope.userSelectionCombo.SelectedIndex -eq 2) { 'Visible' } else { 'Collapsed' }
        if ($scriptScope.userSelectionCombo.SelectedIndex -eq 2) { $scriptScope.appRemovalScopeCombo.SelectedIndex = 0; $scriptScope.appRemovalScopeCombo.IsEnabled = $false } else { $scriptScope.appRemovalScopeCombo.IsEnabled = $true }
        UpdateAppRemovalScopeDescription -scriptScope $scriptScope
    })
    $scriptScope.appRemovalScopeCombo.Add_SelectionChanged({ UpdateAppRemovalScopeDescription -scriptScope $scriptScope })

    $scriptScope.previousBtn.Add_Click({ if ($scriptScope.tabControl.SelectedIndex -gt 0) { $scriptScope.tabControl.SelectedIndex-- } })
    $scriptScope.nextBtn.Add_Click({
        if ($scriptScope.tabControl.SelectedIndex -eq 0) { if (-not (ValidateOtherUsername -scriptScope $scriptScope)) { return } }
        if ($scriptScope.tabControl.SelectedIndex -lt $scriptScope.tabControl.Items.Count - 1) { $scriptScope.tabControl.SelectedIndex++ }
    })
    $scriptScope.tabControl.Add_SelectionChanged({ if ($_.OriginalSource -eq $scriptScope.tabControl) { UpdateNavigationButtons -scriptScope $scriptScope } })
    $scriptScope.showOverviewBtn.Add_Click({ ShowChangesOverview -scriptScope $scriptScope })

    $scriptScope.applyBtn.Add_Click({
        if (-not (ValidateOtherUsername -scriptScope $scriptScope)) { $scriptScope.tabControl.SelectedIndex = 0; return }
        $changes = GenerateOverview -scriptScope $scriptScope
        if ($changes.Count -eq 0) { Show-MessageBox -Message "No changes selected to apply." -Title "Apply Changes" -Button 'OK' -Icon 'Warning'; return }
        
        $script:Params = @{}
        foreach ($mappingKey in $script:UiControlMappings.Keys) {
            $control = $window.FindName($mappingKey); $mapping = $script:UiControlMappings[$mappingKey]
            if ($control -is [System.Windows.Controls.CheckBox]) { if ($mapping.IsSystemApplied) { if ($control.IsChecked -eq $true) { AddParameter -parameterName $mapping.FeatureId } elseif ($control.IsChecked -eq $false) { AddParameter -parameterName "Revert_$($mapping.FeatureId)" } } else { if ($control.IsChecked -eq $true) { AddParameter -parameterName $mapping.FeatureId } } }
            elseif ($control -is [System.Windows.Controls.ComboBox]) { if ($control.SelectedIndex -gt 0) { if ($mapping.Type -eq 'group') { $val = $mapping.Values[$control.SelectedIndex - 1]; foreach ($fid in $val.FeatureIds) { AddParameter -parameterName $fid } } elseif ($mapping.Type -eq 'feature') { AddParameter -parameterName $mapping.FeatureId } } }
        }
        $selectedApps = @(); foreach ($child in $scriptScope.appsPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) { $selectedApps += $child.Tag } }
        if ($selectedApps.Count -gt 0) { AddParameter -parameterName "RemoveApps"; AddParameter -parameterName "Apps" -value ($selectedApps -join ',') }
        if ($scriptScope.restorePointCheckBox.IsChecked) { AddParameter -parameterName "CreateRestorePoint" }
        if ($scriptScope.userSelectionCombo.SelectedIndex -eq 1) { AddParameter -parameterName "User" -value ($scriptScope.otherUsernameTextBox.Text.Trim()) }
        elseif ($scriptScope.userSelectionCombo.SelectedIndex -eq 2) { AddParameter -parameterName "Sysprep" }
        if ($selectedApps.Count -gt 0) { $scopeContent = $scriptScope.appRemovalScopeCombo.SelectedItem.Content; if ($scopeContent -eq 'Current user only') { AddParameter -parameterName 'AppRemovalTarget' -value 'CurrentUser' } elseif ($scopeContent -eq 'Target user only') { AddParameter -parameterName 'AppRemovalTarget' -value ($scriptScope.otherUsernameTextBox.Text.Trim()) } else { AddParameter -parameterName 'AppRemovalTarget' -value 'AllUsers' } }
        
        $window.Hide()
        Show-ApplyModal -ParentWindow $window
        $window.Close()
    })

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
        BuildDynamicTweaks -window $window -WinVersion $WinVersion
        Update-AppProfileCombo -scriptScope $scriptScope
        LoadAppsWithList -scriptScope $scriptScope -window $window
        UpdateNavigationButtons -scriptScope $scriptScope
    })

    $null = $window.ShowDialog()
}
