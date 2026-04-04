param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceFile,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationIso,

    [Parameter(Mandatory=$false)]
    [string]$PayloadFolder
)
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = "Stop"

try {
    # Proactive Path Validation
    if (-not (Test-Path -LiteralPath $SourceFile)) { throw "Source 'autounattend.xml' not found at: $SourceFile" }
    if ($PayloadFolder -and -not (Test-Path -LiteralPath $PayloadFolder)) { throw "Staging PayloadFolder not found: $PayloadFolder" }

    # Create temp folder for ISO contents
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
    $finalXmlPath = Join-Path $tempDir "autounattend.xml"
    
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    Copy-Item -LiteralPath $SourceFile -Destination $finalXmlPath -Force

    # Mirror Payload Folder if provided
    if ($PayloadFolder) {
        Write-Host "[*] Mirroring Payload Folder: $PayloadFolder" -ForegroundColor Gray
        $null = Copy-Item -Path "$PayloadFolder\*" -Destination $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "[*] Ensuring target ISO is not locked: $DestinationIso" -ForegroundColor Gray
    Dismount-DiskImage -ImagePath "$DestinationIso" -ErrorAction SilentlyContinue | Out-Null
    
    Write-Host "[*] Creating ISO using Oscdimg.exe..." -ForegroundColor Gray
    
    $oscdimg = Get-Command "oscdimg.exe" -ErrorAction SilentlyContinue
    if (-not $oscdimg) { throw "oscdimg.exe not found in PATH. Please install Windows ADK / Deployment Tools." }

    & $oscdimg.Source -n -m "$tempDir" "$DestinationIso" 
    if ($LASTEXITCODE -ne 0) { throw "Oscdimg failed with exit code $LASTEXITCODE." }

    Write-Host "[OK] ISO created successfully: $DestinationIso" -ForegroundColor Green
    
    # Cleanup
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
} catch {
    if ($tempDir -and (Test-Path $tempDir)) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    $msg = $_.Exception.Message
    $line = $_.InvocationInfo.ScriptLineNumber
    throw "ISO Build Failure at line ${line}: $msg"
}
