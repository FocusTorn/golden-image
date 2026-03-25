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
    
    # --- DYNAMIC DISCOVERY HELPERS ---
    
    $sysPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $combinedPath = "$sysPath;$userPath"
    $testPathVar = { param($search) return $combinedPath -like "*$search*" }
    
    $commonPrograms = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonPrograms)
    $commonStart = Split-Path $commonPrograms -Parent
    $userPrograms = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Programs)
    $userStart = Split-Path $userPrograms -Parent
    $startMenuRoots = @($commonPrograms, $commonStart, $userPrograms, $userStart)

    $testLnk = { 
        param($namePattern) 
        foreach ($root in $startMenuRoots) {
            if (Get-ChildItem -Path $root -Filter "*$namePattern*.lnk" -Recurse -ErrorAction SilentlyContinue) { return $true }
        }
        return $false
    }

    $findInRegistry = {
        param($displayNamePattern)
        $hives = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", 
                   "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                   "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall")
        foreach ($hive in $hives) {
            if (Test-Path $hive) {
                $match = Get-ChildItem $hive -ErrorAction SilentlyContinue | Where-Object { 
                    $dn = $_.GetValue("DisplayName"); $null -ne $dn -and $dn -match $displayNamePattern 
                }
                if ($match) { return $true }
            }
        }
        return $false
    }

    # --- AUDIT DEFINITIONS ---

    $stages = @(
        @{ 
            Id = 1; Name = "Scoop" 
            Reg = $null # Scoop doesn't use standard registry
            PathCheck = { 
                return (Test-Path "C:\Scoop\shims\scoop.ps1") -or 
                       (Test-Path "$env:USERPROFILE\scoop\shims\scoop.ps1") -or
                       (&$testPathVar "scoop\shims")
            }
        }
        @{ 
            Id = 2; Name = "MSVC" 
            RegCheck = { return (&$findInRegistry "Visual Studio Build Tools") -or (&$findInRegistry "Visual Studio Community") -or (Test-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7") }
            PathCheck = { return (Test-Path "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools") -or (Test-Path "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community") }
            Lnk = "Visual Studio"
        }
        @{ Id = 3; Name = "System Apps"; Items = @(
            @{ 
                Id = 31; Name = "Chrome"
                Reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
                Path = "C:\Program Files\Google\Chrome\Application\chrome.exe" 
                Lnk = "Chrome"
            }
            @{ 
                Id = 32; Name = "VS Code"
                RegCheck = { return (&$findInRegistry "Visual Studio Code") }
                PathCheck = { return (Test-Path "C:\Program Files\Microsoft VS Code\bin\code.cmd") -or (Test-Path "$env:LocalAppData\Programs\Microsoft VS Code\bin\code.cmd") }
                Lnk = "Visual Studio Code"
            }
            @{ 
                Id = 33; Name = "Git"
                RegCheck = { return (&$findInRegistry "Git") -or (Test-Path "HKLM:\SOFTWARE\GitForWindows") }
                PathCheck = { return (Test-Path "C:\Program Files\Git\bin\git.exe") -or (&$testPathVar "Git\bin") }
                Lnk = "Git Bash"
            }
            @{ 
                Id = 34; Name = "Go"
                Reg = $null # Set to null as requested/not found
                PathCheck = { return (Test-Path "C:\Program Files\Go\bin\go.exe") -or (&$testPathVar "Go\bin") }
            }
            @{ 
                Id = 35; Name = "GitHub CLI"
                RegCheck = { return (&$findInRegistry "GitHub CLI") }
                PathCheck = { return (Test-Path "C:\Program Files\GitHub CLI\gh.exe") -or (&$testPathVar "GitHub CLI") }
            }
            @{ 
                Id = 36; Name = "UniGetUI"
                RegCheck = { return (&$findInRegistry "UniGetUI") }
                PathCheck = { return (Test-Path "C:\Program Files\UniGetUI\UniGetUI.exe") -or (Test-Path "$env:LocalAppData\Programs\UniGetUI\UniGetUI.exe") }
                Lnk = "UniGetUI"
            }
        )}
        @{ 
            Id = 4; Name = "Rust Finish" 
            PathCheck = { return (Test-Path "$env:USERPROFILE\.cargo\bin\rustc.exe") -or (&$testPathVar ".cargo\bin") }
        }
        @{ 
            Id = 5; Name = "Finalize" 
            Path = "C:\Windows\System32\Sysprep\unattend.xml"
        }
    )
    
    $scriptScope.HomeStagesAuditPanel.Children.Clear()
    
    $createDot = {
        param($color = "#808080")
        $e = New-Object System.Windows.Shapes.Ellipse
        $e.Width = 8; $e.Height = 8; $e.Fill = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString($color))
        $e.HorizontalAlignment = 'Center'; $e.VerticalAlignment = 'Center'
        return $e
    }

    $createAuditRow = {
        param($id, $name, $isSubItem, $checks)
        $grid = New-Object System.Windows.Controls.Grid
        $grid.Margin = "0,1,0,1"
        $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(18) })) | Out-Null
        $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(18) })) | Out-Null
        $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(18) })) | Out-Null
        $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })) | Out-Null
        
        # Registry Check (R)
        $regOk = $null
        if ($checks.RegCheck) {
            $regOk = &$checks.RegCheck
        } elseif ($checks.Reg) {
            $regOk = Test-Path $checks.Reg
            if (-not $regOk -and $checks.Reg -like "HKLM:\SOFTWARE\*") {
                $regOk = Test-Path ($checks.Reg -replace "HKLM:\\SOFTWARE\\", "HKLM:\SOFTWARE\WOW6432Node\")
            }
        }

        $regColor = switch ($regOk) { $true { "#4CAF50" } $false { "#c42b1c" } default { "#808080" } }
        $regDot = &$createDot $regColor
        $grid.Children.Add($regDot) | Out-Null; [System.Windows.Controls.Grid]::SetColumn($regDot, 0)
        
        # Path Check (P)
        $pathOk = $null
        if ($checks.PathCheck) {
            $pathOk = &$checks.PathCheck
        } elseif ($checks.Path) {
            $pathOk = Test-Path $checks.Path
        }
        
        $pathColor = switch ($pathOk) { $true { "#4CAF50" } $false { "#c42b1c" } default { "#808080" } }
        $pathDot = &$createDot $pathColor
        $grid.Children.Add($pathDot) | Out-Null; [System.Windows.Controls.Grid]::SetColumn($pathDot, 1)
        
        # Link Check (L)
        $lnkOk = if ($checks.Lnk) { &$testLnk $checks.Lnk } else { $null }
        $lnkColor = switch ($lnkOk) { $true { "#4CAF50" } $false { "#c42b1c" } default { "#808080" } }
        $linkDot = &$createDot $lnkColor
        $grid.Children.Add($linkDot) | Out-Null; [System.Windows.Controls.Grid]::SetColumn($linkDot, 2)
        
        $txt = New-Object System.Windows.Controls.TextBlock
        $txt.Text = "$id. $name"
        $txt.FontSize = $(if ($isSubItem) { 11 } else { 12 })
        $txt.Foreground = $scriptScope.window.Resources["LabelColor"]
        $txt.Margin = $(if ($isSubItem) { "20,0,0,0" } else { "8,0,0,0" })
        $txt.VerticalAlignment = 'Center'
        $grid.Children.Add($txt) | Out-Null; [System.Windows.Controls.Grid]::SetColumn($txt, 3)
        return $grid
    }

    foreach ($stage in $stages) {
        $row = &$createAuditRow $stage.Id $stage.Name $false $stage
        $scriptScope.HomeStagesAuditPanel.Children.Add($row) | Out-Null
        
        if ($stage.Items) {
            foreach ($item in $stage.Items) {
                $subRow = &$createAuditRow $item.Id $item.Name $true $item
                $scriptScope.HomeStagesAuditPanel.Children.Add($subRow) | Out-Null
            }
        }
    }
    
    $scriptScope.HomeStagesAuditSpinner.Visibility = 'Collapsed'
    $scriptScope.HomeStagesAuditContent.Visibility = 'Visible'
}
