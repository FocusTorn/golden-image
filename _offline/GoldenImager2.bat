@echo off
setlocal
cd /d "%~dp0"

echo ==================================================
echo   GoldenImager2: Modernized Native Engine + GUI
echo ==================================================
echo.

rem Enter the project directory
if exist "GoldenImager2" cd GoldenImager2

rem Check for Node.js
where npm >nul 2>nul || echo [ERROR] npm not found! && pause && exit /b

rem Check for Rust
where cargo >nul 2>nul || echo [ERROR] cargo not found! && pause && exit /b

rem Ensure dependencies are installed
if not exist "node_modules" echo [INFO] First run: Installing dependencies...
if not exist "node_modules" call npm install

echo [1] Start UI Dev Server (Fast / Browser Mode)
echo [2] Launch App GUI (Tauri / Native Engine)
echo [3] Build Prod Binary (.exe)
echo [4] Run Audit CLI (No GUI)
echo.

set "choice="
set /p choice="Select an option [1-4] or press Enter to exit: "

if "%choice%"=="1" goto :ui_dev
if "%choice%"=="2" goto :dev
if "%choice%"=="3" goto :build
if "%choice%"=="4" goto :audit
exit /b

:ui_dev
echo Launching UI Dev Server in Browser...
echo Keep this window open for instant refreshes!
call npm run dev
goto :eof

:dev
echo Launching GoldenImager2 App...
echo Connecting to UI Server...
rem We override beforeDevCommand to empty because we assume Terminal 1 is running it.
rem If Terminal 1 is NOT running, this will show a 'Connection Refused' error in the App window.
call npx tauri dev --config "{\"build\": {\"beforeDevCommand\": \"\"}}"
goto :eof

:build
echo Building GoldenImager2 Production Binary...
call npm run tauri build
echo.
echo Done! Your binary is in: src-tauri\target\release\GoldenImager2.exe
pause
goto :eof

:audit
echo Running System Audit...
cd src-tauri
cargo run --quiet -- audit
pause
goto :eof
