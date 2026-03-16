<#
.SYNOPSIS
    Creates a shortcut with the Golden Imager icon that launches the .bat file.
.DESCRIPTION
    Run this once to create "Golden Imager.lnk" in the same folder as the .bat.
    The shortcut uses the same icon as the running app (imageres.dll index 251).
#>
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$batPath = Join-Path $scriptDir "GoldenImager.bat"
$shortcutPath = Join-Path $scriptDir "Golden Imager.lnk"
$iconPath = Join-Path $env:SystemRoot "System32\imageres.dll"
$iconIndex = 251

if (-not (Test-Path $batPath)) {
    Write-Error "Bat file not found: $batPath"
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $batPath
$shortcut.WorkingDirectory = $scriptDir
$shortcut.IconLocation = "$iconPath,$iconIndex"
$shortcut.Description = "Launch Golden Imager"
$shortcut.Save()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null

Write-Host "Shortcut created: $shortcutPath" -ForegroundColor Green
Write-Host "Use this shortcut instead of the .bat for the app icon." -ForegroundColor Gray
