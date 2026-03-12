# 2025/2026 Windows Golden Image: Technical Workflow (Fresh Install)
**Goal:** Create a thin, system-agnostic Windows image (WIM/ESD) starting from a clean installation.

---

## 🛠️ Tool Sourcing
*   **Windows ISO:** Download from [Microsoft](https://www.microsoft.com/software-download/windows11).
*   **WinPE:** Created by the [Windows ADK](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install) or just use a standard Windows Install USB.
*   **WinUtil:** Accessed via `irm https://christitus.com/win | iex`.
*   **Deployment Scripts:** Located in `P:\Projects\golden-image\`.

---

## 🚀 Executive Action Plan (Step-by-Step)

| Step | Action | Tool | Purpose |
| :--- | :--- | :--- | :--- |
| **1** | **Fresh Install** | Windows ISO | Start clean. Do not connect internet. |
| **2** | **Enter Audit Mode**| `Ctrl + Shift + F3` | Log in as "Ghost Admin" without a user account. |
| **3** | **Debloat** | `Universal_Agnostic_Debloater.ps1` | Use your custom script for a hardware-neutral start. |
| **4** | **Install Software**| `winget` / Ninite | Install VS Code, Browser, etc. |
| **5** | **Apply Tweaks** | WinUtil | Final system-level optimizations and AI removal. |
| **6** | **Prep Unattend** | `unattend.xml` | Set up OOBE skip and profile copying. |
| **7** | **Sysprep** | `sysprep.exe` | Generalize and shut down. |
| **8** | **Capture** | DISM (WinPE) | Save the master `.wim` file. |

---

## 1. Detailed Technical Steps

### Phase 1: Clean Installation & Audit Mode
1.  Install Windows. At the "Let's connect you to a network" screen, press `Shift + F10` and type `OOBE\BYPASSNRO` to skip the Microsoft Account requirement.
2.  At the **Region Selection** screen, press `Ctrl + Shift + F3`.
3.  The system reboots into **Audit Mode**. Minimize the Sysprep window.

### Phase 2: Customization & Universal Cleaning
1.  **Hardware-Neutral Clean:** Run `Universal_Agnostic_Debloater.ps1`. This ensures no OEM drivers or bloat contaminate your master image.
2.  **Install Apps:** Use the terminal for speed:
    `winget install Google.Chrome Microsoft.VisualStudioCode`
3.  **Final Tweak:** Run Chris Titus WinUtil to disable telemetry and remove "Recall" AI components.

### Phase 3: The "Generalize" Command
1.  Place `unattend.xml` into `C:\Windows\System32\Sysprep\`.
2.  Run:
    ```cmd
    cd C:\Windows\System32\Sysprep
    sysprep.exe /oobe /generalize /shutdown /unattend:unattend.xml
    ```

### Phase 4: Capture (The "Ghost" Image)
1.  Boot into WinPE.
2.  Identify your external drive letter (e.g., `E:`).
3.  Run the capture:
    ```cmd
    dism /Capture-Image /ImageFile:"E:\Golden_Master_2026.wim" /CaptureDir:C:\ /Name:"Windows11_Thin_Agnostic" /Compress:max
    ```

---

## 🛠️ Troubleshooting & Tips
*   **Virtual Machines:** For a "Fresh Install" image, **always** use a VM (Hyper-V). It is the only way to ensure 100% hardware agnosticism.
*   **ESD Conversion:** To make the file even smaller (but harder to edit), export the WIM to ESD:
    `dism /Export-Image /SourceImageFile:Master.wim /SourceIndex:1 /DestinationImageFile:install.esd /Compress:recovery`
