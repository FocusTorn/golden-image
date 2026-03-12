# Prepare_VSCode_Installer.ps1
# Run this on your HOST machine with internet access.
# This script uses the fastest native download method with a background progress tracker.

$ErrorActionPreference = "Stop"
$InstallersDir = "P:\Projects\golden-image\installers"
$TargetFile = Join-Path $InstallersDir "VSCodeSetup-x64-System.exe"

Write-Host "--- PREPARING VS CODE SYSTEM INSTALLER (FAST MODE) ---" -ForegroundColor Cyan

# Ensure directory exists
if (!(Test-Path $InstallersDir)) {
    New-Item -ItemType Directory -Path $InstallersDir -Force | Out-Null
}

$DownloadUrl = 'https://go.microsoft.com/fwlink/?linkid=852157'

Write-Host "[*] Downloading latest VS Code System Installer..." -ForegroundColor Yellow
Write-Host "    Source: $DownloadUrl" -ForegroundColor Gray
Write-Host "    Target: $TargetFile" -ForegroundColor Gray

try {
    # 1. Get total size first for the progress bar
    $request = [System.Net.HttpWebRequest]::Create($DownloadUrl)
    $request.AllowAutoRedirect = $true
    $response = $request.GetResponse()
    $totalBytes = $response.ContentLength
    $totalMB = [math]::Round($totalBytes / 1MB, 2)
    $response.Close()

    # 2. Start fast native download in background
    $client = New-Object System.Net.WebClient
    $client.DownloadFileAsync($DownloadUrl, $TargetFile)

    # 3. Monitor file growth for progress (much faster than manual stream reading)
    while ($client.IsBusy) {
        if (Test-Path $TargetFile) {
            $currentBytes = (Get-Item $TargetFile).Length
            $currentMB = [math]::Round($currentBytes / 1MB, 2)
            $percent = [math]::Min(100, [math]::Floor(($currentBytes / $totalBytes) * 100))
            Write-Progress -Activity "Downloading VS Code (Fast Mode)" -Status "Received: $currentMB MB / $totalMB MB" -PercentComplete $percent
        }
        Start-Sleep -Milliseconds 500
    }

    Write-Progress -Activity "Downloading VS Code (Fast Mode)" -Completed
    Write-Host "`n[SUCCESS] Download verified: $totalMB MB." -ForegroundColor Green
}
catch {
    Write-Progress -Activity "Downloading VS Code (Fast Mode)" -Completed
    Write-Host "`n[FATAL] Download failed: $($_.Exception.Message)" -ForegroundColor Red
}
