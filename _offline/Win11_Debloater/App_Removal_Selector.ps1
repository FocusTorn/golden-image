# App Removal Selector - Build -Apps string for Win11Debloat_Config.ps1
# Config: App_Removal_Selector.json (window size, splitter, profiles, blacklist)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:ConfigPath = Join-Path $PSScriptRoot "App_Removal_Selector.json"
$script:DefaultOutputHeight = 140
$script:MinWindowWidth = 500
$script:MinWindowHeight = 400

# --- Default Sysprep Safe profile (common bloat to remove for golden image) ---
$script:SysprepSafeApps = @(
    "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.BingSports", "Microsoft.BingFinance",
    "Microsoft.3DBuilder", "Microsoft.Microsoft3DViewer", "Microsoft.GetHelp", "Microsoft.WindowsFeedbackHub",
    "Clipchamp.Clipchamp", "Microsoft.WindowsAlarms", "Microsoft.windowscommunicationsapps",
    "Microsoft.Xbox.TCUI", "Microsoft.XboxGameOverlay", "Microsoft.XboxGamingOverlay", "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay", "Microsoft.GamingApp", "Microsoft.People", "Microsoft.MicrosoftStickyNotes",
    "Microsoft.ScreenSketch", "Microsoft.ZuneMusic", "Microsoft.ZuneVideo", "Microsoft.MicrosoftSolitaireCollection",
    "king.com.CandyCrushSaga", "king.com.CandyCrushSodaSaga", "king.com.BubbleWitch3Saga",
    "Microsoft.Windows.Photos", "Microsoft.Getstarted", "Microsoft.MicrosoftOfficeHub",
    "Microsoft.BingFoodAndDrink", "Microsoft.BingHealthAndFitness", "Microsoft.BingTravel",
    "Microsoft.BingTranslator", "Microsoft.WindowsSoundRecorder", "Microsoft.SkypeApp",
    "Microsoft.549981C3F5F10", "Microsoft.WindowsStore", "Microsoft.WindowsCalculator"
)

# --- Config load/save ---
function Get-DefaultConfig {
    return @{
        WindowWidth  = 700
        WindowHeight = 650
        SplitterDistance = 450
        Blacklist    = @()
        Profiles     = @{
            "Sysprep Safe" = $script:SysprepSafeApps
        }
    } | ConvertTo-Json -Depth 5
}

function Get-Config {
    if (-not (Test-Path $script:ConfigPath)) {
        return (Get-DefaultConfig | ConvertFrom-Json)
    }
    try {
        $raw = Get-Content $script:ConfigPath -Raw -Encoding UTF8
        $cfg = $raw | ConvertFrom-Json
        if (-not $cfg.Profiles) { $cfg | Add-Member -NotePropertyName Profiles -NotePropertyValue ([PSCustomObject]@{ "Sysprep Safe" = $script:SysprepSafeApps }) -Force }
        elseif (-not $cfg.Profiles.PSObject.Properties["Sysprep Safe"]) {
            $prof = @{}
            $cfg.Profiles.PSObject.Properties | ForEach-Object { $prof[$_.Name] = $_.Value }
            $prof["Sysprep Safe"] = $script:SysprepSafeApps
            $cfg.Profiles = [PSCustomObject]$prof
        }
        if (-not $cfg.Blacklist) { $cfg | Add-Member -NotePropertyName Blacklist -NotePropertyValue @() -Force }
        return $cfg
    } catch {
        return (Get-DefaultConfig | ConvertFrom-Json)
    }
}

function Save-Config {
    param($Cfg, $Form, $Splitter)
    $Cfg.WindowWidth = $Form.Width
    $Cfg.WindowHeight = $Form.Height
    $Cfg.SplitterDistance = $Splitter.SplitterDistance
    $json = $Cfg | ConvertTo-Json -Depth 5
    Set-Content $script:ConfigPath -Value $json -Encoding UTF8 -Force
}

# --- Get installed apps (exclude framework + blacklist) ---
function Get-FilteredApps {
    param($Blacklist)
    $excludePatterns = @(
        "*.Framework*", "*.ResourcePack*", "*.NeutralResources*",
        "Microsoft.VCLibs*", "Microsoft.NET.Native*", "Microsoft.UI.Xaml*",
        "Microsoft.WinAppRuntime*"
    )
    $apps = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
        Where-Object {
            $n = $_.Name
            if (-not $n -or -not $_.PackageFamilyName) { return $false }
            foreach ($p in $excludePatterns) { if ($n -like $p) { return $false } }
            foreach ($b in $Blacklist) { if ($n -eq $b -or $n -like $b) { return $false } }
            $true
        } |
        Sort-Object Name |
        ForEach-Object { [PSCustomObject]@{ Name = $_.Name } }
    return $apps
}

# --- Load config ---
$script:Cfg = Get-Config
$blacklist = @()
if ($script:Cfg.Blacklist) {
    $blacklist = if ($script:Cfg.Blacklist -is [array]) { $script:Cfg.Blacklist } else { @($script:Cfg.Blacklist) }
}
$apps = Get-FilteredApps -Blacklist $blacklist

# --- Form ---
$script:MainFont = New-Object System.Drawing.Font("Verdana", 10)
$script:MainFontBold = New-Object System.Drawing.Font("Verdana", 10, [System.Drawing.FontStyle]::Bold)
$form = New-Object System.Windows.Forms.Form
$form.Text = "App Removal Selector - for Win11Debloat"
$form.MinimumSize = New-Object System.Drawing.Size($script:MinWindowWidth, $script:MinWindowHeight)
$form.Size = New-Object System.Drawing.Size($script:Cfg.WindowWidth, $script:Cfg.WindowHeight)
$form.StartPosition = "CenterScreen"
$form.Font = $script:MainFont

# --- SplitContainer (top = list, bottom = output) ---
$split = New-Object System.Windows.Forms.SplitContainer
$split.Dock = [System.Windows.Forms.DockStyle]::Fill
$split.Orientation = [System.Windows.Forms.Orientation]::Horizontal
$split.SplitterWidth = 6
$splitDist = if ($script:Cfg.SplitterDistance) { [int]$script:Cfg.SplitterDistance } else { 450 }
$split.SplitterDistance = [Math]::Max(250, $splitDist)
$split.FixedPanel = [System.Windows.Forms.FixedPanel]::None
$split.Panel2MinSize = 80
$split.Panel1MinSize = 120
$form.Controls.Add($split)

# --- Panel1: List + toolbar (TableLayoutPanel for reliable layout) ---
$pnlTop = New-Object System.Windows.Forms.TableLayoutPanel
$pnlTop.Dock = [System.Windows.Forms.DockStyle]::Fill
$pnlTop.RowCount = 3
$pnlTop.ColumnCount = 1
$pnlTop.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$pnlTop.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$pnlTop.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$pnlTop.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
$pnlTop.Padding = New-Object System.Windows.Forms.Padding(5)
$split.Panel1.Controls.Add($pnlTop)

$lblApps = New-Object System.Windows.Forms.Label
$lblApps.Text = "Installed apps (check those to remove):"
$lblApps.AutoSize = $true
$pnlTop.Controls.Add($lblApps, 0, 0)

$listBox = New-Object System.Windows.Forms.CheckedListBox
$listBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$listBox.CheckOnClick = $true
$listBox.Sorted = $true
$listBox.IntegralHeight = $true
$listBox.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 4)
foreach ($a in $apps) { [void]$listBox.Items.Add($a.Name, $false) }
$pnlTop.Controls.Add($listBox, 0, 1)

$toolbar = New-Object System.Windows.Forms.FlowLayoutPanel
$toolbar.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$toolbar.AutoSize = $true
$toolbar.WrapContents = $false
$pnlTop.Controls.Add($toolbar, 0, 2)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Clear"
$btnClear.Size = New-Object System.Drawing.Size(70, 28)
$btnClear.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
$btnClear.Add_Click({
    for ($i = 0; $i -lt $listBox.Items.Count; $i++) { $listBox.SetItemChecked($i, $false) }
    $txtOutput.Text = ""
})
$toolbar.Controls.Add($btnClear)

$btnSelectAll = New-Object System.Windows.Forms.Button
$btnSelectAll.Text = "Select All"
$btnSelectAll.Size = New-Object System.Drawing.Size(75, 28)
$btnSelectAll.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
$btnSelectAll.Add_Click({
    for ($i = 0; $i -lt $listBox.Items.Count; $i++) { $listBox.SetItemChecked($i, $true) }
})
$toolbar.Controls.Add($btnSelectAll)

$btnCreate = New-Object System.Windows.Forms.Button
$btnCreate.Text = "Create"
$btnCreate.Size = New-Object System.Drawing.Size(70, 28)
$btnCreate.Margin = New-Object System.Windows.Forms.Padding(0, 0, 12, 0)
$btnCreate.Add_Click({
    $checked = @()
    for ($i = 0; $i -lt $listBox.Items.Count; $i++) {
        if ($listBox.GetItemChecked($i)) { $checked += $listBox.Items[$i] }
    }
    if ($checked.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No apps selected. Check at least one app.", "Create", "OK", "Information")
        return
    }
    $appsStr = $checked -join ","
    $configBlock = @"
# Paste into Win11Debloat_Config.ps1 (same folder) `$Config block:

RemoveApps
-Apps "$appsStr"
"@
    $txtOutput.Text = $configBlock
    [System.Windows.Forms.Clipboard]::SetText($configBlock)
    [System.Windows.Forms.MessageBox]::Show("Copied to clipboard. Paste into Win11Debloat_Config.ps1", "Created", "OK", "Information")
})
$toolbar.Controls.Add($btnCreate)

# Profile dropdown
$lblProfile = New-Object System.Windows.Forms.Label
$lblProfile.Text = "Profile:"
$lblProfile.AutoSize = $true
$lblProfile.Margin = New-Object System.Windows.Forms.Padding(0, 6, 4, 0)
$toolbar.Controls.Add($lblProfile)

$cmbProfile = New-Object System.Windows.Forms.ComboBox
$cmbProfile.Font = $script:MainFont
$cmbProfile.Size = New-Object System.Drawing.Size(140, 25)
$cmbProfile.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
$cmbProfile.DropDownStyle = "DropDownList"
$profNames = @()
if ($script:Cfg.Profiles) {
    $script:Cfg.Profiles.PSObject.Properties | ForEach-Object { $profNames += $_.Name }
}
$profNames | Sort-Object | ForEach-Object { [void]$cmbProfile.Items.Add($_) }
if ($cmbProfile.Items.Count -gt 0) { $cmbProfile.SelectedIndex = 0 }
$toolbar.Controls.Add($cmbProfile)

$btnLoad = New-Object System.Windows.Forms.Button
$btnLoad.Text = "Load"
$btnLoad.Size = New-Object System.Drawing.Size(55, 28)
$btnLoad.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
$btnLoad.Add_Click({
    $name = $cmbProfile.SelectedItem
    if (-not $name) { return }
    $ids = $script:Cfg.Profiles.$name
    if (-not $ids) { $ids = @() }
    if ($ids -isnot [array]) { $ids = @($ids) }
    for ($i = 0; $i -lt $listBox.Items.Count; $i++) {
        $listBox.SetItemChecked($i, $ids -contains $listBox.Items[$i])
    }
})
$toolbar.Controls.Add($btnLoad)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save"
$btnSave.Size = New-Object System.Drawing.Size(55, 28)
$btnSave.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
$btnSave.Add_Click({
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Save Profile"
    $inputForm.Size = New-Object System.Drawing.Size(300, 120)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $lbl = New-Object System.Windows.Forms.Label; $lbl.Text = "Profile name:"; $lbl.Location = New-Object System.Drawing.Point(10, 15); $lbl.AutoSize = $true
    $tb = New-Object System.Windows.Forms.TextBox; $tb.Location = New-Object System.Drawing.Point(10, 35); $tb.Size = New-Object System.Drawing.Size(265, 23); $tb.Text = $cmbProfile.SelectedItem
    $btnOk = New-Object System.Windows.Forms.Button; $btnOk.Text = "OK"; $btnOk.DialogResult = "OK"; $btnOk.Location = New-Object System.Drawing.Point(110, 65); $btnOk.Size = New-Object System.Drawing.Size(75, 28)
    $btnCancel = New-Object System.Windows.Forms.Button; $btnCancel.Text = "Cancel"; $btnCancel.DialogResult = "Cancel"; $btnCancel.Location = New-Object System.Drawing.Point(195, 65); $btnCancel.Size = New-Object System.Drawing.Size(75, 28)
    $inputForm.AcceptButton = $btnOk; $inputForm.CancelButton = $btnCancel
    $inputForm.Controls.AddRange(@($lbl, $tb, $btnOk, $btnCancel))
    if ($inputForm.ShowDialog($form) -ne "OK") { return }
    $name = $tb.Text.Trim()
    if (-not $name) { return }
    $checked = @()
    for ($i = 0; $i -lt $listBox.Items.Count; $i++) {
        if ($listBox.GetItemChecked($i)) { $checked += $listBox.Items[$i] }
    }
    $prof = @{}
    $script:Cfg.Profiles.PSObject.Properties | ForEach-Object { $prof[$_.Name] = $_.Value }
    $prof[$name] = $checked
    $script:Cfg.Profiles = [PSCustomObject]$prof
    $cmbProfile.Items.Clear()
    $script:Cfg.Profiles.PSObject.Properties.Name | Sort-Object | ForEach-Object { [void]$cmbProfile.Items.Add($_) }
    $idx = [array]::IndexOf([array]$cmbProfile.Items, $name)
    if ($idx -ge 0) { $cmbProfile.SelectedIndex = $idx }
})
$toolbar.Controls.Add($btnSave)

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = "Delete"
$btnDelete.Size = New-Object System.Drawing.Size(55, 28)
$btnDelete.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
$btnDelete.Add_Click({
    $name = $cmbProfile.SelectedItem
    if (-not $name) { return }
    if ($name -eq "Sysprep Safe") {
        [System.Windows.Forms.MessageBox]::Show("Cannot delete the built-in Sysprep Safe profile.", "Delete", "OK", "Warning")
        return
    }
    $prof = @{}
    $script:Cfg.Profiles.PSObject.Properties | Where-Object { $_.Name -ne $name } | ForEach-Object { $prof[$_.Name] = $_.Value }
    $script:Cfg.Profiles = [PSCustomObject]$prof
    $cmbProfile.Items.Remove($name)
    if ($cmbProfile.Items.Count -gt 0) { $cmbProfile.SelectedIndex = 0 }
})
$toolbar.Controls.Add($btnDelete)

# --- Panel2: Output ---
$pnlBottom = New-Object System.Windows.Forms.Panel
$pnlBottom.Dock = [System.Windows.Forms.DockStyle]::Fill
$split.Panel2.Controls.Add($pnlBottom)

$lblOutPanel = New-Object System.Windows.Forms.Panel
$lblOutPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$lblOutPanel.Height = 26
$pnlBottom.Controls.Add($lblOutPanel)

$lblOut = New-Object System.Windows.Forms.Label
$lblOut.Text = "Output (paste into Win11Debloat_Config.ps1):"
$lblOut.Location = New-Object System.Drawing.Point(10, 6)
$lblOut.AutoSize = $true
$lblOutPanel.Controls.Add($lblOut)

$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Multiline = $true
$txtOutput.ScrollBars = "Vertical"
$txtOutput.Dock = [System.Windows.Forms.DockStyle]::Fill
$txtOutput.ReadOnly = $true
$pnlBottom.Controls.Add($txtOutput)

# --- Config button (edit blacklist in JSON) ---
$btnConfig = New-Object System.Windows.Forms.Button
$btnConfig.Text = "Config"
$btnConfig.Size = New-Object System.Drawing.Size(55, 28)
$btnConfig.Add_Click({
    if (Test-Path $script:ConfigPath) {
        Start-Process notepad $script:ConfigPath
    } else {
        Get-DefaultConfig | Set-Content $script:ConfigPath -Encoding UTF8
        Start-Process notepad $script:ConfigPath
    }
})
$toolbar.Controls.Add($btnConfig)

# --- Save config on close ---
$form.Add_FormClosing({
    Save-Config -Cfg $script:Cfg -Form $form -Splitter $split
})

$form.ShowDialog()
