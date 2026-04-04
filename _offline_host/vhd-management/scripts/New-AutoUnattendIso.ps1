param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceFile, # Your autounattend.xml

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$WindowsSourceIso, # The official Microsoft ISO

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationIso, # The output tiny ISO

    [Parameter(Mandatory=$false)]
    [string]$PayloadFolder
)

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = "Stop"

try {
    # 1. Path Validation
    if (-not (Test-Path -LiteralPath $SourceFile)) { throw "Source XML not found: $SourceFile" }
    if (-not (Test-Path -LiteralPath $WindowsSourceIso)) { throw "Windows Source ISO not found: $WindowsSourceIso" }
    
    # 2. Mount the Windows Source ISO to grab boot files
    Write-Host "[*] Mounting Windows Source: $(Split-Path $WindowsSourceIso -Leaf)" -ForegroundColor Gray
    $MountAction = Mount-DiskImage -ImagePath $WindowsSourceIso -PassThru -StorageType ISO
    $DriveLetter = ($MountAction | Get-Volume).DriveLetter
    if (-not $DriveLetter) { throw "Failed to obtain drive letter for mounted ISO." }
    $SourceDrive = $DriveLetter + ":"

    # 3. Create temp staging area
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    
    try {
        # 4. Extract Boot and EFI directories (required for the ISO to be bootable)
        Write-Host "[*] Extracting boot files from $SourceDrive..." -ForegroundColor Gray
        Copy-Item "$SourceDrive\boot" -Destination $tempDir -Recurse -Force
        Copy-Item "$SourceDrive\efi" -Destination $tempDir -Recurse -Force

        # 5. Place your custom XML at the root
        Copy-Item -LiteralPath $SourceFile -Destination (Join-Path $tempDir "autounattend.xml") -Force

        # 6. Mirror Payload Folder if provided
        if ($PayloadFolder -and (Test-Path $PayloadFolder)) {
            Write-Host "[*] Adding Payload Folder content..." -ForegroundColor Gray
            Copy-Item -Path "$PayloadFolder\*" -Destination $tempDir -Recurse -Force
        }

        # 7. Locate Oscdimg.exe
        $oscdimg = Get-Command "oscdimg.exe" -ErrorAction SilentlyContinue
        if (-not $oscdimg) { throw "oscdimg.exe not found in PATH. Please install Windows ADK." }

        # 8. Define No-Prompt Boot Arguments
        # p0 = BIOS (etfsboot.com), p1 = UEFI (efisys_noprompt.bin)
        $biosBoot = Join-Path $tempDir "boot\etfsboot.com"
        $uefiBoot = Join-Path $tempDir "efi\microsoft\boot\efisys_noprompt.bin"
        $bootArgs = "-bootdata:2#p0,e,b`"$biosBoot`"#p1,e,b`"$uefiBoot`""

        Write-Host "[*] Generating No-Prompt Bootable ISO..." -ForegroundColor Gray
        & $oscdimg.Source -n -m -o $bootArgs "$tempDir" "$DestinationIso"
        
        if ($LASTEXITCODE -ne 0) { throw "Oscdimg failed with exit code $LASTEXITCODE." }
        Write-Host "[OK] Tiny ISO created successfully: $DestinationIso" -ForegroundColor Green

    } finally {
        # 9. Cleanup: Dismount and Delete Temp
        Write-Host "[*] Cleaning up resources..." -ForegroundColor Gray
        Dismount-DiskImage -ImagePath $WindowsSourceIso | Out-Null
        if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
} catch {
    $msg = $_.Exception.Message
    $line = $_.InvocationInfo.ScriptLineNumber
    Write-Error "ISO Build Failure at line ${line}: $msg"
}