<script lang="ts">
  import { onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/tauri";
  import { 
    Monitor, Zap, Play, StopCircle, RefreshCw, Trash2, History, Mail, AlertCircle, UserCheck, ShieldAlert,
    Wifi, Key, HardDrive, ShieldCheck, Loader2, Database, ChevronDown, Shield, CheckCircle2, WifiOff,
    XCircle, Globe, Search, Download, LayoutGrid, Cpu, MemoryStick, ArrowRight, Lock, Unlock, Save, LayoutDashboard, Layers, Box
  } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";
  import TweakSelect from "./TweakSelect.svelte";
  import TacticalContainer from "./TacticalContainer.svelte";
  import { vhdStore, settings } from "./store";
  import { notificationStore } from "./notifications";
  import { OrchestratorEngine } from "./orchestrator-engine.svelte";

  const engine = new OrchestratorEngine();

  const isTauri = (window as any).__TAURI_METADATA__ !== undefined;

  let hostStats = $state<any>(null);
  let vmStats = $state<any>(null);
  let masterConfig = $state<any>(null);
  let vmProfiles = $state<string[]>([]);
  let currentOsVhd = $state("");
  let isProfileOpen = $state(false);
  let loading = $state(true);
  let error = $state<string | null>(null);
  let executingActions = $state(new Set<string>());
  let vmStatuses = $state<Record<string, string>>({});
  let statusLoading = $state(true);

  let envModeOpen = $state(false);
  const envModes: (typeof $settings.environmentTarget)[] = ['Local Image', 'VHD & VM', 'Local'];

  function toggleEnvMode(e?: Event) {
    if (e) e.stopPropagation();
    envModeOpen = !envModeOpen;
    if (envModeOpen) isProfileOpen = false;
  }

  function handleWindowClick() {
    envModeOpen = false;
    isProfileOpen = false;
  }

  async function loadStats() {
    loading = true;
    error = null;
    
    try {
      if (isTauri) {
        try {
          hostStats = await invoke("get_dashboard_stats", { target_vm: null });
        } catch (e) {
          console.error("Host Stats Audit Failed:", e);
          error = `Host Sync Error: ${e}`;
        }

        if ($vhdStore.remoteActive && $vhdStore.vmName) {
          try {
            vmStats = await invoke("get_dashboard_stats", { target_vm: $vhdStore.vmName });
          } catch (e) {
            console.error("VM Stats Audit Failed:", e);
            notificationStore.add(`Remote Target Unreachable: ${e}`, "error");
            vhdStore.update(s => ({ ...s, remoteActive: false }));
          }
        }
      } else {
        hostStats = { 
          os_build: "22631.PRO", 
          uptime: "04:12:15", 
          audit_mode: true,
          Connection: { LimitBlank: true, Winrm: false, AdminEnabled: true }
        };
        vmStats = $vhdStore.remoteActive ? { 
          os_build: "22631.PRO", 
          uptime: "00:05:22", 
          audit_mode: true,
          Connection: { LimitBlank: false, Winrm: true, AdminEnabled: false }
        } : null;
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
        await loadVmStatuses();
        if (!$vhdStore.selectedProfile && masterConfig.defaultVMProfile) {
          handleProfileChange(masterConfig.defaultVMProfile);
        }
      } else {
        vmProfiles = ["Pro-Gaming", "Workstation-Ultra", "Server-Core"];
      }
    } catch (e) {
      console.error("Master config failed load on dashboard:", e);
    }
  }

  async function loadVmStatuses() {
    if (!isTauri || vmProfiles.length === 0) return;
    statusLoading = true;
    try {
      const names = vmProfiles.map(p => masterConfig?.VMProfiles[p]?.VMDetails?.VMName).filter(Boolean);
      const statuses: any = await invoke("get_vhd_hub_statuses", { vmNames: names });
      const mapped: Record<string, string> = {};
      for (const p of vmProfiles) {
        const vmName = masterConfig?.VMProfiles[p]?.VMDetails?.VMName;
        mapped[p] = statuses[vmName] || "Missing";
      }
      vmStatuses = mapped;
    } catch (e) {
      console.error("Failed to load VM statuses:", e);
    } finally {
      statusLoading = false;
    }
  }

  function handleProfileChange(selected: string) {
    const profile = masterConfig?.VMProfiles[selected];
    if (profile) {
      vhdStore.update(s => ({
        ...s,
        vhdPath: masterConfig.VMFileSystem.HostVhdPath, 
        vmName: profile.VMDetails?.VMName || "",
        selectedProfile: selected
      }));
      currentOsVhd = profile.VMDetails?.OsVhdPath || "";
    }
  }

  function toggleProfile(e?: MouseEvent) {
    if (e) e.stopPropagation();
    isProfileOpen = !isProfileOpen;
  }

  function selectProfile(p: string) {
    handleProfileChange(p);
    isProfileOpen = false;
  }

  async function runAction(actionId: string, targetVm: string | null = null, stateKey: string | null = null) {
    const key = actionId + (targetVm ? '-VM' : '-Host');
    if (executingActions.has(key)) return;

    const stats = targetVm ? vmStats : hostStats;
    const currentVal = stats?.Connection?.[stateKey || actionId];
    const cmd = currentVal ? "undo_feature" : "apply_feature";

    executingActions.add(key);
    executingActions = new Set(executingActions);

    try {
      if (isTauri) {
        await invoke(cmd, { featureId: actionId, targetVm: targetVm });
        await loadStats();
      } else {
        await new Promise(r => setTimeout(r, 1000));
      }
    } catch (e) {
      const errorMsg = typeof e === 'object' ? (e as any).message || JSON.stringify(e) : String(e);
      notificationStore.add(`Policy Update Failed: ${errorMsg}`, "error");
    } finally {
      executingActions.delete(key);
      executingActions = new Set(executingActions);
    }
  }

  async function handleVhdTransition(target: string) {
    if (!$vhdStore.vhdPath || $vhdStore.processing) return;
    if (target === "VM" && !$vhdStore.vmName) return;

    vhdStore.update(s => ({ ...s, processing: true }));
    try {
      if (isTauri) {
        const info: any = await invoke("transition_vhd", { target, vhdPath: $vhdStore.vhdPath, vmName: $vhdStore.vmName || null });
        if (target === "Host") {
          vhdStore.update(s => ({ ...s, vhdMounted: info.Attached, vhdDiskNumber: info.DiskNumber, vhdAttached: false }));
        } else {
          vhdStore.update(s => ({ ...s, vhdAttached: info.Attached, vhdMounted: false, vhdDiskNumber: null }));
        }
      } else {
        await new Promise(r => setTimeout(r, 1000));
        vhdStore.update(s => ({ ...s, vhdMounted: target === "Host", vhdAttached: target === "VM", vhdDiskNumber: target === "Host" ? 3 : null }));
      }
      notificationStore.add(`VHD active on ${target}.`, "success");
    } catch (e: any) {
      notificationStore.add(`VHD Error: ${e.message || JSON.stringify(e)}`, "error");
    } finally {
      vhdStore.update(s => ({ ...s, processing: false }));
    }
  }

  async function handleVhdRelease() {
    if (!$vhdStore.vhdPath || $vhdStore.processing) return;
    vhdStore.update(s => ({ ...s, processing: true }));
    try {
      if (isTauri) {
        await invoke("unmount_vhd", { vhdPath: $vhdStore.vhdPath });
        if ($vhdStore.vmName) await invoke("detach_vhd_from_vm", { vhdPath: $vhdStore.vhdPath, vmName: $vhdStore.vmName });
        vhdStore.update(s => ({ ...s, vhdMounted: false, vhdAttached: false, vhdDiskNumber: null }));
      } else {
        await new Promise(r => setTimeout(r, 500));
        vhdStore.update(s => ({ ...s, vhdMounted: false, vhdAttached: false, vhdDiskNumber: null }));
      }
      notificationStore.add("VHD released.", "info");
    } catch (e: any) {
      notificationStore.add(`Release failed: ${e.message || JSON.stringify(e)}`, "error");
    } finally {
      vhdStore.update(s => ({ ...s, processing: false }));
    }
  }

  async function toggleRemote() {
    if (loading) return;
    const targetState = !$vhdStore.remoteActive;
    if (targetState && !$vhdStore.vmName) {
      notificationStore.add("Activation Failed: No VM profile selected.", "error");
      return;
    }
    if (targetState) {
      try {
        const state = await invoke("check_vm_status", { vmName: $vhdStore.vmName });
        if (state !== "Running") {
          notificationStore.add(`Activation Blocked: VM ['${$vhdStore.vmName}'] is currently ${state}.`, "error");
          return;
        }
      } catch (e) {
        notificationStore.add(`Activation Error: ${e}`, "error");
        return;
      }
    }
    vhdStore.update(s => ({ ...s, remoteActive: targetState }));
  }

  onMount(async () => {
    await loadStats();
    await loadMasterConfig();
  });

  $effect(() => {
    // Reactive synchronization
    if ($vhdStore.remoteActive !== undefined || $vhdStore.vhdAttached !== undefined || $vhdStore.selectedProfile !== undefined) {
      loadStats();
    }
  });

  $effect(() => {
    if (!$vhdStore.vmName && $vhdStore.remoteActive) {
      vhdStore.update(s => ({ ...s, remoteActive: false }));
    }
  });

  function selectEnvMode(mode: typeof $settings.environmentTarget) {
    settings.update(s => ({ ...s, environmentTarget: mode }));
    envModeOpen = false;
  }
</script>

<svelte:window onclick={handleWindowClick} />

<div class="panel">
  <div class="toolbar">
    <div class="title-cluster">
      <LayoutDashboard size={18} class="glow-icon" />
      <h2>OVERVIEW & TARGETS</h2>
    </div>
    <div class="spacer"></div>
    
    <div 
      class="env-mode-selector" 
      style="position: relative; width: 155px; z-index: 1000;" 
      onclick={(e) => e.stopPropagation()} 
      onkeydown={(e) => e.key === 'Enter' && toggleEnvMode(e)}
      role="button"
      tabindex="0"
    >
      <BloomControl
        width="100%"
        active={envModeOpen}
        onclick={toggleEnvMode}
        style="padding: 0 10px; justify-content: flex-start !important; height: 26px; border-radius: 4px; background: rgba(255,255,255,0.05);"
      >
        <span class="select-label" style="font-size: 10px; line-height: 1; color: var(--accent-color);">{$settings.environmentTarget || 'Local Image'}</span>
        <div class="chevron-wrapper" class:open={envModeOpen} style="margin-left: auto;">
          <ChevronDown size={14} color="var(--accent-color)" />
        </div>
      </BloomControl>

      {#if envModeOpen}
        <div class="dropdown-list" style="top: 32px;">
          {#each envModes as mode}
            <button
              class="dropdown-item"
              class:active={$settings.environmentTarget === mode}
              onclick={(e) => { e.stopPropagation(); selectEnvMode(mode); }}
            >
              {mode}
            </button>
          {/each}
        </div>
      {/if}
    </div>
  </div>

  <div style="display: contents;">
    <TacticalContainer padding="12px 16px">
      <div class="dashboard-grid">
        <!-- FULL WIDTH TOP CARD: ENVIRONMENT OVERVIEW -->
    <div class="overview-header-card" style="grid-column: 2 / span 2; grid-row: 1;">
      <div class="category-card full-width-card">
        <div class="card-header">
          <span class="header-icon">
            <ShieldCheck size={16} strokeWidth={3.5} />
          </span>
          <h3>ENVIRONMENT OVERVIEW HUB</h3>
          
          <div class="spacer"></div>
          
          <div class="header-loader" style="margin-right: 12px; margin-left: 0;">
            {#if loading}
              <Loader2 size={10} class="spin" />
            {/if}
          </div>
        </div>
        
        <div class="card-body overview-body">
          {#if $settings.environmentTarget === 'VHD & VM'}
          <!-- VM-HOST DUAL VIEW -->
          <div class="env-section host-side">
            <div class="section-label">
              <HardDrive size={14} strokeWidth={2.5} />
              <span>LINKED HOST</span>
            </div>
            {#if hostStats}
              <div class="env-stats">
                <div class="env-stat">
                  <span class="label">OS BUILD</span>
                  <span class="value">{hostStats.os_build || '---'}</span>
                </div>
                <div class="env-stat">
                  <span class="label">UPTIME</span>
                  <span class="value">{hostStats.uptime || '00:00:00'}</span>
                </div>
                <div class="env-stat">
                  <span class="label">AUDIT MODE</span>
                  <span class="status-pill" class:active={hostStats.audit_mode}>
                    {hostStats.audit_mode ? 'ARMED' : 'OFF'}
                  </span>
                </div>
              </div>
            {/if}
          </div>

          <div class="env-divider"></div>

          <div class="env-section vm-side" class:disconnected={!$vhdStore.remoteActive}>
            <div class="section-label">
              <Monitor size={14} strokeWidth={2.5} />
              <span>REMOTE VM TARGET</span>
            </div>
            {#if $vhdStore.remoteActive && vmStats}
              <div class="env-stats">
                <div class="env-stat">
                  <span class="label">OS BUILD</span>
                  <span class="value">{vmStats.os_build || '---'}</span>
                </div>
                <div class="env-stat">
                  <span class="label">UPTIME</span>
                  <span class="value">{vmStats.uptime || '00:00:00'}</span>
                </div>
                <div class="env-stat">
                  <span class="label">AUDIT MODE</span>
                  <span class="status-pill" class:active={vmStats.audit_mode}>
                    {vmStats.audit_mode ? 'ARMED' : 'OFF'}
                  </span>
                </div>
              </div>
            {:else}
              <div class="disconnected-overlay">
                <WifiOff size={24} class="dim-icon" strokeWidth={1.5} />
                <span class="dim-text">TARGET DECOUPLED</span>
              </div>
            {/if}
          </div>
          {:else if $settings.environmentTarget === 'Local'}
            <!-- LOCAL HOST PRIMARY VIEW -->
            <div class="env-section host-side" style="flex: 2;">
              <div class="section-label">
                <HardDrive size={14} strokeWidth={2.5} />
                <span>LOCAL HOST SYSTEM (PRIMARY TARGET)</span>
              </div>
              {#if hostStats}
                <div class="env-stats" style="grid-template-columns: repeat(4, 1fr);">
                  <div class="env-stat">
                    <span class="label">OS BUILD</span>
                    <span class="value">{hostStats.os_build || '---'}</span>
                  </div>
                  <div class="env-stat">
                    <span class="label">UPTIME</span>
                    <span class="value">{hostStats.uptime || '00:00:00'}</span>
                  </div>
                  <div class="env-stat">
                    <span class="label">AUDIT MODE</span>
                    <span class="status-pill" class:active={hostStats.audit_mode}>
                      {hostStats.audit_mode ? 'ARMED' : 'OFF'}
                    </span>
                  </div>
                  <div class="env-stat">
                    <span class="label">PROVISIONING</span>
                    <span class="value" style="color: var(--accent-color);">ONLINE</span>
                  </div>
                </div>
              {/if}
            </div>
          {:else}
            <!-- LOCAL IMAGE / PACKER VIEW -->
            <div class="env-section host-side disconnected">
              <div class="section-label">
                <HardDrive size={14} strokeWidth={2.5} />
                <span>OFFLINE IMAGE BUILD (PACKER)</span>
              </div>
              <div class="disconnected-overlay">
                <span class="dim-text">SOURCE: OSDBUILDER / PACKER PIPELINE</span>
              </div>
            </div>

            <div class="env-divider"></div>

            <div class="env-section vm-side disconnected">
              <div class="section-label">
                 <Monitor size={14} strokeWidth={2.5} />
                 <span>DECOUPLED ENVIRONMENT</span>
              </div>
              <div class="disconnected-overlay">
                <Monitor size={24} class="dim-icon" strokeWidth={1.5} />
                <span class="dim-text" style="font-size: 9px;">NO ACTIVE VM PIPELINE</span>
              </div>
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- COLUMN 1: OPERATIONAL QUICK-ACTIONS (Commands Card) -->
    <div class="tweak-column" style="grid-column: 1; grid-row: 1 / span 2; align-self: stretch; display: flex; flex-direction: column;">
      <div class="category-card" style="flex: 1; height: 100%;">
        <div class="card-header">
          <span class="header-icon">
            <Zap size={16} strokeWidth={3.5} />
          </span>
          <h3>
            {#if $settings.environmentTarget === 'VHD & VM'}
              PROVISIONING TOOLSET
            {:else}
              MASTERING TOOLSET
            {/if}
          </h3>
        </div>
        
        <div class="card-body">
          {#if $settings.environmentTarget === 'VHD & VM'}
            <!-- PROVISIONING ACTIONS -->
            <div class="action-item tweak-row">
              <span class="tweak-name">Clear All Pinned Start Apps</span>
              <div class="spacer"></div>
              <button class="zap-btn" onclick={() => runAction('ClearStart')}>
                <Trash2 size={11} strokeWidth={2.5} />
              </button>
            </div>
            <div class="action-item tweak-row">
              <span class="tweak-name">Create System Restore Point</span>
              <div class="spacer"></div>
              <button class="zap-btn" onclick={() => runAction('CreateRestorePoint')}>
                <History size={11} strokeWidth={2.5} />
              </button>
            </div>
          {:else if $settings.environmentTarget === 'Local Image'}
            <!-- MASTERING ACTIONS -->
            <div class="action-item tweak-row">
              <span class="tweak-name">Scrub Mount Points (Cleanup)</span>
              <div class="spacer"></div>
              <button class="zap-btn" onclick={() => engine.handleCleanup()}>
                <Trash2 size={11} strokeWidth={2.5} />
              </button>
            </div>
            <div class="action-item tweak-row">
              <span class="tweak-name">Compact WIM Image (LZX)</span>
              <div class="spacer"></div>
              <button class="zap-btn" onclick={() => engine.handleCompaction()}>
                <Cpu size={11} strokeWidth={2.5} />
              </button>
            </div>
            <div class="action-item tweak-row">
              <span class="tweak-name">Master Production ISO</span>
              <div class="spacer"></div>
              <button class="zap-btn active-accent" onclick={() => engine.handleMastering()}>
                <Layers size={11} strokeWidth={2.5} />
              </button>
            </div>
          {:else}
            <!-- LOCAL TUNING -->
            <div class="action-item tweak-row">
              <span class="tweak-name">Local System Audit</span>
              <div class="spacer"></div>
              <button class="zap-btn" onclick={() => loadStats()}>
                <RefreshCw size={11} strokeWidth={2.5} />
              </button>
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- COLUMN 3: CONNECTION POLICIES -->
    <div class="tweak-column" style="grid-column: 3; grid-row: 2; display: flex; flex-direction: column;">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon">
            <Wifi size={16} strokeWidth={3.5} />
          </span>
          <h3>CONNECTION POLICIES</h3>
        </div>
        
        <div class="card-body">
          {#if $settings.environmentTarget === 'VHD & VM'}
            {#if loading}
              <div class="card-loading-center">
                <RefreshCw size={36} class="spin dim-blue" />
                <span class="loading-text">AUDITING POLICY...</span>
              </div>
            {:else}
              <div class="tweak-row" title="Allows blank passwords for local admin accounts. Required for zero-touch deployments.">
                <span class="tweak-name">LSA Admin Passwords</span>
                <div class="spacer"></div>
                <div class="target-toggle-group">
                  <button 
                    class="target-btn" 
                    class:active={hostStats?.Connection?.LimitBlank}
                    class:inactive={!hostStats?.Connection?.LimitBlank}
                    class:executing={executingActions.has('LimitBlank-Host')}
                    onclick={() => runAction('LimitBlank', null)}
                  >
                    {#if executingActions.has('LimitBlank-Host')}<RefreshCw size={10} class="spin" />{:else}H{/if}
                  </button>
                  <button 
                    class="target-btn" 
                    class:active={vmStats?.Connection?.LimitBlank}
                    class:inactive={!vmStats?.Connection?.LimitBlank}
                    class:executing={executingActions.has('LimitBlank-VM')}
                    disabled={!$vhdStore.remoteActive}
                    onclick={() => runAction('LimitBlank', $vhdStore.vmName)}
                  >
                    {#if executingActions.has('LimitBlank-VM')}<RefreshCw size={10} class="spin" />{:else}V{/if}
                  </button>
                </div>
              </div>
              <div class="tweak-row" title="Windows Remote Management. Primary service for PowerShell remoting.">
                <span class="tweak-name">WinRM Management Stack</span>
                <div class="spacer"></div>
                <div class="target-toggle-group">
                  <button 
                    class="target-btn" 
                    class:active={hostStats?.Connection?.Winrm}
                    class:inactive={!hostStats?.Connection?.Winrm}
                    class:executing={executingActions.has('WinRM-Host')}
                    onclick={() => runAction('WinRM', null)}
                  >
                    {#if executingActions.has('WinRM-Host')}<RefreshCw size={10} class="spin" />{:else}H{/if}
                  </button>
                  <button 
                    class="target-btn" 
                    class:active={vmStats?.Connection?.Winrm}
                    class:inactive={!vmStats?.Connection?.Winrm}
                    class:executing={executingActions.has('WinRM-VM')}
                    disabled={!$vhdStore.remoteActive}
                    onclick={() => runAction('WinRM', $vhdStore.vmName)}
                  >
                    {#if executingActions.has('WinRM-VM')}<RefreshCw size={10} class="spin" />{:else}V{/if}
                  </button>
                </div>
              </div>
            {/if}
          {:else}
            <div class="disconnected-overlay" style="min-height: 120px;">
              <WifiOff size={24} class="dim-icon" strokeWidth={1.5} />
              <span class="dim-text">POLICIES DECOUPLED</span>
              <span class="dim-text" style="font-size: 8px; opacity: 0.5;">NO ACTIVE VM SESSION</span>
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- COLUMN 2: HUB (Switches between VHD & VM Hub and Image Control) -->
    <div class="tweak-column" style="grid-column: 2; grid-row: 2;">
      <div class="category-card" style="height: 100%;">
        {#if $settings.environmentTarget === 'VHD & VM'}
          <div class="card-header">
            <span class="header-icon">
              <Zap size={16} strokeWidth={2.5} />
            </span>
            <h3>VHD & VM HUB</h3>
          </div>
          <div class="card-body" style="flex: 1; gap: 8px;">
            <div class="stat-row">
              <div class="stat-label">ACTIVE VM NAME</div>
              <div class="stat-value truncate" style="max-width: 140px;" title={$vhdStore.vmName || 'No Session'}>
                {$vhdStore.vmName || 'No Session'}
              </div>
              <button class="zap-btn" onclick={() => invoke('select_vm')}>
                <LayoutGrid size={11} strokeWidth={2.5} />
              </button>
            </div>
            
            <div class="divider"></div>

            <div class="stat-row">
              <div class="stat-label">MASTER VHD PATH</div>
              <div class="stat-value truncate" style="max-width: 140px;" title={$vhdStore.vhdPath || 'Unmounted'}>
                {$vhdStore.vhdPath.split('\\').pop() || 'Unmounted'}
              </div>
              <button class="zap-btn" onclick={() => $vhdStore.vhdPath ? null : invoke('select_vhd')}>
                <HardDrive size={11} strokeWidth={2.5} />
              </button>
            </div>

            <div class="divider"></div>

            <div class="stat-row remote-toggle-row">
              <div class="stat-label">REMOTE ORCHESTRATION</div>
              <div class="status-pill" class:active={$vhdStore.remoteActive}>
                {$vhdStore.remoteActive ? 'ESTABLISHED' : 'DETACHED'}
              </div>
            </div>

            <div class="vhd-control-grid" style="margin-top: auto;">
               <button class="vhd-action-btn host" class:active={!$vhdStore.remoteActive} onclick={() => invoke('vhd_host_mode')} disabled={$vhdStore.remoteActive}>
                  <Shield size={14} />
                  <span>HOST</span>
               </button>
               <button class="vhd-action-btn vm" class:active={$vhdStore.remoteActive} onclick={() => invoke('vhd_vm_mode')} disabled={!$vhdStore.remoteActive}>
                  <Monitor size={14} />
                  <span>VM</span>
               </button>
               <button class="vhd-action-btn release" onclick={() => invoke('vhd_release')}>
                  <Trash2 size={14} />
                  <span>RELEASE</span>
               </button>
            </div>
          </div>
        {:else}
          <div class="card-header">
            <span class="header-icon">
              <HardDrive size={16} strokeWidth={2.5} />
            </span>
            <h3>IMAGE SOURCE & CONTROL</h3>
          </div>
          <div class="card-body" style="flex: 1; gap: 8px;">
            <div class="stat-row">
              <div class="stat-label">SOURCE IMAGE ARCHIVE</div>
              <div class="stat-value truncate" style="max-width: 140px;" title={engine.config.iso_url || 'None'}>
                {engine.config.iso_url.split('\\').pop() || 'None'}
              </div>
              <button class="zap-btn" onclick={() => engine.selectFile('iso_url', 'Select Source Image', ['iso', 'wim', 'esd'])}>
                <LayoutGrid size={11} strokeWidth={2.5} />
              </button>
            </div>
            
            <div class="divider"></div>

            <div class="stat-row">
              <div class="stat-label">TARGET EDITION</div>
              <select bind:value={engine.config.wim_index} class="orchestrator-select">
                {#if engine.availableImages.length === 0}
                  <option value={1}>Index 1 (Generic)</option>
                {:else}
                  {#each engine.availableImages as img}
                    <option value={img.ImageIndex}>[{img.ImageIndex}] {img.ImageName}</option>
                  {/each}
                {/if}
              </select>
            </div>

            <div class="divider"></div>

            <div class="stat-row remote-toggle-row">
              <div class="stat-label">ORCHESTRATION ENGINE</div>
              <div class="status-pill" class:active={engine.status.isMounted}>
                {engine.status.isMounted ? 'MOUNT ARMED' : 'READY'}
              </div>
            </div>

            <div class="vhd-control-grid" style="margin-top: auto;">
               {#if !engine.status.isMounted}
                 <button class="vhd-action-btn host full-width" onclick={() => engine.handleMount()} disabled={engine.processing}>
                    <Layers size={14} />
                    <span>MOUNT OFFLINE IMAGE</span>
                 </button>
               {:else}
                 <button class="vhd-action-btn vm" onclick={() => engine.handleUnmount(false)} disabled={engine.processing}>
                    <Save size={14} />
                    <span>COMMIT CHANGES</span>
                 </button>
                 <button class="vhd-action-btn release" onclick={() => engine.handleUnmount(true)} disabled={engine.processing}>
                    <Trash2 size={14} />
                    <span>DISCARD SESSION</span>
                 </button>
               {/if}
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
</TacticalContainer>
</div>
</div>

<style>
  .panel {
    display: flex;
    flex-direction: column;
    height: 100%;
    gap: 0;
    overflow: hidden;
    background: #1a1f22;
    border: 1px solid #0d1214;
    border-radius: 8px;
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

  .title-cluster {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  h2 {
    font-size: 11px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.15em;
    color: rgba(255, 255, 255, 0.85);
    margin: 0;
    text-shadow: 0 0 15px rgba(255, 255, 255, 0.1);
  }

  .glow-icon {
    color: var(--accent-color);
    filter: drop-shadow(0 0 8px rgba(var(--accent-rgb), 0.4));
  }

  .dashboard-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr); /* Responsive fluid columns */
    grid-template-rows: auto auto; 
    padding: 16px; 
    grid-gap: 16px;
    width: 100%; 
    height: auto;
    align-items: start;
    justify-content: start;
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
    background: #181E20; /* Requested base color */
    background-image: linear-gradient(180deg, rgba(255,255,255,0.03) 0%, transparent 100%);
    border-bottom: none;
    position: relative;
    border-radius: 8px 8px 0 0;
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
    margin-right: 12px;
    color: var(--accent-color);
    display: flex;
    align-items: center;
  }

  .card-body {
    padding: 8px 10px;
    display: flex;
    flex-direction: column;
    gap: 6px;
    flex: 1;
  }

  .tweak-row {
    display: flex;
    align-items: center;
    height: 26px;
    padding: 0 10px;
    background: #242a2d; 
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 4px;
    transition: background 0.2s;
  }

  .tweak-row:hover {
    background: rgba(255, 255, 255, 0.04);
  }

  .tweak-name {
    font-size: 10px;
    color: rgba(255, 255, 255, 0.8);
    font-weight: 600;
    letter-spacing: 0.02em;
  }

  .overview-header-card {
    grid-column: 2 / span 2;
    grid-row: 1;
  }

  .overview-body {
    display: flex;
    flex-direction: row;
    padding: 14px 18px;
    gap: 24px;
    height: 100px;
  }

  .env-section {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 8px;
    justify-content: center;
  }

  .section-label {
    display: flex;
    align-items: center;
    gap: 10px;
    font-size: 9px;
    font-weight: 900;
    color: var(--accent-color);
    letter-spacing: 0.2em;
    text-transform: uppercase;
    opacity: 0.9;
  }

  .env-stats {
    display: flex;
    gap: 24px;
  }

  .env-stat {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .env-stat .label {
    font-size: 8px;
    font-weight: 800;
    color: rgba(255, 255, 255, 0.4);
    letter-spacing: 0.05em;
  }

  .env-stat .value {
    font-size: 11px;
    font-weight: 600;
    color: #fff;
    font-family: 'JetBrains Mono', monospace;
  }

  .env-divider {
    width: 2px;
    height: 60%;
    align-self: center;
    background: 
      linear-gradient(to bottom, transparent, rgba(0,0,0,0.5) 50%, transparent),
      linear-gradient(to bottom, transparent, rgba(255,255,255,0.05) 50%, transparent);
    background-size: 1px 100%;
    background-repeat: no-repeat;
    background-position: left, right;
  }

  .target-toggle-group {
    display: flex;
    gap: 4px;
  }

  .target-btn {
    width: 18px;
    height: 18px;
    border: 1px solid rgba(255, 255, 255, 0.08);
    background: transparent;
    color: rgba(255, 255, 255, 0.3);
    border-radius: 3px;
    font-size: 9px;
    font-weight: 900;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s;
  }

  .target-btn.active {
    color: #4fb995;
    border-color: rgba(79, 185, 149, 0.4);
    background: rgba(79, 185, 149, 0.05) !important;
  }

  .target-btn.inactive {
    color: #ff3d60;
    border-color: rgba(255, 61, 96, 0.4);
    background: rgba(255, 61, 96, 0.05) !important;
  }

  .zap-btn {
    width: 22px;
    height: 22px;
    background: rgba(var(--accent-rgb), 0.1);
    border: 1px solid rgba(var(--accent-rgb), 0.2);
    color: var(--accent-color);
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
  }

  .status-pill {
    padding: 2px 6px;
    font-size: 8px;
    font-weight: 900;
    border-radius: 3px;
    background: rgba(255, 255, 255, 0.05);
  }

  .status-pill.active {
    color: var(--accent-color);
    background: rgba(var(--accent-rgb), 0.1);
  }

  .vhd-hub-body {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .vhd-control-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    grid-gap: 8px;
  }

  .vhd-action-btn {
    height: 30px;
    background: #242a2d;
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 4px;
    color: rgba(255, 255, 255, 0.6);
    font-size: 9px;
    font-weight: 800;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    cursor: pointer;
  }

  .vhd-action-btn.active {
    background: rgba(var(--accent-rgb), 0.1);
    color: var(--accent-color);
    border-color: var(--accent-color);
  }

  .vhd-action-btn.full-width {
    grid-column: span 2;
  }

  .vhd-action-btn.release.active {
    color: #ff3d60;
    border-color: #ff3d60;
    background: rgba(255, 61, 96, 0.1);
  }

  .stat-label {
    font-size: 8px;
    font-weight: 900;
    color: rgba(255, 255, 255, 0.35);
    letter-spacing: 0.1em;
  }

  .dropdown-list {
    position: absolute;
    top: calc(100% + 4px);
    width: 100%;
    background: #1a1f22;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 4px;
    z-index: 5000;
    padding: 4px;
  }

  .dropdown-item {
    width: 100%;
    padding: 6px 12px;
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.6);
    font-size: 9px;
    text-align: left;
    cursor: pointer;
  }

  .dropdown-item:hover {
    background: rgba(255, 255, 255, 0.05);
    color: #fff;
  }

  .dropdown-item.active {
    color: var(--accent-color);
    background: rgba(var(--accent-rgb), 0.1);
  }

  .remote-btn {
    height: 24px;
    padding: 0 12px;
    font-size: 9px;
    font-weight: 900;
    border-radius: 4px;
    cursor: pointer;
  }

  .remote-btn.active {
    background: var(--accent-color);
    color: #000;
  }
  
  .spin { 
    animation: spin 1s linear infinite; 
  }
  
  @keyframes spin { 
    from { transform: rotate(0deg); } 
    to { transform: rotate(360deg); } 
  }

  /* REPRODUCED TWEAK CARD STYLING */
  .category-card {
    width: 100%;
    background: #1a1f22; /* Calibrated slate charcoal from reference */
    border: 1px solid rgba(255, 255, 255, 0.05); /* Stealth edge */
    border-radius: 8px; /* Industrial curve */
    overflow: hidden;
    display: flex;
    flex-direction: column;
    box-shadow: 0 4px 20px rgba(0,0,0,0.4);
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
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
    text-shadow: 0 2px 10px rgba(0, 0, 0, 0.8);
  }

  .header-icon {
    margin-right: 12px;
    color: var(--accent-color);
    opacity: 0.9;
    filter: drop-shadow(0 0 12px rgba(var(--accent-rgb), 0.5));
    display: flex;
    align-items: center;
  }

  .header-loader {
    margin-left: auto;
    color: var(--accent-color);
    display: flex;
    align-items: center;
    opacity: 0.6;
  }

  .card-body {
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    overflow: visible;
    flex: 1;
  }

  .tweak-row {
    position: relative;
    display: flex;
    align-items: center;
    height: 24px;
    padding: 0 8px;
    padding-left: 10px;
    font-size: 11px;
    background: #242a2d; 
    border: 1px solid rgba(255, 255, 255, 0.04);
    border-radius: 5px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
    flex-shrink: 0;
    overflow: visible;
    transition: all 0.15s ease;
  }

  .tweak-row:hover {
    background: rgba(255, 255, 255, 0.04);
    z-index: 100 !important;
  }

  .tweak-name {
    font-size: 11px;
    color: rgba(255, 255, 255, 0.7);
    font-weight: 500;
  }

  .spacer { flex: 1; }

  .overview-header-card {
    grid-column: 1 / -1; /* SPAN ALL 3 COLUMNS */
  }

  .overview-body {
    display: flex;
    flex-direction: row;
    padding: 12px 20px;
    gap: 30px;
    height: 125px; /* FIXED HEIGHT TO ANCHOR GRID ITEMS BELOW */
  }

  .env-section {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 12px;
    position: relative;
    transition: opacity 0.3s ease;
  }

  .env-section.disconnected .env-stats {
    opacity: 0.45;
    filter: grayscale(1);
  }

  .vm-side.disconnected .disconnected-overlay {
    opacity: 1;
    filter: none;
    color: var(--risk-unsafe);
  }

  .vm-side.disconnected :global(.dim-icon) {
    color: var(--risk-unsafe);
    filter: 
      drop-shadow(0 2px 4px rgba(0, 0, 0, 0.6))
      drop-shadow(0 0 20px rgba(255, 61, 96, 0.45));
  }

  .vm-side.disconnected .dim-text {
    color: var(--risk-unsafe);
    opacity: 0.9;
    text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
  }

  .section-label {
    display: flex;
    align-items: center;
    gap: 12px;
    font-size: 11px;
    font-weight: 900;
    color: var(--accent-color);
    letter-spacing: 0.3em;
    text-transform: uppercase;
    opacity: 1;
    text-shadow: 
      0 0 15px rgba(var(--accent-rgb), 0.45),
      0 2px 10px rgba(0, 0, 0, 0.9);
    filter: drop-shadow(0 4px 12px rgba(0, 0, 0, 0.6));
  }

  .env-stats {
    display: flex;
    justify-content: flex-start;
    gap: 40px;
    padding: 4px 0;
  }

  .env-stat {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .env-stat .label {
    font-size: 8.5px;
    font-weight: 800;
    color: rgba(255, 255, 255, 0.5);
    letter-spacing: 0.1em;
  }

  .env-stat .value {
    font-size: 14px;
    font-weight: 600;
    color: #fff;
    font-family: 'JetBrains Mono', monospace;
  }

  .status-pill {
    width: fit-content;
    padding: 3px 10px;
    font-size: 9px;
    font-weight: 900;
    border-radius: 4px;
    background: rgba(255, 255, 255, 0.05);
    color: rgba(255, 255, 255, 0.4);
    letter-spacing: 0.1em;
    border: 1px solid rgba(255,255,255,0.05);
  }

  .status-pill.active {
    background: rgba(var(--accent-rgb), 0.1);
    color: var(--accent-color);
    border-color: rgba(var(--accent-rgb), 0.2);
    box-shadow: 0 0 10px rgba(var(--accent-rgb), 0.1);
  }

  .env-divider {
    width: 2px;
    background: linear-gradient(to bottom, 
      var(--divider-edge) 0%, 
      var(--divider-core) 50%, 
      var(--divider-edge) 100%
    );
  }

  .disconnected-overlay {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 10px 0;
  }

  :global(.dim-icon) {
    color: rgba(255, 255, 255, 0.1);
    filter: drop-shadow(0 0 15px rgba(0,0,0,0.5));
  }

  .dim-text {
    font-size: 9px;
    font-weight: 900;
    color: rgba(255, 255, 255, 0.15);
    letter-spacing: 0.3em;
  }

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

  .divider {
    height: 2px;
    background: linear-gradient(to right, 
      var(--divider-edge) 0%, 
      var(--divider-core) 50%, 
      var(--divider-edge) 100%
    );
    margin: 12px 0;
  }

  .target-toggle-group {
    display: flex;
    gap: 6px;
    align-items: center;
  }

  .target-btn {
    width: 18px;
    height: 18px;
    border: 1px solid rgba(255, 255, 255, 0.06);
    background: transparent !important; 
    color: rgba(255, 255, 255, 0.2);
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 9px; /* EXACT HUB PARITY */
    font-weight: 800; /* EXACT HUB PARITY */
    letter-spacing: 0em;
    cursor: default;
    transition: all 0.2s;
    user-select: none;
  }

  .target-btn.active {
    color: #4fb995; /* EXACT HUB PARITY */
    border-color: rgba(79, 185, 149, 0.4); 
    box-shadow: 0 0 10px rgba(79, 185, 149, 0.1);
  }

  .target-btn.inactive {
    color: #ff3d60; /* EXACT HUB PARITY */
    border-color: rgba(255, 61, 96, 0.4); 
    box-shadow: 0 0 10px rgba(255, 61, 96, 0.1);
  }

  .target-btn:hover:not(:disabled) {
    z-index: 50;
    color: #fff !important; /* EXACT HUB WHITE-POP PARITY */
    filter: brightness(1.3);
    font-weight: 800;
  }

  .target-btn.active:hover:not(:disabled) {
    border: 1.5px solid rgba(79, 185, 149, 1.0) !important; 
    box-shadow: 
      0 0 15px rgba(79, 185, 149, 0.35), 
      0 0 5px rgba(79, 185, 149, 0.55);
  }

  .target-btn.inactive:hover:not(:disabled) {
    border: 1.5px solid rgba(255, 0, 48, 1.0) !important; 
    box-shadow: 
      0 0 18px rgba(255, 0, 48, 0.45), 
      0 0 6px rgba(255, 0, 48, 0.7), 
      0 0 5px rgba(255, 255, 255, 0.2); 
  }

  .target-btn.executing {
    opacity: 0.8;
    pointer-events: none;
    background: rgba(255, 255, 255, 0.05) !important;
    border-color: rgba(255, 255, 255, 0.2) !important;
    animation: execute-pulse 1s infinite ease-in-out;
  }

  @keyframes execute-pulse {
    0% { filter: brightness(1); box-shadow: 0 0 5px rgba(255,255,255,0.05); }
    50% { filter: brightness(1.5); box-shadow: 0 0 15px rgba(255,255,255,0.15); }
    100% { filter: brightness(1); box-shadow: 0 0 5px rgba(255,255,255,0.05); }
  }

  :global(.spin) {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  .target-btn:disabled {
    opacity: 0.25;
    cursor: default; 
    filter: grayscale(1);
  }

  .target-btn.executing {
    cursor: wait;
    opacity: 0.7;
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
    padding-right: 12px; /* Increased right padding as requested */
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
    display: flex;
    align-items: center;
    width: 100%;
    padding: 8px 12px;
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.6);
    font-size: 11px;
    font-weight: 500;
    text-align: left;
    cursor: pointer;
    transition: all 0.2s;
  }

  .item-status {
    width: 16px;
    height: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-right: 8px;
    opacity: 0.8;
  }

  .dropdown-item.missing {
    color: rgba(255, 255, 255, 0.4);
    cursor: not-allowed;
  }

  .dropdown-item.active {
    background: rgba(var(--accent-rgb), 0.15);
    color: var(--accent-color);
    border: 1px solid rgba(var(--accent-rgb), 0.3);
  }

  .vhd-hub-body {
    position: relative;
    min-height: 345px;
    display: flex;
    flex-direction: column;
  }

  .card-loading-center {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    background: radial-gradient(circle, rgba(var(--accent-rgb), 0.03) 0%, transparent 70%);
  }

  :global(.dim-blue) {
    color: var(--accent-color);
    filter: drop-shadow(0 0 10px rgba(var(--accent-rgb), 0.5));
    animation: spin 1.2s cubic-bezier(0.4, 0, 0.2, 1) infinite;
  }

  .loading-text {
    font-size: 8.5px;
    font-weight: 900;
    color: rgba(255, 255, 255, 0.4);
    letter-spacing: 0.15em;
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



  .remote-toggle-row {
     margin: 6px 0 10px 0;
     background: rgba(0, 188, 212, 0.05);
     padding: 8px;
     border-radius: 4px;
     border: 1px dashed rgba(0, 188, 212, 0.2);
  }

  .remote-btn {
     width: 80px; /* REFINED WIDTH */
     height: 32px; /* HUB CHASSIS PARITY */
     background: #242a2d; /* INDUSTRIAL DARK-GREY BASE */
     border: 1px solid rgba(255, 255, 255, 0.05); 
     border-radius: 4px;
     color: rgba(255, 255, 255, 0.5);
     font-size: 9px;
     font-weight: 800;
     letter-spacing: 0.1em;
     display: flex;
     align-items: center;
     justify-content: center;
     cursor: pointer;
     transition: all 0.2s;
  }

  .remote-btn.active {
     background: #00bcd4;
     color: #000;
     box-shadow: 0 0 15px rgba(0, 188, 212, 0.6);
     border-color: #00bcd4;
     filter: brightness(1.1);
  }

  .remote-btn.connecting {
     background: rgba(0, 188, 212, 0.1);
     color: #00bcd4;
     border-color: rgba(0, 188, 212, 0.4);
     cursor: wait;
     animation: pulse 1.5s infinite ease-in-out;
  }

  .remote-btn:hover:not(:disabled):not(.active) {
    background: #2a3135;
    color: #fff;
    border-color: rgba(255, 255, 255, 0.15);
    box-shadow: 0 0 10px rgba(255, 255, 255, 0.06);
  }

  @keyframes pulse {
    0% { box-shadow: 0 0 5px rgba(0, 188, 212, 0.2); }
    50% { box-shadow: 0 0 15px rgba(0, 188, 212, 0.4); }
    100% { box-shadow: 0 0 5px rgba(0, 188, 212, 0.2); }
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
    filter: brightness(1.3);
    color: #fff;
    z-index: 50;
    box-shadow: 0 0 18px rgba(255, 255, 255, 0.12); /* NEUTRAL DISCONNECTED BLOOM */
  }

  .vhd-action-btn.host.active:hover:not(:disabled) {
    border-color: rgba(79, 185, 149, 1.0) !important; 
    box-shadow: 
      0 0 15px rgba(79, 185, 149, 0.35), 
      0 0 5px rgba(79, 185, 149, 0.55);
  }

  .vhd-action-btn.vm.active:hover:not(:disabled) {
    border-color: rgba(0, 188, 212, 1.0) !important; 
    box-shadow: 
      0 0 15px rgba(0, 238, 255, 0.35), /* PURER CYAN BLOOM */
      0 0 5px rgba(0, 238, 255, 0.55);
  }

  .vhd-action-btn.release.active:hover:not(:disabled) {
    border: 1.5px solid rgba(255, 0, 48, 1.0) !important; /* HIGH-SATURATION PRIMARY RED FRAME */
    box-shadow: 
      0 0 18px rgba(255, 0, 48, 0.45), 
      0 0 6px rgba(255, 0, 48, 0.7), 
      0 0 5px rgba(255, 255, 255, 0.2); 
  }

  .vhd-action-btn.active.host {
    background: rgba(79, 185, 149, 0.12);
    color: #4fb995;
    border-color: rgba(79, 185, 149, 0.4);
  }

  .vhd-action-btn.active.vm {
    background: rgba(0, 188, 212, 0.12);
    color: #00bcd4;
    border-color: rgba(0, 188, 212, 0.8); /* MATCHING REFINED INTENSITY */
  }

  .vhd-action-btn.release.active {
    background: rgba(255, 61, 96, 0.12); 
    box-shadow: 
      0 0 0 1px rgba(255, 61, 96, 0.2), 
      0 0 12px rgba(255, 61, 96, 0.12); 
    border-color: rgba(255, 61, 96, 1.0); 
    color: var(--risk-unsafe);
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

  .action-item.restricted {
    opacity: 0.35;
    pointer-events: none;
    filter: grayscale(1);
    cursor: not-allowed;
  }
</style>
