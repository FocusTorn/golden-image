# Advanced: Injecting Registry Settings Offline
**Goal:** Change a Windows setting inside your `.wim` file without booting it.

## 🛠️ The "Ghost Registry" Workflow

1.  **Mount the Image:**
    (Use your `Run_Driver_Injection.ps1` script or the manual command to mount the `.wim` to the `Mount` folder).

2.  **Load the "Ghost" Hive:**
    Open an **Admin Command Prompt** and type:
    `reg load HKLM\OFFLINE_SOFTWARE "P:\Projects\golden-image\Mount\Windows\System32\config\SOFTWARE"`
    *This makes the "Software" registry of your Golden Image appear inside your current registry under a folder called "OFFLINE_SOFTWARE".*

3.  **Apply your Tweaks:**
    *   Open `regedit.exe`.
    *   Go to `HKEY_LOCAL_MACHINE\OFFLINE_SOFTWARE`.
    *   Change any setting you want (e.g., Disable a startup app, change a default path).

4.  **Unload the Hive (Save):**
    `reg unload HKLM\OFFLINE_SOFTWARE`

5.  **Commit the Image:**
    `dism /Unmount-Image /MountDir:"P:\Projects\golden-image\Mount" /Commit`

---

## ⚠️ The "Default User" Secret
If you want to change a setting for **new users** (like Wallpaper or Taskbar), you must load the "Default User" hive:
`reg load HKLM\OFFLINE_USER "P:\Projects\golden-image\Mount\Users\Default\NTUSER.DAT"`
*Any change you make in `OFFLINE_USER` will apply to every person who logs into that PC in the future.*
