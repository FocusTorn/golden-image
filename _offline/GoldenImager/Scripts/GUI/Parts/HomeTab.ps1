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

    $window = $scriptScope.window
    $dispatcher = $window.Dispatcher
    $logFile = Join-Path $script:GoldenImagerRoot "Logs\AuditDebug.log"
    if (-not (Test-Path (Split-Path $logFile))) { New-Item -ItemType Directory (Split-Path $logFile) -Force | Out-Null }
    "--- Audit Log $(Get-Date) ---" | Out-File $logFile

    # Helper to check and set elements
    $checkAndSet = {
        param($name, $visibility)
        if ($null -ne $scriptScope[$name]) {
            $scriptScope[$name].Visibility = $visibility
        }
    }

    # 1. Immediate UI state
    &$checkAndSet "HomeModSpinner" "Collapsed"
    &$checkAndSet "HomeModContent" "Visible"
    &$checkAndSet "HomeExecSpinner" "Collapsed"
    &$checkAndSet "HomeExecContent" "Visible"

    # 2. Connection Settings Audit
    &$checkAndSet "HomeConnSpinner" "Visible"
    &$checkAndSet "HomeConnContent" "Collapsed"
    
    $localScope = $scriptScope

    $connAction = {
        param($disp, $scope, $log)
        try {
            "Starting Connection Audit..." | Out-File $log -Append
            
            # Real audits
            $lb = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -ErrorAction SilentlyContinue).LimitBlankPasswordUse
            if ($null -eq $lb) { $lb = 1 }
            $wrm = (Get-Service -Name WinRM -ErrorAction SilentlyContinue).Status -eq 'Running'
            $kiso = (Get-Service -Name KeyIso -ErrorAction SilentlyContinue).Status -eq 'Running'
            $adminOk = try { (Get-LocalUser -Name "Administrator" -ErrorAction SilentlyContinue).Enabled } catch { $false }
            
            "Audits complete. Dispatching to UI..." | Out-File $log -Append
            
            $disp.InvokeAsync([Action]{
                if ($null -ne $scope.HomeConnLimitBlank) { $scope.HomeConnLimitBlank.IsChecked = $lb -eq 0 }
                if ($null -ne $scope.HomeConnWinRM)      { $scope.HomeConnWinRM.IsChecked      = $wrm }
                if ($null -ne $scope.HomeConnKeyIso)     { $scope.HomeConnKeyIso.IsChecked     = $kiso }
                if ($null -ne $scope.HomeConnAdmin)      { $scope.HomeConnAdmin.IsChecked      = $adminOk }
                
                if ($null -ne $scope.HomeConnSpinner) { $scope.HomeConnSpinner.Visibility = 'Collapsed' }
                if ($null -ne $scope.HomeConnContent) { $scope.HomeConnContent.Visibility = 'Visible' }
            })
            "Connection Audit Dispatch Sent." | Out-File $log -Append
        } catch {
            "CRASH in Connection Audit: $($_.Exception.Message)" | Out-File $log -Append
            $err = $_.Exception.Message
            $disp.InvokeAsync([Action]{
                if ($null -ne $scope.HomeConnError)   { $scope.HomeConnError.Text = "Err: $err"; $scope.HomeConnError.Visibility = 'Visible' }
                if ($null -ne $scope.HomeConnSpinner) { $scope.HomeConnSpinner.Visibility = 'Collapsed' }
            })
        }
    }

    # Run Connection Task
    [System.Threading.Tasks.Task]::Run([System.Action]{ &$connAction $dispatcher $localScope $logFile })

    # 3. Stages Audit
    &$checkAndSet "HomeStagesAuditSpinner" "Visible"
    &$checkAndSet "HomeStagesAuditContent" "Collapsed"

    $stagesAction = {
        param($disp, $scope, $log)
        try {
            "Starting Stages Audit..." | Out-File $log -Append
            $auditData = @()
            $ps7Ok = Test-Path "C:\Program Files\PowerShell\7\pwsh.exe"
            $auditData += @{ Name = "Customization & PWSH 7"; Status = if ($ps7Ok) { "Green" } else { "Gray" } }
            
            $msvcOk = Test-Path "HKLM:\SOFTWARE\Classes\Installer\Dependencies\VC,redist.x64,amd64,14.0,bundle"
            $auditData += @{ Name = "MSVC Runtimes"; Status = if ($msvcOk) { "Green" } else { "Gray" } }
            
            $appsOk = Test-Path "C:\ProgramData\Chocolatey\bin\choco.exe" -or Test-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
            $auditData += @{ Name = "App Infrastructure"; Status = if ($appsOk) { "Green" } else { "Gray" } }
            
            "Stages Audits complete. Dispatching..." | Out-File $log -Append
            
            $disp.InvokeAsync([Action]{
                if ($null -eq $scope.HomeStagesAuditPanel) { return }
                $scope.HomeStagesAuditPanel.Children.Clear()
                
                foreach ($item in $auditData) {
                    $color = if ($item.Status -eq "Green") { [System.Windows.Media.Brushes]::LimeGreen } else { [System.Windows.Media.Brushes]::DimGray }
                    $tb = New-Object System.Windows.Controls.TextBlock -Property @{ 
                        Text = "• $($item.Name)"; 
                        Margin = "2,0,0,4"; 
                        Foreground = $color;
                        FontWeight = "SemiBold"
                    }
                    $scope.HomeStagesAuditPanel.Children.Add($tb) | Out-Null
                }
                
                if ($null -ne $scope.HomeStagesAuditSpinner) { $scope.HomeStagesAuditSpinner.Visibility = 'Collapsed' }
                if ($null -ne $scope.HomeStagesAuditContent) { $scope.HomeStagesAuditContent.Visibility = 'Visible' }
            })
            "Stages Audit Dispatch Sent." | Out-File $log -Append
        } catch {
            "CRASH in Stages Audit: $($_.Exception.Message)" | Out-File $log -Append
            $err = $_.Exception.Message
            $disp.InvokeAsync([Action]{
                if ($null -ne $scope.HomeStagesAuditError)   { $scope.HomeStagesAuditError.Text = "Err: $err"; $scope.HomeStagesAuditError.Visibility = 'Visible' }
                if ($null -ne $scope.HomeStagesAuditSpinner) { $scope.HomeStagesAuditSpinner.Visibility = 'Collapsed' }
            })
        }
    }

    # Run Stages Task
    [System.Threading.Tasks.Task]::Run([System.Action]{ &$stagesAction $dispatcher $localScope $logFile })

    # 4. Attach Event Handlers
    try {
        if ($null -ne $scriptScope.HomeApplyFeaturesBtn) {
            $scriptScope.HomeApplyFeaturesBtn.Add_Click({ Write-Host "Apply Changes clicked." })
        }
        if ($null -ne $scriptScope.HomeExecRunBtn) {
            $scriptScope.HomeExecRunBtn.Add_Click({
                Invoke-WithProgress "Execution" { Write-Host "Execute clicked." } $scriptScope
            })
        }
    } catch { Write-Warning "[DEBUG] Handler attachment error: $_" }

    Write-Host "[DEBUG] Initialize-HomeTab complete."
}
