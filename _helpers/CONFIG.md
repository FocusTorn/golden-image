# Golden Image configuration

## Files

| File | Role |
|------|------|
| `_master_config.json` | **Source of truth** (JSONC: `//` comments, trailing commas). VM profiles live under `VMProfiles`. Host tools read **only** this (via `Get-Config -Target Host`). |
| `_offline/_offline_config.json` | Guest-side merged export from `shared` + `_offline` (plain JSON). |

## Active VM profile

Resolution order:

1. `$env:GOLDEN_IMAGE_VM_PROFILE` (e.g. `TrialVM`) — session override
2. `activeVMProfile` in master (if set)
3. `defaultVMProfile` in master
4. First entry in `VMProfiles`, or legacy top-level profile objects

Use dashboard **PD** (or `Save-DefaultVmProfileToMaster`) to persist **`defaultVMProfile`**. That also **removes** root **`activeVMProfile`** so it cannot override the saved default. Session env (PF) still wins whenever it is set.

## APIs (dot-source `ConfigUtils.ps1`)

- `Get-Config -Target Host` — merged host view from **master only** (profile + `VMFileSystem` / `VMCredentials` / shared fallbacks). What VHD scripts should use.
- `Get-Config -Target Host -VMProfileKey TrialVM` — same, forced profile.
- `Save-HostVmSettingsToMaster` — update `_master_config.json` for the active profile (VHD path, VM name, guest staging drive, creds mode). **Re-serializes** the file; JSONC `//` comments are **stripped** on save (use Git or edit by hand to preserve comments).
- `Save-DefaultVmProfileToMaster -ProfileKey TrialVM` — set **`defaultVMProfile`** in master; removes **`activeVMProfile`** if present. JSONC comments stripped on save.

## JSONC on Windows PowerShell 5.1

PowerShell 7+ parses JSONC via `System.Text.Json`. On 5.1, install Newtonsoft once:

```powershell
cd P:\Projects\golden-image\_helpers
powershell -ExecutionPolicy Bypass -File .\Install-NewtonsoftJson.ps1
```

## Provisioning templates

`_master_config.json` defines hardware/network provisioning separately from VM identity.

- `VMProvisioningTemplates` — map of template keys to provisioning values used by `New-MasterLikeVm.ps1`
- `VMProfiles.<key>.HardwareTemplate` — the default provisioning template key for that VM profile

If you pass `-ProvisioningTemplateKey` to `New-MasterLikeVm.ps1`, it overrides the profile's `HardwareTemplate`.

## New VM from profile

```powershell
cd P:\Projects\golden-image\_helpers
.\_offline_host\vhd-management\scripts\New-MasterLikeVm.ps1 -VMProfile TrialVM
```

Optional override:

```powershell
.\_offline_host\vhd-management\scripts\New-MasterLikeVm.ps1 -VMProfile TrialVM -ProvisioningTemplateKey StandardWindows
```

Creates a **new** dynamic OS VHD (does not clone a disk), optional ISO from the profile, staging VHD from merged `VhdPath` / `HostVhdPath`.

Hardware/network provisioning comes from `VMProfiles.<ProfileKey>.HardwareTemplate` by default (or `-ProvisioningTemplateKey` override).

## Staging dashboard profile actions

From `_offline_host\vhd-management\Staging_Dashboard.ps1`:

| Key | Action |
|-----|--------|
| **PL** | List profiles (keys + VM name / hostname from master) |
| **PF** | Set **session** profile via `$env:GOLDEN_IMAGE_VM_PROFILE` (this PowerShell only) |
| **PD** | Set **permanent default** profile (`defaultVMProfile` in master; clears `activeVMProfile`; env still overrides) |
| **PC** | Clear that env override |
| **PM** | Show resolution order (env, `activeVMProfile`, `defaultVMProfile`, resolved key) |
| **PV** | Create a NEW VM using the active profile for VM details + a selected provisioning template (needs admin + Hyper-V) |
| **CH** | Set Config VHD (update active profile's `VhdPath`) |
| **CV** | Set Config VM (update active profile's `VMName`) |
| **CG** | Set Config Guest drive (update `GuestStagingDrive`) |
| **CA** | Toggle Creds (`VMCredentials.UsePasswordCreds`: Password vs empty/audit) |
