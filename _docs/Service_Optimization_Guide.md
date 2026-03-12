# Windows Service Optimization Guide (Golden Image)

Selecting **"Set Services to Manual"** in WinUtil applies these changes to your master image. If a feature seems "broken" after deployment, check these services first.

## 🛠️ Performance Enhancements (Set to Manual)
| Service Name | Description | If Disabled/Manual... |
| :--- | :--- | :--- |
| `WSearch` | Windows Search Indexer | Search is slower at first; less disk usage. |
| `SysMain` | Superfetch / Prefetch | Slower app launches; much less disk usage. |
| `Spooler` | Print Spooler | Printers won't show until service is started. |
| `BITS` | Background Intelligent Transfer | Windows Updates only download when requested. |
| `ShellHWDetection` | AutoPlay / Hardware Detection | Windows won't "Pop Up" when you plug in a USB. |

## 🔒 Privacy & Bloat (Set to Disabled)
| Service Name | Description | Status |
| :--- | :--- | :--- |
| `DiagTrack` | Telemetry / Tracking | **Disabled** (Stops data sharing) |
| `RemoteRegistry` | Remote Registry Access | **Disabled** (Improves Security) |
| `MapsBroker` | Offline Maps Manager | **Disabled** (Saves RAM) |
| `XblAuthManager` | Xbox Live Auth | **Disabled** (Only enable for gamers) |

## 🤖 AI & Modern Features (Set to Disabled)
*   **Copilot / Recall Stubs:** Background monitoring services for AI are disabled to save CPU cycles.
*   **Push Notifications:** Background notification "listeners" are set to manual to stop "Suggestions."

---

### **How to revert a service:**
If you realize you NEED a service to be automatic again (e.g., you are a heavy Xbox gamer):
1.  Press `Win + R`, type `services.msc`.
2.  Find the service (e.g., `Xbox Live Auth Manager`).
3.  Right-click -> Properties -> Set Startup Type to **Automatic**.
