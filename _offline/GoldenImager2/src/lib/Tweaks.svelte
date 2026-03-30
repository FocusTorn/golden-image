<script lang="ts">
  import { onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/tauri";
  import { 
    Cog, 
    Shield, 
    Zap, 
    Cpu, 
    Eye, 
    ShieldAlert, 
    RefreshCw, 
    Check, 
    X,
    Search,
    ChevronRight,
    Terminal,
    Info
  } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";

  const isTauri = (window as any).__TAURI_METADATA__ !== undefined;

  let featuresConfig: any = null;
  let auditResults: any[] = [];
  let loading = true;
  let error: string | null = null;
  let activeCategory = "Titus Essentials";
  let applyingFeature: string | null = null;
  let searchQuery = "";

  async function loadData() {
    loading = true;
    error = null;
    try {
      if (isTauri) {
        featuresConfig = await invoke("get_features_config");
        auditResults = await invoke("get_audit_results");
      } else {
        // High-fidelity Mock Data
        featuresConfig = {
          Categories: [
            { Name: "Titus Essentials", Icon: "&#xE9E9;" },
            { Name: "Titus Advanced", Icon: "&#xE7BA;" },
            { Name: "Privacy & Suggested", Icon: "&#xE72E;" },
            { Name: "System", Icon: "&#xe770;" },
            { Name: "AI", Icon: "&#xe794;" }
          ],
          Features: [
            { FeatureId: "DisableWPBT", Label: "Disable WPBT", Category: "Titus Essentials", ToolTip: "Prevents BIOS-injected software execution.", Action: "Disable" },
            { FeatureId: "DisableTelemetry", Label: "Universal Telemetry", Category: "Privacy & Suggested", ToolTip: "Stops background tracking services.", Action: "Disable" },
            { FeatureId: "EnableDarkMode", Label: "Force Dark Mode", Category: "System", ToolTip: "System-wide luminance override.", Action: "Enable" }
          ]
        };
        auditResults = [
          { feature_id: "DisableWPBT", status: "Applied" },
          { feature_id: "DisableTelemetry", status: "Not Applied" }
        ];
      }
      
      if (featuresConfig?.Categories?.length > 0 && !activeCategory) {
        activeCategory = featuresConfig.Categories[0].Name;
      }
    } catch (e) {
      error = typeof e === "string" ? e : "Sync Failure";
    } finally {
      loading = false;
    }
  }

  onMount(loadData);

  function getStatus(id: string) {
    const res = auditResults.find(r => r.feature_id === id);
    return res ? res.status : "Unknown";
  }

  async function toggleFeature(feature: any) {
    const status = getStatus(feature.FeatureId);
    applyingFeature = feature.FeatureId;
    
    try {
      if (status === "Applied") {
        await invoke("undo_feature", { feature_id: feature.FeatureId });
      } else {
        await invoke("apply_feature", { feature_id: feature.FeatureId });
      }
      
      if (isTauri) {
        auditResults = await invoke("get_audit_results");
      }
    } catch (e) {
      console.error("Action failed:", e);
    } finally {
      applyingFeature = null;
    }
  }

  $: categories = featuresConfig?.Categories || [];
  $: filteredFeatures = (featuresConfig?.Features || []).filter(f => {
    const matchesCat = f.Category === activeCategory;
    const matchesSearch = f.Label.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesCat && matchesSearch;
  });
</script>

<div class="panel-container">
  <div class="sidebar">
    <div class="sidebar-header">
      <Cog size={16} class="glow-icon" />
      <span>REGISTRY OPS</span>
    </div>
    <div class="cat-list">
      {#each categories as cat}
        <button 
          class="cat-item" 
          class:active={activeCategory === cat.Name}
          on:click={() => activeCategory = cat.Name}
        >
          <span class="icon">{@html cat.Icon}</span>
          <span class="label">{cat.Name}</span>
          {#if activeCategory === cat.Name}
            <div class="active-indicator"></div>
          {/if}
        </button>
      {/each}
    </div>
  </div>

  <div class="main-content">
    <div class="toolbar">
      <div class="search-box">
        <Search size={14} />
        <input type="text" placeholder="Search tweaks..." bind:value={searchQuery} />
      </div>
      <div class="spacer"></div>
      <BloomControl on:click={loadData} disabled={loading}>
        <RefreshCw size={14} class={loading ? "spin" : ""} />
        <span>RE-AUDIT</span>
      </BloomControl>
    </div>

    <div class="scroll-area">
      <div class="header-banner">
        <div class="banner-content">
          <h1>{activeCategory}</h1>
          <p>Tactical system modifications and policy enforcement for {activeCategory.toLowerCase()}.</p>
        </div>
      </div>

      {#if loading}
        <div class="state-view">
          <RefreshCw size={32} class="spin dim" />
          <span>Scanning Registry State...</span>
        </div>
      {:else if error}
        <div class="state-view error">
          <ShieldAlert size={32} />
          <span>Sync Error: {error}</span>
          <BloomControl on:click={loadData}>Retry Connection</BloomControl>
        </div>
      {:else}
        <div class="tweak-grid">
          {#each filteredFeatures as feature}
            <button 
              class="tweak-card" 
              class:applied={getStatus(feature.FeatureId) === 'Applied'}
              on:click={() => toggleFeature(feature)}
              type="button"
            >
              <div class="card-top">
                <span class="card-label">{feature.Label}</span>
                <div class="card-indicator" class:applied={getStatus(feature.FeatureId) === 'Applied'}>
                  {#if applyingFeature === feature.FeatureId}
                    <RefreshCw size={10} class="spin" />
                  {:else if getStatus(feature.FeatureId) === 'Applied'}
                    <Check size={10} />
                  {/if}
                </div>
              </div>

              <div class="card-footer">
                <div class="status-dot" style="--dot-color: {getStatus(feature.FeatureId) === 'Applied' ? 'var(--accent-color)' : 'rgba(255,255,255,0.1)'}"></div>
                {#if feature.ToolTip}
                  <button 
                    class="tooltip-trigger" 
                    on:click|stopPropagation 
                    type="button"
                    aria-label="Tweak Information"
                  >
                    <Info size={10} />
                    <div class="tooltip-content">{feature.ToolTip}</div>
                  </button>
                {/if}
              </div>
            </button>
          {/each}
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  .panel-container {
    display: flex;
    height: 100%;
    background: var(--grad-main);
    overflow: hidden;
  }

  /* Sidebar Styling */
  .sidebar {
    width: 220px;
    background: rgba(18, 24, 26, 0.6);
    border-right: 1px solid rgba(255, 255, 255, 0.05);
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
  }

  .sidebar-header {
    height: 48px;
    display: flex;
    align-items: center;
    padding: 0 20px;
    gap: 12px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
  }

  .sidebar-header span {
    font-size: 10px;
    font-weight: 900;
    letter-spacing: 0.15em;
    color: rgba(255, 255, 255, 0.3);
  }

  .cat-item {
    position: relative;
    display: flex;
    align-items: center;
    gap: 12px;
    background: transparent;
    border: none;
    padding: 10px 12px;
    border-radius: 6px;
    color: rgba(255, 255, 255, 0.4);
    cursor: pointer;
    text-align: left;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .cat-item:hover {
    background: rgba(255, 255, 255, 0.03);
    color: #fff;
  }

  .cat-item.active {
    background: rgba(var(--accent-rgb), 0.08);
    color: #fff;
  }

  .cat-item .icon {
    font-family: "Segoe Fluent Icons", "Segoe MDL2 Assets";
    font-size: 16px;
    width: 20px;
    display: flex;
    justify-content: center;
  }

  .cat-item .label {
    font-size: 12px;
    font-weight: 600;
  }

  .active-indicator {
    position: absolute;
    left: 0;
    top: 10px;
    bottom: 10px;
    width: 2px;
    background: var(--accent-color);
    box-shadow: 0 0 8px var(--accent-color);
    border-radius: 0 2px 2px 0;
  }

  /* Main Content Styling */
  .main-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    background: rgba(0, 0, 0, 0.1);
  }

  .toolbar {
    height: 48px;
    background: rgba(18, 24, 26, 0.4);
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    display: flex;
    align-items: center;
    padding: 0 24px;
    gap: 20px;
    flex-shrink: 0;
  }

  .search-box {
    display: flex;
    align-items: center;
    gap: 10px;
    background: rgba(0, 0, 0, 0.3);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 4px;
    padding: 0 12px;
    width: 280px;
    height: 28px;
    color: rgba(255, 255, 255, 0.3);
  }

  .search-box input {
    background: transparent;
    border: none;
    color: #fff;
    font-size: 12px;
    outline: none;
    width: 100%;
  }

  .spacer { flex: 1; }

  .scroll-area {
    flex: 1;
    overflow-y: auto;
    padding: 32px 48px;
  }

  .header-banner {
    margin-bottom: 40px;
  }

  .banner-content h1 {
    font-size: 32px;
    font-weight: 900;
    margin: 0 0 8px 0;
    letter-spacing: -0.02em;
    color: #fff;
  }

  .banner-content p {
    font-size: 14px;
    color: rgba(255, 255, 255, 0.4);
    margin: 0;
  }

  .state-view {
    height: 300px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 20px;
    color: rgba(255, 255, 255, 0.3);
    font-size: 14px;
  }

  .tweak-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 16px;
  }

  .tweak-card {
    position: relative;
    background: rgba(0, 0, 0, 0.25);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 8px;
    padding: 12px 14px;
    height: 80px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    cursor: pointer;
    transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .tweak-card:hover {
    background: rgba(0, 0, 0, 0.35);
    border-color: rgba(255, 255, 255, 0.1);
  }

  .tweak-card.applied {
    background: rgba(var(--accent-rgb), 0.05);
    border-color: rgba(var(--accent-rgb), 0.2);
  }

  .card-top {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
  }

  .card-label {
    font-size: 11px;
    font-weight: 600;
    color: rgba(255, 255, 255, 0.7);
    letter-spacing: 0.02em;
    max-width: 80%;
  }

  .card-indicator {
    width: 22px;
    height: 22px;
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--accent-color);
    transition: all 0.2s;
    background: rgba(0, 0, 0, 0.1);
  }

  .card-indicator.applied {
    background: rgba(var(--accent-rgb), 0.1);
    border-color: var(--accent-color);
    box-shadow: 0 0 10px rgba(var(--accent-rgb), 0.2);
  }

  .card-footer {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
  }

  .status-dot {
    width: 3px;
    height: 3px;
    background: var(--dot-color);
    border-radius: 50%;
    box-shadow: 0 0 6px var(--dot-color);
    margin-left: 2px;
  }

  .tooltip-trigger {
    color: rgba(255, 255, 255, 0.15);
    background: transparent;
    border: none;
    padding: 0;
    cursor: help;
    display: flex;
  }

  .tooltip-trigger:hover {
    color: rgba(255, 255, 255, 0.4);
  }

  .tooltip-content {
    display: none;
    position: absolute;
    bottom: calc(100% + 10px);
    right: 0;
    background: #0b0f10;
    border: 1px solid rgba(255, 255, 255, 0.1);
    padding: 8px 12px;
    border-radius: 6px;
    font-size: 11px;
    color: rgba(255, 255, 255, 0.7);
    width: 200px;
    z-index: 100;
    pointer-events: none;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.8);
  }

  .tooltip-trigger:hover .tooltip-content {
    display: block;
  }

  .spin {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
</style>
