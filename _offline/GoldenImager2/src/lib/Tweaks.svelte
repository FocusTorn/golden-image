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
    ChevronDown,
    Download,
    Save,
    Plus,
    Trash2,
    Info,
    LayoutGrid
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

  let hoveredDescription: string | null = null;
  let hoveredFeatureId: string | null = null;

  $: categories = featuresConfig?.Categories || [];
  
  function getFilteredFeatures(categoryName: string) {
    return (featuresConfig?.Features || []).filter(f => {
      const matchesCat = f.Category === categoryName;
      const matchesSearch = f.Label.toLowerCase().includes(searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    });
  }

  function getDotColor(category: string) {
    switch (category) {
      case "Titus Essentials": return "#00e676"; // Risk Safe Green
      case "Titus Advanced": return "#ff3d60"; // Risk Alert Red
      case "Privacy & Suggested": return "#9900ff"; // Risk User Purple
      case "System": return "#ffd600"; // Risk Warn Yellow
      case "AI": return "#00ffff"; // AI Cyan
      default: return "#565f67";
    }
  }

  function handleMouseEnter(feature: any) {
    hoveredDescription = feature.ToolTip;
    hoveredFeatureId = feature.FeatureId;
  }

  function handleMouseLeave() {
    hoveredDescription = null;
    hoveredFeatureId = null;
  }
</script>

<div class="panel">
  <div class="toolbar">
    <div class="tool-group">
      <div class="segmented-control profile-group">
        <BloomControl small style="border-radius: 4px 0 0 4px !important;">
          <LayoutGrid size={14} />
          <span class="btn-text">App-Profiles</span>
          <ChevronDown size={14} />
        </BloomControl>
        <button class="icon-btn" title="Load Profile"><Download size={14} /></button>
        <button class="icon-btn" title="Save Profile"><Save size={14} /></button>
        <button class="icon-btn" title="Save As New"><Plus size={14} /></button>
        <button class="icon-btn" title="Delete Profile"><Trash2 size={14} /></button>
      </div>

      <BloomControl small on:click={loadData} disabled={loading} title="Re-Audit System">
        <RefreshCw size={14} class={loading ? "spin" : ""} />
      </BloomControl>
    </div>

    <div class="spacer"></div>

    <div class="tool-group">
      <div class="search-box">
        <Search size={14} class="search-icon" />
        <input 
          type="text" 
          placeholder="Filter tweaks..." 
          class="bloom-input" 
          bind:value={searchQuery} 
        />
      </div>
    </div>
  </div>

  <div class="recessed-tray">
    {#if loading}
      <div class="state-view">
        <RefreshCw size={32} class="spin dim" />
        <span>Synchronizing Registry State...</span>
      </div>
    {:else if error}
      <div class="state-view error">
        <ShieldAlert size={32} />
        <span>Sync Failure: {error}</span>
        <button class="retry-btn" on:click={loadData}>Retry Connection</button>
      </div>
    {:else}
      <div class="tweak-grid">
        {#each categories as category}
          <div class="category-card">
            <div class="card-header">
              <span class="cat-icon">{@html category.Icon}</span>
              <h3>{category.Name.toUpperCase()}</h3>
              <div class="spacer"></div>
              <Info size={12} class="info-icon" />
            </div>
            
            <div class="card-body">
              {#each getFilteredFeatures(category.Name) as feature}
                <div 
                  class="tweak-row" 
                  on:mouseenter={() => handleMouseEnter(feature)}
                  on:mouseleave={handleMouseLeave}
                  on:click={() => toggleFeature(feature)}
                >
                  <div class="dot" style="--dot-color: {getDotColor(category.Name)}"></div>
                  <span class="tweak-name">{feature.Label}</span>
                  
                  {#if hoveredFeatureId === feature.FeatureId && hoveredDescription}
                    <div class="tweak-tooltip">
                      {hoveredDescription}
                    </div>
                  {/if}

                  <div class="spacer"></div>
                  
                  <div class="checkbox-container">
                    {#if applyingFeature === feature.FeatureId}
                      <RefreshCw size={10} class="spin" />
                    {:else}
                      <div class="bloom-checkbox" class:checked={getStatus(feature.FeatureId) === 'Applied'}>
                        {#if getStatus(feature.FeatureId) === 'Applied'}
                          <Check size={10} strokeWidth={4} />
                        {/if}
                      </div>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>
          </div>
        {/each}
      </div>
    {/if}
    
    <div class="tray-footer">
      <div class="stats">
        <span>{auditResults.filter(r => r.status === 'Applied').length} APPLIED</span>
        <span class="divider">|</span>
        <span>{auditResults.length} TOTAL AUDITED</span>
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
  }

  .toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: 4px;
    gap: 12px;
    position: relative;
    z-index: 2000;
  }

  .tool-group {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .segmented-control {
    display: flex;
    align-items: center;
    background: rgba(0, 0, 0, 0.2);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 4px;
    padding: 2px;
  }

  .icon-btn {
    background: transparent;
    border: none;
    color: #fff;
    opacity: 0.35;
    width: 28px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s;
  }

  .icon-btn:hover {
    opacity: 1;
    background: rgba(255, 255, 255, 0.05);
  }

  .btn-text {
    font-size: 11px;
    font-weight: 600;
    margin: 0 4px;
    white-space: nowrap;
  }

  .search-box {
    position: relative;
    display: flex;
    align-items: center;
    width: 200px;
  }

  .search-icon {
    position: absolute;
    left: 8px;
    opacity: 0.35;
    color: #fff;
  }

  .bloom-input {
    background: rgba(0, 0, 0, 0.2);
    border: 1px solid rgba(255, 255, 255, 0.05);
    color: #fff;
    font-size: 11px;
    padding: 6px 10px 6px 30px;
    width: 100%;
    outline: none;
    border-radius: 4px;
  }

  .recessed-tray {
    flex: 1;
    background: rgba(0, 0, 0, 0.15);
    border: 1px solid rgba(255, 255, 255, 0.03);
    border-radius: 4px;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .tweak-grid {
    flex: 1;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 12px;
    padding: 12px;
    overflow-y: auto;
  }

  .category-card {
    display: flex;
    flex-direction: column;
    background: rgba(255, 255, 255, 0.01);
    border: 1px solid rgba(255, 255, 255, 0.02);
    border-radius: 4px;
    height: fit-content;
  }

  .card-header {
    height: 32px;
    display: flex;
    align-items: center;
    padding: 0 12px;
    background: rgba(255, 255, 255, 0.02);
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
  }

  .card-header h3 {
    font-size: 9px;
    font-weight: 800;
    color: rgba(255, 255, 255, 0.4);
    letter-spacing: 0.1em;
    margin: 0;
  }

  .cat-icon {
    font-family: "Segoe Fluent Icons", "Segoe MDL2 Assets";
    font-size: 14px;
    width: 20px;
    color: rgba(255, 255, 255, 0.15);
  }

  .info-icon {
    opacity: 0.15;
  }

  .card-body {
    padding: 4px;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .tweak-row {
    position: relative;
    height: 28px;
    display: flex;
    align-items: center;
    padding: 0 8px;
    cursor: pointer;
    border-radius: 2px;
    transition: all 0.2s;
    
    /* v7 Material Standard */
    background: linear-gradient(to right, var(--slab-edge), var(--slab-base));
    border-top: 1px solid var(--slab-rim);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.03);
  }

  .tweak-row:hover {
    background: var(--slab-base);
    filter: brightness(1.2);
  }

  .dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--dot-color);
    margin-right: 12px;
    box-shadow: 0 0 8px var(--dot-color);
  }

  .tweak-name {
    font-size: 11px;
    color: rgba(255, 255, 255, 0.6);
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 180px;
  }

  .tweak-tooltip {
    position: absolute;
    bottom: 100%;
    left: 24px;
    background: #1a1f21;
    border: 1px solid var(--accent-color);
    padding: 8px 12px;
    border-radius: 4px;
    font-size: 10px;
    color: #fff;
    width: 240px;
    z-index: 5000;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
    pointer-events: none;
    margin-bottom: 8px;
  }

  .checkbox-container {
    width: 24px;
    display: flex;
    justify-content: center;
  }

  .bloom-checkbox {
    width: 14px;
    height: 14px;
    border: 1px solid rgba(255, 255, 255, 0.15);
    background: rgba(0, 0, 0, 0.4);
    border-radius: 2px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--accent-color);
  }

  .bloom-checkbox.checked {
    background: var(--accent-color);
    border-color: var(--accent-color);
    color: #000;
    box-shadow: 0 0 10px rgba(var(--accent-rgb), 0.4);
  }

  .tray-footer {
    height: 32px;
    background: rgba(0, 0, 0, 0.2);
    border-top: 1px solid rgba(255, 255, 255, 0.05);
    padding: 0 16px;
    display: flex;
    align-items: center;
  }

  .stats {
    display: flex;
    gap: 12px;
    font-size: 9px;
    font-weight: 800;
    color: rgba(255, 255, 255, 0.2);
    letter-spacing: 0.05em;
  }

  .divider { opacity: 0.2; }
  .spacer { flex: 1; }
  .spin { animation: spin 1s linear infinite; }
  .dim { opacity: 0.5; }
  
  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  .state-view {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 16px;
    color: rgba(255, 255, 255, 0.3);
  }

  .error { color: var(--risk-unsafe); }
  
  .retry-btn {
    background: var(--risk-unsafe);
    color: #fff;
    border: none;
    padding: 4px 12px;
    border-radius: 4px;
    font-size: 11px;
    cursor: pointer;
  }
</style>
