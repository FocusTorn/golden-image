@echo off
cls
echo ==========================================
echo       WINDOWS DISK PREPARATION TOOL
echo ==========================================
echo.
echo CURRENT DISK LIST:
echo ------------------------------------------
echo list disk | diskpart | findstr /C:"Disk"
echo ------------------------------------------
echo.

set /p disknum="ENTER THE DISK NUMBER TO WIPE (e.g. 0): "

echo.
echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
echo WARNING: DISK %disknum% WILL BE WIPED!
echo ALL DATA ON DISK %disknum% WILL BE LOST.
echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
echo.
pause

:: Create a temporary diskpart script
(
echo select disk %disknum%
echo clean
echo convert gpt
echo create partition efi size=100
echo format quick fs=fat32 label="System"
echo assign letter=S
echo create partition msr size=16
echo create partition primary size=500
echo format quick fs=ntfs label="Recovery"
echo set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac"
echo gpt attributes=0x8000000000000001
echo create partition primary
echo format quick fs=ntfs label="Windows"
echo assign letter=W
echo exit
) > X:\diskpart_temp.txt

:: Run the script
diskpart /s X:\diskpart_temp.txt

:: Clean up
del X:\diskpart_temp.txt

echo.
echo ------------------------------------------
echo DISK %disknum% PREPARED SUCCESSFULLY!
echo ------------------------------------------
echo YOU CAN NOW APPLY THE IMAGE TO DRIVE W:
echo ------------------------------------------
pause
