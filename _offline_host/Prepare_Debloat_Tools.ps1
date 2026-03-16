# Prepare_Debloat_Tools.ps1
# Run this on your HOST machine with internet access.
# Downloads the necessary tools for offline Windows optimization.

$ErrorActionPreference = "Stop"
$InstallersDir = "P:\Projects\golden-image\installers"

# Ensure directories exist
if (-not (Test-Path $InstallersDir)) { New-Item -ItemType Directory -Path $InstallersDir | Out-Null }

Write-Host "--- PREPARING OFFLINE DEBLOAT & PRIVACY TOOLS ---" -ForegroundColor Cyan

function Download-Tool {
    param([string]$Url, [string]$Dest, [string]$Name)
    Write-Host "[*] Downloading $Name..." -ForegroundColor Yellow
    try {
        # Using Invoke-WebRequest for better redirect/TLS handling
        Invoke-WebRequest -Uri $Url -OutFile $Dest -UserAgent "Mozilla/5.0" -ErrorAction Stop
        $size = (Get-Item $Dest).Length
        Write-Host "    [OK] $Name ready ($([math]::Round($size/1MB, 2)) MB)." -ForegroundColor Green
    } catch {
        Write-Host "    [FAIL] Could not download ${Name}: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 1. Titus WinUtil (Stable Release Version)
# The raw GitHub URL for winutil.ps1 often 404s because it's compiled. 
# The Release version is the most stable and contains everything in one file.
$winutilUrl = "https://github.com/ChrisTitusTech/winutil/releases/latest/download/winutil.ps1"
Download-Tool -Url $winutilUrl -Dest (Join-Path $InstallersDir "WinUtil.ps1") -Name "Titus WinUtil"

# 2. Raphire Win11Debloat (FULL REPO for Offline Support)
# The script depends on supporting files (icons, data), so we download the ZIP.
$raphireZipUrl = "https://github.com/Raphire/Win11Debloat/archive/refs/heads/master.zip"
$raphireZipDest = Join-Path $InstallersDir "Win11Debloat.zip"
$raphireExtractDir = Join-Path $InstallersDir "Win11Debloat-Source"

Download-Tool -Url $raphireZipUrl -Dest $raphireZipDest -Name "Raphire Win11Debloat (Full ZIP)"

if (Test-Path $raphireZipDest) {
    Write-Host "[*] Extracting Win11Debloat..." -ForegroundColor Yellow
    if (Test-Path $raphireExtractDir) { Remove-Item $raphireExtractDir -Recurse -Force }
    Expand-Archive -Path $raphireZipDest -DestinationPath $InstallersDir -Force
    $extractedFolder = Join-Path $InstallersDir "Win11Debloat-master"
    if (Test-Path $extractedFolder) { Rename-Item $extractedFolder $raphireExtractDir -Force }
    Copy-Item (Join-Path $raphireExtractDir "Win11Debloat.ps1") (Join-Path $InstallersDir "Win11Debloat.ps1") -Force
    Write-Host "    [OK] Win11Debloat extracted and ready." -ForegroundColor Green
}

# 3. O&O ShutUp10++ (Portable EXE)
$oosu10Url = "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe"
Download-Tool -Url $oosu10Url -Dest (Join-Path $InstallersDir "OOSU10.exe") -Name "O&O ShutUp10++"

# 4. O&O AppBuster (Portable EXE)
$ooapbUrl = "https://dl5.oo-software.com/files/ooappbuster/OOAPB.exe"
Download-Tool -Url $ooapbUrl -Dest (Join-Path $InstallersDir "OOAppBuster.exe") -Name "O&O AppBuster"

Write-Host "`n[SUCCESS] Preparation complete." -ForegroundColor Green
Write-Host "Files located in: $InstallersDir" -ForegroundColor White
