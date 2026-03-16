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

The project uses a **Foundation + Overlay** layout:

- **Foundation** — Upstream source from the original project. Read-only; do not edit.
- **Overlay** — Customizations live alongside Foundation, in sibling folders at the project root.

### Overlay pattern

Files in Foundation are the canonical source. To customize:

1. Create a **sibling folder** at the project root with the same relative path as in Foundation.
2. Place your override files there with the same names.
3. The entry script loads overlays when they exist, falling back to Foundation otherwise.

The overlay layout mirrors Foundation:

```
ProjectRoot/
├── Foundation/           # Upstream (do not edit)
│   ├── Config/
│   ├── Schemas/
│   ├── Scripts/
│   └── ...
├── Config/                # Overlay: user config, profiles
├── Schemas/               # Overlay: XAML UI definitions
├── Scripts/               # Overlay: PowerShell logic
├── Logs/
└── EntryScript.ps1
```

### What goes in the overlay

| Overlay folder | Purpose | Contents |
|----------------|---------|----------|
| **Config/** | User data, runtime config | App profiles, tweak profiles, options, window bounds |
| **Schemas/** | UI layout | XAML schemas that override Foundation equivalents |
| **Scripts/** | GUI logic | PowerShell scripts that override Foundation equivalents |
| **Logs/** | Runtime output | Transcript and run logs |

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

1. Replace Foundation with the new upstream version.
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

1. Ensure `Foundation` is present (e.g. from `Prepare_Debloat_Tools.ps1` or manual extraction).
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
