function Initialize-HomeTab {
    param($scriptScope)
    
    if ($null -eq $scriptScope.HomeConnContent) { return }
    
    # Run connection audit in background
    $scriptScope.HomeConnSpinner.Visibility = 'Visible'
    $scriptScope.HomeConnContent.Visibility = 'Collapsed'
    
    Start-ThreadJob -ScriptBlock {
        param($scriptScope)
        try {
            # 1. LimitBlankPasswordUse
            $limitBlank = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -ErrorAction SilentlyContinue
            $limitBlankVal = $(if ($null -ne $limitBlank) { $limitBlank.LimitBlankPasswordUse } else { 1 })
            
            # 2. WinRM Service
            $winrm = Get-Service -Name WinRM -ErrorAction SilentlyContinue
            $winrmStatus = $(if ($null -ne $winrm) { "$($winrm.Status), $($winrm.StartType)" } else { "Not Found" })
            $winrmOk = $null -ne $winrm -and $winrm.Status -eq 'Running'
            
            # 3. KeyIso Service
            $keyiso = Get-Service -Name KeyIso -ErrorAction SilentlyContinue
            $keyisoStatus = $(if ($null -ne $keyiso) { "$($keyiso.Status), $($keyiso.StartType)" } else { "Not Found" })
            $keyisoOk = $null -ne $keyiso -and $keyiso.Status -eq 'Running'
            
            # 4. Built-in Admin
            $adminEnabled = $false
            try {
                $admin = Get-LocalUser -Name "Administrator" -ErrorAction SilentlyContinue
                if ($admin) { $adminEnabled = $admin.Enabled }
            } catch {}

            return @{
                LimitBlank = $limitBlankVal
                WinRM = $winrmStatus
                WinRMOk = $winrmOk
                KeyIso = $keyisoStatus
                KeyIsoOk = $keyisoOk
                AdminEnabled = $adminEnabled
            }
        } catch { return $null }
    } -ArgumentList $scriptScope | Wait-Job | Receive-Job | ForEach-Object {
        $results = $_
        if ($results) {
            $scriptScope.window.Dispatcher.Invoke({
                $scriptScope.HomeConnLimitBlank.IsChecked = $results.LimitBlank -eq 0
                $scriptScope.HomeConnWinRM.IsChecked = $results.WinRMOk
                $scriptScope.HomeConnKeyIso.IsChecked = $results.KeyIsoOk
                $scriptScope.HomeConnAdmin.IsChecked = $results.AdminEnabled
                
                $scriptScope.HomeConnSpinner.Visibility = 'Collapsed'
                $scriptScope.HomeConnContent.Visibility = 'Visible'
            })
        }
    }

    # Populate Stages Audit
    $scriptScope.HomeStagesAuditSpinner.Visibility = 'Visible'
    $scriptScope.HomeStagesAuditContent.Visibility = 'Collapsed'
    
    $stages = @(
        @{ Id = 1; Name = "Customize" }
        @{ Id = 2; Name = "Scoop" }
        @{ Id = 3; Name = "MSVC" }
        @{ Id = 4; Name = "System Apps" }
        @{ Id = 5; Name = "Rust Finish" }
        @{ Id = 6; Name = "Optimization" }
        @{ Id = 7; Name = "Finalize" }
    )
    
    $scriptScope.HomeStagesAuditPanel.Children.Clear()
    
    foreach ($stage in $stages) {
        $grid = New-Object System.Windows.Controls.Grid
        $grid.Margin = "0,2,0,2"
        $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(28) }))
        $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(28) }))
        $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(28) }))
        $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) }))
        
        $createDot = {
            param($color = "#808080")
            $e = New-Object System.Windows.Shapes.Ellipse
            $e.Width = 8; $e.Height = 8; $e.Fill = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString($color))
            $e.HorizontalAlignment = 'Center'; $e.VerticalAlignment = 'Center'
            return $e
        }
        
        # Registry Check (Mock for now, should check HKLM:\SOFTWARE\GoldenImage\Stages)
        $regDot = &$createDot "#808080"
        $grid.Children.Add($regDot); [System.Windows.Controls.Grid]::SetColumn($regDot, 0)
        
        # Path Check
        $pathOk = Test-Path "C:\GoldenImage\Stage$($stage.Id)"
        $pathDot = &$createDot $(if ($pathOk) { "#4CAF50" } else { "#c42b1c" })
        $grid.Children.Add($pathDot); [System.Windows.Controls.Grid]::SetColumn($pathDot, 1)
        
        # Link Check
        $linkDot = &$createDot "#808080"
        $grid.Children.Add($linkDot); [System.Windows.Controls.Grid]::SetColumn($linkDot, 2)
        
        $txt = New-Object System.Windows.Controls.TextBlock
        $txt.Text = "$($stage.Id). $($stage.Name)"
        $txt.FontSize = 12; $txt.Foreground = $scriptScope.window.Resources["LabelColor"]
        $txt.Margin = "8,0,0,0"; $txt.VerticalAlignment = 'Center'
        $grid.Children.Add($txt); [System.Windows.Controls.Grid]::SetColumn($txt, 3)
        
        $scriptScope.HomeStagesAuditPanel.Children.Add($grid)
    }
    
    $scriptScope.HomeStagesAuditSpinner.Visibility = 'Collapsed'
    $scriptScope.HomeStagesAuditContent.Visibility = 'Visible'
}
