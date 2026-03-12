@echo off
:: Thin launcher for 1_Customize.ps1 - Golden Master: Customization & Foundation
:: Run as Administrator

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [FAIL] Must be run as Administrator.
    pause
    exit /b 1
)

set "SCRIPT=%~dp0\src\1_Customize.ps1"
set "PWSH=C:\Program Files\PowerShell\7\pwsh.exe"

if exist "%PWSH%" (
    "%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
)

