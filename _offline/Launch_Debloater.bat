@echo off
:: Launcher - runnable from standard context. Main.ps1 auto-elevates if needed.
:: Double-click or run from any script - will prompt for admin if needed

set "SCRIPT=%~dp0Win11_Debloater\Main.ps1"
set "PWSH=C:\Program Files\PowerShell\7\pwsh.exe"
if not exist "%PWSH%" set "PWSH=pwsh"

"%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"



