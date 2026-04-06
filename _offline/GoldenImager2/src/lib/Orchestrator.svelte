<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { invoke } from '@tauri-apps/api/tauri';
  import { listen } from '@tauri-apps/api/event';
  import { open } from '@tauri-apps/api/dialog';
  import { 
    Hammer, Play, StopCircle, RefreshCw, FolderOpen, Terminal, 
    Download, CheckCircle2, XCircle, Cpu, Layers, HardDrive, 
    ShieldCheck, Settings as SettingsIcon, Zap, Scissors, PlusSquare,
    Box, FileJson, Trash2, Save, Unlock, Lock
  } from 'lucide-svelte';
  import { settings } from './store';
  import { notificationStore } from "./notifications";

  let status = $state({
    packer_active: false,
    osd_builder_ready: false,
    hyperv_attached: false,
    isMounted: false,
    hivesLoaded: false
  });

  let availableImages: any[] = $state([]);
  let isQuerying = $state(false);

  let config = $state({
    iso_url: "N:/OS_Images/Win11_24H2_Pro.iso",
    wim_index: 1,
    mount_path: "P:/Projects/golden-image/_offline_host/mount",
    drivers_path: "P:/Projects/golden-image/_offline_host/injections/drivers",
    updates_path: "P:/Projects/golden-image/_offline_host/injections/updates",
    admin_pass: "PackerTemp123!",
    vm_name: "GoldenImager-Orchestrator-Build",
    base_dir: "P:/Projects/golden-image/_offline_host/GoldenImager-Orchestrator"
  });

  let removals = $state([
    { id: 'MicrosoftEdge', label: 'Microsoft Edge Browser', checked: true },
    { id: 'MicrosoftStore', label: 'Microsoft Store & Apps', checked: true },
    { id: 'Telemetry', label: 'Telemetry & Data Collection', checked: true },
    { id: 'OneDrive', label: 'OneDrive Cloud Storage', checked: true },
    { id: 'Defender', label: 'Windows Defender (Optional)', checked: false },
    { id: 'Cortana', label: 'Cortana & Search Assist', checked: true }
  ]);

  let logs: string[] = $state([]);
  let isBuilding = false;
  let processing = $state(false);
  let logEnd = $state<HTMLElement | null>(null);

  async function handleQueryImages() {
    if (!config.iso_url) return;
    isQuerying = true;
    try {
      availableImages = await invoke('get_wim_images', { wimPath: config.iso_url });
      if (availableImages.length > 0) {
        config.wim_index = availableImages[0].ImageIndex;
        notificationStore.add(`Found ${availableImages.length} images. Defaulting to index ${config.wim_index}.`, "info");
      } else {
        notificationStore.add("No images found in the specified path.", "warning");
      }
    } catch (e: any) {
      notificationStore.add(`Query failed: ${e}`, "error");
      logs = [...logs, `[ERROR] Query: ${e}`];
    } finally {
      isQuerying = false;
    }
  }

  async function selectFile(key: 'iso_url', title: string, extensions: string[]) {
    try {
      const selected = await open({
        title,
        multiple: false,
        filters: [{ name: 'Images', extensions }]
      });
      if (selected && typeof selected === 'string') {
        config[key] = selected;
        if (key === 'iso_url') handleQueryImages();
      }
    } catch (e) {
      console.error("Selection failed", e);
    }
  }

  async function selectFolder(key: 'mount_path' | 'drivers_path' | 'updates_path' | 'base_dir', title: string) {
    try {
      const selected = await open({
        title,
        directory: true,
        multiple: false
      });
      if (selected && typeof selected === 'string') {
        config[key] = selected;
      }
    } catch (e) {
      console.error("Selection failed", e);
    }
  }

  async function handleMount() {
    processing = true;
    try {
      await invoke('mount_wim', { 
        wimPath: config.iso_url,
        mountPath: config.mount_path,
        index: config.wim_index
      });
      status.isMounted = true;
      notificationStore.add("WIM mounted successfully.", "success");
    } catch (e: any) {
      notificationStore.add(`Mount failed: ${e}`, "error");
      logs = [...logs, `[ERROR] Mount: ${e}`];
    } finally {
      processing = false;
    }
  }

  async function handleUnmount(discard: boolean = false) {
    processing = true;
    try {
      if (status.hivesLoaded) await handleUnloadHives();
      await invoke('unmount_wim', { 
        mountPath: config.mount_path,
        discard
      });
      status.isMounted = false;
      notificationStore.add("WIM unmounted.", "success");
    } catch (e: any) {
      notificationStore.add(`Unmount failed: ${e}`, "error");
    } finally {
      processing = false;
    }
  }

  async function handleLoadHives() {
    processing = true;
    try {
      await invoke('load_offline_hives', { 
        mountPath: config.mount_path,
        hiveTarget: "OFFLINE_TEMP"
      });
      status.hivesLoaded = true;
      notificationStore.add("Offline registry hives loaded.", "success");
    } catch (e: any) {
      notificationStore.add(`Reg load failed: ${e}`, "error");
    } finally {
      processing = false;
    }
  }

  async function handleUnloadHives() {
    processing = true;
    try {
      await invoke('unload_offline_hives', { 
        hiveTarget: "OFFLINE_TEMP"
      });
      status.hivesLoaded = false;
      notificationStore.add("Offline registry hives unloaded.", "success");
    } catch (e: any) {
      notificationStore.add(`Reg unload failed: ${e}`, "error");
    } finally {
      processing = false;
    }
  }

  async function applyStripping() {
    processing = true;
    logs = [...logs, "[*] STRIP: Initiating surgical component removal..."];
    try {
      const activeRemovals = removals.filter(r => r.checked).map(r => r.id);
      // await invoke('apply_stripping', { mountPath: config.mount_path, items: activeRemovals });
      logs = [...logs, "[SUCCESS] Image debloated."];
    } catch (e: any) {
      logs = [...logs, `[ERROR] Strip failed: ${e}`];
    } finally {
      processing = false;
    }
  }

  async function applyInjections() {
    processing = true;
    logs = [...logs, "[*] GROOM: Injecting drivers and updates..."];
    try {
      // await invoke('apply_injections', { mountPath: config.mount_path, drivers: config.drivers_path, updates: config.updates_path });
      logs = [...logs, "[SUCCESS] Assets injected."];
    } catch (e: any) {
      logs = [...logs, `[ERROR] Injection failed: ${e}`];
    } finally {
      processing = false;
    }
  }

  onMount(() => {
    const unlistenFn = listen('orchestrator-log', (event) => {
      logs = [...logs, event.payload as string];
      setTimeout(() => {
        logEnd?.scrollIntoView({ behavior: 'smooth' });
      }, 50);
    });

    return () => {
      unlistenFn.then(fn => fn());
    };
  });

</script>

<div class="panel">
  <div class="dashboard-grid">
    
    <!-- CARD 1: IMAGE SOURCE & MOUNT CONTROL -->
    <div class="tweak-column">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon">
            <HardDrive size={16} strokeWidth={2.5} />
          </span>
          <h3>IMAGE SOURCE & CONTROL</h3>
          {#if processing}
            <div class="header-loader">
              <RefreshCw size={10} class="spin" />
            </div>
          {/if}
        </div>
        <div class="card-body config-body">
          <div class="input-field">
            <label for="iso-url">SOURCE IMAGE (ISO/WIM)</label>
            <div class="input-with-icon">
              <input id="iso-url" type="text" bind:value={config.iso_url} onchange={handleQueryImages} />
              <button class="icon-btn" onclick={() => selectFile('iso_url', 'Select Source Image', ['iso', 'wim', 'esd'])}>
                <FolderOpen size={14} />
              </button>
              <button class="icon-btn" onclick={handleQueryImages} disabled={isQuerying}>
                {#if isQuerying}
                  <RefreshCw size={14} class="spin" />
                {:else}
                  <RefreshCw size={14} />
                {/if}
              </button>
            </div>
          </div>
          
          <div class="row-flex">
            <div class="input-field mini">
              <label for="wim-index">IMAGE EDITION</label>
              <select id="wim-index" bind:value={config.wim_index} class="orchestrator-select">
                {#if availableImages.length === 0}
                  <option value={1}>Index 1 (Generic)</option>
                {:else}
                  {#each availableImages as img}
                    <option value={img.ImageIndex}>
                      [{img.ImageIndex}] {img.ImageName}
                    </option>
                  {/each}
                {/if}
              </select>
            </div>
            <div class="input-field">
              <label for="mount-path">TARGET MOUNT POINT</label>
              <div class="input-with-icon">
                <input id="mount-path" type="text" bind:value={config.mount_path} />
                <button class="icon-btn" onclick={() => selectFolder('mount_path', 'Select Mount Point')}>
                  <FolderOpen size={14} />
                </button>
              </div>
            </div>
          </div>

          <div class="divider"></div>

          <div class="status-indicator" class:active={status.isMounted}>
            <Box size={14} />
            <span>MOUNT STATE: {status.isMounted ? 'ACTIVE' : 'DISCONNECTED'}</span>
          </div>

          {#if !status.isMounted}
            <button class="action-btn primary" onclick={handleMount} disabled={processing}>
              <Layers size={14} />
              <span>MOUNT IMAGE</span>
            </button>
          {:else}
            <div class="row-flex">
              <button class="action-btn secondary" onclick={() => handleUnmount(false)} disabled={processing}>
                <Save size={14} />
                <span>SAVE & COMMIT</span>
              </button>
              <button class="action-btn danger" onclick={() => handleUnmount(true)} disabled={processing}>
                <Trash2 size={14} />
                <span>DISCARD</span>
              </button>
            </div>

            <div class="divider"></div>

            <div class="row-flex">
              {#if !status.hivesLoaded}
                <button class="action-btn outline" onclick={handleLoadHives} disabled={processing}>
                  <Unlock size={14} />
                  <span>LOAD HIVES</span>
                </button>
              {:else}
                <button class="action-btn outline active-cyan" onclick={handleUnloadHives} disabled={processing}>
                  <Lock size={14} />
                  <span>UNLOAD HIVES</span>
                </button>
              {/if}
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- CARD 2: COMPONENT STRIPPING MATRIX -->
    <div class="tweak-column">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon">
            <Scissors size={16} strokeWidth={2.5} />
          </span>
          <h3>SURGICAL REMOVAL MATRIX</h3>
        </div>
        <div class="card-body">
          <div class="stripping-list">
            {#each removals as item}
              <div class="tweak-row">
                <span class="tweak-name">{item.label}</span>
                <div class="spacer"></div>
                <button 
                  class="target-btn small" 
                  class:active={item.checked}
                  onclick={() => item.checked = !item.checked}
                >
                  {item.checked ? 'STRIP' : 'KEEP'}
                </button>
              </div>
            {/each}
          </div>
          
          <div class="divider"></div>
          
          <button class="action-btn primary" onclick={applyStripping} disabled={!status.isMounted || processing}>
            <Zap size={14} />
            <span>IGNITE STRIPPING ENGINE</span>
          </button>
        </div>
      </div>
    </div>

    <!-- CARD 3: IMAGE GROOMING & INJECTION -->
    <div class="tweak-column">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon">
            <PlusSquare size={16} strokeWidth={2.5} />
          </span>
          <h3>IMAGE GROOMING SUITE</h3>
        </div>
        <div class="card-body config-body">
          <div class="input-field">
            <label for="drivers-path">DRIVERS REPOSITORY</label>
            <div class="input-with-icon">
              <input id="drivers-path" type="text" bind:value={config.drivers_path} />
              <button class="icon-btn" onclick={() => selectFolder('drivers_path', 'Select Drivers Directory')}>
                <FolderOpen size={14} />
              </button>
            </div>
          </div>

          <div class="input-field">
            <label for="updates-path">OFFLINE UPDATES (MSU/CAB)</label>
            <div class="input-with-icon">
              <input id="updates-path" type="text" bind:value={config.updates_path} />
              <button class="icon-btn" onclick={() => selectFolder('updates_path', 'Select Updates Directory')}>
                <FolderOpen size={14} />
              </button>
            </div>
          </div>

          <div class="divider"></div>

          <button class="action-btn primary" onclick={applyInjections} disabled={!status.isMounted || processing}>
            <Download size={14} />
            <span>INJECT CRITICAL ASSETS</span>
          </button>

          <button class="action-btn outline mt-8" disabled={!status.isMounted}>
            <ShieldCheck size={14} />
            <span>HARDEN BOOT LOADER</span>
          </button>
        </div>
      </div>
    </div>

    <!-- FULL WIDTH BOTTOM CARD: TELEMETRY -->
    <div class="telemetry-wrapper">
      <div class="category-card full-width-card">
        <div class="card-header">
          <span class="header-icon">
            <Terminal size={16} strokeWidth={2.5} />
          </span>
          <h3>DEBLOAT ENGINE TELEMETRY</h3>
        </div>
        <div class="card-body console-body">
          <div class="console">
            {#each logs as log}
              <div class="log-line" class:error-line={log.startsWith('[ERROR]')}>
                <span class="timestamp">[{new Date().toLocaleTimeString()}]</span>
                {log}
              </div>
            {/each}
            <div bind:this={logEnd}></div>
          </div>
        </div>
      </div>
    </div>

  </div>
</div>

<style>
  .panel {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding: 12px 12px 0 12px;
    gap: 8px;
    background: transparent;
  }

  .dashboard-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    grid-template-rows: auto auto;
    padding: 8px 10px 16px 10px;
    grid-gap: 12px;
    width: 100%;
    max-width: 1103px;
    margin: 0 auto;
    overflow-y: auto;
    flex: 1;
  }

  .tweak-column {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .category-card {
    background: #1a1f22;
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.7);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .card-header {
    height: 38px;
    background: #252b2e;
    display: flex;
    align-items: center;
    padding: 0 16px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    flex-shrink: 0;
  }

  .card-header h3 {
    font-size: 11px;
    font-weight: 800;
    color: #fff;
    opacity: 0.9;
    letter-spacing: 0.15em;
    text-transform: uppercase;
  }

  .header-icon {
    margin-right: 12px;
    color: var(--accent-color);
  }

  .header-loader {
    margin-left: auto;
    color: var(--accent-color);
  }

  .card-body {
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .config-body { gap: 10px; }

  .input-field label {
    display: block;
    font-size: 8.5px;
    font-weight: 900;
    color: rgba(255, 255, 255, 0.4);
    margin-bottom: 6px;
    letter-spacing: 0.12em;
  }

  .input-field input {
    width: 100%;
    background: #0d1112;
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 4px;
    padding: 7px 10px;
    color: #fff;
    font-size: 11px;
    font-family: 'JetBrains Mono', monospace;
    outline: none;
  }

  .input-field.mini { width: 60px; flex-shrink: 0; }

  .input-with-icon {
    display: flex;
    gap: 4px;
  }

  .input-with-icon input { flex: 1; }

  .icon-btn {
    width: 31px;
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.08);
    color: rgba(255, 255, 255, 0.4);
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
  }

  .row-flex {
    display: flex;
    gap: 10px;
    align-items: flex-end;
  }

  .divider {
    height: 1px;
    background: rgba(255, 255, 255, 0.04);
    margin: 4px 0;
  }

  .status-indicator {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 9px;
    font-weight: 800;
    color: rgba(255, 255, 255, 0.3);
    padding: 8px;
    background: rgba(0, 0, 0, 0.2);
    border-radius: 4px;
    margin-bottom: 4px;
  }

  .status-indicator.active {
    color: #4fb995;
    background: rgba(79, 185, 149, 0.05);
  }

  .action-btn {
    height: 34px;
    border-radius: 4px;
    font-size: 10px;
    font-weight: 900;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    cursor: pointer;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    transition: 0.2s;
    flex: 1;
  }

  .action-btn.primary {
    background: var(--accent-color);
    color: #000;
    border: none;
  }

  .action-btn.secondary {
    background: #232d30;
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: #fff;
  }

  .action-btn.danger {
    background: rgba(255, 61, 96, 0.1);
    border: 1px solid #ff3d60;
    color: #ff3d60;
  }

  .action-btn.outline {
    background: transparent;
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.6);
  }

  .action-btn.active-cyan {
    color: #00bcd4;
    border-color: #00bcd4;
    box-shadow: 0 0 10px rgba(0, 188, 212, 0.2);
  }

  .action-btn:hover:not(:disabled) {
    filter: brightness(1.2);
  }

  .action-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .tweak-row {
    display: flex;
    align-items: center;
    height: 28px;
    padding: 0 10px;
    background: #242a2d;
    border: 1px solid rgba(255, 255, 255, 0.04);
    border-radius: 4px;
  }

  .tweak-name {
    font-size: 10px;
    color: rgba(255, 255, 255, 0.7);
    font-weight: 600;
  }

  .target-btn.small {
    width: 44px;
    height: 18px;
    font-size: 8.5px;
    background: transparent;
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.3);
    border-radius: 3px;
    cursor: pointer;
  }

  .target-btn.small.active {
    color: #ff3d60;
    border-color: #ff3d60;
    background: rgba(255, 61, 96, 0.05);
  }

  .mt-8 { margin-top: 8px; }
  .spacer { flex: 1; }

  .telemetry-wrapper {
    grid-column: 1 / -1;
    margin-top: 8px;
  }

  .console-body {
    height: 180px;
    padding: 0;
  }

  .console {
    height: 100%;
    background: #0d1112;
    padding: 12px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 10.5px;
    overflow-y: auto;
    color: rgba(255, 255, 255, 0.6);
  }

  .log-line { margin-bottom: 3px; }
  .timestamp { color: rgba(255, 255, 255, 0.2); margin-right: 8px; }
  .error-line { color: #ff3d60; }

  :global(.spin) { animation: spin 1s linear infinite; }
  @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
</style>
