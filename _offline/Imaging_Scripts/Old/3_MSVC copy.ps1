#  Stage 2: Master MSVC & Installer Engine Injector (OFFLINE)
#  Optimized for Windows 11 Golden Image / Audit Mode
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "`n>>> [1/5] DETECTING VHD STORAGE" -ForegroundColor Cyan
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

$LayoutSource = Join-Path $VhdDrive "installers\VS_Offline"
$ReturnPath   = Join-Path $VhdDrive "return"

Write-Host "[*] VHD Drive detected: $VhdDrive" -ForegroundColor Gray
Write-Host "[*] Layout Source: $LayoutSource" -ForegroundColor Gray


Write-Host "`n>>> [2/5] SYSTEM PREP ^& TRUSTING CERTS" -ForegroundColor Cyan

# Ensure CNG Key Isolation service is running (Critical for signature checks)
Write-Host "[*] Ensuring CNG Key Isolation service is running..." -Yellow
Set-Service -Name "KeyIso" -StartupType Manual -ErrorAction SilentlyContinue
Start-Service -Name "KeyIso" -ErrorAction SilentlyContinue

# Kill hung processes
$VSProcs = "vs_setup", "vs_installershell", "setup", "vs_installer"
Get-Process -Name $VSProcs -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

if (-not (Test-Path $ReturnPath)) { New-Item -Path $ReturnPath -ItemType Directory -Force | Out-Null }

# --- CRITICAL: TRUST CERTIFICATES ---
$CertFolders = @(
    (Join-Path $LayoutSource "certificates"),
    (Join-Path $VhdDrive "installers")
)

foreach ($folder in $CertFolders) {
    if (Test-Path $folder) {
        Write-Host "[*] Injecting Certificates from $folder..." -Yellow
        Get-ChildItem -Path $folder -Include "*.cer", "*.crt" -Recurse | ForEach-Object {
            Unblock-File $_.FullName
            certutil.exe -addstore -f "Root" $_.FullName | Out-Null
            certutil.exe -addstore -f "CA" $_.FullName | Out-Null
            certutil.exe -addstore -f "TrustedPublisher" $_.FullName | Out-Null
            Write-Host "    + Trusted: $($_.Name)" -DarkGray
        }
    }
}

# --- FIX: Type Conversion Error ---
# Use a simple array construction to avoid type issues
$File1 = Join-Path $LayoutSource "vs_setup.exe"
$File2 = Join-Path $LayoutSource "vs_installer.opc"
$TargetFiles = @($File1, $File2)

foreach ($file in $TargetFiles) {
    if (Test-Path $file) {
        Write-Host "[*] Trusting digital signature of $(Split-Path $file -Leaf)..." -Yellow
        certutil.exe -addstore -f "Root" $file | Out-Null
        certutil.exe -addstore -f "CA" $file | Out-Null
        certutil.exe -addstore -f "TrustedPublisher" $file | Out-Null
    }
}


Write-Host "`n>>> [3/5] IDENTIFYING INSTALL STATE" -ForegroundColor Cyan
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$setupExe = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"
$ResponseJson = Join-Path $LayoutSource "Response.json"

$existingPath = $null
if (Test-Path $vswhere) {
    $existingPath = & $vswhere -all -products * -property installationPath 2>$null | Select-Object -First 1
}

# --- CRITICAL: MINIMALIST OFFLINE FLAGS ---
$CommonArgs = @(
    "--noWeb",
    "--noUpdateInstaller",
    "--wait",
    "--norestart",
    "--passive",
    "--in", $ResponseJson
)

if ($existingPath) {
    Write-Host "[*] Build Tools already installed at: $existingPath" -ForegroundColor Gray
    Write-Host "[*] Action: MODIFING existing instance..." -Yellow
    # In Modify mode, we must tell the system-installed setup.exe where the layout is.
    $FinalArgs = @("modify", "--installPath", $existingPath, "--layoutPath", $LayoutSource) + $CommonArgs
    $TargetExe = $setupExe
    $WorkDir = Split-Path $setupExe
} else {
    Write-Host "[*] No Build Tools found." -ForegroundColor Gray
    Write-Host "[*] Action: FRESH INSTALL from Layout..." -Yellow
    # Fresh install picks up workload from Response.json automatically if run from layout folder.
    $FinalArgs = $CommonArgs
    $TargetExe = Join-Path $LayoutSource "vs_setup.exe"
    $WorkDir = $LayoutSource
}


Write-Host "`n>>> [4/5] LAUNCHING INSTALLER" -ForegroundColor Cyan
Write-Host "[*] Command: $TargetExe $($FinalArgs -join ' ')" -ForegroundColor DarkGray

$process = Start-Process -FilePath $TargetExe -ArgumentList $FinalArgs -WorkingDirectory $WorkDir -Wait -PassThru


Write-Host "`n>>> [5/5] HARVESTING DIAGNOSTICS" -ForegroundColor Cyan
$TempPath = $env:TEMP
$LogPatterns = @("dd_bootstrapper*.log", "dd_installer*.log", "vs_setup*.log")

foreach ($pattern in $LogPatterns) {
    Get-ChildItem -Path $TempPath -Filter $pattern -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-10) } | ForEach-Object {
        $dest = Join-Path $ReturnPath $_.Name
        Copy-Item -Path $_.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
        Write-Host "    -> Log Staged: $($_.Name)" -DarkGray
    }
}

if ($null -ne $process) {
    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
        Write-Host "`n[***] SUCCESS: MSVC READY [***]" -ForegroundColor Green
    } else {
        Write-Host "`n[***] ERROR: Exit Code $($process.ExitCode). Check VHD:\return logs. [***]" -ForegroundColor Red
    }
}
