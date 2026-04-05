<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { invoke } from '@tauri-apps/api/tauri';
  import { listen } from '@tauri-apps/api/event';
  import { 
    Hammer, Play, StopCircle, RefreshCw, FolderOpen, Terminal, 
    Download, CheckCircle2, XCircle, Cpu, Layers, HardDrive, 
    ShieldCheck, Settings as SettingsIcon, Zap
  } from 'lucide-svelte';
  import { settings } from './store';
  import { notificationStore } from "./notifications";

  let status = {
    packer_active: false,
    osd_builder_ready: false,
    hyperv_attached: false
  };

  let config = {
    iso_url: "N:/OS_Images/Win11_25H2_English_x64.iso",
    admin_pass: "PackerTemp123!",
    vm_name: "GoldenImager-Orchestrator-Build",
    base_dir: "P:/Projects/golden-image/_offline_host/GoldenImager-Orchestrator"
  };

  let stages = [
    { id: 'Customize', label: '0. Customize (UI/Tweaks)', checked: true },
    { id: '1_Scoop', label: '1. Scoop Bundle', checked: true },
    { id: '2_MSVC', label: '2. MSVC Build Tools', checked: true },
    { id: '3_System_Apps', label: '3. System Apps', checked: true },
    { id: '4_Rust_Finish', label: '4. Rust & Linkers', checked: true },
    { id: '5_Finalize', label: '5. DISM & Purge', checked: true }
  ];

  let logs: string[] = [];
  let isBuilding = false;
  let isInstalling = false;
  let unlisten: any;
  let logEnd: HTMLElement;

  async function refreshStatus() {
    try {
      status = await invoke('get_orchestrator_status');
    } catch (e) {
      console.error("Status check failed", e);
    }
  }

  async function handleInstallPacker() {
    isInstalling = true;
    try {
      await invoke('install_packer', { baseDir: config.base_dir });
      notificationStore.add("Packer installed successfully.", "success");
      await refreshStatus();
    } catch (e) {
      notificationStore.add(`Packer install failed: ${e}`, "error");
    } finally {
      isInstalling = false;
    }
  }

  async function handleInstallOSD() {
    isInstalling = true;
    try {
      await invoke('install_osdbuilder');
      notificationStore.add("OSDBuilder module installed.", "success");
      await refreshStatus();
    } catch (e) {
      notificationStore.add(`OSDBuilder install failed: ${e}`, "error");
    } finally {
      isInstalling = false;
    }
  }

  async function generatePayload() {
    const active = stages.filter(s => s.checked).map(s => s.id);
    logs = [...logs, "[*] Orchestrator: Constructing stealth payload..."];
    try {
      await invoke('generate_stealth_payload', { 
        baseDir: config.base_dir,
        activeStages: active,
        isoUrl: config.iso_url,
        adminPass: config.admin_pass,
        vmName: config.vm_name
      });
      logs = [...logs, "[SUCCESS] Stealth payload ready."];
    } catch (e: any) {
      const msg = e.Message || e.message || JSON.stringify(e);
      logs = [...logs, `[ERROR] Payload assembly failed: ${msg}`];
    }
  }

  async function explorePayload() {
    try {
      await invoke('show_payload_in_explorer', { path: `${config.base_dir}/payload` });
    } catch (e) {
      console.error(e);
    }
  }

  async function igniteEngine() {
    isBuilding = true;
    logs = [...logs, "[*] Ignite: Starting Packer build engine..."];
    try {
      await invoke('run_packer_build', {
        templatePath: `${config.base_dir}/templates/vhd-orchestrator.pkr.hcl`,
        vars: {
          iso_url: config.iso_url,
          vm_name: config.vm_name,
          admin_password: config.admin_pass
        }
      });
    } catch (e: any) {
      const msg = e.Message || e.message || JSON.stringify(e);
      logs = [...logs, `[ERROR] Build ignition failed: ${msg}`];
      isBuilding = false;
    }
  }

  async function abortBuild() {
    try {
      await invoke('abort_packer_build');
      logs = [...logs, "[!] ABORT: Engine termination signal sent."];
    } catch (e) {
      console.error(e);
    }
  }

  onMount(() => {
    refreshStatus();
    const timer = setInterval(refreshStatus, 3000);
    
    let unlistenFn: any;
    
    const initListen = async () => {
      unlistenFn = await listen('orchestrator-log', (event) => {
        logs = [...logs, event.payload as string];
        if (logEnd) {
          setTimeout(() => logEnd.scrollIntoView({ behavior: 'smooth' }), 50);
        }
      });
    };
    
    initListen();

    return () => {
      clearInterval(timer);
      if (unlistenFn) unlistenFn();
    };
  });

</script>

<div class="panel">
  <div class="dashboard-grid">
    <!-- TOOL ACQUISITION CARD -->
    <div class="tweak-column">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon">
            <Download size={16} strokeWidth={3.5} />
          </span>
          <h3>TOOL ACQUISITION SUITE</h3>
        </div>
        <div class="card-body">
          <div class="tweak-row">
            <span class="tweak-name">Packer Build Engine</span>
            <div class="spacer"></div>
            <button 
              class="target-btn" 
              class:active={status.packer_active}
              class:inactive={!status.packer_active}
              on:click={status.packer_active ? null : handleInstallPacker}
              disabled={isInstalling && !status.packer_active}
            >
              {#if isInstalling && !status.packer_active}<RefreshCw size={10} class="spin" />{:else}{status.packer_active ? 'READY' : 'GET'}{/if}
            </button>
          </div>

          <div class="tweak-row">
            <span class="tweak-name">OSDBuilder Module</span>
            <div class="spacer"></div>
            <button 
              class="target-btn" 
              class:active={status.osd_builder_ready}
              class:inactive={!status.osd_builder_ready}
              on:click={status.osd_builder_ready ? null : handleInstallOSD}
              disabled={isInstalling && !status.osd_builder_ready}
            >
              {#if isInstalling && !status.osd_builder_ready}<RefreshCw size={10} class="spin" />{:else}{status.osd_builder_ready ? 'READY' : 'GET'}{/if}
            </button>
          </div>

          <div class="tweak-row">
            <span class="tweak-name">Hyper-V Hypervisor</span>
            <div class="spacer"></div>
            <button 
              class="target-btn" 
              class:active={status.hyperv_attached}
              class:inactive={!status.hyperv_attached}
              disabled
            >
              {status.hyperv_attached ? 'READY' : 'GET'}
            </button>
          </div>
        </div>
      </div>

      <!-- ACTION BUTTONS BELOW TOOLS -->
      <div class="category-card" style="margin-top: 16px;">
        <div class="card-header">
          <span class="header-icon">
            <Zap size={16} strokeWidth={3.5} />
          </span>
          <h3>ORCHESTRATOR ACTIONS</h3>
        </div>
        <div class="card-body">
          <button class="action-item-btn" on:click={generatePayload}>
            <Layers size={14} />
            <span>GENERATE STEALTH PAYLOAD</span>
          </button>
          <button class="action-item-btn outline" on:click={explorePayload}>
            <FolderOpen size={14} />
            <span>EXPLORE ASSETS</span>
          </button>
        </div>
      </div>
    </div>

    <!-- PIPELINE STAGES CARD -->
    <div class="tweak-column">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon">
            <Cpu size={16} strokeWidth={3.5} />
          </span>
          <h3>PIPELINE BUILD STAGES</h3>
        </div>
        <div class="card-body">
          {#each stages as stage}
            <div class="tweak-row">
              <span class="tweak-name">{stage.label}</span>
              <div class="spacer"></div>
              <button 
                class="target-btn" 
                class:active={stage.checked}
                on:click={() => stage.checked = !stage.checked}
              >
                {stage.checked ? 'ON' : 'OFF'}
              </button>
            </div>
          {/each}
        </div>
      </div>
    </div>

    <!-- ENGINE CONFIGURATION CARD -->
    <div class="tweak-column">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon">
            <SettingsIcon size={16} strokeWidth={3.5} />
          </span>
          <h3>ENGINE CONFIGURATION</h3>
        </div>
        <div class="card-body config-body">
          <div class="input-field">
            <label for="iso-url">SOURCE ISO IMAGE</label>
            <input id="iso-url" type="text" bind:value={config.iso_url} />
          </div>
          <div class="input-field">
            <label for="admin-pass">ADMIN PASSWORD</label>
            <input id="admin-pass" type="password" bind:value={config.admin_pass} />
          </div>
          <div class="input-field">
            <label for="vm-name">VM BUILD NAME</label>
            <input id="vm-name" type="text" bind:value={config.vm_name} />
          </div>

          <div class="divider"></div>
          
          {#if !isBuilding}
            <button class="ignite-btn" on:click={igniteEngine}>
              <Play size={16} fill="currentColor" />
              IGNITE BUILD ENGINE
            </button>
          {:else}
            <button class="abort-btn" on:click={abortBuild}>
              <StopCircle size={16} />
              ABORT ACTIVE BUILD
            </button>
          {/if}
        </div>
      </div>
    </div>

    <!-- FULL WIDTH BOTTOM CARD: TELEMETRY -->
    <div class="overview-header-card telemetry-card">
      <div class="category-card full-width-card">
        <div class="card-header">
          <span class="header-icon">
            <Terminal size={16} strokeWidth={3.5} />
          </span>
          <h3>BUILD TELEMETRY CONSOLE</h3>
          {#if isBuilding}
            <div class="header-loader">
              <RefreshCw size={10} class="spin" />
            </div>
          {/if}
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
    padding: 12px;
    gap: 8px;
    overflow: hidden;
    background: transparent;
  }

  .dashboard-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    padding: 16px;
    grid-gap: 16px;
    overflow-y: auto;
    flex: 1;
    align-items: flex-start;
    align-content: start;
    justify-content: start;
  }

  .tweak-column {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .category-card {
    width: 100%;
    background: rgba(26, 31, 34, 0.8);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.7);
    overflow: hidden;
  }

  .card-header {
    height: 26px;
    display: flex;
    align-items: center;
    padding: 0 14px;
    background: rgba(255, 255, 255, 0.02);
  }

  .card-header h3 {
    font-size: 10.5px;
    font-weight: 800;
    color: #fff;
    opacity: 0.9;
    letter-spacing: 0.18em;
    text-transform: uppercase;
  }

  .header-icon {
    margin-right: 12px;
    color: var(--accent-color);
  }

  .card-body {
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .tweak-row {
    display: flex;
    align-items: center;
    height: 31px;
    padding: 0 12px;
    background: #242a2d;
    border: 1px solid rgba(255, 255, 255, 0.04);
    border-radius: 5px;
  }

  .tweak-name {
    font-size: 10.5px;
    color: rgba(255, 255, 255, 0.7);
    font-weight: 500;
  }

  .spacer { flex: 1; }

  .target-btn {
    width: 50px;
    height: 22px;
    border: 1px solid rgba(255, 255, 255, 0.06);
    background: transparent;
    color: rgba(255, 255, 255, 0.2);
    border-radius: 4px;
    font-size: 9px;
    font-weight: 800;
    cursor: pointer;
    transition: 0.2s;
  }

  .target-btn.active {
    color: #4fb995;
    border-color: rgba(79, 185, 149, 0.4);
  }

  .target-btn.inactive {
    color: #ff3d60;
    border-color: rgba(255, 61, 96, 0.4);
  }

  .target-btn:hover:not(:disabled) {
    color: #fff;
    border-color: var(--accent-color);
  }

  .action-item-btn {
    width: 100%;
    height: 32px;
    background: rgba(var(--accent-rgb), 0.1);
    border: 1px solid rgba(var(--accent-rgb), 0.2);
    border-radius: 4px;
    color: var(--accent-color);
    font-size: 10px;
    font-weight: 800;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    cursor: pointer;
    transition: 0.2s;
  }

  .action-item-btn.outline {
    background: transparent;
    border: 1px solid rgba(255, 255, 255, 0.08);
    color: rgba(255, 255, 255, 0.4);
  }

  .action-item-btn:hover {
    background: var(--accent-color);
    color: #000;
  }

  .config-body {
    gap: 12px;
  }

  .input-field label {
    display: block;
    font-size: 8.5px;
    font-weight: 800;
    color: rgba(255, 255, 255, 0.4);
    margin-bottom: 4px;
    letter-spacing: 0.1em;
  }

  .input-field input {
    width: 100%;
    background: #12181a;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 4px;
    padding: 8px 12px;
    color: #fff;
    font-size: 12px;
    outline: none;
  }

  .divider {
    height: 1px;
    background: rgba(255, 255, 255, 0.05);
    margin: 8px 0;
  }

  .ignite-btn, .abort-btn {
    height: 38px;
    border-radius: 4px;
    font-size: 11px;
    font-weight: 900;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    cursor: pointer;
    letter-spacing: 0.1em;
  }

  .ignite-btn {
    background: #4fb995;
    color: #000;
    border: none;
  }

  .abort-btn {
    background: #ff3d60;
    color: #fff;
    border: none;
  }

  .overview-header-card {
    grid-column: 1 / -1;
    margin-top: 8px;
  }

  .console-body {
    height: 200px;
    padding: 0;
  }

  .console {
    height: 100%;
    background: #0d1112;
    padding: 16px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 11px;
    overflow-y: auto;
    color: rgba(255, 255, 255, 0.7);
  }

  .log-line { margin-bottom: 4px; }
  .timestamp { color: rgba(255, 255, 255, 0.2); margin-right: 8px; }
  .error-line { color: #ff3d60; }

  :global(.spin) { animation: spin 1s linear infinite; }
  @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
</style>
