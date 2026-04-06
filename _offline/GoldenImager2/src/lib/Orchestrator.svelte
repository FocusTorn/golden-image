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
  import { OrchestratorEngine } from './orchestrator-engine.svelte';
  import TacticalContainer from './TacticalContainer.svelte';

  const engine = new OrchestratorEngine();
  let logEnd = $state<HTMLElement | null>(null);

  async function applyStripping() {
    engine.processing = true;
    engine.logs = [...engine.logs, "[*] STRIP: Initiating surgical component removal..."];
    try {
      const activeRemovals = engine.removals.filter(r => r.checked).map(r => r.id);
      // await invoke('apply_stripping', { mountPath: engine.config.mount_path, items: activeRemovals });
      engine.logs = [...engine.logs, "[SUCCESS] Image debloated."];
    } catch (e: any) {
      engine.logs = [...engine.logs, `[ERROR] Strip failed: ${e}`];
    } finally {
      engine.processing = false;
    }
  }

  async function applyInjections() {
    engine.processing = true;
    engine.logs = [...engine.logs, "[*] GROOM: Injecting drivers and updates..."];
    try {
      // await invoke('apply_injections', { mountPath: engine.config.mount_path, drivers: engine.config.drivers_path, updates: engine.config.updates_path });
      engine.logs = [...engine.logs, "[SUCCESS] Assets injected."];
    } catch (e: any) {
      engine.logs = [...engine.logs, `[ERROR] Injection failed: ${e}`];
    } finally {
      engine.processing = false;
    }
  }

  onMount(() => {
    setTimeout(() => {
      engine.handleQueryImages();
    }, 100);
  });

  $effect(() => {
    if (engine.logs.length > 0) {
      setTimeout(() => {
        logEnd?.scrollIntoView({ behavior: 'smooth' });
      }, 50);
    }
  });
</script>

<div class="panel">
  <div class="toolbar">
    <div class="title-cluster">
      <HardDrive size={18} class="glow-icon" />
      <h2>Image Orchestration Engine</h2>
    </div>
    <div class="spacer"></div>
    {#if engine.processing}
      <div class="header-loader" style="margin-right: 12px;">
        <RefreshCw size={14} class="spin" />
      </div>
    {/if}
  </div>

  <div class="dashboard-grid">
    
    <!-- CARD 1: IMAGE SOURCE & MOUNT CONTROL -->
    <div class="tweak-column">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon">
            <HardDrive size={16} strokeWidth={2.5} />
          </span>
          <h3>IMAGE SOURCE & CONTROL</h3>
          {#if engine.processing}
            <div class="header-loader">
              <RefreshCw size={10} class="spin" />
            </div>
          {/if}
        </div>
        <div class="card-body config-body">
          <div class="input-field">
            <label for="iso-url">SOURCE IMAGE (ISO/WIM)</label>
            <div class="input-with-icon">
              <input id="iso-url" type="text" bind:value={engine.config.iso_url} onchange={() => engine.handleQueryImages()} />
              <button class="icon-btn" onclick={() => engine.selectFile('iso_url', 'Select Source Image', ['iso', 'wim', 'esd'])}>
                <FolderOpen size={14} />
              </button>
              <button class="icon-btn" onclick={() => engine.handleQueryImages()} disabled={engine.isQuerying}>
                {#if engine.isQuerying}
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
              <select id="wim-index" bind:value={engine.config.wim_index} class="orchestrator-select">
                {#if engine.availableImages.length === 0}
                  <option value={1}>Index 1 (Generic)</option>
                {:else}
                  {#each engine.availableImages as img}
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
                <input id="mount-path" type="text" bind:value={engine.config.mount_path} />
                <button class="icon-btn" onclick={() => engine.selectFolder('mount_path', 'Select Mount Point')}>
                  <FolderOpen size={14} />
                </button>
              </div>
            </div>
          </div>

          <div class="divider"></div>

          <div class="status-indicator" class:active={engine.status.isMounted}>
            <Box size={14} />
            <span>MOUNT STATE: {engine.status.isMounted ? 'ACTIVE' : 'DISCONNECTED'}</span>
          </div>

          {#if !engine.status.isMounted}
            <button class="action-btn primary" onclick={() => engine.handleMount()} disabled={engine.processing}>
              <Layers size={14} />
              <span>MOUNT IMAGE</span>
            </button>
          {:else}
            <div class="row-flex">
              <button class="action-btn secondary" onclick={() => engine.handleUnmount(false)} disabled={engine.processing}>
                <Save size={14} />
                <span>SAVE & COMMIT</span>
              </button>
              <button class="action-btn danger" onclick={() => engine.handleUnmount(true)} disabled={engine.processing}>
                <Trash2 size={14} />
                <span>DISCARD</span>
              </button>
            </div>

            <div class="divider"></div>

            <div class="row-flex">
              {#if !engine.status.hivesLoaded}
                <button class="action-btn outline" onclick={() => engine.handleLoadHives()} disabled={engine.processing}>
                  <Unlock size={14} />
                  <span>LOAD HIVES</span>
                </button>
              {:else}
                <button class="action-btn outline active-cyan" onclick={() => engine.handleUnloadHives()} disabled={engine.processing}>
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
            {#each engine.removals as item}
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
          
          <button class="action-btn primary" onclick={applyStripping} disabled={!engine.status.isMounted || engine.processing}>
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
              <input id="drivers-path" type="text" bind:value={engine.config.drivers_path} />
              <button class="icon-btn" onclick={() => engine.selectFolder('drivers_path', 'Select Drivers Directory')}>
                <FolderOpen size={14} />
              </button>
            </div>
          </div>

          <div class="input-field">
            <label for="updates-path">OFFLINE UPDATES (MSU/CAB)</label>
            <div class="input-with-icon">
              <input id="updates-path" type="text" bind:value={engine.config.updates_path} />
              <button class="icon-btn" onclick={() => engine.selectFolder('updates_path', 'Select Updates Directory')}>
                <FolderOpen size={14} />
              </button>
            </div>
          </div>

          <div class="divider"></div>

          <button class="action-btn primary" onclick={applyInjections} disabled={!engine.status.isMounted || engine.processing}>
            <Download size={14} />
            <span>INJECT CRITICAL ASSETS</span>
          </button>

          <button class="action-btn outline mt-8" disabled={!engine.status.isMounted}>
            <ShieldCheck size={14} />
            <span>HARDEN BOOT LOADER</span>
          </button>
        </div>
      </div>
    </div>

    <!-- FULL WIDTH BOTTOM CARD: TELEMETRY -->
    <div class="telemetry-wrapper" style="grid-column: 1 / span 3;">
      <div class="category-card full-width-card">
        <div class="card-header">
          <span class="header-icon">
            <Terminal size={16} strokeWidth={2.5} />
          </span>
          <h3>DEBLOAT ENGINE TELEMETRY</h3>
        </div>
        <div class="card-body console-body">
          <div class="console">
            {#each engine.logs as log}
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
    gap: 0;
    background: #1a1f22;
    border: 1px solid #0d1214;
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 
      0 12px 40px rgba(0, 0, 0, 0.7),
      inset 0 1px 0 rgba(255, 255, 255, 0.05);
  }

  .toolbar {
    height: 38px;
    background: rgba(18, 24, 26, 0.82);
    backdrop-filter: blur(12px);
    border-bottom: none;
    display: flex;
    align-items: center;
    padding: 0 16px;
    flex-shrink: 0;
    z-index: 1000;
    position: relative;
  }

  .toolbar::after {
    content: "";
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 1px;
    background: rgba(255, 255, 255, 0.04);
    z-index: 2;
  }

  .toolbar::before {
    content: "";
    position: absolute;
    bottom: 1px;
    left: 0;
    right: 0;
    height: 1px;
    background: rgba(0, 0, 0, 0.4);
    z-index: 1;
  }

  .dashboard-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    grid-template-rows: auto auto;
    padding: 16px;
    grid-gap: 16px;
    width: 100%;
    margin: 0;
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
    border: 1px solid #0d1214;
    border-radius: 8px;
    box-shadow: 
      0 12px 40px rgba(0, 0, 0, 0.7),
      inset 0 1px 0 rgba(255, 255, 255, 0.08); 
    display: flex;
    flex-direction: column;
  }

  .card-header {
    height: 32px;
    display: flex;
    align-items: center;
    padding: 0 14px;
    background: #181E20; 
    background-image: linear-gradient(180deg, rgba(255,255,255,0.03) 0%, transparent 100%);
    border-bottom: none;
    position: relative;
    border-radius: 8px 8px 0 0;
    gap: 8px;
  }

  .card-header::after {
    content: "";
    position: absolute;
    bottom: 0;
    left: 8%;
    right: 8%;
    height: 1px;
    background: linear-gradient(to right, transparent, rgba(255,255,255,0.04) 50%, transparent);
    z-index: 2;
  }

  .card-header::before {
    content: "";
    position: absolute;
    bottom: 1px;
    left: 8%;
    right: 8%;
    height: 1px;
    background: linear-gradient(to right, transparent, rgba(0,0,0,0.4) 50%, transparent);
    z-index: 1;
  }

  .card-header h3 {
    font-size: 10px;
    font-weight: 850;
    color: #fff;
    opacity: 0.85;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    margin: 0;
  }

  .header-icon {
    color: var(--accent-color);
  }

  .card-body {
    padding: 12px;
  }

  /* Shared config and input styles */
  .config-body {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .input-field {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .input-field.mini {
    flex: 0.8;
  }

  .input-field label {
    font-size: 8px;
    font-weight: 700;
    color: rgba(255, 255, 255, 0.4);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .input-with-icon {
    display: flex;
    gap: 4px;
  }

  input, select {
    flex: 1;
    background: rgba(0, 0, 0, 0.3);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: #fff;
    font-size: 10px;
    padding: 6px 8px;
    border-radius: 4px;
    outline: none;
    transition: all 0.2s ease;
  }

  input:focus, select:focus {
    border-color: var(--accent-color);
    background: rgba(var(--accent-rgb), 0.05);
  }

  .orchestrator-select {
    padding-right: 25px;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='10' viewBox='0 0 24 24' fill='none' stroke='rgba(255,255,255,0.4)' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 8px center;
  }

  .icon-btn {
    width: 28px;
    height: 28px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 4px;
    color: rgba(255, 255, 255, 0.6);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .icon-btn:hover:not(:disabled) {
    background: rgba(255, 255, 255, 0.1);
    color: #fff;
    border-color: rgba(255, 255, 255, 0.2);
  }

  .icon-btn:disabled {
    opacity: 0.3;
    cursor: not-allowed;
  }

  .row-flex {
    display: flex;
    gap: 8px;
    align-items: flex-end;
  }

  .divider {
    height: 2px;
    background: 
      linear-gradient(to right, transparent, rgba(0,0,0,0.5) 50%, transparent),
      linear-gradient(to right, transparent, rgba(255,255,255,0.05) 50%, transparent);
    background-size: 100% 1px;
    background-repeat: no-repeat;
    background-position: top, bottom;
    margin: 12px 0;
  }

  .action-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 8px 12px;
    border-radius: 4px;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    cursor: pointer;
    transition: all 0.2s ease;
    border: 1px solid transparent;
  }

  .action-btn.primary {
    background: var(--accent-color);
    color: #000;
  }

  .action-btn.primary:hover:not(:disabled) {
    filter: brightness(1.1);
    box-shadow: 0 0 15px rgba(var(--accent-rgb), 0.3);
  }

  .action-btn.secondary {
    background: rgba(0, 230, 118, 0.15);
    color: #00e676;
    border-color: rgba(0, 230, 118, 0.3);
    flex: 1;
  }

  .action-btn.danger {
    background: rgba(255, 61, 96, 0.15);
    color: #ff3d60;
    border-color: rgba(255, 61, 96, 0.3);
    flex: 1;
  }

  .action-btn.outline {
    background: transparent;
    border-color: rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.6);
    flex: 1;
  }

  .action-btn.active-cyan {
    border-color: var(--accent-color);
    color: var(--accent-color);
    background: rgba(var(--accent-rgb), 0.05);
  }

  .action-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .status-indicator {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 8px;
    font-weight: 800;
    color: rgba(255, 255, 255, 0.3);
    padding: 4px 0;
  }

  .status-indicator.active {
    color: #00e676;
  }

  .tweak-row {
    display: flex;
    align-items: center;
    height: 24px;
  }

  .tweak-name {
    font-size: 9px;
    font-weight: 600;
    color: rgba(255, 255, 255, 0.7);
  }

  .spacer { flex: 1; }

  .target-btn.small {
    padding: 2px 6px;
    font-size: 8px;
    min-width: 45px;
    border-radius: 3px;
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.05);
    color: rgba(255, 255, 255, 0.4);
    cursor: pointer;
  }

  .target-btn.small.active {
    background: rgba(var(--accent-rgb), 0.1);
    border-color: var(--accent-color);
    color: var(--accent-color);
  }

  .mt-8 { margin-top: 8px; }

  .console-body {
    padding: 0;
    background: rgba(0, 0, 0, 0.2);
    border-radius: 0 0 8px 8px;
  }

  .console {
    height: 120px;
    overflow-y: auto;
    padding: 10px;
    font-family: 'JetBrains Mono', 'Cascadia Code', monospace;
    font-size: 9px;
    line-height: 1.4;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .log-line {
    color: rgba(255, 255, 255, 0.6);
  }

  .timestamp {
    color: rgba(0, 230, 118, 0.5);
    margin-right: 6px;
  }

  .error-line {
    color: #ff3d60;
  }

  .header-loader {
    margin-left: auto;
    color: var(--accent-color);
  }

  .spin {
    animation: spin 1.5s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
</style>
