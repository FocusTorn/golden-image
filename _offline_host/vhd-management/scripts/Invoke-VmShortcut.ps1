<#
.SYNOPSIS
    Creates the Golden Imager shortcut on the Guest VM desktop via PowerShell Direct.
#>
param([int]$IconIndex = 183)

. (Join-Path $PSScriptRoot "VhdUtils.ps1")
$Cfg = Get-Config
$creds = Get-VMCreds -User $Cfg.VMUser -Config $Cfg
$guestDrive = Get-GuestDriveLetter $Cfg.GuestStagingDrive

try {
    Write-Host ">>> CREATE GOLDEN IMAGER SHORTCUT ON VM DESKTOP" -ForegroundColor Cyan
    Write-Host "[*] Ensuring VHD is attached to VM..." -ForegroundColor Gray
    Invoke-VhdTransition -Target "VM" -VhdPath $Cfg.VhdPath -VMName $Cfg.VMName | Out-Null

    Write-Host "[*] Creating shortcut via Invoke-Command (inside VM)..." -ForegroundColor Gray
    $result = Invoke-Command -VMName $Cfg.VMName -Credential $creds -ScriptBlock {
        param($targetPath, $workingDir, $iconIndex)
        $desktopDir = [Environment]::GetFolderPath('Desktop')
        if (-not (Test-Path $desktopDir)) { $desktopDir = "C:\Users\Administrator\Desktop"; New-Item $desktopDir -ItemType Directory -Force | Out-Null }
        $shortcutPath = Join-Path $desktopDir "Golden Imager.lnk"
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $targetPath
        $shortcut.WorkingDirectory = $workingDir
        $shortcut.IconLocation = "$env:SystemRoot\System32\imageres.dll,$iconIndex"
        $shortcut.Description = "Launch Golden Imager"
        $shortcut.Save()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
        return Test-Path $shortcutPath
    } -ArgumentList "${guestDrive}:\_offline\GoldenImager.bat", "${guestDrive}:\_offline", $IconIndex

    if ($result) { Write-Host "  [OK] Shortcut created successfully." -ForegroundColor Green }
    else { Write-Host "  [--] Shortcut creation failed or verified false." -ForegroundColor Yellow }
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter to continue..."
