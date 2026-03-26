function Invoke-StageScript {
    param([string]$ScriptName, [string]$App = $null)
    $scriptPath = Join-Path $script:GoldenImagerRoot "Imaging_Scripts/$ScriptName"
    if (Test-Path $scriptPath) {
        $args = if ($App) { "-App $App" } else { "" }
        Write-Host "Executing stage script: ${ScriptName} $args"
        try {
            & $scriptPath $args
        } catch {
            Write-Warning "Failed to execute ${ScriptName}: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "Script not found: $scriptPath"
    }
}

function Invoke-WithProgress {
    param([string]$TaskName, [scriptblock]$Action, $scriptScope)
    if ($scriptScope.window) {
        $scriptScope.window.Dispatcher.InvokeAsync([Action]{
            try {
                &$Action
            } finally {
                Initialize-HomeTab -scriptScope $scriptScope
            }
        })
    }
}

function Initialize-HomeTab {
    param($scriptScope)
    
    Write-Host "[DEBUG] Initialize-HomeTab started..."
    if ($null -eq $scriptScope.window) { Write-Warning "[DEBUG] Window is null!"; return }

    # Helper to check and set elements
    $checkAndSet = {
        param($name, $visibility)
        if ($null -ne $scriptScope[$name]) {
            $scriptScope[$name].Visibility = $visibility
        } else {
            Write-Warning "[DEBUG] UI Element NOT FOUND in scriptScope: $name"
        }
    }

    # 1. Immediate UI state (Force show the content containers)
    Write-Host "[DEBUG] Setting immediate UI state..."
    &$checkAndSet "HomeModSpinner" "Collapsed"
    &$checkAndSet "HomeModContent" "Visible"
    &$checkAndSet "HomeExecSpinner" "Collapsed"
    &$checkAndSet "HomeExecContent" "Visible"

    # 2. Connection Settings Audit (Decoupled Task with Closure)
    Write-Host "[DEBUG] Triggering Connection Audit..."
    &$checkAndSet "HomeConnSpinner" "Visible"
    &$checkAndSet "HomeConnContent" "Collapsed"
    if ($null -ne $scriptScope.HomeConnError) { $scriptScope.HomeConnError.Visibility = 'Collapsed' }
    
    # Capture variables for closure
    $localScope = $scriptScope
    $connAction = {
        try {
            # Real audits
            $results = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -ErrorAction SilentlyContinue
            $lb = if ($null -ne $results) { $results.LimitBlankPasswordUse } else { 1 }
            $wrm = (Get-Service -Name WinRM -ErrorAction SilentlyContinue).Status -eq 'Running'
            $kiso = (Get-Service -Name KeyIso -ErrorAction SilentlyContinue).Status -eq 'Running'
            $adminOk = try { (Get-LocalUser -Name "Administrator" -ErrorAction SilentlyContinue).Enabled } catch { $false }
            
            $localScope.window.Dispatcher.InvokeAsync([Action]{
                if ($null -ne $localScope.HomeConnLimitBlank) { $localScope.HomeConnLimitBlank.IsChecked = $lb -eq 0 }
                if ($null -ne $localScope.HomeConnWinRM)      { $localScope.HomeConnWinRM.IsChecked      = $wrm }
                if ($null -ne $localScope.HomeConnKeyIso)     { $localScope.HomeConnKeyIso.IsChecked     = $kiso }
                if ($null -ne $localScope.HomeConnAdmin)      { $localScope.HomeConnAdmin.IsChecked      = $adminOk }
                
                if ($null -ne $localScope.HomeConnSpinner) { $localScope.HomeConnSpinner.Visibility = 'Collapsed' }
                if ($null -ne $localScope.HomeConnContent) { $localScope.HomeConnContent.Visibility = 'Visible' }
            })
        } catch {
            $err = $_.Exception.Message
            Write-Warning "[DEBUG] Conn audit background error: $err"
            $localScope.window.Dispatcher.InvokeAsync([Action]{
                if ($null -ne $localScope.HomeConnError)   { $localScope.HomeConnError.Text = "Audit Error: $err"; $localScope.HomeConnError.Visibility = 'Visible' }
                if ($null -ne $localScope.HomeConnSpinner) { $localScope.HomeConnSpinner.Visibility = 'Collapsed' }
            })
        }
    }.GetNewClosure()

    [System.Threading.Tasks.Task]::Run([System.Action]$connAction)

    # 3. Stages Audit (Decoupled Task with Closure)
    Write-Host "[DEBUG] Triggering Stages Audit..."
    &$checkAndSet "HomeStagesAuditSpinner" "Visible"
    &$checkAndSet "HomeStagesAuditContent" "Collapsed"
    if ($null -ne $scriptScope.HomeStagesAuditError) { $scriptScope.HomeStagesAuditError.Visibility = 'Collapsed' }

    $stagesAction = {
        try {
            # Real Audit: Check system state for imaging progress
            $auditData = @()
            
            # Stage 1: Customization (Check for PS7)
            $ps7Ok = Test-Path "C:\Program Files\PowerShell\7\pwsh.exe"
            $auditData += @{ Name = "Customization & PWSH 7"; Status = if ($ps7Ok) { "Green" } else { "Gray" } }
            
            # Stage 2: MSVC Runtimes
            $msvcOk = Test-Path "HKLM:\SOFTWARE\Classes\Installer\Dependencies\VC,redist.x64,amd64,14.0,bundle"
            $auditData += @{ Name = "MSVC Runtimes"; Status = if ($msvcOk) { "Green" } else { "Gray" } }
            
            # Stage 3: System Apps
            $appsOk = Test-Path "C:\ProgramData\Chocolatey\bin\choco.exe" -or Test-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
            $auditData += @{ Name = "App Infrastructure"; Status = if ($appsOk) { "Green" } else { "Gray" } }
            
            $localScope.window.Dispatcher.InvokeAsync([Action]{
                if ($null -eq $localScope.HomeStagesAuditPanel) { return }
                $localScope.HomeStagesAuditPanel.Children.Clear()
                
                foreach ($item in $auditData) {
                    $color = if ($item.Status -eq "Green") { [System.Windows.Media.Brushes]::LimeGreen } else { [System.Windows.Media.Brushes]::DimGray }
                    $tb = New-Object System.Windows.Controls.TextBlock -Property @{ 
                        Text = "• $($item.Name)"; 
                        Margin = "2,0,0,4"; 
                        Foreground = $color;
                        FontWeight = "SemiBold"
                    }
                    $localScope.HomeStagesAuditPanel.Children.Add($tb) | Out-Null
                }
                
                if ($null -ne $localScope.HomeStagesAuditSpinner) { $localScope.HomeStagesAuditSpinner.Visibility = 'Collapsed' }
                if ($null -ne $localScope.HomeStagesAuditContent) { $localScope.HomeStagesAuditContent.Visibility = 'Visible' }
            })
        } catch {
            $err = $_.Exception.Message
            Write-Warning "[DEBUG] Stages audit background error: $err"
            $localScope.window.Dispatcher.InvokeAsync([Action]{
                if ($null -ne $localScope.HomeStagesAuditError)   { $localScope.HomeStagesAuditError.Text = "Audit Error: $err"; $localScope.HomeStagesAuditError.Visibility = 'Visible' }
                if ($null -ne $localScope.HomeStagesAuditSpinner) { $localScope.HomeStagesAuditSpinner.Visibility = 'Collapsed' }
            })
        }
    }.GetNewClosure()

    [System.Threading.Tasks.Task]::Run([System.Action]$stagesAction)

    # 4. Attach Event Handlers
    Write-Host "[DEBUG] Attaching event handlers..."
    try {
        if ($null -ne $scriptScope.HomeExecRunBtn) {
            $scriptScope.HomeExecRunBtn.Add_Click({
                Invoke-WithProgress "Execution" {
                    # Execute logic...
                    Write-Host "Execute clicked."
                } $scriptScope
            })
        }
    } catch { Write-Warning "[DEBUG] Handler attachment error: $_" }

    Write-Host "[DEBUG] Initialize-HomeTab complete."
}
