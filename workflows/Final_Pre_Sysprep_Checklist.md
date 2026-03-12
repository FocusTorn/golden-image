# 🏆 Golden Image: Final Zero-Hour Checklist & Workflow
**Goal:** Ensure the Windows environment is perfectly "frozen" and clean before the Sysprep generalization process.

---

## 🔍 Phase 0: Sysprep Dry Run (recommended)
Run **`code\Sysprep_Dry_Run.ps1`** as Administrator. It does **not** run Sysprep; it only checks for conditions that will cause Sysprep to fail (unattend.xml, BitLocker, domain, rearm count, Appx "Sysprep killers").  
**If it reports Microsoft.DesktopAppInstaller (WinGet) as a problem:** that state is often **unrepairable**. See **`Desktop_App_Installer_Sysprep_Fix.md`** — the reliable fix is to rebuild the image and do all customization in **Audit Mode**.

---

## 🛑 Phase 1: The "Silent Killers" (System Prep)
Run the `Pre_Sysprep_Zero_Hour.ps1` script first. It handles:
1.  **Hibernation:** Disabled via `powercfg /h off` to prevent file system locks.
2.  **Reserved Storage:** Disabled to save ~7GB of disk space.
3.  **Event Logs:** All previous error/system logs are wiped.
4.  **Temp Files:** All Windows and User temp directories are purged.

---

## 🛠️ Phase 2: Manual Integrity Checks
Before typing the Sysprep command, you **must** manually verify these three items:

### 1. The Microsoft Store Trap
*   Open the **Microsoft Store**.
*   Go to **Library**.
*   Ensure there are **ZERO** pending updates. 
*   *Why?* If Windows tries to update an app while Sysprep is running, the entire process will crash with a fatal error.

### 2. VirtualBox Cleanup
*   Go to **Settings > Apps > Installed Apps**.
*   Uninstall **Oracle VM VirtualBox Guest Additions**.
*   *Note:* The screen will flicker and resolution will drop. This ensures virtual drivers aren't baked into your physical image.

### 3. Connection Isolation
*   **Disconnect the Internet** from the VM settings.
*   This prevents Windows from "phoning home" or starting a background update at the last second.

---

## 📝 Phase 4: The Answer File (`unattend.xml`)
Ensure your `unattend.xml` is located at:
`C:\Windows\System32\Sysprep\unattend.xml`

**Check for this specific line:**
`<CopyProfile>true</CopyProfile>`
*This is what ensures your current wallpaper, taskbar, and settings become the default for all future users.*

---

## ⚡ Phase 5: The Final Command
Open **Command Prompt (Admin)** and execute exactly:

```cmd
cd C:\Windows\System32\Sysprep
sysprep.exe /oobe /generalize /shutdown /unattend:unattend.xml
```

### **What happens next?**
1.  The screen will show "Sysprep is working..."
2.  The VM will shut down completely.
3.  **DO NOT TURN THE VM BACK ON.**
4.  Follow your **Capture Guide** to mount the `.vhdx` and save your `.wim` file.

---

## 🛠️ Troubleshooting: "Sysprep was unable to validate..."
If the command fails, check the log file immediately:
`C:\Windows\System32\Sysprep\Panther\setupact.log` (and `setuperr.log`)
*   Scroll to the bottom. It will name the specific Appx package (e.g., `Microsoft.Spotify`) that blocked the process.
*   For most apps: uninstall that app and try again.
*   **For Microsoft.DesktopAppInstaller (WinGet):** Uninstall/repair often fails. See **`Desktop_App_Installer_Sysprep_Fix.md`** — the reliable fix is to rebuild the image in **Audit Mode** and use `winget install --scope machine` only.
