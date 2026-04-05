$ErrorActionPreference = 'Stop'
Write-Host '[*] Initializing Developer Bootstrap...' -ForegroundColor Cyan
Set-Location 'C:\Windows\Setup\Scripts'
Write-Host '>>> STAGE: Customize'; & '.\Customize.ps1'
Write-Host '>>> STAGE: 1_Scoop'; & '.\1_Scoop.ps1'
Write-Host '>>> STAGE: 2_MSVC'; & '.\2_MSVC.ps1'
Write-Host '>>> STAGE: 3_System_Apps'; & '.\3_System_Apps.ps1'
Write-Host '>>> STAGE: 4_Rust_Finish'; & '.\4_Rust_Finish.ps1'
Write-Host '>>> STAGE: 5_Finalize'; & '.\5_Finalize.ps1'
