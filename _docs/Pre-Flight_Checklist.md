# Golden Image: Final Pre-Flight Checklist
**Run these checks 10 minutes before you type the Sysprep command.**

## 1. Cleanliness
- [ ] **Log Out:** Signed out of Chrome, Edge, Steam, Discord, and Microsoft Account.
- [ ] **Downloads/Desktop:** All personal files (photos, installers) are deleted.
- [ ] **Recycle Bin:** Emptied.
- [ ] **Disk Cleanup:** Run as Admin, including "Windows Update Cleanup."

## 2. Stability
- [ ] **Pending Updates:** Windows Update says "You're up to date" (No restart pending).
- [ ] **BitLocker:** Turned OFF and fully decrypted (`manage-bde -status`).
- [ ] **Tamper Protection:** Turned OFF in Windows Security.
- [ ] **Internet:** Disconnect the Ethernet/WiFi *right before* running Sysprep.

## 3. The "Master" Files
- [ ] **unattend.xml:** Copied into `C:\Windows\System32\Sysprep`.
- [ ] **Universal Debloater:** Run one last time to ensure no new ASUS/NVIDIA bloat crept in.
- [ ] **Safety Backup:** You have confirmed that `OS_BACKUP.wim` exists on your external USB.

## 4. The Command
- [ ] Open Command Prompt as **Admin**.
- [ ] Navigate to `C:\Windows\System32\Sysprep`.
- [ ] Type: `sysprep.exe /oobe /generalize /shutdown /unattend:unattend.xml`

**NOTE:** If Sysprep finishes and the PC shuts down, **DO NOT TURN IT BACK ON** until you have booted into your WinPE USB to capture the image. If you boot back into Windows normally, you have to start the Sysprep process all over again.
