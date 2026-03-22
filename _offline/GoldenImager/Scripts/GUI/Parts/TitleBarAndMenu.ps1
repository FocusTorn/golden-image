function Initialize-TitleBarAndMenu {
    param($scriptScope, $window, $usesDarkMode)

    $scriptScope.titleBar.Add_MouseLeftButtonDown({ if ($_.OriginalSource -is [System.Windows.Controls.Grid] -or $_.OriginalSource -is [System.Windows.Controls.Border] -or $_.OriginalSource -is [System.Windows.Controls.TextBlock]) { $window.DragMove() } })
    $scriptScope.kofiBtn.Add_Click({ Start-Process "https://ko-fi.com/raphire" })
    $scriptScope.menuBtn.Add_Click({ $scriptScope.menuBtn.ContextMenu.PlacementTarget = $scriptScope.menuBtn; $scriptScope.menuBtn.ContextMenu.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Bottom; $scriptScope.menuBtn.ContextMenu.IsOpen = $true })
    $scriptScope.menuDocumentation.Add_Click({ Start-Process "https://github.com/Raphire/Win11Debloat/wiki" })
    $scriptScope.menuReportBug.Add_Click({ Start-Process "https://github.com/Raphire/Win11Debloat/issues" })
    $scriptScope.menuLogs.Add_Click({ $logsFolder = Join-Path $PSScriptRoot "../../Logs"; if (Test-Path $logsFolder) { Start-Process "explorer.exe" -ArgumentList $logsFolder } else { Show-MessageBox -Message "No logs folder found at: $logsFolder" -Title "Logs" -Button 'OK' -Icon 'Information' } })
    $scriptScope.menuAbout.Add_Click({ Show-AboutDialog -Owner $window })
    $scriptScope.menuOptions.Add_Click({ Show-OptionsDialog -Owner $window -usesDarkMode $usesDarkMode })

    $scriptScope.menuExportSettings.Add_Click({
        $settingsJson = Get-CurrentTweakSettingsFromUi
        $selectedApps = @(); foreach ($child in $scriptScope.appsPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) { $selectedApps += $child.Tag } }
        if ($selectedApps.Count -gt 0) { $settingsJson.Settings += @{ Name = 'RemoveApps'; Value = $true }; $settingsJson.Settings += @{ Name = 'Apps'; Value = ($selectedApps -join ',') } }
        if ($scriptScope.restorePointCheckBox -and $scriptScope.restorePointCheckBox.IsChecked) { $settingsJson.Settings += @{ Name = 'CreateRestorePoint'; Value = $true } }
        if ($scriptScope.userSelectionCombo.SelectedIndex -eq 1) { if ($scriptScope.otherUsernameTextBox -and $scriptScope.otherUsernameTextBox.Text.Trim()) { $settingsJson.Settings += @{ Name = 'User'; Value = $scriptScope.otherUsernameTextBox.Text.Trim() } } }
        if ($scriptScope.userSelectionCombo.SelectedIndex -eq 2) { $settingsJson.Settings += @{ Name = 'Sysprep'; Value = $true } }
        if ($scriptScope.appRemovalScopeCombo -and $selectedApps.Count -gt 0) { $scopeContent = if ($scriptScope.appRemovalScopeCombo.SelectedItem) { $scriptScope.appRemovalScopeCombo.SelectedItem.Content } else { $null }; if ($scopeContent -eq 'Current user only') { $settingsJson.Settings += @{ Name = 'AppRemovalTarget'; Value = 'CurrentUser' } } elseif ($scopeContent -eq 'Target user only') { $settingsJson.Settings += @{ Name = 'AppRemovalTarget'; Value = ($scriptScope.otherUsernameTextBox.Text.Trim()) } } else { $settingsJson.Settings += @{ Name = 'AppRemovalTarget'; Value = 'AllUsers' } } }
        $dlg = New-Object Microsoft.Win32.SaveFileDialog; $dlg.Filter = 'JSON files (*.json)|*.json|All files (*.*)|*.*'; $dlg.DefaultExt = 'json'; $dlg.FileName = "GoldenImager-Settings-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        if ($dlg.ShowDialog() -eq $true) { try { $settingsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $dlg.FileName -Encoding UTF8; Show-MessageBox -Message "Settings exported to:`n$($dlg.FileName)" -Title "Export" -Button 'OK' -Icon 'Information' | Out-Null } catch { Show-MessageBox -Message "Failed to export: $_" -Title "Export Error" -Button 'OK' -Icon 'Warning' | Out-Null } }
    })

    $scriptScope.menuImportSettings.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog; $dlg.Filter = 'JSON files (*.json)|*.json|All files (*.*)|*.*'
        if ($dlg.ShowDialog() -eq $true) {
            try {
                $imported = Get-Content -Path $dlg.FileName -Raw | ConvertFrom-Json
                if (-not $imported.Settings) { Show-MessageBox -Message "Invalid settings file format." -Title "Import" -Button 'OK' -Icon 'Warning' | Out-Null; return }
                $settingsObj = @{ Version = $imported.Version; Settings = @() }; foreach ($s in $imported.Settings) { $settingsObj.Settings += @{ Name = $s.Name; Value = $s.Value } }
                ApplySettingsToUiControls -window $window -settingsJson $settingsObj -uiControlMappings $script:UiControlMappings
                if ($settingsObj.Settings | Where-Object { $_.Name -eq 'Apps' }) { $appsSetting = $settingsObj.Settings | Where-Object { $_.Name -eq 'Apps' } | Select-Object -First 1; $appIds = $appsSetting.Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }; foreach ($child in $scriptScope.appsPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and $child.Tag) { $child.IsChecked = $appIds -contains $child.Tag } } }
                if ($scriptScope.restorePointCheckBox -and ($settingsObj.Settings | Where-Object { $_.Name -eq 'CreateRestorePoint' })) { $scriptScope.restorePointCheckBox.IsChecked = $true }
                $userSetting = $settingsObj.Settings | Where-Object { $_.Name -eq 'User' } | Select-Object -First 1; $sysprepSetting = $settingsObj.Settings | Where-Object { $_.Name -eq 'Sysprep' } | Select-Object -First 1
                if ($sysprepSetting) { $scriptScope.userSelectionCombo.SelectedIndex = 2 } elseif ($userSetting) { $scriptScope.userSelectionCombo.SelectedIndex = 1; if ($scriptScope.otherUsernameTextBox) { $scriptScope.otherUsernameTextBox.Text = $userSetting.Value } } else { $scriptScope.userSelectionCombo.SelectedIndex = 0 }
                $scopeSetting = $settingsObj.Settings | Where-Object { $_.Name -eq 'AppRemovalTarget' } | Select-Object -First 1
                if ($scriptScope.appRemovalScopeCombo -and $scopeSetting) { switch ($scopeSetting.Value) { 'CurrentUser' { $scriptScope.appRemovalScopeCombo.SelectedIndex = 1 } 'AllUsers' { $scriptScope.appRemovalScopeCombo.SelectedIndex = 0 } default { $scriptScope.appRemovalScopeCombo.SelectedIndex = 2; if ($scriptScope.otherUsernameTextBox -and $scopeSetting.Value) { $scriptScope.otherUsernameTextBox.Text = $scopeSetting.Value } } } }
                Show-MessageBox -Message "Settings imported from:`n$($dlg.FileName)" -Title "Import" -Button 'OK' -Icon 'Information' | Out-Null
            } catch { Show-MessageBox -Message "Failed to import: $_" -Title "Import Error" -Button 'OK' -Icon 'Warning' | Out-Null }
        }
    })
}
