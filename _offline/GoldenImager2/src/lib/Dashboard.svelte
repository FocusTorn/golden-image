<script lang="ts">
  import { onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/tauri";
  import { 
    Activity, 
    ShieldCheck, 
    Zap, 
    Globe, 
    Server, 
    Key, 
    UserCheck,
    RefreshCw,
    Terminal,
    ChevronRight,
    AlertCircle
  } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";

  const isTauri = (window as any).__TAURI_METADATA__ !== undefined;

  let stats: any = null;
  let loading = true;
  let error: string | null = null;

  async function loadStats() {
    loading = true;
    error = null;
    try {
      if (isTauri) {
        stats = await invoke("get_dashboard_stats");
      } else {
        // Mock stats for dev
        stats = {
          connection: {
            limit_blank: true,
            winrm: false,
            keyiso: true,
            admin_enabled: true
          },
          stages: {
            pwsh7: true,
            msvc: true,
            app_infra: false
          }
        };
      }
    } catch (e) {
      error = typeof e === "string" ? e : JSON.stringify(e);
    } finally {
      loading = false;
    }
  }

  onMount(loadStats);

  function getStatusLabel(val: boolean) {
    return val ? "ACTIVE" : "MISSING";
  }
</script>

<div class="panel-container">
  <div class="toolbar">
    <div class="title-cluster">
      <Activity size={18} class="glow-icon" />
      <h2>Mission Control Dashboard</h2>
    </div>
    <div class="spacer"></div>
    <BloomControl on:click={loadStats} disabled={loading}>
      <RefreshCw size={14} class={loading ? "spin" : ""} />
    </BloomControl>
  </div>

  <div class="content">
    {#if error}
      <div class="error-banner">
        <AlertCircle size={20} />
        <span>Hardware Sync Failure: {error}</span>
      </div>
    {/if}

        <div class="dashboard-grid">
          <div class="status-card bloom-card">
            <div class="card-top">
              <span class="card-label">Tactical Connectivity</span>
              <div class="card-indicator">
                <Globe size={11} />
              </div>
            </div>
            
            <div class="card-body">
              <div class="audit-list">
                <div class="audit-item" class:fail={!stats?.connection?.limit_blank}>
                  <div class="status-dot"></div>
                  <div class="info">
                    <label>LSA Passwords</label>
                    <span class="val">{getStatusLabel(stats?.connection?.limit_blank)}</span>
                  </div>
                </div>
                <div class="audit-item" class:fail={!stats?.connection?.winrm}>
                  <div class="status-dot"></div>
                  <div class="info">
                    <label>WinRM Stack</label>
                    <span class="val">{getStatusLabel(stats?.connection?.winrm)}</span>
                  </div>
                </div>
              </div>
            </div>

            <div class="card-footer">
              <div class="ornament-dot"></div>
            </div>
          </div>

          <div class="status-card bloom-card accent">
            <div class="card-top">
              <span class="card-label">Deployment Readiness</span>
              <div class="card-indicator active">
                <Zap size={11} fill="currentColor" />
              </div>
            </div>
            
            <div class="card-body">
              <div class="audit-list">
                <div class="audit-item" class:fail={!stats?.stages?.pwsh7}>
                  <div class="status-dot"></div>
                  <div class="info">
                    <label>PS7 Core</label>
                    <span class="val">{getStatusLabel(stats?.stages?.pwsh7)}</span>
                  </div>
                </div>
                <div class="audit-item" class:fail={!stats?.stages?.msvc}>
                  <div class="status-dot"></div>
                  <div class="info">
                    <label>MSVC Master</label>
                    <span class="val">{getStatusLabel(stats?.stages?.msvc)}</span>
                  </div>
                </div>
              </div>
            </div>

            <div class="card-footer">
              <div class="ornament-dot active"></div>
              <span class="score-val">{stats ? (Object.values(stats.stages).filter(v => v).length / 3 * 100).toFixed(0) : 0}%</span>
            </div>
          </div>

      <!-- System Summary (Small Stats) -->
      <div class="stats-sidebar">
        <div class="summary-box">
          <div class="stat">
            <span class="label">OS BUILD</span>
            <span class="value">22631.PRO</span>
          </div>
          <div class="stat">
            <span class="label">UPTIME</span>
            <span class="value">04:12:15</span>
          </div>
          <div class="stat">
            <span class="label">AUDIT MODE</span>
            <span class="badge active">ENABLED</span>
          </div>
        </div>

        <div class="action-card bloom-card">
          <div class="card-top">
            <span class="card-label">Active Session</span>
            <div class="card-indicator">
              <Terminal size={11} />
            </div>
          </div>
          <div class="card-body">
            <p>Integrated shell listener is monitoring system changes in real-time.</p>
          </div>
          <div class="card-footer">
            <div class="ornament-dot"></div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .panel-container {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: var(--grad-main);
  }

  .toolbar {
    height: 48px;
    background: rgba(18, 24, 26, 0.8);
    backdrop-filter: blur(12px);
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    display: flex;
    align-items: center;
    padding: 0 16px;
    flex-shrink: 0;
  }

  .title-cluster {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .glow-icon {
    color: var(--accent-color);
    filter: drop-shadow(0 0 8px var(--accent-color));
  }

  h2 {
    font-size: 11px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: rgba(255, 255, 255, 0.7);
    margin: 0;
  }

  .spacer { flex: 1; }

  .content {
    flex: 1;
    padding: 32px;
    overflow-y: auto;
  }

  .error-banner {
    background: rgba(255, 23, 68, 0.1);
    border: 1px solid rgba(255, 23, 68, 0.2);
    color: #ff1744;
    padding: 12px 16px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    gap: 12px;
    font-size: 13px;
    margin-bottom: 32px;
  }

  .dashboard-grid {
    display: grid;
    grid-template-columns: 1fr 1fr 300px;
    gap: 24px;
    max-width: 1400px;
    margin: 0 auto;
  }

  .bloom-card {
    background: rgba(0, 0, 0, 0.25);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 8px;
    padding: 12px 14px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    min-height: 120px;
    transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
    overflow: hidden;
  }

  .bloom-card:hover {
    background: rgba(0, 0, 0, 0.35);
    border-color: rgba(255, 255, 255, 0.1);
  }

  .bloom-card.accent {
    background: rgba(var(--accent-rgb), 0.03);
    border-color: rgba(var(--accent-rgb), 0.15);
  }

  .card-top {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 12px;
  }

  .card-label {
    font-size: 10px;
    font-weight: 800;
    text-transform: uppercase;
    color: rgba(255, 255, 255, 0.4);
    letter-spacing: 0.08em;
  }

  .card-indicator {
    width: 20px;
    height: 20px;
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: rgba(255, 255, 255, 0.2);
    background: rgba(0, 0, 0, 0.1);
  }

  .card-indicator.active {
    color: var(--accent-color);
    border-color: rgba(var(--accent-rgb), 0.3);
    background: rgba(var(--accent-rgb), 0.1);
  }

  .card-body {
    flex: 1;
  }

  .audit-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .audit-item {
    display: flex;
    align-items: center;
    gap: 10px;
    opacity: 0.7;
  }

  .status-dot {
    width: 3px;
    height: 3px;
    border-radius: 50%;
    background: var(--risk-safe);
    box-shadow: 0 0 6px var(--risk-safe);
  }

  .audit-item.fail .status-dot {
    background: var(--risk-unsafe);
    box-shadow: 0 0 6px var(--risk-unsafe);
  }

  .info {
    flex: 1;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  label {
    font-size: 11px;
    font-weight: 500;
    color: rgba(255, 255, 255, 0.6);
  }

  .val {
    font-size: 9px;
    font-weight: 900;
    opacity: 0.3;
  }

  .card-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-top: 12px;
    margin-top: 8px;
    border-top: 1px solid rgba(255, 255, 255, 0.03);
  }

  .ornament-dot {
    width: 3px;
    height: 3px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 50%;
  }

  .ornament-dot.active {
    background: var(--accent-color);
    box-shadow: 0 0 6px var(--accent-color);
  }

  .score-val {
    font-size: 14px;
    font-weight: 800;
    color: var(--accent-color);
  }

  /* Stats Sidebar */
  .stats-sidebar {
    display: flex;
    flex-direction: column;
    gap: 24px;
  }

  .summary-box {
    background: rgba(var(--accent-rgb), 0.04);
    border: 1px solid rgba(var(--accent-rgb), 0.1);
    border-radius: 12px;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .stat {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .stat .label {
    font-size: 9px;
    font-weight: 900;
    color: rgba(255, 255, 255, 0.3);
    letter-spacing: 0.15em;
  }

  .stat .value {
    font-size: 18px;
    font-weight: 800;
    color: #fff;
  }

  .badge {
    display: inline-block;
    font-size: 10px;
    font-weight: 900;
    padding: 4px 8px;
    border-radius: 4px;
    background: rgba(255, 255, 255, 0.05);
    color: rgba(255, 255, 255, 0.4);
    width: fit-content;
  }

  .badge.active {
    background: var(--accent-color);
    color: #000;
  }

  .action-card {
    background: rgba(255, 255, 255, 0.02);
    border: 1px dashed rgba(255, 255, 255, 0.1);
    border-radius: 12px;
    padding: 20px;
  }

  .action-card p {
    font-size: 11px;
    line-height: 1.6;
    color: rgba(255, 255, 255, 0.4);
    margin: 12px 0 0 0;
  }

  .spin {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
</style>
