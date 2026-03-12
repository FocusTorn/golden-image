# 2025/2026 Windows Golden Image: Existing OS Migration Workflow
**Goal:** Capture your current, customized Windows environment (settings, apps, and personalization) into a thin, system-agnostic image.

---

## 🛠️ Resource & Tool Checklist
Before starting, ensure you have gathered these tools:
*   **WinPE / Windows Installation USB:** Created using the [Windows Media Creation Tool](https://www.microsoft.com/software-download/windows11).
*   **Chris Titus WinUtil:** (Included in scripts) for deep debloating.
*   **Imaging Scripts:** (Located in `P:\Projects\golden-image\`)
    *   `Universal_Agnostic_Debloater.ps1`: Cleans hardware-specific junk and bloat.
    *   `Generate_App_Lists_V2.ps1`: Audits your current apps before you start.
    *   `unattend.xml`: Essential for keeping your settings (CopyProfile).

---

## 🚀 Executive Action Plan (Existing OS)

| Step | Action | Tool | Purpose |
| :--- | :--- | :--- | :--- |
| **1** | **Safety Backup** | `Safety_Net_Before_Imaging.md` | Create a "Undo" image of your PC before touching it. |
| **2** | **App Audit** | `Generate_App_Lists_V2.ps1` | See exactly what is currently on your drive. |
| **3** | **Hardware Cleanup**| `Universal_Agnostic_Debloater.ps1`| Strip ASUS/NVIDIA/Realtek and standard bloat. |
| **4** | **Disable Security** | PowerShell / Settings | Turn off BitLocker (Crucial) and Tamper Protection. |
| **5** | **Prep Answer File** | `unattend.xml` | Force Windows to save your settings via `CopyProfile`. |
| **6** | **Generalize** | `sysprep.exe` | Strip hardware IDs but keep the "brain" and settings. |
| **7** | **Offline Capture** | DISM (WinPE) | Take the "Master Photo" of your customized drive. |

---

## 1. Detailed Action Steps

### Phase 1: Preparation (The "Safety & Shrink" Phase)
1.  **Safety Net:** Run Method B from the `Safety_Net_Before_Imaging.md`. This saves your current PC to a `.wim` file so you can revert if Sysprep fails.
2.  **Disable BitLocker:** 
    *   Open Admin PowerShell: `Manage-bde -off C:`
    *   *Verify:* Use `manage-bde -status` to ensure it says "Fully Decrypted."
3.  **Disable Tamper Protection:** Go to Windows Security > Virus & threat protection > Manage settings > Turn off Tamper Protection.

### Phase 2: Personalization & Universal Debloating
1.  **Run Universal Debloater:** 
    Right-click `Universal_Agnostic_Debloater.ps1` and **Run with PowerShell (Admin)**. This script removes:
    *   ASUS PC Assistant & Utilities.
    *   NVIDIA Control Panel.
    *   Realtek Audio Controls.
    *   All identified "Red" bloatware (Clipchamp, Xbox, Bing, etc.).
2.  **Verify Settings:** Ensure your wallpaper, taskbar, and app settings are exactly how you want them.

### Phase 3: The "Migration" Answer File
1.  Copy the `unattend.xml` from `P:\Projects\golden-image\` to `C:\Windows\System32\Sysprep\`.
2.  This file contains the `<CopyProfile>true</CopyProfile>` command, which is the only way to make your current settings stick for future users.

### Phase 4: The "Sysprep" Execution
1.  **Disconnect Internet:** This prevents Windows from silently updating an app while Sysprep is running (which causes a crash).
2.  **Run Sysprep:**
    ```cmd
    cd C:\Windows\System32\Sysprep
    sysprep.exe /oobe /generalize /shutdown /unattend:unattend.xml
    ```
    *Wait for the PC to shut down.*

### Phase 5: Capture the Golden Image
1.  Boot into your **WinPE USB**. Press `Shift + F10`.
2.  **Capture:**
    ```cmd
    dism /Capture-Image /ImageFile:"D:\Thin_Agnostic_Master.wim" /CaptureDir:C:\ /Name:"ThinMaster2026" /Description:"Personalized_HardwareNeutral" /Compress:max
    ```

---

## ⚠️ Critical Troubleshooting for Existing OS
*   **"Sysprep was unable to validate..."** Check `C:\Windows\System32\Sysprep\Panther\setupact.log`. If it lists a package (like Spotify), run: `Get-AppxPackage *Spotify* -AllUsers | Remove-AppxPackage -AllUsers`.
*   **Rearm Count:** If you get a "Fatal Error," your OS may have been sysprepped too many times. Use Method B (Restore) and try a fresh install workflow instead.
