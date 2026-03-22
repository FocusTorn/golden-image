# App Profile functions (GuiFork)
function Get-AppProfilesPath {
    if ($script:AppProfilesPath) { return $script:AppProfilesPath }
    return Join-Path $script:GoldenImagerRoot "Config\AppProfiles"
}

function Get-AppProfileList {
    $profilesPath = Get-AppProfilesPath
    if (-not (Test-Path $profilesPath)) { return @() }
    Get-ChildItem -Path $profilesPath -Filter "*.json" -File | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) } | Sort-Object
}

function Import-AppProfile {
    param([string]$ProfileName)
    if ($ProfileName -eq 'Default') {
        try {
            $appsJson = Get-Content -Path $script:AppsListFilePath -Raw | ConvertFrom-Json
            return @($appsJson.Apps | Where-Object { $_.SelectedByDefault } | ForEach-Object { $_.AppId.Trim() })
        } catch { return @() }
    }
    $profilesPath = Get-AppProfilesPath
    $filePath = Join-Path $profilesPath "$ProfileName.json"
    if (-not (Test-Path $filePath)) { return @() }
    try {
        $data = Get-Content -Path $filePath -Raw | ConvertFrom-Json
        if (-not $data.Apps) { return @() }
        $ids = @()
        foreach ($a in @($data.Apps)) {
            if ($a -is [string]) { $ids += $a.Trim() }
            elseif ($a.AppId) { $ids += $a.AppId.ToString().Trim() }
        }
        return $ids
    } catch { return @() }
}

function Save-AppProfile {
    param([string]$ProfileName, [string[]]$AppIds)
    $profilesPath = Get-AppProfilesPath
    if (-not (Test-Path $profilesPath)) { New-Item -ItemType Directory -Path $profilesPath -Force | Out-Null }
    $filePath = Join-Path $profilesPath "$ProfileName.json"
    $json = @{ Apps = @($AppIds) } | ConvertTo-Json
    Set-Content -Path $filePath -Value $json -Encoding UTF8
    $configPath = Join-Path $script:OfflineRoot "_offline_config.json"
    $guestDrive = "E"; $returnPath = "return"
    if (Test-Path $configPath) {
        try {
            $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
            if ($cfg.GuestStagingDrive) { $guestDrive = $cfg.GuestStagingDrive.ToString().Trim().TrimEnd(':')[0] }
            if ($cfg.ReturnPath) { $returnPath = $cfg.ReturnPath.ToString().Trim() }
        } catch {}
    }
    $returnDir = Join-Path "${guestDrive}:\" $returnPath
    if (Test-Path $returnDir) { try { Copy-Item -Path $filePath -Destination (Join-Path $returnDir "$ProfileName.json") -Force } catch {} }
    else { try { New-Item -ItemType Directory -Path $returnDir -Force | Out-Null; Copy-Item -Path $filePath -Destination (Join-Path $returnDir "$ProfileName.json") -Force } catch {} }
}

function Update-AppProfileCombo {
    param($scriptScope)
    $combo = $scriptScope.appProfileCombo
    if (-not $combo) { return }
    $combo.Items.Clear()
    $combo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = "(No profile selected)" })) | Out-Null
    $combo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = "Default" })) | Out-Null
    foreach ($name in Get-AppProfileList) { $combo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = $name })) | Out-Null }
    $combo.SelectedIndex = 0
}

function Set-AppProfileToUi {
    param([string[]]$AppIds, [switch]$Replace, $scriptScope)
    if ($Replace) { foreach ($child in $scriptScope.appsPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox]) { $child.IsChecked = $AppIds -contains $child.Tag } } }
    else { foreach ($child in $scriptScope.appsPanel.Children) { if ($child -is [System.Windows.Controls.CheckBox] -and ($AppIds -contains $child.Tag)) { $child.IsChecked = $true } } }
    UpdateAppSelectionStatus -scriptScope $scriptScope
}

function Show-OptionsDialog {
    param([System.Windows.Window]$Owner, $usesDarkMode)
    $optionsPath = Join-Path $script:GoldenImagerRoot "Config/Options.json"
    
    function Get-Options {
        if (Test-Path $optionsPath) { try { $o = Get-Content -Path $optionsPath -Raw | ConvertFrom-Json; return @{ HideLauncherWindow = [bool]($o.HideLauncherWindow) } } catch { } }
        return @{ HideLauncherWindow = $false }
    }
    function Set-Options {
        param([hashtable]$opts)
        try { $opts | ConvertTo-Json | Set-Content -Path $optionsPath -Encoding UTF8 -Force } catch { }
    }
    function Set-OptionHideLauncher {
        param([bool]$Hide)
        try {
            $h = [User32_ShowWindow]::GetConsoleWindow()
            if ($h -ne [IntPtr]::Zero -and ([System.Management.Automation.PSTypeName]'User32_ShowWindow').Type) {
                [User32_ShowWindow]::ShowWindow($h, $(if ($Hide) { [User32_ShowWindow]::SW_HIDE } else { [User32_ShowWindow]::SW_SHOW })) | Out-Null
            }
        } catch { }
    }

    $opts = Get-Options
    $overlay = $null; $overlayWasAlreadyVisible = $false
    if ($Owner) { try { $overlay = $Owner.FindName('ModalOverlay'); if ($overlay) { $overlayWasAlreadyVisible = ($overlay.Visibility -eq 'Visible'); if (-not $overlayWasAlreadyVisible) { $Owner.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Visible' }) } } } catch { } }
    $optionsSchema = Join-Path $script:GoldenImagerRoot "Schemas/OptionsWindow.xaml"
    $xaml = Get-Content -Path $optionsSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try { $optWindow = [System.Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
    if ($Owner) { $optWindow.Owner = $Owner }
    SetWindowThemeResources -window $optWindow -usesDarkMode $usesDarkMode
    $toggle = $optWindow.FindName('OptionsHideLauncherToggle'); $okBtn = $optWindow.FindName('OptionsOkButton'); $titleBar = $optWindow.FindName('TitleBar')
    $toggle.IsChecked = $opts.HideLauncherWindow
    $okBtn.Add_Click({ $newOpts = @{ HideLauncherWindow = $toggle.IsChecked -eq $true }; Set-Options $newOpts; Set-OptionHideLauncher -Hide $newOpts.HideLauncherWindow; $optWindow.Close() })
    $titleBar.Add_MouseLeftButtonDown({ $optWindow.DragMove() })
    $optWindow.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { $optWindow.Close() } })
    $optWindow.ShowDialog() | Out-Null
    if ($overlay -and -not $overlayWasAlreadyVisible) { try { $Owner.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Collapsed' }) } catch { } }
}

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try { $optWindow = [System.Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
    if ($Owner) { $optWindow.Owner = $Owner }
    SetWindowThemeResources -window $optWindow -usesDarkMode $usesDarkMode
    $toggle = $optWindow.FindName('OptionsHideLauncherToggle'); $okBtn = $optWindow.FindName('OptionsOkButton'); $titleBar = $optWindow.FindName('TitleBar')
    $toggle.IsChecked = $opts.HideLauncherWindow
    $okBtn.Add_Click({ $newOpts = @{ HideLauncherWindow = $toggle.IsChecked -eq $true }; Set-Options $newOpts; Set-OptionHideLauncher -Hide $newOpts.HideLauncherWindow; $optWindow.Close() })
    $titleBar.Add_MouseLeftButtonDown({ $optWindow.DragMove() })
    $optWindow.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { $optWindow.Close() } })
    $optWindow.ShowDialog() | Out-Null
    if ($overlay -and -not $overlayWasAlreadyVisible) { try { $Owner.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Collapsed' }) } catch { } }
}

function Show-InputDialog {
    param([string]$Prompt = "Enter value:", [string]$Title = "Input", [string]$DefaultText = "", $window)
    $script:inputDialogResult = $null
    $tb = New-Object System.Windows.Controls.TextBox; $tb.Text = $DefaultText; $tb.MinWidth = 280; $tb.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
    $btnPanel = New-Object System.Windows.Controls.StackPanel; $btnPanel.Orientation = 'Horizontal'; $btnPanel.HorizontalAlignment = 'Right'
    $okBtn = New-Object System.Windows.Controls.Button; $okBtn.Content = 'OK'; $okBtn.MinWidth = 75; $okBtn.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
    $cancelBtn = New-Object System.Windows.Controls.Button; $cancelBtn.Content = 'Cancel'; $cancelBtn.MinWidth = 75
    $btnPanel.Children.Add($okBtn) | Out-Null; $btnPanel.Children.Add($cancelBtn) | Out-Null
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text = $Prompt; Margin = [System.Windows.Thickness]::new(0, 0, 0, 8) })) | Out-Null; $sp.Children.Add($tb) | Out-Null; $sp.Children.Add($btnPanel) | Out-Null
    $dialog = New-Object System.Windows.Window; $dialog.Title = $Title; $dialog.SizeToContent = 'WidthAndHeight'; $dialog.Content = $sp; $dialog.WindowStartupLocation = 'CenterOwner'; $dialog.Owner = $window
    $dialog.Add_Loaded({ $tb.Focus(); $tb.SelectAll() })
    $okBtn.Add_Click({ $script:inputDialogResult = $tb.Text; $dialog.Close() })
    $cancelBtn.Add_Click({ $script:inputDialogResult = $null; $dialog.Close() })
    $dialog.Add_KeyDown({ param($s, $e) if ($e.Key -eq [System.Windows.Input.Key]::Return) { $script:inputDialogResult = $tb.Text; $s.Close() }; if ($e.Key -eq [System.Windows.Input.Key]::Escape) { $script:inputDialogResult = $null; $s.Close() } })
    $dialog.ShowDialog() | Out-Null
    return $script:inputDialogResult
}
