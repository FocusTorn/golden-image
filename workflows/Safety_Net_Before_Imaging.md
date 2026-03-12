# The "Safety Net" Guide: Backing Up Before Debloating
**READ THIS FIRST:** Standard System Restore points are NOT safe for Sysprep/Golden Image workflows. You must use a Full System Image.

## Method A: The Windows Legacy Image (Easiest)
1.  Connect your external drive.
2.  Search for **"Control Panel"** -> **"Backup and Restore (Windows 7)"**.
3.  Click **"Create a system image"** on the left.
4.  Select your external drive and hit **"Start Backup"**.
5.  *Result:* Creates a `WindowsImageBackup` folder on your drive.
6.  *To Restore:* Boot from a Windows USB -> Repair -> Troubleshoot -> System Image Recovery.

## Method B: The DISM "Master Snapshot" (Pro Level)
If you want a single file you can keep forever:
1.  Boot to your WinPE/Windows USB.
2.  Press `Shift + F10`.
3.  Identify your external drive letter (usually `D:` or `E:`).
4.  Run:
    `dism /Capture-Image /ImageFile:"D:\OS_BEFORE_DEBLOAT.wim" /CaptureDir:C:\ /Name:"PreDebloatBackup" /Compress:max`
5.  *To Restore:*
    `dism /Apply-Image /ImageFile:"D:\OS_BEFORE_DEBLOAT.wim" /Index:1 /ApplyDir:C:`

## ⚠️ Important Safety Rules
1.  **BitLocker:** If your drive is encrypted, you MUST turn it off (`manage-bde -off C:`) before Method B, or the snapshot will be unreadable.
2.  **Verify:** After Method A or B finishes, check your external drive to ensure the file (WIM) or folder (WindowsImageBackup) actually exists and has a size (usually 30GB+).
3.  **Drivers:** This backup includes all your drivers. If you restore this, your computer will be exactly as it is now—fully functional with all your hardware.
