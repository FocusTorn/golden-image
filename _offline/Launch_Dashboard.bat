@echo off
:: Launcher for VM_Dashboard.ps1 via Windows Terminal (pwsh) or pwsh directly
set "SCRIPT=%~dp0\src\VM_Dashboard.ps1"
set "PWSH=C:\Program Files\PowerShell\7\pwsh.exe"
where wt >nul 2>&1
if %errorLevel% equ 0 (
    if exist "%PWSH%" (
        start "" wt new-tab "%PWSH%" -NoExit -File "%SCRIPT%"
    ) else (
        start "" wt new-tab pwsh -NoExit -File "%SCRIPT%"
    )
) else (
    if exist "%PWSH%" (
        start "" "%PWSH%" -NoExit -File "%SCRIPT%"
    ) else (
        start "" powershell -NoExit -File "%SCRIPT%"
    )
)
exit
