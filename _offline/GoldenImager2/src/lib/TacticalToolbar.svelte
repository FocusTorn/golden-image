<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { 
    ChevronDown, 
    Download, 
    Plus, 
    Save, 
    Search, 
    RefreshCw, 
    Trash2 
  } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";

  const dispatch = createEventDispatcher();

  // Props for Visibility
  export let showPolicy = true;
  export let showProfile = true;
  export let showSearch = true;
  export let showRefresh = true;
  export let showApply = true;

  // Labels & Data
  export let policyLabel = "Select Policy";
  export let profileLabel = "App-Profiles";
  export let searchPlaceholder = "Filter list...";
  export let applyLabel = "Apply Changes";

  // State (Binding recommended)
  export let policyOptions = [];
  export let selectedPolicy = "";
  export let profiles = [];
  export let selectedProfile = "";
  export let searchTerm = "";
  export let selectionCount = 0;
  export let loading = false;
  export let isApplied = false;

  // Calculation Widths (Replicated from Apps.svelte)
  export let policyCalcWidth = "140px";
  export let profileCalcWidth = "160px";

  // Dropdown States
  let isPolicyOpen = false;
  let isProfileOpen = false;

  function togglePolicy(e) {
    if (e && e.detail && e.detail.stopPropagation) e.detail.stopPropagation();
    isPolicyOpen = !isPolicyOpen;
    isProfileOpen = false;
  }

  function toggleProfile(e) {
    if (e && e.detail && e.detail.stopPropagation) e.detail.stopPropagation();
    isProfileOpen = !isProfileOpen;
    isPolicyOpen = false;
  }

  function selectPolicy(id) {
    selectedPolicy = id;
    isPolicyOpen = false;
    dispatch('policyChange', id);
  }

  function selectProfile(p) {
    selectedProfile = p;
    isProfileOpen = false;
    dispatch('profileChange', p);
  }

  function closeAll() {
    isPolicyOpen = false;
    isProfileOpen = false;
  }
</script>

<svelte:window on:click={closeAll} />

<div class="toolbar-reusable">
  <div class="tool-group">
    {#if showPolicy}
      <div class="custom-select-container">
        <BloomControl
          width={policyCalcWidth}
          active={isPolicyOpen}
          on:click={togglePolicy}
          style="padding: 0 8px; justify-content: flex-start !important; border-radius: 4px !important;"
        >
          <span class="select-label truncate">
            {policyOptions.find((o) => o.id === selectedPolicy)?.label || policyLabel}
          </span>
          <div class="chevron-wrapper" class:open={isPolicyOpen}>
            <ChevronDown size={14} />
          </div>
        </BloomControl>

        {#if isPolicyOpen}
          <div class="dropdown-list">
            {#each policyOptions as opt}
              <button
                class="dropdown-item"
                class:active={selectedPolicy === opt.id}
                on:click={() => selectPolicy(opt.id)}
                title={opt.description}
              >
                {opt.label}
              </button>
            {/each}
          </div>
        {/if}
      </div>
    {/if}

    {#if showProfile}
      <div class="segmented-control profile-group">
        <div class="custom-select-container">
          <BloomControl
            width={profileCalcWidth}
            active={isProfileOpen}
            on:click={toggleProfile}
            style="padding: 0 8px; border-radius: 4px 0 0 4px !important; position: relative; justify-content: flex-start !important;"
          >
            <span class="select-label truncate">
              {selectedProfile.replace(".json", "") || profileLabel}
            </span>
            <div class="chevron-wrapper" class:open={isProfileOpen}>
              <ChevronDown size={14} />
            </div>
          </BloomControl>

          {#if isProfileOpen}
            <div class="dropdown-list">
              <button
                class="dropdown-item"
                class:active={!selectedProfile}
                on:click={() => selectProfile("")}
              >
                Clear Selection
              </button>
              {#each profiles as p}
                <div class="dropdown-item-wrapper">
                  <button
                    class="dropdown-item"
                    class:active={selectedProfile === p}
                    on:click={() => selectProfile(p)}
                  >
                    <span class="truncate">{p.replace(".json", "")}</span>
                  </button>
                  <button
                    class="delete-profile-btn"
                    on:click={(e) => { e.stopPropagation(); dispatch('deleteProfile', p); }}
                    title="Delete Profile"
                  >
                    <Trash2 size={12} />
                  </button>
                </div>
              {/each}
            </div>
          {/if}
        </div>

        <BloomControl
          width="34px"
          on:click={() => dispatch('loadProfile')}
          style="border-radius: 0 !important; margin-left: -1px !important; flex-shrink: 0 !important;"
          title="Load Profile Selection"
        >
          <Download size={13} />
        </BloomControl>

        <BloomControl
          width="34px"
          on:click={() => dispatch('saveAsProfile')}
          style="border-radius: 0 !important; margin-left: -1px !important; flex-shrink: 0 !important;"
          title="Save As New Profile"
        >
          <Plus size={13} />
        </BloomControl>

        <BloomControl
          width="34px"
          on:click={() => dispatch('saveProfile')}
          style="border-radius: 0 4px 4px 0 !important; margin-left: -1px !important; flex-shrink: 0 !important;"
          title="Save Current Profile"
        >
          <Save size={13} />
        </BloomControl>
      </div>
    {/if}

    {#if showSearch || showRefresh}
      <div class="segmented-control utility-group">
        {#if showSearch}
          <div class="search-box">
            <BloomControl
              width="180px"
              class="locked-sunken"
              style="border-radius: {showRefresh ? '4px 0 0 4px' : '4px'} !important;"
            >
              <Search size={13} class="search-icon" />
              <input
                type="text"
                bind:value={searchTerm}
                placeholder={searchPlaceholder}
                class="bloom-input"
              />
            </BloomControl>
          </div>
        {/if}
        {#if showRefresh}
          <BloomControl
            width="34px"
            on:click={() => dispatch('refresh')}
            title="Refresh List"
            style="border-radius: {showSearch ? '0 4px 4px 0' : '4px'} !important; margin-left: {showSearch ? '-1px' : '0'} !important; flex-shrink: 0 !important;"
            class="refresh-btn"
          >
            <RefreshCw size={13} strokeWidth={2.5} class={loading ? "spin" : ""} />
          </BloomControl>
        {/if}
      </div>
    {/if}
  </div>

  {#if showApply}
    <div class="tool-group right">
      <button class="action-btn" class:active={selectionCount > 0} on:click={() => dispatch('apply')}>
        {applyLabel} ({selectionCount})
      </button>
    </div>
  {/if}
</div>

<style>
  .toolbar-reusable {
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

  .tool-group.right {
    margin-left: auto;
  }

  .custom-select-container {
    position: relative;
    display: flex;
    align-items: center;
  }

  .segmented-control {
    display: flex;
    align-items: center;
    position: relative;
    z-index: 50; /* Ensure pieces stack correctly */
  }

  .select-label {
    font-size: 11px;
    font-weight: 600;
    color: #fff;
    opacity: 0.9;
    letter-spacing: 0.3px;
  }

  .chevron-wrapper {
    margin-left: auto;
    opacity: 0.4;
    transition: transform 0.2s;
    display: flex;
    align-items: center;
  }

  .chevron-wrapper.open {
    transform: rotate(180deg);
  }

  .dropdown-list {
    position: absolute;
    top: calc(100% + 4px);
    left: 0;
    min-width: 100%;
    background: #1a1f21;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 4px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
    z-index: 5000;
    display: flex;
    flex-direction: column;
    padding: 4px;
    overflow: hidden;
  }

  .dropdown-item {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.6);
    padding: 6px 12px;
    text-align: left;
    font-size: 11px;
    border-radius: 2px;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.2s;
  }

  .dropdown-item.active {
    background: 
      linear-gradient(135deg, rgba(var(--accent-rgb), 0.12), rgba(var(--accent-rgb), 0.05)),
      linear-gradient(to right, #1A1C1D 0%, #222526 15%, #222526 85%, #1A1C1D 100%) !important;
    border: 1px solid rgba(var(--accent-rgb), 0.4) !important;
    box-shadow: 
      0 0 12px rgba(var(--accent-rgb), 0.1),
      inset 0 0 0 1px rgba(var(--accent-rgb), 0.05);
    color: #fff;
    text-shadow: 0 0 8px rgba(255, 255, 255, 0.3);
  }

  .dropdown-item:hover:not(.active) {
    background: rgba(255, 255, 255, 0.05);
    color: #fff;
  }

  .dropdown-item-wrapper {
    display: flex;
    align-items: center;
    gap: 2px;
  }

  .dropdown-item-wrapper .dropdown-item {
    flex: 1;
  }

  .delete-profile-btn {
    background: transparent;
    border: none;
    color: #ff3d60;
    opacity: 0.3;
    padding: 6px;
    cursor: pointer;
    transition: all 0.2s;
  }

  .delete-profile-btn:hover {
    opacity: 1;
    background: rgba(255, 61, 96, 0.15);
  }

  /* Search & Fused Stylings */
  .search-box {
    position: relative;
    display: flex;
    align-items: center;
  }

  :global(.search-icon) {
    position: absolute;
    left: 8px;
    opacity: 0.35;
    color: #fff;
    pointer-events: none;
  }

  .bloom-input {
    background: transparent;
    border: none;
    color: #fff;
    font-size: 11px;
    padding: 0 0 0 28px;
    width: 100%;
    outline: none;
  }

  .action-btn {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.35);
    font-size: 11px;
    font-weight: 700;
    padding: 0 16px;
    height: 28px;
    border-radius: 4px;
    cursor: default;
    transition: all 0.25s;
  }

  .action-btn.active {
    background: rgba(var(--accent-rgb), 0.15) !important;
    color: var(--accent-color);
    border: 1px solid rgba(var(--accent-rgb), 0.6) !important;
    cursor: pointer;
  }

  .action-btn.active:hover {
    filter: brightness(1.15);
  }

  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    display: block;
  }

  .spin {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  :global(.locked-sunken) {
    padding: 0 !important;
  }
</style>
