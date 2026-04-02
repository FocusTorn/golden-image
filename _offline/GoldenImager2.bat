@echo off
setlocal
cd /d "%~dp0"

:: Step 0: Enter the project directory
if exist "GoldenImager2" (
    cd GoldenImager2
)

:: --- Argument Normalization ---
set "choice=%~1"

:: --- Pre-emptive Environment Cleanup ---
echo [*] Reconciling SCSI handles and dismounting ghost volumes...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { . 'P:\Projects\golden-image\_helpers\ConfigUtils.ps1'; . 'P:\Projects\golden-image\_offline_host\vhd-management\scripts\VhdUtils.ps1'; $cfg = Get-Config -Target Host; Invoke-SmartRelease $cfg.VhdPath $cfg.VMName }"
echo.

:: Map words and help flags
if /i "%choice%"=="server"  set "choice=1"
if /i "%choice%"=="gui"     set "choice=2"
if /i "%choice%"=="build"   set "choice=3"
if /i "%choice%"=="audit"   set "choice=4"
if /i "%choice%"=="web"     set "choice=5"
if /i "%choice%"=="clean"   set "choice=6"
if /i "%choice%"=="help"    goto :show_help
if /i "%choice%"=="/?"      goto :show_help

:: If a valid argument was passed, skip the visual menu
if not "%choice%"=="" goto :process_choice

:menu
echo ==================================================
echo   GoldenImager2: Modernized Native Engine + GUI
echo ==================================================
echo [1] Start UI Dev Server (Fast / Browser Mode)
echo [2] Launch App GUI (Tauri / Native Engine)
echo [3] Build Prod Binary (.exe)
echo [4] Run Audit CLI (No GUI)
echo [5] Open Browser to Localhost (Preview Appearance)
echo [6] Clean / Release All VHD Handles (Manual Safegaurd)
echo [H] Help / Usage
echo.

set /p choice="Select an option [1-6, H] or press Enter to exit: "

:process_choice
if "%choice%"=="1" goto :ui_dev
if "%choice%"=="2" goto :dev
if "%choice%"=="3" goto :build
if "%choice%"=="4" goto :audit
if "%choice%"=="5" goto :open_url
if "%choice%"=="6" goto :clean
if /i "%choice%"=="h" goto :show_help
exit /b

:ui_dev
echo Launching UI Dev Server...
call npm run dev <nul
goto :eof

:dev
echo Launching Tauri Dev backend...
npm run tauri dev

echo.
echo [*] GUI closed. Initiating automatic resource release...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { . 'P:\Projects\golden-image\_helpers\ConfigUtils.ps1'; . 'P:\Projects\golden-image\_offline_host\vhd-management\scripts\VhdUtils.ps1'; $cfg = Get-Config -Target Host; Invoke-SmartRelease $cfg.VhdPath $cfg.VMName }"
goto :eof

:build
echo Building Production Binary...
call npm run tauri build
pause
goto :eof

:audit
echo Running System Audit...
cd src-tauri && cargo run --quiet -- audit
pause
goto :eof

:open_url
echo Opening UI preview in your default browser...
:: Standard Vite port is 5173; change if your tauri.conf.json uses a different port
start http://localhost:1420
goto :eof

:clean
echo.
echo [*] Initiating Manual Resource Release / Environment Cleanup...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { . 'P:\Projects\golden-image\_helpers\ConfigUtils.ps1'; . 'P:\Projects\golden-image\_offline_host\vhd-management\scripts\VhdUtils.ps1'; $cfg = Get-Config -Target Host; Invoke-SmartRelease $cfg.VhdPath $cfg.VMName }"
echo.
echo [DONE] SCSI handles cleared and staging volumes dismounted.
pause
goto :eof

:show_help
echo.
echo GoldenImager2 CLI Usage:
echo --------------------------------------------------
echo   server  (1)  Starts the Node/Vite dev server.
echo   gui     (2)  Runs the Tauri app in development mode.
echo   build   (3)  Compiles the project into a native .exe.
echo   audit   (4)  Runs the Rust backend audit command.
echo   web     (5)  Opens the frontend URL in your browser.
echo   clean   (6)  Manually releases all VHD handles/mounts.
echo   help         Displays this help message.
echo.
pause
goto :eof




@REM @echo off
@REM setlocal
@REM cd /d "%~dp0"

@REM :: Step 0: Enter the project directory BEFORE any logic occurs
@REM if exist "GoldenImager2" (
@REM     cd GoldenImager2
@REM )

@REM :: --- Argument Normalization ---
@REM set "choice=%~1"

@REM :: Map words to existing menu numbers
@REM if /i "%choice%"=="server" set "choice=1"
@REM if /i "%choice%"=="gui"    set "choice=2"
@REM if /i "%choice%"=="build"  set "choice=3"
@REM if /i "%choice%"=="audit"  set "choice=4"

@REM :: If a valid argument was passed, skip the visual menu and go straight to processing
@REM if not "%choice%"=="" goto :process_choice

@REM echo ==================================================
@REM echo   GoldenImager2: Modernized Native Engine + GUI
@REM echo ==================================================
@REM echo.

@REM :: Check for Node.js
@REM where npm >nul 2>nul || (echo [ERROR] npm not found! && pause && exit /b)

@REM :: Check for Rust
@REM where cargo >nul 2>nul || (echo [ERROR] cargo not found! && pause && exit /b)

@REM :: Ensure dependencies are installed
@REM if not exist "node_modules" (
@REM     echo [INFO] First run: Installing dependencies...
@REM     call npm install
@REM )

@REM echo [1] Start UI Dev Server (Fast / Browser Mode)
@REM echo [2] Launch App GUI (Tauri / Native Engine)
@REM echo [3] Build Prod Binary (.exe)
@REM echo [4] Run Audit CLI (No GUI)
@REM echo.

@REM set /p choice="Select an option [1-4] or press Enter to exit: "

@REM :process_choice
@REM if "%choice%"=="1" goto :ui_dev
@REM if "%choice%"=="2" goto :dev
@REM if "%choice%"=="3" goto :build
@REM if "%choice%"=="4" goto :audit
@REM exit /b

@REM :ui_dev
@REM echo Launching UI Dev Server in Browser...
@REM echo Keep this window open for instant refreshes!
@REM call npm run dev <nul
@REM goto :eof

@REM :dev
@REM echo Launching GoldenImager2 App...
@REM echo Connecting to UI Server...
@REM :: We override beforeDevCommand to empty because we assume Terminal 1 is running it.
@REM call npx -y @tauri-apps/cli@^1 dev --config "{\"build\": {\"beforeDevCommand\": \"\"}}"  <nul
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

