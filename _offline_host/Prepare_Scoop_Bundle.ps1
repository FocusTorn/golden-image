# Part 1: Online phase - Prepare Scoop bundle (SOLIDIFIED EDITION)
# Run this on a machine with internet access and Scoop installed.
# This script creates a portable, robocopy-safe Scoop structure.

Param(
    [string]$BundleRoot = "P:\Projects\golden-image\installers\Scoop_Offline_Bundle"
)

$ErrorActionPreference = "Stop"
Write-Host "--- STAGE 1: PREPARE SCOOP BUNDLE (ONLINE) ---" -ForegroundColor Cyan

function Ensure-Directory {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

$bundleScoopRoot = Join-Path $BundleRoot "scoop-root"
$bundleGlobalRoot = Join-Path $BundleRoot "scoop-global"
$bundleCache = Join-Path $bundleScoopRoot "cache"
$bundleShims = Join-Path $bundleScoopRoot "shims"
$bundleApps = Join-Path $bundleScoopRoot "apps"

Write-Host "[*] Initializing bundle directories at $BundleRoot..." -ForegroundColor Yellow
Ensure-Directory $bundleScoopRoot
Ensure-Directory $bundleGlobalRoot
Ensure-Directory $bundleCache
Ensure-Directory $bundleShims
Ensure-Directory $bundleApps
Ensure-Directory (Join-Path $bundleScoopRoot "buckets")

# --- SECTION 1: ENVIRONMENT ISOLATION ---
$env:SCOOP = $bundleScoopRoot
$env:SCOOP_GLOBAL = $bundleGlobalRoot
$env:SCOOP_CACHE = $bundleCache
$env:PATH = "$bundleShims;" + $env:PATH

# --- SECTION 2: BOOTSTRAP CORE ---
$bundleScoopApp = Join-Path $bundleApps "scoop\current"
if (!(Test-Path (Join-Path $bundleScoopApp "bin\scoop.ps1"))) {
    Write-Host "[*] Bootstrapping Scoop Core..." -ForegroundColor Gray
    $hostScoopPath = (Get-Command scoop -ErrorAction SilentlyContinue).Source
    if ($hostScoopPath) {
        $hostScoopCore = Join-Path (Split-Path $hostScoopPath -Parent) "..\apps\scoop\current"
        Ensure-Directory $bundleScoopApp
        robocopy $hostScoopCore $bundleScoopApp /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    }
}

# Create the master shim inside the bundle
$shimContent = @"
`# Scoop offline shim
`$script_path = Split-Path `$MyInvocation.MyCommand.Path -Parent
`$scoop_core = Join-Path `$script_path "..\apps\scoop\current\bin\scoop.ps1"
if (Test-Path `$scoop_core) { & `$scoop_core @args }
"@
$shimContent | Set-Content -Path (Join-Path $bundleShims "scoop.ps1") -Encoding UTF8

$bundleScoopCmd = Join-Path $bundleShims "scoop.ps1"

# --- SECTION 3: POPULATE APPS ---
$buckets = @("main", "sysinternals", "nirsoft")
foreach ($bucket in $buckets) {
    Write-Host "[*] Adding bucket: $bucket" -ForegroundColor Gray
    powershell -Command "& '$bundleScoopCmd' bucket add $bucket" 2>&1 | Out-Null
}

$apps = @("7zip", "bat", "ripgrep", "scoop-search")
foreach ($app in $apps) {
    Write-Host "[*] Installing app: $app" -ForegroundColor Yellow
    & $bundleScoopCmd install $app 2>&1 | Out-String | Write-Host
}

# --- SECTION 4: SOLIDIFICATION (ROBOCOPY PROOFING) ---
Write-Host "`n[*] Solidifying junctions for offline portability..." -ForegroundColor Cyan

$installedApps = Get-ChildItem $bundleApps -Directory
foreach ($appDir in $installedApps) {
    $currentPath = Join-Path $appDir.FullName "current"
    if (Test-Path $currentPath) {
        $item = Get-Item $currentPath
        if ($item.Attributes -match "ReparsePoint") {
            $target = $item.Target
            Write-Host "    -> Solidifying $($appDir.Name)..." -ForegroundColor Gray
            
            # Use CMD to remove the junction cleanly (PowerShell Remove-Item fails on Scoop junctions)
            cmd /c "rd /s /q `"$currentPath`""
            
            # Replace with a physical copy
            Ensure-Directory $currentPath
            robocopy $target $currentPath /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        }
    }
}

# --- SECTION 5: SHIM HARVESTING ---
# Ensure shims folder has the actual binaries for offline PATH health
Write-Host "[*] Harvesting binaries to shims folder..." -ForegroundColor Gray
$ShimTargets = @(
    @{ Exe = "7z.exe"; Src = "7zip\current\7z.exe" }
    @{ Exe = "bat.exe"; Src = "bat\current\bat.exe" }
    @{ Exe = "rg.exe"; Src = "ripgrep\current\rg.exe" }
    @{ Exe = "scoop-search.exe"; Src = "scoop-search\current\scoop-search.exe" }
)

foreach ($item in $ShimTargets) {
    $fullSrc = Join-Path $bundleApps $item.Src
    if (Test-Path $fullSrc) {
        Copy-Item $fullSrc (Join-Path $bundleShims $item.Exe) -Force
        Write-Host "    + Shimmed: $($item.Exe)" -DarkGray
    }
}

Write-Host "`n[SUCCESS] Solidified Scoop bundle ready at $BundleRoot" -ForegroundColor Green
