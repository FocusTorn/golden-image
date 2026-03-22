# GuiFork: Get restart marker suffix for feature/group labels (explorer/reboot/none)
function Get-RestartMarkerSuffix {
    param($featureOrGroup, $featuresJson, [switch]$IsGroup)
    $req = 'explorer'
    if ($IsGroup) {
        $allFids = $featureOrGroup.Values | ForEach-Object { $_.FeatureIds } | ForEach-Object { $_ }
        foreach ($fid in $allFids) {
            $f = $featuresJson.Features | Where-Object { $_.FeatureId -eq $fid } | Select-Object -First 1
            $r = if ($f.RequiresRestart) { $f.RequiresRestart } elseif ($fid -match '^Remove|^ForceRemove' -or $fid -in @('EnableWindowsSandbox','EnableWindowsSubsystemForLinux','DisableCopilot')) { 'reboot' } elseif ($f.RegistryKey) { 'explorer' } else { 'explorer' }
            if ($r -eq 'reboot') { $req = 'reboot'; break }
            if ($r -eq 'explorer' -and $req -eq 'none') { $req = 'explorer' }
        }
    } else {
        $req = if ($featureOrGroup.RequiresRestart) { $featureOrGroup.RequiresRestart } elseif ($featureOrGroup.FeatureId -match '^Remove|^ForceRemove' -or $featureOrGroup.FeatureId -in @('EnableWindowsSandbox','EnableWindowsSubsystemForLinux','DisableCopilot')) { 'reboot' } elseif ($featureOrGroup.RegistryKey) { 'explorer' } else { 'explorer' }
    }
    switch ($req) { 'reboot' { ' [reboot]' } 'explorer' { ' [restart]' } default { '' } }
}

function CreateLabeledCombo {
    param($parent, $labelText, $comboName, $items, $feature, $window)
    # If only 2 items (No Change + one option), use checkbox
    if ($items.Count -eq 2) {
        $checkbox = New-Object System.Windows.Controls.CheckBox
        $checkbox.Content = $labelText
        $checkbox.Name = $comboName
        $checkbox.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $labelText)
        $checkbox.IsChecked = $false
        $checkbox.Style = $window.Resources["FeatureCheckboxStyle"]
        $parent.Children.Add($checkbox) | Out-Null
        try {
            [System.Windows.NameScope]::SetNameScope($checkbox, [System.Windows.NameScope]::GetNameScope($window))
            $window.RegisterName($comboName, $checkbox)
        }
        catch { }
        return $checkbox
    }
    
    # Otherwise use a combobox for multiple options
    # Wrap label in a Border for search highlighting
    $lblBorder = New-Object System.Windows.Controls.Border
    $lblBorder.Style = $window.Resources['LabelBorderStyle']
    $lblBorderName = "$comboName`_LabelBorder"
    $lblBorder.Name = $lblBorderName
    
    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text = $labelText
    $lbl.Style = $window.Resources['LabelStyle']
    $labelName = "$comboName`_Label"
    $lbl.Name = $labelName
    
    $lblBorder.Child = $lbl
    $parent.Children.Add($lblBorder) | Out-Null
    
    # Register the label border with the window's name scope
    try {
        [System.Windows.NameScope]::SetNameScope($lblBorder, [System.Windows.NameScope]::GetNameScope($window))
        $window.RegisterName($lblBorderName, $lblBorder)
    }
    catch { }

    $combo = New-Object System.Windows.Controls.ComboBox
    $combo.Name = $comboName
    $combo.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $labelText)
    foreach ($it in $items) { $cbItem = New-Object System.Windows.Controls.ComboBoxItem; $cbItem.Content = $it; $combo.Items.Add($cbItem) | Out-Null }
    $combo.SelectedIndex = 0
    $parent.Children.Add($combo) | Out-Null
    
    # Register the combo box with the window's name scope
    try {
        [System.Windows.NameScope]::SetNameScope($combo, [System.Windows.NameScope]::GetNameScope($window))
        $window.RegisterName($comboName, $combo)
    }
    catch { }
    
    return $combo
}

function GetWikiUrlForCategory {
    param($category)
    if (-not $category) { return 'https://github.com/Raphire/Win11Debloat/wiki/Features' }
    $slug = $category.ToLowerInvariant()
    $slug = $slug -replace '&', ''
    $slug = $slug -replace '[^a-z0-9\s-]', ''
    $slug = $slug -replace '\s', '-'
    return "https://github.com/Raphire/Win11Debloat/wiki/Features#$slug"
}

function GetOrCreateCategoryCard {
    param($categoryObj, $window, $columns)
    $categoryName = $categoryObj.Name
    $categoryIcon = $categoryObj.Icon

    if ($script:CategoryCardMap.ContainsKey($categoryName)) { return $script:CategoryCardMap[$categoryName] }

    # Create a new card Border + StackPanel and add to shortest column
    $target = $columns | Sort-Object @{Expression={$_.Children.Count}; Ascending=$true}, @{Expression={$columns.IndexOf($_)}; Ascending=$true} | Select-Object -First 1

    $border = New-Object System.Windows.Controls.Border
    $border.Style = $window.Resources['CategoryCardBorderStyle']
    $border.Tag = 'DynamicCategory'

    $panel = New-Object System.Windows.Controls.StackPanel
    $safe = ($categoryName -replace '[^a-zA-Z0-9_]','_')
    $panel.Name = "Category_{0}_Panel" -f $safe

    $headerRow = New-Object System.Windows.Controls.StackPanel
    $headerRow.Orientation = 'Horizontal'

    # Add category icon
    $icon = New-Object System.Windows.Controls.TextBlock
    if ($categoryIcon -match '&#x([0-9A-Fa-f]+);') {
        $hexValue = [Convert]::ToInt32($matches[1], 16)
        $icon.Text = [char]$hexValue
    }
    $icon.Style = $window.Resources['CategoryHeaderIcon']
    $headerRow.Children.Add($icon) | Out-Null

    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = $categoryName
    $header.Style = $window.Resources['CategoryHeaderTextBlock']
    $headerRow.Children.Add($header) | Out-Null

    $helpIcon = New-Object System.Windows.Controls.TextBlock
    $helpIcon.Text = '(?)'
    $helpIcon.Style = $window.Resources['CategoryHelpLinkTextStyle']

    $helpBtn = New-Object System.Windows.Controls.Button
    $helpBtn.Content = $helpIcon
    $helpBtn.ToolTip = "Open wiki for more info on '$categoryName' tweaks"
    $helpBtn.Tag = (GetWikiUrlForCategory -category $categoryName)
    $helpBtn.Style = $window.Resources['CategoryHelpLinkButtonStyle']
    $helpBtn.Add_Click({
        param($evtSender, $e)
        if ($evtSender.Tag) { Start-Process $evtSender.Tag }
    })
    $headerRow.Children.Add($helpBtn) | Out-Null

    $panel.Children.Add($headerRow) | Out-Null

    $border.Child = $panel
    $target.Children.Add($border) | Out-Null

    $script:CategoryCardMap[$categoryName] = $panel
    return $panel
}

function BuildDynamicTweaks {
    param($window, $WinVersion)
    $featuresJson = LoadJsonFile -filePath $script:FeaturesFilePath -expectedVersion "1.0"

    if (-not $featuresJson) {
        Show-MessageBox -Message "Unable to load Features.json file!" -Title "Error" -Button 'OK' -Icon 'Error' | Out-Null
        Exit
    }

    # Column containers
    $col0 = $window.FindName('Column0Panel')
    $col1 = $window.FindName('Column1Panel')
    $col2 = $window.FindName('Column2Panel')
    $columns = @($col0, $col1, $col2) | Where-Object { $_ -ne $null }

    foreach ($col in $columns) {
        if ($col) { $col.Children.Clear() }
    }

    $script:UiControlMappings = @{}
    $script:CategoryCardMap = @{}

    # Determine categories present
    $categoriesPresent = @{}
    if ($featuresJson.UiGroups) {
        foreach ($g in $featuresJson.UiGroups) { if ($g.Category) { $categoriesPresent[$g.Category] = $true } }
    }
    foreach ($f in $featuresJson.Features) { if ($f.Category) { $categoriesPresent[$f.Category] = $true } }

    # Create cards in order
    $orderedCategories = @()
    if ($featuresJson.Categories) {
        foreach ($c in $featuresJson.Categories) {
            $categoryName = if ($c -is [string]) { $c } else { $c.Name }
            if ($categoriesPresent.ContainsKey($categoryName)) {
                $categoryObj = if ($c -is [string]) { @{Name = $c; Icon = '&#xE712;'} } else { $c }
                $orderedCategories += $categoryObj
            }
        }
    } else {
        foreach ($catName in $categoriesPresent.Keys) {
            $orderedCategories += @{Name = $catName; Icon = '&#xE712;'}
        }
    }

    foreach ($categoryObj in $orderedCategories) {
        $categoryName = $categoryObj.Name
        $panel = GetOrCreateCategoryCard -categoryObj $categoryObj -window $window -columns $columns
        if (-not $panel) { continue }

        $categoryItems = @()
        if ($featuresJson.UiGroups) {
            $groupIndex = 0
            foreach ($group in $featuresJson.UiGroups) {
                if ($group.Category -ne $categoryName) { $groupIndex++; continue }
                $categoryItems += [PSCustomObject]@{ Type = 'group'; Data = $group; Priority = if ($null -ne $group.Priority) { $group.Priority } else { [int]::MaxValue }; OriginalIndex = $groupIndex }
                $groupIndex++
            }
        }

        $featureIndex = 0
        foreach ($feature in $featuresJson.Features) {
            if ($feature.Category -ne $categoryName) { $featureIndex++; continue }
            if (($feature.MinVersion -and $WinVersion -lt $feature.MinVersion) -or ($feature.MaxVersion -and $WinVersion -gt $feature.MaxVersion) -or ($feature.FeatureId -eq 'DisableModernStandbyNetworking' -and (-not $script:ModernStandbySupported))) {
                $featureIndex++; continue
            }
            $inGroup = $false
            if ($featuresJson.UiGroups) {
                foreach ($g in $featuresJson.UiGroups) { foreach ($val in $g.Values) { if ($val.FeatureIds -contains $feature.FeatureId) { $inGroup = $true; break } }; if ($inGroup) { break } }
            }
            if ($inGroup) { $featureIndex++; continue }
            $categoryItems += [PSCustomObject]@{ Type = 'feature'; Data = $feature; Priority = if ($null -ne $feature.Priority) { $feature.Priority } else { [int]::MaxValue }; OriginalIndex = $featureIndex }
            $featureIndex++
        }

        $sortedItems = $categoryItems | Sort-Object -Property Priority, OriginalIndex
        foreach ($item in $sortedItems) {
            if ($item.Type -eq 'group') {
                $group = $item.Data
                $items = @('No Change') + ($group.Values | ForEach-Object { $_.Label })
                $comboName = 'Group_{0}Combo' -f $group.GroupId
                $groupLabel = $group.Label + (Get-RestartMarkerSuffix -featureOrGroup $group -featuresJson $featuresJson -IsGroup)
                $combo = CreateLabeledCombo -parent $panel -labelText $groupLabel -comboName $comboName -items $items -feature $null -window $window
                if ($group.ToolTip) {
                    $tipBlock = New-Object System.Windows.Controls.TextBlock; $tipBlock.Text = $group.ToolTip; $tipBlock.TextWrapping = 'Wrap'; $tipBlock.MaxWidth = 420; $combo.ToolTip = $tipBlock
                    $lblBorderObj = $null; try { $lblBorderObj = $window.FindName("$comboName`_LabelBorder") } catch {}
                    if ($lblBorderObj) { $lblBorderObj.ToolTip = $tipBlock }
                }
                $script:UiControlMappings[$comboName] = @{ Type='group'; Values = $group.Values; Label = $group.Label }
            }
            elseif ($item.Type -eq 'feature') {
                $feature = $item.Data
                $opt = 'Apply'
                if ($feature.FeatureId -match '^Disable') { $opt = 'Disable' } elseif ($feature.FeatureId -match '^Enable') { $opt = 'Enable' }
                $items = @('No Change', $opt)
                $comboName = ("Feature_{0}_Combo" -f $feature.FeatureId) -replace '[^a-zA-Z0-9_]',''
                $featureLabel = $feature.Action + ' ' + $feature.Label + (Get-RestartMarkerSuffix -featureOrGroup $feature -featuresJson $featuresJson)
                $combo = CreateLabeledCombo -parent $panel -labelText $featureLabel -comboName $comboName -items $items -feature $feature -window $window
                if ($feature.ToolTip) {
                    $tipBlock = New-Object System.Windows.Controls.TextBlock; $tipBlock.Text = $feature.ToolTip; $tipBlock.TextWrapping = 'Wrap'; $tipBlock.MaxWidth = 420; $combo.ToolTip = $tipBlock
                }
                $script:UiControlMappings[$comboName] = @{ Type='feature'; FeatureId = $feature.FeatureId; Action = $feature.Action }
            }
        }
    }
}
