# Visual Studio Build Tools — Manual GUI Checklist (for Rust / Stage 4)

If you install or modify the MSVC workload **manually** in the Visual Studio Installer (instead of running Stage 2 `Install_Stage_2_MSVC.ps1` or Stage 4 `Install_Stage_4_Rust_Finish.ps1`), use this checklist so the result matches what the script expects.

---

## 1. Open the right product

- Start **Visual Studio Installer** (Start menu or `C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe`).
- In the list of installed products, select **Visual Studio Build Tools 2022** (not Community, not Enterprise).
- If Build Tools is not installed at all, install it first (e.g. via winget: `winget install Microsoft.VisualStudio.2022.BuildTools`) then continue below.

---

## 2. Modify the instance

- Click **Modify** on the Build Tools 2022 card.

---

## 3. Workloads tab — what to check

| Check | Workload | Notes |
|-------|----------|--------|
| **Yes** | **Desktop development with C++** | This is the "VCTools" workload (MSVC compiler, linker, headers). Required for Rust (MSVC toolchain). |

Do **not** need: .NET desktop, Azure, UWP, etc. Only the C++ desktop workload is required for the golden image / Rust.

---

## 4. Individual components (optional check)

The C++ workload usually includes a Windows SDK. The script explicitly adds **Windows 11 SDK (10.0.22621.x)**. In the GUI:

- Open the **Individual components** tab.
- Search for **Windows 11** or **Windows SDK**.
- Ensure **Windows 11 SDK (10.0.22621.0)** or the latest 22H2 SDK is selected if you want to match the script exactly. It is often already included when "Desktop development with C++" is selected.

---

## 5. Install path (optional)

- The script uses: `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools`.
- If you installed Build Tools elsewhere, the script’s vswhere check may still find it; otherwise point the script or your PATH to the instance you modified.

---

## 6. After installing

- Close the installer and run **Stage 4** again, or run `rustup default stable-x86_64-pc-windows-msvc` and continue with the rest of the script (PATH, cargo tools) if you only needed the MSVC workload fixed.

---

## Quick reference (script equivalent)

The script runs the equivalent of:

```text
setup.exe modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" ^
  --add Microsoft.VisualStudio.Workload.VCTools ^
  --add Microsoft.VisualStudio.Component.Windows11SDK.22621 ^
  --quiet --norestart
```

So in the GUI you need at least:

- **Workload:** Desktop development with C++
- **Component (if visible):** Windows 11 SDK 22H2 (22621)
