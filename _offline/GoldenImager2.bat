@echo off
setlocal
cd /d "%~dp0"

:: --- Argument Normalization ---
set "choice=%~1"

:: Map words to existing menu numbers
if /i "%choice%"=="server" set "choice=1"
if /i "%choice%"=="gui"    set "choice=2"
if /i "%choice%"=="build"  set "choice=3"
if /i "%choice%"=="audit"  set "choice=4"

:: If a valid argument was passed, skip the visual menu and go straight to processing
if not "%choice%"=="" goto :process_choice

echo ==================================================
echo   GoldenImager2: Modernized Native Engine + GUI
echo ==================================================
echo.

:: Enter the project directory
if exist "GoldenImager2" cd GoldenImager2

:: Check for Node.js
where npm >nul 2>nul || (echo [ERROR] npm not found! && pause && exit /b)

:: Check for Rust
where cargo >nul 2>nul || (echo [ERROR] cargo not found! && pause && exit /b)

:: Ensure dependencies are installed
if not exist "node_modules" (
    echo [INFO] First run: Installing dependencies...
    call npm install
)

echo [1] Start UI Dev Server (Fast / Browser Mode)
echo [2] Launch App GUI (Tauri / Native Engine)
echo [3] Build Prod Binary (.exe)
echo [4] Run Audit CLI (No GUI)
echo.

set /p choice="Select an option [1-4] or press Enter to exit: "

:process_choice
if "%choice%"=="1" goto :ui_dev
if "%choice%"=="2" goto :dev
if "%choice%"=="3" goto :build
if "%choice%"=="4" goto :audit
exit /b

:ui_dev
echo Launching UI Dev Server in Browser...
echo Keep this window open for instant refreshes!
call npm run dev <nul
goto :eof

:dev
echo Launching GoldenImager2 App...
echo Connecting to UI Server...
:: We override beforeDevCommand to empty because we assume Terminal 1 is running it.
call npx -y @tauri-apps/cli@^1 dev --config "{\"build\": {\"beforeDevCommand\": \"\"}}"  <nul
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


@REM @echo off
@REM setlocal
@REM cd /d "%~dp0"

@REM echo ==================================================
@REM echo   GoldenImager2: Modernized Native Engine + GUI
@REM echo ==================================================
@REM echo.

@REM rem Enter the project directory
@REM if exist "GoldenImager2" cd GoldenImager2

@REM rem Check for Node.js
@REM where npm >nul 2>nul || echo [ERROR] npm not found! && pause && exit /b

@REM rem Check for Rust
@REM where cargo >nul 2>nul || echo [ERROR] cargo not found! && pause && exit /b

@REM rem Ensure dependencies are installed
@REM if not exist "node_modules" echo [INFO] First run: Installing dependencies...
@REM if not exist "node_modules" call npm install

@REM echo [1] Start UI Dev Server (Fast / Browser Mode)
@REM echo [2] Launch App GUI (Tauri / Native Engine)
@REM echo [3] Build Prod Binary (.exe)
@REM echo [4] Run Audit CLI (No GUI)
@REM echo.

@REM set "choice="
@REM set /p choice="Select an option [1-4] or press Enter to exit: "

@REM if "%choice%"=="1" goto :ui_dev
@REM if "%choice%"=="2" goto :dev
@REM if "%choice%"=="3" goto :build
@REM if "%choice%"=="4" goto :audit
@REM exit /b

@REM :ui_dev
@REM echo Launching UI Dev Server in Browser...
@REM echo Keep this window open for instant refreshes!
@REM call npm run dev
@REM goto :eof

@REM :dev
@REM echo Launching GoldenImager2 App...
@REM echo Connecting to UI Server...
@REM rem We override beforeDevCommand to empty because we assume Terminal 1 is running it.
@REM rem If Terminal 1 is NOT running, this will show a 'Connection Refused' error in the App window.
@REM call npx tauri dev --config "{\"build\": {\"beforeDevCommand\": \"\"}}"
@REM goto :eof

@REM :build
@REM echo Building GoldenImager2 Production Binary...
@REM call npm run tauri build
@REM echo.
@REM echo Done! Your binary is in: src-tauri\target\release\GoldenImager2.exe
@REM pause
@REM goto :eof

@REM :audit
@REM echo Running System Audit...
@REM cd src-tauri
@REM cargo run --quiet -- audit
@REM pause
@REM goto :eof
