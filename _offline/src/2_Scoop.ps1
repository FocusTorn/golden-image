# Stage 1: Scoop Offline Setup
# Location: _offline\Install_Stage_1_Scoop.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$InstallersDir = Join-Path (Split-Path $ScriptDir -Parent) "installers"
$BundleRoot = Join-Path $InstallersDir "Scoop_Offline_Bundle"
$TargetScoopRoot = "C:\Scoop"

# --- SECTION 0: LOGGING & DRIVE DETECTION ---
$VhdDrive = (Get-PSDrive | Where-Object { Test-Path "$($_.Root)installers\VS_Offline" } | Select-Object -First 1).Root
if (-not $VhdDrive) {
    $StagingVolume = Get-Volume | Where-Object { $_.FileSystemLabel -eq "Staging" -and $_.DriveLetter -ne $null } | Select-Object -First 1
    if ($StagingVolume) { $VhdDrive = "$($StagingVolume.DriveLetter):\" }
}

if ($VhdDrive) {
    $ReturnPath = Join-Path $VhdDrive "return"
    if (!(Test-Path $ReturnPath)) { New-Item -Path $ReturnPath -ItemType Directory -Force | Out-Null }
    $LogFile = Join-Path $ReturnPath "Install_Stage_1_Scoop_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    Start-Transcript -Path $LogFile -Force
}

Write-Host "--- STAGE 1: DEPLOY SCOOP BUNDLE (OFFLINE) ---" -ForegroundColor Cyan

function Ensure-Directory {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Ensure-PathContains {
    param([string]$PathEntry)
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($machinePath -notlike "*$PathEntry*") {
        Write-Host "[*] Adding $PathEntry to System PATH..." -ForegroundColor Gray
        [Environment]::SetEnvironmentVariable("Path", "$machinePath;$PathEntry", "Machine")
    }
}

try {
    $bundleScoopRoot = Join-Path $BundleRoot "scoop-root"
    if (!(Test-Path -LiteralPath $bundleScoopRoot)) {
        throw "Scoop bundle not found at: $bundleScoopRoot."
    }

    Write-Host "[*] Deploying prebuilt bundle to $TargetScoopRoot..." -ForegroundColor Yellow
    Ensure-Directory -Path $TargetScoopRoot
    robocopy $bundleScoopRoot $TargetScoopRoot /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null

    $targetShims = Join-Path $TargetScoopRoot "shims"
    $targetApps = Join-Path $TargetScoopRoot "apps"
    Ensure-Directory -Path $targetShims

    # --- FIX: ROBUST VERSION RESOLUTION & SHIMMING ---
    Write-Host "[*] Resolving app versions and shimming binaries..." -ForegroundColor Yellow

    $ShimMap = @(
        @{ Name = "7zip"; Exe = "7z.exe" }
        @{ Name = "bat"; Exe = "bat.exe" }
        @{ Name = "ripgrep"; Exe = "rg.exe" }
        @{ Name = "scoop-search"; Exe = "scoop-search.exe" }
    )

    foreach ($item in $ShimMap) {
        $appBase = Join-Path $targetApps $item.Name
        if (Test-Path $appBase) {
            # 1. Find the latest version folder (ignoring 'current' junction)
            $latestVerDir = Get-ChildItem -Path $appBase -Directory | 
                            Where-Object { $_.Name -ne "current" } | 
                            Sort-Object Name -Descending | 
                            Select-Object -First 1
            
            if ($latestVerDir) {
                Write-Host "    -> Resolved $($item.Name) version: $($latestVerDir.Name)" -ForegroundColor Gray
                
                # 2. Re-create the 'current' junction
                $currentJunction = Join-Path $appBase "current"
                if (Test-Path $currentJunction) { 
                    # If it's a junction, we must use cmd /c rd or similar to be safe, but Remove-Item -Force usually works
                    Remove-Item $currentJunction -Force -Recurse -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Junction -Path $currentJunction -Target $latestVerDir.FullName | Out-Null

                # 3. Locate Binary (Aggressive Search)
                $binaryFound = $null
                # Check root of version folder
                $fullSrc = Join-Path $latestVerDir.FullName $item.Exe
                if (Test-Path $fullSrc) { $binaryFound = $fullSrc }
                
                # Check bin subfolder
                if (!$binaryFound) {
                    $fullSrcBin = Join-Path $latestVerDir.FullName "bin\$($item.Exe)"
                    if (Test-Path $fullSrcBin) { $binaryFound = $fullSrcBin }
                }

                # Recursive check if still not found
                if (!$binaryFound) {
                    $match = Get-ChildItem -Path $latestVerDir.FullName -Filter $item.Exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($match) { $binaryFound = $match.FullName }
                }

                # 4. Copy to Shims
                if ($binaryFound) {
                    $fullDest = Join-Path $targetShims $item.Exe
                    Copy-Item $binaryFound $fullDest -Force
                    Write-Host "    [OK] Shimmed: $($item.Exe)" -ForegroundColor Green
                } else {
                    Write-Host "    [WARN] Binary not found for $($item.Name): $($item.Exe) inside $($latestVerDir.FullName)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "    [WARN] App folder missing: $appBase" -ForegroundColor Red
        }
    }

    # Configure environment variables
    Write-Host "[*] Configuring system environment variables..." -ForegroundColor Gray
    [Environment]::SetEnvironmentVariable("SCOOP", $TargetScoopRoot, "Machine")
    [Environment]::SetEnvironmentVariable("SCOOP_GLOBAL", $TargetScoopRoot, "Machine")
    Ensure-PathContains -PathEntry $targetShims

    # Update session
    $env:SCOOP = $TargetScoopRoot
    $env:SCOOP_GLOBAL = $TargetScoopRoot
    $env:PATH = "$targetShims;" + $env:PATH

    # Verification
    Write-Host "[*] Verifying health..." -ForegroundColor Gray
    $failures = @()
    foreach ($item in $ShimMap) {
        if (Get-Command $item.Exe -ErrorAction SilentlyContinue) {
            Write-Host "[PASS] $($item.Name) is functional." -ForegroundColor Green
        } else {
            Write-Host "[ERROR] $($item.Name) ($($item.Exe)) not found in PATH." -ForegroundColor Red
            $failures += $item.Name
        }
    }

    if ($failures.Count -gt 0) {
        Write-Host "[!] Deployment finished with missing components: $($failures -join ', ')" -ForegroundColor Yellow
    } else {
        Write-Host "`n--- STAGE 1 COMPLETE (OFFLINE) ---" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n[FATAL] Error during Stage 1: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($LogFile) { Stop-Transcript }
}
