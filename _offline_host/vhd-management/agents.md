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

---
**Note to Agents**: If the user reports a "generic error" in the dashboard, trace the call from `Staging_Dashboard.ps1` down to the specific script in `scripts/` and look for suppressed errors or missing `try/catch` logic.
