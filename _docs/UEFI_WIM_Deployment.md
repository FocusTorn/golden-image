# UEFI: Verify in VM (`[IN]`), Then Deploy the WIM

This guide assumes **UEFI firmware** and **GPT** disks. All steps use **DISM** and **diskpart** from **Windows PE (WinPE)** unless noted.

**Related files in this repo**

- `[IN]` workflow (staging dashboard): applies your captured WIM into a **new** blank Gen 2 VM OS VHD and prepares boot — `_offline_host/vhd-management/scripts/Boot-WimInNewVm.ps1`
- **WinPE on USB + how to boot:** `_docs/WinPE_USB_and_Boot.md`
- **Rufus vs ADK + Windows 11 rescue USB checklist:** `_docs/Windows11_Rescue_USB_Recommendations.md`
- Sample UEFI diskpart layout: `_docs/Diskpart_Automation.txt`
- Pre-capture checklist: `_docs/Pre-Flight_Checklist.md`

**Config**

- Set `VMDetails.WimDestination` in `_master_config.json` to your `.wim` file (or a folder where the newest `*.wim` is picked up). The `[IN]` script resolves that path before applying.

---

## 1. Terms

| Term | Meaning |
|------|--------|
| **Primary / main drive** | The disk the PC boots from today (usually **Disk 0**). Replacing it **erases** the current Windows install unless you back up first. |
| **Secondary drive** | Another physical disk (e.g. **Disk 1**) you image **without** wiping Disk 0. You later move that disk to another PC or swap it to become the only/boot disk. |
| **`[IN]`** | Staging dashboard action **“Boot WIM in new VM”** — runs `Boot-WimInNewVm.ps1`, which partitions the VM’s OS VHD (UEFI), applies the WIM, runs `bcdboot`, leaves the VM off for you to start and verify. |
| **WinPE USB** | Bootable USB built with the **Windows ADK** / **WinPE** add-on; contains `diskpart`, `Dism`, `bcdboot`. |

---

## 2. Verify the WIM in a VM using `[IN]` (UEFI / Gen 2)

**Goal:** Confirm the image boots and OOBE/unattend behave as expected **before** you deploy to physical hardware.

1. **Capture** your golden WIM from the reference VM (after sysprep) using your normal process. Ensure the file path matches `WimDestination` (or drop the newest `.wim` in that folder).
2. On the **Hyper-V host**, open the staging dashboard and use **`[IN] Boot WIM in new VM`** (or run `Boot-WimInNewVm.ps1` from an elevated PowerShell session with the repo’s config loaded).
3. The script creates a VM (name suffix `_WimBoot`), detaches the blank OS VHD, **partitions for UEFI**, **applies** the WIM with DISM, runs **`bcdboot`**, reattaches the VHD, and leaves the VM **powered off**.
4. **Start the VM** and complete your smoke test (keyboard, network, policies, etc.).
5. If something fails, fix **unattend**, **recapture**, and run `[IN]` again.

**Why this matches production:** Gen 2 VMs use **UEFI** and **Secure Boot** options aligned with `_master_config.json` provisioning templates — closer to modern PCs than legacy BIOS.

---

## 2.5 Split one drive: **keep existing data**, add a new partition for the Windows image

**Use case:** A single disk has **one big volume** with lots of files (e.g. ~50 GB used). You want to **shrink** that volume **without deleting** its contents, then **create a new partition** in the free space to **apply your `.wim`** (staging, test apply, or a second OS volume — depending on your disk layout).

### 2.5.1 Before you shrink (read this)

| Topic | What to do |
|--------|------------|
| **Backup** | Shrink is usually safe; still **back up** anything important. |
| **BitLocker** | If the volume is encrypted, **suspend** or **decrypt** BitLocker for that drive before shrinking (otherwise shrink may be blocked or unreliable). |
| **How shrink works** | Windows frees space from the **end** of the volume. **Unmovable files** (hiberfil, pagefile, restore points) can **limit** how much you can shrink — see §2.5.4. |
| **Boot / UEFI** | A **new NTFS partition alone** is enough to **`Dism /Apply-Image`** into it from WinPE. Making that install **UEFI-bootable** requires an **EFI System Partition** on **that disk** (and usually **GPT**). If the disk **already** has **EFI + Windows** (typical OS disk), you can dual-boot or replace boot entries — **advanced**. If the disk is **data-only** or **MBR-only** with no EFI, plan a **full GPT layout** (see §3–§4) or add EFI — **don’t assume** split + apply alone creates a bootable PC. |

### 2.5.2 Easiest: Disk Management (GUI)

1. Sign in to Windows (run this **on the machine** where the disk is installed — **not** WinPE for this step).
2. Press **Win + X** → **Disk Management** (`diskmgmt.msc`).
3. Right‑click the **volume** (partition) that has your data → **Shrink Volume…**.
4. Enter **how many MB** to free (e.g. `80000` ≈ 80 GB for the new partition). If **maximum shrinkable** is too small, go to §2.5.4.
5. After shrink completes, you’ll see **Unallocated** space next to that volume.
6. Right‑click **Unallocated** → **New Simple Volume** → wizard: size, drive letter (e.g. `W:`), **NTFS**, label e.g. `WinImage`.
7. That new volume is where you can later **`Dism /Apply-Image /ApplyDir=W:\`** (often from **WinPE** so the OS on `C:` isn’t locking files).

### 2.5.3 diskpart (same machine, elevated Command Prompt)

**Identify the volume number** (Disk Management shows volume #, or use `list volume`). Replace `X` and the shrink size (MB) as needed.

```txt
diskpart
list volume
select volume X
shrink querymax
shrink desired=80000
create partition primary
format quick fs=ntfs label="WinImage"
assign letter=W
exit
```

- **`shrink querymax`** — shows maximum MB you can shrink (limited by files in use).
- **`shrink desired=80000`** — frees ~80 GB for the new partition (adjust to your plan).

### 2.5.4 If “maximum shrink” is tiny (unmovable files)

Try **in order** (reboot between steps if prompted):

1. **Disable hibernation** (removes `hiberfil.sys`):  
   `powercfg /h off`
2. **System Restore / shadow copies:** Temporarily **turn off** System Protection for that drive (**System Properties** → **System Protection**).
3. **Page file:** **System Properties** → **Advanced** → **Performance** → **Advanced** → **Virtual memory** — set **No paging file** on **that** drive, reboot, shrink, then **restore** paging file if desired.
4. **Disk Cleanup** on that volume (includes “Previous Windows installations” if present).
5. **Optimize / defrag** the volume (SSD: **Optimize**; HDD: defrag can help move data for shrink).

Then run **`shrink querymax`** again.

### 2.5.5 Applying the WIM to the **new** partition

- Boot **WinPE** from USB (see §7 and `_docs/WinPE_USB_and_Boot.md`), confirm letters with `diskpart` → `list vol`.
- Apply:

  ```cmd
  Dism /Apply-Image /ImageFile:E:\Images\YourGolden.wim /Index:1 /ApplyDir=W:\
  ```

- **`bcdboot`** (UEFI) only after you know **which partition is EFI** on that disk — same caveats as §2.5.1.

---

## 3. Deploy the WIM to a **secondary** drive (later becomes **C:** on another PC)

**Use case:** You have a **working PC** with Windows on **Disk 0**. You add a **new SSD** as **Disk 1**, image **only Disk 1**, then **move that SSD** to the target machine (or swap it in as the only drive). After boot on the new hardware, Windows will assign **C:** to the Windows volume.

### 3.1 Safety

- **Triple-check** `list disk` in diskpart: **`select disk N`** must be the **secondary** disk, **not** Disk 0.
- Unplug other USB disks if possible to avoid selecting the wrong disk.

### 3.2 Boot WinPE

- Boot the build PC from your **WinPE USB** (disable Secure Boot temporarily if your unsigned WinPE requires it, or use signed boot media).

### 3.3 Partition the **secondary** disk (GPT / UEFI)

In `diskpart`:

```txt
list disk
select disk 1
clean
convert gpt
```

Create **EFI**, **MSR**, and **Windows** (adjust sizes to match your standards; EFI is often 100–260 MB):

```txt
create partition efi size=260
format quick fs=fat32 label="System"
assign letter=S

create partition msr size=16

create partition primary
format quick fs=ntfs label="Windows"
assign letter=W
exit
```

Letters **S:** and **W:** are only for this WinPE session.

### 3.4 Apply the WIM and register boot files

Adjust paths and index:

```cmd
Dism /Get-ImageInfo /ImageFile:E:\Images\YourGolden.wim

Dism /Apply-Image /ImageFile:E:\Images\YourGolden.wim /Index:1 /ApplyDir:W:\

W:\Windows\System32\bcdboot W:\Windows /s S: /f UEFI
```

- **`E:\`** = USB or network path where the `.wim` lives (use `dir` / `diskpart` → `list vol` to confirm letters).

### 3.5 Shutdown and move the disk

- **Shut down**, install the SSD in the **target** PC as the **only** (or primary boot) disk.
- First boot on new hardware may take longer; drivers may install via PnP.

**Note:** If the target PC has **different storage/NVMe controllers**, ensure your image includes those drivers or inject them offline (see `_docs/Inject_Drivers_Offline.md`).

---

## 4. Deploy the WIM to the computer’s **current main hard drive** using a USB

**Use case:** **Clean install** on the existing PC: the current Windows on Disk 0 will be **wiped**.

### 4.1 Backup

- Copy data you need off the machine; **this process destroys** existing partitions on the selected disk.

### 4.2 Boot WinPE from USB

- Boot from WinPE USB; use **UEFI** boot entry if the PC is UEFI.

### 4.3 Wipe and partition **Disk 0** (GPT / UEFI)

```txt
diskpart
list disk
select disk 0
clean
convert gpt
```

Then EFI + MSR + Windows (same pattern as section 3.3). You can adapt the full layout from `_docs/Diskpart_Automation.txt` if you also want a **Recovery** partition.

### 4.4 Apply WIM + bcdboot

Same as section 3.4, with **`W:\`** = Windows volume and **`S:\`** = EFI.

### 4.5 Reboot

- Remove the USB, reboot, firmware should boot Windows from the internal disk.

---

## 5. Quick reference commands

| Step | Command pattern |
|------|------------------|
| WIM info | `Dism /Get-ImageInfo /ImageFile:path\to\image.wim` |
| Apply | `Dism /Apply-Image /ImageFile:...\image.wim /Index:N /ApplyDir:W:\` |
| Boot files (UEFI) | `W:\Windows\System32\bcdboot W:\Windows /s S: /f UEFI` |

---

## 6. Troubleshooting (UEFI)

| Symptom | Things to check |
|--------|-------------------|
| “No bootable device” | EFI partition exists, formatted **FAT32**, `bcdboot` targeted **`/s S:`** (EFI letter), firmware boot order prefers internal disk. |
| Wrong disk wiped | Always run `list disk` and confirm **size/model** before `clean`. |
| Applied WIM but no **C:** in WinPE | Normal — **C:** is assigned at first full boot; in WinPE use **W:** for the Windows folder. |
| `[IN]` vs physical | `[IN]` validates the **WIM** in a VM; physical PCs still need correct **drivers** and firmware (UEFI) settings. |

---

## 7. Building WinPE and booting from USB

Use the full step-by-step guide (ADK + WinPE add-on, `copype`, `MakeWinPEMedia`, UEFI boot menu, Secure Boot, troubleshooting):

**→ `_docs/WinPE_USB_and_Boot.md`**

---

*Last updated: aligns with repo `[IN]` = `Boot-WimInNewVm.ps1` and UEFI/GPT deployment patterns.*
