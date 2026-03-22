# Golden Imager

A PowerShell GUI for Windows optimization and debloating, built as an overlay on an upstream foundation. Removes bloatware, disables telemetry, applies system tweaks, and supports app/tweak profiles for repeatable deployments.

## Table of Contents

- [Overview](#overview)
- [Architecture: Foundation + Overlay](#architecture-foundation--overlay)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Development](#development)
- [License](#license)

## Overview

Golden Imager provides:

- **App removal** — Select apps to remove with profiles, default preset, and "installed only" filtering
- **System tweaks** — Registry-based UI customization (taskbar, search, privacy, etc.)
- **Deployment options** — Apply to current user, other user, or default user (Sysprep)
- **Profiles** — Save and load app/tweak selections for reuse across images

## Architecture: Foundation + Overlay

The project uses a **Foundation + Overlay** layout to allow customization while keeping the upstream source (Foundation) pristine.

- **Foundation** — Upstream source from the original project (Win11Debloat). Read-only; do not edit. Located in `Foundation/Win11Debloat`.
- **Overlay** — Customizations live in the project root, mirroring the Foundation structure.

### Overlay pattern

The entry script `GoldenImager.ps1` manages the loading of these two layers. It explicitly defines which components are loaded from the overlay and which fall back to Foundation.

```powershell
# Foundation is loaded from a subfolder
$script:SourceRoot = Join-Path $PSScriptRoot 'Foundation/Win11Debloat'

# Overlays are explicitly dot-sourced from the root Scripts/ folder
. "$PSScriptRoot/Scripts/AppRemoval/RemoveApps.ps1"

# Fallbacks use the SourceRoot (Foundation)
. "$script:SourceRoot/Scripts/AppRemoval/ForceRemoveEdge.ps1"
```

The overlay layout mirrors Foundation:

```
GoldenImager/
├── Foundation/           # Upstream (do not edit)
│   ├── Win11Debloat/     # Upstream Win11Debloat source
│   │   ├── Config/
│   │   ├── Regfiles/
│   │   ├── Schemas/
│   │   └── Scripts/
│   └── CTT/              # Upstream Chris Titus Tweaks source (planned)
├── Config/               # Overlay: custom profiles, overrides
├── Schemas/              # Overlay: custom XAML (e.g., MainWindow)
├── Scripts/              # Overlay: custom logic (e.g., offline AppRemoval)
├── Logs/                 # Runtime output
└── GoldenImager.ps1      # Entry script and layer orchestrator
```

### What goes in the overlay

| Overlay folder | Purpose | Implementation |
|----------------|---------|----------------|
| **Config/** | User data, profiles | Referenced by `$PSScriptRoot/Config` |
| **Schemas/** | UI layout | Overrides specific Foundation XAML files |
| **Scripts/** | GUI logic | Dot-sourced in `GoldenImager.ps1` to override functions |
| **Logs/** | Runtime output | Transcript and run logs |

### Key Customizations in Golden Imager

- **Offline App Removal**: Uses a custom `RemoveApps.ps1` that doesn't depend on WinGet or network access, making it safe for Audit Mode and offline imaging.
- **Three-State UI**: Supports "Revert" logic for tweaks (Apply, Skip, Revert).
- **Profile Support**: Dedicated UI and logic for saving/loading app and tweak profiles.
- **Typography & Branding**: Custom UI themes and typography defined in the entry script.

### Schema overlays

XAML schemas in the overlay override Foundation schemas with the same path. Use them to:

- Change layout, tabs, or controls
- Add new UI (e.g. profile selectors)
- Adjust styling or branding

### Script overlays

PowerShell scripts in the overlay override Foundation scripts with the same path. Use them to:

- Change behavior or add features
- Wire new UI controls
- Integrate with other tooling

### Foundation updates

When Foundation is updated:

1. Replace contents of `Foundation/Win11Debloat` with the new upstream version.
2. Keep overlay folders unchanged.
3. Resolve any conflicts if Foundation structure changed.
4. Re-test overlays and adjust if needed.

## Prerequisites

- Windows 10/11
- PowerShell 5.1 or later
- Administrator rights

## Offline / Sysprep

Golden Imager is designed for **offline audit mode** and **Sysprep** deployment. It does not rely on WinGet or any network:

- **App removal** — The overlay `Scripts/AppRemoval/RemoveApps.ps1` uses `Remove-AppxPackage` and `Remove-ProvisionedAppxPackage` only. Edge and OneDrive are removed the same way as other apps (no WinGet, no RunOnce tasks that require network).
- **Installed apps list** — Falls back to `Get-AppxPackage` when WinGet is unavailable.
- **Do not use** `Get.ps1` (GitHub download) in offline environments.

## Installation

1. Ensure `Foundation/Win11Debloat` is present (e.g. from `Prepare_Debloat_Tools.ps1` or manual extraction).
2. Run the entry script as Administrator:
   ```powershell
   .\GoldenImager.ps1
   ```
3. Or use the launcher batch file if it exists in the parent folder.

## Usage

### GUI

- **App Removal** — Select apps, use profiles or defaults, apply.
- **Tweaks** — Apply registry tweaks, use profiles or defaults.
- **Deployment** — Choose target user, options, then apply changes.

### Profiles

- **Default** — Built-in preset from Foundation config.
- **Custom** — Save current selection and load it later.

### CLI

The entry script supports the same CLI parameters as the original Foundation script for automation and scripting.

## Configuration

| Location | Purpose |
|---------|---------|
| `Config/Options.json` | App-level options (e.g. hide launcher) |
| `Config/WindowBounds.json` | Window position/size |
| `Config/AppProfiles/` | Saved app selection profiles |
| `Config/TweakProfiles/` | Saved tweak selection profiles |

## Development

### Adding a new overlay

1. Identify the Foundation path you want to override.
2. Create the matching folder at the project root.
3. Add your override file with the same name.
4. Ensure the entry script loads it (e.g. via `$SourceRoot` or explicit path variables).

### Modifying behavior

- **UI changes** — Use schema overlays.
- **Logic changes** — Use script overlays.
- **Data changes** — Add or edit config in `Config/`.

### Testing

- Run the entry script and verify overlays load correctly.
- Test profile save/load and default presets.
- Confirm Foundation updates do not break overlays.

## License

See the Foundation project for license and attribution. Golden Imager overlays follow the same license as the parent project.

## Acknowledgments

- Foundation: [Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat)
- Part of the golden-image project for Windows deployment and imaging.
