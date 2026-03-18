
Even after a reboot,  ps5 is still default and Settings and File explorer are still pinned in the start menu




```ps1



    # ./dir/file.exe
    $noParent     = Join-Path $PSScriptRoot "dir/file.exe"

    # ../dir/file.exe
    $singleParent = Join-Path (Split-Path $PSScriptRoot -Parent) "dir/file.exe"
    
    # ../../dir/file.exe
    $doubleParent = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "dir/file.exe"
    

```




Enable-VMIntegrationService -VMName "Windows 11 Master" -Name "Guest Service Interface"

Set-VMHost -EnableEnhancedSessionMode $true 




Get-Service -Name TermService, vmicguestinterface | Select-Object Name, DisplayName, Status

# Start Remote Desktop Services
Set-Service -Name TermService -StartupType Automatic
Start-Service -Name TermService

# Start Hyper-V Guest Service Interface
Set-Service -Name vmicguestinterface -StartupType Automatic
Start-Service -Name vmicguestinterface










  Rename your .ps1 file to .bat and put this "Header" at the very top:

  The "One-File" Hybrid Header


   <# :
   @echo off
   pwsh -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content '%~f0') -join [Environment]::NewLine)"
   exit /b
   #>

   # --- EVERYTHING BELOW THIS LINE IS REGULAR POWERSHELL ---
   Write-Host "Successfully running in PowerShell 7!" -ForegroundColor Cyan
   Write-Host "Current Version: $($PSVersionTable.PSVersion)"
   $Host.UI.RawUI.WindowTitle = "My Auto-Running Script"

   # Your code here...
   pause











  The Fast Method (PowerShell Admin)
  Open PowerShell (or Terminal) as Administrator and run these two commands. This tells Windows that .ps1 files belong to a "PowerShell" class, and that the "Open" action for that class
  is to run pwsh.exe.


   # 1. Map the extension to a file type name
   assoc .ps1=Microsoft.PowerShellScript.1

   # 2. Define the execution command (using -ExecutionPolicy Bypass to ensure they actually run)
   ftype Microsoft.PowerShellScript.1="C:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -File "%1" %*
  Note: If your pwsh.exe is installed in a different path, adjust the string accordingly.

  ---

  The "Stay Open" Method
   ftype Microsoft.PowerShellScript.1="C:\Program Files\PowerShell\7\pwsh.exe" -NoExit -ExecutionPolicy Bypass -File "%1" %*














   @echo off
   :: Check for Admin Privileges
   net session >nul 2>&1
   if %errorLevel% neq 0 (
       echo [ERROR] Please run this batch file as Administrator.
       pause
       exit /b
   )

   echo [*] Setting .ps1 files to execute in PowerShell 7 (pwsh)...

   :: 1. Define the file association
   assoc .ps1=Microsoft.PowerShellScript.1

   :: 2. Set the execution command
   :: Note: We use "%%1" and "%%*" to escape them for Batch.
   ftype Microsoft.PowerShellScript.1="C:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -File "%%1" %%*

   echo [SUCCESS] Double-clicking a .ps1 file will now run it in pwsh.
   pause






  Alternative: The "Launcher" Batch File
  If you don't want to change the setting for your entire computer, but you want a specific script to run when you double-click it, you can create a "Wrapper" batch file next to your
  script:


  Example: Run_My_Script.bat
   @echo off
   pwsh -ExecutionPolicy Bypass -File "%~dp0YourScript.ps1"
   pause
   * %~dp0 tells the batch file to look in the same folder it is currently in.
   * This is the safest method for sharing scripts with others without messing with their Windows settings.


