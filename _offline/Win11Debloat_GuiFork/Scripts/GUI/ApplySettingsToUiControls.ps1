# GuiFork: Applies settings from JSON to UI controls (checkboxes and comboboxes)
function ApplySettingsToUiControls {
    param (
        $window,
        $settingsJson,
        $uiControlMappings
    )
    
    if (-not $settingsJson -or -not $settingsJson.Settings) {
        return $false
    }
    
    # Reset all tweaks
    if ($uiControlMappings) {
        foreach ($comboName in $uiControlMappings.Keys) {
            $control = $window.FindName($comboName)
            if ($control -is [System.Windows.Controls.CheckBox]) {
                $control.IsChecked = $false
            }
            elseif ($control -is [System.Windows.Controls.ComboBox]) {
                $control.SelectedIndex = 0
            }
        }
    }
    
    # Apply settings from JSON
    foreach ($setting in $settingsJson.Settings) {
        if ($setting.Value -ne $true) { continue }
        $paramName = $setting.Name
        if ($paramName -eq 'CreateRestorePoint') { continue }

        if ($uiControlMappings) {
            foreach ($comboName in $uiControlMappings.Keys) {
                $mapping = $uiControlMappings[$comboName]
                if ($mapping.Type -eq 'group') {
                    $i = 1
                    foreach ($val in $mapping.Values) {
                        if ($val.FeatureIds -contains $paramName) {
                            $control = $window.FindName($comboName)
                            if ($control -and $control.Visibility -eq 'Visible' -and $control -is [System.Windows.Controls.ComboBox]) {
                                $control.SelectedIndex = $i
                            }
                            break
                        }
                        $i++
                    }
                }
                elseif ($mapping.Type -eq 'feature') {
                    if ($mapping.FeatureId -eq $paramName) {
                        $control = $window.FindName($comboName)
                        if ($control -and $control.Visibility -eq 'Visible') {
                            if ($control -is [System.Windows.Controls.CheckBox]) {
                                $control.IsChecked = $true
                            }
                            elseif ($control -is [System.Windows.Controls.ComboBox]) {
                                $control.SelectedIndex = 1
                            }
                        }
                    }
                }
            }
        }
    }
    
    return $true
}
