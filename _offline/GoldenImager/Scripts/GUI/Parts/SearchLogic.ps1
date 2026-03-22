# Helper function to find the parent ScrollViewer of an element
function FindParentScrollViewer {
    param ([System.Windows.UIElement]$element)
    $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($element)
    while ($null -ne $parent) {
        if ($parent -is [System.Windows.Controls.ScrollViewer]) { return $parent }
        $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($parent)
    }
    return $null
}

# Helper function to scroll to an item if it's not visible, centering it in the viewport
function ScrollToItemIfNotVisible {
    param ([System.Windows.Controls.ScrollViewer]$scrollViewer, [System.Windows.UIElement]$item, [System.Windows.UIElement]$container)
    if (-not $scrollViewer -or -not $item -or -not $container) { return }
    try {
        $itemPosition = $item.TransformToAncestor($container).Transform([System.Windows.Point]::new(0, 0)).Y
        $viewportHeight = $scrollViewer.ViewportHeight
        $itemHeight = $item.ActualHeight
        $currentOffset = $scrollViewer.VerticalOffset
        $itemTop = $itemPosition - $currentOffset
        $itemBottom = $itemTop + $itemHeight
        if (-not (($itemTop -ge 0) -and ($itemBottom -le $viewportHeight))) {
            $targetOffset = $itemPosition - ($viewportHeight / 2) + ($itemHeight / 2)
            $scrollViewer.ScrollToVerticalOffset([Math]::Max(0, $targetOffset))
        }
    } catch { $item.BringIntoView() }
}

function Initialize-AppSearch {
    param($scriptScope, $window)
    $scriptScope.appSearchBox.Add_TextChanged({
        $searchText = $scriptScope.appSearchBox.Text.ToLower().Trim()
        $scriptScope.appSearchPlaceholder.Visibility = if ([string]::IsNullOrWhiteSpace($scriptScope.appSearchBox.Text)) { 'Visible' } else { 'Collapsed' }
        foreach ($child in $scriptScope.appsPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox]) { $child.Background = [System.Windows.Media.Brushes]::Transparent } }
        $script:AppSearchMatches = @()
        $script:AppSearchMatchIndex = -1
        if ([string]::IsNullOrWhiteSpace($searchText)) { return }
        $highlightBrush = $window.Resources["SearchHighlightColor"]
        $activeHighlightBrush = $window.Resources["SearchHighlightActiveColor"]
        foreach ($child in $scriptScope.appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.Visibility -eq 'Visible') {
                $appName = if ($child.AppName) { $child.AppName } else { '' }
                $appId = if ($child.Tag) { $child.Tag.ToString() } else { '' }
                $appDesc = if ($child.AppDescription) { $child.AppDescription } else { '' }
                if ($appName.ToLower().Contains($searchText) -or $appId.ToLower().Contains($searchText) -or $appDesc.ToLower().Contains($searchText)) {
                    $child.Background = $highlightBrush
                    $script:AppSearchMatches += $child
                }
            }
        }
        if ($script:AppSearchMatches.Count -gt 0) {
            $script:AppSearchMatchIndex = 0
            $script:AppSearchMatches[0].Background = $activeHighlightBrush
            $scrollViewer = FindParentScrollViewer -element $scriptScope.appsPanel
            if ($scrollViewer) { ScrollToItemIfNotVisible -scrollViewer $scrollViewer -item $script:AppSearchMatches[0] -container $scriptScope.appsPanel }
        }
    })
    $scriptScope.appSearchBox.Add_KeyDown({
        param($evtSender, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter -and $script:AppSearchMatches.Count -gt 0) {
            $script:AppSearchMatches[$script:AppSearchMatchIndex].Background = $window.Resources["SearchHighlightColor"]
            $script:AppSearchMatchIndex = ($script:AppSearchMatchIndex + 1) % $script:AppSearchMatches.Count
            $script:AppSearchMatches[$script:AppSearchMatchIndex].Background = $window.Resources["SearchHighlightActiveColor"]
            $scrollViewer = FindParentScrollViewer -element $scriptScope.appsPanel
            if ($scrollViewer) { ScrollToItemIfNotVisible -scrollViewer $scrollViewer -item $script:AppSearchMatches[$script:AppSearchMatchIndex] -container $scriptScope.appsPanel }
            $e.Handled = $true
        }
    })
}

function Initialize-TweakSearch {
    param($scriptScope, $window)
    $scriptScope.tweaksScrollViewer.Add_ScrollChanged({
        if ($scriptScope.tweaksScrollViewer.ScrollableHeight -gt 0) { $scriptScope.tweakSearchBorder.Margin = [System.Windows.Thickness]::new(0, 0, 17, 0) }
        else { $scriptScope.tweakSearchBorder.Margin = [System.Windows.Thickness]::new(0, 0, 0, 0) }
    })
    function ClearTweakHighlights {
        $cols = @($scriptScope.col0, $scriptScope.col1, $scriptScope.col2) | Where-Object { $_ -ne $null }
        foreach ($c in $cols) {
            foreach ($card in $c.Children) {
                if ($card -is [System.Windows.Controls.Border] -and $card.Child -is [System.Windows.Controls.StackPanel]) {
                    foreach ($ctrl in $card.Child.Children) {
                        if ($ctrl -is [System.Windows.Controls.CheckBox] -or ($ctrl -is [System.Windows.Controls.Border] -and $ctrl.Name -like '*_LabelBorder')) { $ctrl.Background = [System.Windows.Media.Brushes]::Transparent }
                    }
                }
            }
        }
    }
    $scriptScope.tweakSearchBox.Add_TextChanged({
        $searchText = $scriptScope.tweakSearchBox.Text.ToLower().Trim()
        $scriptScope.tweakSearchPlaceholder.Visibility = if ([string]::IsNullOrWhiteSpace($scriptScope.tweakSearchBox.Text)) { 'Visible' } else { 'Collapsed' }
        ClearTweakHighlights
        if ([string]::IsNullOrWhiteSpace($searchText)) { return }
        $firstMatch = $null
        $highlightBrush = $window.Resources["SearchHighlightColor"]
        $cols = @($scriptScope.col0, $scriptScope.col1, $scriptScope.col2) | Where-Object { $_ -ne $null }
        foreach ($column in $cols) {
            foreach ($card in $column.Children) {
                if ($card -is [System.Windows.Controls.Border] -and $card.Child -is [System.Windows.Controls.StackPanel]) {
                    $controlsList = @($card.Child.Children)
                    for ($i = 0; $i -lt $controlsList.Count; $i++) {
                        $control = $controlsList[$i]; $matchFound = $false; $controlToHighlight = $null
                        if ($control -is [System.Windows.Controls.CheckBox]) { if ($control.Content.ToString().ToLower().Contains($searchText)) { $matchFound = $true; $controlToHighlight = $control } }
                        elseif ($control -is [System.Windows.Controls.Border] -and $control.Name -like '*_LabelBorder') {
                            $labelText = if ($control.Child) { $control.Child.Text.ToLower() } else { "" }
                            $comboBox = if ($i + 1 -lt $controlsList.Count -and $controlsList[$i + 1] -is [System.Windows.Controls.ComboBox]) { $controlsList[$i + 1] } else { $null }
                            if ($labelText.Contains($searchText) -or ($comboBox -and ($comboBox.Items | ForEach-Object { if ($_ -is [System.Windows.Controls.ComboBoxItem]) { $_.Content.ToString().ToLower() } else { $_.ToString().ToLower() } } | Where-Object { $_.Contains($searchText) }))) { $matchFound = $true; $controlToHighlight = $control }
                        }
                        if ($matchFound -and $controlToHighlight) { $controlToHighlight.Background = $highlightBrush; if ($null -eq $firstMatch) { $firstMatch = $controlToHighlight } }
                    }
                }
            }
        }
        if ($firstMatch -and $scriptScope.tweaksScrollViewer) { ScrollToItemIfNotVisible -scrollViewer $scriptScope.tweaksScrollViewer -item $firstMatch -container $scriptScope.tweaksGrid }
    })
}
