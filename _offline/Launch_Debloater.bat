@echo off

set "SCRIPT=%~dp0\Win11_Debloater\Main.ps1"
set "PWSH=C:\Program Files\PowerShell\7\pwsh.exe"
where wt >nul 2>&1
if %errorLevel% equ 0 (
    if exist "%PWSH%" (
        start "" wt new-tab "%PWSH%" -WindowStyle Hidden -NoProfile -File "%SCRIPT%"
    ) else (
        start "" wt new-tab pwsh -WindowStyle Hidden -NoProfile  -File "%SCRIPT%"
    )
) else (
    if exist "%PWSH%" (
        start "" "%PWSH%" -WindowStyle Hidden -NoProfile   -File "%SCRIPT%"
    ) else (
        start "" powershell -WindowStyle Hidden -NoProfile  -File "%SCRIPT%"
    )
)
exit
