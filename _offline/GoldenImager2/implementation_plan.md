# Implementation Plan - Profile Selection & Save As

The user reported that profile selection does not update the selected apps, and requested a "Save As New" button.

## 1. Fix Profile Selection & Loading Logic
- **Issue**: Selecting "Clear Selection" does not clear the `selectedApps` set because `loadProfile` returns early if `selectedProfile` is empty.
- **Fix**: Update `loadProfile` to clear `selectedApps` when no profile is selected.
- **Issue**: Checkbox interaction is broken (clicking the icon/check doesn't toggle selection due to `stopPropagation` and missing handlers).
- **Fix**: Add `on:change` handler to the checkbox or correctly route clicks to `toggleSelect`.

## 2. Add "Save As New" Button
- **Requirement**: Add a button after Load and before Save for "Save As New".
- **Implementation**:
    - Add `Plus` icon to Lucide imports.
    - Insert a `BloomControl` button in the `profile-group` segmented control.
    - Button will trigger `showSaveModal = true` and reset `saveName` if needed.

## 3. Verify Reactive Consistency
- Ensure `selectedApps` reassignment in `loadProfile` correctly triggers UI updates in the `{#each}` loop.

## Proposed Changes

### src/lib/Apps.svelte
- Add `Plus` to Lucide imports.
- Update `loadProfile` logic.
- Update `selectProfile` to be more robust.
- Add "Save As" button to the toolbar.
- Fix checkbox `on:change` or `on:click` handling.

### src-tauri/src/apps.rs
- (Optional) Verify if any backend matching improvements are needed, though the JS logic handles local matching.

---
Next steps: Implement the changes in `Apps.svelte`.
