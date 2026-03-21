#Requires -Version 5.1
<#
.SYNOPSIS
    Downloads Newtonsoft.Json from NuGet into _helpers\lib for JSONC parsing on Windows PowerShell 5.1.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-NewtonsoftJson.ps1
#>
param(
    [string]$Version = '13.0.3'
)
$ErrorActionPreference = 'Stop'
$libDir = Join-Path $PSScriptRoot 'lib'
if (-not (Test-Path $libDir)) { New-Item -ItemType Directory -Path $libDir -Force | Out-Null }

$dllOut = Join-Path $libDir 'Newtonsoft.Json.dll'
if (Test-Path $dllOut) {
    Write-Host "Already present: $dllOut" -ForegroundColor Green
    exit 0
}

$nupkg = Join-Path $env:TEMP "Newtonsoft.Json.$Version.nupkg"
$uri = "https://www.nuget.org/api/v2/package/Newtonsoft.Json/$Version"
Write-Host "Downloading $uri ..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $uri -OutFile $nupkg -UseBasicParsing

$expand = Join-Path $env:TEMP "Newtonsoft.Json.$Version.extract"
if (Test-Path $expand) { Remove-Item $expand -Recurse -Force }
# .nupkg is a ZIP; Expand-Archive only accepts .zip on Windows PowerShell 5.1
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($nupkg, $expand)

$srcDll = Get-ChildItem -Path $expand -Recurse -Filter 'Newtonsoft.Json.dll' |
    Where-Object { $_.FullName -match '\\lib\\net(45|standard2\.0)\\' } |
    Select-Object -First 1
if (-not $srcDll) {
    throw "Newtonsoft.Json.dll not found inside nupkg."
}
Copy-Item -LiteralPath $srcDll.FullName -Destination $dllOut -Force
Write-Host "Installed: $dllOut" -ForegroundColor Green
