# WinPE: Put it on a USB and boot from it

This doc explains **how to build** Windows PE (WinPE) onto a **USB flash drive** and **how to boot** a PC from it. Use it with `_docs/UEFI_WIM_Deployment.md` and `_docs/WinPE_Commands_Cheat_Sheet.txt`.

---

## 1. What you need

| Requirement | Notes |
|-------------|--------|
| **Windows PC** (64-bit) | To run the ADK tools. |
| **Windows Assessment and Deployment Kit (ADK)** | Download from Microsoft for your **target OS wave** (e.g. Windows 11 24H2 ADK for current Win11 images). |
| **Windows PE add-on** | Separate download **matching the same ADK version** — install **after** the ADK. Without it, `copype` / `MakeWinPEMedia` are missing. |
| **USB flash drive** | **8 GB+** recommended if you’ll copy large `.wim` files onto it; **will be erased** when using `/UFD`. |

### Rufus — do you still need other downloads?

**Rufus only writes (flashes) an ISO to USB.** It does **not** replace:

- **Building custom WinPE** — you still need the **Windows ADK** + **WinPE add-on** to run `copype` / `MakeWinPEMedia`, **unless** you use a WinPE `.iso` you already built or obtained elsewhere.
- **The image you flash** — you must **download or build** that separately, e.g.:
  - **`MakeWinPEMedia /ISO …`** output → point **Rufus** at that `.iso` (good if you prefer Rufus over `MakeWinPEMedia /UFD`).
  - **Windows 11** official **ISO** from Microsoft → Rufus can create installer/repair media (see `_docs/Windows11_Rescue_USB_Recommendations.md`).

So: **having Rufus does not remove the need for ADK** if your workflow is “build my own WinPE.” It **does** mean you can skip `MakeWinPEMedia /UFD` and instead flash the **WinPE ISO** with Rufus.

---

## 2. Install ADK + WinPE add-on

1. Run the **ADK setup** → choose at least **Deployment Tools** (includes Deployment and Imaging Tools Environment).
2. Run the **Windows PE add-on** installer for the **same** ADK build.
3. Open **Start** → **Windows Kits** → **Deployment and Imaging Tools Environment** (run **as Administrator**).

All `copype` / `MakeWinPEMedia` commands below run in **that** shell (not plain PowerShell unless you’ve added paths manually).

---

## 3. Build WinPE and write it to USB (typical flow)

### 3.1 Create a working folder (staging)

From **Deployment and Imaging Tools Environment**:

```cmd
copype amd64 C:\WinPE_amd64
```

- **`amd64`** = 64-bit WinPE (use for UEFI and modern PCs).
- This copies WinPE files into `C:\WinPE_amd64` (change path if you prefer).

### 3.2 (Optional) Customize before USB

Examples (only if you need them):

- Add drivers: `Dism /Add-Driver /Image:C:\WinPE_amd64\media\sources\boot.wim ...`
- Add scripts: edit or add `C:\WinPE_amd64\media\Startnet.cmd` to run `diskpart`, `wpeinit`, map network drives, etc.

For basic imaging, the default WinPE from `copype` is often enough.

### 3.3 Create a **bootable USB** (erases the USB)

1. Plug in the USB. Note the drive letter (e.g. `E:`).
2. Run:

```cmd
MakeWinPEMedia /UFD C:\WinPE_amd64 E:
```

- **`/UFD`** = USB Flash Drive.
- **This formats the USB** — all data on that drive is lost.
- If the tool warns about multiple removable drives, **remove other USB disks** and confirm the correct letter.

When it finishes, the USB contains bootable WinPE.

### 3.4 Put your `.wim` (and tools) on the same USB (optional)

After the USB is built, you can **copy** files to it in Explorer:

- e.g. `\Images\Golden.wim` — then in WinPE: `Dism /Apply-Image /ImageFile:E:\Images\Golden.wim ...` (drive letter in WinPE may differ — use `diskpart` → `list vol`).

If the WIM is huge, use a **second USB**, a **network share**, or an **external SSD** instead.

---

## 4. Alternative: ISO instead of USB

To boot from a **virtual DVD** in a VM or burn a disc:

```cmd
MakeWinPEMedia /ISO C:\WinPE_amd64 C:\WinPE_amd64\WinPE.iso
```

Mount the ISO in Hyper-V / VMware, or use Rufus to write the ISO to USB later.

---

## 5. How to **boot** WinPE from the USB

### 5.1 Firmware: UEFI vs Legacy

- **UEFI** (recommended for this repo’s UEFI guides): In firmware setup, enable **UEFI boot** and often **USB boot**.
- **Legacy/CSM**: Older “BIOS” mode — only if your deployment targets that; WinPE still works but partition layout differs.

### 5.2 One-time boot menu (most common)

1. **Shut down** the PC (or restart).
2. Plug in the WinPE USB **before** power-on.
3. Power on and open the **boot menu** (key varies by OEM):

   | OEM / type | Common keys |
   |------------|-------------|
   | Dell | F12 |
   | HP | F9 or Esc |
   | Lenovo | F12, F10, or Fn + F12 |
   | ASUS | F8 or Esc |
   | Generic | Esc, F11, F12 |

4. Choose the USB entry:
   - **UEFI: … USB** (vendor name) — use this for GPT/UEFI imaging.
   - **USB** / legacy — avoid for pure UEFI workflows unless you know you need it.

### 5.3 Boot order in BIOS/UEFI setup

If the menu doesn’t list USB:

- Enter **BIOS/UEFI Setup** (often **Del**, **F2**, **F10** at startup).
- **Boot** tab → put **USB** / **Removable** **above** the internal disk (or use “Boot Override” if available).
- **Save** and exit.

### 5.4 Secure Boot

- **Stock** Microsoft WinPE from ADK is usually **signed** and boots with **Secure Boot** enabled.
- If you **customize** WinPE (unsigned drivers/scripts don’t usually break SB; bad boot.wim edits might), and the PC **refuses** to boot the USB, try **temporarily disabling Secure Boot** in firmware, boot WinPE, finish your work, then re-enable Secure Boot.

---

## 6. What you should see after boot

- A **command prompt** (often `X:\` is WinPE’s RAM drive).
- Run:

  ```cmd
  diskpart
  list vol
  exit
  ```

  to see drive letters for your disks and USB.

- **`wpeinit`** may run automatically; if networking matters, WinPE may need drivers for your NIC.

---

## 7. Quick troubleshooting

| Problem | What to try |
|--------|-------------|
| PC ignores USB | Try another USB port (USB 2.0 port sometimes more compatible); enable “USB boot”; disable Fast Boot in firmware. |
| Two entries for same USB | Pick **UEFI** entry for UEFI/GPT work. |
| “No bootable device” after imaging | You imaged the **internal** disk — **remove** the USB and reboot; or fix partitions/`bcdboot` per `_docs/UEFI_WIM_Deployment.md`. |
| `MakeWinPEMedia` fails | Run **Deployment and Imaging Tools Environment as Administrator**; use a different USB; ensure WinPE add-on matches ADK. |

---

## 8. Related repo docs

- `_docs/UEFI_WIM_Deployment.md` — partition disks, apply `.wim`, `bcdboot` (UEFI).
- `_docs/WinPE_Commands_Cheat_Sheet.txt` — `Dism`, `bcdboot`, `diskpart` once WinPE is running.
- `_docs/Windows11_Rescue_USB_Recommendations.md` — Rufus + Windows 11 ISO + optional WinPE / Ventoy “one stick” rescue kit.

---

*WinPE is part of the Windows ADK; version names and download pages change — use Microsoft’s current “Download the Windows ADK” documentation for your release.*
