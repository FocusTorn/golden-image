# Remove the Original (Incomplete) Build Tools Instance

After the bootstrapper install completes and you have a working MSVC instance, remove the **original** incomplete instance so only one Build Tools entry remains in the Visual Studio Installer.

## Steps

1. **Open Visual Studio Installer**  
   Start menu → “Visual Studio Installer”, or run:
   `C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe`

2. **Identify the two instances**  
   You should see two “Visual Studio Build Tools 2022” (or similar) cards.  
   - The **one to keep**: the one installed by the bootstrapper (usually has the C++ workload and components installed; `Check_MSVC_Installed.ps1` passes for it).  
   - The **one to remove**: the original instance (workload may be checked but components missing, or it’s the empty/broken one).

3. **Remove the original instance**  
   On the card you want to **remove** (the bad one):
   - Click the **three dots (⋮)** on that card, or use the dropdown next to it.
   - Choose **“Uninstall”** or **“Remove”**.
   - Confirm when prompted. The installer will remove that instance and its files.

4. **Confirm**  
   Only one Build Tools 2022 entry should remain. Run `code\Check_MSVC_Installed.ps1` to confirm MSVC is still installed and working.

## If you’re not sure which to remove

- **Keep** the instance whose install path is  
  `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools`  
  (or the path you used with the bootstrapper).
- **Remove** the other one, or the one that was created first (often the one that never got the components installed).

After removal, the remaining instance is the one the bootstrapper set up; use that for Rust and future updates.
