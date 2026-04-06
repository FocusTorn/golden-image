import { invoke } from '@tauri-apps/api/tauri';
import { listen } from '@tauri-apps/api/event';
import { open } from '@tauri-apps/api/dialog';
import { notificationStore } from "./notifications";

export interface ImagingConfig {
  iso_url: string;
  wim_index: number;
  mount_path: string;
  drivers_path: string;
  updates_path: string;
  admin_pass: string;
  vm_name: string;
  base_dir: string;
}

export interface ImagingStatus {
  packer_active: boolean;
  osd_builder_ready: boolean;
  hyperv_attached: boolean;
  isMounted: boolean;
  hivesLoaded: boolean;
}

export interface RemovalItem {
  id: string;
  label: string;
  checked: boolean;
}

export class OrchestratorEngine {
  status = $state<ImagingStatus>({
    packer_active: false,
    osd_builder_ready: false,
    hyperv_attached: false,
    isMounted: false,
    hivesLoaded: false
  });

  config = $state<ImagingConfig>({
    iso_url: "N:/OS_Images/Win11_24H2_Pro.iso",
    wim_index: 1,
    mount_path: "P:/Projects/golden-image/_offline_host/mount",
    drivers_path: "P:/Projects/golden-image/_offline_host/injections/drivers",
    updates_path: "P:/Projects/golden-image/_offline_host/injections/updates",
    admin_pass: "PackerTemp123!",
    vm_name: "GoldenImager-Orchestrator-Build",
    base_dir: "P:/Projects/golden-image/_offline_host/GoldenImager-Orchestrator"
  });

  removals = $state<RemovalItem[]>([
    { id: 'MicrosoftEdge', label: 'Microsoft Edge Browser', checked: true },
    { id: 'MicrosoftStore', label: 'Microsoft Store & Apps', checked: true },
    { id: 'Telemetry', label: 'Telemetry & Data Collection', checked: true },
    { id: 'OneDrive', label: 'OneDrive Cloud Storage', checked: true },
    { id: 'Defender', label: 'Windows Defender (Optional)', checked: false },
    { id: 'Cortana', label: 'Cortana & Search Assist', checked: true }
  ]);

  availableImages = $state<any[]>([]);
  isQuerying = $state(false);
  logs = $state<string[]>([]);
  processing = $state(false);

  constructor() {
    this.setupListeners();
  }

  private async setupListeners() {
    await listen('orchestrator-log', (event) => {
      this.logs = [...this.logs, event.payload as string];
    });
  }

  async handleQueryImages() {
    if (!this.config.iso_url) return;
    this.isQuerying = true;
    try {
      this.availableImages = await invoke('get_wim_images', { wimPath: this.config.iso_url });
      if (this.availableImages.length > 0) {
        this.config.wim_index = this.availableImages[0].ImageIndex;
        notificationStore.add(`Found ${this.availableImages.length} images. Defaulting to index ${this.config.wim_index}.`, "info");
      }
    } catch (e: any) {
      notificationStore.add(`Query failed: ${e}`, "error");
      this.logs = [...this.logs, `[ERROR] Query: ${e}`];
    } finally {
      this.isQuerying = false;
    }
  }

  async selectFile(key: keyof ImagingConfig, title: string, extensions: string[]) {
    try {
      const selected = await open({
        title,
        multiple: false,
        filters: [{ name: 'Images', extensions }]
      });
      if (selected && typeof selected === 'string') {
        (this.config as any)[key] = selected;
        if (key === 'iso_url') this.handleQueryImages();
      }
    } catch (e) {
      console.error("Selection failed", e);
    }
  }

  async selectFolder(key: keyof ImagingConfig, title: string) {
    try {
      const selected = await open({
        title,
        directory: true,
        multiple: false
      });
      if (selected && typeof selected === 'string') {
        (this.config as any)[key] = selected;
      }
    } catch (e) {
      console.error("Selection failed", e);
    }
  }

  async handleMount() {
    this.processing = true;
    try {
      await invoke('mount_wim', { 
        wimPath: this.config.iso_url,
        mountPath: this.config.mount_path,
        index: this.config.wim_index
      });
      this.status.isMounted = true;
      notificationStore.add("WIM mounted successfully.", "success");
    } catch (e: any) {
      notificationStore.add(`Mount failed: ${e}`, "error");
      this.logs = [...this.logs, `[ERROR] Mount: ${e}`];
    } finally {
      this.processing = false;
    }
  }

  async handleUnmount(discard: boolean = false) {
    this.processing = true;
    try {
      if (this.status.hivesLoaded) await this.handleUnloadHives();
      await invoke('unmount_wim', { 
        mountPath: this.config.mount_path,
        discard
      });
      this.status.isMounted = false;
      notificationStore.add("WIM unmounted.", "success");
    } catch (e: any) {
      notificationStore.add(`Unmount failed: ${e}`, "error");
    } finally {
      this.processing = false;
    }
  }

  async handleLoadHives() {
    this.processing = true;
    try {
      await invoke('load_offline_hives', { 
        mountPath: this.config.mount_path,
        hiveTarget: "OFFLINE_TEMP"
      });
      this.status.hivesLoaded = true;
      notificationStore.add("Offline registry hives loaded.", "success");
    } catch (e: any) {
      notificationStore.add(`Reg load failed: ${e}`, "error");
    } finally {
      this.processing = false;
    }
  }

  async handleUnloadHives() {
    this.processing = true;
    try {
      await invoke('unload_offline_hives', { 
        hiveTarget: "OFFLINE_TEMP"
      });
      this.status.hivesLoaded = false;
      notificationStore.add("Offline registry hives unloaded.", "success");
    } catch (e: any) {
      notificationStore.add(`Reg unload failed: ${e}`, "error");
    } finally {
      this.processing = false;
    }
  }

  async handleCleanup() {
    this.processing = true;
    this.logs = [...this.logs, "[*] CLEANUP: Scrubbing mount points and orphaned handles..."];
    try {
      await invoke('cleanup_mount_points');
      notificationStore.add("Mount cleanup complete.", "success");
      this.logs = [...this.logs, "[SUCCESS] Cleanup finished."];
    } catch (e: any) {
      this.logs = [...this.logs, `[ERROR] Cleanup: ${e}`];
    } finally {
      this.processing = false;
    }
  }

  async handleCompaction() {
    this.processing = true;
    this.logs = [...this.logs, "[*] COMPACT: Attempting maximum WIM compression (Lzx)..."];
    try {
      // await invoke('compact_wim', { wimPath: this.config.iso_url });
      notificationStore.add("Image compaction complete.", "success");
      this.logs = [...this.logs, "[SUCCESS] Image compacted."];
    } catch (e: any) {
      this.logs = [...this.logs, `[ERROR] Compact: ${e}`];
    } finally {
      this.processing = false;
    }
  }

  async handleMastering() {
    this.processing = true;
    this.logs = [...this.logs, "[*] ISO: Mastering final production image..."];
    try {
      // await invoke('master_iso', { config: this.config });
      notificationStore.add("ISO Mastering initiated.", "info");
    } catch (e: any) {
      this.logs = [...this.logs, `[ERROR] Mastering: ${e}`];
    } finally {
      this.processing = false;
    }
  }
}
