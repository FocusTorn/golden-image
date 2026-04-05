@echo off
setlocal
set "AppDir=%~dp0\GoldenImager-Orchestrator"
set "AppScript=%AppDir%\GoldenImager-Orchestrator.ps1"

:: -----------------------------------------------------------------------------
:: --- ELEVATION GUARD: RESTART AS ADMIN IF NEEDED                           ---
:: -----------------------------------------------------------------------------
fltmc >nul 2>&1
if "%errorlevel%" neq "0" (
    echo [*] PREFLIGHT: Requesting Administrator Elevation...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: -----------------------------------------------------------------------------
:: --- MAIN APPLICATION LOOP                                                 ---
:: -----------------------------------------------------------------------------
:loop
cls
echo ==============================================================================
echo   GOLDEN IMAGER - ORCHESTRATOR LAUNCHER
echo ==============================================================================
echo [*] Initializing High-Fidelity Build Control Plane...
echo [*] Working Directory: %AppDir%

if not exist "%AppScript%" (
    echo [ERROR] Application script missing: %AppScript%
    pause
    exit /b
)

:: Execute with bypass and no profile
call powershell -NoProfile -ExecutionPolicy Bypass -File "%AppScript%"

echo.
echo ==============================================================================
echo [!] APPLICATION EXITED.
echo ==============================================================================
echo Press any key to RELOAD the interface, or Close this window.
pause >nul
goto loop
