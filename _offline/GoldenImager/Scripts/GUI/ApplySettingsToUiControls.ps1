# GuiFork: Applies settings from JSON to UI controls (checkboxes and comboboxes)
function ApplySettingsToUiControls {
    param(
        $window,
        $settingsJson,
        $uiControlMappings
    )

    if (-not $settingsJson -or -not $settingsJson.Settings) {
        return $false
    }

    # Reset all tweaks (system-applied get star/null, others get false)
    if ($uiControlMappings) {
        foreach ($comboName in $uiControlMappings.Keys) {
            $control = $window.FindName($comboName)
            $mapping = $uiControlMappings[$comboName]
            if ($control -is [System.Windows.Controls.CheckBox]) {
                if ($mapping.IsSystemApplied) {
                    $control.IsChecked = $null
                } else {
                    $control.IsChecked = $false
                }
            } elseif ($control -is [System.Windows.Controls.ComboBox]) {
                $control.SelectedIndex = 0
            }
        }
    }

    # Apply settings from JSON
    foreach ($setting in $settingsJson.Settings) {
        if ($setting.Value -ne $true) { continue }
        $paramName = $setting.Name
        if ($paramName -eq 'CreateRestorePoint') { continue }

        # GuiFork: Handle Revert_FeatureId (system-applied checkbox in revert state)
        if ($paramName -match '^Revert_(.+)$') {
            $featureId = $matches[1]
            $appliedColor = $window.Resources['AppliedColor']
            if ($uiControlMappings) {
                foreach ($comboName in $uiControlMappings.Keys) {
                    $mapping = $uiControlMappings[$comboName]
                    if ($mapping.Type -eq 'feature' -and $mapping.FeatureId -eq $featureId) {
                        $control = $window.FindName($comboName)
                        if ($control -and $control.Visibility -eq 'Visible' -and $control -is [System.Windows.Controls.CheckBox]) {
                            $control.Style = $window.Resources['FeatureCheckboxSystemAppliedStyle']
                            $control.IsThreeState = $true
                            $control.IsChecked = $false
                            $control.Foreground = $appliedColor
                            $uiControlMappings[$comboName].IsSystemApplied = $true
                        }
                        break
                    }
                }
            }
            continue
        }

        if ($uiControlMappings) {
            foreach ($comboName in $uiControlMappings.Keys) {
                $mapping = $uiControlMappings[$comboName]
                if ($mapping.Type -eq 'group') {
                    for ($idx = 0; $idx -lt $mapping.Values.Count; $idx++) {
                        $val = $mapping.Values[$idx]
                        if ($val.FeatureIds -contains $paramName) {
                            $control = $window.FindName($comboName)
                            if ($control -and $control.Visibility -eq 'Visible' -and $control -is [System.Windows.Controls.ComboBox]) {
                                $control.SelectedIndex = $idx + 1
                            }
                            break
                        }
                    }
                } elseif ($mapping.Type -eq 'feature') {
                    if ($mapping.FeatureId -eq $paramName) {
                        $control = $window.FindName($comboName)
                        if ($control -and $control.Visibility -eq 'Visible') {
                            if ($control -is [System.Windows.Controls.CheckBox]) {
                                $control.IsChecked = $true
                            } elseif ($control -is [System.Windows.Controls.ComboBox]) {
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
