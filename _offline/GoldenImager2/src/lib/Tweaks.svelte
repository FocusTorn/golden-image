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
    Zap,
    Activity,
    ShieldCheck,
    Target,
    Cpu,
    Brain,
    RectangleEllipsis,
    FileStack,
    Palette,
    Grid2x2
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

  // Mapping for categorical merging and renaming
  const CATEGORY_MAP: Record<string, string> = {
    "AI": "COPILOT",
    "Windows Updates": "WINDOWS",
    "Windows Features": "WINDOWS",
    "Optional Windows Features": "WINDOWS"
  };

  $: rawCategories = featuresConfig?.Categories || [];
  $: displayCategories = (() => {
    const seen = new Set<string>();
    return rawCategories.map(c => {
      const mapped = CATEGORY_MAP[c.Name] || c.Name.toUpperCase();
      return { ...c, displayName: mapped };
    }).filter(c => {
      if (seen.has(c.displayName)) return false;
      seen.add(c.displayName);
      return true;
    });
  })();

  function getFilteredFeatures(displayName: string) {
    const allFeatures = featuresConfig?.Features || [];
    return allFeatures.filter(f => {
      const mappedName = CATEGORY_MAP[f.Category] || f.Category.toUpperCase();
      const matchesCat = mappedName === displayName;
      const matchesSearch = f.Label.toLowerCase().includes(searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    });
  }

  // Balanced distribution for 3 columns
  $: [col1, col2, col3] = distributeCategories(displayCategories);

  function distributeCategories(cats: any[]) {
    const cols: any[][] = [[], [], []];
    const heights = [0, 0, 0];
    
    // Weight: 30 units base + 10 per feature
    cats.forEach(cat => {
      const features = getFilteredFeatures(cat.displayName);
      const weight = 30 + (features.length * 10);
      
      const minIdx = heights.indexOf(Math.min(...heights));
      cols[minIdx].push(cat);
      heights[minIdx] += weight;
    });
    
    return cols;
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
        {#each [col1, col2, col3] as col}
          <div class="tweak-column">
            {#each col as cat}
              <div class="category-card">
                <div class="card-header">
                  <span class="cat-icon-lucide">
                    {#if cat.displayName === "COPILOT"}
                      <Brain size={16} strokeWidth={3.5} />
                    {:else if cat.displayName === "WINDOWS"}
                      <Grid2x2 size={16} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("ESSENTIALS")}
                      <Zap size={16} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("APPEARANCE")}
                      <Palette size={16} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("TASKBAR")}
                      <RectangleEllipsis size={16} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("EXPLORER")}
                      <FileStack size={16} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("ADVANCED")}
                      <Activity size={16} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("PRIVACY")}
                      <ShieldCheck size={16} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("GAMING")}
                      <Target size={16} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("SYSTEM")}
                      <Cpu size={16} strokeWidth={3.5} />
                    {:else}
                      <Cog size={16} strokeWidth={3.5} />
                    {/if}
                  </span>
                  <h3>{cat.displayName}</h3>
                  <div class="spacer"></div>
                </div>
                
                <div class="card-body">
                  {#each getFilteredFeatures(cat.displayName) as feature}
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
    background: #1a1f22; /* Calibrated slate charcoal from reference */
    border: 1px solid rgba(255, 255, 255, 0.08); /* Subtle high-def border */
    border-radius: 8px;
    /* Misted atmospheric glow from reference */
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
    background: transparent;
    border-bottom: none; /* Removed divider line */
    margin-bottom: 0px;
  }

  .card-header h3 {
    font-size: 10px; /* Parity with Apps.svelte table-header */
    font-weight: 800; /* Parity with Apps.svelte table-header */
    color: #fff; /* Brighter, high-contrast header text */
    letter-spacing: 0.18em;
    margin: 0;
    text-transform: uppercase;
    opacity: 0.8;
  }

  .cat-icon-lucide {
    display: flex;
    align-items: center;
    justify-content: center;
    color: #fff; /* Synchronized with title text luminosity */
    margin-right: 12px;
    opacity: 0.8;
  }

  .card-body {
    padding: 8px 10px;
    display: flex;
    flex-direction: column;
    gap: 5px; /* Precise gap from reference */
  }

  .tweak-row {
    position: relative;
    display: flex;
    align-items: center;
    height: 31px; /* Tighter industrial density */
    padding: 0 12px;
    padding-left: 16px;
    font-size: 11px;
    cursor: pointer;
    transition: all 0.15s ease;
    
    /* Matte Charcoal Plate from reference */
    background: #242a2d; 
    
    /* Hardware Rim / Outer Shadow */
    border: 1px solid rgba(255, 255, 255, 0.04);
    border-radius: 5px;
    flex-shrink: 0;
    overflow: hidden;
    
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  }

  /* Radiant Status Hub (Vertical Strip) */
  .tweak-row::before {
    content: '';
    position: absolute;
    left: 0;
    top: 5px;
    bottom: 5px;
    width: 4px;
    background: var(--status-color);
    opacity: 1;
    /* High-fidelity LED glow logic */
    filter: blur(0.3px);
    box-shadow: 0 0 12px var(--status-color); 
    z-index: 2;
    border-radius: 0 2px 2px 0;
  }

  .tweak-row:hover {
    filter: brightness(1.2);
    box-shadow: 
      inset 0 1px 0 rgba(255, 255, 255, 0.08),
      0 4px 16px rgba(0, 0, 0, 0.5);
  }

  .tweak-row.selected {
    background: linear-gradient(to bottom, #3a3a3a 0%, #2a2a2a 100%);
    border-color: rgba(0, 188, 212, 0.2);
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
    gap: 20px;
    color: rgba(255, 255, 255, 0.4);
    background: radial-gradient(circle, rgba(255, 255, 255, 0.02) 0%, transparent 70%);
    position: relative;
    overflow: hidden;
  }

  /* Industrial Glow Spinner */
  .state-view :global(.spin) {
    color: #00bcd4; /* Active Bloom Color */
    filter: drop-shadow(0 0 10px rgba(0, 188, 212, 0.5));
    animation: spin 1.2s cubic-bezier(0.4, 0, 0.2, 1) infinite, pulse-glow-active 2s ease-in-out infinite;
  }

  .state-view span {
    font-size: 10.5px;
    font-weight: 700;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: rgba(255, 255, 255, 0.75); /* Brighter Text */
    text-shadow: 0 2px 10px rgba(0, 0, 0, 0.8), 0 0 8px rgba(255, 255, 255, 0.2);
  }

  @keyframes pulse-glow-active {
    0%, 100% { filter: drop-shadow(0 0 8px rgba(0, 188, 212, 0.3)); opacity: 0.8; }
    50% { filter: drop-shadow(0 0 18px rgba(0, 188, 212, 0.6)); opacity: 1; }
  }

  .error { color: var(--risk-unsafe); }
  
  .retry-btn {
    background: rgba(var(--risk-unsafe-rgb, 255, 61, 96), 0.1);
    border: 1px solid var(--risk-unsafe);
    color: var(--risk-unsafe);
    padding: 6px 16px;
    border-radius: 4px;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    cursor: pointer;
    transition: all 0.2s;
  }

  .retry-btn:hover {
    background: var(--risk-unsafe);
    color: #fff;
    box-shadow: 0 0 12px rgba(255, 61, 96, 0.4);
  }
</style>
