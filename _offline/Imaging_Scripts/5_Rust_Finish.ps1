# Stage 4: Rust & Cargo Tools (Offline Version)
# Location: _offline\Install_Stage_4_Rust_Finish.ps1
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Continue"

# --- SECTION 0: DRIVE DETECTION & LOGGING ---
$VhdDrive = (Get-PSDrive | Where-Object { Test-Path "$($_.Root)installers\VS_Offline" } | Select-Object -First 1).Root
if (-not $VhdDrive) {
    $StagingVolume = Get-Volume | Where-Object { $_.FileSystemLabel -eq "Staging" -and $_.DriveLetter -ne $null } | Select-Object -First 1
    if ($StagingVolume) { $VhdDrive = "$($StagingVolume.DriveLetter):\" }
}

if (-not $VhdDrive) {
    Write-Host "[ERROR] VHD storage not found." -ForegroundColor Red
    return
}

$ReturnPath = Join-Path $VhdDrive "return"
if (-not (Test-Path $ReturnPath)) { New-Item -Path $ReturnPath -ItemType Directory -Force | Out-Null }

$LogFile = Join-Path $ReturnPath "Install_Stage_4_Rust_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
# Start-Transcript captures stdout. Using 'cmd /c' for external calls ensures stderr is captured.
Start-Transcript -Path $LogFile -Force

Write-Host "--- STAGE 4: RUST & LINKER LOCATOR (OFFLINE) ---" -ForegroundColor Cyan
Write-Host "[*] Logging to: $LogFile" -ForegroundColor Gray

$InstallersDir = Join-Path $VhdDrive "installers"
$RustAssetsDir = Join-Path $InstallersDir "Rust_Assets"

try {
    # --- SECTION 1: LINKER LOCATOR (MSVC) ---
    Write-Host "`n[1/5] Locating MSVC Linker..." -ForegroundColor Cyan
    # Use cmd /c to capture stderr reliably in the transcript
    $vsPath = cmd /c "vswhere.exe -latest -products * -property installationPath 2>&1"
    if ($vsPath -and (Test-Path $vsPath.Trim())) {
        $vsPath = $vsPath.Trim()
        $msvcRoot = Join-Path $vsPath "VC\Tools\MSVC"
        $latestVersion = Get-ChildItem -Path $msvcRoot -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        $binPath = if ($latestVersion) { Join-Path $msvcRoot "$($latestVersion.Name)\bin\Hostx64\x64" } else { $null }
        if ($binPath -and (Test-Path $binPath)) {
            Write-Host "[PASS] MSVC toolchain found at $binPath" -ForegroundColor Green
            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($currentPath -notlike "*$binPath*") {
                Write-Host "[*] Adding MSVC linker to System PATH..." -ForegroundColor Gray
                [Environment]::SetEnvironmentVariable("Path", "$currentPath;$binPath", "Machine")
                $env:PATH += ";$binPath"
            }
        }
    } else {
        Write-Host "[WARN] MSVC not detected. Run Stage 2 first." -ForegroundColor Yellow
    }

    # --- SECTION 2: RUST ENGINE (MSI STANDALONE) ---
    Write-Host "`n[2/5] Deploying Rust Standalone Engine..." -ForegroundColor Cyan
    
    $existingMsiRust = Get-ChildItem "C:\Program Files\Rust*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existingMsiRust) {
        Write-Host "    [PASS] Rust Engine already present at $($existingMsiRust.FullName)" -ForegroundColor Green
        $RustRoot = $existingMsiRust.FullName
    } else {
        $rustMsi = Get-ChildItem -Path $InstallersDir -Filter "rust-*.msi" | Select-Object -First 1
        if ($rustMsi) {
            Write-Host "    -> Installing $($rustMsi.Name) (Visible Mode)..." -ForegroundColor Gray
            $msiArgs = "/i `"$($rustMsi.FullName)`" /passive /norestart"
            $msiProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
            if ($msiProcess.ExitCode -eq 0 -or $msiProcess.ExitCode -eq 3010) {
                Write-Host "    [OK] Engine installed." -ForegroundColor Green
                $RustRoot = (Get-ChildItem "C:\Program Files\Rust*" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
            } else {
                Write-Host "    [FAIL] Engine install failed (Code $($msiProcess.ExitCode))." -ForegroundColor Red
            }
        }
    }

    # --- SECTION 3: RUST MANAGER (RUSTUP) ---
    Write-Host "`n[3/5] Deploying Rustup Manager..." -ForegroundColor Cyan
    if (!(Get-Command rustup -ErrorAction SilentlyContinue)) {
        $rustupInit = Get-ChildItem -Path $RustAssetsDir -Filter "rustup-init.exe" | Select-Object -First 1
        if ($rustupInit) {
            Write-Host "    -> Running $($rustupInit.Name)..." -ForegroundColor Gray
            $env:RUSTUP_DIST_SERVER = "http://127.0.0.1" 
            cmd /c "`"$($rustupInit.FullName)`" -y --no-modify-path --default-toolchain none --profile minimal 2>&1"
            
            $cargoBin = Join-Path $env:USERPROFILE ".cargo\bin"
            $mPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($mPath -notlike "*$cargoBin*") {
                Write-Host "[*] Adding Cargo Bin to System PATH..." -ForegroundColor Gray
                [Environment]::SetEnvironmentVariable("Path", "$mPath;$cargoBin", "Machine")
                $env:PATH = "$cargoBin;$env:PATH"
            }
        }
    } else {
        Write-Host "    [PASS] Rustup Manager present." -ForegroundColor Green
    }

    # --- SECTION 4: OFFLINE LINKING ---
    Write-Host "`n[4/5] Linking Toolchain..." -ForegroundColor Cyan
    
    if ($RustRoot -and (Test-Path $RustRoot)) {
        Write-Host "    -> Linking $RustRoot to 'offline-stable'..." -ForegroundColor Gray
        
        # Using cmd /c avoids PowerShell's 'NativeCommandError' and ensures transcript capture
        cmd /c "rustup toolchain link offline-stable `"$RustRoot`" 2>&1"
        cmd /c "rustup default offline-stable 2>&1"
        
        # --- RIGOROUS VERIFICATION ---
        $list = cmd /c "rustup toolchain list 2>&1"
        cmd /c "rustc --version 2>&1"
        
        if ($list -like "*offline-stable*" -and $LASTEXITCODE -eq 0) {
            Write-Host "[PASS] Toolchain 'offline-stable' linked and functional." -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Toolchain verification failed. rustc is not operational." -ForegroundColor Red
        }
    } else {
        Write-Host "[WARN] Standalone Rust binaries not found. Linking skipped." -ForegroundColor Yellow
    }

    # --- SECTION 5: CARGO TOOLS ---
    Write-Host "`n[5/5] Deploying Cargo Helpers..." -ForegroundColor Cyan
    $cargoBin = Join-Path $env:USERPROFILE ".cargo\bin"
    if (!(Test-Path $cargoBin)) { New-Item -ItemType Directory -Path $cargoBin -Force | Out-Null }

    $binstallZip = Get-ChildItem -Path $RustAssetsDir -Filter "cargo-binstall*.zip" | Select-Object -First 1
    if ($binstallZip) {
        Write-Host "    [*] Extracting cargo-binstall..." -ForegroundColor Gray
        Expand-Archive -Path $binstallZip.FullName -DestinationPath $cargoBin -Force
    }

    $updateZip = Get-ChildItem -Path $RustAssetsDir -Filter "cargo-update*.zip" | Select-Object -First 1
    if ($updateZip) {
        Write-Host "    [*] Extracting cargo-update..." -ForegroundColor Gray
        $extractDir = Join-Path $env:TEMP "cargo-update-extract"
        if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
        Expand-Archive -Path $updateZip.FullName -DestinationPath $extractDir -Force
        Get-ChildItem -Path $extractDir -Recurse -Filter "*.exe" | ForEach-Object { Copy-Item $_.FullName -Destination $cargoBin -Force }
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "`n--- STAGE 4 COMPLETE (OFFLINE) ---" -ForegroundColor Green
}
catch {
    Write-Host "`n[FAIL] Stage 4 error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Stop-Transcript
}
