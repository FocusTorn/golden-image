function UpdateSortArrows {
    param($scriptScope)
    $ease = New-Object System.Windows.Media.Animation.QuadraticEase
    $ease.EasingMode = 'EaseOut'
    $arrows = @{
        'Name'        = $scriptScope.sortArrowName
        'Description' = $scriptScope.sortArrowDescription
        'AppId'       = $scriptScope.sortArrowAppId
    }
    foreach ($col in $arrows.Keys) {
        $tb = $arrows[$col]
        if ($col -eq $script:SortColumn) {
            $targetAngle = if ($script:SortAscending) { 0 } else { 180 }
            $tb.Opacity = 1.0
        } else {
            $targetAngle = 0
            $tb.Opacity = 0.3
        }
        $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
        $anim.To = $targetAngle
        $anim.Duration = [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(200))
        $anim.EasingFunction = $ease
        $tb.RenderTransform.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $anim)
    }
}

function SortApps {
    param($scriptScope)
    $children = @($scriptScope.appsPanel.Children)
    $key = switch ($script:SortColumn) {
        'Name'        { { $_.AppName } }
        'Description' { { $_.AppDescription } }
        'AppId'       { { $_.Tag } }
    }
    $sorted = $children | Sort-Object $key -Descending:(-not $script:SortAscending)
    $scriptScope.appsPanel.Children.Clear()
    foreach ($checkbox in $sorted) {
        $scriptScope.appsPanel.Children.Add($checkbox) | Out-Null
    }
    UpdateSortArrows -scriptScope $scriptScope
}

function SetSortColumn {
    param($column, $scriptScope)
    if ($script:SortColumn -eq $column) {
        $script:SortAscending = -not $script:SortAscending
    } else {
        $script:SortColumn = $column
        $script:SortAscending = $true
    }
    SortApps -scriptScope $scriptScope
}

function SyncColumnWidthsToRows {
    param($scriptScope)
    $nameW  = $script:HeaderColName.ActualWidth
    $descW  = $script:HeaderColDesc.ActualWidth
    $idW    = $script:HeaderColId.ActualWidth
    if ($nameW -le 0) { return }
    foreach ($child in $scriptScope.appsPanel.Children) {
        if ($child -is [System.Windows.Controls.CheckBox] -and $child.Content -is [System.Windows.Controls.Grid]) {
            $grid = $child.Content
            if ($grid.ColumnDefinitions.Count -ge 4) {
                $grid.ColumnDefinitions[1].Width = [System.Windows.GridLength]::new($nameW)
                $grid.ColumnDefinitions[2].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
                $grid.ColumnDefinitions[3].Width = [System.Windows.GridLength]::new($idW)
            }
        }
    }
}

function UpdateAppSelectionStatus {
    param($scriptScope)
    $selectedCount = 0
    foreach ($child in $scriptScope.appsPanel.Children) {
        if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
            $selectedCount++
        }
    }
    $scriptScope.appSelectionStatus.Text = "$selectedCount app(s) selected for removal"
}

function AddAppsToPanel {
    param($appsToAdd, $scriptScope, $window)
    $script:MainWindowLastSelectedCheckbox = $null
    if (-not $appsToAdd) { $appsToAdd = @() }

    $brushSafe    = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#4CAF50')
    $brushUnsafe  = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F44336')
    $brushDefault = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FFC107')
    $brushSafe.Freeze(); $brushUnsafe.Freeze(); $brushDefault.Freeze()

    $batchSize = 20
    $idx = 0
    $sorted = @($appsToAdd | Where-Object { $_.AppId -or $_.FriendlyName } | Sort-Object -Property FriendlyName)
    foreach ($app in $sorted) {
        $checkbox = New-Object System.Windows.Controls.CheckBox
        $automationName = if ($app.FriendlyName) { $app.FriendlyName } elseif ($app.AppId) { $app.AppId } else { $null }
        if ($automationName) { $checkbox.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $automationName) }
        $checkbox.Tag = $app.AppId
        $checkbox.IsChecked = $app.IsChecked
        $checkbox.Style = $window.Resources["AppsPanelCheckBoxStyle"]

        $row = New-Object System.Windows.Controls.Grid
        $row.Margin = [System.Windows.Thickness]::new(0,1,0,0)
        $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = [System.Windows.GridLength]::new(16)
        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::new(151)
        $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $c3 = New-Object System.Windows.Controls.ColumnDefinition; $c3.Width = [System.Windows.GridLength]::new(261)
        $row.ColumnDefinitions.Add($c0); $row.ColumnDefinitions.Add($c1)
        $row.ColumnDefinitions.Add($c2); $row.ColumnDefinitions.Add($c3)

        $dot = New-Object System.Windows.Shapes.Ellipse
        $dot.Width = 9; $dot.Height = 9
        $dot.HorizontalAlignment = 'Left'
        $dot.VerticalAlignment = 'Center'
        $dot.Fill  = switch ($app.Recommendation) { 'safe' { $brushSafe } 'unsafe' { $brushUnsafe } default { $brushDefault } }
        $dot.ToolTip = switch ($app.Recommendation) {
            'safe'   { '[Recommended] Safe to remove for most users' }
            'unsafe' { '[Not Recommended] Only remove if you know what you are doing' }
            default  { "[Optional] Remove if you don't need this app" }
        }
        [System.Windows.Controls.Grid]::SetColumn($dot, 0)

        $tbName = New-Object System.Windows.Controls.TextBlock
        $tbName.Text = $app.FriendlyName
        $tbName.Style = $window.Resources["AppNameTextStyle"]
        [System.Windows.Controls.Grid]::SetColumn($tbName, 1)

        $tbDesc = New-Object System.Windows.Controls.TextBlock
        $tbDesc.Text = $app.Description
        $tbDesc.Style = $window.Resources["AppDescTextStyle"]
        $tbDesc.ToolTip = $app.Description
        [System.Windows.Controls.Grid]::SetColumn($tbDesc, 2)

        $tbId = New-Object System.Windows.Controls.TextBlock
        $tbId.Text = $app.AppId
        $tbId.Style = $window.Resources["AppIdTextStyle"]
        $tbId.ToolTip = $app.AppId
        [System.Windows.Controls.Grid]::SetColumn($tbId, 3)

        $row.Children.Add($dot)    | Out-Null
        $row.Children.Add($tbName) | Out-Null
        $row.Children.Add($tbDesc) | Out-Null
        $row.Children.Add($tbId)   | Out-Null
        $checkbox.Content = $row

        Add-Member -InputObject $checkbox -MemberType NoteProperty -Name "AppName" -Value $app.FriendlyName
        Add-Member -InputObject $checkbox -MemberType NoteProperty -Name "AppDescription" -Value $app.Description
        Add-Member -InputObject $checkbox -MemberType NoteProperty -Name "SelectedByDefault" -Value $app.SelectedByDefault

        $checkbox.Add_Checked({ UpdateAppSelectionStatus -scriptScope $scriptScope })
        $checkbox.Add_Unchecked({ UpdateAppSelectionStatus -scriptScope $scriptScope })
        AttachShiftClickBehavior -checkbox $checkbox -appsPanel $scriptScope.appsPanel -lastSelectedCheckboxRef ([ref]$script:MainWindowLastSelectedCheckbox) -updateStatusCallback { UpdateAppSelectionStatus -scriptScope $scriptScope }

        $scriptScope.appsPanel.Children.Add($checkbox) | Out-Null
        $idx++
        if ($idx % $batchSize -eq 0) { DoEvents }
    }
    SortApps -scriptScope $scriptScope
    SyncColumnWidthsToRows -scriptScope $scriptScope
    $scriptScope.loadingAppsIndicator.Visibility = 'Collapsed'
    if ($scriptScope.exportAppListLink) { $scriptScope.exportAppListLink.Visibility = 'Visible' }
    UpdateNavigationButtons
    UpdateAppSelectionStatus -scriptScope $scriptScope
}

function LoadAppsWithList {
    param($scriptScope, $window)
    $onlyInstalledVal = $false
    if ($scriptScope.onlyInstalledAppsBox) { $onlyInstalledVal = $scriptScope.onlyInstalledAppsBox.IsChecked }
    $viewMode = 'FromJson'
    if ($scriptScope.showAllNotListedBox -and $scriptScope.showAllNotListedBox.IsChecked) { $viewMode = 'AllNotListed' }
    elseif ($scriptScope.showProvisionedNotListedBox -and $scriptScope.showProvisionedNotListedBox.IsChecked) { $viewMode = 'ProvisionedNotListed' }
    elseif ($scriptScope.showUserNotListedBox -and $scriptScope.showUserNotListedBox.IsChecked) { $viewMode = 'UserNotListed' }

    $appsListPath = [System.IO.Path]::GetFullPath($script:AppsListFilePath)
    $loaderPath = [System.IO.Path]::GetFullPath($script:LoadAppsDetailsScriptPath)
    $overlayPath = if ($script:OverlayAppsListFilePath) { [System.IO.Path]::GetFullPath($script:OverlayAppsListFilePath) } else { '' }

    try {
        $appsToAdd = Invoke-NonBlocking -ScriptBlock {
            param($loaderScriptPath, $appsListFilePath, $onlyInstalled, $viewMode, $overlayAppsPath)
            $script:AppsListFilePath = $appsListFilePath
            $script:OverlayAppsListFilePath = $overlayAppsPath
            . $loaderScriptPath
            LoadAppsDetailsFromJson -OnlyInstalled:$onlyInstalled -ViewMode $viewMode -InitialCheckedFromJson:$false
        } -ArgumentList $loaderPath, $appsListPath, $onlyInstalledVal, $viewMode, $overlayPath -TimeoutSeconds 60

        AddAppsToPanel -appsToAdd $appsToAdd -scriptScope $scriptScope -window $window
    }
    catch {
        $scriptScope.loadingAppsIndicator.Visibility = 'Collapsed'
        if ($scriptScope.exportAppListLink) { $scriptScope.exportAppListLink.Visibility = 'Collapsed' }
        UpdateNavigationButtons
        Show-MessageBox -Message "Unable to load app list.`n`n$($_.Exception.Message)" -Title 'Error' -Button 'OK' -Icon 'Error' | Out-Null
    }
}
