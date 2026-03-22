# Golden Imager: Agent Guide

This document is for AI agents (LLMs) to understand the architecture and operational constraints of the Golden Imager project. Follow these rules to maintain project integrity.

## Core Architecture: The Overlay Pattern

Golden Imager is built as a **non-destructive overlay** on an upstream project (Win11Debloat).

### 1. Foundation (Upstream)
- **Path**: `Foundation/Win11Debloat/`
- **Rule**: **NEVER** modify files in this directory. It is treated as a read-only dependency.
- **Purpose**: Allows for easy upstream updates by simply replacing this folder.

### 2. Overlay (Customizations)
- **Path**: Project Root (`/`)
- **Rule**: All project-specific logic, UI changes, and configurations must live here.
- **Mechanism**: The entry script `GoldenImager.ps1` orchestrates the loading of both layers.

## Implementation Details for Agents

### Dot-Sourcing Pattern
When modifying or adding logic, identify if the function exists in `Foundation/Scripts/`.
- To override: Create a matching path in `Scripts/` (root) and ensure `GoldenImager.ps1` dot-sources it from `$PSScriptRoot`.
- To use upstream: Ensure `GoldenImager.ps1` dot-sources it from `$script:SourceRoot`.

Example from `GoldenImager.ps1`:
```powershell
# OVERRIDE: Uses our custom offline-first logic
. "$PSScriptRoot/Scripts/AppRemoval/RemoveApps.ps1"

# UPSTREAM: Uses original logic for Edge removal
. "$script:SourceRoot/Scripts/AppRemoval/ForceRemoveEdge.ps1"
```

### UI & Schemas
- The main window is overridden via `$script:MainWindowSchema = Join-Path $PSScriptRoot "Schemas/MainWindow.xaml"`.
- Other windows might still use `$script:SourceRoot/Schemas/...`. Check `GoldenImager.ps1` variables before suggesting UI changes.

### Config & Data
- `Config/Apps.json` (root) overrides `Foundation/Config/Apps.json` in specific logic (`LoadAppsDetailsFromJson.ps1`).
- App and Tweak profiles always live in the root `Config/AppProfiles/` and `Config/TweakProfiles/`.

## Critical Operational Constraints

### 1. Offline-First (No WinGet)
Golden Imager is primarily used in **Windows Audit Mode** or **Offline WinPE** environments where internet access is unavailable.
- **Constraint**: Do not introduce dependencies on `winget`, `Invoke-WebRequest`, or any network-based tools in the core `AppRemoval` or `Features` logic.
- **Fallback**: Always use `Get-AppxPackage`, `Remove-AppxPackage`, and `DISM` commands.

### 2. Three-State UI
The overlay supports a three-state selection for tweaks:
1. **Apply (Checked)**: Feature will be enabled/applied.
2. **Skip (Unchecked)**: Feature will be ignored.
3. **Revert (Indeterminate)**: Feature will be explicitly undone/reverted using `ImportRegistryFileForRevert`.

### 3. Sysprep & Default User
When applying changes with the `-Sysprep` switch:
- Targets the **Default User Profile** registry hive and filesystem.
- Uses `Load-RegistryHive` (if available) or targets `C:\Users\Default`.

## How to add a new Tweak
1. Add the registry `.reg` file to `Foundation/Regfiles` (if it's a general tweak) or a project-specific location.
2. Update `Foundation/Config/Features.json` (or our overlay config if implemented).
3. If special logic is needed, add it to `ExecuteParameter` in `GoldenImager.ps1` or a dedicated script in `Scripts/Features/`.

## How to add a new App for removal
1. Add the package name/pattern to `Config/Apps.json` (root).
2. Ensure `Scripts/FileIO/LoadAppsDetailsFromJson.ps1` correctly parses and merges the lists.

---
**Note to Agents**: If you are asked to "fix" something in `Foundation/`, you must instead create an override in the root `Scripts/` or `Schemas/` folder and update the entry script to point to your new version.
