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
    position: relative;
    display: flex;
    align-items: center;
    height: 34px;
    margin: 4px 0;
    padding: 0 12px;
    cursor: pointer;
    border-radius: 2px;
    
    /* THE INDUSTRIAL SLAB (v7) - BRING BACK THE LIGHT */
    background: 
      linear-gradient(to right, var(--slab-edge) 0%, var(--slab-base) 15%, var(--slab-base) 85%, var(--slab-edge) 100%);

    /* MACHINED EDGES: Sharp Milled Silver-Grey (#6A6E72) */
    border-top: 1px solid var(--slab-rim);
    border-bottom: 1px solid #000000;
    border-left: 1px solid #000000;
    border-right: 1px solid #000000;
    
    box-shadow: 
      0 2px 8px rgba(0, 0, 0, 0.4),
      inset 0 1px 0 rgba(255, 255, 255, 0.05);
      
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    overflow: hidden;
  }

  /* REFINED CELLULAR GRAIN: 10% Opacity Overlay */
  .audit-item::before {
    content: "";
    position: absolute;
    inset: 0;
    background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='voronoiFilter'%3E%3CfeTurbulence type='turbulence' baseFrequency='0.45' numOctaves='3' stitchTiles='stitch'/%3E%3CfeColorMatrix type='matrix' values='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 10 0'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23voronoiFilter)'/%3E%3C/svg%3E");
    opacity: 0.10; 
    pointer-events: none;
    mix-blend-mode: overlay;
    z-index: 1;
  }

  .audit-item:hover {
    filter: brightness(1.1);
  }

  .status-dot {
    width: 8px;
    height: 8px;
    border-radius: 2px;
    background: var(--risk-safe);
    box-shadow: 
      0 0 10px var(--risk-safe),
      0 0 2px rgba(255, 255, 255, 0.5);
    z-index: 2;
    filter: saturate(1.8) brightness(1.2) drop-shadow(0 0 3px var(--risk-safe));
  }

  .audit-item.fail .status-dot {
    background: var(--risk-unsafe);
    box-shadow: 
      0 0 10px var(--risk-unsafe),
      0 0 2px rgba(255, 255, 255, 0.5);
    filter: saturate(1.8) brightness(1.2) drop-shadow(0 0 3px var(--risk-unsafe));
  }

  .info {
    flex: 1;
    display: flex;
    justify-content: space-between;
    align-items: center;
    z-index: 2;
    padding-left: 8px;
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
