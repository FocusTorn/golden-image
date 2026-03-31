<script lang="ts">
  import { onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/tauri";
  import { 
    Cog, 
    RefreshCw, 
    Check, 
    Minus,
    ChevronDown,
    LayoutGrid,
    Info
  } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";
  import TacticalToolbar from "./TacticalToolbar.svelte";
  import TacticalContainer from "./TacticalContainer.svelte";

  export let appliedCount = 0;
  export let totalCount = 0;

  const isTauri = (window as any).__TAURI_METADATA__ !== undefined;

  let featuresConfig: any = null;
  let auditResults: any[] = [];
  let loading = true;
  let error: string | null = null;
  let activeCategory = "Titus Essentials";
  let applyingFeature: string | null = null;
  let searchQuery = "";
  let stagedChanges = new Set<string>();

  async function loadData() {
    loading = true;
    error = null;
    try {
      if (isTauri) {
        featuresConfig = await invoke("get_features_config");
        auditResults = await invoke("get_audit_results");
        profiles = await invoke("list_app_profiles");
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

  function toggleStage(id: string) {
    if (stagedChanges.has(id)) {
      stagedChanges.delete(id);
    } else {
      stagedChanges.add(id);
    }
    stagedChanges = stagedChanges;
  }

  async function executeChanges() {
    if (stagedChanges.size === 0) return;
    
    loading = true;
    try {
      for (const id of Array.from(stagedChanges)) {
        const feature = (featuresConfig?.Features || []).find(f => f.FeatureId === id);
        if (!feature) continue;
        
        const currentStatus = getStatus(id);
        if (currentStatus === "Applied") {
          await invoke("undo_feature", { feature_id: id });
        } else {
          await invoke("apply_feature", { feature_id: id });
        }
      }
      stagedChanges.clear();
      stagedChanges = stagedChanges;
      await loadData(); // Refresh system audit
    } catch (e) {
      console.error("Action failed:", e);
    } finally {
      loading = false;
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

  function getStatusColor(id: string) {
    const res = auditResults.find(r => r.feature_id === id);
    if (!res) return "#ffd600"; // Unknown Yellow
    
    switch (res.status) {
      case "Applied": 
        return "var(--risk-safe)"; // #00e676
      case "Not Applied": 
        return "var(--risk-unsafe)"; // #ff3d60
      default: 
        return "var(--risk-warn)";  // #ffd600 (Unknown / Error / Unsupported)
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

  let profiles: string[] = [];
  let selectedProfile = "";

  $: appliedCount = auditResults.filter(r => r.status === 'Applied').length;
  $: totalCount = auditResults.length;
</script>

<div class="panel">
  <TacticalToolbar 
    showPolicy={false}
    profiles={profiles}
    bind:selectedProfile={selectedProfile}
    bind:searchTerm={searchQuery}
    loading={loading}
    selectionCount={stagedChanges.size}
    profileLabel="Tweak-Profiles"
    applyLabel="Update Changes"
    on:refresh={loadData}
    on:apply={executeChanges}
  />

  <TacticalContainer padding="0 6px">
    {#if loading}
      <div class="state-view">
        <RefreshCw size={32} class="spin dim" />
        <span>Synchronizing Registry State...</span>
      </div>
    {:else if error}
      <div class="state-view error">
        <RefreshCw size={32} class="dim" />
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
                  class:selected={stagedChanges.has(feature.FeatureId)}
                  class:v-applied={getStatus(feature.FeatureId) === 'Applied'}
                  on:mouseenter={() => handleMouseEnter(feature)}
                  on:mouseleave={handleMouseLeave}
                  on:click={() => toggleStage(feature.FeatureId)}
                >
                  <div class="dot" style="--dot-color: {getStatusColor(feature.FeatureId)}"></div>
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
                      <div 
                        class="bloom-checkbox" 
                        class:checked={stagedChanges.has(feature.FeatureId)}
                        class:reverting={stagedChanges.has(feature.FeatureId) && getStatus(feature.FeatureId) === 'Applied'}
                      >
                        {#if stagedChanges.has(feature.FeatureId)}
                          {#if getStatus(feature.FeatureId) === 'Applied'}
                            <Minus size={10} strokeWidth={4} />
                          {:else}
                            <Check size={10} strokeWidth={4} />
                          {/if}
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
  </TacticalContainer>
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



  .tweak-grid {
    column-count: 3;
    column-gap: 16px;
    padding: 16px;
    padding-top: 32px; /* Breathing room for industrial shadow */
    overflow-y: auto;
    flex: 1;
    display: block; /* Override default flex from TacticalContainer if any, though it should be block for columns */
  }

  .category-card {
    display: inline-block; /* Essential for masonry-like column flow */
    width: 100%;
    break-inside: avoid-column;
    margin-bottom: 24px; /* Matches the vertical breathing room in the provided image */
    background: rgba(255, 255, 255, 0.01);
    border: 1px solid rgba(255, 255, 255, 0.02);
    border-radius: 4px;
  }

  .card-header {
    height: 28px;
    display: flex;
    align-items: center;
    padding: 0 4px; /* Tighter industrial gutter */
    background: transparent;
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
    margin-bottom: 8px;
  }

  .card-header h3 {
    font-size: 10px;
    font-weight: 800;
    color: rgba(255, 255, 255, 0.4);
    letter-spacing: 0.15em; /* Industrial high-density spacing */
    margin: 0;
    text-transform: uppercase;
  }

  .cat-icon {
    font-family: inherit; /* Use standard icon for now */
    font-size: 14px;
    width: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: rgba(255, 255, 255, 0.15);
    opacity: 0.5;
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
    display: flex;
    align-items: center;
    height: 32px;
    margin: 0px; /* Flush industrial alignment */
    padding: 0 12px;
    font-size: 11px;
    cursor: pointer;
    border-radius: 0px; /* Squared off for flush stacking, except for card rounding if applied elsewhere? No, row doesn't need rounding if stacked */
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    
    /* v7 Material Standard */
    background: linear-gradient(to right, var(--slab-edge), var(--slab-base));
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-top: 1px solid var(--slab-rim);
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.03);
    flex-shrink: 0;
  }

  .tweak-row:hover:not(.selected) {
    background: var(--slab-base);
    filter: brightness(1.2);
  }

  .tweak-row.selected {
    background: 
      linear-gradient(135deg, rgba(var(--accent-rgb), 0.12), rgba(var(--accent-rgb), 0.05)),
      linear-gradient(to right, #1A1C1D 0%, #222526 15%, #222526 85%, #1A1C1D 100%) !important;
    border: 1px solid rgba(var(--accent-rgb), 0.6) !important; 
    box-shadow:
      0 0 12px rgba(var(--accent-rgb), 0.15),
      inset 0 0 0 1px rgba(var(--accent-rgb), 0.05);
  }

  /* Verified Applied Indication */
  .tweak-row.v-applied {
    border-left: 2px solid var(--risk-safe);
  }

  .tweak-row.selected .tweak-name {
    color: #fff;
    text-shadow: 0 0 8px rgba(255, 255, 255, 0.3);
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
    width: 18px; /* Synchronized with Apps.svelte */
    height: 18px;
    background: rgba(0, 0, 0, 0.35) !important; /* Bloom Base - Sunken */
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    flex-shrink: 0;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.4);
  }

  /* INTENT TO APPLY: Luminous Accent Border */
  .bloom-checkbox.checked {
    border-color: rgba(var(--accent-rgb), 0.85) !important; 
    box-shadow:
      0 0 10px rgba(var(--accent-rgb), 0.3),
      inset 0 1px 3px rgba(0, 0, 0, 0.4);
    background: rgba(var(--accent-rgb), 0.05) !important;
    color: #fff;
  }

  /* INTENT TO REVERT: Luminous Red Alert Border */
  .bloom-checkbox.reverting {
    border-color: rgba(255, 61, 96, 0.85) !important;
    box-shadow:
      0 0 10px rgba(255, 61, 96, 0.3),
      inset 0 1px 3px rgba(0, 0, 0, 0.4);
    background: rgba(255, 61, 96, 0.05) !important;
    color: #fff;
  }

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
