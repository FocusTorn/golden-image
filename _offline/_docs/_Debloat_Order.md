Here is the Golden Order of Operations optimized for stability and Sysprep safety.

  ⚠️ The Golden Rule of Sysprep
  NEVER remove the following apps, or Sysprep will crash:
   1. Microsoft Store (Microsoft.WindowsStore)
   2. App Installer / Winget (Microsoft.DesktopAppInstaller)
   3. Windows Security (Microsoft.SecHealthUI)
   4. Content Delivery Manager (Sometimes removing this breaks OOBE)

  ---

  The Workflow Protocol

  Run them in this exact order. We start with surgical removal (AppBuster), move to system configuration (Titus), and finish with privacy policies (ShutUp10).

  1. O&O AppBuster (Surgical Clean)
  Why First: Remove the garbage before you try to tweak it.
  Action: Launch AppBuster from the Dashboard (Option 5 -> 4).
  Target: Select "Machine" (Local Machine) view, not just "Current User".

   * ✅ SAFE TO REMOVE (Bloat):
       * Microsoft To Do
       * Microsoft Solitaire Collection
       * Microsoft Tips
       * Microsoft Family
       * Weather, Maps, News
       * Feedback Hub
       * Xbox Console Companion (Keep "Xbox Identity Provider" and "Game Bar" if you want gaming support)
       * Clipchamp
       * Mail and Calendar (Outlook is replacing this)
       * Your Phone / Phone Link

   * ❌ DO NOT TOUCH (System Critical):
       * Store, App Installer, Windows Security.
       * Calculator & Photos (Keep these. Windows feels "broken" to users without them).

  2. Titus WinUtil (System & Services)
  Why Second: Configures how the remaining OS behaves.
  Action: Launch WinUtil from the Dashboard (Option 5 -> 1).
  Tab: Go to the Tweaks tab.

   * ✅ ENABLE (Safe):
       * Essential Tweaks: (Creates restore point, disables telemetry, disables WiFi Sense).
       * Disable Consumer Features: (Stops auto-installing Candy Crush).
       * Show File Extensions: (Essential for IT).
       * Dark Mode / Light Mode: (Set your preference).
       * Set Display to Performance: (Optional, turns off animations).

   * ❌ AVOID (Sysprep Risks):
       * Remove Microsoft Edge: NEVER do this. It breaks OOBE and WebViews.
       * Disable Windows Update: Leave this enabled. Sysprep needs to check update status.
       * Remove Store: (See Golden Rule).

  3. Raphire Win11Debloat (UI & UX Polish)
  Why Third: Cleans up the visual clutter left behind.
  Action: Launch Win11Debloat from the Dashboard (Option 5 -> 2).

   * Settings:
       * Choose "Default" mode.
       * It effectively disables Bing Search in the Start Menu and removes the "Chat" icon, which are often stubborn.
       * "Custom" is too risky for a Golden Image unless you test every checkbox.

  4. O&O ShutUp10++ (Privacy Policy)
  Why Last: Locks down the configuration with Registry Policies.
  Action: Launch ShutUp10 from the Dashboard (Option 5 -> 3).

   * The Strategy:
       * Go to Actions -> Apply only recommended settings (Green checks).
       * Do NOT apply "Somewhat recommended" (Yellow) or "Limited" (Red).
       * Reason: The Yellow/Red settings often disable Windows Update or User Account Control (UAC). If UAC is disabled, Sysprep cannot run, and Metro apps (Calculator) will fail to    
         launch.

  ---

  Summary Checklist

   1. AppBuster: Kill Clipchamp, Solitaire, Tips, Family, ToDo. Keep Store, Winget, Defender.
   2. Titus: Apply "Essential Tweaks" & "Disable Consumer Features". Keep Edge.
   3. Raphire: Run "Default" to kill Bing Search/Chat.
   4. ShutUp10: Apply "Green/Recommended" only.