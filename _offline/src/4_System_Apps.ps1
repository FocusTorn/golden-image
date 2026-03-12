# Stage 3: System-Wide Core Apps (Offline Version)
# Location: _offline\Install_Stage_3_System_Apps.ps1

Param(
    [ValidateSet("All", "Chrome", "VSCode", "Git", "Go", "GitHubCLI", "UniGetUI")]
    [string]$App = "All"
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$InstallersDir = Join-Path (Split-Path $ScriptDir -Parent) "installers"

# --- SECTION 0: LOGGING & DRIVE DETECTION ---
$VhdDrive = (Get-PSDrive | Where-Object { Test-Path "$($_.Root)installers\VS_Offline" } | Select-Object -First 1).Root
if (-not $VhdDrive) {
    $StagingVolume = Get-Volume | Where-Object { $_.FileSystemLabel -eq "Staging" -and $_.DriveLetter -ne $null } | Select-Object -First 1
    if ($StagingVolume) { $VhdDrive = "$($StagingVolume.DriveLetter):\" }
}

if ($VhdDrive) {
    $ReturnPath = Join-Path $VhdDrive "return"
    if (!(Test-Path $ReturnPath)) { New-Item -Path $ReturnPath -ItemType Directory -Force | Out-Null }
    $LogFile = Join-Path $ReturnPath "Install_Stage_3_Apps_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    Start-Transcript -Path $LogFile -Force
}

function Ensure-MachinePath {
    param([string]$PathToAdd)
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $cleanPathToAdd = $PathToAdd.TrimEnd('\')
    $pathList = $currentPath.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.TrimEnd('\') }
    
    if ($pathList -notcontains $cleanPathToAdd) {
        Write-Host "    [*] Adding to Machine PATH: $cleanPathToAdd" -ForegroundColor Cyan
        $newPath = if ($currentPath.EndsWith(';')) { "$currentPath$cleanPathToAdd" } else { "$currentPath;$cleanPathToAdd" }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        $env:PATH = "$env:PATH;$cleanPathToAdd"
    }
}

function Install-Chrome {
    Write-Host "`n[*] Installing Google Chrome..." -ForegroundColor Yellow
    $filter = "01_Chrome_Standalone_x64.exe"
    $chromeInstaller = Get-ChildItem -Path $InstallersDir -Filter $filter | Select-Object -First 1
    if ($chromeInstaller) {
        Write-Host "    [EXEC] Running standalone installer: $($chromeInstaller.Name) (Visible)" -ForegroundColor Gray
        $p = Start-Process -FilePath $chromeInstaller.FullName -ArgumentList "/silent /install" -Wait -PassThru
        if ($p.ExitCode -eq 0) {
            Write-Host "    [PASS] Chrome installed." -ForegroundColor Green
        }
    }
}
function Install-VSCode {
    Write-Host "`n[*] Installing Visual Studio Code..." -ForegroundColor Yellow
    $filter = "*VSCode*System*.exe"
    $vscodeInstaller = Get-ChildItem -Path $InstallersDir -Filter $filter | Select-Object -First 1

    if ($vscodeInstaller) {
        # Check if the file is valid (more than 1MB)
        if ($vscodeInstaller.Length -lt 1MB) {
            Write-Host "    [ERROR] VS Code installer is corrupt or invalid (Size: $($vscodeInstaller.Length) bytes)." -ForegroundColor Red
            return
        }

        Write-Host "    [EXEC] Running system installer (Visible)..." -ForegroundColor Gray
        # VS Code uses Inno Setup. /SILENT shows progress, /VERYSILENT is hidden.
        Start-Process -FilePath $vscodeInstaller.FullName -ArgumentList "/SILENT /SUPPRESSMSGBOXES /NORESTART /MERGETASKS=`"!runcode,addcontextmenufiles,addcontextmenufolders,addtopath`"" -Wait
        Write-Host "    [PASS] VS Code installed." -ForegroundColor Green
        Ensure-MachinePath -PathToAdd "C:\Program Files\Microsoft VS Code\bin"
    } else {
        Write-Host "    [SKIP] VS Code installer not found." -ForegroundColor Cyan
    }
}

function Install-Git {
    Write-Host "`n[*] Installing Git for Windows..." -ForegroundColor Yellow
    $filter = "03_Git_for_Windows_x64.exe"
    $gitInstaller = Get-ChildItem -Path $InstallersDir -Filter $filter | Select-Object -First 1
    if ($gitInstaller) {
        Write-Host "    [EXEC] Running installer (Visible)..." -ForegroundColor Gray
        Start-Process -FilePath $gitInstaller.FullName -ArgumentList "/SILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS" -Wait
        Write-Host "    [PASS] Git installed." -ForegroundColor Green
        Ensure-MachinePath -PathToAdd "C:\Program Files\Git\cmd"
        Ensure-MachinePath -PathToAdd "C:\Program Files\Git\bin"
    }
}

function Install-Go {
    Write-Host "`n[*] Installing Go Language..." -ForegroundColor Yellow
    $filter = "04_Go_Lang_x64.msi"
    $goInstaller = Get-ChildItem -Path $InstallersDir -Filter $filter | Select-Object -First 1
    if ($goInstaller) {
        Write-Host "    [EXEC] Running MSI installer (Visible)..." -ForegroundColor Gray
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$($goInstaller.FullName)`" /passive /norestart" -Wait
        Write-Host "    [PASS] Go installed." -ForegroundColor Green
        Ensure-MachinePath -PathToAdd "C:\Program Files\Go\bin"
    }
}

function Install-GitHubCLI {
    Write-Host "`n[*] Installing GitHub CLI..." -ForegroundColor Yellow
    $filter = "*gh*amd64.msi"
    $ghInstaller = Get-ChildItem -Path $InstallersDir -Filter $filter | Select-Object -First 1
    if ($ghInstaller) {
        Write-Host "    [EXEC] Running MSI installer (Visible)..." -ForegroundColor Gray
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$($ghInstaller.FullName)`" /passive /norestart" -Wait
        Write-Host "    [PASS] GitHub CLI installed." -ForegroundColor Green
        Ensure-MachinePath -PathToAdd "C:\Program Files\GitHub CLI"
    }
}
function Install-UniGetUI {
    Write-Host "`n[*] Installing UniGetUI..." -ForegroundColor Yellow
    
    # 1. Attempt Silent Uninstall of existing version
    $uninstPath = "C:\Program Files\UniGetUI\unins000.exe"
    if (Test-Path $uninstPath) {
        Write-Host "    [PRE] Found existing UniGetUI. Uninstalling silently..." -ForegroundColor Gray
        $unp = Start-Process -FilePath $uninstPath -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -PassThru -Wait
        Start-Sleep -Seconds 2
    }

    $filter = "06_UniGetUI_Installer.exe"
    $unigetInstaller = Get-ChildItem -Path $InstallersDir -Filter $filter | Select-Object -First 1
    if ($unigetInstaller) {
        Write-Host "    [EXEC] Running installer (Visible)..." -ForegroundColor Gray
        # /SILENT shows progress. We use Start-Process with explicit monitoring to avoid hangs.
        $p = Start-Process -FilePath $unigetInstaller.FullName -ArgumentList "/SILENT /NORESTART /ALLUSERS /CLOSEAPPLICATIONS" -PassThru
        
        Write-Host "    [*] Waiting for installer to finish..." -NoNewline -ForegroundColor DarkGray
        while (!$p.HasExited) {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 2
        }
        Write-Host " Done." -ForegroundColor DarkGray

        Write-Host "    [PASS] UniGetUI installed." -ForegroundColor Green
        Ensure-MachinePath -PathToAdd "C:\Program Files\UniGetUI"
    }
}

try {
    Write-Host "--- STAGE 3: SYSTEM APP DEPLOYMENT ($App) ---" -ForegroundColor Cyan

    switch ($App) {
        "Chrome"       { Install-Chrome }
        "VSCode"       { Install-VSCode }
        "Git"          { Install-Git }
        "Go"           { Install-Go }
        "GitHubCLI"    { Install-GitHubCLI }
        "UniGetUI"     { Install-UniGetUI }
        "All" {
            Install-Chrome
            Install-VSCode
            Install-Git
            Install-Go
            Install-GitHubCLI
            Install-UniGetUI
        }
    }

    Write-Host "`n--- STAGE 3 COMPLETE ---" -ForegroundColor Green
}
finally {
    if ($LogFile) { Stop-Transcript }
}
