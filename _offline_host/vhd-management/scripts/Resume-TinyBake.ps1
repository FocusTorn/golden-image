[CmdletBinding()]
param(
    [string]$SourcePath = "N:\OS_Images\Win11_25H2_English_x64.iso",
    [string]$VanillaName = "Win11_Pro_Slim_Vanilla.iso",
    [string]$DestinationPath = "N:\OS_Images",
    [string]$ScratchDir = "N:\_bake_temp"
)
$ErrorActionPreference = "Stop"

$mountDir = Join-Path $ScratchDir "mount"
$isoFilesDir = Join-Path $ScratchDir "iso_files"
$stagedWim = Join-Path $ScratchDir "install.wim"

try {
    Write-Host "[*] RESUMING TINY BAKE FROM MOUNT: $mountDir" -ForegroundColor Cyan
    
    if (-not (Get-WindowsImage -Mounted | Where-Object { $_.MountPath -eq $mountDir })) {
        throw "ABORT: Mount point '$mountDir' is not active. Use S0 to start fresh."
    }

    Write-Host "[*] Re-attempting Feature Disabling (Recall)..." -ForegroundColor White
    $OptionalFeaturesToDisable = @('Recall')
    foreach ($feat in $OptionalFeaturesToDisable) {
        try {
            Write-Host "    [-] Disabling: $feat" -ForegroundColor Gray
            Disable-WindowsOptionalFeature -Path $mountDir -FeatureName $feat -Remove -NoRestart -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "    [!] WARN: Failed to disable Feature '$feat': $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    Write-Host "[*] PERFORMING COMPONENT CLEANUP (ResetBase)..." -ForegroundColor Yellow
    & dism.exe /Image:$mountDir /Cleanup-Image /StartComponentCleanup /ResetBase
    
    Write-Host "[*] DISMOUNTING & SAVING CHANGES..." -ForegroundColor Green
    Dismount-WindowsImage -Path $mountDir -Save

    # --- REBUILD ISO ---
    Write-Host "[*] Finalizing ISO Structure..." -ForegroundColor Gray
    # Re-build ISO infrastructure if it's there
    $targetVanilla = Join-Path $DestinationPath $VanillaName
    $biosBoot = Join-Path $isoFilesDir "boot\etfsboot.com"
    $uefiBoot = Join-Path $isoFilesDir "efi\microsoft\boot\efisys.bin"
    $bootData = "2#p0,e,b$biosBoot#pEF,e,b$uefiBoot"
    
    Write-Host "[*] RE-BUILDING TINY PRO ISO: $VanillaName..." -ForegroundColor Magenta
    & "oscdimg.exe" -m -o -u2 -udfver102 -bootdata:$bootData "$isoFilesDir" "$targetVanilla"
    
    Write-Host "[OK] RESUME COMPLETE. TINY ISO CREATED: $targetVanilla" -ForegroundColor Green

} catch {
    Write-Host "[ERROR] Resume failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Dismount-DiskImage -ImagePath $SourcePath -ErrorAction SilentlyContinue | Out-Null
}
