# VHD & Infrastructure Management

This directory contains the core automation for managing the Virtual Hard Disk (VHD) infrastructure used for Windows Golden Image creation. It provides a "Staging Dashboard" that orchestrates VHD mounting, VM creation, and imaging tasks.

## Components

- **`Staging_Dashboard.ps1`**: The primary interactive CLI for managing the imaging lifecycle.
- **`scripts/`**: Supporting PowerShell scripts for specific infrastructure tasks.

## Key Workflows

### 1. VHD Lifecycle
- **Syncing**: Copying the `_offline` customization folder and installers into the VHD.
- **Mount Control**: Moving the VHD between the Host (for file access) and the VM (for execution).
- **Imaging**: Capturing a `.wim` image from a prepared VHD.

### 2. VM Management
- **Profile-based Creation**: Creating new VMs based on profiles defined in `_master_config.json`.
- **WIM Booting**: Applying a captured `.wim` to a new VM for validation.
- **Provisioning**: Hardware and network templates for consistent VM environments.

### 3. Debugging & Diagnostics
- **Lock Diagnostics**: Identifying processes holding a lock on a VHD file.
- **Remote Logging**: Pulling logs from the VM via PowerShell Direct.

## Usage

Run the dashboard from an Administrator PowerShell prompt:
```powershell
.\Staging_Dashboard.ps1
```

## Profiles and Templates
The system relies on `_master_config.json` (located in the project root) for:
- **VMProfiles**: Defines VM names, hostnames, and VHD paths.
- **VMProvisioningTemplates**: Defines hardware specs (vCPU, RAM, Generation, etc.).
