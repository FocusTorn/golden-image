# Building GoldenImager2 (Offline Portable Edition)

This guide explains how to compile **GoldenImager2** into a **single, standalone, zero-dependency Windows `.exe`**. This is specifically designed for use in **offline Sysprep Audit Mode** environments where no internet access or runtimes are available.

## Key Portable Features
- **All-in-One Binary**: The UI, Rust engine, configuration files, and registry scripts are bundled into a single file.
- **Zero Runtime**: No Node.js or Rust is required on the target machine.
- **Air-Gapped Ready**: Once built, the binary requires no internet connection.
Ensure your environment is set up:
- **Rust (MSVC)**: For the native engine.
- **Node.js & npm**: For the Svelte frontend.
- **Tauri CLI**: `npm install -g @tauri-apps/cli`

## Dev Mode vs. Prod Mode

- **Dev Mode (`npm run tauri dev`)**:
  - Uses the **Debug** profile (faster compilation).
  - Supports **Hot Module Replacement (HMR)** for the UI.
  - Supports Rust incremental compilation (fast restarts after the first build).
  - Includes a debugger/web inspector (right-click -> Inspect).

- **Prod Mode (`npm run tauri build`)**:
  - Uses the **Release** profile (maximum optimization, smaller size).
  - Strips debug symbols and enables performance optimizations.
  - Generates the final **Portable .exe** and **MSI Installer**.

## Optimization Tips for Developers

### How to avoid the "Frontend Waiting" delay:
If you find yourself waiting for `tauri dev` to start the frontend each time:
1.  **Keep the UI server running**: Open a separate terminal and run `npm run dev`.
2.  **Update `tauri.conf.json`**: Temporarily comment out the `beforeDevCommand`.
3.  **Instant UI Mode**: Use **Option [2]** in `GoldenImager2.bat` for styling work. This bypasses the Rust compiler and the Tauri overhead entirely.

### Faster Rust Rebuilds:
The first compilation takes time because it downloads and compiles the Windows API crates. Standard development runs will be much faster (usually < 2 seconds) because Rust only re-compiles what you changed.

## The Build Process
GoldenImager2 uses **Tauri** to bundle the Rust backend and Svelte frontend together.

1.  Open a terminal in the `GoldenImager2` folder.
2.  Run the build command:
    ```powershell
    npm run tauri build
    ```
    *Note: The first time you run this, it will download many dependencies and may take 5–10 minutes.*

## Output Locations
Once the build completes successfully, you can find the results in:

- **Standalone Executable**:  
  `src-tauri\target\release\GoldenImager2.exe`
  
- **MSI Installer**:  
  `src-tauri\target\release\bundle\msi\GoldenImager2_0.1.0_x64_en-US.msi`

## Technical Details
- **Bundled Resources**: All configuration files (`Apps.json`, `Features.json`) and registry scripts are compressed into the final binary.
- **Mica/Glassmorphism**: The build automatically enables native Windows 11 transparency effects.
