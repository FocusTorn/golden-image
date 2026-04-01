<script lang="ts">
  import { onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/tauri";
  import { 
    Monitor,
    Zap,
    Play,
    StopCircle,
    RefreshCw,
    Trash2,
    History,
    Mail,
    AlertCircle,
    UserCheck,
    ShieldAlert,
    Wifi,
    Key,
    HardDrive,
    ShieldCheck,
    Loader2,
    Database,
    ChevronDown
  } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";
  import TweakSelect from "./TweakSelect.svelte";
  import { vhdStore } from "./store";
  import { notificationStore } from "./notifications";

  const isTauri = (window as any).__TAURI_METADATA__ !== undefined;

  let stats: any = null;
  let masterConfig: any = null;
  let vmProfiles: string[] = [];
  let isProfileOpen = false;
  let loading = true;
  let error: string | null = null;
  let executingActions = new Set<string>();

  async function loadStats() {
    loading = true;
    error = null;
    try {
      if (isTauri) {
        stats = await invoke("get_dashboard_stats", {
          target_vm: $vhdStore.remoteActive ? $vhdStore.vmName : null
        });
      } else {
        // Mock stats for dev
        stats = {
          os_build: "22631.PRO",
          uptime: "04:12:15",
          audit_mode: true,
          Connection: {
            LimitBlank: true,
            Winrm: false,
            Keyiso: true,
            AdminEnabled: true
          },
          Stages: {
            Pwsh7: true,
            Msvc: false,
            AppInfra: true
          }
        };
      }
    } catch (e) {
      error = typeof e === "string" ? e : JSON.stringify(e);
    } finally {
      loading = false;
    }
  }

  async function loadMasterConfig() {
    try {
      if (isTauri) {
        masterConfig = await invoke("get_master_config");
        vmProfiles = Object.keys(masterConfig.VMProfiles);
        
        // Sync initial state if a profile is already selected globally
        const currentProfile = $vhdStore.selectedProfile;
        if (currentProfile && !vmProfiles.includes(currentProfile)) {
          // Profile exists but perhaps config reloaded
        }
      } else {
        vmProfiles = ["Pro-Gaming", "Workstation-Ultra", "Server-Core"];
      }
    } catch (e) {
      console.error("Master config failed load on dashboard:", e);
    }
  }

  function handleProfileChange(selected: string) {
    const profile = masterConfig?.VMProfiles[selected];
    if (profile) {
      vhdStore.update(s => ({
        ...s,
        vhdPath: profile.VMDetails?.OsVhdPath || masterConfig.VMFileSystem.HostVhdPath,
        vmName: profile.VMDetails?.VMName || "",
        selectedProfile: selected
      }));
    }
  }

  function toggleProfile(e: any) {
    // e is the Svelte CustomEvent, detail is the MouseEvent
    if (e && e.detail && e.detail.stopPropagation) e.detail.stopPropagation();
    isProfileOpen = !isProfileOpen;
  }

  function selectProfile(p: string) {
    handleProfileChange(p);
    isProfileOpen = false;
  }

  async function runAction(actionId: string, isToggle = false) {
    if (executingActions.has(actionId)) return;
    executingActions.add(actionId);
    executingActions = executingActions; 

    try {
      if (isTauri) {
        await invoke("apply_feature", { 
          feature_id: actionId, 
          offline_hive: null,
          remote_active: $vhdStore.remoteActive,
          target_vm: $vhdStore.vmName || null
        });
        await loadStats();
      } else {
        await new Promise(r => setTimeout(r, 1000));
        if (isToggle && stats?.Connection) {
          // Mock toggle logic
          const map: any = {
            "LimitBlank": "LimitBlank",
            "WinRM": "Winrm",
            "KeyIso": "Keyiso",
            "AdminAccount": "AdminEnabled"
          };
          const key = map[actionId];
          if (key) stats.Connection[key] = !stats.Connection[key];
        }
      }
    } catch (e) {
      console.error(`Action ${actionId} failed:`, e);
    } finally {
      executingActions.delete(actionId);
      executingActions = executingActions;
    }
  }

  // VHD CONTEXT (Global Synchronization)
  let vhdState: import("./store").VhdState;
  vhdStore.subscribe(state => { vhdState = state; });

  async function handleVhdTransition(target: string) {
    if (!vhdState.vhdPath || vhdState.processing) return;
    if (target === "VM" && !vhdState.vmName) return;

    vhdStore.update(s => ({ ...s, processing: true }));
    try {
      if (isTauri) {
        const info: any = await invoke("transition_vhd", { 
          target, 
          vhdPath: vhdState.vhdPath, 
          vmName: vhdState.vmName || null 
        });
        
        if (target === "Host") {
          vhdStore.update(s => ({ ...s, vhdMounted: info.Attached, vhdDiskNumber: info.DiskNumber, vhdAttached: false }));
        } else {
          vhdStore.update(s => ({ ...s, vhdAttached: info.Attached, vhdMounted: false, vhdDiskNumber: null }));
        }
      } else {
        await new Promise(r => setTimeout(r, 1000));
        vhdStore.update(s => ({ 
          ...s, 
          vhdMounted: target === "Host", 
          vhdAttached: target === "VM",
          vhdDiskNumber: target === "Host" ? 3 : null
        }));
      }
      notificationStore.add(`VHD active on ${target}.`, "success");
    } catch (e: any) {
      notificationStore.add(`VHD Error: ${e}`, "error");
    } finally {
      vhdStore.update(s => ({ ...s, processing: false }));
    }
  }

  async function handleVhdRelease() {
    if (!vhdState.vhdPath || vhdState.processing) return;
    vhdStore.update(s => ({ ...s, processing: true }));
    try {
      if (isTauri) {
        await invoke("unmount_vhd", { vhdPath: vhdState.vhdPath });
        if (vhdState.vmName) await invoke("detach_vhd_from_vm", { vhdPath: vhdState.vhdPath, vmName: vhdState.vmName });
        vhdStore.update(s => ({ ...s, vhdMounted: false, vhdAttached: false, vhdDiskNumber: null }));
      } else {
        await new Promise(r => setTimeout(r, 500));
        vhdStore.update(s => ({ ...s, vhdMounted: false, vhdAttached: false, vhdDiskNumber: null }));
      }
      notificationStore.add("VHD released.", "info");
    } catch (e) {
      notificationStore.add("Release failed.", "error");
    } finally {
      vhdStore.update(s => ({ ...s, processing: false }));
    }
  }

  onMount(async () => {
    await loadStats();
    await loadMasterConfig();
  });

  // Automatically refresh stats when the environment target changes
  $: if ($vhdStore.remoteActive !== undefined || $vhdStore.vhdAttached !== undefined) {
     loadStats();
  }

  // Safety Reset: If VM context is lost, force Remoting OFF
  $: if (!$vhdStore.vmName && $vhdStore.remoteActive) {
    vhdStore.update(s => ({ ...s, remoteActive: false }));
  }
</script>

<svelte:window on:click={() => isProfileOpen = false} />

<div class="panel">
  <div class="dashboard-grid">
    <!-- COLUMN 1: SYSTEM & SESSION SNAPSHOT -->
    <div class="tweak-column">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon">
            <Monitor size={16} strokeWidth={3.5} />
          </span>
          <h3>SYSTEM & SESSION SNAPSHOT</h3>
        </div>
        
        <div class="card-body">
          <div class="stats-hub">
            <div class="stat-row">
              <div class="stat-label">HOST OS BUILD</div>
              <div class="stat-value">{stats?.OsBuild || "22631.PRO"}</div>
            </div>
            <div class="stat-row">
              <div class="stat-label">HOST UPTIME</div>
              <div class="stat-value">{stats?.Uptime || "00:00:00"}</div>
            </div>
          </div>

          <div class="divider"></div>

          <div class="stats-hub">
            <div class="stat-row">
              <div class="stat-label">ACTIVE VHD</div>
              <div class="stat-value truncate" title={vhdState.vhdPath || 'No VHD Loaded'}>
                {vhdState.vhdPath ? vhdState.vhdPath.split(/[\\/]/).pop() : 'NONE'}
              </div>
            </div>
            <div class="stat-row">
              <div class="stat-label">IMAGE AUDIT MODE</div>
              <div class="stat-badge" class:active={stats?.AuditMode}>
                {stats?.AuditMode ? 'YES' : 'NO'}
              </div>
            </div>
            <div class="stat-row">
              <div class="stat-label">BUILD TARGET</div>
              <div class="stat-badge vhd-status" class:host-active={vhdState.vhdMounted} class:vm-active={vhdState.vhdAttached}>
                {#if vhdState.vhdMounted}
                  LOCAL (HOST)
                {:else if vhdState.vhdAttached}
                  REMOTE ({vhdState.vmName || 'VM'})
                {:else}
                  DECOUPLED
                {/if}
              </div>
            </div>
          </div>

          <div class="divider"></div>

          <!-- SESSION AUDIT ITEMS (4 Items) -->
          <div class="tweak-row status-row" style="--status-color: {stats?.Connection?.LimitBlank ? 'var(--risk-safe)' : 'var(--risk-unsafe)'}">
            <span class="tweak-name">LSA Admin Passwords</span>
            <div class="spacer"></div>
            <button 
              class="bloom-select" 
              class:deactivate={stats?.Connection?.LimitBlank}
              class:activate={!stats?.Connection?.LimitBlank}
              class:executing={executingActions.has('LimitBlank')}
              on:click={() => runAction('LimitBlank', true)}
            >
              {#if executingActions.has('LimitBlank')}
                 <RefreshCw size={10} class="spin" />
              {:else}
                 {stats?.Connection?.LimitBlank ? 'DEACTIVATE' : 'ACTIVATE'}
              {/if}
            </button>
          </div>

          <div class="tweak-row status-row" style="--status-color: {stats?.Connection?.Winrm ? 'var(--risk-safe)' : 'var(--risk-unsafe)'}">
            <span class="tweak-name">WinRM Management Stack</span>
            <div class="spacer"></div>
            <button 
              class="bloom-select" 
              class:deactivate={stats?.Connection?.Winrm}
              class:activate={!stats?.Connection?.Winrm}
              class:executing={executingActions.has('WinRM')}
              on:click={() => runAction('WinRM', true)}
            >
              {#if executingActions.has('WinRM')}
                 <RefreshCw size={10} class="spin" />
              {:else}
                 {stats?.Connection?.Winrm ? 'DEACTIVATE' : 'ACTIVATE'}
              {/if}
            </button>
          </div>

          <div class="tweak-row status-row" style="--status-color: {stats?.Connection?.Keyiso ? 'var(--risk-safe)' : 'var(--risk-unsafe)'}">
            <span class="tweak-name">Isolated Key Service (KeyIso)</span>
            <div class="spacer"></div>
            <button 
              class="bloom-select" 
              class:deactivate={stats?.Connection?.Keyiso}
              class:activate={!stats?.Connection?.Keyiso}
              class:executing={executingActions.has('KeyIso')}
              on:click={() => runAction('KeyIso', true)}
            >
              {#if executingActions.has('KeyIso')}
                 <RefreshCw size={10} class="spin" />
              {:else}
                 {stats?.Connection?.Keyiso ? 'DEACTIVATE' : 'ACTIVATE'}
              {/if}
            </button>
          </div>

          <div class="tweak-row status-row" style="--status-color: {stats?.Connection?.AdminEnabled ? 'var(--risk-safe)' : 'var(--risk-unsafe)'}">
            <span class="tweak-name">Local Admin Account State</span>
            <div class="spacer"></div>
            <button 
              class="bloom-select" 
              class:deactivate={stats?.Connection?.AdminEnabled}
              class:activate={!stats?.Connection?.AdminEnabled}
              class:executing={executingActions.has('AdminAccount')}
              on:click={() => runAction('AdminAccount', true)}
            >
              {#if executingActions.has('AdminAccount')}
                 <RefreshCw size={10} class="spin" />
              {:else}
                 {stats?.Connection?.AdminEnabled ? 'DEACTIVATE' : 'ACTIVATE'}
              {/if}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- COLUMN 2: OPERATIONAL QUICK-ACTIONS -->
    <div class="tweak-column">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon">
            <Zap size={16} strokeWidth={3.5} />
          </span>
          <h3>OPERATIONAL QUICK-ACTIONS</h3>
        </div>
        
        <div class="card-body">
          <div class="action-item tweak-row">
            <span class="tweak-name">Clear All Pinned Start Apps</span>
            <div class="spacer"></div>
            <button 
              class="zap-btn" 
              class:executing={executingActions.has('ClearStart')}
              on:click={() => runAction('ClearStart')}
            >
              {#if executingActions.has('ClearStart')}
                <RefreshCw size={12} class="spin" />
              {:else}
                <Play size={10} fill="currentColor" />
              {/if}
            </button>
          </div>

          <div class="action-item tweak-row">
            <span class="tweak-name">Create System Restore Point</span>
            <div class="spacer"></div>
            <button 
              class="zap-btn" 
              class:executing={executingActions.has('CreateRestorePoint')}
              on:click={() => runAction('CreateRestorePoint')}
            >
              {#if executingActions.has('CreateRestorePoint')}
                <RefreshCw size={12} class="spin" />
              {:else}
                <History size={11} strokeWidth={2.5} />
              {/if}
            </button>
          </div>

          <div class="action-item tweak-row">
            <span class="tweak-name">Scrub Communication Apps</span>
            <div class="spacer"></div>
            <button 
              class="zap-btn" 
              class:executing={executingActions.has('RemoveCommApps')}
              on:click={() => runAction('RemoveCommApps')}
            >
              {#if executingActions.has('RemoveCommApps')}
                <RefreshCw size={12} class="spin" />
              {:else}
                <Mail size={11} strokeWidth={2.5} />
              {/if}
            </button>
          </div>

          <div class="action-item tweak-row">
            <span class="tweak-name">Remove HP OEM Bloat</span>
            <div class="spacer"></div>
            <button 
              class="zap-btn" 
              class:executing={executingActions.has('RemoveHPApps')}
              on:click={() => runAction('RemoveHPApps')}
            >
              {#if executingActions.has('RemoveHPApps')}
                <RefreshCw size={12} class="spin" />
              {:else}
                <Trash2 size={11} strokeWidth={2.5} />
              {/if}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- COLUMN 3: VHD & VM ECOSYSTEM -->
    <div class="tweak-column">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon">
            <Database size={16} strokeWidth={3.5} />
          </span>
          <h3>VHD & VM HUB</h3>
        </div>
        
        <div class="card-body">
          <div class="profile-selector-group">
            <div class="stat-label">IMAGE BUILD PROFILE</div>
            <div class="custom-select-container">
              <BloomControl
                width="100%"
                active={isProfileOpen}
                on:click={toggleProfile}
                style="padding: 0 10px; justify-content: flex-start !important; height: 32px; border-radius: 4px;"
              >
                <span class="select-label truncate">
                  {vhdState.selectedProfile || 'SELECT PROFILE...'}
                </span>
                <div class="chevron-wrapper" class:open={isProfileOpen}>
                  <ChevronDown size={14} />
                </div>
              </BloomControl>

              {#if isProfileOpen}
                <div class="dropdown-list">
                  {#each vmProfiles as p}
                    <button
                      class="dropdown-item"
                      class:active={vhdState.selectedProfile === p}
                      on:click|stopPropagation={() => selectProfile(p)}
                    >
                      {p}
                    </button>
                  {/each}
                </div>
              {/if}
            </div>
          </div>

          <div class="divider"></div>

          <!-- REMOTE PROVISIONING MODE -->
          <div class="stat-row remote-toggle-row">
            <div class="stat-label">REMOTE TARGET</div>
            <button 
              class="bloom-select remote-btn" 
              class:active={vhdState.remoteActive}
              disabled={!vhdState.vmName}
              title={!vhdState.vmName ? "Select an Image Profile to unlock Remote mode" : ""}
              on:click={() => vhdStore.update(s => ({ ...s, remoteActive: !s.remoteActive }))}
            >
              {vhdState.remoteActive ? 'ACTIVE (VM)' : 'OFF (LOCAL)'}
            </button>
          </div>

          <div class="vhd-control-grid">
            <button 
              class="vhd-action-btn host" 
              class:active={vhdState.vhdMounted} 
              disabled={vhdState.processing || !vhdState.vhdPath}
              on:click={() => handleVhdTransition('Host')}
            >
              {#if vhdState.processing}
                <Loader2 size={12} class="spin" />
              {:else}
                <HardDrive size={14} />
                <span>MOUNT HOST</span>
              {/if}
            </button>

            <button 
              class="vhd-action-btn vm" 
              class:active={vhdState.vhdAttached} 
              disabled={vhdState.processing || !vhdState.vhdPath || !vhdState.vmName}
              on:click={() => handleVhdTransition('VM')}
            >
              {#if vhdState.processing}
                <Loader2 size={12} class="spin" />
              {:else}
                <ShieldCheck size={14} />
                <span>ATTACH VM</span>
              {/if}
            </button>

            <button 
              class="vhd-action-btn release full-width" 
              disabled={vhdState.processing || (!vhdState.vhdMounted && !vhdState.vhdAttached)}
              on:click={handleVhdRelease}
            >
              <AlertCircle size={14} />
              <span>RELEASE ALL HANDLES</span>
            </button>
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
    padding: 12px 12px 12px 24px;
    gap: 8px;
    overflow: hidden;
    background: transparent;

    /* UNIFIED RISK PALETTE */
    --risk-safe: #00e676;
    --risk-unsafe: #ff3d60;
    --risk-unknown: rgba(0, 0, 0, 0.35);
  }

  .dashboard-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    grid-gap: 16px;
    padding: 16px;
    overflow-y: auto;
    flex: 1;
    scrollbar-gutter: stable;
    align-items: flex-start;
  }

  .tweak-column {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  /* REPRODUCED TWEAK CARD STYLING */
  .category-card {
    width: 100%;
    background: #1a1f22; /* Calibrated slate charcoal */
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    box-shadow: 
      0 12px 40px rgba(0, 0, 0, 0.7),
      inset 0 1px 1px rgba(255, 255, 255, 0.02); 
    overflow: hidden;
    flex-shrink: 0;
  }

  .card-header {
    height: 36px;
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
    text-shadow: 0 2px 10px rgba(0, 0, 0, 0.8);
  }

  .header-icon {
    margin-right: 12px;
    color: var(--accent-color);
  }

  .card-body {
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .tweak-row {
    position: relative;
    display: flex;
    align-items: center;
    height: 31px;
    padding: 0 12px;
    font-size: 11px;
    background: #242a2d; 
    border: 1px solid rgba(255, 255, 255, 0.04);
    border-radius: 5px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
    cursor: default;
  }

  .tweak-name {
    font-size: 10.5px;
    color: rgba(255, 255, 255, 0.7);
    font-weight: 500;
  }

  .spacer { flex: 1; }

  /* Stats Styling */
  .stats-hub {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 4px;
    margin-bottom: 4px;
  }

  .stat-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .stat-label {
    font-size: 9px;
    font-weight: 900;
    color: rgba(255, 255, 255, 0.3);
    letter-spacing: 0.15em;
  }

  .stat-value {
    font-size: 11.5px;
    font-weight: 500;
    color: rgba(255, 255, 255, 0.85);
    letter-spacing: -0.01em;
  }

  .stat-badge {
    font-size: 9px;
    font-weight: 900;
    padding: 3px 6px;
    border-radius: 4px;
    background: rgba(255, 255, 255, 0.05);
    color: rgba(255, 255, 255, 0.4);
  }

  .stat-badge.active {
    background: var(--accent-color);
    color: #000;
    box-shadow: 0 0 12px rgba(var(--accent-rgb), 0.3);
    font-weight: 800;
  }

  .vhd-status {
     font-weight: 700;
     border-radius: 4px;
     padding: 2px 8px;
  }

  .divider {
    height: 1px;
    background: rgba(255, 255, 255, 0.05);
    margin: 8px 0;
  }

  /* Industrial Status Tube logic - Parity with Tweaks */
  .status-row::before {
    content: '';
    position: absolute;
    left: 0;
    top: 5px;
    bottom: 5px;
    width: 4px;
    background: var(--status-color, var(--risk-unknown));
    opacity: 1;
    filter: blur(0.3px);
    box-shadow: 
      0 0 12px var(--status-color, var(--risk-unknown)),
      inset 0 1px 2px rgba(255, 255, 255, 0.05); 
    z-index: 2;
    border-radius: 0 2px 2px 0;
  }

  /* Bloom Select Interaction Pills - Synchronized with Apps/Tweaks */
  .bloom-select {
    padding: 2px 10px;
    height: 22px;
    border-radius: 4px;
    font-size: 8.5px;
    font-weight: 800;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 70px;
    outline: none;
    background: rgba(255, 255, 255, 0.02);
    border: 1px solid rgba(255, 255, 255, 0.05);
    color: rgba(255, 255, 255, 0.4);
  }

  .bloom-select.activate {
    border-color: rgba(0, 188, 212, 0.2);
    background: rgba(0, 188, 212, 0.05);
    color: #00bcd4;
  }
  .bloom-select.activate:hover:not(.executing) {
    background: #00bcd4;
    color: #000;
    box-shadow: 0 0 12px #00bcd4;
  }

  .bloom-select.deactivate {
    border-color: rgba(255, 61, 96, 0.2);
    background: rgba(255, 61, 96, 0.05);
    color: #ff3d60;
  }
  .bloom-select.deactivate:hover:not(.executing) {
    background: #ff3d60;
    color: #fff;
    box-shadow: 0 0 12px #ff3d60;
  }

  .bloom-select.executing {
    cursor: wait;
    opacity: 0.5;
  }

  /* Action Buttons (The Zap) for Column 2 */
  .zap-btn {
    width: 22px;
    height: 22px;
    border: 1px solid rgba(0, 188, 212, 0.2);
    background: rgba(0, 188, 212, 0.05);
    color: #00bcd4;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s;
  }

  .profile-selector-group {
    display: flex;
    flex-direction: column;
    gap: 4px;
    margin-bottom: 12px;
  }

  /* DROPDOWN PARITY WITH TACTICAL TOOLBAR */
  .custom-select-container {
    position: relative;
    display: flex;
    align-items: center;
  }

  .select-label {
    font-size: 11px;
    font-weight: 800;
    color: var(--accent-color);
    letter-spacing: 0.05em;
    text-transform: uppercase;
  }

  .chevron-wrapper {
    margin-left: auto;
    opacity: 0.6;
    color: var(--accent-color);
    transition: transform 0.2s;
    display: flex;
    align-items: center;
  }

  .chevron-wrapper.open {
    transform: rotate(180deg);
  }

  .dropdown-list {
    position: absolute;
    top: calc(100% + 4px);
    left: 0;
    min-width: 100%;
    background: #1a1f22;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 4px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.8);
    z-index: 5000;
    display: flex;
    flex-direction: column;
    padding: 6px;
    overflow: hidden;
  }

  .dropdown-item {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.6);
    padding: 8px 12px;
    text-align: left;
    font-size: 10.5px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    border-radius: 4px;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.2s;
  }

  .dropdown-item.active {
    background: rgba(var(--accent-rgb), 0.15);
    color: var(--accent-color);
    border: 1px solid rgba(var(--accent-rgb), 0.3);
  }

  .dropdown-item:hover:not(.active) {
    background: rgba(255, 255, 255, 0.05);
    color: #fff;
  }

  .stat-value.truncate {
    max-width: 180px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .vhd-status {
    min-width: 100px;
    text-align: center;
  }

  .vhd-status.host-active {
    background: rgba(79, 185, 149, 0.2);
    color: #4fb995;
    border: 1px solid rgba(79, 185, 149, 0.3);
  }

  .vhd-status.vm-active {
    background: rgba(0, 188, 212, 0.2);
    color: #00bcd4;
    border: 1px solid rgba(0, 188, 212, 0.3);
  }

  .remote-toggle-row {
     margin: 6px 0 10px 0;
     background: rgba(0, 188, 212, 0.05);
     padding: 8px;
     border-radius: 4px;
     border: 1px dashed rgba(0, 188, 212, 0.2);
  }

  .remote-btn {
     width: 100px;
     transition: all 0.3s;
  }

  .remote-btn.active {
     background: #00bcd4;
     color: #000;
     box-shadow: 0 0 15px rgba(0, 188, 212, 0.6);
     border-color: #00bcd4;
  }

  .vhd-control-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    grid-gap: 8px;
    margin-top: 4px;
  }

  .vhd-action-btn {
    height: 32px;
    background: #242a2d;
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 4px;
    color: rgba(255, 255, 255, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    font-size: 9px;
    font-weight: 800;
    letter-spacing: 0.1em;
    cursor: pointer;
    transition: all 0.2s;
  }

  .vhd-action-btn.full-width {
    grid-column: span 2;
  }

  .vhd-action-btn:hover:not(:disabled) {
    background: rgba(255, 255, 255, 0.08);
    color: #fff;
  }

  .vhd-action-btn.active.host {
    background: rgba(79, 185, 149, 0.1);
    color: #4fb995;
    border-color: rgba(79, 185, 149, 0.3);
  }

  .vhd-action-btn.active.vm {
    background: rgba(0, 188, 212, 0.1);
    color: #00bcd4;
    border-color: rgba(0, 188, 212, 0.3);
  }

  .vhd-action-btn.release:hover:not(:disabled) {
    background: rgba(255, 61, 96, 0.1);
    color: #ff3d60;
    border-color: rgba(255, 61, 96, 0.3);
  }

  .vhd-action-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .vhd-action-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }
</style>
