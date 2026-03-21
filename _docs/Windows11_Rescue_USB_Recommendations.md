# Windows 11 Pro: “One USB” rescue / repair kit

This is a **practical checklist** for a single USB stick that covers **most** Windows 11 Pro recovery scenarios (boot, disk, image repair, reinstall). **Scope:** Windows 11 Pro only, as you specified.

**Companion docs:** `_docs/WinPE_USB_and_Boot.md`, `_docs/UEFI_WIM_Deployment.md` (DISM / `bcdboot` / diskpart).

---

## 1. What you still need besides Rufus

| Item | Needed? | Role |
|------|--------|------|
| **Rufus** | You have it | Writes ISOs to USB; **does not** supply the OS or WinPE by itself. |
| **Windows 11 ISO (x64)** | **Yes** (recommended) | **Microsoft official** download — full installer + **Repair your computer** (Startup Repair, CMD, Reset, uninstall updates). |
| **Windows ADK + WinPE add-on** | **Optional** | Only if you **build** custom WinPE (`copype` + `MakeWinPEMedia /ISO`). Then flash that ISO with **Rufus** if you want. |
| **Your golden `.wim`** (optional) | Optional | If you want **apply-image / restore** from this stick; copy to a folder on the USB **or** a second drive. |

**Nothing else is strictly required** for a solid rescue stick: **one official Windows 11 ISO** + **Rufus** gets you **Recovery Environment**–class tools from Microsoft’s boot media.

---

## 2. Tier 1 — Minimum “always works” (Microsoft-only)

**Goal:** Boot to **Windows Setup** → **Repair your computer** → **Troubleshoot**.

1. Download **Windows 11** disk image (ISO) from Microsoft **for the same language/architecture** you deploy (e.g. **64-bit**).
2. Use **Rufus**:
   - Select the ISO.
   - **GPT** + **UEFI** (no CSM) for modern PCs.
   - Use defaults unless you need **Windows To Go**–style options (rare).

**What you get on boot:**

- **Startup Repair**
- **Command Prompt** (offline `diskpart`, `chkdsk`, `bcdboot` on mounted volumes — paths vary)
- **Uninstall Updates** (quality / feature)
- **System Restore** (if restore points exist)
- **Reset this PC** / **reinstall** (destructive options — use carefully)

**No ADK required** for this tier.

---

## 3. Tier 2 — Add **custom WinPE** (imaging / advanced)

**Goal:** Same tools as `_docs/WinPE_Commands_Cheat_Sheet.txt` — **`Dism /Apply-Image`**, **`Capture-Image`**, `diskpart`, `bcdboot` in a **minimal** environment.

1. Install **ADK** + **WinPE add-on** (see `_docs/WinPE_USB_and_Boot.md`).
2. `copype` → `MakeWinPEMedia /ISO` → get **`WinPE.iso`**.
3. **Either:**
   - **Second USB** (simplest), or  
   - **Ventoy** (see §6) to hold **multiple ISOs** on one large USB.

**Why add WinPE if you already have Windows 11 ISO?**  
WinPE is **smaller** and **purpose-built** for imaging; **Setup’s environment** is heavier but still has **DISM** in some paths. For **repeatable** golden-image work, **WinPE** is the usual choice.

---

## 4. What to **copy onto the USB** (data partition or extra folders)

**After** Rufus creates the bootable Windows 11 USB, **Explorer may show only one partition** (FAT32 limit). For **large** files:

- Use **Rufus** options that add a **second NTFS partition** for files **≥ 4 GB**, **or**
- Keep **big `.wim` files** on a **second USB** / **network share**, **or**
- Use **Ventoy** + NTFS exFAT (see §6).

**Suggested folders (if space allows):**

| Folder | Contents |
|--------|----------|
| **`\Drivers\`** | **Storage + network** drivers for your **worst-case** PC (extract `.inf` from OEM packs). Helps WinPE/Setup see disks. |
| **`\Scripts\`** | Your `.cmd` / `.ps1` helpers: `diskpart` answer files, `Dism` apply/capture lines. |
| **`\Images\`** | Optional **backup** `.wim` or **golden** `.wim` (if size allows). |
| **`\ISO\`** | **Extra** ISOs (WinPE, Linux live) if you use Ventoy. |

---

## 5. Optional “nice to have” (not required)

| Item | Why |
|------|-----|
| **Sysinternals Suite** (zip) | **Autoruns**, **ProcDump** — mostly **inside Windows**, not offline. |
| **Offline** `.cab` / drivers | For **DISM /AddDriver** when the image won’t boot. |
| **Microsoft DaRT** | Advanced remote recovery — **only** if you have **MDOP / licensing**; not in public ISO. |
| **Linux live ISO** (e.g. Ubuntu) | **Partitioning / disk clone** when Windows won’t boot — optional second ISO on Ventoy. |

---

## 6. One USB, **multiple** boot images — **Ventoy**

**Ventoy** formats the USB once; you **copy** ISO files as **files** (no re-flash per ISO).

- Put **Windows 11.iso** + **WinPE.iso** (+ optional Linux) on the same **exFAT/NTFS** partition.
- Boot menu picks the ISO.

**Trade-off:** Another tool to install (download **Ventoy** from the official site). **Rufus** stays useful for **single-ISO** sticks.

---

## 7. Quick “single USB” recipe (Windows 11 Pro)

1. **Download** official **Windows 11 x64 ISO** (Microsoft).
2. **Flash** with **Rufus** (UEFI + GPT).
3. If you **build WinPE**, add **`WinPE.iso`** via **second partition**, **second USB**, or **Ventoy**.
4. Add **`\Drivers`**, **`\Scripts`**, and optionally **`\Images`** as above.
5. **Test** boot: **Repair your computer** → **Command Prompt** → `diskpart` → `list vol`.

---

## 8. Security note

**Only** download **ADK**, **Windows ISO**, **Ventoy**, and **Rufus** from **official** sources. Avoid “pre-made WinPE” ISOs from random sites.

---

*This is operational guidance, not a guarantee every failure mode is covered.*
