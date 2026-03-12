# How to Inject Drivers into your Golden Image (No Reinstall Needed!)
**Goal:** Add specific drivers (WiFi, LAN, NVMe) to your `.wim` file while it is "offline."

## 🛠️ The "Injection" Workflow

1.  **Prepare the Folders:**
    *   Create a folder called `Mount` in `P:\Projects\golden-image`.
    *   Create a folder called `Drivers_To_Inject` in `P:\Projects\golden-image`.
    *   Put all your raw driver folders (containing `.inf` files) into `Drivers_To_Inject`.

2.  **Mount the Image:**
    `dism /Mount-Image /ImageFile:"P:\Projects\golden-image\Thin_Agnostic_Master.wim" /Index:1 /MountDir:"P:\Projects\golden-image\Mount"`

3.  **Inject the Drivers:**
    `dism /Image:"P:\Projects\golden-image\Mount" /Add-Driver /Driver:"P:\Projects\golden-image\Drivers_To_Inject" /Recurse`

4.  **Save and Close:**
    `dism /Unmount-Image /MountDir:"P:\Projects\golden-image\Mount" /Commit`

---

## ⚠️ Important Rules
*   **Index:** Most `.wim` files only have one "Index" (1). If yours has multiple (Home, Pro, etc.), you must specify which one you are mounting.
*   **Read-Only:** Ensure the `.wim` file is not "Read-Only" and that no other program (like 7-Zip) has it open.
*   **Commit vs. Discard:** If you make a mistake, use `/Discard` instead of `/Commit` to cancel all changes and unmount the image safely.
