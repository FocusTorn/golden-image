# List Microsoft Store Apps (Pre-Debloat Check)
Run these commands in an **Administrator PowerShell** to see exactly what is on your system before you start removing things.

## 1. List All Currently Installed Apps
This will show everything installed for the current user and other accounts.
```powershell
Get-AppxPackage -AllUsers | Select-Object Name, PackageFullName | Sort-Object Name | Out-File "P:\Projects\Installed_Apps_List.txt"
```

## 2. List "Provisioned" Apps (The Bloat Source)
Provisioned apps are the ones Microsoft hides in a "waiting room." Even if you delete an app, if it's still "Provisioned," it will come back when you create a new user or run Sysprep. These are the primary targets for thinning.
```powershell
Get-AppxProvisionedPackage -Online | Select-Object DisplayName, PackageName | Sort-Object DisplayName | Out-File "P:\Projects\Provisioned_Apps_List.txt"
```

---

## 💡 How to read these lists:
*   **Safe to Remove (Bloat):** Things like `Microsoft.ZuneVideo` (Movies & TV), `Microsoft.People`, `Microsoft.GamingApp` (Xbox), `Disney`, `Spotify`, etc.
*   **DO NOT REMOVE (System):** Things like `Microsoft.WindowsStore` (unless you really want it gone), `Microsoft.BioEnrollment` (Hello/Face ID), `Microsoft.DesktopAppInstaller`.

## 🔍 Quick View Script
You can run this one-liner to see the list directly in your console window:
```powershell
Get-AppxPackage -AllUsers | Where-Object {$_.IsFramework -eq $false} | Select-Object Name | Sort-Object Name
```

---

## I have generated a helper script for you:
I've created a PowerShell script in your projects folder that will automatically generate these text files for you to review.
