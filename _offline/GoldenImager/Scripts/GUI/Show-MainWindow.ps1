function Show-MainWindow {    
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing | Out-Null

    # Extract icon from imageres.dll for taskbar; AppUserModelID to separate from PowerShell
    $iconCode = @'
using System;
using System.Runtime.InteropServices;
public class Shell32_Extract {
    [DllImport("Shell32.dll", EntryPoint="ExtractIconExW", CharSet=CharSet.Unicode, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)]
    public static extern int ExtractIconEx(string lpszFile, int iconIndex, out IntPtr phiconLarge, out IntPtr phiconSmall, int nIcons);
}
'@
    $appIdCode = @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public class PSAppID {
    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
    private interface IPropertyStore {
        uint GetCount([Out] out uint cProps);
        uint GetAt([In] uint iProp, out PropertyKey pkey);
        uint GetValue([In] ref PropertyKey key, [Out] PropVariant pv);
        uint SetValue([In] ref PropertyKey key, [In] PropVariant pv);
        uint Commit();
    }
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PropertyKey {
        private Guid formatId;
        private Int32 propertyId;
        public PropertyKey(string formatId, Int32 propertyId) { this.formatId = new Guid(formatId); this.propertyId = propertyId; }
    }
    [StructLayout(LayoutKind.Explicit)]
    public class PropVariant : IDisposable {
        [FieldOffset(0)] ushort valueType;
        [FieldOffset(8)] IntPtr ptr;
        public PropVariant(string value) {
            if (value == null) throw new ArgumentException("Failed to set value.");
            valueType = (ushort)VarEnum.VT_LPWSTR;
            ptr = Marshal.StringToCoTaskMemUni(value);
        }
        public void Dispose() { PropVariantClear(this); GC.SuppressFinalize(this); }
    }
    [DllImport("Ole32.dll", PreserveSig = false)]
    private static extern void PropVariantClear([In, Out] PropVariant pvar);
    [DllImport("shell32.dll")]
    private static extern int SHGetPropertyStoreForWindow(IntPtr hwnd, ref Guid iid, [Out, MarshalAs(UnmanagedType.Interface)] out IPropertyStore propertyStore);
    public static void SetAppIdForWindow(IntPtr hwnd, string appId) {
        Guid iid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
        IPropertyStore prop;
        if (SHGetPropertyStoreForWindow(hwnd, ref iid, out prop) == 0) {
            PropertyKey key = new PropertyKey("{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}", 5);
            PropVariant pv = new PropVariant(appId);
            prop.SetValue(ref key, pv);
            Marshal.ReleaseComObject(prop);
        }
    }
}
'@
    if (-not ([System.Management.Automation.PSTypeName]'Shell32_Extract').Type) {
        Add-Type -TypeDefinition $iconCode -ErrorAction SilentlyContinue
    }
    if (-not ([System.Management.Automation.PSTypeName]'PSAppID').Type) {
        Add-Type -TypeDefinition $appIdCode -ErrorAction SilentlyContinue
    }

    # Get current Windows build version
    $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

    $usesDarkMode = GetSystemUsesDarkMode

    # Load XAML from file
    $xaml = Get-Content -Path $script:MainWindowSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }

    SetWindowThemeResources -window $window -usesDarkMode $usesDarkMode

    # Taskbar/window icon will be set in Loaded event (see below)

    # GuiFork: Add green color for already-applied tweaks (green border + green check, background unchanged)
    if (-not $window.Resources.Contains("AppliedColor")) {
        $window.Resources.Add("AppliedColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#22C55E")))
    }

    # Apply typography config from $script:Typography to window.Resources
    $tw = $script:Typography
    $fwMap = @{
        Normal = [System.Windows.FontWeights]::Normal
        Light = [System.Windows.FontWeights]::Light
        SemiBold = [System.Windows.FontWeights]::SemiBold
        Bold = [System.Windows.FontWeights]::Bold
        ExtraBold = [System.Windows.FontWeights]::ExtraBold
    }
    $getFw = { param($k, $d) if ($fwMap[$k]) { $fwMap[$k] } else { $d } }
    $fgBrush = $window.Resources["FgColor"]
    $brush = { param($c) if ($c) { [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString($c)) } else { $fgBrush } }
    $add = { param($k, $v) if (-not $window.Resources.Contains($k)) { $window.Resources.Add($k, $v) } }
    & $add "PageTitleFontSize" ([double]$tw.PageTitleFontSize)
    & $add "PageTitleFontWeight" (& $getFw $tw.PageTitleFontWeight ([System.Windows.FontWeights]::Bold))
    & $add "PageTitleFontFamily" ([System.Windows.Media.FontFamily]::new($tw.PageTitleFontFamily))
    & $add "PageTitleColor" (& $brush $tw.PageTitleColor)
    & $add "TabTitleFontSize" ([double]$tw.TabTitleFontSize)
    & $add "TabTitleFontWeight" (& $getFw $tw.TabTitleFontWeight ([System.Windows.FontWeights]::Bold))
    & $add "TabTitleFontFamily" ([System.Windows.Media.FontFamily]::new($tw.TabTitleFontFamily))
    & $add "TabTitleColor" (& $brush $tw.TabTitleColor)
    & $add "CardTitleFontSize" ([double]$tw.CardTitleFontSize)
    & $add "CardTitleFontWeight" (& $getFw $tw.CardTitleFontWeight ([System.Windows.FontWeights]::Bold))
    & $add "CardTitleFontFamily" ([System.Windows.Media.FontFamily]::new($tw.CardTitleFontFamily))
    & $add "CardTitleColor" (& $brush $tw.CardTitleColor)
    $marginParts = $tw.CardTitleMargin -split ','
    $cardTitleMargin = if ($marginParts.Count -ge 4) { [System.Windows.Thickness]::new([double]$marginParts[0], [double]$marginParts[1], [double]$marginParts[2], [double]$marginParts[3]) } else { [System.Windows.Thickness]::new(0, 0, 0, 13) }
    & $add "CardTitleMargin" $cardTitleMargin
    & $add "CardSubtitleFontSize" ([double]$tw.CardSubtitleFontSize)
    & $add "CardSubtitleFontWeight" (& $getFw $tw.CardSubtitleFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "CardSubtitleFontFamily" ([System.Windows.Media.FontFamily]::new($tw.CardSubtitleFontFamily))
    & $add "CardSubtitleColor" (& $brush $tw.CardSubtitleColor)
    & $add "LabelFontSize" ([double]$tw.LabelFontSize)
    & $add "LabelFontWeight" (& $getFw $tw.LabelFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "LabelFontFamily" ([System.Windows.Media.FontFamily]::new($tw.LabelFontFamily))
    & $add "LabelColor" (& $brush $tw.LabelColor)
    & $add "LabelSmallFontSize" ([double]$tw.LabelSmallFontSize)
    & $add "LabelSmallFontWeight" (& $getFw $tw.LabelSmallFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "TableHeaderFontSize" ([double]$tw.TableHeaderFontSize)
    & $add "TableHeaderFontWeight" (& $getFw $tw.TableHeaderFontWeight ([System.Windows.FontWeights]::SemiBold))
    & $add "TableHeaderFontFamily" ([System.Windows.Media.FontFamily]::new($tw.TableHeaderFontFamily))
    & $add "TableHeaderColor" (& $brush $tw.TableHeaderColor)
    & $add "BodyFontSize" ([double]$tw.BodyFontSize)
    & $add "BodyFontWeight" (& $getFw $tw.BodyFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "BodyFontFamily" ([System.Windows.Media.FontFamily]::new($tw.BodyFontFamily))
    & $add "BodyColor" (& $brush $tw.BodyColor)
    & $add "SearchFontSize" ([double]$tw.SearchFontSize)
    & $add "SearchFontWeight" (& $getFw $tw.SearchFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "SearchPlaceholderOpacity" ([double]$tw.SearchPlaceholderOpacity)
    & $add "ButtonPrimaryFontSize" ([double]$tw.ButtonPrimaryFontSize)
    & $add "ButtonPrimaryFontWeight" (& $getFw $tw.ButtonPrimaryFontWeight ([System.Windows.FontWeights]::SemiBold))
    & $add "ButtonSecondaryFontSize" ([double]$tw.ButtonSecondaryFontSize)
    & $add "ButtonSecondaryFontWeight" (& $getFw $tw.ButtonSecondaryFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "NavButtonFontSize" ([double]$tw.NavButtonFontSize)
    & $add "NavButtonFontWeight" (& $getFw $tw.NavButtonFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "HelpLinkFontSize" ([double]$tw.HelpLinkFontSize)
    & $add "HelpLinkFontWeight" (& $getFw $tw.HelpLinkFontWeight ([System.Windows.FontWeights]::Bold))
    & $add "CustomSetupFontSize" ([double]$tw.CustomSetupFontSize)
    & $add "CustomSetupFontWeight" (& $getFw $tw.CustomSetupFontWeight ([System.Windows.FontWeights]::SemiBold))
    & $add "IconFontFamily" ([System.Windows.Media.FontFamily]::new($tw.IconFontFamily))
    & $add "BaseFontFamily" ([System.Windows.Media.FontFamily]::new($tw.FontFamily))
    & $add "TypographyCharacterSpacing" ([int]$tw.CharacterSpacing)

    # Get named elements
    $titleBar = $window.FindName('TitleBar')
    $kofiBtn = $window.FindName('KofiBtn')
    $menuBtn = $window.FindName('MenuBtn')
    $closeBtn = $window.FindName('CloseBtn')
    $menuDocumentation = $window.FindName('MenuDocumentation')
    $menuReportBug = $window.FindName('MenuReportBug')
    $menuLogs = $window.FindName('MenuLogs')
    $menuAbout = $window.FindName('MenuAbout')
    $menuOptions = $window.FindName('MenuOptions')
    $menuExportSettings = $window.FindName('MenuExportSettings')
    $menuImportSettings = $window.FindName('MenuImportSettings')

    # Title bar event handlers
    $titleBar.Add_MouseLeftButtonDown({
        if ($_.OriginalSource -is [System.Windows.Controls.Grid] -or $_.OriginalSource -is [System.Windows.Controls.Border] -or $_.OriginalSource -is [System.Windows.Controls.TextBlock]) {
            $window.DragMove()
        }
    })
    
    $kofiBtn.Add_Click({
        Start-Process "https://ko-fi.com/raphire"
    })
    
    $menuBtn.Add_Click({
        $menuBtn.ContextMenu.PlacementTarget = $menuBtn
        $menuBtn.ContextMenu.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Bottom
        $menuBtn.ContextMenu.IsOpen = $true
    })

    $menuDocumentation.Add_Click({
        Start-Process "https://github.com/Raphire/Win11Debloat/wiki"
    })

    $menuReportBug.Add_Click({
        Start-Process "https://github.com/Raphire/Win11Debloat/issues"
    })

    $menuLogs.Add_Click({
        $logsFolder = Join-Path $PSScriptRoot "../../Logs"
        if (Test-Path $logsFolder) {
            Start-Process "explorer.exe" -ArgumentList $logsFolder
        }
        else {
            Show-MessageBox -Message "No logs folder found at: $logsFolder" -Title "Logs" -Button 'OK' -Icon 'Information'
        }
    })

    $menuAbout.Add_Click({
        Show-AboutDialog -Owner $window
    })

    $menuOptions.Add_Click({
        Show-OptionsDialog -Owner $window
    })

    $menuExportSettings.Add_Click({
        $settingsJson = Get-CurrentTweakSettingsFromUi
        $appsPanelRef = $window.FindName('AppSelectionPanel')
        $selectedApps = @()
        foreach ($child in $appsPanelRef.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedApps += $child.Tag
            }
        }
        if ($selectedApps.Count -gt 0) {
            $settingsJson.Settings += @{ Name = 'RemoveApps'; Value = $true }
            $settingsJson.Settings += @{ Name = 'Apps'; Value = ($selectedApps -join ',') }
        }
        $restorePointCheckBox = $window.FindName('RestorePointCheckBox')
        if ($restorePointCheckBox -and $restorePointCheckBox.IsChecked) {
            $settingsJson.Settings += @{ Name = 'CreateRestorePoint'; Value = $true }
        }
        $userSelCombo = $window.FindName('UserSelectionCombo')
        $otherUserTb = $window.FindName('OtherUsernameTextBox')
        if ($userSelCombo.SelectedIndex -eq 1) {
            if ($otherUserTb -and $otherUserTb.Text.Trim()) {
                $settingsJson.Settings += @{ Name = 'User'; Value = $otherUserTb.Text.Trim() }
            }
        }
        if ($userSelCombo.SelectedIndex -eq 2) {
            $settingsJson.Settings += @{ Name = 'Sysprep'; Value = $true }
        }
        $appRemovalScopeCombo = $window.FindName('AppRemovalScopeCombo')
        if ($appRemovalScopeCombo -and $selectedApps.Count -gt 0) {
            $scopeContent = if ($appRemovalScopeCombo.SelectedItem) { $appRemovalScopeCombo.SelectedItem.Content } else { $null }
            if ($scopeContent -eq 'Current user only') { $settingsJson.Settings += @{ Name = 'AppRemovalTarget'; Value = 'CurrentUser' } }
            elseif ($scopeContent -eq 'Target user only') { $settingsJson.Settings += @{ Name = 'AppRemovalTarget'; Value = ($otherUserTb.Text.Trim()) } }
            else { $settingsJson.Settings += @{ Name = 'AppRemovalTarget'; Value = 'AllUsers' } }
        }
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = 'JSON files (*.json)|*.json|All files (*.*)|*.*'
        $dlg.DefaultExt = 'json'
        $dlg.FileName = "GoldenImager-Settings-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        if ($dlg.ShowDialog() -eq $true) {
            try {
                $settingsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $dlg.FileName -Encoding UTF8
                Show-MessageBox -Message "Settings exported to:`n$($dlg.FileName)" -Title "Export" -Button 'OK' -Icon 'Information' | Out-Null
            } catch {
                Show-MessageBox -Message "Failed to export: $_" -Title "Export Error" -Button 'OK' -Icon 'Warning' | Out-Null
            }
        }
    })

    $menuImportSettings.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Filter = 'JSON files (*.json)|*.json|All files (*.*)|*.*'
        if ($dlg.ShowDialog() -eq $true) {
            try {
                $imported = Get-Content -Path $dlg.FileName -Raw | ConvertFrom-Json
                if (-not $imported.Settings) {
                    Show-MessageBox -Message "Invalid settings file format." -Title "Import" -Button 'OK' -Icon 'Warning' | Out-Null
                    return
                }
                $settingsObj = @{ Version = $imported.Version; Settings = @() }
                foreach ($s in $imported.Settings) {
                    $settingsObj.Settings += @{ Name = $s.Name; Value = $s.Value }
                }
                ApplySettingsToUiControls -window $window -settingsJson $settingsObj -uiControlMappings $script:UiControlMappings
                if ($settingsObj.Settings | Where-Object { $_.Name -eq 'Apps' }) {
                    $appsSetting = $settingsObj.Settings | Where-Object { $_.Name -eq 'Apps' } | Select-Object -First 1
                    $appIds = $appsSetting.Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    $appsPanelRef = $window.FindName('AppSelectionPanel')
                    foreach ($child in $appsPanelRef.Children) {
                        if ($child -is [System.Windows.Controls.CheckBox] -and $child.Tag) {
                            $child.IsChecked = $appIds -contains $child.Tag
                        }
                    }
                }
                $restorePointCheckBox = $window.FindName('RestorePointCheckBox')
                if ($restorePointCheckBox -and ($settingsObj.Settings | Where-Object { $_.Name -eq 'CreateRestorePoint' })) {
                    $restorePointCheckBox.IsChecked = $true
                }
                $userSelectionCombo = $window.FindName('UserSelectionCombo')
                $otherUsernameTextBox = $window.FindName('OtherUsernameTextBox')
                $userSetting = $settingsObj.Settings | Where-Object { $_.Name -eq 'User' } | Select-Object -First 1
                $sysprepSetting = $settingsObj.Settings | Where-Object { $_.Name -eq 'Sysprep' } | Select-Object -First 1
                if ($sysprepSetting) { $userSelectionCombo.SelectedIndex = 2 }
                elseif ($userSetting) { $userSelectionCombo.SelectedIndex = 1; if ($otherUsernameTextBox) { $otherUsernameTextBox.Text = $userSetting.Value } }
                else { $userSelectionCombo.SelectedIndex = 0 }
                $scopeSetting = $settingsObj.Settings | Where-Object { $_.Name -eq 'AppRemovalTarget' } | Select-Object -First 1
                $appRemovalScopeCombo = $window.FindName('AppRemovalScopeCombo')
                if ($appRemovalScopeCombo -and $scopeSetting) {
                    switch ($scopeSetting.Value) {
                        'CurrentUser' { $appRemovalScopeCombo.SelectedIndex = 1 }
                        'AllUsers' { $appRemovalScopeCombo.SelectedIndex = 0 }
                        default { $appRemovalScopeCombo.SelectedIndex = 2; if ($otherUsernameTextBox -and $scopeSetting.Value) { $otherUsernameTextBox.Text = $scopeSetting.Value } }
                    }
                }
                Show-MessageBox -Message "Settings imported from:`n$($dlg.FileName)" -Title "Import" -Button 'OK' -Icon 'Information' | Out-Null
            } catch {
                Show-MessageBox -Message "Failed to import: $_" -Title "Import Error" -Button 'OK' -Icon 'Warning' | Out-Null
            }
        }
    })

    $closeBtn.Add_Click({
        $window.Close()
    })

    # Window bounds persistence (x, y, width, height)
    $guiForkRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $configDir = Join-Path $guiForkRoot "Config"
    $windowBoundsPath = Join-Path $configDir "WindowBounds.json"
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }

    # Ensure closing the main window stops all execution and save bounds
    $window.Add_Closing({
        $script:CancelRequested = $true
        try {
            $w = $window
            if ($w.WindowState -eq 'Normal') {
                $bounds = @{ Left = $w.Left; Top = $w.Top; Width = $w.Width; Height = $w.Height }
                $bounds | ConvertTo-Json | Set-Content -Path $windowBoundsPath -Encoding UTF8 -Force
            }
        } catch { }
    })

    # Implement window resize functionality
    $resizeLeft = $window.FindName('ResizeLeft')
    $resizeRight = $window.FindName('ResizeRight')
    $resizeTop = $window.FindName('ResizeTop')
    $resizeBottom = $window.FindName('ResizeBottom')
    $resizeTopLeft = $window.FindName('ResizeTopLeft')
    $resizeTopRight = $window.FindName('ResizeTopRight')
    $resizeBottomLeft = $window.FindName('ResizeBottomLeft')
    $resizeBottomRight = $window.FindName('ResizeBottomRight')

    $script:resizing = $false
    $script:resizeEdges = $null
    $script:resizeStart = $null
    $script:windowStart = $null
    $script:resizeElement = $null

    $resizeHandler = {
        param($evtSender, $e)
        
        $script:resizing = $true
        $script:resizeElement = $evtSender
        $script:resizeStart = [System.Windows.Forms.Cursor]::Position
        $script:windowStart = @{
            Left = $window.Left
            Top = $window.Top
            Width = $window.ActualWidth
            Height = $window.ActualHeight
        }
        
        # Parse direction tag into edge flags for cleaner resize logic
        $direction = $evtSender.Tag
        $script:resizeEdges = @{
            Left = $direction -match 'Left'
            Right = $direction -match 'Right'
            Top = $direction -match 'Top'
            Bottom = $direction -match 'Bottom'
        }
        
        $evtSender.CaptureMouse()
        $e.Handled = $true
    }

    $moveHandler = {
        param($evtSender, $e)
        if (-not $script:resizing) { return }
        
        $current = [System.Windows.Forms.Cursor]::Position
        $deltaX = $current.X - $script:resizeStart.X
        $deltaY = $current.Y - $script:resizeStart.Y

        # Handle horizontal resize
        if ($script:resizeEdges.Left) {
            $newWidth = [Math]::Max($window.MinWidth, $script:windowStart.Width - $deltaX)
            if ($newWidth -ne $window.Width) {
                $window.Left = $script:windowStart.Left + ($script:windowStart.Width - $newWidth)
                $window.Width = $newWidth
            }
        }
        elseif ($script:resizeEdges.Right) {
            $window.Width = [Math]::Max($window.MinWidth, $script:windowStart.Width + $deltaX)
        }

        # Handle vertical resize
        if ($script:resizeEdges.Top) {
            $newHeight = [Math]::Max($window.MinHeight, $script:windowStart.Height - $deltaY)
            if ($newHeight -ne $window.Height) {
                $window.Top = $script:windowStart.Top + ($script:windowStart.Height - $newHeight)
                $window.Height = $newHeight
            }
        }
        elseif ($script:resizeEdges.Bottom) {
            $window.Height = [Math]::Max($window.MinHeight, $script:windowStart.Height + $deltaY)
        }
        
        $e.Handled = $true
    }

    $releaseHandler = {
        param($evtSender, $e)
        if ($script:resizing -and $script:resizeElement) {
            $script:resizing = $false
            $script:resizeEdges = $null
            $script:resizeElement.ReleaseMouseCapture()
            $script:resizeElement = $null
            $e.Handled = $true
        }
    }

    # Set tags and add event handlers for resize borders
    $resizeLeft.Tag = 'Left'
    $resizeLeft.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeLeft.Add_MouseMove($moveHandler)
    $resizeLeft.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeRight.Tag = 'Right'
    $resizeRight.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeRight.Add_MouseMove($moveHandler)
    $resizeRight.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeTop.Tag = 'Top'
    $resizeTop.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeTop.Add_MouseMove($moveHandler)
    $resizeTop.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeBottom.Tag = 'Bottom'
    $resizeBottom.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeBottom.Add_MouseMove($moveHandler)
    $resizeBottom.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeTopLeft.Tag = 'TopLeft'
    $resizeTopLeft.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeTopLeft.Add_MouseMove($moveHandler)
    $resizeTopLeft.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeTopRight.Tag = 'TopRight'
    $resizeTopRight.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeTopRight.Add_MouseMove($moveHandler)
    $resizeTopRight.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeBottomLeft.Tag = 'BottomLeft'
    $resizeBottomLeft.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeBottomLeft.Add_MouseMove($moveHandler)
    $resizeBottomLeft.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeBottomRight.Tag = 'BottomRight'
    $resizeBottomRight.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeBottomRight.Add_MouseMove($moveHandler)
    $resizeBottomRight.Add_MouseLeftButtonUp($releaseHandler)

    # Integrated App Selection UI
    $appsPanel = $window.FindName('AppSelectionPanel')
    $onlyInstalledAppsBox = $window.FindName('OnlyInstalledAppsBox')
    $showUserNotListedBox = $window.FindName('ShowUserNotListedBox')
    $showProvisionedNotListedBox = $window.FindName('ShowProvisionedNotListedBox')
    $showAllNotListedBox = $window.FindName('ShowAllNotListedBox')
    $loadingAppsIndicator = $window.FindName('LoadingAppsIndicator')
    $appSelectionStatus = $window.FindName('AppSelectionStatus')
    $defaultAppsBtn = $window.FindName('DefaultAppsBtn')
    $clearAppSelectionBtn = $window.FindName('ClearAppSelectionBtn')
    
    # Track the last selected checkbox for shift-click range selection
    $script:MainWindowLastSelectedCheckbox = $null

    # Set script-level variable for GUI window reference
    $script:GuiWindow = $window

    # Column header elements for sort and resize
    $appHeaderGrid      = $window.FindName('AppHeaderGrid')
    $headerNameBtn      = $window.FindName('HeaderNameBtn')
    $headerDescriptionBtn = $window.FindName('HeaderDescriptionBtn')
    $headerAppIdBtn     = $window.FindName('HeaderAppIdBtn')
    $sortArrowName        = $window.FindName('SortArrowName')
    $sortArrowDescription = $window.FindName('SortArrowDescription')
    $sortArrowAppId       = $window.FindName('SortArrowAppId')
    $script:HeaderColName = $window.FindName('HeaderColName')
    $script:HeaderColDesc = $window.FindName('HeaderColDesc')
    $script:HeaderColId   = $window.FindName('HeaderColId')

    $script:SortColumn = 'Name'
    $script:SortAscending = $true

    function UpdateSortArrows {
        $ease = New-Object System.Windows.Media.Animation.QuadraticEase
        $ease.EasingMode = 'EaseOut'
        $arrows = @{
            'Name'        = $sortArrowName
            'Description' = $sortArrowDescription
            'AppId'       = $sortArrowAppId
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
        $children = @($appsPanel.Children)
        $key = switch ($script:SortColumn) {
            'Name'        { { $_.AppName } }
            'Description' { { $_.AppDescription } }
            'AppId'       { { $_.Tag } }
        }
        $sorted = $children | Sort-Object $key -Descending:(-not $script:SortAscending)
        $appsPanel.Children.Clear()
        foreach ($checkbox in $sorted) {
            $appsPanel.Children.Add($checkbox) | Out-Null
        }
        UpdateSortArrows
    }

    function SetSortColumn($column) {
        if ($script:SortColumn -eq $column) {
            $script:SortAscending = -not $script:SortAscending
        } else {
            $script:SortColumn = $column
            $script:SortAscending = $true
        }
        SortApps
    }

    function SyncColumnWidthsToRows {
        $nameW  = $script:HeaderColName.ActualWidth
        $descW  = $script:HeaderColDesc.ActualWidth
        $idW    = $script:HeaderColId.ActualWidth
        if ($nameW -le 0) { return }
        foreach ($child in $appsPanel.Children) {
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
        $selectedCount = 0
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedCount++
            }
        }
        $appSelectionStatus.Text = "$selectedCount app(s) selected for removal"
    }

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

    # Dynamically builds Tweaks UI from Features.json
    function BuildDynamicTweaks {
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

        # Clear all columns for fully dynamic panel creation
        foreach ($col in $columns) {
            if ($col) { $col.Children.Clear() }
        }

        $script:UiControlMappings = @{}
        $script:CategoryCardMap = @{}

        function CreateLabeledCombo($parent, $labelText, $comboName, $items, $feature) {
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
            catch {
                # Name might already be registered, ignore
            }

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
            catch {
                # Name might already be registered, ignore
            }
            
            return $combo
        }

        function GetWikiUrlForCategory($category) {
            if (-not $category) { return 'https://github.com/Raphire/Win11Debloat/wiki/Features' }

            $slug = $category.ToLowerInvariant()
            $slug = $slug -replace '&', ''
            $slug = $slug -replace '[^a-z0-9\s-]', ''
            $slug = $slug -replace '\s', '-'

            return "https://github.com/Raphire/Win11Debloat/wiki/Features#$slug"
        }

        function GetOrCreateCategoryCard($categoryObj) {
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
            # Convert HTML entity to character (e.g., &#xE72E; -> actual character)
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

        # Determine categories present (from lists and features)
        $categoriesPresent = @{}
        if ($featuresJson.UiGroups) {
            foreach ($g in $featuresJson.UiGroups) { if ($g.Category) { $categoriesPresent[$g.Category] = $true } }
        }
        foreach ($f in $featuresJson.Features) { if ($f.Category) { $categoriesPresent[$f.Category] = $true } }

        # Create cards in the order defined in Features.json Categories (if present)
        $orderedCategories = @()
        if ($featuresJson.Categories) {
            foreach ($c in $featuresJson.Categories) {
                $categoryName = if ($c -is [string]) { $c } else { $c.Name }
                if ($categoriesPresent.ContainsKey($categoryName)) {
                    # Store the full category object (or create one with default icon for string categories)
                    $categoryObj = if ($c -is [string]) { @{Name = $c; Icon = '&#xE712;'} } else { $c }
                    $orderedCategories += $categoryObj
                }
            }
        } else {
            # For backward compatibility, create category objects from keys
            foreach ($catName in $categoriesPresent.Keys) {
                $orderedCategories += @{Name = $catName; Icon = '&#xE712;'}
            }
        }

        foreach ($categoryObj in $orderedCategories) {
            $categoryName = $categoryObj.Name
            
            # Create/get card for this category
            $panel = GetOrCreateCategoryCard -categoryObj $categoryObj
            if (-not $panel) { continue }

            # Collect groups and features for this category, then sort by priority
            $categoryItems = @()

            # Add any groups for this category
            if ($featuresJson.UiGroups) {
                $groupIndex = 0
                foreach ($group in $featuresJson.UiGroups) {
                    if ($group.Category -ne $categoryName) { $groupIndex++; continue }
                    $categoryItems += [PSCustomObject]@{
                        Type = 'group'
                        Data = $group
                        Priority = if ($null -ne $group.Priority) { $group.Priority } else { [int]::MaxValue }
                        OriginalIndex = $groupIndex
                    }
                    $groupIndex++
                }
            }

            # Add individual features for this category
            $featureIndex = 0
            foreach ($feature in $featuresJson.Features) {
                if ($feature.Category -ne $categoryName) { $featureIndex++; continue }
                
                # Check version and feature compatibility using Features.json
                if (($feature.MinVersion -and $WinVersion -lt $feature.MinVersion) -or ($feature.MaxVersion -and $WinVersion -gt $feature.MaxVersion) -or ($feature.FeatureId -eq 'DisableModernStandbyNetworking' -and (-not $script:ModernStandbySupported))) {
                    $featureIndex++; continue
                }

                # Skip if feature part of a group
                $inGroup = $false
                if ($featuresJson.UiGroups) {
                    foreach ($g in $featuresJson.UiGroups) { foreach ($val in $g.Values) { if ($val.FeatureIds -contains $feature.FeatureId) { $inGroup = $true; break } }; if ($inGroup) { break } }
                }
                if ($inGroup) { $featureIndex++; continue }

                $categoryItems += [PSCustomObject]@{
                    Type = 'feature'
                    Data = $feature
                    Priority = if ($null -ne $feature.Priority) { $feature.Priority } else { [int]::MaxValue }
                    OriginalIndex = $featureIndex
                }
                $featureIndex++
            }

            # Sort by priority first, then by original index for items with same/no priority
            $sortedItems = $categoryItems | Sort-Object -Property Priority, OriginalIndex

            # Render sorted items
            foreach ($item in $sortedItems) {
                if ($item.Type -eq 'group') {
                    $group = $item.Data
                    $items = @('No Change') + ($group.Values | ForEach-Object { $_.Label })
                    $comboName = 'Group_{0}Combo' -f $group.GroupId
                    $groupLabel = $group.Label + (Get-RestartMarkerSuffix -featureOrGroup $group -featuresJson $featuresJson -IsGroup)
                    $combo = CreateLabeledCombo -parent $panel -labelText $groupLabel -comboName $comboName -items $items -feature $null
                    # attach tooltip from UiGroups if present
                    if ($group.ToolTip) {
                        $tipBlock = New-Object System.Windows.Controls.TextBlock
                        $tipBlock.Text = $group.ToolTip
                        $tipBlock.TextWrapping = 'Wrap'
                        $tipBlock.MaxWidth = 420
                        $combo.ToolTip = $tipBlock
                        $lblBorderObj = $null
                        try { $lblBorderObj = $window.FindName("$comboName`_LabelBorder") } catch {}
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
                    $combo = CreateLabeledCombo -parent $panel -labelText $featureLabel -comboName $comboName -items $items -feature $feature
                    if ($feature.ToolTip) {
                        $tipBlock = New-Object System.Windows.Controls.TextBlock
                        $tipBlock.Text = $feature.ToolTip
                        $tipBlock.TextWrapping = 'Wrap'
                        $tipBlock.MaxWidth = 420
                        $combo.ToolTip = $tipBlock
                    }
                    $script:UiControlMappings[$comboName] = @{ Type='feature'; FeatureId = $feature.FeatureId; Action = $feature.Action }
                }
            }
        }
    }

    # Adds app checkboxes to the panel (runs on UI thread)
    function script:AddAppsToPanel($appsToAdd) {
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

            $checkbox.Add_Checked({ UpdateAppSelectionStatus })
            $checkbox.Add_Unchecked({ UpdateAppSelectionStatus })
            AttachShiftClickBehavior -checkbox $checkbox -appsPanel $appsPanel -lastSelectedCheckboxRef ([ref]$script:MainWindowLastSelectedCheckbox) -updateStatusCallback { UpdateAppSelectionStatus }

            $appsPanel.Children.Add($checkbox) | Out-Null
            $idx++
            if ($idx % $batchSize -eq 0) { DoEvents }
        }
        SortApps
        SyncColumnWidthsToRows
        $loadingAppsIndicator.Visibility = 'Collapsed'
        $exportAppListLink = $window.FindName('ExportAppListLink')
        if ($exportAppListLink) { $exportAppListLink.Visibility = 'Visible' }
        UpdateNavigationButtons
        UpdateAppSelectionStatus
    }

    # Loads apps via in-process runspace (Invoke-NonBlocking keeps UI responsive via DoEvents)
    function script:LoadAppsWithList {
        $onlyInstalledVal = $false
        if ($onlyInstalledAppsBox) { $onlyInstalledVal = $onlyInstalledAppsBox.IsChecked }
        $viewMode = 'FromJson'
        if ($showAllNotListedBox -and $showAllNotListedBox.IsChecked) { $viewMode = 'AllNotListed' }
        elseif ($showProvisionedNotListedBox -and $showProvisionedNotListedBox.IsChecked) { $viewMode = 'ProvisionedNotListed' }
        elseif ($showUserNotListedBox -and $showUserNotListedBox.IsChecked) { $viewMode = 'UserNotListed' }

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

            AddAppsToPanel $appsToAdd
        }
        catch {
            $loadingAppsIndicator.Visibility = 'Collapsed'
            $exportLink = $window.FindName('ExportAppListLink')
            if ($exportLink) { $exportLink.Visibility = 'Collapsed' }
            UpdateNavigationButtons
            Show-MessageBox -Message "Unable to load app list.`n`n$($_.Exception.Message)" -Title 'Error' -Button 'OK' -Icon 'Error' | Out-Null
        }
    }

    # Loads apps into the UI
    function LoadAppsIntoMainUI {
        $exportAppListLink = $window.FindName('ExportAppListLink')
        if ($exportAppListLink) { $exportAppListLink.Visibility = 'Collapsed' }
        $loadingAppsIndicator.Visibility = 'Visible'
        $appsPanel.Children.Clear()
        UpdateNavigationButtons
        $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Render, [action]{})
        
        # Start loading job immediately - all work runs in background, UI stays responsive
        LoadAppsWithList
    }

    # Column header sort handlers
    $headerNameBtn.Add_MouseLeftButtonUp({ SetSortColumn 'Name' })
    $headerDescriptionBtn.Add_MouseLeftButtonUp({ SetSortColumn 'Description' })
    $headerAppIdBtn.Add_MouseLeftButtonUp({ SetSortColumn 'AppId' })

    # GridSplitter drag handler — propagate header column widths to all data rows
    $appHeaderGrid.Add_LayoutUpdated({
        if ($script:_lastColNameW -ne $script:HeaderColName.ActualWidth -or
            $script:_lastColIdW   -ne $script:HeaderColId.ActualWidth) {
            $script:_lastColNameW = $script:HeaderColName.ActualWidth
            $script:_lastColIdW   = $script:HeaderColId.ActualWidth
            SyncColumnWidthsToRows
        }
    })

    # Event handlers for app selection
    $onlyInstalledAppsBox.Add_Checked({ LoadAppsIntoMainUI })
    $onlyInstalledAppsBox.Add_Unchecked({ LoadAppsIntoMainUI })

    # Mutually exclusive: when one "not listed" toggle is checked, uncheck the others
    function script:UncheckOtherNotListed($checkedBox) {
        if ($showUserNotListedBox -and $showUserNotListedBox -ne $checkedBox) { $showUserNotListedBox.IsChecked = $false }
        if ($showProvisionedNotListedBox -and $showProvisionedNotListedBox -ne $checkedBox) { $showProvisionedNotListedBox.IsChecked = $false }
        if ($showAllNotListedBox -and $showAllNotListedBox -ne $checkedBox) { $showAllNotListedBox.IsChecked = $false }
    }
    $showUserNotListedBox.Add_Checked({
        UncheckOtherNotListed $showUserNotListedBox
        LoadAppsIntoMainUI
    })
    $showUserNotListedBox.Add_Unchecked({ LoadAppsIntoMainUI })
    $showProvisionedNotListedBox.Add_Checked({
        UncheckOtherNotListed $showProvisionedNotListedBox
        LoadAppsIntoMainUI
    })
    $showProvisionedNotListedBox.Add_Unchecked({ LoadAppsIntoMainUI })
    $showAllNotListedBox.Add_Checked({
        UncheckOtherNotListed $showAllNotListedBox
        LoadAppsIntoMainUI
    })
    $showAllNotListedBox.Add_Unchecked({ LoadAppsIntoMainUI })

    # Quick selection buttons - only select apps actually in those categories
    $defaultAppsBtn.Add_Click({
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                if ($child.SelectedByDefault -eq $true) {
                    $child.IsChecked = $true
                } else {
                    $child.IsChecked = $false
                }
            }
        }
    })

    $clearAppSelectionBtn.Add_Click({
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.IsChecked = $false
            }
        }
    })

    # Simple input dialog (GuiFork)
    # Options config path and ShowWindow for hiding console
    $optionsPath = Join-Path $configDir "Options.json"
    $showWindowCode = @'
using System;
using System.Runtime.InteropServices;
public class User32_ShowWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr lpdwProcessId);
    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    public const int SW_HIDE = 0;
    public const int SW_SHOW = 5;
    public const int SW_RESTORE = 9;

    public static void ForceActivate(IntPtr hwnd) {
        IntPtr fg = GetForegroundWindow();
        uint fgThread = GetWindowThreadProcessId(fg, IntPtr.Zero);
        uint myThread = GetCurrentThreadId();
        if (fgThread != myThread) AttachThreadInput(myThread, fgThread, true);
        SetForegroundWindow(hwnd);
        if (fgThread != myThread) AttachThreadInput(myThread, fgThread, false);
    }
}
'@
    if (-not ([System.Management.Automation.PSTypeName]'User32_ShowWindow').Type) {
        Add-Type -TypeDefinition $showWindowCode -ErrorAction SilentlyContinue
    }

    function Get-Options {
        if (Test-Path $optionsPath) {
            try {
                $o = Get-Content -Path $optionsPath -Raw | ConvertFrom-Json
                return @{ HideLauncherWindow = [bool]($o.HideLauncherWindow) }
            } catch { }
        }
        return @{ HideLauncherWindow = $false }
    }
    function Set-Options {
        param([hashtable]$opts)
        try {
            $opts | ConvertTo-Json | Set-Content -Path $optionsPath -Encoding UTF8 -Force
        } catch { }
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

    function Show-OptionsDialog {
        param([System.Windows.Window]$Owner)
        $opts = Get-Options
        $hideLauncher = $opts.HideLauncherWindow

        # Show overlay if owner has ModalOverlay (same as Show-MessageBox)
        $overlay = $null
        $overlayWasAlreadyVisible = $false
        if ($Owner) {
            try {
                $overlay = $Owner.FindName('ModalOverlay')
                if ($overlay) {
                    $overlayWasAlreadyVisible = ($overlay.Visibility -eq 'Visible')
                    if (-not $overlayWasAlreadyVisible) {
                        $Owner.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Visible' })
                    }
                }
            } catch { }
        }

        # Load XAML (same structure as MessageBox)
        $optionsSchema = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "Schemas\OptionsWindow.xaml"
        $xaml = Get-Content -Path $optionsSchema -Raw
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        try {
            $optWindow = [System.Windows.Markup.XamlReader]::Load($reader)
        }
        finally {
            $reader.Close()
        }

        if ($Owner) { $optWindow.Owner = $Owner }
        SetWindowThemeResources -window $optWindow -usesDarkMode $usesDarkMode

        $toggle = $optWindow.FindName('OptionsHideLauncherToggle')
        $okBtn = $optWindow.FindName('OptionsOkButton')
        $titleBar = $optWindow.FindName('TitleBar')
        $toggle.IsChecked = $hideLauncher

        $okBtn.Add_Click({
            $newOpts = @{ HideLauncherWindow = $toggle.IsChecked -eq $true }
            Set-Options $newOpts
            Set-OptionHideLauncher -Hide $newOpts.HideLauncherWindow
            $optWindow.Close()
        })
        $titleBar.Add_MouseLeftButtonDown({ $optWindow.DragMove() })
        $optWindow.Add_KeyDown({
            param($s, $e)
            if ($e.Key -eq 'Escape') { $optWindow.Close() }
        })

        $optWindow.ShowDialog() | Out-Null

        if ($overlay -and -not $overlayWasAlreadyVisible) {
            try {
                $Owner.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Collapsed' })
            } catch { }
        }
    }

    function Show-InputDialog {
        param([string]$Prompt = "Enter value:", [string]$Title = "Input", [string]$DefaultText = "")
        $script:inputDialogResult = $null
        $tb = New-Object System.Windows.Controls.TextBox
        $tb.Text = $DefaultText
        $tb.MinWidth = 280
        $tb.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)
        $btnPanel = New-Object System.Windows.Controls.StackPanel
        $btnPanel.Orientation = 'Horizontal'
        $btnPanel.HorizontalAlignment = 'Right'
        $okBtn = New-Object System.Windows.Controls.Button
        $okBtn.Content = 'OK'
        $okBtn.MinWidth = 75
        $okBtn.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
        $cancelBtn = New-Object System.Windows.Controls.Button
        $cancelBtn.Content = 'Cancel'
        $cancelBtn.MinWidth = 75
        $btnPanel.Children.Add($okBtn) | Out-Null
        $btnPanel.Children.Add($cancelBtn) | Out-Null
        $sp = New-Object System.Windows.Controls.StackPanel
        $sp.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text = $Prompt; Margin = [System.Windows.Thickness]::new(0, 0, 0, 8) })) | Out-Null
        $sp.Children.Add($tb) | Out-Null
        $sp.Children.Add($btnPanel) | Out-Null
        $dialog = New-Object System.Windows.Window
        $dialog.Title = $Title
        $dialog.SizeToContent = 'WidthAndHeight'
        $dialog.Content = $sp
        $dialog.WindowStartupLocation = 'CenterOwner'
        $dialog.Owner = $window
        $dialog.Add_Loaded({ $tb.Focus(); $tb.SelectAll() })
        $okBtn.Add_Click({ $script:inputDialogResult = $tb.Text; $dialog.Close() })
        $cancelBtn.Add_Click({ $script:inputDialogResult = $null; $dialog.Close() })
        $dialog.Add_KeyDown({
            param($s, $e)
            if ($e.Key -eq [System.Windows.Input.Key]::Return) { $script:inputDialogResult = $tb.Text; $s.Close() }
            if ($e.Key -eq [System.Windows.Input.Key]::Escape) { $script:inputDialogResult = $null; $s.Close() }
        })
        $dialog.ShowDialog() | Out-Null
        return $script:inputDialogResult
    }

    # App Profile functions (GuiFork)
    function Get-AppProfilesPath {
        if ($script:AppProfilesPath) { return $script:AppProfilesPath }
        $guiForkRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        return Join-Path $guiForkRoot "Config\AppProfiles"
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
        $offlineDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $configPath = Join-Path $offlineDir "_offline_config.json"
        $guestDrive = "E"
        $returnPath = "return"
        if (Test-Path $configPath) {
            try {
                $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
                if ($cfg.GuestStagingDrive) { $guestDrive = $cfg.GuestStagingDrive.ToString().Trim().TrimEnd(':')[0] }
                if ($cfg.ReturnPath) { $returnPath = $cfg.ReturnPath.ToString().Trim() }
            } catch {}
        }
        $returnDir = Join-Path "${guestDrive}:\" $returnPath
        if (Test-Path $returnDir) {
            try { Copy-Item -Path $filePath -Destination (Join-Path $returnDir "$ProfileName.json") -Force } catch {}
        } else {
            try { New-Item -ItemType Directory -Path $returnDir -Force | Out-Null; Copy-Item -Path $filePath -Destination (Join-Path $returnDir "$ProfileName.json") -Force } catch {}
        }
    }
    function Update-AppProfileCombo {
        $combo = $window.FindName('AppProfileCombo')
        if (-not $combo) { return }
        $combo.Items.Clear()
        $combo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = "(No profile selected)" })) | Out-Null
        $combo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = "Default" })) | Out-Null
        foreach ($name in Get-AppProfileList) {
            $combo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = $name })) | Out-Null
        }
        $combo.SelectedIndex = 0
    }
    function Set-AppProfileToUi {
        param([string[]]$AppIds, [switch]$Replace)
        if ($Replace) {
            foreach ($child in $appsPanel.Children) {
                if ($child -is [System.Windows.Controls.CheckBox]) {
                    $child.IsChecked = $AppIds -contains $child.Tag
                }
            }
        } else {
            foreach ($child in $appsPanel.Children) {
                if ($child -is [System.Windows.Controls.CheckBox] -and ($AppIds -contains $child.Tag)) {
                    $child.IsChecked = $true
                }
            }
        }
        UpdateAppSelectionStatus
    }

    # App Profile UI handlers (GuiFork)
    $appProfileCombo = $window.FindName('AppProfileCombo')
    $appProfileReplaceBtn = $window.FindName('AppProfileReplaceBtn')
    $appProfileMergeBtn = $window.FindName('AppProfileMergeBtn')
    $appProfileSaveBtn = $window.FindName('AppProfileSaveBtn')
    $appProfileSaveAsBtn = $window.FindName('AppProfileSaveAsBtn')
    $appProfileDeleteBtn = $window.FindName('AppProfileDeleteBtn')
    if ($appProfileCombo -and $appProfileReplaceBtn -and $appProfileMergeBtn -and $appProfileSaveBtn -and $appProfileSaveAsBtn -and $appProfileDeleteBtn) {
        Update-AppProfileCombo
        $appProfileReplaceBtn.Add_Click({
            $item = $appProfileCombo.SelectedItem
            if (-not $item -or $appProfileCombo.SelectedIndex -eq 0) {
                Show-MessageBox -Message "Select a profile first." -Title "App Profile" -Button 'OK' -Icon 'Information' | Out-Null
                return
            }
            $profileName = $item.Content
            $appIds = Import-AppProfile -ProfileName $profileName
            if ($appIds.Count -eq 0) {
                Show-MessageBox -Message "Profile '$profileName' is empty or could not be loaded." -Title "App Profile" -Button 'OK' -Icon 'Warning' | Out-Null
                return
            }
            Set-AppProfileToUi -AppIds $appIds -Replace
        })
        $appProfileMergeBtn.Add_Click({
            $item = $appProfileCombo.SelectedItem
            if (-not $item -or $appProfileCombo.SelectedIndex -eq 0) {
                Show-MessageBox -Message "Select a profile first." -Title "App Profile" -Button 'OK' -Icon 'Information' | Out-Null
                return
            }
            $profileName = $item.Content
            $appIds = Import-AppProfile -ProfileName $profileName
            if ($appIds.Count -eq 0) {
                Show-MessageBox -Message "Profile '$profileName' is empty or could not be loaded." -Title "App Profile" -Button 'OK' -Icon 'Warning' | Out-Null
                return
            }
            Set-AppProfileToUi -AppIds $appIds -Replace:$false
        })
        $appProfileSaveBtn.Add_Click({
            $selectedApps = @()
            foreach ($child in $appsPanel.Children) {
                if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                    $selectedApps += $child.Tag
                }
            }
            if ($selectedApps.Count -eq 0) {
                Show-MessageBox -Message "No apps selected. Select at least one app to save." -Title "Save Profile" -Button 'OK' -Icon 'Information' | Out-Null
                return
            }
            $item = $appProfileCombo.SelectedItem
            $profileName = $null
            if ($item -and $appProfileCombo.SelectedIndex -ge 2) {
                $profileName = $item.Content
            }
            if (-not $profileName) {
                $profileName = Show-InputDialog -Prompt "Enter profile name:" -Title "Save App Profile" -DefaultText "New Profile"
                if ([string]::IsNullOrWhiteSpace($profileName)) { return }
                $profileName = $profileName.Trim()
            }
            if ($profileName -eq 'Default') {
                Show-MessageBox -Message "'Default' is reserved for the built-in preset." -Title "Invalid Name" -Button 'OK' -Icon 'Warning' | Out-Null
                return
            }
            $invalidPattern = '[<>:' + [char]34 + '/\\|?*]'
            if ($profileName -match $invalidPattern) {
                Show-MessageBox -Message 'Profile name cannot contain: < > : " / \ | ? *' -Title "Invalid Name" -Button 'OK' -Icon 'Warning' | Out-Null
                return
            }
            Save-AppProfile -ProfileName $profileName -AppIds $selectedApps
            Update-AppProfileCombo
            Show-MessageBox -Message "Profile '$profileName' saved with $($selectedApps.Count) app(s)." -Title "Save Profile" -Button 'OK' -Icon 'Information' | Out-Null
        })
        $appProfileSaveAsBtn.Add_Click({
            $selectedApps = @()
            foreach ($child in $appsPanel.Children) {
                if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                    $selectedApps += $child.Tag
                }
            }
            if ($selectedApps.Count -eq 0) {
                Show-MessageBox -Message "No apps selected. Select at least one app to save." -Title "Save Profile" -Button 'OK' -Icon 'Information' | Out-Null
                return
            }
            $profileName = Show-InputDialog -Prompt "Enter profile name:" -Title "Save App Profile As" -DefaultText "New Profile"
            if ([string]::IsNullOrWhiteSpace($profileName)) { return }
            $profileName = $profileName.Trim()
            if ($profileName -eq 'Default') {
                Show-MessageBox -Message "'Default' is reserved for the built-in preset." -Title "Invalid Name" -Button 'OK' -Icon 'Warning' | Out-Null
                return
            }
            $invalidPattern = '[<>:' + [char]34 + '/\\|?*]'
            if ($profileName -match $invalidPattern) {
                Show-MessageBox -Message 'Profile name cannot contain: < > : " / \ | ? *' -Title "Invalid Name" -Button 'OK' -Icon 'Warning' | Out-Null
                return
            }
            Save-AppProfile -ProfileName $profileName -AppIds $selectedApps
            Update-AppProfileCombo
            Show-MessageBox -Message "Profile '$profileName' saved with $($selectedApps.Count) app(s)." -Title "Save Profile" -Button 'OK' -Icon 'Information' | Out-Null
        })
        $appProfileDeleteBtn.Add_Click({
            $item = $appProfileCombo.SelectedItem
            if (-not $item -or $appProfileCombo.SelectedIndex -lt 2) {
                Show-MessageBox -Message "Select a custom profile to delete (not Default or 'No profile selected')." -Title "Delete Profile" -Button 'OK' -Icon 'Information' | Out-Null
                return
            }
            $profileName = $item.Content
            if ($profileName -eq 'Default') {
                Show-MessageBox -Message "Cannot delete the built-in Default profile." -Title "Delete Profile" -Button 'OK' -Icon 'Warning' | Out-Null
                return
            }
            $confirm = Show-MessageBox -Message "Delete profile '$profileName'?" -Title "Delete Profile" -Button 'YesNo' -Icon 'Question'
            if ($confirm -ne 'Yes') { return }
            $profilesPath = Get-AppProfilesPath
            $filePath = Join-Path $profilesPath "$profileName.json"
            if (-not (Test-Path $filePath)) {
                Update-AppProfileCombo
                return
            }
            try {
                Remove-Item -Path $filePath -Force
                $offlineDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
                $configPath = Join-Path $offlineDir "_offline_config.json"
                $guestDrive = "E"
                $returnPath = "return"
                if (Test-Path $configPath) {
                    try {
                        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
                        if ($cfg.GuestStagingDrive) { $guestDrive = $cfg.GuestStagingDrive.ToString().Trim().TrimEnd(':')[0] }
                        if ($cfg.ReturnPath) { $returnPath = $cfg.ReturnPath.ToString().Trim() }
                    } catch {}
                }
                $returnFilePath = Join-Path (Join-Path "${guestDrive}:\" $returnPath) "$ProfileName.json"
                if (Test-Path $returnFilePath) { Remove-Item -Path $returnFilePath -Force }
            } catch {}
            Update-AppProfileCombo
            Show-MessageBox -Message "Profile '$profileName' deleted." -Title "Delete Profile" -Button 'OK' -Icon 'Information' | Out-Null
        })
    }

    # Helper function to scroll to an item if it's not visible, centering it in the viewport
    function ScrollToItemIfNotVisible {
        param (
            [System.Windows.Controls.ScrollViewer]$scrollViewer,
            [System.Windows.UIElement]$item,
            [System.Windows.UIElement]$container
        )
        
        if (-not $scrollViewer -or -not $item -or -not $container) { return }
        
        try {
            $itemPosition = $item.TransformToAncestor($container).Transform([System.Windows.Point]::new(0, 0)).Y
            $viewportHeight = $scrollViewer.ViewportHeight
            $itemHeight = $item.ActualHeight
            $currentOffset = $scrollViewer.VerticalOffset
            
            # Check if the item is currently visible in the viewport
            $itemTop = $itemPosition - $currentOffset
            $itemBottom = $itemTop + $itemHeight
            
            $isVisible = ($itemTop -ge 0) -and ($itemBottom -le $viewportHeight)
            
            # Only scroll if the item is not visible
            if (-not $isVisible) {
                # Center the item in the viewport
                $targetOffset = $itemPosition - ($viewportHeight / 2) + ($itemHeight / 2)
                $scrollViewer.ScrollToVerticalOffset([Math]::Max(0, $targetOffset))
            }
        }
        catch {
            # Fallback to simple bring into view
            $item.BringIntoView()
        }
    }
    
    # Helper function to find the parent ScrollViewer of an element
    function FindParentScrollViewer {
        param ([System.Windows.UIElement]$element)
        
        $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($element)
        while ($null -ne $parent) {
            if ($parent -is [System.Windows.Controls.ScrollViewer]) {
                return $parent
            }
            $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($parent)
        }
        return $null
    }

    # App Search Box functionality
    $appSearchBox = $window.FindName('AppSearchBox')
    $appSearchPlaceholder = $window.FindName('AppSearchPlaceholder')
    
    # Track current search matches and active index for Enter-key navigation
    $script:AppSearchMatches = @()
    $script:AppSearchMatchIndex = -1
    
    $appSearchBox.Add_TextChanged({
        $searchText = $appSearchBox.Text.ToLower().Trim()
        
        # Show/hide placeholder
        $appSearchPlaceholder.Visibility = if ([string]::IsNullOrWhiteSpace($appSearchBox.Text)) { 'Visible' } else { 'Collapsed' }
        
        # Clear all highlights first
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.Background = [System.Windows.Media.Brushes]::Transparent
            }
        }
        
        $script:AppSearchMatches = @()
        $script:AppSearchMatchIndex = -1
        
        if ([string]::IsNullOrWhiteSpace($searchText)) { return }
        
        # Find and highlight all matching apps
        $highlightBrush = $window.Resources["SearchHighlightColor"]
        $activeHighlightBrush = $window.Resources["SearchHighlightActiveColor"]
        
        foreach ($child in $appsPanel.Children) {
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
        
        # Scroll to first match and mark it as active
        if ($script:AppSearchMatches.Count -gt 0) {
            $script:AppSearchMatchIndex = 0
            $script:AppSearchMatches[0].Background = $activeHighlightBrush
            $scrollViewer = FindParentScrollViewer -element $appsPanel
            if ($scrollViewer) {
                ScrollToItemIfNotVisible -scrollViewer $scrollViewer -item $script:AppSearchMatches[0] -container $appsPanel
            }
        }
    })
    
    $appSearchBox.Add_KeyDown({
        param($evtSender, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter -and $script:AppSearchMatches.Count -gt 0) {
            # Reset background of current active match
            $script:AppSearchMatches[$script:AppSearchMatchIndex].Background = $window.Resources["SearchHighlightColor"]
            # Advance to next match (wrapping)
            $script:AppSearchMatchIndex = ($script:AppSearchMatchIndex + 1) % $script:AppSearchMatches.Count
            # Highlight new active match
            $script:AppSearchMatches[$script:AppSearchMatchIndex].Background = $window.Resources["SearchHighlightActiveColor"]
            $scrollViewer = FindParentScrollViewer -element $appsPanel
            if ($scrollViewer) {
                ScrollToItemIfNotVisible -scrollViewer $scrollViewer -item $script:AppSearchMatches[$script:AppSearchMatchIndex] -container $appsPanel
            }
            $e.Handled = $true
        }
    })

    # Tweak Search Box functionality
    $tweakSearchBox = $window.FindName('TweakSearchBox')
    $tweakSearchPlaceholder = $window.FindName('TweakSearchPlaceholder')
    $tweakSearchBorder = $window.FindName('TweakSearchBorder')
    $tweaksScrollViewer = $window.FindName('TweaksScrollViewer')
    $tweaksGrid = $window.FindName('TweaksGrid')
    $col0 = $window.FindName('Column0Panel')
    $col1 = $window.FindName('Column1Panel')
    $col2 = $window.FindName('Column2Panel')
    
    # Monitor scrollbar visibility and adjust searchbar margin
    $tweaksScrollViewer.Add_ScrollChanged({
        if ($tweaksScrollViewer.ScrollableHeight -gt 0) {
            # The 17px accounts for the scrollbar width + some padding
            $tweakSearchBorder.Margin = [System.Windows.Thickness]::new(0, 0, 17, 0)
        } else {
            $tweakSearchBorder.Margin = [System.Windows.Thickness]::new(0, 0, 0, 0)
        }
    })
    
    # Helper function to clear all tweak highlights
    function ClearTweakHighlights {
        $columns = @($col0, $col1, $col2) | Where-Object { $_ -ne $null }
        foreach ($column in $columns) {
            foreach ($card in $column.Children) {
                if ($card -is [System.Windows.Controls.Border] -and $card.Child -is [System.Windows.Controls.StackPanel]) {
                    foreach ($control in $card.Child.Children) {
                        if ($control -is [System.Windows.Controls.CheckBox] -or 
                            ($control -is [System.Windows.Controls.Border] -and $control.Name -like '*_LabelBorder')) {
                            $control.Background = [System.Windows.Media.Brushes]::Transparent
                        }
                    }
                }
            }
        }
    }
    
    # Helper function to check if a ComboBox contains matching items
    function ComboBoxContainsMatch {
        param ([System.Windows.Controls.ComboBox]$comboBox, [string]$searchText)
        
        foreach ($item in $comboBox.Items) {
            $itemText = if ($item -is [System.Windows.Controls.ComboBoxItem]) { $item.Content.ToString().ToLower() } else { $item.ToString().ToLower() }
            if ($itemText.Contains($searchText)) { return $true }
        }
        return $false
    }
    
    $tweakSearchBox.Add_TextChanged({
        $searchText = $tweakSearchBox.Text.ToLower().Trim()
        
        # Show/hide placeholder
        $tweakSearchPlaceholder.Visibility = if ([string]::IsNullOrWhiteSpace($tweakSearchBox.Text)) { 'Visible' } else { 'Collapsed' }
        
        # Clear all highlights
        ClearTweakHighlights
        
        if ([string]::IsNullOrWhiteSpace($searchText)) { return }
        
        # Find and highlight all matching tweaks
        $firstMatch = $null
        $highlightBrush = $window.Resources["SearchHighlightColor"]
        $columns = @($col0, $col1, $col2) | Where-Object { $_ -ne $null }
        
        foreach ($column in $columns) {
            foreach ($card in $column.Children) {
                if ($card -is [System.Windows.Controls.Border] -and $card.Child -is [System.Windows.Controls.StackPanel]) {
                    $controlsList = @($card.Child.Children)
                    for ($i = 0; $i -lt $controlsList.Count; $i++) {
                        $control = $controlsList[$i]
                        $matchFound = $false
                        $controlToHighlight = $null
                        
                        if ($control -is [System.Windows.Controls.CheckBox]) {
                            if ($control.Content.ToString().ToLower().Contains($searchText)) {
                                $matchFound = $true
                                $controlToHighlight = $control
                            }
                        }
                        elseif ($control -is [System.Windows.Controls.Border] -and $control.Name -like '*_LabelBorder') {
                            $labelText = if ($control.Child) { $control.Child.Text.ToLower() } else { "" }
                            $comboBox = if ($i + 1 -lt $controlsList.Count -and $controlsList[$i + 1] -is [System.Windows.Controls.ComboBox]) { $controlsList[$i + 1] } else { $null }
                            
                            # Check label text or combo box items
                            if ($labelText.Contains($searchText) -or ($comboBox -and (ComboBoxContainsMatch -comboBox $comboBox -searchText $searchText))) {
                                $matchFound = $true
                                $controlToHighlight = $control
                            }
                        }
                        
                        if ($matchFound -and $controlToHighlight) {
                            $controlToHighlight.Background = $highlightBrush
                            if ($null -eq $firstMatch) { $firstMatch = $controlToHighlight }
                        }
                    }
                }
            }
        }
        
        # Scroll to first match if not visible
        if ($firstMatch -and $tweaksScrollViewer) {
            ScrollToItemIfNotVisible -scrollViewer $tweaksScrollViewer -item $firstMatch -container $tweaksGrid
        }
    })

    # Add Ctrl+F keyboard shortcut to focus search box on current tab
    $window.Add_KeyDown({
        param($evtSender, $e)
        
        # Check if Ctrl+F was pressed
        if ($e.Key -eq [System.Windows.Input.Key]::F -and 
            ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) {
            
            $currentTab = $tabControl.SelectedItem
            
            # Focus AppSearchBox if on App Removal tab
            if ($currentTab.Header -eq "App Removal" -and $appSearchBox) {
                $appSearchBox.Focus()
                $e.Handled = $true
            }
            # Focus TweakSearchBox if on Tweaks tab
            elseif ($currentTab.Header -eq "Tweaks" -and $tweakSearchBox) {
                $tweakSearchBox.Focus()
                $e.Handled = $true
            }
        }
    })

    # Wizard Navigation
    $tabControl = $window.FindName('MainTabControl')
    $previousBtn = $window.FindName('PreviousBtn')
    $nextBtn = $window.FindName('NextBtn')
    $userSelectionCombo = $window.FindName('UserSelectionCombo')
    $userSelectionDescription = $window.FindName('UserSelectionDescription')
    $otherUserPanel = $window.FindName('OtherUserPanel')
    $otherUsernameTextBox = $window.FindName('OtherUsernameTextBox')
    $usernameTextBoxPlaceholder = $window.FindName('UsernameTextBoxPlaceholder')
    $usernameValidationMessage = $window.FindName('UsernameValidationMessage')
    $appRemovalScopeCombo = $window.FindName('AppRemovalScopeCombo')
    $appRemovalScopeDescription = $window.FindName('AppRemovalScopeDescription')
    $appRemovalScopeSection = $window.FindName('AppRemovalScopeSection')
    $appRemovalScopeCurrentUser = $window.FindName('AppRemovalScopeCurrentUser')
    $appRemovalScopeTargetUser = $window.FindName('AppRemovalScopeTargetUser')

    # Navigation button handlers
    function UpdateNavigationButtons {
        $currentIndex = $tabControl.SelectedIndex
        $totalTabs = $tabControl.Items.Count
        
        # Home tab is index 0; hide Back button on splash
        $homeIndex = 0
        $overviewIndex = $totalTabs - 1

        # Navigation button visibility (Home shows Next in corner like other panes)
        if ($currentIndex -eq $homeIndex) {
            $nextBtn.Visibility = 'Visible'
            $previousBtn.Visibility = 'Collapsed'
        } elseif ($currentIndex -eq $overviewIndex) {
            $nextBtn.Visibility = 'Collapsed'
            $previousBtn.Visibility = 'Visible'
        } else {
            $nextBtn.Visibility = 'Visible'
            $previousBtn.Visibility = 'Visible'
        }
        
        # Update progress indicators
        # Tab indices: 0=Home, 1=App Removal, 2=Tweaks, 3=Deployment Settings
        $blueColor = "#0067c0"
        $greyColor = "#808080"
        
        $progressIndicator1 = $window.FindName('ProgressIndicator1') # App Removal
        $progressIndicator2 = $window.FindName('ProgressIndicator2') # Tweaks
        $progressIndicator3 = $window.FindName('ProgressIndicator3') # Deployment Settings
        $bottomNavGrid = $window.FindName('BottomNavGrid')
        
        # GuiFork: No home page - always show bottom nav
        $bottomNavGrid.Visibility = 'Visible'
        
        # Update indicator colors based on current tab (GuiFork: 0=App Removal, 1=Tweaks, 2=Deployment)
        if ($currentIndex -ge 0) {
            $progressIndicator1.Fill = $blueColor
        } else {
            $progressIndicator1.Fill = $greyColor
        }
        
        if ($currentIndex -ge 1) {
            $progressIndicator2.Fill = $blueColor
        } else {
            $progressIndicator2.Fill = $greyColor
        }
        
        if ($currentIndex -ge 2) {
            $progressIndicator3.Fill = $blueColor
        } else {
            $progressIndicator3.Fill = $greyColor
        }
    }

    # Update user selection description and show/hide other user panel
    $userSelectionCombo.Add_SelectionChanged({
        switch ($userSelectionCombo.SelectedIndex) {
            0 { 
                $userSelectionDescription.Text = "Changes will be applied to the currently logged-in user profile."
                $otherUserPanel.Visibility = 'Collapsed'
                $usernameValidationMessage.Text = ""
                # Show "Current user only" option, hide "Target user only" option
                $appRemovalScopeCurrentUser.Visibility = 'Visible'
                $appRemovalScopeTargetUser.Visibility = 'Collapsed'
                # Enable app removal scope selection for current user
                $appRemovalScopeCombo.IsEnabled = $true
                $appRemovalScopeCombo.SelectedIndex = 0
            }
            1 { 
                $userSelectionDescription.Text = "Changes will be applied to a different user profile on this system."
                $otherUserPanel.Visibility = 'Visible'
                $usernameValidationMessage.Text = ""
                # Hide "Current user only" option, show "Target user only" option
                $appRemovalScopeCurrentUser.Visibility = 'Collapsed'
                $appRemovalScopeTargetUser.Visibility = 'Visible'
                # Enable app removal scope selection for other user
                $appRemovalScopeCombo.IsEnabled = $true
                $appRemovalScopeCombo.SelectedIndex = 0
            }
            2 { 
                $userSelectionDescription.Text = "Changes will be applied to the default user template, affecting all new users created after this point. Useful for Sysprep deployment."
                $otherUserPanel.Visibility = 'Collapsed'
                $usernameValidationMessage.Text = ""
                # Hide other user options since they don't apply to default user template
                $appRemovalScopeCurrentUser.Visibility = 'Collapsed'
                $appRemovalScopeTargetUser.Visibility = 'Collapsed'
                # Lock app removal scope to "All users" when applying to sysprep
                $appRemovalScopeCombo.IsEnabled = $false
                $appRemovalScopeCombo.SelectedIndex = 0
            }
        }
    })

    # Helper function to update app removal scope description
    function UpdateAppRemovalScopeDescription {
        $selectedItem = $appRemovalScopeCombo.SelectedItem
        if ($selectedItem) {
            switch ($selectedItem.Content) {
                "All users" { 
                    $appRemovalScopeDescription.Text = "Apps will be removed for all users and from the Windows image to prevent reinstallation for new users."
                }
                "Current user only" { 
                    $appRemovalScopeDescription.Text = "Apps will only be removed for the current user. Other users and new users will not be affected."
                }
                "Target user only" { 
                    $appRemovalScopeDescription.Text = "Apps will only be removed for the specified target user. Other users and new users will not be affected."
                }
            }
        }
    }

    # Update app removal scope description
    $appRemovalScopeCombo.Add_SelectionChanged({
        UpdateAppRemovalScopeDescription
    })

    $otherUsernameTextBox.Add_TextChanged({
        # Show/hide placeholder
        if ([string]::IsNullOrWhiteSpace($otherUsernameTextBox.Text)) {
            $usernameTextBoxPlaceholder.Visibility = 'Visible'
        } else {
            $usernameTextBoxPlaceholder.Visibility = 'Collapsed'
        }
        
        ValidateOtherUsername
    })

    function ValidateOtherUsername {
        # Only validate if "Other User" is selected
        if ($userSelectionCombo.SelectedIndex -ne 1) {
            return $true
        }

        $username = $otherUsernameTextBox.Text.Trim()

        $errorBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#c42b1c"))
        $successBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#28a745"))

        if ($username.Length -eq 0) {
            $usernameValidationMessage.Text = "[X] Please enter a username"
            $usernameValidationMessage.Foreground = $errorBrush
            return $false
        }
        
        if ($username -eq $env:USERNAME) {
            $usernameValidationMessage.Text = "[X] Cannot enter your own username, use 'Current User' option instead"
            $usernameValidationMessage.Foreground = $errorBrush
            return $false
        }
        
        $userExists = CheckIfUserExists -Username $username

        if ($userExists) {
            $usernameValidationMessage.Text = "[OK] User found: $username"
            $usernameValidationMessage.Foreground = $successBrush
            return $true
        }

        $usernameValidationMessage.Text = "[X] User not found, please enter a valid username"
        $usernameValidationMessage.Foreground = $errorBrush
        return $false
    }

    function GenerateOverview {
        # Load Features.json
        $featuresJson = LoadJsonFile -filePath $script:FeaturesFilePath -expectedVersion "1.0"
        
        $changesList = @()
        
        # Collect selected apps
        $selectedAppsCount = 0
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedAppsCount++
            }
        }
        if ($selectedAppsCount -gt 0) {
            $changesList += "Remove $selectedAppsCount application(s)"
        }
        
        # Update app removal scope section based on whether apps are selected
        if ($selectedAppsCount -gt 0) {
            # Enable app removal scope selection (unless locked by sysprep mode)
            if ($userSelectionCombo.SelectedIndex -ne 2) {
                $appRemovalScopeCombo.IsEnabled = $true
            }
            $appRemovalScopeSection.Opacity = 1.0
            UpdateAppRemovalScopeDescription
        }
        else {
            # Disable app removal scope selection when no apps selected
            $appRemovalScopeCombo.IsEnabled = $false
            $appRemovalScopeSection.Opacity = 0.5
            $appRemovalScopeDescription.Text = "No apps selected for removal."
        }
        
        # Collect all ComboBox/CheckBox selections from dynamically created controls
        if ($script:UiControlMappings) {
            foreach ($mappingKey in $script:UiControlMappings.Keys) {
                $control = $window.FindName($mappingKey)
                $mapping = $script:UiControlMappings[$mappingKey]
                $isSelected = $false
                $isRevert = $false
                if ($control -is [System.Windows.Controls.CheckBox]) {
                    if ($mapping.IsSystemApplied) {
                        $isSelected = $control.IsChecked -eq $true
                        $isRevert = $control.IsChecked -eq $false
                    }
                    else {
                        $isSelected = $control.IsChecked -eq $true
                    }
                }
                elseif ($control -is [System.Windows.Controls.ComboBox]) {
                    $isSelected = $control.SelectedIndex -gt 0 -and (-not $mapping.IsSystemApplied -or $control.SelectedIndex -ne $mapping.AppliedIndex)
                }
                if ($control -and $isSelected) {
                    if ($mapping.Type -eq 'group') {
                        $selectedValue = $mapping.Values[$control.SelectedIndex - 1]
                        foreach ($fid in $selectedValue.FeatureIds) {
                            $feature = $featuresJson.Features | Where-Object { $_.FeatureId -eq $fid }
                            if ($feature) { $changesList += ($feature.Action + ' ' + $feature.Label) }
                        }
                    }
                    elseif ($mapping.Type -eq 'feature') {
                        $feature = $featuresJson.Features | Where-Object { $_.FeatureId -eq $mapping.FeatureId } | Select-Object -First 1
                        if ($feature) { $changesList += ($feature.Action + ' ' + $feature.Label) }
                    }
                }
                if ($control -and $isRevert -and $mapping.Type -eq 'feature') {
                    $feature = $featuresJson.Features | Where-Object { $_.FeatureId -eq $mapping.FeatureId } | Select-Object -First 1
                    if ($feature -and $feature.RegistryUndoKey) { $changesList += ("Revert " + $feature.Action + ' ' + $feature.Label) }
                }
            }
        }
        
        return $changesList
    }

    function ShowChangesOverview {
        $changesList = GenerateOverview

        if ($changesList.Count -eq 0) {
            Show-MessageBox -Message 'No changes have been selected.' -Title 'Selected Changes' -Button 'OK' -Icon 'Information'
            return
        }

        $message = ($changesList | ForEach-Object { "$([char]0x2022) $_" }) -join "`n"
        Show-MessageBox -Message $message -Title 'Selected Changes' -Button 'OK' -Icon 'None' -Width 600
    }

    $previousBtn.Add_Click({        
        if ($tabControl.SelectedIndex -gt 0) {
            $tabControl.SelectedIndex--
            UpdateNavigationButtons
        }
    })

    $nextBtn.Add_Click({        
        if ($tabControl.SelectedIndex -lt ($tabControl.Items.Count - 1)) {
            $tabControl.SelectedIndex++
            if ($tabControl.SelectedIndex -eq 1 -and -not $script:AppsListLoadedForTab) {
                $script:AppsListLoadedForTab = $true
                LoadAppsIntoMainUI
            }
            UpdateNavigationButtons
        }
    })

    # Handle Home Update Connections button (same as C command in VM_Dashboard.ps1)
    $homeConnUpdateBtn = $window.FindName('HomeConnUpdateBtn')
    if ($homeConnUpdateBtn) {
        $homeConnUpdateBtn.Add_Click({
            $homeConnUpdateBtn.IsEnabled = $false
            $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{
                $errs = @()
                try {
                    $admin = Get-LocalUser | Where-Object { $_.SID -like '*-500' }
                    if ($admin) {
                        Enable-LocalUser -Name $admin.Name -ErrorAction Stop
                    }
                } catch { $errs += "Admin: $_" }
                try {
                    reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v "LimitBlankPasswordUse" /t REG_DWORD /d 0 /f 2>$null | Out-Null
                } catch { $errs += "LimitBlankPasswordUse: $_" }
                try {
                    Set-Service KeyIso -StartupType Automatic -ErrorAction Stop
                    Start-Service KeyIso -ErrorAction SilentlyContinue
                } catch { $errs += "KeyIso: $_" }
                try {
                    Set-Service WinRM -StartupType Automatic -ErrorAction Stop
                    & winrm quickconfig -quiet 2>$null | Out-Null
                } catch { $errs += "WinRM: $_" }
                $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Normal, [action]{
                    $homeConnUpdateBtn.IsEnabled = $true
                    Update-ConnectionSettingsOnly
                    if ($errs.Count -gt 0) {
                        Show-MessageBox -Message "Update Connections completed with errors:`n`n$($errs -join "`n")" -Title "Update Connections" -Button 'OK' -Icon 'Warning' | Out-Null
                    } else {
                        Show-MessageBox -Message "Connections updated successfully." -Title "Update Connections" -Button 'OK' -Icon 'Information' | Out-Null
                    }
                })
            }) | Out-Null
        })
    }

    # Handle Home Execute button - run checked installation options in series
    $script:ImagingScriptsPath = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) "Imaging_Scripts"
    $homeExecRunBtn = $window.FindName('HomeExecRunBtn')
    $runHomeExecute = {
        $off = $script:ImagingScriptsPath
        if (-not (Test-Path $off)) {
            Show-MessageBox -Message "Imaging scripts path not found: $off" -Title "Error" -Button 'OK' -Icon 'Warning' | Out-Null
            return
        }
        $tasks = @()
        
        if (($window.FindName('HomeExec1')).IsChecked) { $tasks += @{ N='Customize'; C={ $p = $script:ImagingScriptsPath; $bat = "$p\1_Customize.bat"; if (Test-Path $bat) { cmd /c "`"$bat`"" } else { & "$p\1_Customize.ps1" } } } }
        if (($window.FindName('HomeExec2')).IsChecked) { $tasks += @{ N='Scoop'; C={ & "$($script:ImagingScriptsPath)\2_Scoop.ps1" } } }
        if (($window.FindName('HomeExec3')).IsChecked) { $tasks += @{ N='MSVC Build Tools'; C={ & "$($script:ImagingScriptsPath)\3_MSVC.ps1" } } }
        if (($window.FindName('HomeExec4')).IsChecked) { $tasks += @{ N='ALL System Apps'; C={ & "$($script:ImagingScriptsPath)\4_System_Apps.ps1" -App "All" } } }
        if (($window.FindName('HomeExec41')).IsChecked) { $tasks += @{ N='Chrome'; C={ & "$($script:ImagingScriptsPath)\4_System_Apps.ps1" -App "Chrome" } } }
        if (($window.FindName('HomeExec42')).IsChecked) { $tasks += @{ N='VS Code'; C={ & "$($script:ImagingScriptsPath)\4_System_Apps.ps1" -App "VSCode" } } }
        if (($window.FindName('HomeExec43')).IsChecked) { $tasks += @{ N='Go'; C={ & "$($script:ImagingScriptsPath)\4_System_Apps.ps1" -App "Go" } } }
        if (($window.FindName('HomeExec44')).IsChecked) { $tasks += @{ N='Git'; C={ & "$($script:ImagingScriptsPath)\4_System_Apps.ps1" -App "Git" } } }
        if (($window.FindName('HomeExec45')).IsChecked) { $tasks += @{ N='GitHub CLI'; C={ & "$($script:ImagingScriptsPath)\4_System_Apps.ps1" -App "GitHubCLI" } } }
        if (($window.FindName('HomeExec46')).IsChecked) { $tasks += @{ N='UniGetUI'; C={ & "$($script:ImagingScriptsPath)\4_System_Apps.ps1" -App "UniGetUI" } } }
        if (($window.FindName('HomeExec5')).IsChecked) { $tasks += @{ N='Rust'; C={ & "$($script:ImagingScriptsPath)\5_Rust_Finish.ps1" } } }
        if (($window.FindName('HomeExec6')).IsChecked) { $tasks += @{ N='Finalize'; C={ & "$($script:ImagingScriptsPath)\7_Finalize.ps1" } } }
        if ($tasks.Count -eq 0) {
            Show-MessageBox -Message "Select at least one execution option." -Title "Execute" -Button 'OK' -Icon 'Information' | Out-Null
            return
        }
        $homeExecRunBtn.IsEnabled = $false
        $script:PendingHomeTasks = $tasks
        $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{
            try {
                $h = [User32_ShowWindow]::GetConsoleWindow()
                if ($h -ne [IntPtr]::Zero) {
                    [User32_ShowWindow]::ShowWindow($h, [User32_ShowWindow]::SW_RESTORE) | Out-Null
                    [User32_ShowWindow]::ForceActivate($h)
                }
            } catch { }
            foreach ($t in $script:PendingHomeTasks) {
                try {
                    & $t.C
                } catch {
                    Show-MessageBox -Message "$($t.N) failed: $_" -Title "Error" -Button 'OK' -Icon 'Warning' | Out-Null
                }
            }
            $script:PendingHomeTasks = $null
            $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Normal, [action]{ $homeExecRunBtn.IsEnabled = $true })
            $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Normal, [action]{ Update-HomeDashboard })
        }) | Out-Null
    }
    if ($homeExecRunBtn) { $homeExecRunBtn.Add_Click($runHomeExecute) }

    # ALL System Apps sync: HomeExec4 <-> HomeExec41..46
    $homeExec4 = $window.FindName('HomeExec4')
    $homeExec41 = $window.FindName('HomeExec41')
    $homeExec42 = $window.FindName('HomeExec42')
    $homeExec43 = $window.FindName('HomeExec43')
    $homeExec44 = $window.FindName('HomeExec44')
    $homeExec45 = $window.FindName('HomeExec45')
    $homeExec46 = $window.FindName('HomeExec46')
    $systemAppChecks = @($homeExec41, $homeExec42, $homeExec43, $homeExec44, $homeExec45, $homeExec46)
    $script:HomeExec4Updating = $false
    if ($homeExec4 -and ($systemAppChecks | Where-Object { $_ } | Measure-Object).Count -eq 6) {
        $homeExec4.Add_Checked({
            if ($script:HomeExec4Updating) { return }
            $script:HomeExec4Updating = $true
            try {
                foreach ($c in $systemAppChecks) { $c.IsChecked = $true }
            } finally { $script:HomeExec4Updating = $false }
        })
        $homeExec4.Add_Unchecked({
            if ($script:HomeExec4Updating) { return }
            $script:HomeExec4Updating = $true
            try {
                foreach ($c in $systemAppChecks) { $c.IsChecked = $false }
            } finally { $script:HomeExec4Updating = $false }
        })
        $updateHomeExec4FromChildren = {
            if ($script:HomeExec4Updating) { return }
            $allChecked = ($systemAppChecks | Where-Object { $_.IsChecked -eq $true } | Measure-Object).Count -eq 6
            $script:HomeExec4Updating = $true
            try { $homeExec4.IsChecked = $allChecked } finally { $script:HomeExec4Updating = $false }
        }
        foreach ($c in $systemAppChecks) { $c.Add_Checked($updateHomeExec4FromChildren); $c.Add_Unchecked($updateHomeExec4FromChildren) }
    }

    # Handle Home Load Profiles card
    $homeImportJsonPath = $window.FindName('HomeImportJsonPath')
    $homeImportJsonBrowseBtn = $window.FindName('HomeImportJsonBrowseBtn')
    $homeImportJsonLoadBtn = $window.FindName('HomeImportJsonLoadBtn')
    $homeAppsProfileCombo = $window.FindName('HomeAppsProfileCombo')
    $homeAppsProfileLoadBtn = $window.FindName('HomeAppsProfileLoadBtn')
    $homeTweaksProfileCombo = $window.FindName('HomeTweaksProfileCombo')
    $homeTweaksProfileLoadBtn = $window.FindName('HomeTweaksProfileLoadBtn')
    if ($homeImportJsonBrowseBtn) {
        $homeImportJsonBrowseBtn.Add_Click({
            $dlg = New-Object Microsoft.Win32.OpenFileDialog
            $dlg.Filter = 'JSON files (*.json)|*.json|All files (*.*)|*.*'
            if ($dlg.ShowDialog() -eq $true) {
                $homeImportJsonPath.Text = $dlg.FileName
            }
        })
    }
    if ($homeImportJsonLoadBtn -and $homeImportJsonPath) {
        $homeImportJsonLoadBtn.Add_Click({
            $path = $homeImportJsonPath.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($path) -or $path -eq '(No file selected)') {
                Show-MessageBox -Message "Select a JSON file first (Browse)." -Title "Import" -Button 'OK' -Icon 'Information' | Out-Null
                return
            }
            if (-not (Test-Path $path)) {
                Show-MessageBox -Message "File not found: $path" -Title "Import" -Button 'OK' -Icon 'Warning' | Out-Null
                return
            }
            try {
                $imported = Get-Content -Path $path -Raw | ConvertFrom-Json
                if (-not $imported.Settings) {
                    Show-MessageBox -Message "Invalid settings file format." -Title "Import" -Button 'OK' -Icon 'Warning' | Out-Null
                    return
                }
                $settingsObj = @{ Version = $imported.Version; Settings = @() }
                foreach ($s in $imported.Settings) {
                    $settingsObj.Settings += @{ Name = $s.Name; Value = $s.Value }
                }
                ApplySettingsToUiControls -window $window -settingsJson $settingsObj -uiControlMappings $script:UiControlMappings
                if ($settingsObj.Settings | Where-Object { $_.Name -eq 'Apps' }) {
                    $appsSetting = $settingsObj.Settings | Where-Object { $_.Name -eq 'Apps' } | Select-Object -First 1
                    $appIds = $appsSetting.Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    $appsPanelRef = $window.FindName('AppSelectionPanel')
                    foreach ($child in $appsPanelRef.Children) {
                        if ($child -is [System.Windows.Controls.CheckBox] -and $child.Tag) {
                            $child.IsChecked = $appIds -contains $child.Tag
                        }
                    }
                }
                $restorePointCheckBox = $window.FindName('RestorePointCheckBox')
                if ($restorePointCheckBox -and ($settingsObj.Settings | Where-Object { $_.Name -eq 'CreateRestorePoint' })) {
                    $restorePointCheckBox.IsChecked = $true
                }
                $userSelectionCombo = $window.FindName('UserSelectionCombo')
                $otherUsernameTextBox = $window.FindName('OtherUsernameTextBox')
                $userSetting = $settingsObj.Settings | Where-Object { $_.Name -eq 'User' } | Select-Object -First 1
                $sysprepSetting = $settingsObj.Settings | Where-Object { $_.Name -eq 'Sysprep' } | Select-Object -First 1
                if ($sysprepSetting) { $userSelectionCombo.SelectedIndex = 2 }
                elseif ($userSetting) { $userSelectionCombo.SelectedIndex = 1; if ($otherUsernameTextBox) { $otherUsernameTextBox.Text = $userSetting.Value } }
                else { $userSelectionCombo.SelectedIndex = 0 }
                $scopeSetting = $settingsObj.Settings | Where-Object { $_.Name -eq 'AppRemovalTarget' } | Select-Object -First 1
                $appRemovalScopeCombo = $window.FindName('AppRemovalScopeCombo')
                if ($appRemovalScopeCombo -and $scopeSetting) {
                    switch ($scopeSetting.Value) {
                        'CurrentUser' { $appRemovalScopeCombo.SelectedIndex = 1 }
                        'AllUsers' { $appRemovalScopeCombo.SelectedIndex = 0 }
                        default { $appRemovalScopeCombo.SelectedIndex = 2; if ($otherUsernameTextBox -and $scopeSetting.Value) { $otherUsernameTextBox.Text = $scopeSetting.Value } }
                    }
                }
                Show-MessageBox -Message "Settings imported from:`n$path" -Title "Import" -Button 'OK' -Icon 'Information' | Out-Null
            } catch {
                Show-MessageBox -Message "Failed to import: $_" -Title "Import Error" -Button 'OK' -Icon 'Warning' | Out-Null
            }
        })
    }
    if ($homeAppsProfileLoadBtn -and $homeAppsProfileCombo) {
        $homeAppsProfileLoadBtn.Add_Click({
            $item = $homeAppsProfileCombo.SelectedItem
            if (-not $item -or $homeAppsProfileCombo.SelectedIndex -eq 0) {
                Show-MessageBox -Message "Select a profile first." -Title "App Profile" -Button 'OK' -Icon 'Information' | Out-Null
                return
            }
            $profileName = $item.Content
            $appIds = Import-AppProfile -ProfileName $profileName
            if ($appIds.Count -eq 0) {
                Show-MessageBox -Message "Profile '$profileName' is empty or could not be loaded." -Title "App Profile" -Button 'OK' -Icon 'Warning' | Out-Null
                return
            }
            Set-AppProfileToUi -AppIds $appIds -Replace
        })
    }
    if ($homeTweaksProfileLoadBtn -and $homeTweaksProfileCombo) {
        $homeTweaksProfileLoadBtn.Add_Click({
            $item = $homeTweaksProfileCombo.SelectedItem
            if (-not $item -or $homeTweaksProfileCombo.SelectedIndex -eq 0) {
                Show-MessageBox -Message "Select a profile first." -Title "Tweak Profile" -Button 'OK' -Icon 'Information' | Out-Null
                return
            }
            $profileJson = Import-TweakProfile -ProfileName $item.Content
            if (-not $profileJson -or -not $profileJson.Settings) {
                Show-MessageBox -Message "Profile could not be loaded or is empty." -Title "Tweak Profile" -Button 'OK' -Icon 'Warning' | Out-Null
                return
            }
            ApplySettingsToUiControls -window $window -settingsJson $profileJson -uiControlMappings $script:UiControlMappings
        })
    }

    # Handle Review Changes link button
    $reviewChangesBtn = $window.FindName('ReviewChangesBtn')
    $reviewChangesBtn.Add_Click({
        ShowChangesOverview
    })

    # Handle Apply Changes button - validates and immediately starts applying changes
    $deploymentApplyBtn = $window.FindName('DeploymentApplyBtn')
    $deploymentApplyBtn.Add_Click({
        if (-not (ValidateOtherUsername)) {
            Show-MessageBox -Message "Please enter a valid username." -Title "Invalid Username" -Button 'OK' -Icon 'Warning' | Out-Null
            return
        }

        # App Removal - collect selected apps from integrated UI
        $selectedApps = @()
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedApps += $child.Tag
            }
        }
        
        if ($selectedApps.Count -gt 0) {
            # Check if Microsoft Store is selected
            if ($selectedApps -contains "Microsoft.WindowsStore") {
                $result = Show-MessageBox -Message 'Are you sure you wish to uninstall the Microsoft Store? This app cannot easily be reinstalled.' -Title 'Are you sure?' -Button 'YesNo' -Icon 'Warning'

                if ($result -eq 'No') {
                    return
                }
            }
            
            AddParameter 'RemoveApps'
            AddParameter 'Apps' ($selectedApps -join ',')
            
            # Add app removal target parameter based on selection
            $selectedScopeItem = $appRemovalScopeCombo.SelectedItem
            if ($selectedScopeItem) {
                switch ($selectedScopeItem.Content) {
                    "All users" { 
                        AddParameter 'AppRemovalTarget' 'AllUsers'
                    }
                    "Current user only" { 
                        AddParameter 'AppRemovalTarget' 'CurrentUser'
                    }
                    "Target user only" { 
                        # Use the target username from Other User panel
                        AddParameter 'AppRemovalTarget' ($otherUsernameTextBox.Text.Trim())
                    }
                }
            }
        }

        # Apply dynamic tweaks selections
        if ($script:UiControlMappings) {
            foreach ($mappingKey in $script:UiControlMappings.Keys) {
                $control = $window.FindName($mappingKey)
                $mapping = $script:UiControlMappings[$mappingKey]
                $isSelected = $false
                $isRevert = $false
                $selectedIndex = 0
                if ($control -is [System.Windows.Controls.CheckBox]) {
                    if ($mapping.IsSystemApplied) {
                        $isSelected = $control.IsChecked -eq $true
                        $isRevert = $control.IsChecked -eq $false
                    }
                    else {
                        $isSelected = $control.IsChecked -eq $true
                    }
                    $selectedIndex = if ($isSelected) { 1 } else { 0 }
                }
                elseif ($control -is [System.Windows.Controls.ComboBox]) {
                    $isSelected = $control.SelectedIndex -gt 0 -and (-not $mapping.IsSystemApplied -or $control.SelectedIndex -ne $mapping.AppliedIndex)
                    $selectedIndex = $control.SelectedIndex
                }
                if ($control -and $isSelected) {
                    if ($mapping.Type -eq 'group') {
                        if ($selectedIndex -gt 0 -and $selectedIndex -le $mapping.Values.Count) {
                            $selectedValue = $mapping.Values[$selectedIndex - 1]
                            foreach ($fid in $selectedValue.FeatureIds) { AddParameter $fid }
                        }
                    }
                    elseif ($mapping.Type -eq 'feature') {
                        AddParameter $mapping.FeatureId
                    }
                }
                if ($control -and $isRevert -and $mapping.Type -eq 'feature') {
                    $featuresJson = LoadJsonFile -filePath $script:FeaturesFilePath -expectedVersion "1.0"
                    $feat = $featuresJson.Features | Where-Object { $_.FeatureId -eq $mapping.FeatureId } | Select-Object -First 1
                    if ($feat -and $feat.RegistryUndoKey) {
                        AddParameter "Revert_$($mapping.FeatureId)"
                    }
                }
            }
        }

        $controlParamsCount = 0
        foreach ($Param in $script:ControlParams) {
            if ($script:Params.ContainsKey($Param)) {
                $controlParamsCount++
            }
        }

        # Check if any changes were selected
        $totalChanges = $script:Params.Count - $controlParamsCount

        # Apps parameter does not count as a change itself
        if ($script:Params.ContainsKey('Apps')) {
            $totalChanges = $totalChanges - 1
        }

        if ($totalChanges -eq 0) {
            Show-MessageBox -Message 'No changes have been selected, please select at least one option to proceed.' -Title 'No Changes Selected' -Button 'OK' -Icon 'Information'
            return
        }

        # Check RestorePointCheckBox
        $restorePointCheckBox = $window.FindName('RestorePointCheckBox')
        if ($restorePointCheckBox -and $restorePointCheckBox.IsChecked) {
            AddParameter 'CreateRestorePoint'
        }
        
        # Store selected user mode
        switch ($userSelectionCombo.SelectedIndex) {
            1 { AddParameter User ($otherUsernameTextBox.Text.Trim()) }
            2 { AddParameter Sysprep }
        }

        SaveSettings

        # Check if user wants to restart explorer
        $restartExplorerCheckBox = $window.FindName('RestartExplorerCheckBox')
        $shouldRestartExplorer = $restartExplorerCheckBox -and $restartExplorerCheckBox.IsChecked

        # Show the apply changes window
        Show-ApplyModal -Owner $window -RestartExplorer $shouldRestartExplorer

        # Close the main window after the apply dialog closes
        $window.Close()
    })

    # Handle Export App List link
    $exportAppListLink = $window.FindName('ExportAppListLink')
    $exportAppListLink.Add_MouseLeftButtonUp({
        $apps = @()
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.Tag) {
                $apps += [PSCustomObject]@{
                    AppId            = $child.Tag
                    FriendlyName     = $child.AppName
                    Description      = $child.AppDescription
                    IsChecked        = [bool]$child.IsChecked
                    SelectedByDefault = $child.SelectedByDefault
                }
            }
        }
        if ($apps.Count -eq 0) {
            Show-MessageBox -Message 'No apps in the current list to export.' -Title 'Export' -Button 'OK' -Icon 'Information' | Out-Null
            return
        }
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = 'JSON files (*.json)|*.json|CSV files (*.csv)|*.csv|All files (*.*)|*.*'
        $dlg.FileName = 'AppList'
        if ($dlg.ShowDialog()) {
            try {
                if ($dlg.FileName -like '*.csv') {
                    $apps | Export-Csv -Path $dlg.FileName -NoTypeInformation -Encoding UTF8
                } else {
                    $apps | ConvertTo-Json -Depth 5 | Set-Content -Path $dlg.FileName -Encoding UTF8
                }
                Show-MessageBox -Message "App list exported to:`n$($dlg.FileName)" -Title "Export" -Button 'OK' -Icon 'Information' | Out-Null
            } catch {
                Show-MessageBox -Message "Failed to export: $_" -Title "Export Error" -Button 'OK' -Icon 'Warning' | Out-Null
            }
        }
    })

    # Handle Export CLI button - build CLI command from current selections and copy to clipboard
    $deploymentExportCliBtn = $window.FindName('DeploymentExportCliBtn')
    $deploymentExportCliBtn.Add_Click({
        if (-not (ValidateOtherUsername)) {
            Show-MessageBox -Message "Please enter a valid username." -Title "Invalid Username" -Button 'OK' -Icon 'Warning' | Out-Null
            return
        }
        $exportParams = @{}
        $selectedApps = @()
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedApps += $child.Tag
            }
        }
        if ($selectedApps.Count -gt 0) {
            $exportParams['RemoveApps'] = $true
            $exportParams['Apps'] = $selectedApps -join ','
            $selectedScopeItem = $appRemovalScopeCombo.SelectedItem
            if ($selectedScopeItem) {
                switch ($selectedScopeItem.Content) {
                    "All users" { $exportParams['AppRemovalTarget'] = 'AllUsers' }
                    "Current user only" { $exportParams['AppRemovalTarget'] = 'CurrentUser' }
                    "Target user only" { $exportParams['AppRemovalTarget'] = $otherUsernameTextBox.Text.Trim() }
                }
            }
        }
        if ($script:UiControlMappings) {
            foreach ($mappingKey in $script:UiControlMappings.Keys) {
                $control = $window.FindName($mappingKey)
                $mapping = $script:UiControlMappings[$mappingKey]
                $isSelected = $false
                $isRevert = $false
                $selectedIndex = 0
                if ($control -is [System.Windows.Controls.CheckBox]) {
                    if ($mapping.IsSystemApplied) {
                        $isSelected = $control.IsChecked -eq $true
                        $isRevert = $control.IsChecked -eq $false
                    } else { $isSelected = $control.IsChecked -eq $true }
                    $selectedIndex = if ($isSelected) { 1 } else { 0 }
                }
                elseif ($control -is [System.Windows.Controls.ComboBox]) {
                    $isSelected = $control.SelectedIndex -gt 0 -and (-not $mapping.IsSystemApplied -or $control.SelectedIndex -ne $mapping.AppliedIndex)
                    $selectedIndex = $control.SelectedIndex
                }
                if ($control -and $isSelected) {
                    if ($mapping.Type -eq 'group') {
                        if ($selectedIndex -gt 0 -and $selectedIndex -le $mapping.Values.Count) {
                            foreach ($fid in $mapping.Values[$selectedIndex - 1].FeatureIds) { $exportParams[$fid] = $true }
                        }
                    }
                    elseif ($mapping.Type -eq 'feature') { $exportParams[$mapping.FeatureId] = $true }
                }
                if ($control -and $isRevert -and $mapping.Type -eq 'feature') {
                    $featuresJson = LoadJsonFile -filePath $script:FeaturesFilePath -expectedVersion "1.0"
                    $feat = $featuresJson.Features | Where-Object { $_.FeatureId -eq $mapping.FeatureId } | Select-Object -First 1
                    if ($feat -and $feat.RegistryUndoKey) { $exportParams["Revert_$($mapping.FeatureId)"] = $true }
                }
            }
        }
        $restorePointCheckBox = $window.FindName('RestorePointCheckBox')
        if ($restorePointCheckBox -and $restorePointCheckBox.IsChecked) { $exportParams['CreateRestorePoint'] = $true }
        switch ($userSelectionCombo.SelectedIndex) {
            1 { $exportParams['User'] = $otherUsernameTextBox.Text.Trim() }
            2 { $exportParams['Sysprep'] = $true }
        }
        $totalChanges = ($exportParams.Keys | Where-Object { $script:ControlParams -notcontains $_ }).Count
        if ($exportParams.ContainsKey('Apps')) { $totalChanges-- }
        if ($totalChanges -eq 0) {
            Show-MessageBox -Message 'No changes have been selected. Select at least one option to export.' -Title 'No Changes Selected' -Button 'OK' -Icon 'Information' | Out-Null
            return
        }
        $scriptPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "GoldenImager.ps1"
        $argList = @()
        foreach ($key in $exportParams.Keys) {
            if ($script:ControlParams -contains $key) { continue }
            if ($exportParams[$key] -eq $true) {
                $argList += "-$key"
            } else {
                $argList += "-$key", "`"$($exportParams[$key])`""
            }
        }
        $cliCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $($argList -join ' ')"
        try {
            [System.Windows.Clipboard]::SetText($cliCmd)
            Show-MessageBox -Message "CLI command copied to clipboard. Run in an elevated PowerShell terminal.`n`n$cliCmd" -Title "Export CLI" -Button 'OK' -Icon 'Information' -Width 600 | Out-Null
        } catch {
            Show-MessageBox -Message "Command (clipboard copy failed):`n`n$cliCmd" -Title "Export CLI" -Button 'OK' -Icon 'Information' -Width 600 | Out-Null
        }
    })

    # Refresh only Connection Settings (LimitBlank, WinRM, KeyIso, Admin) - does not touch Stages Audit
    function Update-ConnectionSettingsOnly {
        $connLimit = $window.FindName('HomeConnLimitBlank')
        $connWinRM = $window.FindName('HomeConnWinRM')
        $connKeyIso = $window.FindName('HomeConnKeyIso')
        $connAdmin = $window.FindName('HomeConnAdmin')
        $connSpinner = $window.FindName('HomeConnSpinner')
        $connContent = $window.FindName('HomeConnContent')
        if (-not $connLimit -or -not $connSpinner) { return }
        if ($connSpinner) { $connSpinner.Visibility = 'Visible' }
        if ($connContent) { $connContent.Visibility = 'Collapsed' }
        $runConnAudit = {
            Import-Module Microsoft.PowerShell.LocalAccounts -ErrorAction SilentlyContinue
            $conn = @{ LimitBlank = $null; WinRM = $null; KeyIso = $null; Admin = $null }
            try { $val = (Get-ItemPropertyValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'LimitBlankPasswordUse' -ErrorAction Stop).ToString(); $conn.LimitBlank = ($val -eq '0') } catch { }
            try { $svc = Get-Service -Name WinRM -ErrorAction Stop; $conn.WinRM = "$($svc.Status) ($($svc.StartType))" -like 'Running*Auto*' } catch { }
            try { $svc = Get-Service -Name KeyIso -ErrorAction Stop; $conn.KeyIso = "$($svc.Status) ($($svc.StartType))" -like 'Running*Auto*' } catch { }
            try { $admin = Get-LocalUser | Where-Object { $_.SID -like '*-500' }; $conn.Admin = ($admin -and $admin.Enabled) } catch { }
            $conn
        }
        $result = Invoke-NonBlocking -ScriptBlock $runConnAudit
        $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Normal, [action]{
            if ($result) {
                $connLimit.IsChecked = $result.LimitBlank
                $connWinRM.IsChecked = $result.WinRM
                $connKeyIso.IsChecked = $result.KeyIso
                $connAdmin.IsChecked = $result.Admin
            }
            if ($connSpinner) { $connSpinner.Visibility = 'Collapsed' }
            if ($connContent) { $connContent.Visibility = 'Visible' }
        })
    }

    # Populate Home dashboard (Connection Settings + Stages Audit) from VM_Dashboard logic
    function Update-HomeDashboard {
        # #region agent log
        $dbgLog = Join-Path $env:TEMP 'debug-ba5e25.log'
        try { Add-Content -Path $dbgLog -Value (@{sessionId='ba5e25';location='Update-HomeDashboard:entry';message='Update-HomeDashboard called';data=@{};timestamp=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()} | ConvertTo-Json -Compress) -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }
        # #endregion
        $connLimit = $window.FindName('HomeConnLimitBlank')
        $connWinRM = $window.FindName('HomeConnWinRM')
        $connKeyIso = $window.FindName('HomeConnKeyIso')
        $connAdmin = $window.FindName('HomeConnAdmin')
        $connSpinner = $window.FindName('HomeConnSpinner')
        $stagesPanel = $window.FindName('HomeStagesAuditPanel')
        $stagesSpinner = $window.FindName('HomeStagesAuditSpinner')
        $spinnerSelector = $window.FindName('HomeSpinnerSelector')

        if (-not $connLimit -or -not $stagesPanel) {
            return
        }

        # Update Spinner styles based on selection
        $styleKey = "$($script:SpinnerStyle)Style"
        if ($spinnerSelector -and $spinnerSelector.Text) {
            $styleKey = "$($spinnerSelector.Text)Style"
        }
        try {
            $style = $window.Resources[$styleKey]
            if ($style) {
                if ($connSpinner) { $connSpinner.Style = $style }
                if ($stagesSpinner) { $stagesSpinner.Style = $style }
            }
        } catch { }

        # Gate Audit Debug card behind -debug flag
        $debugCard = $window.FindName('HomeAuditDebugCard')
        if ($debugCard) {
            $debugCard.Visibility = if ($script:Params.ContainsKey('Debug')) { 'Visible' } else { 'Collapsed' }
        }

        # Connection Settings - spinner visible
        $connContent = $window.FindName('HomeConnContent')
        if ($connSpinner) { $connSpinner.Visibility = 'Visible' }
        if ($connContent) { $connContent.Visibility = 'Collapsed' }

        # Load Profiles
        try {
            $homeAppsCombo = $window.FindName('HomeAppsProfileCombo')
            if ($homeAppsCombo) {
                $homeAppsCombo.Items.Clear()
                $homeAppsCombo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = "(No profile selected)" })) | Out-Null
                foreach ($name in Get-AppProfileList) {
                    $homeAppsCombo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = $name })) | Out-Null
                }
                $homeAppsCombo.SelectedIndex = 0
            }
            $homeTweaksCombo = $window.FindName('HomeTweaksProfileCombo')
            if ($homeTweaksCombo) {
                $homeTweaksCombo.Items.Clear()
                $homeTweaksCombo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = "(No profile selected)" })) | Out-Null
                foreach ($name in Get-TweakProfileList) {
                    $homeTweaksCombo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = $name })) | Out-Null
                }
                $homeTweaksCombo.SelectedIndex = 0
            }
        } catch { }

        # Stages Audit - spinner visible
        $stagesContent = $window.FindName('HomeStagesAuditContent')
        if ($stagesSpinner) { $stagesSpinner.Visibility = 'Visible' }
        if ($stagesContent) { $stagesContent.Visibility = 'Collapsed' }
        $apps = @(
            @{ N='PowerShell 7'; Reg='PowerShell 7'; Exe='pwsh'; Lnk='PowerShell 7'; NoPath=$false; NoReg=$false; NoLnk=$false; FileCheck='C:\Program Files\PowerShell\7\pwsh.exe' },
            @{ N='Scoop'; Reg=$null; Exe='scoop'; Lnk=$null; NoPath=$false; NoReg=$true; NoLnk=$true; FileCheck='C:\Scoop\shims\scoop.ps1' },
            @{ N='MSVC Build Tools'; Reg='Visual Studio Build Tools'; Exe=$null; Lnk=$null; NoPath=$true; NoReg=$false; NoLnk=$true; FileCheck="${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" },
            @{ N='Chrome'; Reg='Google Chrome'; Exe=$null; Lnk='Chrome'; NoPath=$true; NoReg=$false; NoLnk=$false; FileCheck='C:\Program Files\Google\Chrome\Application\chrome.exe' },
            @{ N='VS Code'; Reg='Visual Studio Code'; Exe='code'; Lnk='Visual Studio Code'; NoPath=$false; NoReg=$false; NoLnk=$false; FileCheck='C:\Program Files\Microsoft VS Code\bin\code.cmd' },
            @{ N='Go'; Reg='Go Programming Language'; Exe='go'; Lnk=$null; NoPath=$false; NoReg=$false; NoLnk=$true; FileCheck='C:\Program Files\Go\bin\go.exe' },
            @{ N='Git'; Reg='Git'; Exe='git'; Lnk='Git'; NoPath=$false; NoReg=$false; NoLnk=$false; FileCheck='C:\Program Files\Git\bin\git.exe' },
            @{ N='GitHub CLI'; Reg='GitHub CLI'; Exe='gh'; Lnk=$null; NoPath=$false; NoReg=$false; NoLnk=$true; FileCheck='C:\Program Files\GitHub CLI\gh.exe' },
            @{ N='UniGetUI'; Reg='UniGetUI'; Exe='unigetui'; Lnk='UniGetUI'; NoPath=$false; NoReg=$false; NoLnk=$false; FileCheck='C:\Program Files\UniGetUI\unigetui.exe' },
            @{ N='Rust'; Reg='Rust'; Exe='rustup'; Lnk=$null; NoPath=$true; NoReg=$false; NoLnk=$true; FileCheck="$env:USERPROFILE\.cargo\bin\rustup.exe" }
        )
        $appsJson = $apps | ConvertTo-Json -Compress

        $runAudit = {
            param($appsJson, $delaySec)
            if ($delaySec -gt 0) { Start-Sleep -Seconds $delaySec }
            Import-Module Microsoft.PowerShell.LocalAccounts -ErrorAction SilentlyContinue
            $conn = @{ LimitBlank = $null; WinRM = $null; KeyIso = $null; Admin = $null }
            try {
                $val = (Get-ItemPropertyValue -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'LimitBlankPasswordUse' -ErrorAction Stop).ToString()
                $conn.LimitBlank = ($val -eq '0')
            } catch { }
            try {
                $svc = Get-Service -Name WinRM -ErrorAction Stop
                $conn.WinRM = "$($svc.Status) ($($svc.StartType))" -like 'Running*Auto*'
            } catch { }
            try {
                $svc = Get-Service -Name KeyIso -ErrorAction Stop
                $conn.KeyIso = "$($svc.Status) ($($svc.StartType))" -like 'Running*Auto*'
            } catch { }
            try {
                $admin = Get-LocalUser | Where-Object { $_.SID -like '*-500' }
                $conn.Admin = ($admin -and $admin.Enabled)
            } catch { }

            $regPaths = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
            $lnkDirs = @('C:\ProgramData\Microsoft\Windows\Start Menu', 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs')
            $installedReg = Get-ItemProperty $regPaths -EA SilentlyContinue | Select-Object -Property DisplayName
            $allLnks = Get-ChildItem -Path $lnkDirs -Recurse -File -EA SilentlyContinue | Select-Object -Property Name

            $appsList = $appsJson | ConvertFrom-Json
            $stages = @()
            foreach ($a in $appsList) {
                $regOk = $pathOk = $lnkOk = $false
                if (-not $a.NoReg -and $a.Reg) {
                    $regOk = [bool]($installedReg | Where-Object { $_.DisplayName -like "*$($a.Reg)*" } | Select-Object -First 1)
                }
                if (-not $a.NoPath) {
                    if ($a.FileCheck) { $pathOk = Test-Path $a.FileCheck }
                    elseif ($a.Exe) { $pathOk = [bool](Get-Command $a.Exe -EA SilentlyContinue) }
                } elseif ($a.FileCheck) { $pathOk = Test-Path $a.FileCheck }
                if (-not $a.NoLnk -and $a.Lnk) {
                    $lnkOk = [bool]($allLnks | Where-Object { $_.Name -like "*$($a.Lnk)*" } | Select-Object -First 1)
                }
                $hasPathCheck = (-not $a.NoPath) -or $a.FileCheck
                $stages += @{ Reg = if ($a.NoReg) { $null } else { $regOk }; Path = if ($hasPathCheck) { $pathOk } else { $null }; Lnk = if ($a.NoLnk) { $null } else { $lnkOk } }
            }
            @{ Conn = $conn; Stages = $stages }
        }

        # Run audit via Invoke-NonBlocking
        $result = Invoke-NonBlocking -ScriptBlock $runAudit -ArgumentList $appsJson, $script:AuditDelaySeconds

        # Update UI with results
        $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Normal, [action]{
            if ($result -and $result.Conn) {
                $connLimit.IsChecked = $result.Conn.LimitBlank
                $connWinRM.IsChecked = $result.Conn.WinRM
                $connKeyIso.IsChecked = $result.Conn.KeyIso
                $connAdmin.IsChecked = $result.Conn.Admin
            }
            if ($connSpinner) { $connSpinner.Visibility = 'Collapsed' }
            if ($connContent) { $connContent.Visibility = 'Visible' }

            if ($stagesPanel) {
                $stagesPanel.Children.Clear()
                for ($i = 0; $i -lt $apps.Count; $i++) {
                    $a = $apps[$i]
                    $hasPathCheck = (-not $a.NoPath) -or $a.FileCheck
                    $row = New-Object System.Windows.Controls.Grid
                    $row.Margin = [System.Windows.Thickness]::new(0,0,0,6)
                    $row.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width=[System.Windows.GridLength]::new(28)})) | Out-Null
                    $row.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width=[System.Windows.GridLength]::new(28)})) | Out-Null
                    $row.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width=[System.Windows.GridLength]::new(28)})) | Out-Null
                    $row.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)})) | Out-Null
                    
                    $cbReg = New-Object System.Windows.Controls.CheckBox
                    $cbReg.IsChecked = if ($result -and $result.Stages[$i]) { $result.Stages[$i].Reg } else { $null }
                    $cbReg.IsHitTestVisible = $false
                    $cbReg.Style = $window.Resources['StagesCheckboxStyle']
                    $cbReg.IsEnabled = -not $a.NoReg
                    [System.Windows.Controls.Grid]::SetColumn($cbReg, 0)
                    $row.Children.Add($cbReg) | Out-Null
                    
                    $cbPath = New-Object System.Windows.Controls.CheckBox
                    $cbPath.IsChecked = if ($result -and $result.Stages[$i]) { $result.Stages[$i].Path } else { $null }
                    $cbPath.IsHitTestVisible = $false
                    $cbPath.Style = $window.Resources['StagesCheckboxStyle']
                    $cbPath.IsEnabled = $hasPathCheck
                    [System.Windows.Controls.Grid]::SetColumn($cbPath, 1)
                    $row.Children.Add($cbPath) | Out-Null
                    
                    $cbLnk = New-Object System.Windows.Controls.CheckBox
                    $cbLnk.IsChecked = if ($result -and $result.Stages[$i]) { $result.Stages[$i].Lnk } else { $null }
                    $cbLnk.IsHitTestVisible = $false
                    $cbLnk.Style = $window.Resources['StagesCheckboxStyle']
                    $cbLnk.IsEnabled = -not $a.NoLnk
                    [System.Windows.Controls.Grid]::SetColumn($cbLnk, 2)
                    $row.Children.Add($cbLnk) | Out-Null
                    
                    $tb = New-Object System.Windows.Controls.TextBlock
                    $tb.Text = $a.N
                    $tb.FontSize = 12
                    $tb.Foreground = $window.Resources['FgColor']
                    $tb.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
                    [System.Windows.Controls.Grid]::SetColumn($tb, 3)
                    $row.Children.Add($tb) | Out-Null
                    
                    $stagesPanel.Children.Add($row) | Out-Null
                }
            }
            if ($stagesSpinner) { $stagesSpinner.Visibility = 'Collapsed' }
            if ($stagesContent) { $stagesContent.Visibility = 'Visible' }
        })
    }

    # Initialize UI elements on window load
    $window.Add_Loaded({
        # ... (Icon logic remains same) ...
        # [Existing code for phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall, phiconLarge, phiconSmall]
        
        # Audit Debug Logic
        $spinnerSelector = $window.FindName('HomeSpinnerSelector')
        if ($spinnerSelector) {
            $spinnerSelector.Add_SelectionChanged({
                # Only update spinner style; do not re-run the audit
                $connSpinner = $window.FindName('HomeConnSpinner')
                $stagesSpinner = $window.FindName('HomeStagesAuditSpinner')
                $styleKey = if ($spinnerSelector.Text) { "$($spinnerSelector.Text)Style" } else { "OldWinBars1Style" }
                try {
                    $style = $window.Resources[$styleKey]
                    if ($style) {
                        if ($connSpinner) { $connSpinner.Style = $style }
                        if ($stagesSpinner) { $stagesSpinner.Style = $style }
                    }
                } catch { }
            })
        }

        $delayText = $window.FindName('HomeAuditDelayText')
        if ($delayText) { $delayText.Text = $script:AuditDelaySeconds.ToString() }

        $delayUp = $window.FindName('HomeAuditDelayUp')
        if ($delayUp) {
            $delayUp.Add_Click({
                $script:AuditDelaySeconds++
                if ($delayText) { $delayText.Text = $script:AuditDelaySeconds.ToString() }
            })
        }
        $delayDown = $window.FindName('HomeAuditDelayDown')
        if ($delayDown) {
            $delayDown.Add_Click({
                if ($script:AuditDelaySeconds -gt 0) { $script:AuditDelaySeconds-- }
                if ($delayText) { $delayText.Text = $script:AuditDelaySeconds.ToString() }
            })
        }

        # Apply saved Options (e.g. hide launcher window)
        try {
            $opts = Get-Options
            if ($opts.HideLauncherWindow) { Set-OptionHideLauncher -Hide $true }
        } catch { }

        # GuiFork: Hide default apps button (we use profile-based app selection)
        # DefaultAppsBtn stays visible - use it or the Default app profile

        BuildDynamicTweaks

        # Populate Home dashboard (run async to avoid blocking)
        $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{ Update-HomeDashboard }) | Out-Null

        # ... (rest of load logic) ...
    })

    # Add event handler for tab changes
    $script:AppsListLoadedForTab = $false
    $tabControl.Add_SelectionChanged({
        # Load apps only when App Removal tab (index 1) is first shown
        if ($tabControl.SelectedIndex -eq 1 -and -not $script:AppsListLoadedForTab) {
            $script:AppsListLoadedForTab = $true
            LoadAppsIntoMainUI
        }
        # Regenerate overview when switching to Overview tab
        if ($tabControl.SelectedIndex -eq ($tabControl.Items.Count - 2)) {
            GenerateOverview
        }
        UpdateNavigationButtons
    })

    # Handle Load Defaults button
    $loadDefaultsBtn = $window.FindName('LoadDefaultsBtn')
    $loadDefaultsBtn.Add_Click({
        $defaultsJson = LoadJsonFile -filePath $script:DefaultSettingsFilePath -expectedVersion "1.0"

        if (-not $defaultsJson) {
            Show-MessageBox -Message "Failed to load default settings file" -Title "Error" -Button 'OK' -Icon 'Error'
            return
        }
        
        ApplySettingsToUiControls -window $window -settingsJson $defaultsJson -uiControlMappings $script:UiControlMappings
    })

    # Handle Load Last Used settings and Load Last Used apps
    $loadLastUsedBtn = $window.FindName('LoadLastUsedBtn')
    $loadLastUsedAppsBtn = $window.FindName('LoadLastUsedAppsBtn')

    $lastUsedSettingsJson = LoadJsonFile -filePath $script:SavedSettingsFilePath -expectedVersion "1.0" -optionalFile

    $hasSettings = $false
    $appsSetting = $null
    if ($lastUsedSettingsJson -and $lastUsedSettingsJson.Settings) {
        foreach ($s in $lastUsedSettingsJson.Settings) {
            if ($s.Value -eq $true -and $s.Name -ne 'RemoveApps' -and $s.Name -ne 'Apps') { $hasSettings = $true }
            if ($s.Name -eq 'Apps' -and $s.Value) { $appsSetting = $s.Value }
        }
    }

    # Show option to load last used settings if they exist
    if ($hasSettings) {
        $loadLastUsedBtn.Add_Click({
            try {
                ApplySettingsToUiControls -window $window -settingsJson $lastUsedSettingsJson -uiControlMappings $script:UiControlMappings
            }
            catch {
                Show-MessageBox -Message "Failed to load last used settings: $_" -Title "Error" -Button 'OK' -Icon 'Error'
            }
        })
    }
    else {
        $loadLastUsedBtn.Visibility = 'Collapsed'
    }

    # Show option to load last used apps if they exist
    if ($appsSetting -and $appsSetting.ToString().Trim().Length -gt 0) {
        $loadLastUsedAppsBtn.Add_Click({
            try {
                $savedApps = @()
                if ($appsSetting -is [string]) { $savedApps = $appsSetting.Split(',') }
                elseif ($appsSetting -is [array]) { $savedApps = $appsSetting }
                $savedApps = $savedApps | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

                foreach ($child in $appsPanel.Children) {
                    if ($child -is [System.Windows.Controls.CheckBox]) {
                        if ($savedApps -contains $child.Tag) { $child.IsChecked = $true } else { $child.IsChecked = $false }
                    }
                }
            }
            catch {
                Show-MessageBox -Message "Failed to load last used app selection: $($_.Exception.Message)" -Title "Error" -Button 'OK' -Icon 'Error'
            }
        })
    }
    else {
        $loadLastUsedAppsBtn.Visibility = 'Collapsed'
    }

    # Clear All Tweaks button - clears all selections including update-added (system-applied) ones
    $clearAllTweaksBtn = $window.FindName('ClearAllTweaksBtn')
    $clearAllTweaksBtn.Add_Click({
        if ($script:UiControlMappings) {
            foreach ($comboName in $script:UiControlMappings.Keys) {
                $control = $window.FindName($comboName)
                if ($control -is [System.Windows.Controls.CheckBox]) {
                    $control.IsChecked = $false
                }
                elseif ($control -is [System.Windows.Controls.ComboBox]) {
                    $control.SelectedIndex = 0
                }
            }
        }
        Clear-AppliedTweakStyling -ClearAll
    })

    # GuiFork: Clear system-activated styling. For system-applied checkboxes, reset to star (ignore) unless $ClearAll.
    # When $ClearAll is true (from Clear button), also reset system-applied to unchecked.
    function Clear-AppliedTweakStyling {
        param([switch]$ClearAll)
        if (-not $script:UiControlMappings) { return }
        $defaultFg = $window.Resources["FgColor"]
        foreach ($comboName in $script:UiControlMappings.Keys) {
            $control = $window.FindName($comboName)
            $lblBorder = $window.FindName("$comboName`_LabelBorder")
            $mapping = $script:UiControlMappings[$comboName]
            if ($control -is [System.Windows.Controls.ComboBox]) {
                $control.Foreground = $defaultFg
                $control.Background = [System.Windows.Media.Brushes]::Transparent
                if ($mapping.DropDownHandler) {
                    try { $control.Remove_DropDownOpened($mapping.DropDownHandler) } catch {}
                    $mapping.DropDownHandler = $null
                }
                $mapping.IsSystemApplied = $false
                $mapping.AppliedIndex = $null
            }
            elseif ($control -is [System.Windows.Controls.CheckBox]) {
                $mapping = $script:UiControlMappings[$comboName]
                if ($mapping.IsSystemApplied) {
                    $control.IsChecked = if ($ClearAll) { $false } else { $null }
                }
            }
            if ($lblBorder -and $lblBorder.Child) { $lblBorder.Child.Foreground = $defaultFg }
        }
    }

    # GuiFork: Test if a .reg file's values are already applied
    function Test-RegistryFileApplied {
        param([string]$RegFileName)
        $guiForkRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $logPath = Join-Path $guiForkRoot 'debug-619e9b.log'
        $dbg = @{ RegFile = $RegFileName; KeyFound = $null; Actual = $null; Expected = $null; Result = $null; Path = $null; Hive = $null; RegPath = $null }
        $regPath = Join-Path $script:RegfilesPath $RegFileName
        $dbg.RegPath = $regPath
        if (-not (Test-Path $regPath)) { return $false }
        if ($RegFileName -match 'Show_Hidden|Show_Extensions|Disable_Show_More') {
            $testKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software', $false)
            $dbg.HKCU_Software_Accessible = ($null -ne $testKey)
            if ($testKey) { $testKey.Close() }
        }
        $content = Get-Content $regPath -Raw
        $currentKey = $null
        $allMatch = $true
        $lines = $content -split "`r?`n"
        if ($RegFileName -match 'Show_Hidden|Show_Extensions|Disable_Show_More') { $dbg.LineCount = $lines.Count; $idx = [Math]::Min(4, [Math]::Max(0, $lines.Count - 1)); $dbg.FirstLines = if ($lines.Count -gt 0) { ($lines[0..$idx] | ForEach-Object { $_ -replace '"', "'" }) } else { @() } }
        foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line -match '^\[(HKEY_[^\\]+)\\(.+)\]$') {
                $currentKey = @{ Hive = $matches[1]; Path = $matches[2] }
                if ($RegFileName -match 'Show_Hidden|Show_Extensions|Disable_Show_More') { $dbg.Path = $matches[2]; $dbg.Hive = $matches[1]; $dbg.KeyLineMatched = $true }
            }
            elseif ($currentKey -and $line -match '^@=(.+)$') {
                $valData = $matches[1]
                $valName = $null
                try {
                    $baseKey = switch -Regex ($currentKey.Hive) {
                        'HKEY_CURRENT_USER' { [Microsoft.Win32.Registry]::CurrentUser }
                        'HKEY_LOCAL_MACHINE' { [Microsoft.Win32.Registry]::LocalMachine }
                        default { $allMatch = $false; break }
                    }
                    if (-not $allMatch) { break }
                    $key = $baseKey.OpenSubKey($currentKey.Path, $false)
                    if (-not $key) { $dbg.KeyFound = $false; $dbg.Result = 'key_not_found'; $dbg.TriedPath = $currentKey.Path; $allMatch = $false; break }
                    $dbg.KeyFound = $true
                    $actual = $key.GetValue($valName)
                    $key.Close()
                    $expected = $null
                    if ($valData -eq '-') {
                        if ($null -ne $actual) { $allMatch = $false }
                    }
                    elseif ($valData -match '^dword:([0-9a-fA-F]+)$') {
                        $expected = [int][Convert]::ToInt32($matches[1], 16)
                        $actualStr = if ($null -eq $actual) { $null } else { $actual.ToString() }
                        $expectedStr = $expected.ToString()
                        $dbg.Actual = $actualStr; $dbg.Expected = $expectedStr
                        if ($actualStr -ne $expectedStr) { $allMatch = $false }
                    }
                    elseif ($valData -eq '""' -or $valData -match '^"(.+)"$') {
                        $expected = if ($valData -eq '""') { '' } else { $matches[1] -replace '\\"','"' }
                        $actualStr = if ($null -eq $actual) { '' } else { $actual.ToString() }
                        $expectedStr = if ($null -eq $expected) { '' } else { $expected.ToString() }
                        $dbg.Actual = $actualStr; $dbg.Expected = $expectedStr
                        if ($actualStr -ne $expectedStr) { $allMatch = $false }
                    }
                } catch { $dbg.Result = $_.Exception.Message; $allMatch = $false }
                $dbg.Result = $allMatch
                if ($RegFileName -match 'Show_Hidden|Show_Extensions|Disable_Show_More') { try { [System.IO.File]::AppendAllText($logPath, (@{ sessionId = '619e9b'; location = 'Test-RegistryFileApplied'; message = 'check'; data = $dbg; timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() } | ConvertTo-Json -Compress) + "`n") } catch {} }
                if (-not $allMatch) { break }
            }
            elseif ($currentKey -and $line -match '^"([^"]+)"=(.+)$') {
                $valName = $matches[1]
                $valData = $matches[2]
                try {
                    $baseKey = switch -Regex ($currentKey.Hive) {
                        'HKEY_CURRENT_USER' { [Microsoft.Win32.Registry]::CurrentUser }
                        'HKEY_LOCAL_MACHINE' { [Microsoft.Win32.Registry]::LocalMachine }
                        default { $allMatch = $false; break }
                    }
                    if (-not $allMatch) { break }
                    $key = $baseKey.OpenSubKey($currentKey.Path, $false)
                    if (-not $key) { $dbg.KeyFound = $false; $dbg.Result = 'key_not_found'; $dbg.TriedPath = $currentKey.Path; $allMatch = $false; break }
                    $dbg.KeyFound = $true
                    $actual = $key.GetValue($valName)
                    $key.Close()
                    $expected = $null
                    if ($valData -eq '-') {
                        if ($null -ne $actual) { $allMatch = $false }
                    }
                    elseif ($valData -match '^dword:([0-9a-fA-F]+)$') {
                        $expected = [int][Convert]::ToInt32($matches[1], 16)
                        $actualStr = if ($null -eq $actual) { $null } else { $actual.ToString() }
                        $expectedStr = $expected.ToString()
                        $dbg.Actual = $actualStr; $dbg.Expected = $expectedStr
                        if ($actualStr -ne $expectedStr) { $allMatch = $false }
                    }
                    elseif ($valData -eq '""' -or $valData -match '^"(.+)"$') {
                        $expected = if ($valData -eq '""') { '' } else { $matches[1] -replace '\\"','"' }
                        $actualStr = if ($null -eq $actual) { '' } else { $actual.ToString() }
                        $expectedStr = if ($null -eq $expected) { '' } else { $expected.ToString() }
                        $dbg.Actual = $actualStr; $dbg.Expected = $expectedStr
                        if ($actualStr -ne $expectedStr) { $allMatch = $false }
                    }
                } catch { $dbg.Result = $_.Exception.Message; $allMatch = $false }
                $dbg.Result = $allMatch
                if ($RegFileName -match 'Show_Hidden|Show_Extensions|Disable_Show_More') { try { [System.IO.File]::AppendAllText($logPath, (@{ sessionId = '619e9b'; location = 'Test-RegistryFileApplied'; message = 'check'; data = $dbg; timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() } | ConvertTo-Json -Compress) + "`n") } catch {} }
                if (-not $allMatch) { break }
            }
        }
        $dbg.Result = $allMatch
        if ($RegFileName -match 'Show_Hidden|Show_Extensions|Disable_Show_More') { try { [System.IO.File]::AppendAllText($logPath, (@{ sessionId = '619e9b'; location = 'Test-RegistryFileApplied'; message = 'final'; data = $dbg; timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() } | ConvertTo-Json -Compress) + "`n") } catch {} }
        return $allMatch
    }

    # GuiFork: Update tweak selections from system registry scan
    # System-applied checkboxes: 3-state style (star=ignore, check=reinstall, empty=revert), default star
    # System-applied combos: green styling, keep current selection
    function Update-TweakSelectionsFromSystem {
        $featuresJson = LoadJsonFile -filePath $script:FeaturesFilePath -expectedVersion "1.0"
        if (-not $featuresJson) { return }
        Clear-AppliedTweakStyling
        $window.UpdateLayout()
        $appliedColor = $window.Resources["AppliedColor"]
        foreach ($comboName in $script:UiControlMappings.Keys) {
            $mapping = $script:UiControlMappings[$comboName]
            $control = $window.FindName($comboName)
            $lblBorder = $window.FindName("$comboName`_LabelBorder")
            if (-not $control) { continue }
            if ($mapping.Type -eq 'group') {
                $matchedIndex = -1
                for ($i = 0; $i -lt $mapping.Values.Count; $i++) {
                    $val = $mapping.Values[$i]
                    foreach ($fid in $val.FeatureIds) {
                        $feat = $featuresJson.Features | Where-Object { $_.FeatureId -eq $fid } | Select-Object -First 1
                        if ($feat -and $feat.RegistryKey -and (Test-RegistryFileApplied -RegFileName $feat.RegistryKey)) {
                            $matchedIndex = $i + 1
                            break
                        }
                    }
                    if ($matchedIndex -ge 0) { break }
                }
                if ($matchedIndex -ge 0 -and $control -is [System.Windows.Controls.ComboBox]) {
                    $control.SelectedIndex = $matchedIndex
                    $control.Foreground = $appliedColor
                    if ($lblBorder -and $lblBorder.Child) { $lblBorder.Child.Foreground = $appliedColor }
                    $script:UiControlMappings[$comboName].IsSystemApplied = $true
                    $script:UiControlMappings[$comboName].AppliedIndex = $matchedIndex
                    $appliedColorRef = $appliedColor
                    $defaultFgRef = $window.Resources["FgColor"]
                    $handler = {
                        $comboCtrl = $args[0]
                        $comboName = $comboCtrl.Name
                        $mapping = $script:UiControlMappings[$comboName]
                        if (-not $mapping -or -not $mapping.IsSystemApplied -or $null -eq $mapping.AppliedIndex) { return }
                        $appliedBrush = $appliedColorRef
                        $defaultBrush = $defaultFgRef
                        for ($i = 0; $i -lt $comboCtrl.Items.Count; $i++) {
                            $item = $comboCtrl.Items[$i]
                            if ($item -is [System.Windows.Controls.ComboBoxItem]) {
                                $item.Foreground = if ($i -eq $mapping.AppliedIndex) { $appliedBrush } else { $defaultBrush }
                            }
                        }
                    }.GetNewClosure()
                    $control.Add_DropDownOpened($handler)
                    $script:UiControlMappings[$comboName].DropDownHandler = $handler
                }
            }
            elseif ($mapping.Type -eq 'feature') {
                $feat = $featuresJson.Features | Where-Object { $_.FeatureId -eq $mapping.FeatureId } | Select-Object -First 1
                if ($feat -and $feat.RegistryKey -and (Test-RegistryFileApplied -RegFileName $feat.RegistryKey)) {
                    if ($control -is [System.Windows.Controls.CheckBox]) {
                        $control.Style = $window.Resources["FeatureCheckboxSystemAppliedStyle"]
                        $control.IsThreeState = $true
                        $control.IsChecked = $null
                        $control.Foreground = $appliedColor
                        $script:UiControlMappings[$comboName].IsSystemApplied = $true
                    }
                    elseif ($control -is [System.Windows.Controls.ComboBox]) {
                        $control.SelectedIndex = 1
                        $control.Foreground = $appliedColor
                        $script:UiControlMappings[$comboName].IsSystemApplied = $true
                        $script:UiControlMappings[$comboName].AppliedIndex = 1
                        $appliedColorRef = $appliedColor
                        $defaultFgRef = $window.Resources["FgColor"]
                        $handler = {
                            $comboCtrl = $args[0]
                            $comboName = $comboCtrl.Name
                            $mapping = $script:UiControlMappings[$comboName]
                            if (-not $mapping -or -not $mapping.IsSystemApplied -or $null -eq $mapping.AppliedIndex) { return }
                            $appliedBrush = $appliedColorRef
                            $defaultBrush = $defaultFgRef
                            for ($i = 0; $i -lt $comboCtrl.Items.Count; $i++) {
                                $item = $comboCtrl.Items[$i]
                                if ($item -is [System.Windows.Controls.ComboBoxItem]) {
                                    $item.Foreground = if ($i -eq $mapping.AppliedIndex) { $appliedBrush } else { $defaultBrush }
                                }
                            }
                        }.GetNewClosure()
                        $control.Add_DropDownOpened($handler)
                        $script:UiControlMappings[$comboName].DropDownHandler = $handler
                    }
                    if ($lblBorder -and $lblBorder.Child) { $lblBorder.Child.Foreground = $appliedColor }
                }
            }
        }
    }

    # GuiFork: Get current tweak settings from UI (same format as LastUsedSettings)
    function Get-CurrentTweakSettingsFromUi {
        $settings = @()
        if (-not $script:UiControlMappings) { return @{ Version = "1.0"; Settings = $settings } }
        foreach ($comboName in $script:UiControlMappings.Keys) {
            $control = $window.FindName($comboName)
            $mapping = $script:UiControlMappings[$comboName]
            if (-not $control) { continue }
            $paramName = $null
            if ($control -is [System.Windows.Controls.CheckBox]) {
                if ($mapping.IsSystemApplied) {
                    if ($control.IsChecked -eq $true) {
                        $paramName = $mapping.FeatureId
                        $settings += @{ Name = $paramName; Value = $true }
                    }
                    elseif ($control.IsChecked -eq $false) {
                        $paramName = "Revert_$($mapping.FeatureId)"
                        $settings += @{ Name = $paramName; Value = $true }
                    }
                }
                elseif ($control.IsChecked -eq $true) {
                    $paramName = $mapping.FeatureId
                    $settings += @{ Name = $paramName; Value = $true }
                }
            }
            elseif ($control -is [System.Windows.Controls.ComboBox] -and $control.SelectedIndex -gt 0) {
                $paramName = if ($mapping.Type -eq 'feature') { $mapping.FeatureId } else { $mapping.Values[$control.SelectedIndex - 1].FeatureIds[0] }
                $settings += @{ Name = $paramName; Value = $true }
            }
        }
        return @{ Version = "1.0"; Settings = $settings }
    }

    # GuiFork: Tweak Profile functions
    function Get-TweakProfilesPath {
        if ($script:TweakProfilesPath) { return $script:TweakProfilesPath }
        $guiForkRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        return Join-Path $guiForkRoot "Config\TweakProfiles"
    }
    function Get-TweakProfileList {
        $path = Get-TweakProfilesPath
        if (-not (Test-Path $path)) { return @() }
        Get-ChildItem -Path $path -Filter "*.json" -File | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) } | Sort-Object
    }
    function Import-TweakProfile {
        param([string]$ProfileName)
        if ($ProfileName -eq 'Default') {
            return LoadJsonFile -filePath $script:DefaultSettingsFilePath -expectedVersion "1.0"
        }
        $path = Get-TweakProfilesPath
        $filePath = Join-Path $path "$ProfileName.json"
        if (-not (Test-Path $filePath)) { return $null }
        try {
            return Get-Content -Path $filePath -Raw | ConvertFrom-Json
        } catch { return $null }
    }
    function Save-TweakProfile {
        param([string]$ProfileName, [object]$SettingsJson)
        $path = Get-TweakProfilesPath
        if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
        $filePath = Join-Path $path "$ProfileName.json"
        $json = $SettingsJson | ConvertTo-Json -Depth 10
        Set-Content -Path $filePath -Value $json -Encoding UTF8
        $offlineDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $configPath = Join-Path $offlineDir "_offline_config.json"
        $guestDrive = "E"
        $returnPath = "return"
        if (Test-Path $configPath) {
            try {
                $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
                if ($cfg.GuestStagingDrive) { $guestDrive = $cfg.GuestStagingDrive.ToString().Trim().TrimEnd(':')[0] }
                if ($cfg.ReturnPath) { $returnPath = $cfg.ReturnPath.ToString().Trim() }
            } catch {}
        }
        $returnDir = Join-Path "${guestDrive}:\" $returnPath
        if (Test-Path $returnDir) {
            $destPath = Join-Path $returnDir "$ProfileName.json"
            try { Copy-Item -Path $filePath -Destination $destPath -Force } catch {}
        } else {
            try { New-Item -ItemType Directory -Path $returnDir -Force | Out-Null; Copy-Item -Path $filePath -Destination (Join-Path $returnDir "$ProfileName.json") -Force } catch {}
        }
    }
    function Update-TweakProfileCombo {
        $combo = $window.FindName('TweakProfileCombo')
        if (-not $combo) { return }
        $combo.Items.Clear()
        $combo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = "(No profile selected)" })) | Out-Null
        $combo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = "Default" })) | Out-Null
        foreach ($name in Get-TweakProfileList) {
            $combo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = $name })) | Out-Null
        }
        $combo.SelectedIndex = 0
    }

    # GuiFork: Tweak Update and Profile button handlers
    $tweakUpdateBtn = $window.FindName('TweakUpdateBtn')
    $tweakProfileCombo = $window.FindName('TweakProfileCombo')
    $tweakProfileReplaceBtn = $window.FindName('TweakProfileReplaceBtn')
    $tweakProfileMergeBtn = $window.FindName('TweakProfileMergeBtn')
    $tweakProfileSaveBtn = $window.FindName('TweakProfileSaveBtn')
    $tweakProfileSaveAsBtn = $window.FindName('TweakProfileSaveAsBtn')
    $tweakProfileDeleteBtn = $window.FindName('TweakProfileDeleteBtn')
    $tweakUpdateStatus = $window.FindName('TweakUpdateStatus')
    if ($tweakUpdateBtn) {
        $tweakUpdateBtn.Add_Click({
            Update-TweakSelectionsFromSystem
            if ($tweakUpdateStatus) {
                if ($script:TweakUpdateStatusHideTimer -and $script:TweakUpdateStatusHideTimer.IsEnabled) {
                    $script:TweakUpdateStatusHideTimer.Stop()
                }
                $tweakUpdateStatus.Text = "Scan completed successfully"
                $tweakUpdateStatus.Foreground = $window.Resources["AppliedColor"]
                $tweakUpdateStatus.FontSize = 16
                $tweakUpdateStatus.Visibility = 'Visible'
                $script:TweakUpdateStatusHideTimer = New-Object System.Windows.Threading.DispatcherTimer
                $script:TweakUpdateStatusHideTimer.Interval = [TimeSpan]::FromSeconds(2)
                $script:TweakUpdateStatusHideTimer.Add_Tick({
                    $script:TweakUpdateStatusHideTimer.Stop()
                    $tweakUpdateStatus.Visibility = 'Collapsed'
                })
                $script:TweakUpdateStatusHideTimer.Start()
            }
        })
    }
    if ($tweakProfileCombo -and $tweakProfileReplaceBtn -and $tweakProfileMergeBtn -and $tweakProfileSaveBtn) {
        Update-TweakProfileCombo
        $doSaveTweakProfile = {
            param([string]$ProfileName)
            $settingsJson = Get-CurrentTweakSettingsFromUi
            if ($settingsJson.Settings.Count -eq 0) {
                Show-MessageBox -Message "No tweaks selected. Select at least one to save." -Title "Save Profile" -Button 'OK' -Icon 'Information' | Out-Null
                return $false
            }
            if ($ProfileName -eq 'Default') {
                Show-MessageBox -Message "'Default' is reserved for the built-in preset." -Title "Invalid Name" -Button 'OK' -Icon 'Warning' | Out-Null
                return $false
            }
            $invalidPattern = '[<>:' + [char]34 + '/\\|?*]'
            if ($ProfileName -match $invalidPattern) {
                Show-MessageBox -Message 'Profile name cannot contain: < > : " / \ | ? *' -Title "Invalid Name" -Button 'OK' -Icon 'Warning' | Out-Null
                return $false
            }
            Save-TweakProfile -ProfileName $ProfileName -SettingsJson $settingsJson
            Update-TweakProfileCombo
            for ($i = 0; $i -lt $tweakProfileCombo.Items.Count; $i++) {
                $it = $tweakProfileCombo.Items[$i]
                if ($it -and $it.Content -eq $ProfileName) { $tweakProfileCombo.SelectedIndex = $i; break }
            }
            return $true
        }
        $tweakProfileReplaceBtn.Add_Click({
            $item = $tweakProfileCombo.SelectedItem
            if (-not $item -or $tweakProfileCombo.SelectedIndex -eq 0) {
                Show-MessageBox -Message "Select a profile first." -Title "Tweak Profile" -Button 'OK' -Icon 'Information' | Out-Null
                return
            }
            $profileJson = Import-TweakProfile -ProfileName $item.Content
            if (-not $profileJson -or -not $profileJson.Settings) {
                Show-MessageBox -Message "Profile could not be loaded or is empty." -Title "Tweak Profile" -Button 'OK' -Icon 'Warning' | Out-Null
                return
            }
            ApplySettingsToUiControls -window $window -settingsJson $profileJson -uiControlMappings $script:UiControlMappings
        })
        $tweakProfileMergeBtn.Add_Click({
            $item = $tweakProfileCombo.SelectedItem
            if (-not $item -or $tweakProfileCombo.SelectedIndex -eq 0) {
                Show-MessageBox -Message "Select a profile first." -Title "Tweak Profile" -Button 'OK' -Icon 'Information' | Out-Null
                return
            }
            $profileJson = Import-TweakProfile -ProfileName $item.Content
            if (-not $profileJson -or -not $profileJson.Settings) {
                Show-MessageBox -Message "Profile could not be loaded or is empty." -Title "Tweak Profile" -Button 'OK' -Icon 'Warning' | Out-Null
                return
            }
            foreach ($setting in $profileJson.Settings) {
                if ($setting.Value -ne $true) { continue }
                $paramName = $setting.Name
                if ($paramName -eq 'CreateRestorePoint') { continue }
                if ($paramName -match '^Revert_(.+)$') {
                    $featureId = $matches[1]
                    $appliedColor = $window.Resources["AppliedColor"]
                    foreach ($comboName in $script:UiControlMappings.Keys) {
                        $mapping = $script:UiControlMappings[$comboName]
                        if ($mapping.Type -eq 'feature' -and $mapping.FeatureId -eq $featureId) {
                            $control = $window.FindName($comboName)
                            if ($control -and $control -is [System.Windows.Controls.CheckBox]) {
                                $control.Style = $window.Resources["FeatureCheckboxSystemAppliedStyle"]
                                $control.IsThreeState = $true
                                $control.IsChecked = $false
                                $control.Foreground = $appliedColor
                                $script:UiControlMappings[$comboName].IsSystemApplied = $true
                            }
                            break
                        }
                    }
                    continue
                }
                foreach ($comboName in $script:UiControlMappings.Keys) {
                    $mapping = $script:UiControlMappings[$comboName]
                    $control = $window.FindName($comboName)
                    if (-not $control) { continue }
                    if ($mapping.Type -eq 'group') {
                        $i = 1
                        foreach ($val in $mapping.Values) {
                            if ($val.FeatureIds -contains $paramName) {
                                if ($control -is [System.Windows.Controls.ComboBox]) { $control.SelectedIndex = $i }
                                break
                            }
                            $i++
                        }
                    }
                    elseif ($mapping.Type -eq 'feature' -and $mapping.FeatureId -eq $paramName) {
                        if ($control -is [System.Windows.Controls.CheckBox]) { $control.IsChecked = $true }
                        elseif ($control -is [System.Windows.Controls.ComboBox]) { $control.SelectedIndex = 1 }
                        break
                    }
                }
            }
        })
        $tweakProfileSaveBtn.Add_Click({
            $item = $tweakProfileCombo.SelectedItem
            $profileName = if ($item -and $item.Content) { $item.Content.Trim() } else { $null }
            if ($profileName -and $profileName -ne "(No profile selected)" -and $profileName -ne "Default") {
                if (& $doSaveTweakProfile -ProfileName $profileName) {
                    Show-MessageBox -Message "Profile '$profileName' updated." -Title "Save Profile" -Button 'OK' -Icon 'Information' | Out-Null
                }
            } else {
                $profileName = Show-InputDialog -Prompt "Enter profile name:" -Title "Save Tweak Profile" -DefaultText "New Profile"
                if ([string]::IsNullOrWhiteSpace($profileName)) { return }
                $profileName = $profileName.Trim()
                if (& $doSaveTweakProfile -ProfileName $profileName) {
                    Show-MessageBox -Message "Profile '$profileName' saved with $((Get-CurrentTweakSettingsFromUi).Settings.Count) setting(s)." -Title "Save Profile" -Button 'OK' -Icon 'Information' | Out-Null
                }
            }
        })
        if ($tweakProfileSaveAsBtn) {
            $tweakProfileSaveAsBtn.Add_Click({
                $profileName = Show-InputDialog -Prompt "Enter profile name:" -Title "Save Tweak Profile As" -DefaultText "New Profile"
                if ([string]::IsNullOrWhiteSpace($profileName)) { return }
                $profileName = $profileName.Trim()
                if (& $doSaveTweakProfile -ProfileName $profileName) {
                    Show-MessageBox -Message "Profile '$profileName' saved." -Title "Save Profile" -Button 'OK' -Icon 'Information' | Out-Null
                }
            })
        }
        if ($tweakProfileDeleteBtn) {
            $tweakProfileDeleteBtn.Add_Click({
                $item = $tweakProfileCombo.SelectedItem
                if (-not $item -or $tweakProfileCombo.SelectedIndex -le 1) {
                    Show-MessageBox -Message "Select a profile to delete (cannot delete Default)." -Title "Delete Profile" -Button 'OK' -Icon 'Information' | Out-Null
                    return
                }
                $profileName = $item.Content
                if ($profileName -eq "Default") {
                    Show-MessageBox -Message "Cannot delete the Default profile." -Title "Delete Profile" -Button 'OK' -Icon 'Warning' | Out-Null
                    return
                }
                $confirm = Show-MessageBox -Message "Delete profile '$profileName'?" -Title "Delete Profile" -Button 'YesNo' -Icon 'Question'
                if ($confirm -eq 'Yes') {
                    $path = Get-TweakProfilesPath
                    $filePath = Join-Path $path "$profileName.json"
                    if (Test-Path $filePath) {
                        Remove-Item $filePath -Force
                        Update-TweakProfileCombo
                        $offlineDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
                        $configPath = Join-Path $offlineDir "_offline_config.json"
                        $guestDrive = "E"
                        $returnPath = "return"
                        if (Test-Path $configPath) {
                            try {
                                $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
                                if ($cfg.GuestStagingDrive) { $guestDrive = $cfg.GuestStagingDrive.ToString().Trim().TrimEnd(':')[0] }
                                if ($cfg.ReturnPath) { $returnPath = $cfg.ReturnPath.ToString().Trim() }
                            } catch {}
                        }
                        $returnFilePath = Join-Path (Join-Path "${guestDrive}:\" $returnPath) "$profileName.json"
                        if (Test-Path $returnFilePath) { Remove-Item $returnFilePath -Force }
                        Show-MessageBox -Message "Profile '$profileName' deleted." -Title "Delete Profile" -Button 'OK' -Icon 'Information' | Out-Null
                    }
                }
            })
        }
    }

    # Restore window position/size before showing
    if (Test-Path $windowBoundsPath) {
        try {
            $bounds = Get-Content -Path $windowBoundsPath -Raw | ConvertFrom-Json
            $left = [double]$bounds.Left
            $top = [double]$bounds.Top
            $width = [double]$bounds.Width
            $height = [double]$bounds.Height
            $minW = [double]$window.MinWidth
            $minH = [double]$window.MinHeight
            if ($width -ge $minW -and $height -ge $minH) {
                $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
                $window.Left = $left
                $window.Top = $top
                $window.Width = $width
                $window.Height = $height
            }
        } catch { }
    }

    # Show the window
    return $window.ShowDialog()
}
