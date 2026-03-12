# Win11 Debloater - Main GUI
# Uses our Win11Debloat_Config.ps1. Dark theme matching Win11Debloat style.
# Auto-elevates if not admin. Run from Launch_Debloater.bat or directly.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[void][System.Windows.Forms.Application]::EnableVisualStyles()
[void][System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($true)

# Auto-elevate if not admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $mainPath = $MyInvocation.MyCommand.Path
    Start-Process -FilePath "pwsh.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$mainPath`"" -Verb RunAs -WorkingDirectory (Split-Path $mainPath)
    exit 0
}

$script:RootDir = $PSScriptRoot
$script:ConfigScript = Join-Path $script:RootDir "Win11Debloat_Config.ps1"
$script:AppSelectorScript = Join-Path $script:RootDir "App_Removal_Selector.ps1"

# --- Theme (Win11Debloat-style dark, card layout) ---
$script:ClrBg = [System.Drawing.Color]::FromArgb(30, 30, 46)      # #1e1e2e
$script:ClrPanel = [System.Drawing.Color]::FromArgb(36, 36, 52)   # #242434
$script:ClrCardBg = [System.Drawing.Color]::FromArgb(38, 38, 55)  # Slightly lighter for cards
$script:ClrBorder = [System.Drawing.Color]::FromArgb(60, 60, 80) # Card border
$script:ClrAccent = [System.Drawing.Color]::FromArgb(0, 120, 212)  # #0078d4
$script:ClrText = [System.Drawing.Color]::FromArgb(230, 230, 240)
$script:ClrTextDim = [System.Drawing.Color]::FromArgb(160, 160, 180)
$script:ClrApplied = [System.Drawing.Color]::FromArgb(0, 180, 120) # Green for already applied

# Category icons (Segoe Fluent Icons) - map group name keywords to Unicode
$script:CategoryIcons = @{
    "App removal" = [char]0xE74C; "Privacy" = [char]0xE72E; "Content" = [char]0xE8FC
    "Search" = [char]0xE721; "AI" = [char]0xE794; "System" = [char]0xE770
    "Appearance" = [char]0xE771; "Start menu" = [char]0xE8FC; "Taskbar" = [char]0xE75B
    "File Explorer" = [char]0xEC50; "Gaming" = [char]0xE7FC; "Window snapping" = [char]0xE7C4
    "Alt+Tab" = [char]0xE7C4; "Other" = [char]0xE713; "Optional" = [char]0xEFDA
    "Run mode" = [char]0xE895
}

# Universal font - use system default UI font family for consistency
$script:DefaultUIFont = [System.Drawing.SystemFonts]::DefaultFont
$script:MainFontSize = 9
$script:TitleFontSize = 14
$script:SubtitleFontSize = 12
$script:MainFont = New-Object System.Drawing.Font($script:DefaultUIFont.FontFamily, $script:MainFontSize)
$script:MainFontBold = New-Object System.Drawing.Font($script:DefaultUIFont.FontFamily, $script:MainFontSize, [System.Drawing.FontStyle]::Bold)
$script:TitleFont = New-Object System.Drawing.Font($script:DefaultUIFont.FontFamily, $script:TitleFontSize, [System.Drawing.FontStyle]::Bold)
$script:SubtitleFont = New-Object System.Drawing.Font($script:DefaultUIFont.FontFamily, $script:SubtitleFontSize, [System.Drawing.FontStyle]::Bold)
$script:IconFont = $null
try { $script:IconFont = New-Object System.Drawing.Font("Segoe Fluent Icons", 16) } catch { $script:IconFont = $script:MainFont }

# --- Parse config options from Win11Debloat_Config.ps1 ---
function Get-ConfigOptions {
    $configPath = $script:ConfigScript
    if (-not (Test-Path $configPath)) { return @() }
    $content = Get-Content $configPath -Raw
    if ($content -notmatch '(?s)\$Config\s*=\s*@"(.*?)"@') { return @() }
    $block = $Matches[1]
    $options = @()
    $currentGroup = "General"
    foreach ($line in ($block -split "`r?`n")) {
        $t = $line.Trim()
        if ($t -match '^#\s*---\s*(.+?)\s*---\s*$') { $currentGroup = $Matches[1].Trim(); continue }
        if ([string]::IsNullOrWhiteSpace($t)) { continue }
        $t = $t -replace '^\s*#\s*', ''
        if ([string]::IsNullOrWhiteSpace($t)) { continue }
        $param = $null
        $val = $null
        if ($t -match '^(-?\w+)\s+(.+)$') { $param = $Matches[1].TrimStart('-'); $val = $Matches[2] }
        elseif ($t -match '^(-?\w+)\s*$') { $param = $Matches[1].TrimStart('-') }
        if ($param) {
            $label = $param -replace '([A-Z])', ' $1' -replace '^ ', ''
            $pickOneGroups = @('Taskbar - combine (main)', 'Taskbar - combine (secondary)', 'Taskbar - multi-monitor', 'Taskbar - search', 'File Explorer - default open', 'Alt+Tab tabs')
            $isPickOne = $pickOneGroups -contains $currentGroup
            $groupName = $currentGroup
            $subGroup = $null
            $originalGroup = $currentGroup
            if ($currentGroup -match '^File Explorer -\s*(.+)$') {
                $groupName = "File Explorer"
                $subGroup = $Matches[1].Trim()
            }
            elseif ($currentGroup -match '^Taskbar -\s*(.+)$') {
                $groupName = "Taskbar"
                $subGroup = $Matches[1].Trim()
            }
            $options += [PSCustomObject]@{ Param = $param; Label = $label; Group = $groupName; SubGroup = $subGroup; OriginalGroup = $originalGroup; Value = $(if ($val) { $val.Trim().Trim('"') } else { $null }); IsPickOne = $isPickOne }
        }
    }
    return $options
}

function Get-CategoryIcon {
    param([string]$GroupName)
    foreach ($key in $script:CategoryIcons.Keys) {
        if ($GroupName -like "*$key*") { return $script:CategoryIcons[$key] }
    }
    return [char]0xE8A7  # Default: settings gear
}

# --- Check if setting is already applied (subset of registry checks) ---
function Test-SettingApplied {
    param([string]$ParamName)
    $ErrorActionPreference = "SilentlyContinue"
    switch -Regex ($ParamName) {
        '^DisableTelemetry$' {
            $v = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name AllowTelemetry -ErrorAction SilentlyContinue
            return ($v.AllowTelemetry -eq 0)
        }
        '^DisableWidgets$' {
            $v = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name AllowNewsAndInterests -ErrorAction SilentlyContinue
            return ($v.AllowNewsAndInterests -eq 0)
        }
        '^ShowHiddenFolders$' {
            $v = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Hidden -ErrorAction SilentlyContinue
            return ($v.Hidden -eq 1)
        }
        '^ShowKnownFileExt$' {
            $v = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name HideFileExt -ErrorAction SilentlyContinue
            return ($v.HideFileExt -eq 0)
        }
        '^HideTaskview$' {
            $v = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowTaskViewButton -ErrorAction SilentlyContinue
            return ($v.ShowTaskViewButton -eq 0)
        }
        '^TaskbarAlignLeft$' {
            $v = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarAl -ErrorAction SilentlyContinue
            return ($v.TaskbarAl -eq 0)
        }
        '^EnableDarkMode$' {
            $v = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name AppsUseLightTheme -ErrorAction SilentlyContinue
            return ($v.AppsUseLightTheme -eq 0)
        }
        '^DisableCopilot$' {
            $v = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name EnableFeeds -ErrorAction SilentlyContinue
            return ($null -ne $v -and $v.EnableFeeds -eq 0)
        }
        default { return $false }
    }
}

# --- Get current applied value for pick-one options (for Update button) ---
function Get-AppliedPickOneValue {
    param([string]$GroupName, [string[]]$ParamNames)
    $ErrorActionPreference = "SilentlyContinue"
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    switch -Regex ($GroupName) {
        'Taskbar - combine \(main' {
            $v = Get-ItemProperty $path -Name TaskbarGlomLevel -ErrorAction SilentlyContinue
            if ($null -eq $v) { return "Unknown" }
            $map = @{ 0 = "CombineTaskbarAlways"; 1 = "CombineTaskbarWhenFull"; 2 = "CombineTaskbarNever" }
            $r = $map[$v.TaskbarGlomLevel]; return $(if ($r) { $r } else { "Unknown" })
        }
        'Taskbar - combine \(secondary' {
            $v = Get-ItemProperty $path -Name MMTaskbarGlomLevel -ErrorAction SilentlyContinue
            if ($null -eq $v) { return "Unknown" }
            $map = @{ 0 = "CombineMMTaskbarAlways"; 1 = "CombineMMTaskbarWhenFull"; 2 = "CombineMMTaskbarNever" }
            $r = $map[$v.MMTaskbarGlomLevel]; return $(if ($r) { $r } else { "Unknown" })
        }
        'Taskbar - multi-monitor' {
            $v = Get-ItemProperty $path -Name MMTaskbarMode -ErrorAction SilentlyContinue
            if ($null -eq $v) { return "Unknown" }
            $map = @{ 0 = "MMTaskbarModeAll"; 1 = "MMTaskbarModeMainActive"; 2 = "MMTaskbarModeActive" }
            $r = $map[$v.MMTaskbarMode]; return $(if ($r) { $r } else { "Unknown" })
        }
        'Taskbar - search' {
            $v = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name SearchboxTaskbarMode -ErrorAction SilentlyContinue
            if ($null -eq $v) { return "Unknown" }
            $map = @{ 0 = "HideSearchTb"; 1 = "ShowSearchIconTb"; 2 = "ShowSearchBoxTb"; 3 = "ShowSearchLabelTb" }
            $r = $map[$v.SearchboxTaskbarMode]; return $(if ($r) { $r } else { "Unknown" })
        }
        'File Explorer - default open' {
            $v = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name LaunchTo -ErrorAction SilentlyContinue
            if ($null -eq $v) { return "Unknown" }
            $map = @{ 0 = "ExplorerToHome"; 1 = "ExplorerToThisPC"; 2 = "ExplorerToOneDrive"; 3 = "ExplorerToDownloads" }
            $r = $map[$v.LaunchTo]; return $(if ($r) { $r } else { "Unknown" })
        }
        'Alt\+Tab tabs' {
            $v = Get-ItemProperty $path -Name MultiTaskingAltTabFilter -ErrorAction SilentlyContinue
            if ($null -eq $v) { return "Unknown" }
            $map = @{ 0 = "HideTabsInAltTab"; 3 = "Show3TabsInAltTab"; 5 = "Show5TabsInAltTab"; 20 = "Show20TabsInAltTab" }
            $r = $map[$v.MultiTaskingAltTabFilter]; return $(if ($r) { $r } else { "Unknown" })
        }
        default { return "Unknown" }
    }
}

# --- Write config from selected options ---
function Update-ConfigFromSelection {
    param([hashtable]$Selected)
    $configPath = $script:ConfigScript
    $lines = Get-Content $configPath
    $result = @()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        $matched = $false
        foreach ($param in $Selected.Keys) {
            $esc = [regex]::Escape($param)
            if ($trimmed -match "^\s*#?\s*(-?$esc)(\s+(.+))?$") {
                $indent = if ($line -match '^(\s*)') { $Matches[1] } else { "" }
                $token = $Matches[1]
                $suffix = if ($Matches[3]) { " $($Matches[3])" } else { "" }
                $result += if ($Selected[$param]) { "$indent$token$suffix" } else { "$indent# $token$suffix" }
                $matched = $true
                break
            }
        }
        if (-not $matched) { $result += $line }
    }
    $result | Set-Content $configPath -Encoding UTF8
}

# --- Build form ---
$options = Get-ConfigOptions
if ($options.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("Could not load options from Win11Debloat_Config.ps1", "Error", "OK", "Error")
    exit 1
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Win11 Debloater"
$form.Font = $script:MainFont
$form.BackColor = $script:ClrBg
$form.ForeColor = $script:ClrText
$form.MinimumSize = New-Object System.Drawing.Size(600, 450)

$settingsPath = Join-Path $script:RootDir "MainWindow.json"
if (Test-Path $settingsPath) {
    try {
        $s = Get-Content $settingsPath -Raw | ConvertFrom-Json
        $form.StartPosition = "Manual"
        $form.Location = New-Object System.Drawing.Point($s.X, $s.Y)
        $form.Size = New-Object System.Drawing.Size($s.Width, $s.Height)
    } catch { $form.StartPosition = "CenterScreen"; $form.Size = New-Object System.Drawing.Size(900, 580) }
} else {
    $form.StartPosition = "CenterScreen"
    $form.Size = New-Object System.Drawing.Size(900, 580)
}

# --- Menu ---
$menu = New-Object System.Windows.Forms.MenuStrip
$menu.BackColor = $script:ClrPanel
$menu.ForeColor = $script:ClrText
$menu.Font = $script:MainFont

$mnuFile = New-Object System.Windows.Forms.ToolStripMenuItem("File")
$mnuExit = New-Object System.Windows.Forms.ToolStripMenuItem("Exit")
$mnuExit.Add_Click({ $form.Close() })
$mnuFile.DropDownItems.Add($mnuExit) | Out-Null

$mnuTools = New-Object System.Windows.Forms.ToolStripMenuItem("Tools")
$mnuAppSelector = New-Object System.Windows.Forms.ToolStripMenuItem("App Removal Selector...")
$mnuAppSelector.Add_Click({
    if (Test-Path $script:AppSelectorScript) {
        Start-Process pwsh -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$script:AppSelectorScript`"" -WorkingDirectory $script:RootDir
    } else {
        [System.Windows.Forms.MessageBox]::Show("App_Removal_Selector.ps1 not found.", "Tools", "OK", "Warning")
    }
})
$mnuTools.DropDownItems.Add($mnuAppSelector) | Out-Null

$mnuHelp = New-Object System.Windows.Forms.ToolStripMenuItem("Help")
$mnuAbout = New-Object System.Windows.Forms.ToolStripMenuItem("About")
$mnuAbout.Add_Click({
    [System.Windows.Forms.MessageBox]::Show("Win11 Debloater`nUses Win11Debloat with our configuration.`nGreen check = already applied on system.", "About", "OK", "Information")
})
$mnuHelp.DropDownItems.Add($mnuAbout) | Out-Null

$menu.Items.AddRange(@($mnuFile, $mnuTools, $mnuHelp))
$form.MainMenuStrip = $menu

# --- Toolbar ---
$toolbar = New-Object System.Windows.Forms.Panel
$toolbar.Dock = [System.Windows.Forms.DockStyle]::Top
$toolbar.Height = 45
$toolbar.BackColor = $script:ClrPanel
$toolbar.Padding = New-Object System.Windows.Forms.Padding(8, 6, 8, 0)

$btnUpdate = New-Object System.Windows.Forms.Button
$btnUpdate.Text = "Update"
$btnUpdate.Location = New-Object System.Drawing.Point(8, 8)
$btnUpdate.Size = New-Object System.Drawing.Size(90, 28)
$btnUpdate.BackColor = $script:ClrAccent
$btnUpdate.ForeColor = [System.Drawing.Color]::White
$btnUpdate.FlatStyle = "Flat"
$btnUpdate.Font = $script:MainFont
$toolbar.Controls.Add($btnUpdate)

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "Apply Selected"
$btnApply.Location = New-Object System.Drawing.Point(105, 8)
$btnApply.Size = New-Object System.Drawing.Size(120, 28)
$btnApply.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 100)
$btnApply.ForeColor = [System.Drawing.Color]::White
$btnApply.FlatStyle = "Flat"
$btnApply.Font = $script:MainFont
$toolbar.Controls.Add($btnApply)

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.UseCompatibleTextRendering = $true
$lblHint.Text = "Green check = already applied"
$lblHint.ForeColor = $script:ClrApplied
$lblHint.Font = $script:MainFont
$lblHint.Location = New-Object System.Drawing.Point(240, 14)
$lblHint.AutoSize = $true
$toolbar.Controls.Add($lblHint)

# --- Scrollable options panel: FlowLayoutPanel, uniform columns, no resize thrashing ---
$scroll = New-Object System.Windows.Forms.Panel
$scroll.Dock = [System.Windows.Forms.DockStyle]::Fill
$scroll.AutoScroll = $true
$scroll.BackColor = $script:ClrBg
$scroll.Padding = New-Object System.Windows.Forms.Padding(12, 8, 12, 12)
$scroll.Font = $script:MainFont

$categoryFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$categoryFlow.AutoSize = $true
$categoryFlow.AutoSizeMode = "GrowAndShrink"
$categoryFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$categoryFlow.WrapContents = $true
$categoryFlow.Dock = [System.Windows.Forms.DockStyle]::Top
$categoryFlow.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
$categoryFlow.Font = $script:MainFont
$scroll.Controls.Add($categoryFlow)

$script:FileExplorerSubOrder = @("default open", "display", "navigation", "context menu")
$script:TaskbarSubOrder = @("alignment", "combine (main)", "combine (secondary)", "multi-monitor", "search", "other")
$rawGroups = $options | Group-Object Group
$groups = @()
foreach ($g in $rawGroups) {
    if ($g.Name -eq "File Explorer") {
        $sorted = $g.Group | Sort-Object { $i = [array]::IndexOf($script:FileExplorerSubOrder, $_.SubGroup); if ($i -ge 0) { $i } else { 999 } }
        $groups += [PSCustomObject]@{ Name = $g.Name; Group = [array]$sorted }
    }
    elseif ($g.Name -eq "Taskbar") {
        $sorted = $g.Group | Sort-Object { $i = [array]::IndexOf($script:TaskbarSubOrder, $_.SubGroup); if ($i -ge 0) { $i } else { 999 } }
        $groups += [PSCustomObject]@{ Name = $g.Name; Group = [array]$sorted }
    }
    else {
        $groups += $g
    }
}
$script:ColWidths = @()
foreach ($grp in $groups) {
    $colMax = 0
    $w = [System.Windows.Forms.TextRenderer]::MeasureText($grp.Name, $script:TitleFont).Width
    if ($w -gt $colMax) { $colMax = $w }
    foreach ($opt in $grp.Group) {
        if ($opt.IsPickOne) {
            $w = [System.Windows.Forms.TextRenderer]::MeasureText($opt.Label, $script:MainFont).Width
            if ($w -gt $colMax) { $colMax = $w }
        } else {
            $txt = [char]0x2610 + " " + $opt.Label
            $w = [System.Windows.Forms.TextRenderer]::MeasureText($txt, $script:MainFont).Width
            if ($w -gt $colMax) { $colMax = $w }
        }
    }
    $w = [System.Windows.Forms.TextRenderer]::MeasureText("(None)", $script:MainFont).Width
    if ($w -gt $colMax) { $colMax = $w }
    $script:ColWidths += $colMax + 2
}
$script:UniformColW = ($script:ColWidths | Measure-Object -Maximum).Maximum
$script:CardW = $script:UniformColW + 16
$script:MaxCols = [Math]::Max(1, $groups.Count)
$categoryFlowMinWidth = $script:CardW * $script:MaxCols + 12 * ($script:MaxCols - 1) + 24

function Update-CategoryLayout {
    $avail = [Math]::Max($script:CardW, $scroll.ClientSize.Width - 24)
    $script:NumCols = [Math]::Max(1, [Math]::Min($script:MaxCols, [Math]::Floor(($avail + 12) / ($script:CardW + 12))))
    $categoryFlow.Width = [Math]::Max($avail, $script:CardW * $script:NumCols + 12 * ($script:NumCols - 1))
    $categoryFlow.SuspendLayout()
    $categoryFlow.Controls.Clear()
    $n = $script:AllCards.Count
    $colLists = [System.Collections.ArrayList[]]::new($script:NumCols)
    for ($c = 0; $c -lt $script:NumCols; $c++) { $colLists[$c] = [System.Collections.ArrayList]::new() }
    if ($script:CardHeights.Count -eq $n) {
        $colHeights = @(0) * $script:NumCols
        $order = 0..($n - 1) | Sort-Object { $script:CardHeights[$_] } -Descending
        foreach ($i in $order) {
            $minCol = 0
            for ($c = 1; $c -lt $script:NumCols; $c++) {
                if ($colHeights[$c] -lt $colHeights[$minCol]) { $minCol = $c }
            }
            [void]$colLists[$minCol].Add($i)
            $colHeights[$minCol] += $script:CardHeights[$i]
        }
        for ($c = 0; $c -lt $script:NumCols; $c++) {
            $colLists[$c] = $colLists[$c] | Sort-Object
        }
    } else {
        $base = [Math]::Floor($n / $script:NumCols)
        $remainder = $n % $script:NumCols
        $colsWithBase = $script:NumCols - $remainder
        for ($col = 0; $col -lt $script:NumCols; $col++) {
            if ($col -lt $colsWithBase) {
                $start = $col * $base
                $end = $start + $base - 1
            } else {
                $offset = $colsWithBase * $base
                $idx = $col - $colsWithBase
                $start = $offset + $idx * ($base + 1)
                $end = $start + $base
            }
            for ($j = $start; $j -le $end -and $j -lt $n; $j++) { [void]$colLists[$col].Add($j) }
        }
    }
    for ($col = 0; $col -lt $script:NumCols; $col++) {
        $columnFlow = New-Object System.Windows.Forms.FlowLayoutPanel
        $columnFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
        $columnFlow.WrapContents = $false
        $columnFlow.AutoSize = $true
        $columnFlow.AutoSizeMode = "GrowAndShrink"
        $columnFlow.Width = $script:CardW
        $columnFlow.Margin = New-Object System.Windows.Forms.Padding(0, 0, 12, 0)
        $columnFlow.Font = $script:MainFont
        foreach ($j in $colLists[$col]) {
            [void]$columnFlow.Controls.Add($script:AllCards[$j])
        }
        [void]$categoryFlow.Controls.Add($columnFlow)
    }
    $categoryFlow.ResumeLayout($true)
}

$form.Add_Load({
    Update-CategoryLayout
    foreach ($lbl in $script:Checkboxes.Values) {
        $lbl.Font = $script:MainFont
    }
})
$form.Add_Resize({
    if ($script:AllCards.Count -eq 0) { return }
    $avail = [Math]::Max($script:CardW, $scroll.ClientSize.Width - 24)
    $pendingCols = [Math]::Max(1, [Math]::Min($script:MaxCols, [Math]::Floor(($avail + 12) / ($script:CardW + 12))))
    if ($pendingCols -ne $script:NumCols) {
        Update-CategoryLayout
    }
})
$form.Add_ResizeEnd({
    Update-CategoryLayout
})

# Distribute groups into columns (sequential order for balanced layout on resize)
$columnGroups = @()
for ($i = 0; $i -lt $script:MaxCols; $i++) {
    $colGrps = @()
    for ($j = $i; $j -lt $groups.Count; $j += $script:MaxCols) {
        $colGrps += $groups[$j]
    }
    $columnGroups += ,@($colGrps)
}

$script:Checkboxes = @{}
$script:CheckboxStates = @{}
$script:PickOneDropdowns = @{}   # GroupName -> ComboBox
$script:PickOneCurrentText = @{} # GroupName -> Label
$script:AllCards = @()
$script:CardHeights = @()

foreach ($colGrps in $columnGroups) {
    foreach ($grp in $colGrps) {
    $card = New-Object System.Windows.Forms.Panel
    $card.BackColor = $script:ClrCardBg
    $card.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $card.MinimumSize = New-Object System.Drawing.Size($script:CardW, 0)
    $card.MaximumSize = New-Object System.Drawing.Size($script:CardW, 30000)
    $card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)

    $colFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $colFlow.FlowDirection = "TopDown"
    $colFlow.WrapContents = $false
    $colFlow.AutoSize = $true
    $colFlow.AutoSizeMode = "GrowAndShrink"
    $colFlow.BackColor = [System.Drawing.Color]::Transparent
    $colFlow.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
    $colFlow.Font = $script:MainFont

    $headerPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $headerPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $headerPanel.WrapContents = $false
    $headerPanel.AutoSize = $true
    $headerPanel.BackColor = [System.Drawing.Color]::Transparent
    $headerPanel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)

    $icon = Get-CategoryIcon -GroupName $grp.Name
    $lblIcon = New-Object System.Windows.Forms.Label
    $lblIcon.UseCompatibleTextRendering = $true
    $lblIcon.Text = $icon
    $lblIcon.Font = $script:IconFont
    $lblIcon.ForeColor = $script:ClrText
    $lblIcon.AutoSize = $true
    $lblIcon.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
    $headerPanel.Controls.Add($lblIcon)

    $lblGrp = New-Object System.Windows.Forms.Label
    $lblGrp.UseCompatibleTextRendering = $true
    $lblGrp.Text = $grp.Name
    $lblGrp.Font = $script:TitleFont
    $lblGrp.ForeColor = $script:ClrText
    $lblGrp.AutoSize = $true
    $headerPanel.Controls.Add($lblGrp)

    $colFlow.Controls.Add($headerPanel)

    $hasSubGroups = ($grp.Group | Where-Object { $_.SubGroup } | Select-Object -First 1)
    if ($hasSubGroups) {
        $subOrder = if ($grp.Name -eq "Taskbar") { $script:TaskbarSubOrder } else { $script:FileExplorerSubOrder }
        $subGroupsToRender = $grp.Group | Group-Object SubGroup | Sort-Object { $i = [array]::IndexOf($subOrder, $_.Name); if ($i -ge 0) { $i } else { 999 } } | ForEach-Object { , $_.Group }
    } else {
        $subGroupsToRender = [System.Collections.ArrayList]::new()
        [void]$subGroupsToRender.Add([array]$grp.Group)
    }

    foreach ($subOpts in $subGroupsToRender) {
        $firstOpt = $subOpts[0]
        $subTitle = $firstOpt.SubGroup
        if ($subTitle) {
            $lblSub = New-Object System.Windows.Forms.Label
            $lblSub.UseCompatibleTextRendering = $true
            $lblSub.Text = (Get-Culture).TextInfo.ToTitleCase($subTitle)
            $lblSub.Font = $script:SubtitleFont
            $lblSub.ForeColor = $script:ClrTextDim
            $lblSub.AutoSize = $true
            $lblSub.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 4)
            $colFlow.Controls.Add($lblSub)
        }
        $pickOneKey = $firstOpt.OriginalGroup
        $isPickOne = $firstOpt.IsPickOne
        if ($isPickOne) {
            $lblCurrentVal = New-Object System.Windows.Forms.Label
            $lblCurrentVal.UseCompatibleTextRendering = $true
            $lblCurrentVal.Text = "(click Update)"
            $lblCurrentVal.ForeColor = $script:ClrTextDim
            $lblCurrentVal.Font = $script:MainFont
            $lblCurrentVal.AutoSize = $true
            $lblCurrentVal.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 4)
            $colFlow.Controls.Add($lblCurrentVal)
            $script:PickOneCurrentText[$pickOneKey] = $lblCurrentVal

            $pickOneItems = @([PSCustomObject]@{ Param = $null; Label = "(None)" }) + @($subOpts)
            $cmbMaxW = 0
            foreach ($item in $pickOneItems) {
                $w = [System.Windows.Forms.TextRenderer]::MeasureText($item.Label, $script:MainFont).Width
                if ($w -gt $cmbMaxW) { $cmbMaxW = $w }
            }
            $cmb = New-Object System.Windows.Forms.ComboBox
            $cmb.Font = $script:MainFont
            $cmb.BackColor = $script:ClrPanel
            $cmb.ForeColor = $script:ClrText
            $cmb.FlatStyle = "Flat"
            $cmb.DropDownStyle = "DropDownList"
            $cmb.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
            $cmb.ItemHeight = 22
            $cmb.Width = [Math]::Min($cmbMaxW + 28, $script:UniformColW - 8)
            foreach ($item in $pickOneItems) { [void]$cmb.Items.Add($item.Label) }
            $cmb.SelectedIndex = 0
            $cmb.Tag = @{ GroupName = $pickOneKey; Items = $pickOneItems }
            $cmb.Add_DrawItem({
                param($sender, $e)
                if ($e.Index -lt 0) { return }
                $txt = $sender.Items[$e.Index].ToString()
                $isSelected = ($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -ne 0
                if ($isSelected) {
                    $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($script:ClrAccent)), $e.Bounds)
                    $brush = [System.Drawing.Brushes]::White
                } else {
                    $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($script:ClrPanel)), $e.Bounds)
                    $brush = New-Object System.Drawing.SolidBrush($script:ClrText)
                }
                $e.Graphics.DrawString($txt, $script:MainFont, $brush, $e.Bounds.X, $e.Bounds.Y)
            })
            $colFlow.Controls.Add($cmb)
            $script:PickOneDropdowns[$pickOneKey] = $cmb
        } else {
            foreach ($opt in $subOpts) {
                $lblChk = New-Object System.Windows.Forms.Label
                $lblChk.UseCompatibleTextRendering = $true
                $lblChk.Font = $script:MainFont
                $lblChk.ForeColor = $script:ClrText
                $lblChk.BackColor = [System.Drawing.Color]::Transparent
                $lblChk.AutoSize = $true
                $lblChk.AutoEllipsis = $false
                $lblChk.Tag = @{ Param = $opt.Param; Label = $opt.Label }
                $lblChk.Margin = New-Object System.Windows.Forms.Padding(4, 2, 0, 2)
                $lblChk.Cursor = [System.Windows.Forms.Cursors]::Hand
                $script:CheckboxStates[$opt.Param] = $false
                $lblChk.Text = [char]0x2610 + " " + $opt.Label
                $lblChk.Add_Click({
                    $t = $this.Tag
                    $p = $t.Param
                    $script:CheckboxStates[$p] = -not $script:CheckboxStates[$p]
                    $glyph = if ($script:CheckboxStates[$p]) { [char]0x2611 } else { [char]0x2610 }
                    $this.Text = "$glyph $($t.Label)"
                })
                $script:Checkboxes[$opt.Param] = $lblChk
                $colFlow.Controls.Add($lblChk)
            }
        }
    }

    $colFlow.Location = New-Object System.Drawing.Point(8, 8)
    $card.Controls.Add($colFlow)
    $script:AllCards += $card
    }
}
$form.Add_Shown({
    $categoryFlow.PerformLayout()
    $script:CardHeights = @()
    for ($i = 0; $i -lt $script:AllCards.Count; $i++) {
        $card = $script:AllCards[$i]
        if ($card.Controls.Count -gt 0) {
            $inner = $card.Controls[0]
            $card.Height = [Math]::Max(60, $inner.Height + 16)
        }
        $script:CardHeights += $card.Height
    }
    Update-CategoryLayout
})

# Add controls in order: scroll first (fill), toolbar (top), menu (top) so menu is at very top
$form.Controls.Add($scroll)
$form.Controls.Add($toolbar)
$form.Controls.Add($menu)

# --- Load current config state ---
$configContent = Get-Content $script:ConfigScript -Raw
foreach ($param in $script:Checkboxes.Keys) {
    $lbl = $script:Checkboxes[$param]
    $esc = [regex]::Escape($param)
    $checked = $configContent -match "(?m)^\s*(-?$esc)(\s|$)"
    $script:CheckboxStates[$param] = $checked
    $t = $lbl.Tag
    $glyph = if ($checked) { [char]0x2611 } else { [char]0x2610 }
    $lbl.Text = "$glyph $($t.Label)"
}
foreach ($grpName in $script:PickOneDropdowns.Keys) {
    $cmb = $script:PickOneDropdowns[$grpName]
    $tag = $cmb.Tag
    $found = $false
    for ($i = 0; $i -lt $tag.Items.Count; $i++) {
        $item = $tag.Items[$i]
        if ($null -eq $item.Param) { continue }
        $esc = [regex]::Escape($item.Param)
        if ($configContent -match "(?m)^\s*(-?$esc)(\s|$)") { 
            $cmb.SelectedIndex = $i
            $found = $true
            break 
        }
    }
    if (-not $found) { $cmb.SelectedIndex = 0 }
}

# --- Update button: check system, color applied items, populate pick-one current ---
$btnUpdate.Add_Click({
    foreach ($param in $script:Checkboxes.Keys) {
        $lbl = $script:Checkboxes[$param]
        $applied = Test-SettingApplied -ParamName $param
        $lbl.ForeColor = if ($applied -and $script:CheckboxStates[$param]) { $script:ClrApplied } else { $script:ClrText }
    }
    foreach ($grpName in $script:PickOneDropdowns.Keys) {
        $tag = $script:PickOneDropdowns[$grpName].Tag
        $params = @(); foreach ($item in $tag.Items) { if ($item.Param) { $params += $item.Param } }
        $applied = Get-AppliedPickOneValue -GroupName $grpName -ParamNames $params
        $lbl = $applied
        if ($applied -ne "Unknown") {
            foreach ($item in $tag.Items) {
                if ($item.Param -eq $applied) { $lbl = $item.Label; break }
            }
        }
        $script:PickOneCurrentText[$grpName].Text = $lbl
    }
})

# --- Apply button ---
$btnApply.Add_Click({
    $selected = @{}
    foreach ($param in $script:Checkboxes.Keys) {
        $selected[$param] = $script:CheckboxStates[$param]
    }
    foreach ($grpName in $script:PickOneDropdowns.Keys) {
        $cmb = $script:PickOneDropdowns[$grpName]
        $tag = $cmb.Tag
        $selParam = $tag.Items[$cmb.SelectedIndex].Param
        foreach ($item in $tag.Items) {
            $p = $item.Param
            if ($null -ne $p) { $selected[$p] = ($p -eq $selParam) }
        }
    }
    Update-ConfigFromSelection -Selected $selected
    & $script:ConfigScript
})

$form.Add_FormClosing({
    $bounds = $this.Bounds
    @{ X = $bounds.X; Y = $bounds.Y; Width = $bounds.Width; Height = $bounds.Height } | ConvertTo-Json | Set-Content $settingsPath -Encoding UTF8
})

$form.ShowDialog()
