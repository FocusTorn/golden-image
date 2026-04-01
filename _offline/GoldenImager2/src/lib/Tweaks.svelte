<script lang="ts">
  import { onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/tauri";
  import { 
    Cog, 
    RefreshCw, 
    Check, 
    Minus,
    ChevronDown,
    Download,
    Plus,
    Save,
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
  import TweakSelect from "./TweakSelect.svelte";
  import { vhdStore } from "./store";
  import { notificationStore } from "./notifications";

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
        
        // Pass only the non-dashboard items to the lazy audit engine
        const auditTargets = (featuresConfig?.Features || [])
          .filter((f: any) => !DASHBOARD_ACTIONS.has(f.FeatureId))
          .map((f: any) => f.FeatureId);
          
        auditResults = await invoke("get_audit_results", { featureIds: auditTargets });
        profiles = await invoke("list_tweak_profiles");
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
          { FeatureId: "DisableWPBT", Status: "Applied" },
          { FeatureId: "DisableTelemetry", Status: "Not Applied" }
        ];
      }
      
      if (featuresConfig?.Categories?.length > 0) {
        if (!activeCategory || !featuresConfig.Categories.find((c: any) => c.Name === activeCategory)) {
          activeCategory = featuresConfig.Categories[0].Name;
        }
      }
    } catch (e) {
      error = typeof e === "string" ? e : "Sync Failure";
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    loadData();
    
    let unlisten: any;
    if (isTauri) {
      import("@tauri-apps/api/event").then(({ listen }) => {
        listen("features-config-updated", () => {
          console.log(">>> Live Update: Refreshing config labels...");
          loadData();
          notificationStore.add("Configuration updated live.", "info");
        }).then(u => unlisten = u);
      });
    }

    return () => {
      if (unlisten) unlisten();
    };
  });

  function getStatus(id: string) {
    const res = auditResults.find(r => r.FeatureId === id);
    return res ? res.Status : "Unknown";
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
    if (stagedChanges.size === 0 && Object.keys(groupStagedChanges).length === 0) return;
    
    loading = true;
    try {
      const allStagedIds = [
        ...Array.from(stagedChanges),
        ...Object.values(groupStagedChanges).filter(id => id && id !== "none")
      ];
      
      await invoke("apply_features_batch", { 
        featureIds: allStagedIds, 
        offlineHive: null,
        targetVm: $vhdStore.remoteActive ? $vhdStore.vmName : null
      });

      stagedChanges.clear();
      groupStagedChanges = {};
      stagedChanges = stagedChanges;
      groupStagedChanges = groupStagedChanges;
      
      await loadData();
      notificationStore.add("Changes applied successfully.", "success");
    } catch (e) {
      console.error("Action failed:", e);
      notificationStore.add(`Failed to apply changes: ${e}`, "error");
    } finally {
      loading = false;
    }
  }

  // Group handling
  let groupStagedChanges: Record<string, string> = {}; // GroupId -> FeatureId (single selected)

  function toggleGroupStage(groupId: string, featureId: string) {
    if (!featureId || featureId === "none") {
      delete groupStagedChanges[groupId];
    } else {
      groupStagedChanges[groupId] = featureId;
    }
    groupStagedChanges = groupStagedChanges;
  }

  function getGroupAppliedLabel(group: any) {
    for (const val of group.Values) {
      if (val.FeatureIds.every((id: string) => getStatus(id) === "Applied")) {
        return val.Label;
      }
    }
    return "Applied"; // Fallback label or "No Change"
  }

  function getStatusColor(id: string) {
    const status = getStatus(id);
    const isStaged = stagedChanges.has(id);
    
    if (isStaged) {
      return "var(--risk-staged)"; // Yellow for staged
    }
    
    return status === "Applied" ? "var(--risk-safe)" : "var(--risk-unknown)";
  }

  function getGroupAppliedValue(group: any) {
    const applied = group.Values.find((val: any) => val.FeatureIds.every((id: string) => getStatus(id) === "Applied"));
    return applied ? applied.FeatureIds[0] : "none";
  }

  function getGroupStatusColor(group: any) {
    const appliedValue = getGroupAppliedValue(group);
    const stagedValue = groupStagedChanges[group.GroupId];
    
    // If we have a staged change that differs from the system setting
    if (stagedValue && stagedValue !== appliedValue) {
      return "var(--risk-staged)"; // Yellow for staged
    }
    
    // if not applied, unknown grey
    return appliedValue !== "none" ? "var(--risk-safe)" : "var(--risk-unknown)";
  }

  async function handleLoadProfile() {
    if (!selectedProfile) return;
    loading = true;
    try {
      const settings = await invoke("load_tweak_profile", { name: selectedProfile });
      stagedChanges.clear();
      groupStagedChanges = {};
      
      for (const s of settings as any[]) {
        if (s.Value === true) {
          stagedChanges.add(s.Name);
        } else if (typeof s.Value === "string" && s.Value !== "No Change") {
          // Check if it's a group selection
          const group = (featuresConfig?.UiGroups || []).find((g: any) => g.GroupId === s.Name);
          if (group) {
            const val = group.Values.find((v: any) => v.Label === s.Value);
            if (val && val.FeatureIds.length > 0) {
              groupStagedChanges[group.GroupId] = val.FeatureIds[0];
            }
          }
        }
      }
      stagedChanges = stagedChanges;
      groupStagedChanges = groupStagedChanges;
      notificationStore.add(`Profile "${selectedProfile}" loaded.`, 'info');
    } catch (e) {
      notificationStore.add(`Load failed: ${e}`, 'error');
    } finally {
      loading = false;
    }
  }

  async function handleSaveProfile() {
    if (!selectedProfile) return handleSaveAsProfile();
    await saveCurrentProfile(selectedProfile);
  }

  async function handleSaveAsProfile() {
    const name = prompt("Enter profile name:");
    if (name) {
      await saveCurrentProfile(name);
      profiles = await invoke("list_tweak_profiles");
      selectedProfile = name.endsWith(".json") ? name : name + ".json";
    }
  }

  async function saveCurrentProfile(name: string) {
    const settings = [];
    for (const id of Array.from(stagedChanges)) {
      settings.push({ Name: id, Value: true });
    }
    for (const [groupId, featureId] of Object.entries(groupStagedChanges)) {
      const group = featuresConfig.UiGroups.find((g: any) => g.GroupId === groupId);
      const val = group?.Values.find((v: any) => v.FeatureIds.includes(featureId));
      if (val) {
        settings.push({ Name: groupId, Value: val.Label });
      }
    }
    
    try {
      await invoke("save_tweak_profile", { name, settings });
      notificationStore.add(`Profile "${name}" saved successfully.`, 'success');
    } catch (e) {
      notificationStore.add(`Save failed: ${e}`, 'error');
    }
  }

  async function handleDeleteProfile(name: any) {
    const profileName = name.detail || name;
    if (confirm(`Delete profile ${profileName}?`)) {
      try {
        await invoke("delete_tweak_profile", { name: profileName });
        profiles = await invoke("list_tweak_profiles");
        if (selectedProfile === profileName) selectedProfile = "";
        notificationStore.add(`Profile "${profileName}" deleted.`, 'warning');
      } catch (e) {
        notificationStore.add(`Delete failed: ${e}`, 'error');
      }
    }
  }

  let hoveredDescription: string | null = null;
  let hoveredFeatureId: string | null = null;

  // Actions migrated to Dashboard Home
  const DASHBOARD_ACTIONS = new Set([
    "ClearStart",
    "ClearStartAllUsers",
    "CreateRestorePoint",
    "RemoveApps",
    "Apps",
    "RemoveAppsCustom",
    "RemoveCommApps",
    "RemoveW11Outlook",
    "RemoveGamingApps",
    "RemoveHPApps",
    "ReplaceStart",
    "ReplaceStartAllUsers",
    "ForceRemoveEdge",
    "DeleteTemporaryFiles",
    "RunDiskCleanup",
    "SystemCorruptionScan",
    "WinGetReinstall"
  ]);

  // Mapping for categorical merging and renaming
  const CATEGORY_MAP: Record<string, string> = {
    "AI": "COPILOT",
    "Windows Updates": "WINDOWS",
    "Windows Features": "WINDOWS",
    "Optional Windows Features": "WINDOWS"
  };

  $: displayCategories = (() => {
    if (!featuresConfig) return [];
    const rawCategories = featuresConfig.Categories || [];
    const seen = new Set<string>();
    const cats = rawCategories.map(c => {
      const name = c.Name || "Other";
      const mapped = CATEGORY_MAP[name] || name.toUpperCase();
      return { ...c, displayName: mapped };
    }).filter(c => {
      if (seen.has(c.displayName)) return false;
      seen.add(c.displayName);
      return true;
    });

    // Ensure "OTHER" is present if there are features without a matching category
    const hasUncategorized = (featuresConfig?.Features || []).some(f => !f.Category);
    if (hasUncategorized && !seen.has("OTHER")) {
      cats.push({ Name: "Other", displayName: "OTHER" });
    }
    return cats;
  })();

  // Set of feature IDs that belong to a group (to hide standalone toggles)
  $: groupedFeatureIds = new Set(
    (featuresConfig?.UiGroups || []).flatMap(g => 
      (g.Values || []).flatMap(v => v.FeatureIds || [])
    )
  );

  function getCombinedItems(displayName: string) {
    const allFeatures = featuresConfig?.Features || [];
    const allGroups = featuresConfig?.UiGroups || [];

    const features = allFeatures.filter(f => {
      if (DASHBOARD_ACTIONS.has(f.FeatureId)) return false;
      if (groupedFeatureIds.has(f.FeatureId)) return false; // HIDE IF IN GROUP
      const categoryRaw = f.Category || "Other";
      const mappedName = CATEGORY_MAP[categoryRaw] || categoryRaw.toUpperCase();
      return mappedName === displayName && (f.Label || "").toLowerCase().includes(searchQuery.toLowerCase());
    }).map(f => ({ ...f, itemType: 'feature' }));

    const groups = allGroups.filter(g => {
      if (DASHBOARD_ACTIONS.has(g.GroupId)) return false;
      const categoryRaw = g.Category || "Other";
      const mappedName = CATEGORY_MAP[categoryRaw] || categoryRaw.toUpperCase();
      return mappedName === displayName && (g.Label || "").toLowerCase().includes(searchQuery.toLowerCase());
    }).map(g => ({ ...g, itemType: 'group' }));

    return [...features, ...groups].sort((a: any, b: any) => (a.Priority || 99) - (b.Priority || 99));
  }

  // Balanced distribution for 3 columns - Filters empty categories during search
  $: [col1, col2, col3] = distributeCategories(displayCategories, searchQuery);

  function distributeCategories(cats: any[], query: string) {
    const cols: any[][] = [[], [], []];
    const heights = [0, 0, 0];
    
    // Filtering logic moved inside distribution for absolute consistency
    const visible = cats.filter(cat => getCombinedItems(cat.displayName).length > 0);

    visible.forEach(cat => {
      const items = getCombinedItems(cat.displayName);
      const weight = 30 + (items.length * 10);
      
      const minIdx = heights.indexOf(Math.min(...heights));
      cols[minIdx].push(cat);
      heights[minIdx] += weight;
    });
    
    return cols;
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

  $: appliedCount = auditResults.filter(r => r.Status === 'Applied').length;
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
    on:loadProfile={handleLoadProfile}
    on:saveProfile={handleSaveProfile}
    on:saveAsProfile={handleSaveAsProfile}
    on:deleteProfile={handleDeleteProfile}
  />

  <TacticalContainer padding="0">
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
                  <span class="header-icon">
                    {#if cat.displayName === "COPILOT"}
                      <Brain size={14} strokeWidth={3.5} />
                    {:else if cat.displayName === "WINDOWS"}
                      <Grid2x2 size={14} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("ESSENTIALS")}
                      <Zap size={14} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("APPEARANCE")}
                      <Palette size={14} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("TASKBAR")}
                      <RectangleEllipsis size={14} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("EXPLORER")}
                      <FileStack size={14} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("ADVANCED")}
                      <Activity size={14} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("PRIVACY")}
                      <ShieldCheck size={14} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("GAMING")}
                      <Target size={14} strokeWidth={3.5} />
                    {:else if cat.displayName.includes("SYSTEM")}
                      <Cpu size={14} strokeWidth={3.5} />
                    {:else}
                      <Cog size={14} strokeWidth={3.5} />
                    {/if}
                  </span>
                  <h3>{cat.displayName}</h3>
                  <div class="spacer"></div>
                </div>
                
                <div class="card-body">
                  {#each getCombinedItems(cat.displayName) as item}
                    {#if item.itemType === 'feature'}
                      <div 
                        class="tweak-row" 
                        role="button"
                        tabindex="0"
                        class:selected={stagedChanges.has(item.FeatureId)}
                        class:v-applied={getStatus(item.FeatureId) === 'Applied'}
                        style="--status-color: {getStatusColor(item.FeatureId)}"
                        on:mouseenter={() => handleMouseEnter(item)}
                        on:mouseleave={handleMouseLeave}
                        on:click={() => toggleStage(item.FeatureId)}
                        on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') toggleStage(item.FeatureId); }}
                      >
                        <div class="checkbox-container">
                          {#if applyingFeature === item.FeatureId}
                            <RefreshCw size={8} class="spin" />
                          {:else}
                            <div 
                              class="bloom-checkbox" 
                              class:checked={stagedChanges.has(item.FeatureId)}
                              class:reverting={stagedChanges.has(item.FeatureId) && getStatus(item.FeatureId) === 'Applied'}
                            >
                              {#if stagedChanges.has(item.FeatureId)}
                                {#if getStatus(item.FeatureId) === 'Applied'}
                                  <Minus size={8} strokeWidth={4} />
                                {:else}
                                  <Check size={8} strokeWidth={4} />
                                {/if}
                              {/if}
                            </div>
                          {/if}
                        </div>

                        <span class="tweak-name">{item.Action ? item.Action + ' ' : ''}{item.Label}</span>
                        
                        {#if hoveredFeatureId === item.FeatureId && hoveredDescription}
                          <div class="tweak-tooltip">
                            {hoveredDescription}
                          </div>
                        {/if}

                        <div class="spacer"></div>
                      </div>
                    {:else if item.itemType === 'group'}
                      <div 
                        class="tweak-row group-row" 
                        style="--status-color: {getGroupStatusColor(item)}"
                      >
                        <span class="tweak-name">{item.Action ? item.Action + ' ' : ''}{item.Label}</span>
                        <div class="spacer"></div>
                        <TweakSelect 
                          options={item.Values}
                          value={groupStagedChanges[item.GroupId] || getGroupAppliedValue(item)}
                          appliedValue={getGroupAppliedValue(item)}
                          label={getGroupAppliedLabel(item)}
                          on:change={(e) => toggleGroupStage(item.GroupId, e.detail.value)}
                        />
                      </div>
                    {/if}
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
    padding: 12px 12px 12px 12px;
    gap: 8px;
    overflow: hidden;
    background: transparent; /* Synchronized with Apps.svelte */

    /* UNIFIED RISK PALETTE */
    --risk-safe: #00e676;
    --risk-staged: #ffd600; /* YELLOW */
    --risk-unsafe: #ff3d60;
    --risk-unknown: rgba(0, 0, 0, 0.35); /* APPS PANEL OFF-STATE */
  }

  .tweak-grid {
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
    gap: 16px; /* Vertical gap between stacked cards - Synchronized to 16px */
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
    overflow: visible; /* ALLOW POPUPS */
    flex-shrink: 0;
  }

  .card-header {
    height: 26px;
    display: flex;
    align-items: center;
    padding: 0 14px;
    background: transparent;
    border-bottom: none; /* Removed divider line */
    margin-bottom: 0px;
  }

  .card-header h3 {
    font-size: 11px;
    font-weight: 800;
    color: #fff; /* Brighter header */
    opacity: 0.9;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    text-shadow: 0 2px 10px rgba(0, 0, 0, 0.8), 0 0 8px rgba(255, 255, 255, 0.15);
  }

  .header-icon {
    margin-right: 12px;
    opacity: 0.9;
    filter: drop-shadow(0 0 12px rgba(var(--accent-rgb), 0.5));
    display: flex;
    align-items: center;
    color: var(--accent-color);
  }

  .card-body {
    padding: 4px 6px;
    display: flex;
    flex-direction: column;
    gap: 4px; /* Precise gap from reference */
    overflow: visible; /* ALLOW POPUPS */
  }

  .tweak-row {
    position: relative;
    display: flex;
    align-items: center;
    height: 24px; /* Tighter industrial density */
    padding: 0 8px;
    padding-left: 10px;
    font-size: 11px;
    cursor: pointer;
    transition: all 0.15s ease;
    
    /* Matte Charcoal Plate from reference */
    background: #242a2d; 
    
    /* Hardware Rim / Outer Shadow */
    border: 1px solid rgba(255, 255, 255, 0.04);
    border-radius: 5px;
    flex-shrink: 0;
    overflow: visible; /* ALLOW POPUPS */
    
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  }

  .tweak-row:hover {
    background: rgba(255, 255, 255, 0.04);
    z-index: 100 !important;
  }

  .group-row {
    cursor: default;
    justify-content: space-between;
    gap: 8px;
    height: 24px; /* Match standard row height for consistency */
    transition: all 0.2s;
    overflow: visible !important; /* ALLOW POPUPS TO SPILL OUT */
    z-index: 52; /* Ensure it stays above checkbox-based rows */
  }

  /* Radiant Status Hub (Vertical Strip) */
  .tweak-row::before {
    content: '';
    position: absolute;
    left: 0;
    top: 4px;
    bottom: 4px;
    width: 4px;
    background: var(--status-color);
    opacity: 1;
    /* High-fidelity LED glow logic */
    filter: blur(0.3px);
    box-shadow: 
      0 0 12px var(--status-color),
      inset 0 1px 2px rgba(255, 255, 255, 0.05); /* Machined look */
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
    margin-right: 6px;
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

  .tweak-tooltip {
    position: absolute;
    bottom: 110%;
    left: 20px;
    background: rgba(18, 18, 18, 0.98);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 4px;
    padding: 8px 12px;
    color: rgba(255, 255, 255, 0.9);
    font-size: 10px;
    font-weight: 500;
    line-height: 1.4;
    width: 260px;
    z-index: 1000;
    pointer-events: none;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.8), 0 0 0 1px rgba(255, 255, 255, 0.05);
    backdrop-filter: blur(12px);
    transition: all 0.15s ease-out;
  }
</style>
