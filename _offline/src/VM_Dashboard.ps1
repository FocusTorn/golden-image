# Master_Dashboard.ps1
# Location: _offline\Master_Dashboard.ps1
# High-precision Machine-Scope Dashboard.

$ErrorActionPreference = "Continue"
$off = $PSScriptRoot
$script:DashboardLevel = 0


function Update-Environment { #>
    $HKLM = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment"
    Get-ItemProperty $HKLM | Get-Member -MemberType NoteProperty | ForEach-Object {
        $name = $_.Name
        $val = (Get-ItemProperty $HKLM).$name
        if ($null -ne $val -and $name -ne "Path") {
            $expandedVal = [Environment]::ExpandEnvironmentVariables($val)
            [Environment]::SetEnvironmentVariable($name, $expandedVal, "Process")
        }
    }
    $mPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $env:PATH = [Environment]::ExpandEnvironmentVariables($mPath)
    Get-Command -Name * -ErrorAction SilentlyContinue | Out-Null
} #<

function Get-GranularStatus { #>
    param(
        [string]$Name,
        [string]$RegName,      
        [string]$ExeName,      
        [string]$LnkName,      
        [switch]$NoPath,       
        [switch]$NoReg,        
        [switch]$NoLnk,        
        [string]$FileCheck,
        [scriptblock]$FunctionalCheck 
    )

    $allPassed = $true
    Write-Host "  " -NoNewline
    
    if ($NoReg) { #> Registry (Machine Scope Only)
        Write-Host "[REG] " -NoNewline -ForegroundColor DarkGray
    } else {
        $regPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
        $reg = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$RegName*" } | Select-Object -First 1
        $regOk = [bool]$reg
        if (!$regOk) { $allPassed = $false }
        Write-Host "[REG] " -NoNewline -ForegroundColor $(if($regOk){"Green"}else{"Red"})
    } #<

    if ($NoPath) { #> Path & Functional Check
        Write-Host "[PATH] " -NoNewline -ForegroundColor DarkGray
    } else {
        $pathOk = [bool](Get-Command $ExeName -ErrorAction SilentlyContinue)
        if ($pathOk -and $FunctionalCheck) { $pathOk = & $FunctionalCheck }
        if (!$pathOk) { $allPassed = $false }
        Write-Host "[PATH] " -NoNewline -ForegroundColor $(if($pathOk){"Green"}else{"Red"})
    } #<

    if ($NoLnk) {#> Shortcut (Machine Scope Only)
        Write-Host "[LNK] " -NoNewline -ForegroundColor DarkGray
    } else {
        $lnkDirs = @("C:\ProgramData\Microsoft\Windows\Start Menu", "C:\ProgramData\Microsoft\Windows\Start Menu\Programs")
        $lnk = Get-ChildItem -Path $lnkDirs -Filter "*$LnkName*" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        $lnkOk = [bool]$lnk
        if (!$lnkOk) { $allPassed = $false }
        Write-Host "[LNK] " -NoNewline -ForegroundColor $(if($lnkOk){"Green"}else{"Red"})
    } #<

    if ($FileCheck -and !(Test-Path $FileCheck)) { #> Mandatory Physical File Check
         $allPassed = $false
    } #<

    $nameColor = if ($allPassed) { "Green" } else { "White" }
    Write-Host " $Name" -ForegroundColor $nameColor
} #<

function Show-Header { #>
    Update-Environment 
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "             GOLDEN MASTER INSTALLATION DASHBOARD               " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
} #<
    
function Show-Connections { #>
    # 1. AUDIT SECTION (The Essentials Only)
    $AuditTable = @(
        @{ Category = "Registry"; Setting = "LimitBlankPasswordUse"; Property = "LimitBlankPasswordUse"; Path = "HKLM:\System\CurrentControlSet\Control\Lsa"; Target = "0" },
        @{ Category = "Service";  Setting = "WinRM Service"; Name = "WinRM"; Target = "Running (Automatic)" },
        @{ Category = "Service";  Setting = "KeyIso (Cryptography)"; Name = "KeyIso"; Target = "Running (Automatic)" },
        @{ Category = "Identity"; Setting = "Built-in Admin Account"; Target = "True" }
    )
    
    Write-Host "Connections:"

    foreach ($Item in $AuditTable) {
        $Value = "Null"; $IsGood = $false
        if ($Item.Category -eq "Registry") {
            if (Test-Path $Item.Path) {
                try { 
                    $Val = Get-ItemPropertyValue -Path $Item.Path -Name $Item.Property -ErrorAction Stop 
                    $Value = $Val.ToString()
                    if ($Value -eq $Item.Target) { $IsGood = $true }
                } catch { $Value = "Null (Missing)" }
            } else { $Value = "Path Not Found" }
        }
        elseif ($Item.Category -eq "Service") {
            try {
                $Svc = Get-Service -Name $Item.Name -ErrorAction Stop
                $Value = "$($Svc.Status) ($($Svc.StartType))"
                if ($Value -like "Running*Auto*") { $IsGood = $true }
            } catch { $Value = "Not Installed" }
        }
        elseif ($Item.Category -eq "Identity") {
            $Admin = Get-LocalUser | Where-Object { $_.SID -like "*-500" }
            $Value = if ($Admin) { $Admin.Enabled.ToString() } else { "Not Found" }
            if ($Value -eq "True") { $IsGood = $true }
        }
        $Color = if ($IsGood) { "Green" } else { "Red" }
        Write-Host ("  {0,-24}  {1,-20}  Target: {2}" -f $Item.Setting, $Value, $Item.Target) -ForegroundColor $Color
    }
    Write-Host ""
} #<
    
function Show-GranularStatus { #>
    Write-Host "Applications:"
    Get-GranularStatus "PowerShell 7 (Core)" -RegName "PowerShell 7" -ExeName "pwsh" -LnkName "PowerShell 7" -FileCheck "C:\Program Files\PowerShell\7\pwsh.exe"
    
    # Scoop Core & Search (Grouped)
    Get-GranularStatus "Scoop (Core)" -ExeName "scoop" -NoReg -NoLnk -FileCheck "C:\Scoop\shims\scoop.ps1"
    Get-GranularStatus "  -> Scoop Search" -ExeName "scoop-search" -NoReg -NoLnk -FileCheck "C:\Scoop\shims\scoop-search.exe"
    
    
    # MSVC
    Get-GranularStatus "MSVC Build Tools (Base)" -RegName "Visual Studio Build Tools" -NoPath -NoLnk -FileCheck "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    Get-GranularStatus "MSVC Toolchain (PATH)" -ExeName "cl.exe" -NoReg -NoLnk -FunctionalCheck { return [bool](Get-Command cl.exe -ErrorAction SilentlyContinue) }

    # Apps
    Get-GranularStatus "Google Chrome" -RegName "Google Chrome" -LnkName "Chrome" -NoPath -FileCheck "C:\Program Files\Google\Chrome\Application\chrome.exe"
    Get-GranularStatus "Visual Studio Code" -RegName "Visual Studio Code" -ExeName "code" -LnkName "Visual Studio Code" -FileCheck "C:\Program Files\Microsoft VS Code\bin\code.cmd"
    Get-GranularStatus "Go Language" -RegName "Go Programming Language" -ExeName "go" -NoLnk -FunctionalCheck { return [bool](Get-Command go -ErrorAction SilentlyContinue) }
    Get-GranularStatus "Git for Windows" -RegName "Git" -ExeName "git" -LnkName "Git" -FileCheck "C:\Program Files\Git\bin\git.exe"
    Get-GranularStatus "GitHub CLI" -RegName "GitHub CLI" -ExeName "gh" -NoLnk -FileCheck "C:\Program Files\GitHub CLI\gh.exe"
    Get-GranularStatus "UniGetUI" -RegName "UniGetUI" -ExeName "unigetui" -LnkName "UniGetUI" -FileCheck "C:\Program Files\UniGetUI\unigetui.exe"
    
    # Rust
    Get-GranularStatus "Rust (Manager/Base)" -RegName "Rust" -ExeName "rustup" -NoPath -NoLnk -FileCheck "$env:USERPROFILE\.cargo\bin\rustup.exe"
    Get-GranularStatus "Rust (Toolchain/PATH)" -ExeName "rustc" -NoReg -NoLnk -FunctionalCheck {
        $list = & rustup toolchain list 2>$null
        $version = & rustc --version 2>$null
        return ($list -and $list -notlike "*(none)*" -and $version)
    }

    # Optimizations
    Get-GranularStatus "Optimization Suite" -ExeName "powershell" -NoReg -NoLnk -FileCheck "$off\Install_Stage_5_Optimization.ps1"
    
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
} #<

function Invoke-DashboardTask { #>
    param([string]$Name, [scriptblock]$Task)
    Write-Host "`n>>> STARTING: $Name" -ForegroundColor Cyan
    $script:DashboardLevel = 0
    $script:LastError = $null
    try {
        & $Task
        Write-Host "`n[SUCCESS] $Name completed." -ForegroundColor Green
    } catch {
        Write-Host "`n[ERROR] $Name encountered a failure." -ForegroundColor Red
    }
    Read-Host "`nPress Enter to return to menu"
} #<

function Invoke-Group { #>
    param([string]$Name, [scriptblock]$Steps)
    $indent = "  " * ($script:DashboardLevel + 1)
    Write-Host "$indent$Name" -ForegroundColor Yellow
    $script:DashboardLevel++
    try {
        & $Steps
    } finally {
        $script:DashboardLevel--
    }
} #<

function Invoke-Step { #>
    param([string]$Name, [scriptblock]$Task, [scriptblock]$Verify)
    $indent = "  " * ($script:DashboardLevel + 1)
    
    try {
        $null = & $Task
        $passed = $true
        if ($Verify) { $passed = [bool](& $Verify) }
        
        if ($passed) {
            Write-Host "$indent[OK]   $Name" -ForegroundColor Green
        } else {
            Write-Host "$indent[FAIL] $Name (Verify Failed)" -ForegroundColor Red
        }
    } catch {
        Write-Host "$indent[FAIL] $Name" -ForegroundColor Red
        if ($null -eq $script:LastError -or $script:LastError -ne $_) {
            Write-Host "$indent     $($_.Exception.Message)" -ForegroundColor Gray
            $script:LastError = $_
        }
        throw $_
    }
} #<

:MainLoop while ($true) {
    Show-Header
    Show-Connections
    Show-GranularStatus
    
    Write-Host "SELECT AN INSTALLATION OPTION:" -ForegroundColor Yellow
    Write-Host "  1. Customize (Cleanup & PS7)"
    Write-Host "  2. Scoop (inc. Basic Tools & Search)"
    Write-Host "  3. MSVC Build Tools"
    Write-Host "  4. ALL System Apps"
    Write-Host "     41. Chrome"
    Write-Host "     42. VS Code"
    Write-Host "     43. Go"
    Write-Host "     44. Git"
    Write-Host "     45. Git CLI"
    Write-Host "     46. UniGetUI"
    Write-Host "  5. Rust (w/ Cargo Helpers)"
    Write-Host "  6. Run Optimization Suite (Titus, O&O)"
    Write-Host ""
    Write-Host "  C. Update Connections"
    Write-Host "  O. Open F:\_offline"
    Write-Host "  R. Refresh Status"
    Write-Host "  X. Exit Dashboard"
    Write-Host ""
    
    $choice = Read-Host "Choice"
    
    switch ($choice) {
        "1" { Invoke-DashboardTask "Customize" { cmd /c "$off\1_Customize.bat" } }
        "2" { Invoke-DashboardTask "Scoop" { & "$off\2_Scoop.ps1" } }
        "3" { Invoke-DashboardTask "MSVC Build Tools" { & "$off\3_MSVC.ps1" } }
        "4" { Invoke-DashboardTask "ALL System Apps" { & "$off\4_System_Apps.ps1" -App "All" } }
        "41" { Invoke-DashboardTask "Google Chrome" { & "$off\4_System_Apps.ps1" -App "Chrome" } }
        "42" { Invoke-DashboardTask "VS Code" { & "$off\4_System_Apps.ps1" -App "VSCode" } }
        "43" { Invoke-DashboardTask "Go Language" { & "$off\4_System_Apps.ps1" -App "Go" } }
        "44" { Invoke-DashboardTask "Git for Windows" { & "$off\4_System_Apps.ps1" -App "Git" } }
        "45" { Invoke-DashboardTask "GitHub CLI" { & "$off\4_System_Apps.ps1" -App "GitHubCLI" } }
        "46" { Invoke-DashboardTask "UniGetUI" { & "$off\4_System_Apps.ps1" -App "UniGetUI" } }
        "5" { Invoke-DashboardTask "Rust" { & "$off\5_Rust_Finish.ps1" } }
        "6" { Invoke-DashboardTask "Optimization Suite" { & "$off\6_Optimization.ps1" } }
        
        "c"{ 
            Invoke-DashboardTask "Update Connections" {
                Invoke-Step "Enable Administrator Account" -Task {
                    $AdminName = (Get-LocalUser | Where-Object { $_.SID -like "*-500" }).Name
                    Enable-LocalUser -Name $AdminName -ErrorAction Stop
                } -Verify { 
                    $Admin = Get-LocalUser | Where-Object { $_.SID -like "*-500" }
                    return $Admin.Enabled
                }

                Invoke-Step "Set LimitBlankPasswordUse=0" -Task {
                    reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v "LimitBlankPasswordUse" /t REG_DWORD /d 0 /f | Out-Null
                } -Verify {
                    (Get-ItemPropertyValue -Path "HKLM:\System\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse") -eq 0
                }

                Invoke-Group "Configure KeyIso Service" {
                    Invoke-Step "Set Startup Type: Automatic" -Task { Set-Service KeyIso -StartupType Automatic -ErrorAction Stop } -Verify { (Get-Service KeyIso).StartType -eq "Automatic" }
                    Invoke-Step "Start Service" -Task { Start-Service KeyIso -ErrorAction SilentlyContinue } -Verify { (Get-Service KeyIso).Status -eq "Running" }
                }

                Invoke-Group "Configure WinRM Service" {
                    Invoke-Step "Set Startup Type: Automatic" -Task { Set-Service WinRM -StartupType Automatic -ErrorAction Stop } -Verify { (Get-Service WinRM).StartType -eq "Automatic" }
                    Invoke-Step "Run QuickConfig" -Task { & winrm quickconfig -quiet 2>$null >$null } -Verify { (Get-Service WinRM).Status -eq "Running" }
                }
            }
        }
        "o" { Invoke-Item "F:\_offline"; Read-Host "`nPress Enter to return to menu" }
        "r" { continue }
        "x" { break MainLoop }
        
        default { Write-Host "Invalid choice!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
