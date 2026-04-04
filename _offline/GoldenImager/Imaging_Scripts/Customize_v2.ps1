<#
.SYNOPSIS
    Stage 1: Customization v2 - Modern Terminal & Shell Defaults.
    Finalizes the environment by setting Windows Terminal and PowerShell 7 as defaults.
#>

#Requires -RunAsAdministrator

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "          GOLDEN MASTER: MODERN DEFAULTS (v2)                   " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# 1. Set Windows Terminal as the Default Terminal Emulator (Win 11)
Write-Host "[>] Setting Windows Terminal as the Default Terminal Emulator..." -ForegroundColor Gray
$consoleKey = "HKCU:\Console"
if (-not (Test-Path $consoleKey)) { New-Item $consoleKey -Force | Out-Null }
# This GUID represents the Windows Terminal Delegation
Set-ItemProperty -Path $consoleKey -Name "DelegationConsole" -Value "{B23D10C0-F124-4B44-8848-AAA20E4A1052}" -Force
Set-ItemProperty -Path $consoleKey -Name "DelegationTerminal" -Value "{B23D10C0-F124-4B44-8848-AAA20E4A1052}" -Force

# 2. Set PowerShell 7 as the Default Profile in Windows Terminal
Write-Host "[>] Setting PowerShell 7 as the Default Profile in Terminal..." -ForegroundColor Gray
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (Test-Path $wtSettingsPath) {
    try {
        $settings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
        # Standard PWSH 7 GUID used by Windows Terminal
        $pwsh7Guid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"
        $settings.defaultProfile = $pwsh7Guid
        $settings | ConvertTo-Json -Depth 100 | Set-Content $wtSettingsPath -Force
        Write-Host "  [OK] Default profile updated to PWSH 7." -ForegroundColor Green
    } catch {
        Write-Host "  [!] Could not update Terminal settings.json automatically." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [--] Windows Terminal settings not found (may not have been launched yet)." -ForegroundColor DarkGray
}

# 3. Finalizing Environment
Write-Host "`n[SUCCESS] Modern Defaults applied." -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
