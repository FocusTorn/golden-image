# VHD Management: Agent Guide

This document is for AI agents (LLMs) to understand the VHD infrastructure's architecture and operational rules.

## Core Concepts

### 1. Master Configuration (`_master_config.json`)
This is the single source of truth for all infrastructure settings.
- **VMProfiles**: Keyed sections containing VM-specific paths and names.
- **VMProvisioningTemplates**: Reusable hardware/network specs.
- **Active Profile**: The system resolves the "active" profile from environment variables (`$env:GOLDEN_IMAGE_VM_PROFILE`) or keys within the JSON.

### 2. Transitioning Logic
VHDs are managed through "transitions" (see `Invoke-VhdTransition` in `VhdUtils.ps1`).
- **Host**: Mounted locally on the host machine for file operations.
- **VM**: Attached to a Hyper-V VM for running Windows and applying customizations.

## Key Scripts

- **`Staging_Dashboard.ps1`**: The main entry point. It wraps other scripts and provides the menu-driven UI.
- **`New-MasterLikeVm.ps1`**: Creates a new Hyper-V VM from scratch using a profile and a template.
- **`New-WimFromVhd.ps1`**: Captures a `.wim` image from a prepared, sysprepped VHD.
- **`Boot-WimInNewVm.ps1`**: Takes a `.wim` and "boots" it into a new VM by applying it to a blank OS VHD.

## Operational Rules for Agents

### 1. Error Handling (Crucial)
The user has requested better error handling throughout this infrastructure.
- **Rule**: Avoid generic "Failed to..." messages. Capture and display the underlying PowerShell exception (`$_.Exception.Message` and `$_.ScriptStackTrace`).
- **Rule**: Ensure `ErrorActionPreference = 'Stop'` is used to correctly trigger `try/catch` blocks.
- **Rule**: If a script depends on an external tool (e.g., `DISM`, `OSCDIMG`), verify it exists and is in the PATH before attempting to use it.

### 2. VHD Locking
VHDs are frequently locked by either the System process (mounted) or the Hyper-V worker process (VM).
- **Rule**: When a VHD operation fails, suggest running the "Lock Diagnostics" command (`z`).
- **Rule**: Do not assume `Disconnect-VHD` or `Dismount-DiskImage` will succeed on the first attempt; they often require the "vds" service to be restarted.

### 3. Paths
- **Rule**: Use `$PSScriptRoot` for relative paths within the `scripts` folder.
- **Rule**: Use the project root (`$LocalProjectRoot`) for accessing `_master_config.json`, `_offline`, and `_helpers`.

### 4. Hyper-V
- **Rule**: Always require Administrator privileges (`#Requires -RunAsAdministrator`).
- **Rule**: Check for the existence of a VM by name before attempting creation.

### 5. Research Efficiency
- **Rule**: If investigating a JSON parsing or configuration merging issue, read `_helpers\ConfigUtils.ps1` in its entirety (or in large blocks) immediately. It contains the central logic for all configuration handling.

---

## PROJECT_PRIMER: VHD & Infrastructure Management

1. Core Stack & Architecture
   * Tech Stack: PowerShell (Admin), Hyper-V, DISM, BCDboot, Robocopy, JSONC.
   * Pattern: Orchestrated Scripting Framework. A central menu-driven dashboard delegates specialized tasks to standalone idempotent scripts.
   * Primary Orchestrator: Staging_Dashboard.ps1.
   * Transition Engine: VhdUtils.ps1 handles the movement of VHDX files between the Host (local filesystem access) and the VM (Hyper-V execution).

  2. State & Configuration
   * Source of Truth: _master_config.json (located in project root).
       * VMProfiles: Maps profile keys to specific VMName, VhdPath, and WimDestination.
       * VMProvisioningTemplates: Hardware specs (vCPU, RAM, Generation, SecureBoot).
   * Profile Resolution:
       1. $env:GOLDEN_IMAGE_VM_PROFILE (Process-level override).
       2. master.activeVMProfile (Global active state).
       3. master.defaultVMProfile (Fallback).
   * Shared Helpers: _helpers\ConfigUtils.ps1 (external) for JSON parsing and profile merging.

  3. Primary Entry Points & Data Flow
   * Staging_Dashboard.ps1: Interactive CLI. Manages lifecycle via Invoke-VhdTransition.
   * New-MasterLikeVm.ps1: Provisions new Hyper-V VMs from hardware templates.
   * New-WimFromVhd.ps1: Captures sysprepped VHDs into .wim images via DISM.
   * Boot-WimInNewVm.ps1: Validates images by applying a .wim to a blank VHD and preparing UEFI boot.
   * Flow: Get-Config -> Invoke-SmartRelease (Lock Clearing) -> Invoke-VhdTransition (Mount/Attach) -> Task Execution.

  4. Key Utilities & Logic
   * VHD Lock Mitigation (VhdUtils.ps1):
       * Invoke-SmartRelease: Force-detaches VHD from both VM and Host.
       * Kill VDS: Restarts vds (Virtual Disk Service) to resolve "In Use" errors.
       * Get-VhdLockDiagnostics.ps1: Uses handle.exe to identify process-level locks (e.g., vmwp.exe, explorer.exe).
   * Guest Communication: Uses PowerShell Direct (Invoke-Command -VMName) for script execution and log harvesting (Get-RemoteLog.ps1) without network requirements.
   * Injected Logic: Boot-WimInNewVm.ps1 injects a RunOnce registry key and a SetupDrives.ps1 script into the guest OS to persist drive letters (C, D, E) on first boot.

  5. Infrastructure Constants
   * Staging Drive: Usually mounted on Host as a free drive letter; attached to VM as a SCSI disk.
   * Sync Logic: robocopy /MIR from local _offline and installers folders to the mounted VHD.
   * Capture Path: Defaults to VMDetails.WimDestination or timestamped fallback in the VHD's directory.



---
**Note to Agents**: If the user reports a "generic error" in the dashboard, trace the call from `Staging_Dashboard.ps1` down to the specific script in `scripts/` and look for suppressed errors or missing `try/catch` logic.
