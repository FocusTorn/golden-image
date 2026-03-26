# Load required assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

function Show-MainWindow {
    param (
        [string]$xamlPath = $script:MainWindowSchema,
        [hashtable]$scriptScope = @{}
    )

    try {
        # 0. Get Environment Context
        $usesDarkMode = GetSystemUsesDarkMode
        $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

        # 1. Load XAML
        $xamlContent = Get-Content -Path $xamlPath -Raw
        
        # Parse XML to find all named elements robustly
        $xml = [xml]$xamlContent
        $uniqueNames = $xml.GetElementsByTagName("*") | ForEach-Object {
            if ($_.HasAttribute("Name")) { $_.GetAttribute("Name") }
            elseif ($_.HasAttribute("x:Name")) { $_.GetAttribute("x:Name") }
        } | Where-Object { $_ } | Select-Object -Unique

        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
        $scriptScope.window = $window

        # 1.5 Apply Theme and Typography
        SetWindowThemeResources -window $window -usesDarkMode $usesDarkMode
        Apply-TypographyResources -window $window

        # 2. Map named elements into $scriptScope using FindName
        foreach ($name in $uniqueNames) {
            $element = $window.FindName($name)
            if ($null -ne $element) {
                $scriptScope[$name] = $element
            }
        }
        
        # Fallback: Manual recursion for items inside ContextMenus
        $stack = New-Object System.Collections.Generic.Stack[System.Windows.DependencyObject]
        $stack.Push($window)
        $visited = New-Object System.Collections.Generic.HashSet[System.Windows.DependencyObject]
        while ($stack.Count -gt 0) {
            $curr = $stack.Pop()
            if ($null -eq $curr -or $visited.Contains($curr)) { continue }
            [void]$visited.Add($curr)
            
            if ($curr -is [System.Windows.FrameworkElement] -and $curr.Name -and -not $scriptScope.ContainsKey($curr.Name)) {
                $scriptScope[$curr.Name] = $curr
            }
            
            if ($curr -is [System.Windows.FrameworkElement] -and $curr.ContextMenu) { $stack.Push($curr.ContextMenu) }
            
            try {
                foreach ($child in [System.Windows.LogicalTreeHelper]::GetChildren($curr)) {
                    if ($child -is [System.Windows.DependencyObject]) { $stack.Push($child) }
                }
            } catch {}
        }

        # 3. Initialize Shared Components
        Write-Host "[DEBUG] Initializing Global GUI Components..."
        try { Initialize-Navigation -scriptScope $scriptScope } catch { Write-Warning "Navigation init failed: $_" }
        try { Initialize-TitleBarAndMenu -scriptScope $scriptScope -window $window -usesDarkMode $usesDarkMode } catch { Write-Warning "TitleBar init failed: $_" }
        
        # 4. Initialize Tabs
        Write-Host "[DEBUG] Initializing Tab Content..."
        
        # Home Tab
        try { Initialize-HomeTab -scriptScope $scriptScope } catch { Write-Warning "HomeTab init failed: $_" }
        
        # Apps Tab
        try { 
            LoadAppsWithList -scriptScope $scriptScope -window $window 
            Initialize-AppSearch -scriptScope $scriptScope -window $window
            Update-AppProfileCombo -scriptScope $scriptScope
        } catch { Write-Warning "App Removal tab init failed: $_" }
        
        # Tweaks Tab
        try { 
            BuildDynamicTweaks -window $window -WinVersion $WinVersion -scriptScope $scriptScope
            if (Get-Command Initialize-TweakSearch -ErrorAction SilentlyContinue) {
                Initialize-TweakSearch -scriptScope $scriptScope -window $window
            }
        } catch { Write-Warning "Tweaks tab init failed: $_" }

        # 5. Handle window resizing (Cursor fix)
        $window.Add_SourceInitialized({
            $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
            [void][System.Windows.Forms.Cursor]
        })

        # 6. Show Window
        $window.ShowDialog() | Out-Null
    }
    catch {
        Write-Warning "Unable to load WPF GUI: $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            Write-Warning "Inner Exception: $($_.Exception.InnerException.Message)"
        }
        $line = $_.InvocationInfo.ScriptLineNumber
        Write-Warning "at Show-MainWindow, $($_.InvocationInfo.ScriptName): line $line"
        throw $_
    }
}
