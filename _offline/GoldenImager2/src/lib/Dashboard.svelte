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
    Key
  } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";

  const isTauri = (window as any).__TAURI_METADATA__ !== undefined;

  let stats: any = null;
  let loading = true;
  let error: string | null = null;
  let executingActions = new Set<string>();

  async function loadStats() {
    loading = true;
    error = null;
    try {
      if (isTauri) {
        stats = await invoke("get_dashboard_stats");
      } else {
        // Mock stats for dev
        stats = {
          os_build: "22631.PRO",
          uptime: "04:12:15",
          audit_mode: true,
          connection: {
            limit_blank: true,
            winrm: false,
            keyiso: true,
            admin_enabled: true
          }
        };
      }
    } catch (e) {
      error = typeof e === "string" ? e : JSON.stringify(e);
    } finally {
      loading = false;
    }
  }

  async function runAction(actionId: string, isToggle = false) {
    if (executingActions.has(actionId)) return;
    executingActions.add(actionId);
    executingActions = executingActions; 

    try {
      if (isTauri) {
        // Here we'd call specific session toggle commands if they differ 
        // from standard tweaks, but we'll use apply_feature as requested 
        // Or specific session_toggle if implemented.
        await invoke("apply_feature", { id: actionId });
        await loadStats(); // Refresh to show new state
      } else {
        await new Promise(r => setTimeout(r, 1000));
        if (isToggle && stats?.connection) {
          // Mock toggle logic
          const map: any = {
            "LimitBlank": "limit_blank",
            "WinRM": "winrm",
            "KeyIso": "keyiso",
            "AdminAccount": "admin_enabled"
          };
          const key = map[actionId];
          if (key) stats.connection[key] = !stats.connection[key];
        }
      }
    } catch (e) {
      console.error(`Action ${actionId} failed:`, e);
    } finally {
      executingActions.delete(actionId);
      executingActions = executingActions;
    }
  }

  onMount(loadStats);
</script>

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
              <div class="stat-label">OS BUILD</div>
              <div class="stat-value">{stats?.os_build || "22631.PRO"}</div>
            </div>
            <div class="stat-row">
              <div class="stat-label">UPTIME</div>
              <div class="stat-value">{stats?.uptime || "00:00:00"}</div>
            </div>
            <div class="stat-row">
              <div class="stat-label">AUDIT MODE</div>
              <div class="stat-badge" class:active={stats?.audit_mode}>
                {stats?.audit_mode ? 'ENABLED' : 'DISABLED'}
              </div>
            </div>
          </div>

          <div class="divider"></div>

          <!-- SESSION AUDIT ITEMS (4 Items) -->
          <div class="tweak-row status-row" style="--status-color: {stats?.connection?.limit_blank ? 'var(--risk-safe)' : 'var(--risk-unsafe)'}">
            <span class="tweak-name">LSA Admin Passwords</span>
            <div class="spacer"></div>
            <button 
              class="bloom-select" 
              class:deactivate={stats?.connection?.limit_blank}
              class:activate={!stats?.connection?.limit_blank}
              class:executing={executingActions.has('LimitBlank')}
              on:click={() => runAction('LimitBlank', true)}
            >
              {#if executingActions.has('LimitBlank')}
                 <RefreshCw size={10} class="spin" />
              {:else}
                 {stats?.connection?.limit_blank ? 'DEACTIVATE' : 'ACTIVATE'}
              {/if}
            </button>
          </div>

          <div class="tweak-row status-row" style="--status-color: {stats?.connection?.winrm ? 'var(--risk-safe)' : 'var(--risk-unsafe)'}">
            <span class="tweak-name">WinRM Management Stack</span>
            <div class="spacer"></div>
            <button 
              class="bloom-select" 
              class:deactivate={stats?.connection?.winrm}
              class:activate={!stats?.connection?.winrm}
              class:executing={executingActions.has('WinRM')}
              on:click={() => runAction('WinRM', true)}
            >
              {#if executingActions.has('WinRM')}
                 <RefreshCw size={10} class="spin" />
              {:else}
                 {stats?.connection?.winrm ? 'DEACTIVATE' : 'ACTIVATE'}
              {/if}
            </button>
          </div>

          <div class="tweak-row status-row" style="--status-color: {stats?.connection?.keyiso ? 'var(--risk-safe)' : 'var(--risk-unsafe)'}">
            <span class="tweak-name">Isolated Key Service (KeyIso)</span>
            <div class="spacer"></div>
            <button 
              class="bloom-select" 
              class:deactivate={stats?.connection?.keyiso}
              class:activate={!stats?.connection?.keyiso}
              class:executing={executingActions.has('KeyIso')}
              on:click={() => runAction('KeyIso', true)}
            >
              {#if executingActions.has('KeyIso')}
                 <RefreshCw size={10} class="spin" />
              {:else}
                 {stats?.connection?.keyiso ? 'DEACTIVATE' : 'ACTIVATE'}
              {/if}
            </button>
          </div>

          <div class="tweak-row status-row" style="--status-color: {stats?.connection?.admin_enabled ? 'var(--risk-safe)' : 'var(--risk-unsafe)'}">
            <span class="tweak-name">Local Admin Account State</span>
            <div class="spacer"></div>
            <button 
              class="bloom-select" 
              class:deactivate={stats?.connection?.admin_enabled}
              class:activate={!stats?.connection?.admin_enabled}
              class:executing={executingActions.has('AdminAccount')}
              on:click={() => runAction('AdminAccount', true)}
            >
              {#if executingActions.has('AdminAccount')}
                 <RefreshCw size={10} class="spin" />
              {:else}
                 {stats?.connection?.admin_enabled ? 'DEACTIVATE' : 'ACTIVATE'}
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

    <!-- COLUMN 3: EMPTY/FUTURE -->
    <div class="tweak-column"></div>
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
    font-size: 12px;
    font-weight: 700;
    color: #fff;
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
    box-shadow: 0 0 10px var(--accent-color);
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

  .spin {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  :global(.spin) {
    animation: spin 1s linear infinite;
  }
</style>
