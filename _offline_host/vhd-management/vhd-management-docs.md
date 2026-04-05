# VHD Management: Technical Infrastructure Guide

## 1. Overview
The VHD Management suite is a PowerShell-driven orchestration framework designed to automate the lifecycle of Windows Virtual Hard Disks (VHDX). It facilitates the transition of images between high-speed host-side file operations and Hyper-V based virtual machine execution for true hardware-level customization and validation.

This infrastructure is the "mastering" engine for the **Golden Image** project, moving beyond simple script injection to full OS-level automation during the Windows Setup process.

---

## 2. System Architecture

### 2.1. Dual-State Execution
The suite operates on a "State Transition" model:
- **Host Mode**: The VHDX is mounted locally on the technician's machine. This is used for `robocopy` syncs, registry hive mounting, and surgical stripping using DISM.
- **VM Mode**: The VHDX is attached to a Hyper-V VM. This is used for "Active Customization" (OOBE, Appx removal, Windows Updates) where the OS must be live to process changes.

### 2.2. Configuration (The Source of Truth)
All operations are governed by `_master_config.json` in the project root. This file defines:
- **VMProfiles**: Maps specific workloads (e.g., "Tiny11", "Workstation") to paths and VM names.
- **VMProvisioningTemplates**: Defines hardware specs (RAM, vCPUs, Generation) to ensure consistency across builds.

---

## 3. Core Components

### 3.1. Staging Dashboard (`Staging_Dashboard.ps1`)
The primary entry point. It provides a menu-driven interface to:
- **Mount/Dismount**: Rapidly toggle the VHD between Host and VM states.
- **Sync Files**: Mirrors local source folders (`_offline`, `installers`) to the VHD.
- **Launch scripts**: Executes the specialized provisioning and capture scripts.
- **Lock Diagnostics**: Resolves the common "File in use" errors caused by Hyper-V or the Virtual Disk Service (VDS).

### 3.2. Unattend Engine (`unattend_engine/`)
The "brain" of the automated installation. It uses a hardened `autounattend.xml` to bypass Windows 11 hardware checks and automate the setup flow.

#### Key Files:
- **`autounattend.xml`**: Handles disk partitioning (GPT/UEFI), region settings, and script injection.
- **`Specialize.ps1`**: Runs during the `specialize` pass. It stages the `scripts/` folder from the Answer ISO to the local drive and installs PowerShell 7.
- **`FirstLogon.ps1`**: Runs on the first boot as Administrator. It cleans up reparse points and resets the AutoLogon count.
- **`UserOnce.ps1`**: Configures the user environment (Classic context menu, hiding search, desktop icons) and restarts Explorer to apply changes.

### 3.3. Support Scripts (`scripts/`)
Standalone utilities called by the Dashboard or used for specific workflows:
- **`New-MasterLikeVm.ps1`**: Provisions a new Hyper-V VM based on a template.
- **`New-WimFromVhd.ps1`**: Captures a sysprepped VHD into a compressed `.wim` file using DISM.
- **`Boot-WimInNewVm.ps1`**: Validates a captured WIM by applying it to a fresh VHD and attempting a silent boot.

---

## 4. Operational Workflows

### 4.1. The "Golden" Lifecycle
1.  **Provision**: Create a fresh VM and VHD using `New-MasterLikeVm`.
2.  **Mount**: Use the Dashboard to mount the VHD on the Host.
3.  **Sync**: Robocopy the latest toolkit and installers.
4.  **Execute**: Start the VM. The `unattend_engine` takes over, performing a Zero-Touch installation.
5.  **Seal**: The VM reseals into **Audit Mode** for final inspection.
6.  **Capture**: Run `New-WimFromVhd` to create the final deployment image.

### 4.2. Lock Mitigation logic
VHDX files are notoriously difficult to manage due to `vmsvc` and `vds` locks. The suite includes `Invoke-SmartRelease` (in `VhdUtils.ps1`) which:
1.  Terminates Hyper-V worker processes (`vmwp.exe`) for that VM.
2.  Force-detaches the VHD from the host.
3.  Restarts the Virtual Disk Service if necessary.

---

## 5. Security & Hardening
- **Bypass Logic**: Integrated Registry bypasses for TPM, Secure Boot, and RAM requirements to support "Tiny" builds and legacy hardware.
- **Policy Suppression**: Disables Windows Defender and Telemetry via `Specialize.ps1` for performance-focused images.
- **Classic UI**: Enforces the classic right-click menu and optimized visual effects to reduce "DWM" overhead.

---

## 6. Developer Notes
- **Admin Rights**: All scripts REQUIRE local Administrator privileges.
- **Pathing**: Use `$PSScriptRoot` for local script references and the `$LocalProjectRoot` variable for global configuration access.
- **Logging**: Most automation logs to `C:\Windows\Setup\Scripts\*.log` for post-boot debugging.
