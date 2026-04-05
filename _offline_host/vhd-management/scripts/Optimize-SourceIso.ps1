[CmdletBinding()]
param(
    [string]$SourcePath = "N:\OS_Images\Win11_25H2_English_x64.iso",
    [string]$VanillaName = "Win11_Pro_Slim_Vanilla.iso",
    [string]$DestinationPath = "N:\OS_Images",
    [switch]$Tiny,
    [switch]$Interactive,
    [string]$Steps = "" # Supports "1-4", "1,3,7", etc.
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue" # Ensure we see progress for long-running DISM tasks

function Invoke-PollUntil {
    param([Parameter(Mandatory)] [scriptblock]$Action, [int]$MaxWaitSeconds = 5)
    $start = Get-Date
    while (((Get-Date) - $start).TotalSeconds -lt $MaxWaitSeconds) { $res = & $Action; if ($res) { return $res }; Start-Sleep -Milliseconds 250 }
    return $null
}

# --- CONFIGURATION: THE "SHIT" LISTS (WILDCARDS SUPPORTED) ---
$AppxPatterns = @(
    "*3DViewer*"; "*BingSearch*"; "*Clipchamp*"; "*WindowsAlarms*";
    "*DevHome*"; "*MicrosoftFamily*"; "*FeedbackHub*"; "*GetHelp*"; "*Getstarted*"; "*MixedReality*";
    "*BingNews*"; "*Office.OneNote*"; "*OutlookForWindows*"; "*People*";
    "*PowerAutomate*"; "*QuickAssist*"; "*SkypeApp*"; "*Solitaire*"; "*StickyNotes*";
    "*Teams*"; "*MSTeams*"; "*Todos*"; "*SoundRecorder*"; "*BingWeather*"; "*YourPhone*";
    "*ZuneVideo*"; "*WindowsMaps*"; "*ZuneMusic*"; "*Skype*"; "*Spotify*"; "*DisneyPlus*";
    "*TikTok*"; "*LinkedIn*"; "*Wallet*"; "*PowerBI*"; "*OneNote*"; "*Yammer*"
)

$CapabilityPatterns = @(
    "Language.Handwriting*"; "Browser.InternetExplorer*"; "MathRecognizer*";
    "App.Support.QuickAssist*"; "App.StepsRecorder*"; "Media.WindowsMediaPlayer*";
    "Language.OCR*"; "Language.Speech*"; "Language.TextToSpeech*"; "OneCore.Speech.Common*"
)

$OptionalFeaturesToDisable = @("Recall"; "HelloFace")

# --- ENGINE PATHS ---
$scratchDir = "N:\_bake_temp"
$mountDir = Join-Path $scratchDir "mount"
$isoFilesDir = Join-Path $scratchDir "iso_files"
$stagedWim = Join-Path $scratchDir "install.wim"
$winrePath = Join-Path $mountDir "Windows\System32\Recovery\Winre.wim"

function Show-Header {
    Clear-Host
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "       GOLDEN IMAGER: TINY BAKE ENGINE              " -ForegroundColor White
    Write-Host "====================================================`n" -ForegroundColor Cyan
}

function Invoke-Step {
    param([int]$Step, [string]$Label, [scriptblock]$Action)
    Write-Host "`n>>> [STEP $Step] $Label..." -ForegroundColor Cyan
    try {
        & $Action
        # The Action block can return a status string
        Write-Host "[OK] Step $Step completed." -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Step $Step failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($Interactive) {
            Write-Host "`n[!] The script has paused at Step $Step." -ForegroundColor Yellow
            [void](Read-Host "Correct the issue, then press ENTER to retry or Ctrl+C to abort")
            return Invoke-Step -Step $Step -Label $Label -Action $Action
        } else {
            throw $_
        }
    }
}

try {
    Show-Header
    
    $targetSteps = @()
    if ($Steps) {
        $parts = $Steps.Split(',') | Where-Object { $_.Trim() -ne "" }
        foreach ($p in $parts) {
            $p = $p.Trim()
            if ($p -match "-") {
                $range = $p.Split('-')
                $start = [int]$range[0]
                $end = if ([string]::IsNullOrWhiteSpace($range[1])) { 9 } else { [int]$range[1] }
                $targetSteps += $start..$end
            } else {
                $targetSteps += [int]$p
            }
        }
        Write-Host "[*] EXECUTION PLAN: Steps $($targetSteps | Sort-Object -Unique | Out-String | %{ $_.Trim() } | ?{$_})" -ForegroundColor Cyan
    } elseif ($Interactive) {
        Write-Host "SELECT STARTING POINT (or range like 1-4, or list like 1,3,5):" -ForegroundColor Yellow
        Write-Host "  [1] Fresh Start (Export & Mount)"
        Write-Host "  [2] Remove Appx Packages"
        Write-Host "  [3] Remove Capabilities"
        Write-Host "  [4] Disable Features (Recall)"
        Write-Host "  [5] Stripping Recovery Environment (WinRE)"
        Write-Host "  [6] Component Cleanup (ResetBase) - LONG"
        Write-Host "  [7] Save & Dismount"
        Write-Host "  [8] WIM Garbage Collection (Compaction)"
        Write-Host "  [9] Finalize & Build ISO"
        $choice = Read-Host "`nEnter Step(s)"
        if ($choice -match "[,-]") {
             $parts = $choice.Split(',') | Where-Object { $_.Trim() -ne "" }
             foreach ($p in $parts) {
                 $p = $p.Trim()
                 if ($p -match "-") {
                     $range = $p.Split('-')
                     $start = [int]$range[0]
                     $end = if ([string]::IsNullOrWhiteSpace($range[1])) { 9 } else { [int]$range[1] }
                     $targetSteps += $start..$end
                 } else { $targetSteps += [int]$p }
             }
        } else {
            $targetSteps = [int]$choice..8
        }
        $targetSteps = $targetSteps | Sort-Object -Unique
        Write-Host "[*] EXECUTION PLAN: Steps $($targetSteps -join ', ')" -ForegroundColor Cyan
    } else {
        $targetSteps = 1..8
    }

    # --- STEP 1: PREP ---
    if ($targetSteps -contains 1) {
        Invoke-Step -Step 1 -Label "Mounting & Exporting Pro Baseline" -Action {
            Write-Host "[*] Mounting original ISO: $SourcePath..." -ForegroundColor Gray
            Mount-DiskImage -ImagePath $SourcePath -StorageType ISO | Out-Null
            
            # Use our robust drive letter capture
            $drive = $null
            # Try to find existing mount
            $img = Get-DiskImage -ImagePath $SourcePath -ErrorAction SilentlyContinue 
            if ($img.Attached) { $drive = ($img | Get-Volume).DriveLetter }
            if (-not $drive) { $drive = [string](Invoke-PollUntil { (Get-DiskImage -ImagePath $SourcePath | Get-Volume).DriveLetter } -MaxWaitSeconds 5) }
            
            if (-not $drive) { throw "ABORT: Could not resolve drive letter for $SourcePath" }
            $drive = "${drive}:"
            Write-Host "    -> Mounted on $drive" -ForegroundColor DarkGray

            $imagePath = Join-Path $drive "sources\install.wim"
            if (-not (Test-Path $imagePath)) { $imagePath = Join-Path $drive "sources\install.esd" }
            
            # --- PRE-BUILD METRICS ---
            $isoSizeOrig = (Get-Item $SourcePath).Length
            $wimSizeOrig = (Get-Item $imagePath).Length
            $script:OriginalMetrics = @{ 
                IsoSize = $isoSizeOrig; 
                WimSize = $wimSizeOrig; 
                StartTime = Get-Date 
            }

            $images = Get-WindowsImage -ImagePath $imagePath
            $proImage = $images | Where-Object { $_.ImageName.Trim() -ieq "Windows 11 Pro" } | Select-Object -First 1
            if (-not $proImage) { 
                Write-Host "[!] Pro Edition not found. Available in this ISO:" -ForegroundColor Yellow
                $images | ForEach-Object { Write-Host "    - [$($_.ImageIndex)] $($_.ImageName)" -ForegroundColor DarkGray }
                throw "ABORT: Windows 11 Pro not found." 
            }

            if (Test-Path $scratchDir) { 
                Write-Host "[*] Wiping old scratch space..." -ForegroundColor DarkGray
                Get-WindowsImage -Mounted | Where-Object { $_.MountPath -eq $mountDir } | Dismount-WindowsImage -Discard -ErrorAction SilentlyContinue
                Remove-Item -Path $scratchDir -Recurse -Force -ErrorAction SilentlyContinue 
            }
            New-Item -ItemType Directory -Path $mountDir -Force | Out-Null
            New-Item -ItemType Directory -Path $isoFilesDir -Force | Out-Null
            $scratch = Join-Path $scratchDir "DISM"
            New-Item -ItemType Directory -Path $scratch -Force | Out-Null

            # TURBO: Prevent Defender from scanning our deletions (Requires Admin)
            try { 
                Write-Host "[*] TURBO: Adding AV Exclusion for $scratchDir..." -ForegroundColor DarkGray
                Add-MpPreference -ExclusionPath $scratchDir -ErrorAction SilentlyContinue 
            } catch { }

            Write-Host "[*] Exporting index $($proImage.ImageIndex) ($($proImage.ImageName)) from $imagePath to $stagedWim..." -ForegroundColor Cyan
            Export-WindowsImage -SourceImagePath $imagePath -SourceIndex $proImage.ImageIndex -DestinationImagePath $stagedWim -CompressionType Maximum
            
            if ($Tiny) {
                Write-Host "[*] Mounting exported WIM (Fast Mode)..." -ForegroundColor Gray
                # Pre-create scratch to be safe
                if (-not (Test-Path $scratch)) { New-Item -ItemType Directory -Path $scratch -Force | Out-Null }
                Mount-WindowsImage -ImagePath $stagedWim -Index 1 -Path $mountDir -ScratchDirectory $scratch
            }
            Dismount-DiskImage -ImagePath $SourcePath -ErrorAction SilentlyContinue | Out-Null
        }
    }

    # --- MOUNT CONTINUITY CHECK ---
    if ($Tiny) {
        $hasStripping = ($targetSteps | Where-Object { $_ -ge 2 -and $_ -le 7 })
        $isMounted = (Get-WindowsImage -Mounted | Where-Object { $_.MountPath -eq $mountDir })
        
        if ($hasStripping -and -not $isMounted) {
            Write-Host "[!] RESUME DETECTED: Ensuring image is mounted for requested steps..." -ForegroundColor Yellow
            if (-not (Test-Path $stagedWim)) {
                throw "ABORT: Staged WIM not found at $stagedWim. You must run Step 1 (Fresh Start) first."
            }
            if (-not (Test-Path $mountDir)) { New-Item -ItemType Directory -Path $mountDir -Force | Out-Null }
            $scratch = Join-Path $scratchDir "DISM"
            if (-not (Test-Path $scratch)) { New-Item -ItemType Directory -Path $scratch -Force | Out-Null }

            Write-Host "[*] Restoring mount for stripping phase (Fast Mode)..." -ForegroundColor Gray
            Mount-WindowsImage -ImagePath $stagedWim -Index 1 -Path $mountDir -ScratchDirectory $scratch -ErrorAction Stop
            Write-Host "[OK] Mount restored successfully." -ForegroundColor Green
        }
    }

    if ($Tiny) {
        # --- STEP 2: APPX ---
        if ($targetSteps -contains 2) {
            Invoke-Step -Step 2 -Label "Stripping Appx Packages (Stable Audit)" -Action {
                $totalRemoved = 0
                foreach ($pattern in $AppxPatterns) {
                    try {
                        # Re-scan every time to avoid double-hits on already removed items
                        $currentApps = Get-AppxProvisionedPackage -Path $mountDir
                        $matches = $currentApps | Where-Object { $_.DisplayName -like $pattern -or $_.PackageName -like $pattern }
                        $count = ($matches | Measure-Object).Count
                        if ($count -gt 0) {
                            Write-Host "    [+] Found $count matches for '$pattern':" -ForegroundColor White
                            foreach ($m in $matches) {
                                Write-Host "        [-] Removing: $($m.DisplayName)" -ForegroundColor Gray
                                Remove-AppxProvisionedPackage -Path $mountDir -PackageName $m.PackageName -ErrorAction Stop | Out-Null
                                $totalRemoved++
                            }
                        } else {
                            Write-Host "    [ ] Found 0 matches for '$pattern' (Skipping)" -ForegroundColor DarkGray
                        }
                    } catch {
                        Write-Host "    [!] ERROR: Failed pattern ${pattern}: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                Write-Host "    [!] TOTAL REALITY CHECK: $totalRemoved Appx Packages Removed." -ForegroundColor Yellow
            }
        }

        # --- STEP 3: CAPS ---
        if ($targetSteps -contains 3) {
            Invoke-Step -Step 3 -Label "Stripping Capabilities (Nuclear Package Blast)" -Action {
                $totalBlasted = 0
                $stagedCaps = Get-WindowsCapability -Path $mountDir
                $blastList = @()
                
                # --- AUDIT & TRANSLATION ---
                foreach ($pattern in $CapabilityPatterns) {
                    $matches = $stagedCaps | Where-Object { $_.Name -like $pattern -and $_.State -ne 'NotPresent' }
                    $count = ($matches | Measure-Object).Count
                    if ($count -gt 0) {
                        Write-Host "    [+] Found $count matches for '$pattern' (Queuing as Packages)" -ForegroundColor White
                        foreach ($m in $matches) {
                            if ($blastList -notcontains $m.Name) { $blastList += $m.Name }
                        }
                    } else {
                        Write-Host "    [ ] Found 0 matches for '$pattern' (Skipping)" -ForegroundColor DarkGray
                    }
                }

                # --- NUCLEAR BLAST ---
                if ($blastList.Count -gt 0) {
                    Write-Host "`n[*] BLASTING $($blastList.Count) Capabilities in ONE atomic session..." -ForegroundColor Cyan
                    $allPackages = Get-WindowsPackage -Path $mountDir
                    $packageIdentities = @()

                    foreach ($capName in $blastList) {
                        $pMatch = $allPackages | Where-Object { $_.PackageName -match ([regex]::Escape($capName.Replace("~~~","*"))) }
                        if ($pMatch) { 
                            $packageIdentities += $pMatch[0].PackageName 
                        } else {
                            Write-Host "    [!] Fallback: Purging $capName individually..." -ForegroundColor Gray
                            & dism.exe /Image:$mountDir /Remove-Capability /CapabilityName:$capName /NoRestart | Out-Null
                            $totalBlasted++
                        }
                    }

                    if ($packageIdentities.Count -gt 0) {
                        $batchSize = 20
                        for($i=0; $i -lt $packageIdentities.Count; $i += $batchSize) {
                            $batch = $packageIdentities[$i..($i+$batchSize-1)] | Where-Object {$_}
                            $dismArgs = @("/Image:$mountDir", "/Remove-Package")
                            $batch | ForEach-Object { $dismArgs += "/PackageName:$_" }
                            & dism.exe $dismArgs
                            $totalBlasted += $batch.Count
                        }
                    }
                    Write-Host "    [!] TOTAL REALITY CHECK: $totalBlasted Capabilities Nuked." -ForegroundColor Yellow
                }
            }
        }

        # --- STEP 4: FEATURES ---
        if ($targetSteps -contains 4) {
            Invoke-Step -Step 4 -Label "Disabling System Features (Validated Audit)" -Action {
                $totalDisabled = 0
                $currentFeatures = Get-WindowsOptionalFeature -Path $mountDir
                foreach ($feat in $OptionalFeaturesToDisable) {
                    try { 
                        $match = $currentFeatures | Where-Object { $_.FeatureName -eq $feat -and $_.State -ne 'Disabled' }
                        if ($match) {
                            Write-Host "    [-] Disabling: $feat" -ForegroundColor Gray
                            & dism.exe /Image:$mountDir /Disable-Feature /FeatureName:$feat /Remove /NoRestart /ScratchDir:$scratchDir | Out-Null
                            $totalDisabled++
                        }
                    } catch { Write-Host "    [!] ERROR: Failed feature ${feat}: $($_.Exception.Message)" -ForegroundColor Red }
                }

                # TURBO: Kill 7GB Reserved Storage (Shaves ISO weight)
                Write-Host "    [-] TURBO: Disabling Reserved Storage..." -ForegroundColor Yellow
                & dism.exe /Image:$mountDir /Set-ReservedStorageState /State:Disabled /ScratchDir:$scratchDir | Out-Null

                Write-Host "    [!] TOTAL REALITY CHECK: $totalDisabled System Features Disabled." -ForegroundColor Yellow
            }
        }

        # --- STEP 5: WinRE NUKING ---
        if ($targetSteps -contains 5) {
            Invoke-Step -Step 5 -Label "Stripping Recovery Environment (WinRE.wim)" -Action {
                if (Test-Path $winrePath) {
                    Write-Host "    [-] Nuking: $winrePath (Saving ~600MB)" -ForegroundColor Yellow
                    attrib -h -s -r $winrePath
                    Remove-Item -Path $winrePath -Force
                } else {
                    Write-Host "    [ ] WinRE.wim not found (Skipping)." -ForegroundColor DarkGray
                }
            }
        }

        # --- STEP 6: CLEANUP ---
        if ($targetSteps -contains 6) {
            Invoke-Step -Step 6 -Label "Component Cleanup (ResetBase) - EMPTY TRASH" -Action {
                # --- BLOAT AUDIT (FEEDBACK-ENABLED) ---
                Write-Host "[*] SCANNING GIGABYTES: Identifying heaviest directories..." -ForegroundColor Cyan
                $topDirs = Get-ChildItem -Path $mountDir -Directory -ErrorAction SilentlyContinue
                $dirAudit = @()
                $count = 0
                
                foreach ($d in $topDirs) {
                    $count++
                    Write-Progress -Activity "Weighing System Payload" -Status "Calculating: $($d.Name)" -PercentComplete (($count / $topDirs.Count) * 100)
                    $size = (Get-ChildItem $d.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
                    $dirAudit += [PSCustomObject]@{ FullName = $d.FullName; SizeMB = [Math]::Round($size, 2) }
                }
                Write-Progress -Activity "Weighing System Payload" -Completed

                $topAudit = $dirAudit | Sort-Object SizeMB -Descending | Select-Object -First 10
                
                Write-Host "`n[!] TOP 10 HEAVIEST FOLDERS (TARGETED FOR CLEANUP):" -ForegroundColor White
                foreach ($auditItem in $topAudit) {
                    $shortPath = $auditItem.FullName.Replace($mountDir, "")
                    Write-Host ("    {0,10:N2} MB  -> {1}" -f $auditItem.SizeMB, $shortPath) -ForegroundColor Gray
                }
                Write-Host "`n[*] Purging component store (ResetBase)..." -ForegroundColor Cyan
                & dism.exe /Image:$mountDir /Cleanup-Image /StartComponentCleanup /ResetBase
            }
        }

        # --- STEP 7: DISMOUNT ---
        if ($targetSteps -contains 7) {
            Invoke-Step -Step 7 -Label "Dismounting & Saving" -Action {
                Dismount-WindowsImage -Path $mountDir -Save
            }
        }

        # --- STEP 8: GARBAGE COLLECTION (Compaction) ---
        if ($targetSteps -contains 8) {
            Invoke-Step -Step 8 -Label "COLD COMPRESSION: Finalizing Tiny WIM" -Action {
                $targetWim = $stagedWim
                if (-not (Test-Path $targetWim)) {
                    $fallback = Join-Path $isoFilesDir "sources\install.wim"
                    if (Test-Path $fallback) { 
                        Write-Host "[!] Using WIM from ISO structure for compaction..." -ForegroundColor Yellow
                        $targetWim = $fallback 
                    } else { throw "ABORT: install.wim not found." }
                }

                $preSize = (Get-Item $targetWim).Length / 1MB
                Write-Host "[*] WIM Size (Pre-Compaction): $("{0:N2}" -f $preSize) MB" -ForegroundColor Gray

                $compactedWim = Join-Path $scratchDir "install_compacted.wim"
                Write-Host "[*] Exporting stripped image to FRESH WIM (GC)..." -ForegroundColor Cyan
                Export-WindowsImage -SourceImagePath $targetWim -SourceIndex 1 -DestinationImagePath $compactedWim -CompressionType Maximum
                
                $postSize = (Get-Item $compactedWim).Length / 1MB
                Write-Host "[*] WIM Size (Post-Compaction): $("{0:N2}" -f $postSize) MB" -ForegroundColor Green
                Write-Host "[!] TOTAL REDUCTION: $("{0:N2}" -f ($preSize - $postSize)) MB" -ForegroundColor Yellow

                # INJECTION LOCK: Ensure the compacted WIM is both staged AND placed in the ISO root
                $finalIsoWim = Join-Path $isoFilesDir "sources\install.wim"
                $finalIsoSources = Split-Path $finalIsoWim -Parent
                if (-not (Test-Path $finalIsoSources)) { New-Item -ItemType Directory -Path $finalIsoSources -Force | Out-Null }
                
                Write-Host "[*] Injecting Tiny WIM into ISO structure: $finalIsoWim" -ForegroundColor Gray
                Move-Item -Path $compactedWim -Destination $finalIsoWim -Force
                if (Test-Path $stagedWim) { Copy-Item -Path $finalIsoWim -Destination $stagedWim -Force }
            }
        }
    }

    # --- STEP 9: BUILD ISO ---
    $targetName = if ($Tiny) { "Win11_Pro_Tiny_Vanilla.iso" } else { "Win11_Pro_Slim_Vanilla.iso" }
    
    if ($targetSteps -contains 9) {
        Invoke-Step -Step 9 -Label "Final Building of $targetName" -Action {
            # --- PRE-BUILD AUDIT ---
            $finalIsoWim = Join-Path $isoFilesDir "sources\install.wim"
            if (Test-Path $finalIsoWim) {
                $wimSize = (Get-Item $finalIsoWim).Length / 1GB
                if ($Tiny -and $wimSize -gt 4.5) {
                    Write-Host "[!] WARNING: Your 'Tiny' WIM is $($wimSize.ToString('N2')) GB. That's FAT!" -ForegroundColor Yellow
                } else {
                    Write-Host "[OK] Tiny Payload Verified: $($wimSize.ToString('N2')) GB" -ForegroundColor Green
                }
            }

            $drive = $null
            # Try to find existing mount
            $img = Get-DiskImage -ImagePath $SourcePath -ErrorAction SilentlyContinue 
            if ($img.Attached) { $drive = ($img | Get-Volume).DriveLetter }
            
            if (-not $drive) {
                Write-Host "[*] Re-mounting ISO to capture files..." -ForegroundColor Gray
                Mount-DiskImage -ImagePath $SourcePath -StorageType ISO -ErrorAction SilentlyContinue | Out-Null
                # Wait for volume to settle
                $drive = [string](Invoke-PollUntil { (Get-DiskImage -ImagePath $SourcePath | Get-Volume).DriveLetter } -MaxWaitSeconds 5)
            }

            if (-not $drive -or $drive -eq ":") { throw "ABORT: Could not resolve drive letter for $SourcePath" }
            $drive = "${drive}:"
            Write-Host "    -> Using source drive: $drive" -ForegroundColor DarkGray

            if (-not (Test-Path (Join-Path $isoFilesDir "boot"))) {
                Write-Host "[*] Building ISO structure..." -ForegroundColor Gray
                Get-ChildItem -Path $drive | Where-Object { $_.Name -ne "sources" -and $_.Name -ne "setup.exe" } | Copy-Item -Destination $isoFilesDir -Recurse
                New-Item -ItemType Directory -Path (Join-Path $isoFilesDir "sources") -Force | Out-Null
                
                # SURGICAL EXTRACTION: Only copy essential setup files, skipping heavy OEM upgrade bloat
                $blacklist = @("sxs", "dlmanifests", "replacementmanifests", "xp")
                Get-ChildItem -Path (Join-Path $drive "sources") | Where-Object { 
                    $_.Name -notin @("install.wim", "install.esd", "autounattend.xml") -and 
                    $_.Name -notin $blacklist 
                } | Copy-Item -Destination (Join-Path $isoFilesDir "sources") -Recurse
            }

            # NATIVE NO-PROMPT RENAMING: Use the built-in silent files from the ISO itself
            $noPromptFiles = Get-ChildItem -Path $isoFilesDir -Filter "*_noprompt.*" -Recurse
            if ($noPromptFiles) {
                Write-Host "[*] Activating Silent Boot (renaming native no-prompt files)..." -ForegroundColor Cyan
                foreach ($f in $noPromptFiles) {
                    $targetPath = $f.FullName.Replace("_noprompt", "")
                    Write-Host "    [-] Replacing: $($f.Name) -> $($f.Name.Replace('_noprompt',''))" -ForegroundColor Gray
                    Move-Item -Path $f.FullName -Destination $targetPath -Force
                }
            }

            # NUCLEAR ZERO-PROMPT BOOT: Delete bootfix.bin from BIOS and UEFI paths
            $bootFixFiles = Get-ChildItem -Path $isoFilesDir -Filter "bootfix.bin" -Recurse
            if ($bootFixFiles) {
                Write-Host "[*] Purging remnant bootfix.bin files..." -ForegroundColor Gray
                $bootFixFiles | Remove-Item -Force
            }
            
            # Smart WIM placement: Don't overwrite if Step 7 already put a compacted WIM there
            $finalWimPath = Join-Path $isoFilesDir "sources\install.wim"
            if (Test-Path $stagedWim) {
                Write-Host "[*] Moving master WIM to ISO structure..." -ForegroundColor Gray
                Move-Item -Path $stagedWim -Destination $finalWimPath -Force
            } elseif (Test-Path $finalWimPath) {
                Write-Host "[*] Compacted WIM already in place. Proceeding to build..." -ForegroundColor Cyan
            }
            
            $targetVanilla = Join-Path $DestinationPath $targetName
            $biosBoot = Join-Path $isoFilesDir "boot\etfsboot.com"
            $uefiBoot = Join-Path $isoFilesDir "efi\microsoft\boot\efisys.bin"
            $bootData = "2#p0,e,b$biosBoot#pEF,e,b$uefiBoot"
            
            & "oscdimg.exe" -m -o -u2 -udfver102 -bootdata:$bootData "$isoFilesDir" "$targetVanilla"
            Dismount-DiskImage -ImagePath $SourcePath -ErrorAction SilentlyContinue | Out-Null
            
            # --- STEP 10: CLEANUP ---
            Write-Host "`n[*] FINALIZING CLEANUP: Restoring system state..." -ForegroundColor Gray
            try { 
                Remove-MpPreference -ExclusionPath $scratchDir -ErrorAction SilentlyContinue 
                Write-Host "    [OK] AV Exclusion removed." -ForegroundColor DarkGray
            } catch { }
            
            if (Test-Path $scratchDir) { 
                Remove-Item -Path $scratchDir -Recurse -Force -ErrorAction SilentlyContinue 
                Write-Host "    [OK] Scratch space purged." -ForegroundColor DarkGray
            }

            # --- EXECUTIVE SUMMARY ---
            if (Test-Path $targetVanilla) {
                $isoSizeFinal = (Get-Item $targetVanilla).Length
                $finalWim = Join-Path $isoFilesDir "sources\install.wim"
                $wimSizeFinal = if (Test-Path $finalWim) { (Get-Item $finalWim).Length } else { 0 }
                
                $isoReduced = ($script:OriginalMetrics.IsoSize - $isoSizeFinal) / 1MB
                $wimReduced = ($script:OriginalMetrics.WimSize - $wimSizeFinal) / 1MB
                $isoSavings = ($isoReduced / ($script:OriginalMetrics.IsoSize / 1MB)) * 100
                $wimSavings = ($wimReduced / ($script:OriginalMetrics.WimSize / 1MB)) * 100
                $totalTime = (New-TimeSpan -Start $script:OriginalMetrics.StartTime -End (Get-Date)).TotalMinutes

                Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
                Write-Host "             [ TINY-OS EXECUTIVE BUILD SUMMARY ]" -ForegroundColor Cyan
                Write-Host ("=" * 60) -ForegroundColor Cyan
                Write-Host (" {0,-20} | {1,-15} | {2,-15} | {3,-10}" -f "Component", "Original", "Tiny", "Savings") -ForegroundColor White
                Write-Host ("-" * 60) -ForegroundColor DarkGray
                Write-Host (" {0,-20} | {1,12} MB | {2,12} MB | {3,8:N1}%" -f "Base ISO", ($script:OriginalMetrics.IsoSize / 1MB).ToString("N0"), ($isoSizeFinal / 1MB).ToString("N0"), $isoSavings) -ForegroundColor Gray
                Write-Host (" {0,-20} | {1,12} MB | {2,12} MB | {3,8:N1}%" -f "Core install.wim", ($script:OriginalMetrics.WimSize / 1MB).ToString("N0"), ($wimSizeFinal / 1MB).ToString("N0"), $wimSavings) -ForegroundColor Yellow
                Write-Host ("-" * 60) -ForegroundColor DarkGray
                Write-Host (" [!] TOTAL SHAVE: {0:N0} MB across all structures." -f ($isoReduced)) -ForegroundColor Green
                Write-Host (" [!] BUILD TIME:  {0:N2} Minutes." -f $totalTime) -ForegroundColor Cyan
                Write-Host ("=" * 60) -ForegroundColor Cyan
            }
        }
    }

    Write-Host "`n[OK] TINY BAKE PROCESS COMPLETE." -ForegroundColor Green
    [void](Read-Host "Press ENTER to return to Dashboard")

} finally {
    Dismount-DiskImage -ImagePath $SourcePath -ErrorAction SilentlyContinue | Out-Null
}
