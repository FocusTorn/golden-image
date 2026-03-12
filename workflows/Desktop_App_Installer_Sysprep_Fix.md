# Desktop App Installer (WinGet) — Sysprep "Exists but Not Provisioned" and No Way to Repair

## The problem

When building a golden image, Sysprep can fail with:

- **Error:** `Package Microsoft.DesktopAppInstaller_* was installed for a user, but not provisioned for all users`
- **Error:** `Failed to remove apps for the current user: 0x80073cf2`

**Microsoft.DesktopAppInstaller** is the App Installer / WinGet backend. If it ends up installed for the current user but **not** in the provisioned-app list, Sysprep’s cleanup step tries to remove it and fails. At that point the package is in a bad state: normal uninstall and repair often don’t work.

## Why it gets into this state

- WinGet or App Installer was used (or updated) in a context where it registered as **per-user** instead of **provisioned for all users**.
- Windows Update or Microsoft Store updated the app for the current user only.
- You removed or changed provisioning (e.g. deprovisioned something) so the system and user state no longer match.

Once that happens, the package is “user-installed but not provisioned.” Sysprep then fails with 0x80073cf2 when it tries to clean it up.

## Why repair usually fails

Standard fixes assume you can:

1. Remove the package for the user: `Remove-AppxPackage -Package <packagefullname>`
2. Remove provisioning: `Remove-AppxProvisionedPackage -Online -PackageName <packagefullname>`

For **Microsoft.DesktopAppInstaller**, one or both of these often fail (access denied, package in use, or “can’t be removed”). There is no supported, reliable in-place repair when it’s stuck in this state. Many people hit this and find that **the only reliable fix is to rebuild the image**.

## Reliable fix: prevent it (Audit Mode workflow)

The only dependable approach is to **never** get into the bad state:

1. **Do all golden-image customization in Audit Mode.**  
   Boot into Audit Mode (or stay in it from install). Do **not** go through OOBE and create a normal user profile before you’re done installing and configuring.

2. **Use a single built-in Administrator account** for installing apps and running WinGet.  
   Avoid using a non-admin or a second user so you don’t get per-user App Installer registration.

3. **Install WinGet apps machine-wide:**  
   Always use `winget install ... --scope machine` (or equivalent) so packages are provisioned for the image, not just the current user.

4. **Before Sysprep:**  
   - Disconnect the network so Store/Windows Update don’t update App Installer (or other apps) at the last moment.  
   - Run **Sysprep_Dry_Run.ps1** to catch Desktop App Installer (and other “user-only, not provisioned”) issues **before** you run Sysprep.

If you do all of this, Desktop App Installer stays provisioned and Sysprep can complete.

## If you’re already stuck

If the dry run (or a failed Sysprep) shows **Microsoft.DesktopAppInstaller** as “user-installed but not provisioned”:

- You can still **try** the Microsoft steps (remove for user, then remove provisioned) once, per user that has it installed.  
- If that fails (as it often does for this package), **do not** keep trying random removal/repair; it usually doesn’t work and wastes time.

**Practical option:** Rebuild the reference image and follow the Audit Mode workflow above. Use a clean install, stay in Audit Mode, install everything with `--scope machine`, then run the dry run and Sysprep. That’s the only way to guarantee you won’t hit the “exists but not provisioned with no way to repair” state again.

## Summary

| Situation | What to do |
|----------|------------|
| **Prevention** | Build image in Audit Mode; use `winget install --scope machine`; disconnect network before Sysprep; run `Sysprep_Dry_Run.ps1` first. |
| **Dry run shows Desktop App Installer as killer** | Treat as unfixable; plan to rebuild using the Audit Mode workflow. |
| **Sysprep already failed with 0x80073cf2 on DesktopAppInstaller** | Try Microsoft’s remove-per-user then remove-provisioned once; if it fails, rebuild the image in Audit Mode. |
