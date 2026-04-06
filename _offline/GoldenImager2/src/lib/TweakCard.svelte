<script lang="ts">
  import { 
    Cog, Zap, Palette, RectangleEllipsis, FileStack, Activity, 
    ShieldCheck, Target, Cpu, Brain, Grid2x2, Check, Minus 
  } from "lucide-svelte";
  import TweakSelect from "./TweakSelect.svelte";

  interface Props {
    displayName: string;
    items: any[];
    stagedChanges: Set<string>;
    groupStagedChanges: Record<string, string>;
    getStatus: (id: string) => string;
    getStatusColor: (id: string) => string;
    getGroupStatusColor: (group: any) => string;
    getGroupAppliedValue: (group: any) => string;
    getGroupAppliedLabel: (group: any) => string;
    ontoggleTweak: (id: string) => void;
    ontoggleGroup: (groupId: string, featureId: string) => void;
  }

  let { 
    displayName, 
    items, 
    stagedChanges, 
    groupStagedChanges, 
    getStatus, 
    getStatusColor,
    getGroupStatusColor,
    getGroupAppliedValue, 
    getGroupAppliedLabel,
    ontoggleTweak,
    ontoggleGroup
  }: Props = $props();

  let hoveredFeatureId = $state<string | null>(null);
  let hoveredDescription = $state<string | null>(null);

  function handleMouseEnter(item: any) {
    hoveredFeatureId = item.FeatureId;
    hoveredDescription = item.ToolTip;
  }

  function handleMouseLeave() {
    hoveredFeatureId = null;
    hoveredDescription = null;
  }
</script>

<div class="category-card">
  <div class="card-header">
    <span class="header-icon">
      {#if displayName === "COPILOT"}<Brain size={14} strokeWidth={3.5} />
      {:else if displayName === "WINDOWS"}<Grid2x2 size={14} strokeWidth={3.5} />
      {:else if displayName.includes("ESSENTIALS")}<Zap size={14} strokeWidth={3.5} />
      {:else if displayName.includes("APPEARANCE")}<Palette size={14} strokeWidth={3.5} />
      {:else if displayName.includes("TASKBAR")}<RectangleEllipsis size={14} strokeWidth={3.5} />
      {:else if displayName.includes("EXPLORER")}<FileStack size={14} strokeWidth={3.5} />
      {:else if displayName.includes("ADVANCED")}<Activity size={14} strokeWidth={3.5} />
      {:else if displayName.includes("PRIVACY")}<ShieldCheck size={14} strokeWidth={3.5} />
      {:else if displayName.includes("GAMING")}<Target size={14} strokeWidth={3.5} />
      {:else if displayName.includes("SYSTEM")}<Cpu size={14} strokeWidth={3.5} />
      {:else}<Cog size={14} strokeWidth={3.5} />{/if}
    </span>
    <h3>{displayName}</h3>
  </div>

  <div class="card-body">
    {#each items as item}
      {#if item.itemType === 'feature'}
        <div 
          class="tweak-row" 
          role="button"
          tabindex="0"
          class:v-applied={getStatus(item.FeatureId) === 'Applied'}
          style="--status-color: {getStatusColor(item.FeatureId)}"
          onmouseenter={() => handleMouseEnter(item)}
          onmouseleave={handleMouseLeave}
          onclick={() => ontoggleTweak(item.FeatureId)}
          onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && ontoggleTweak(item.FeatureId)}
        >
          <div class="checkbox-container">
            <div 
              class="bloom-checkbox" 
              class:checked={stagedChanges.has(item.FeatureId)}
              class:reverting={stagedChanges.has(item.FeatureId) && getStatus(item.FeatureId) === 'Applied'}
            >
              {#if stagedChanges.has(item.FeatureId)}
                {#if getStatus(item.FeatureId) === 'Applied'}<Minus size={8} strokeWidth={4} />
                {:else}<Check size={8} strokeWidth={4} />{/if}
              {/if}
            </div>
          </div>
          <span class="tweak-name">{item.Action ? item.Action + ' ' : ''}{item.Label}</span>
          {#if hoveredFeatureId === item.FeatureId && hoveredDescription}
            <div class="tweak-tooltip">{hoveredDescription}</div>
          {/if}
        </div>
      {:else if item.itemType === 'group'}
        <div class="tweak-row group-row" style="--status-color: {getGroupStatusColor(item)}">
          <span class="tweak-name">{item.Action ? item.Action + ' ' : ''}{item.Label}</span>
          <div class="spacer"></div>
          <TweakSelect 
            options={item.Values}
            value={groupStagedChanges[item.GroupId] || getGroupAppliedValue(item)}
            appliedValue={getGroupAppliedValue(item)}
            label={getGroupAppliedLabel(item)}
            onchange={(v) => ontoggleGroup(item.GroupId, v)}
          />
        </div>
      {/if}
    {/each}
  </div>
</div>

<style>
  .category-card {
    background: #1a1f22;
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.7);
    overflow: visible;
  }
  .card-header { height: 26px; display: flex; align-items: center; padding: 0 14px; }
  .card-header h3 { font-size: 11px; font-weight: 800; color: #fff; letter-spacing: 0.18em; text-transform: uppercase; }
  .header-icon { margin-right: 12px; color: var(--accent-color); display: flex; }
  .card-body { padding: 4px 6px; display: flex; flex-direction: column; gap: 4px; overflow: visible; }
  .tweak-row { position: relative; display: flex; align-items: center; height: 24px; padding: 0 8px; padding-left: 10px; font-size: 11px; cursor: pointer; background: #242a2d; border: 1px solid rgba(255, 255, 255, 0.04); border-radius: 5px; box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2); }
  .tweak-row:hover { filter: brightness(1.2); z-index: 100; }
  .tweak-row::before { content: ''; position: absolute; left: 0; top: 4px; bottom: 4px; width: 4px; background: var(--status-color); box-shadow: 0 0 12px var(--status-color); border-radius: 0 2px 2px 0; }
  .group-row { cursor: default; justify-content: space-between; gap: 8px; z-index: 52; }
  .checkbox-container { width: 20px; display: flex; justify-content: center; margin-right: 6px; }
  .bloom-checkbox { width: 16px; height: 16px; background: rgba(0, 0, 0, 0.2); border: 1px solid rgba(255, 255, 255, 0.15); border-radius: 3px; display: flex; align-items: center; justify-content: center; }
  .bloom-checkbox.checked { background: #00bcd4 !important; border-color: #00bcd4 !important; color: #000; box-shadow: 0 0 8px rgba(0, 188, 212, 0.4); }
  .bloom-checkbox.reverting { background: #ff1744 !important; }
  .tweak-name { font-size: 11px; color: rgba(255, 255, 255, 0.7); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .tweak-tooltip { position: absolute; bottom: 100%; left: 24px; background: #1a1f21; border: 1px solid rgba(255, 255, 255, 0.1); padding: 8px 12px; border-radius: 4px; font-size: 10px; color: #fff; width: 240px; z-index: 5000; pointer-events: none; margin-bottom: 8px; }
  .spacer { flex: 1; }
</style>
