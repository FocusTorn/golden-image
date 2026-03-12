# Detailed App Analysis (Categorized with Purpose) - FULL SYSTEM SCAN
*Generated on February 27, 2026*

## 🟢 Category: SYSTEM INFRASTRUCTURE (Do Not Touch)
*These power the core of Windows. Removing these will break the UI, networking, or security.*

| Name | Purpose |
| :--- | :--- |
| `Microsoft.AAD.BrokerPlugin` | Handles work/school account logins and Office 365 auth. |
| `Microsoft.AccountsControl` | Manages the "Accounts" page in Settings and user switching. |
| `Microsoft.AsyncTextService` | Critical for typing, input methods, and emojis. |
| `Microsoft.BioEnrollment` | Powers Windows Hello (Fingerprint, Face ID, PIN). |
| `Microsoft.CredDialogHost` | Pop-up that asks for your password/PIN for admin actions. |
| `Microsoft.LockApp` | Powers the Windows Lock Screen and login wallpaper. |
| `Microsoft.NET.Native.*` | Engines that allow modern apps to run. |
| `Microsoft.UI.Xaml.*` | The "Design Engine" for Windows 11's modern look. |
| `Microsoft.VCLibs.*` | C++ Libraries required by almost every app on the PC. |
| `Microsoft.Win32WebViewHost` | Allows apps to show web content (like a login screen). |
| `Microsoft.Windows.CloudExperienceHost` | Powers the "Out of Box" setup and account linking. |
| `Microsoft.Windows.ShellExperienceHost` | **The Taskbar, Start Menu, and Clock.** |
| `Microsoft.Windows.StartMenuExperienceHost` | Specifically handles the Start Menu search and layout. |
| `windows.immersivecontrolpanel` | **The "Settings" App.** |
| `Microsoft.WinAppRuntime.*` | Modern application framework (WinUI 3). |
| `Microsoft.WindowsAppRuntime.*` | Core runtime for modern Windows apps. |
| `Microsoft.Winget.Source` | Infrastructure for the Windows Package Manager. |
| `MicrosoftWindows.Client.*` | Core Windows 11 client components (Explorer, OOBE, etc.). |

---

## 🟢 Category: ESSENTIAL UTILITIES (Keep)
*Small tools that define a "complete" OS.*

| Name | Purpose |
| :--- | :--- |
| `Microsoft.DesktopAppInstaller` | **WINGET.** Allows command-line software installation. |
| `Microsoft.WindowsCalculator` | Basic math utility. |
| `Microsoft.WindowsNotepad` | Basic text editing. |
| `Microsoft.WindowsTerminal` | The modern command line (highly recommended). |
| `Microsoft.Paint` / `Microsoft.ScreenSketch` | Drawing and the "Snipping Tool" for screenshots. |
| `Microsoft.SecHealthUI` | The window where you control Windows Defender/Antivirus. |
| `Microsoft.WindowsStore` | How you update these apps or get new ones. |
| `Microsoft.StorePurchaseApp` | Engine that allows the Store to actually buy/download things. |

---

## 🟢 Category: HARDWARE & DRIVERS (Keep)
*Specific to your ASUS motherboard and hardware.*

| Name | Purpose |
| :--- | :--- |
| `B9ECED6F.ASUSPCAssistant` | ASUS-specific motherboard/laptop utility. |
| `NVIDIACorp.NVIDIAControlPanel` | Controls your Graphics Card settings. |
| `RealtekSemiconductorCorp.RealtekAudioControl` | Controls your Sound Card and headphone jack. |

---

## 🔴 Category: SAFE TO THIN (Bloat)
*Apps you can remove to make the image "Thin."*

| Name | Purpose |
| :--- | :--- |
| `Clipchamp.Clipchamp` | Video editor. |
| `Microsoft.BingSearch` | Bing integration in the Start menu. |
| `Microsoft.BingWeather` | The weather app. |
| `Microsoft.GamingApp` | The main Xbox/Game Pass app. |
| `Microsoft.GetHelp` | Redirects you to Microsoft websites for support. |
| `Microsoft.MicrosoftSolitaireCollection` | Cards and games. |
| `Microsoft.MicrosoftStickyNotes` | Virtual post-it notes. |
| `Microsoft.PowerAutomateDesktop` | Automation tool for office tasks. |
| `Microsoft.Windows.DevHome` | Dashboard for coders. |
| `Microsoft.ZuneMusic` / `ZuneVideo` | Legacy Media Player apps. |
| `MSTeams` | The "Chat" button on the taskbar. |
| `Microsoft.Windows.ContentDeliveryManager` | **Powers "Suggested Apps" and Ads in the Start Menu.** |
| `Microsoft.Windows.ParentalControls` | Screen time and content filtering. |
| `Microsoft.Windows.SecureAssessmentBrowser` | "Take a Test" mode for education. |
| `Microsoft.WindowsFeedbackHub` | Send bugs/complaints to Microsoft. |
| `Microsoft.Windows.AugLoop.CBS` | Microsoft AI/Search loop metadata. |
| `Microsoft.WidgetsPlatformRuntime` | The "Widgets" board (news/weather slide-out). |
| `Microsoft.Windows.NarratorQuickStart` | Tutorial for the Narrator (safe to remove if you don't use it). |

---

## 🧩 Category: DEVELOPER / OPTIONAL
| Name | Purpose |
| :--- | :--- |
| `MicrosoftCorporationII.WindowsSubsystemForLinux` | **WSL.** Runs Linux distros inside Windows. Keep if you are a coder. |
| `Microsoft.Windows.DevHome` | Developer environment setup tool. |
| `Microsoft.MicrosoftEdgeDevToolsClient` | Developer tools for Edge/Webview apps. |
