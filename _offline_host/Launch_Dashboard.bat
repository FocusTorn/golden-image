   @echo off
   :loop
   cls
   :: 'call' prevents the batch file from being tied to the process termination
   call powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\vhd-management\Staging_Dashboard.ps1"
   echo.
   echo Dashboard exited. Press any key to reload...
   pause >nul
   goto loop