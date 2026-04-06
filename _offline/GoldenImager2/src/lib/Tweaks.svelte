<script lang="ts">
  import { RefreshCw, Cog, Zap, Palette, RectangleEllipsis, FileStack, Activity, ShieldCheck, Target, Cpu, Brain, Grid2x2, Check, Minus } from "lucide-svelte";
  import TacticalToolbar from "./TacticalToolbar.svelte";
  import TacticalContainer from "./TacticalContainer.svelte";
  import TweakCard from "./TweakCard.svelte";
  import { TweaksEngine } from "./tweaks-engine.svelte";

  interface Props {
    appliedCount?: number;
    totalCount?: number;
  }

  let { appliedCount = $bindable(0), totalCount = $bindable(0) }: Props = $props();

  const engine = new TweaksEngine();

  const CATEGORY_MAP: Record<string, string> = {
    "AI": "COPILOT",
    "Windows Updates": "WINDOWS",
    "Windows Features": "WINDOWS",
    "Optional Windows Features": "WINDOWS"
  };

  const DASHBOARD_ACTIONS = new Set(["ClearStart", "ClearStartAllUsers", "CreateRestorePoint", "RemoveApps", "Apps", "RemoveAppsCustom", "RemoveCommApps", "RemoveW11Outlook", "RemoveGamingApps", "RemoveHPApps", "ReplaceStart", "ReplaceStartAllUsers", "ForceRemoveEdge", "DeleteTemporaryFiles", "RunDiskCleanup", "SystemCorruptionScan", "WinGetReinstall"]);

  let displayCategories = $derived.by(() => {
    if (!engine.featuresConfig) return [];
    const seen = new Set<string>();
    const cats = (engine.featuresConfig.Categories || []).map((c: any) => {
      const name = c.Name || "Other";
      const mapped = CATEGORY_MAP[name] || name.toUpperCase();
      return { ...c, displayName: mapped };
    }).filter((c: any) => {
      if (seen.has(c.displayName)) return false;
      seen.add(c.displayName);
      return true;
    });
    if ((engine.featuresConfig.Features || []).some((f: any) => !f.Category) && !seen.has("OTHER")) {
      cats.push({ Name: "Other", displayName: "OTHER" });
    }
    return cats;
  });

  let groupedFeatureIds = $derived(new Set((engine.featuresConfig?.UiGroups || []).flatMap((g: any) => (g.Values || []).flatMap((v: any) => v.FeatureIds || []))));

  function getCombinedItems(displayName: string) {
    const features = (engine.featuresConfig?.Features || []).filter((f: any) => {
      if (DASHBOARD_ACTIONS.has(f.FeatureId) || groupedFeatureIds.has(f.FeatureId)) return false;
      const mapped = CATEGORY_MAP[f.Category || "Other"] || (f.Category || "Other").toUpperCase();
      return mapped === displayName && (f.Label || "").toLowerCase().includes(engine.searchQuery.toLowerCase());
    }).map((f: any) => ({ ...f, itemType: 'feature' }));

    const groups = (engine.featuresConfig?.UiGroups || []).filter((g: any) => {
      const mapped = CATEGORY_MAP[g.Category || "Other"] || (g.Category || "Other").toUpperCase();
      return mapped === displayName && (g.Label || "").toLowerCase().includes(engine.searchQuery.toLowerCase());
    }).map((g: any) => ({ ...g, itemType: 'group' }));

    return [...features, ...groups].sort((a, b) => (a.Priority || 99) - (b.Priority || 99));
  }

  function getGroupAppliedLabel(group: any) {
    const applied = group.Values.find((val: any) => val.FeatureIds.every((id: string) => engine.getStatus(id) === "Applied"));
    return applied ? applied.Label : "NONE";
  }

  function getGroupAppliedValue(group: any) {
    const applied = group.Values.find((val: any) => val.FeatureIds.every((id: string) => engine.getStatus(id) === "Applied"));
    return applied ? applied.FeatureIds[0] : "none";
  }

  function getStatusColor(id: string) {
    const isStaged = engine.stagedChanges.has(id);
    if (isStaged) return "#ffd600";
    return engine.getStatus(id) === "Applied" ? "var(--risk-safe)" : "rgba(0, 0, 0, 0.35)";
  }

  function getGroupStatusColor(group: any) {
    const appliedValue = getGroupAppliedValue(group);
    const stagedValue = engine.groupStagedChanges[group.GroupId];
    if (stagedValue && stagedValue !== appliedValue) return "#ffd600";
    return appliedValue !== "none" ? "var(--risk-safe)" : "rgba(0, 0, 0, 0.35)";
  }

  function distributeCategories(cats: any[]) {
    const cols: any[][] = [[], [], []];
    const heights = [0, 0, 0];
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

  let balancedCols = $derived(distributeCategories(displayCategories));

  $effect(() => {
    appliedCount = engine.auditResults.filter(r => r.Status === 'Applied').length;
    totalCount = engine.auditResults.length;
  });
</script>

<div class="panel">
  <TacticalToolbar 
    showPolicy={false}
    profiles={engine.profiles}
    bind:selectedProfile={engine.selectedProfile}
    bind:searchTerm={engine.searchQuery}
    loading={engine.loading}
    selectionCount={engine.stagedChanges.size + Object.keys(engine.groupStagedChanges).length}
    profileLabel="Tweak-Profiles"
    applyLabel="Update Changes"
    onrefresh={() => engine.refresh()}
    onapply={() => engine.apply()}
    onloadProfile={() => engine.loadProfile()}
    onsaveProfile={() => engine.saveProfile()}
    onsaveAsProfile={() => { const n = prompt("Name:"); if(n) engine.saveProfile(n); }}
    ondeleteProfile={(p) => engine.deleteProfile(p)}
  />

  <TacticalContainer padding="8px 12px">
    {#if engine.loading}
      <div class="state-view">
        <RefreshCw size={32} class="spin active-bloom" />
        <span>Synchronizing Registry State...</span>
      </div>
    {:else if engine.error}
      <div class="state-view error">
        <span>Sync Failure: {engine.error}</span>
        <button class="retry-btn" onclick={() => engine.refresh()}>Retry Connection</button>
      </div>
    {:else}
      <div class="tweak-grid">
        {#each balancedCols as col}
          <div class="tweak-column">
            {#each col as cat}
              <TweakCard 
                displayName={cat.displayName}
                items={getCombinedItems(cat.displayName)}
                stagedChanges={engine.stagedChanges}
                groupStagedChanges={engine.groupStagedChanges}
                getStatus={(id) => engine.getStatus(id)}
                getStatusColor={getStatusColor}
                getGroupStatusColor={getGroupStatusColor}
                getGroupAppliedValue={getGroupAppliedValue}
                getGroupAppliedLabel={getGroupAppliedLabel}
                ontoggleTweak={(id) => engine.toggleTweak(id)}
                ontoggleGroup={(gid, fid) => engine.toggleGroup(gid, fid)}
              />
            {/each}
          </div>
        {/each}
      </div>
    {/if}
  </TacticalContainer>
</div>

<style>
  .panel { display: flex; flex-direction: column; height: 100%; gap: 0; overflow: hidden; --risk-safe: #00e676; }
  .tweak-grid { display: grid; grid-template-columns: repeat(3, 1fr); grid-gap: 16px; padding: 16px; overflow-y: auto; flex: 1; align-items: flex-start; scrollbar-gutter: stable; }
  .tweak-column { display: flex; flex-direction: column; gap: 16px; }
  .tweak-grid::-webkit-scrollbar { width: 6px; }
  .tweak-grid::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.1); border-radius: 12px; }
  .state-view { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 20px; color: rgba(255, 255, 255, 0.4); font-size: 12px; }
  :global(.active-bloom) { color: #00bcd4; filter: drop-shadow(0 0 10px rgba(0, 188, 212, 0.5)); }
  .retry-btn { margin-top: 10px; background: rgba(255, 255, 255, 0.1); border: 1px solid rgba(255, 255, 255, 0.1); color: #fff; padding: 4px 12px; border-radius: 4px; cursor: pointer; }
</style>
