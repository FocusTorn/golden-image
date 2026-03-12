# App Removal Cheat Sheet (2026 Edition)

## 🟢 KEEP (Critical Infrastructure)
*   `Microsoft.WindowsStore` / `StorePurchaseApp` (Your way to get apps back)
*   `Microsoft.DesktopAppInstaller` (This is `winget`)
*   `Microsoft.SecHealthUI` (Windows Defender Interface)
*   `Microsoft.WindowsCalculator` / `Microsoft.WindowsNotepad`
*   `Microsoft.WindowsTerminal`
*   `WinAppRuntime` / `Framework` / `DDLM` (System engines - do not touch)
*   `AV1` / `HEVC` / `VP9` / `MPEG2` (Video Codecs)
*   `HEIF` / `Webp` / `RawImage` (Image Codecs)
*   `NVIDIACorp` / `Realtek` (Hardware controls)

## 🟡 OPTIONAL (User Preference)
*   `Microsoft.Paint` / `Microsoft.ScreenSketch` (Snipping Tool)
*   `Microsoft.WindowsCamera` / `Microsoft.WindowsAlarms`
*   `Microsoft.MicrosoftStickyNotes`
*   `Microsoft.Windows.DevHome` (Useful for devs, bloat for others)
*   `MicrosoftWindows.CrossDevice` (Phone Link)

## 🔴 REMOVE (Safe Bloat)
*   `Clipchamp`
*   `BingSearch` / `BingWeather`
*   `Microsoft.GamingApp` / `Xbox` (Unless you game)
*   `Microsoft.MicrosoftSolitaireCollection`
*   `Microsoft.PowerAutomateDesktop`
*   `Microsoft.ZuneMusic` / `ZuneVideo` (The old Media Player)
*   `MSTeams` (Usually the personal version)
*   `Microsoft.GetHelp` / `Microsoft.WindowsFeedbackHub`
