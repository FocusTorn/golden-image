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

  // Balanced Height Distribution Logic
  function distributeCategories(cats: any[], features: any[]) {
    const columns: any[][] = [[], [], []];
    const itemWeights = [0, 0, 0];
    
    if (!cats || cats.length === 0) return columns;

    // Create a copy to sort or process if needed, but here we just iterate
    // and greedily place into the shortest column
    cats.forEach(cat => {
      const featureCount = (features || []).filter(f => f.Category === cat.Name).length;
      // We add a "tax" of 6 items for the Card Header/Margins to account for visual height
      const categoryWeight = featureCount + 6;
      
      // Find shortest column
      let shortestIdx = 0;
      if (itemWeights[1] < itemWeights[0]) shortestIdx = 1;
      if (itemWeights[2] < itemWeights[shortestIdx]) shortestIdx = 2;
      
      columns[shortestIdx].push(cat);
      itemWeights[shortestIdx] += categoryWeight;
    });
    
    return columns;
  }

  $: balancedCols = distributeCategories(categories, featuresConfig?.Features);
  $: col1 = balancedCols[0];
  $: col2 = balancedCols[1];
  $: col3 = balancedCols[2];
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
        {#each [col1, col2, col3] as col}
          <div class="tweak-column">
            {#each col as category}
              <div class="category-card">
                <div class="card-header">
                  <span class="cat-icon">{@html category.Icon}</span>
                  <h3>{category.Name.toUpperCase()}</h3>
                  <div class="spacer"></div>
                </div>
                
                <div class="card-body">
                  {#each getFilteredFeatures(category.Name) as feature}
                    <div 
                      class="tweak-row" 
                      role="button"
                      tabindex="0"
                      class:selected={stagedChanges.has(feature.FeatureId)}
                      class:v-applied={getStatus(feature.FeatureId) === 'Applied'}
                      style="--status-color: {getStatusColor(feature.FeatureId)}"
                      on:mouseenter={() => handleMouseEnter(feature)}
                      on:mouseleave={handleMouseLeave}
                      on:click={() => toggleStage(feature.FeatureId)}
                      on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') toggleStage(feature.FeatureId); }}
                    >
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

                      <span class="tweak-name">{feature.Label}</span>
                      
                      {#if hoveredFeatureId === feature.FeatureId && hoveredDescription}
                        <div class="tweak-tooltip">
                          {hoveredDescription}
                        </div>
                      {/if}

                      <div class="spacer"></div>
                    </div>
                  {/each}
                </div>
              </div>
            {/each}
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
    background: transparent; /* Synchronized with Apps.svelte */
  }

  .tweak-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    grid-gap: 16px;
    padding: 16px;
    padding-top: 32px;
    overflow-y: auto;
    flex: 1;
    scrollbar-gutter: stable;
    align-items: flex-start;
  }

  .tweak-column {
    display: flex;
    flex-direction: column;
    gap: 24px; /* Vertical gap between stacked cards */
  }

  /* Industrial Scrollbar - Synchronized with Apps.svelte */
  .tweak-grid::-webkit-scrollbar {
    width: 6px;
  }
  .tweak-grid::-webkit-scrollbar-track {
    background: transparent;
  }
  .tweak-grid::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.1);
    border-radius: 12px 12px 0 0;
  }
  .tweak-grid::-webkit-scrollbar-thumb:hover {
    background: rgba(255, 255, 255, 0.2);
  }

  .category-card {
    width: 100%;
    background: #1a1f21; /* Dark-grey card background */
    border: 1px solid rgba(255, 255, 255, 0.05); /* Subtle light-grey border */
    border-radius: 6px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5); /* Slight drop shadow */
    overflow: hidden;
    flex-shrink: 0;
  }

  .card-header {
    height: 32px;
    display: flex;
    align-items: center;
    padding: 0 12px;
    background: rgba(255, 255, 255, 0.02); /* Very subtle header differentiation */
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    margin-bottom: 4px;
  }

  .card-header h3 {
    font-size: 10px;
    font-weight: 800;
    color: rgba(255, 255, 255, 0.4);
    letter-spacing: 0.15em;
    margin: 0;
    text-transform: uppercase;
  }

  .cat-icon {
    font-size: 14px;
    width: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: rgba(255, 255, 255, 0.15);
  }

  .card-body {
    padding: 8px;
    display: flex;
    flex-direction: column;
    gap: 6px; /* Row separation */
  }

  .tweak-row {
    position: relative;
    display: flex;
    align-items: center;
    height: 34px;
    padding: 0 12px;
    padding-left: 14px; /* Room for the accent stripe */
    font-size: 11px;
    cursor: pointer;
    transition: all 0.2s ease;
    background: #23282a; /* Slightly lighter dark-grey for rows */
    border: 1px solid rgba(255, 255, 255, 0.03);
    border-radius: 4px;
    flex-shrink: 0;
    overflow: hidden;
  }

  /* Vertical Status Accent Stripe */
  .tweak-row::before {
    content: '';
    position: absolute;
    left: 0;
    top: 4px;
    bottom: 4px;
    width: 3px; /* Slightly wider for better visibility */
    background: var(--status-color); /* Dynamically assigned from JS */
    opacity: 0.95;
    box-shadow: 0 0 8px var(--status-color); /* Subtle glow for the indicator */
  }

  .tweak-row:hover {
    background: #2a3033;
    border-color: rgba(255, 255, 255, 0.1);
  }

  .tweak-row.selected {
    background: #2d3437;
    border-color: rgba(0, 188, 212, 0.3);
  }

  .tweak-name {
    font-size: 11px;
    color: rgba(255, 255, 255, 0.7);
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .tweak-tooltip {
    position: absolute;
    bottom: 100%;
    left: 24px;
    background: #1a1f21;
    border: 1px solid rgba(255, 255, 255, 0.1);
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
    width: 20px;
    display: flex;
    justify-content: center;
    margin-right: 12px;
  }

  .bloom-checkbox {
    width: 16px;
    height: 16px;
    background: rgba(0, 0, 0, 0.2);
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 3px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    flex-shrink: 0;
  }

  /* Cyan Accent for Checked State */
  .bloom-checkbox.checked {
    background: #00bcd4 !important; /* Cyan Accent */
    border-color: #00bcd4 !important;
    color: #000; /* Dark icon on cyan */
    box-shadow: 0 0 8px rgba(0, 188, 212, 0.4);
  }

  .bloom-checkbox.reverting {
    background: #ff1744 !important; /* Red for Revert Intent */
    border-color: #ff1744 !important;
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
