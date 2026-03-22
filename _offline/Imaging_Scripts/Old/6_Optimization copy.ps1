# Stage 5: Optimization & Privacy (Offline Version)
# Location: _offline\Install_Stage_5_Optimization.ps1

$ErrorActionPreference = "Stop"

# --- SECTION 0: STAGING DRIVE DETECTION ---
# 1) Label "Golden Imaging" 2) Fallback: Z..A reverse search for installers or _offline
$StagingDrive = $null
$StagingVolume = Get-Volume | Where-Object { $_.FileSystemLabel -eq "Golden Imaging" -and $_.DriveLetter -ne $null } | Select-Object -First 1
if ($StagingVolume) { $StagingDrive = $StagingVolume.DriveLetter }
if (-not $StagingDrive) {
    foreach ($d in [char[]](90..65)) {
        $root = "${d}:\"
        if ((Test-Path (Join-Path $root "installers")) -or (Test-Path (Join-Path $root "_offline"))) {
            $StagingDrive = $d
            break
        }
    }
}
$VhdDrive = if ($StagingDrive) { "${StagingDrive}:\" } else { $null }

if (-not $VhdDrive) {
    Write-Host "[ERROR] Staging drive not found (label 'Golden Imaging' or drive with installers/_offline)." -ForegroundColor Red
    return
}

$InstallersDir = Join-Path $VhdDrive "installers"
$ConfigDir = $PSScriptRoot

# Define Tool Paths
$WinUtilScript = Join-Path $InstallersDir "WinUtil.ps1"
$GoldenImager   = Join-Path $VhdDrive "_offline\GoldenImager\GoldenImager.ps1"
$OOSU10Exe     = Join-Path $InstallersDir "OOSU10.exe"
$OOAPBExe      = Join-Path $InstallersDir "OOAppBuster.exe"
$OOSU10Cfg     = Join-Path $ConfigDir "ooshutup10.cfg"
$CTTCfg        = Join-Path $ConfigDir "CTT.json"

Write-Host "--- STAGE 5: WINDOWS OPTIMIZATION (OFFLINE) ---" -ForegroundColor Cyan

function Invoke-Titus {
    Write-Host "`n[*] Launching Titus WinUtil (Offline Mode)..." -ForegroundColor Yellow
    if (Test-Path $WinUtilScript) {
        if (Test-Path $CTTCfg) {
            Write-Host "    -> Applying settings from CTT.json..." -ForegroundColor Gray
            powershell -ExecutionPolicy Bypass -File $WinUtilScript -Config $CTTCfg
        } else {
            powershell -ExecutionPolicy Bypass -File $WinUtilScript
        }
    } else {
        Write-Host "[ERROR] WinUtil.ps1 not found in installers." -ForegroundColor Red
    }
}

function Invoke-GoldenImager {
    Write-Host "`n[*] Launching Golden Imager (Offline Mode)..." -ForegroundColor Yellow
    if (Test-Path $GoldenImager) {
        powershell -ExecutionPolicy Bypass -File $GoldenImager
    } else {
        Write-Host "[ERROR] GoldenImager.ps1 not found in _offline." -ForegroundColor Red
    }
}

function Invoke-ShutUp10 {
    Write-Host "`n[*] Launching O&O ShutUp10++..." -ForegroundColor Yellow
    if (Test-Path $OOSU10Exe) {
        if (Test-Path $OOSU10Cfg) {
            Write-Host "    -> Importing custom config: ooshutup10.cfg" -ForegroundColor Gray
            # /quiet /apply can be used for automation, but usually user wants to see UI
            Start-Process $OOSU10Exe -ArgumentList "`"$OOSU10Cfg`"" -Wait
        } else {
            Start-Process $OOSU10Exe -Wait
        }
    } else {
        Write-Host "[ERROR] OOSU10.exe not found." -ForegroundColor Red
    }
}

function Invoke-AppBuster {
    Write-Host "`n[*] Launching O&O AppBuster..." -ForegroundColor Yellow
    if (Test-Path $OOAPBExe) {
        Start-Process $OOAPBExe -Wait
    } else {
        Write-Host "[ERROR] OOAppBuster.exe not found." -ForegroundColor Red
    }
}

:OptLoop while ($true) {
    Write-Host "`nSELECT OPTIMIZATION TOOL:" -ForegroundColor Cyan
    Write-Host "  1. Titus WinUtil (Tweaks & Updates)"
    Write-Host "  2. Golden Imager (Bloatware & UI)"
    Write-Host "  3. O&O ShutUp10++ (Privacy & Telemetry)"
    Write-Host "  4. O&O AppBuster (Hidden App Removal)"
    Write-Host "  A. Run ALL (Sequential)"
    Write-Host "  X. Back to Main Dashboard"
    Write-Host ""
    
    $choice = Read-Host "Choice"
    switch ($choice) {
        "1" { Invoke-Titus }
        "2" { Invoke-GoldenImager }
        "3" { Invoke-ShutUp10 }
        "4" { Invoke-AppBuster }
        "a" { Invoke-Titus; Invoke-GoldenImager; Invoke-ShutUp10; Invoke-AppBuster }
        "x" { break OptLoop }
    }
}
