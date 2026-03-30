# Implementation Plan - Fix App Profile Loading

The user reported that apps from a selected profile are not loaded when hitting the "Load" button. My investigation suggests the matching logic between profile IDs (which may contain specific versions) and system IDs is too strict, causing matches to fail when versions differ.

## Proposed Changes

### 1. `Apps.svelte`

- **Robust Matching Logic**: Update `loadProfile` to compare "Base IDs" (the part before the first underscore) for Appx packages. This ensures that an app like `Microsoft.WindowsAlarms_1.2.3_...` in a profile can still match `Microsoft.WindowsAlarms_2.0.0_...` on the system.
- **Improved Casing & Fallbacks**: Ensure case-insensitive matching across `AppId` and `FriendlyName`.
- **Diagnostic Logging**: Add `console.log` statements in `loadProfile` to capture:
    - Number of IDs found in the profile.
    - Number of successful matches found in the system inventory.
    - Any errors during the Tauri invocation.
- **Reactivity Check**: Ensure `selectedApps` is reassigned effectively to trigger Svelte's UI updates.

## Verification Plan

### Automated Validation
- Run `cargo check` to ensure backend integrity (though backend was not modified, good practice after investigation).
- Mental validation of the JS matching logic against the Appx ID format (`Name_Version_Arch_Hash`).

### Manual Verification (User)
- Select a profile from the dropdown (e.g., `Apps-General`).
- Verify if apps auto-load (due to `selectProfile` calling `loadProfile`).
- Manually change some selections, then hit the "Load" (Download icon) button.
- Verify if the original profile selections are restored.
