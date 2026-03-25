[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SourceFile,
    [Parameter(Mandatory=$true)]
    [string]$DestinationIso
)
$ErrorActionPreference = "Stop"

try {
    if (-not (Test-Path $SourceFile)) { throw "Source file not found: $SourceFile" }
    
    # Create temp folder for ISO contents
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    Copy-Item -Path $SourceFile -Destination (Join-Path $tempDir "autounattend.xml") -Force
    
    $fsi = New-Object -ComObject IMAPI2.MsftFileSystemImage -ErrorAction Stop
    $fsi.ChooseImageDefaultsForMediaType(12) | Out-Null # IMAPI_MEDIA_TYPE_DISK
    $fsi.FileSystemsToCreate = 1 # FsiFileSystemISO9660
    
    $fsi.Root.AddTree($tempDir, $false)
    $result = $fsi.CreateResultImage()
    $imageStream = $result.ImageStream
    
    $bytes = New-Object byte[] $imageStream.Size
    $imageStream.Read($bytes, $imageStream.Size) | Out-Null
    
    [System.IO.File]::WriteAllBytes($DestinationIso, $bytes)
    
    Remove-Item -Path $tempDir -Recurse -Force | Out-Null
} catch {
    throw "Failed to create autounattend ISO: $($_.Exception.Message)"
}
