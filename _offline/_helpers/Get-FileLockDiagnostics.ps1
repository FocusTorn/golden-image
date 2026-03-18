<#
.SYNOPSIS
    Check which process(es) have a file open (run on the GUEST when access denied).
.DESCRIPTION
    Use Sysinternals Handle.exe to find what is locking a file.
    Download: https://learn.microsoft.com/en-us/sysinternals/downloads/handle
.EXAMPLE
    .\Get-FileLockDiagnostics.ps1
    .\Get-FileLockDiagnostics.ps1 -Path "E:\_offline\GoldenImager\Scripts\FileIO\LoadAppsDetailsFromJson.ps1"
#>
param(
    [string]$Path = "E:\_offline\GoldenImager\Scripts\FileIO\LoadAppsDetailsFromJson.ps1"
)

$leaf = Split-Path $Path -Leaf
Write-Host "`n=== FILE LOCK DIAGNOSTICS ===" -ForegroundColor Cyan
Write-Host "File: $Path" -ForegroundColor DarkGray
Write-Host ""

# Use Handle from installers (resolves from _offline/_helpers -> project root -> installers/Handle)
$handleDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "installers\Handle"
$handleExe = if (Test-Path (Join-Path $handleDir "handle64.exe")) { Join-Path $handleDir "handle64.exe" }
             elseif (Test-Path (Join-Path $handleDir "handle.exe")) { Join-Path $handleDir "handle.exe" }
             else { $null }

if ($handleExe) {
    Write-Host "Processes with handles on '$leaf':" -ForegroundColor Yellow
    $out = & $handleExe -accepteula $Path 2>&1
    if ($out) {
        $out | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "  (no handles found - file may not be locked)" -ForegroundColor DarkGray
    }
} else {
    Write-Host "Handle not found at: $handleDir" -ForegroundColor Yellow
    Write-Host "  Expected: installers\Handle\handle64.exe or handle.exe" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Common lock sources when Golden Imager fails:" -ForegroundColor Yellow
    Write-Host "  - Hyper-V Guest File Service (Msvm_GuestFileService) = SmartSync pushing files" -ForegroundColor Gray
    Write-Host "  - powershell.exe = another Golden Imager or script instance" -ForegroundColor Gray
    Write-Host "  - explorer.exe = File Explorer with drive open" -ForegroundColor Gray
}

Write-Host ""
