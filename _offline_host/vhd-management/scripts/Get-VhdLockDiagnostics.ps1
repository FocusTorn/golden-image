<#
.SYNOPSIS
    Diagnose what is holding a VHD/VHDX file open (host or VM).

.DESCRIPTION
    Run on the HOST to find processes with handles on the VHD.
    Optionally run inside the VM to find processes that may be using the staging drive (F:).

.PARAMETER VhdPath
    Full path to the VHD file (default: from config.json).

.PARAMETER VMName
    VM name for remote checks (default: from config.json).

.PARAMETER CheckGuest
    If set, run a guest-side check via Invoke-Command (requires WinRM).

.EXAMPLE
    .\Get-VhdLockDiagnostics.ps1
    .\Get-VhdLockDiagnostics.ps1 -VhdPath "N:\VHD\MasterInstallers.vhdx"
#>
param(
    [string]$VhdPath,
    [string]$VMName,
    [switch]$CheckGuest
)

$LocalProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
. (Join-Path $LocalProjectRoot "_helpers\ConfigUtils.ps1")

$cfg = Get-Config -Target Host
if (-not $VhdPath) { $VhdPath = $cfg.VhdPath }
if (-not $VMName) { $VMName = $cfg.VMName }
if (-not $VhdPath) { $VhdPath = "N:\VHD\MasterInstallers.vhdx" }

$leaf = Split-Path $VhdPath -Leaf
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($VhdPath)

Write-Host "`n=== VHD LOCK DIAGNOSTICS ===" -ForegroundColor Cyan
Write-Host "VHD: $VhdPath" -ForegroundColor DarkGray
Write-Host ""

# --- HOST: Hyper-V / VDS state ---
Write-Host "[HOST] Hyper-V & VDS state" -ForegroundColor Yellow
$vmDrives = Get-VMHardDiskDrive -VMName $VMName -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*$leaf*" -or ($baseName -and $_.Path -like "*$baseName*") }
if ($vmDrives) {
    Write-Host "  -> VM '$VMName' has VHD attached: $($vmDrives.Path)" -ForegroundColor Red
    Write-Host "     (Hyper-V worker process vmwp.exe holds the file when VM is running)" -ForegroundColor DarkGray
} else {
    Write-Host "  -> VM '$VMName' does not have this VHD in config" -ForegroundColor Green
}

# Get-VHD can hang when file is locked; use short timeout
$vhdInfo = $null
$job = Start-Job { param($p) Import-Module Hyper-V -EA SilentlyContinue; Get-VHD -Path $p -EA SilentlyContinue } -ArgumentList $VhdPath
if (Wait-Job $job -Timeout 3) { $vhdInfo = Receive-Job $job }; Remove-Job $job -Force -EA SilentlyContinue
if ($vhdInfo -and $vhdInfo.Attached -and $null -ne $vhdInfo.DiskNumber) {
    Write-Host "  -> VHD is host-mounted (Disk $($vhdInfo.DiskNumber))" -ForegroundColor Red
} elseif ($vhdInfo -and $vhdInfo.Attached) {
    Write-Host "  -> VHD is attached (VM or other; no host disk number)" -ForegroundColor Yellow
} else {
    Write-Host "  -> VHD is not host-mounted" -ForegroundColor Gray
}

# --- HOST: Handle.exe (Sysinternals) ---
$handlePath = Get-Command handle.exe -ErrorAction SilentlyContinue
if ($handlePath) {
    Write-Host "`n[HOST] Processes with handles on '$leaf' (handle.exe):" -ForegroundColor Yellow
    $out = & handle.exe -accepteula $leaf 2>&1
    if ($out) { $out | ForEach-Object { Write-Host "  $_" } }
    else { Write-Host "  (no matches - try full path)" -ForegroundColor DarkGray }
} else {
    Write-Host "`n[HOST] Install Sysinternals Handle to see which process has the file:" -ForegroundColor Yellow
    Write-Host "  https://learn.microsoft.com/en-us/sysinternals/downloads/handle" -ForegroundColor DarkGray
    Write-Host "  Then: handle.exe `"$leaf`"" -ForegroundColor DarkGray
}

# --- HOST: Likely culprits ---
Write-Host "`n[HOST] Common lock sources:" -ForegroundColor Yellow
Write-Host "  - vmwp.exe (Hyper-V worker) = VM has VHD attached; use Option V then D to disconnect" -ForegroundColor Gray
Write-Host "  - VDS (Virtual Disk Service) = stale mount; use Option K to restart VDS" -ForegroundColor Gray
Write-Host "  - explorer.exe = File Explorer with drive open; close windows" -ForegroundColor Gray
Write-Host "  - robocopy / other scripts = wait for them to finish" -ForegroundColor Gray

# --- GUEST: Optional remote check ---
if ($CheckGuest -and $VMName) {
    Write-Host "`n[GUEST] Processes that may hold staging drive (F:):" -ForegroundColor Yellow
    try {
        $guestScript = {
            Get-Process | Where-Object {
                $_.Path -like "F:\*" -or
                $_.Path -like "*_offline*" -or
                ($_.Name -match "explorer|searchindexer|msiexec|conhost|powershell|pwsh|cmd|chrome|code|git|unigetui")
            } | Select-Object Name, Id, Path | Format-Table -AutoSize
        }
        Invoke-Command -VMName $VMName -ScriptBlock $guestScript -ErrorAction Stop
    } catch {
        Write-Host "  WinRM/Invoke-Command failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Run this inside the VM instead:" -ForegroundColor DarkGray
        Write-Host '  Get-Process | Where-Object { $_.Path -like "F:\*" } | Select Name, Id, Path' -ForegroundColor DarkGray
    }
}

Write-Host ""
