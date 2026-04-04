[CmdletBinding()]
param(
    [string]$VanillaIsoPath = "N:\OS_Images\Win11_Pro_Slim_Vanilla.iso",
    [string]$SourceXml = "N:\_autounattend\autounattend.xml",
    [string]$TargetName = "Win11_Pro_Final_Master.iso",
    [string]$DestinationPath = "N:\OS_Images\"
)
$ErrorActionPreference = "Stop"

try {
    Write-Host "[*] Mounting Vanilla Master: $VanillaIsoPath..." -ForegroundColor Gray
    Mount-DiskImage -ImagePath $VanillaIsoPath -StorageType ISO | Out-Null
    
    $drive = (Get-DiskImage -ImagePath $VanillaIsoPath | Get-Volume).DriveLetter + ":"
    Write-Host "    -> Mounted on $drive" -ForegroundColor DarkGray
    
    # Create local scratch space
    $scratchDir = Join-Path ([System.IO.Path]::GetTempPath()) "GoldenMaster_FinalBake"
    if (Test-Path $scratchDir) { Remove-Item -Path $scratchDir -Recurse -Force | Out-Null }
    New-Item -ItemType Directory -Path $scratchDir | Out-Null

    Write-Host "[*] Copying master files to injection staging..." -ForegroundColor Gray
    Copy-Item -Path "$($drive)\*" -Destination $scratchDir -Recurse

    Write-Host "[*] INJECTING MASTER XML: Grafting autounattend.xml..." -ForegroundColor Cyan
    if (Test-Path $SourceXml) {
        Copy-Item -Path $SourceXml -Destination (Join-Path $scratchDir "autounattend.xml") -Force
    } else {
        throw "ABORT: Source XML '$SourceXml' not found."
    }

    # Re-build into Final ISO (UEFI/BIOS Dual Boot)
    $targetIso = Join-Path $DestinationPath $TargetName
    Write-Host "[*] RE-BUILDING MASTER ISO: $targetIso..." -ForegroundColor Magenta

    # oscdimg is extremely picky about quotes in the -bootdata string.
    $bootData = "2#p0,e,b$biosBoot#pEF,e,b$uefiBoot"
    
    & "oscdimg.exe" -m -o -u2 -udfver102 -bootdata:$bootData "$scratchDir" "$targetIso"
    if ($LASTEXITCODE -ne 0) { throw "oscdimg failed to create Final Master ISO with exit code $LASTEXITCODE" }
    
    Write-Host "[OK] GOLDEN MASTER FINAL ISO CREATED: $targetIso" -ForegroundColor Green
    
} catch {
    Write-Host "[ERROR] Final Bake failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Dismount-DiskImage -ImagePath $VanillaIsoPath -ErrorAction SilentlyContinue | Out-Null
    if (Test-Path $scratchDir) { Remove-Item -Path $scratchDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null }
}
