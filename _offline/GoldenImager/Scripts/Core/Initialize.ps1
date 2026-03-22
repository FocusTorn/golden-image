# Check if current powershell environment is limited by security policies
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Error "Golden Imager is unable to run on your system, powershell execution is restricted by security policies"
    Write-Output "Press any key to exit..."
    $null = [System.Console]::ReadKey()
    Exit
}

Clear-Host
Write-Host ""
Write-Host "             Golden Imager is launching..." -ForegroundColor White
Write-Host "               Leave this window open" -ForegroundColor DarkGray
Write-Host ""

# Log script output and errors to GoldenImager.log
$script:LogFilePath = if ($LogPath -and (Test-Path $LogPath)) { Join-Path $LogPath "GoldenImager.log" } else { $script:DefaultLogPath }
$logDir = Split-Path $script:LogFilePath -Parent
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
Start-Transcript -Path $script:LogFilePath -Append -IncludeInvocationHeader -Force | Out-Null

# Trap terminating errors (transcript captures Write-Host; do not Add-Content - causes encoding corruption)
trap {
    $errLine = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ERROR: $($_.Exception.Message)"
    if ($_.ScriptStackTrace) { $errLine += "`n$($_.ScriptStackTrace)" }
    Write-Host $errLine -ForegroundColor Red
    continue
}

# Check if script has all required files
# GuiFork: Skip DefaultSettings.json check - we go directly to Custom Setup
if (-not ((Test-Path $script:AppsListFilePath) -and (Test-Path $script:RegfilesPath) -and (Test-Path $script:AssetsPath) -and (Test-Path $script:AppSelectionSchema) -and (Test-Path $script:ApplyChangesWindowSchema) -and (Test-Path $script:SharedStylesSchema) -and (Test-Path $script:FeaturesFilePath))) {
    Write-Error "Golden Imager is unable to find required files, please ensure all script files are present"
    Write-Output ""
    Write-Output "Press any key to exit..."
    $null = [System.Console]::ReadKey()
    Exit
}

# Load feature info from file
$script:Features = @{}
try {
    $featuresData = Get-Content -Path $script:FeaturesFilePath -Raw | ConvertFrom-Json
    foreach ($feature in $featuresData.Features) {
        $script:Features[$feature.FeatureId] = $feature
    }
}
catch {
    Write-Error "Failed to load feature info from Features.json file"
    Write-Output ""
    Write-Output "Press any key to exit..."
    $null = [System.Console]::ReadKey()
    Exit
}

# Check if WinGet is installed & store full path for use in background jobs
try {
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        $script:WingetInstalled = $true
        $script:WingetPath = $wingetCmd.Source
    }
    else {
        $script:WingetInstalled = $false
        $script:WingetPath = $null
    }
}
catch {
    Write-Error "Unable to determine if WinGet is installed, winget command failed: $_"
    $script:WingetInstalled = $false
    $script:WingetPath = $null
}

# Copy log file to return path when it exists (after transcript is stopped)
function Copy-LogToReturnPath {
    if (-not $script:LogFilePath -or -not (Test-Path $script:LogFilePath)) { return }
    $offlineDir = Split-Path $PSScriptRoot -Parent
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
        try {
            $destPath = Join-Path $returnDir "GoldenImager.log"
            Copy-Item -Path $script:LogFilePath -Destination $destPath -Force
        } catch {}
    }
}
