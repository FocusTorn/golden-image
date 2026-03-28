<script lang="ts">
  import { onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/tauri";
  import {
    LayoutDashboard,
    Drill,
    Package,
    Settings,
    Search,
    Save,
    Filter,
    ChevronDown,
    Check,
    Download,
    Upload,
    Trash2,
    RefreshCw,
  } from "lucide-svelte";

  const isTauri = (window as any).__TAURI_METADATA__ !== undefined;

  export let appCount = 0;
  let apps: any[] = [];
  let loading = true;
  let error: string | null = null;
  let searchTerm = "";
  let selectedProfile = "";
  let profiles: string[] = [];
  let selectedApps = new Set<string>();
  let showConfirm = false;
  let viewFilter = "curated";

  const FILTER_OPTIONS = [
    { id: "curated", label: "Curated Policy" },
    { id: "installed", label: "Installed Apps" },
    { id: "system", label: "System (Provisioned)" },
    { id: "user", label: "User (Appx/Reg)" },
    { id: "all", label: "All Applications" },
  ];

  $: appCount = filteredApps ? filteredApps.length : 0;

  async function loadData() {
    loading = true;
    error = null;
    try {
      if (isTauri) {
        apps = await invoke("get_apps");
        profiles = await invoke("list_app_profiles");
        if (profiles.length > 0 && !selectedProfile) {
          selectedProfile = profiles[0];
        }
      }
    } catch (e) {
      error = typeof e === "string" ? e : JSON.stringify(e);
    } finally {
      loading = false;
    }
  }

  async function loadProfile() {
    if (!selectedProfile || !isTauri) return;
    try {
      const profileAppIds: string[] = await invoke("load_app_profile", {
        name: selectedProfile,
      });
      selectedApps = new Set(profileAppIds);
    } catch (e) {
      console.error("Failed to load profile:", e);
    }
  }

  async function saveProfile() {
    if (!selectedProfile || !isTauri) {
      const name = prompt("Enter profile name:");
      if (!name) return;
      selectedProfile = name.endsWith(".json") ? name : `${name}.json`;
    }
    try {
      await invoke("save_app_profile", {
        name: selectedProfile,
        appIds: Array.from(selectedApps),
      });
      profiles = await invoke("list_app_profiles");
    } catch (e) {
      console.error("Failed to save profile:", e);
    }
  }

  onMount(loadData);

  $: filteredApps = apps.filter((app) => {
    const search = searchTerm.toLowerCase();
    const matchesSearch =
      app.FriendlyName?.toLowerCase().includes(search) ||
      app.AppId?.toLowerCase().includes(search);

    let matchesFilter = false;
    switch (viewFilter) {
      case "curated":
        matchesFilter = app.IsCurated;
        break;
      case "installed":
        matchesFilter = app.IsInstalled;
        break;
      case "system":
        matchesFilter = app.IsProvisioned;
        break;
      case "user":
        matchesFilter = app.IsUser;
        break;
      case "all":
        matchesFilter = true;
        break;
    }

    return matchesSearch && matchesFilter;
  });

  const getStatusColor = (rec: string) => {
    switch (rec) {
      case "safe":
        return "var(--risk-safe)";
      case "unsafe":
        return "var(--risk-unsafe)";
      default:
        return "var(--risk-warn)";
    }
  };

  const getRowHue = (rec: string) => {
    switch (rec) {
      case "safe":
        return "rgba(63, 185, 80, 0.1)";
      case "unsafe":
        return "rgba(248, 81, 73, 0.15)";
      default:
        return "rgba(210, 153, 34, 0.1)";
    }
  };

  const toggleSelect = (id: string, event?: any) => {
    if (event) event.stopPropagation();
    if (selectedApps.has(id)) selectedApps.delete(id);
    else selectedApps.add(id);
    selectedApps = new Set(selectedApps);
  };

  function handleToggleAll(e: Event) {
    const target = e.currentTarget as HTMLInputElement;
    if (target.checked) {
      filteredApps.forEach((a) => selectedApps.add(a.AppId));
    } else {
      filteredApps.forEach((a) => selectedApps.delete(a.AppId));
    }
    selectedApps = new Set(selectedApps);
  }

  // Dynamic Column Width Calculation (Full Dataset)
  $: maxNameLen = apps.reduce((max, app) => Math.max(max, (app.FriendlyName || "").length), 20);
  $: maxIdLen = apps.reduce((max, app) => Math.max(max, (app.AppId || "").length), 30);
  
  // Weights: FriendlyName uses ~6.2px/char, AppId (mono) uses ~6.5px/char
  $: nameWidth = Math.min(480, Math.max(140, maxNameLen * 6.2));
  $: idWidth = Math.min(600, Math.max(180, maxIdLen * 6.5));
</script>

<div class="panel">
  <div class="toolbar">
    <div class="tool-group">
      <select bind:value={viewFilter} class="compact-select main-filter">
        {#each FILTER_OPTIONS as opt}
          <option value={opt.id}>{opt.label}</option>
        {/each}
      </select>

      <div class="profile-bar">
        <Package size={12} class="icon-muted" />
        <select
          bind:value={selectedProfile}
          class="compact-select profile-dropdown"
        >
          {#if profiles.length === 0}
            <option value="">No Profiles Found</option>
          {/if}
          {#each profiles as profile}
            <option value={profile}>{profile.replace(".json", "")}</option>
          {/each}
        </select>
        <button class="tool-btn" title="Load Profile" on:click={loadProfile}>
          <Download size={14} />
        </button>
        <button class="tool-btn" title="Save Selection" on:click={saveProfile}>
          <Save size={14} />
        </button>
      </div>

      <div class="search-box">
        <Search size={12} class="search-icon" />
        <input
          type="text"
          bind:value={searchTerm}
          placeholder="Filter apps..."
          class="compact-input"
        />
      </div>
    </div>

    <div class="tool-group right">
      <button
        class="tool-btn refresh"
        on:click={loadData}
        title="Refresh System List"
      >
        <RefreshCw size={14} />
      </button>
      <button class="action-btn" class:active={selectedApps.size > 0}>
        Apply Changes ({selectedApps.size})
      </button>
    </div>
  </div>

  <div class="table-header" style="--col-name-w: {nameWidth}px; --col-id-w: {idWidth}px;">
    <div class="col-check">
      <input
        type="checkbox"
        checked={filteredApps.length > 0 &&
          Array.from(selectedApps).every((id) =>
            filteredApps.some((a) => a.AppId === id),
          )}
        on:change={handleToggleAll}
      />
    </div>
    <div class="col-status"></div>
    <div class="col-name">Friendly Name</div>
    <div class="col-appid">System Identifier / Package Name</div>
  </div>

  <div class="table-container" style="--col-name-w: {nameWidth}px; --col-id-w: {idWidth}px;">
    <div class="table-body">
      {#if loading}
        <div class="state-msg">Scanning system...</div>
      {:else if error}
        <div class="state-msg error">{error}</div>
      {:else}
        {#each filteredApps as app}
          <div
            class="row"
            style="--row-hue: {getRowHue(app.Recommendation)}"
            class:selected={selectedApps.has(app.AppId)}
            on:click={() => toggleSelect(app.AppId)}
            on:keydown={(e) =>
              (e.key === "Enter" || e.key === " ") && toggleSelect(app.AppId)}
            role="row"
            tabindex="0"
            title={app.Description || "No description available"}
          >
            <div class="col-check">
              <input
                type="checkbox"
                checked={selectedApps.has(app.AppId)}
                on:click|stopPropagation
              />
            </div>
            <div class="col-status">
              <div
                class="dot"
                style="background: {getStatusColor(app.Recommendation)}; color: {getStatusColor(app.Recommendation)}"
              ></div>
            </div>
            <div class="col-name">
              <span class="text-main">{app.FriendlyName}</span>
            </div>
            <div class="col-appid">
              <span class="text-mono">{app.AppId}</span>
            </div>
          </div>
        {/each}
      {/if}
    </div>
  </div>
</div>

<style>
  .panel {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: transparent;
    padding: 12px;
    box-sizing: border-box;
    overflow: hidden;
  }

  .toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: 4px;
    gap: 12px;
  }

  .tool-group {
    display: flex;
    align-items: center;
    gap: 8px;
  }


  .compact-select {
    background: #1c2427;
    border: 1px solid var(--border-muted);
    color: var(--text-main);
    font-size: 11px;
    padding: 2px 24px 2px 8px; /* Room for custom arrow */
    border-radius: 4px;
    height: 24px;
    outline: none;
    cursor: pointer;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='white' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'%3E%3C/polyline%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 6px center;
    transition: all 0.2s;
  }

  .compact-select:hover {
    background-color: #232d30;
    border-color: rgba(var(--accent-rgb), 0.3);
  }

  .main-filter {
    font-weight: 600;
    min-width: 120px;
  }

  .profile-bar {
    display: flex;
    align-items: center;
    gap: 4px;
    background: rgba(255, 255, 255, 0.03);
    padding: 1px 4px;
    border-radius: 4px;
    border: 1px solid rgba(255, 255, 255, 0.05);
  }

  .profile-dropdown {
    border: none;
    background: transparent;
    min-width: 100px;
  }

  .search-box {
    position: relative;
    display: flex;
    align-items: center;
  }

  :global(.search-icon) {
    position: absolute;
    left: 8px;
    opacity: 0.3;
    pointer-events: none;
  }

  .compact-input {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.08);
    color: #fff;
    font-size: 11px;
    padding: 2px 8px 2px 26px;
    border-radius: 4px;
    height: 24px;
    width: 160px;
    outline: none;
  }

  .tool-btn {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.6);
    cursor: pointer;
    padding: 4px;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s;
  }

  .tool-btn:hover {
    background: rgba(255, 255, 255, 0.1);
    color: #fff;
  }

  .action-btn {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.3);
    font-size: 11px;
    font-weight: 700;
    padding: 0 16px;
    height: 26px;
    border-radius: 4px;
    cursor: default;
  }

  .action-btn.active {
    background: var(--accent-color);
    color: #fff;
    border: none;
    cursor: pointer;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
  }

  .panel {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding: 12px 12px 0 12px;
    gap: 4px; /* Tighter gap */
    overflow: hidden;
    background: transparent;
  }

  .table-container {
    flex: 1;
    display: flex;
    flex-direction: column;
    background: rgba(0, 0, 0, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 12px 12px 0 0;
    overflow: hidden;
    position: relative;
    padding: 0 6px; /* First half of gutter */
    box-shadow:
      inset 0 0 0 1px #12181a,
      inset 0 2px 10px rgba(0, 0, 0, 0.3);
  }

  .table-container::before,
  .table-container::after {
    content: "";
    position: absolute;
    left: 0;
    right: 0;
    height: 32px;
    z-index: 10;
    pointer-events: none;
  }

  .table-container::before {
    top: 0;
    background: linear-gradient(
      to bottom,
      rgba(0, 0, 0, 0.48) 0%,
      rgba(var(--bg-main-rgb), 0) 100%
    );
    height: 32px;
    z-index: 15;
  }

  .table-container::after {
    bottom: 0;
    background: linear-gradient(
      to top,
      rgba(0, 0, 0, 0.48) 0%,
      rgba(var(--bg-main-rgb), 0) 100%
    );
    height: 32px;
    right: 0;
  }

  .table-header {
    display: flex;
    align-items: flex-end;
    padding: 0 24px 4px 24px; /* Align with Row columns + lowered text */
    height: 32px;
    font-size: 10px;
    font-weight: 800;
    color: #fff;
    opacity: 0.8;
    background: linear-gradient(to right, #fff, #94a3b8);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    flex-shrink: 0;
    z-index: 20;
    position: relative;
  }


  .table-body {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
    padding: 10px 6px; /* Second half of gutter - centers scrollbar */
    display: flex;
    flex-direction: column;
    scrollbar-gutter: stable;
  }

  .row {
    display: flex;
    align-items: center;
    height: 28px;
    margin: 3px 0;
    padding: 0 12px;
    font-size: 11px;
    cursor: pointer;
    background: var(--bg-card);
    border: 1px solid rgba(255, 255, 255, 0.03);
    border-radius: 4px;
    transition: all 0.1s cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
    overflow: hidden;
    flex-shrink: 0;
    color: var(--text-main);
  }

  .row:hover {
    background: var(--bg-card-hover);
    border-color: rgba(var(--accent-rgb), 0.3);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
  }

  .row.selected {
    background: rgba(var(--accent-rgb), 0.12);
    border-color: rgba(var(--accent-rgb), 0.4);
  }

  .col-check {
    width: 36px;
    display: flex;
    justify-content: center;
  }
  .col-status {
    width: 36px;
    display: flex;
    justify-content: center;
  }
  .col-name {
    width: var(--col-name-w, 360px);
    padding-right: 16px;
    box-sizing: border-box;
  }
  .col-appid {
    width: var(--col-id-w, 400px);
    flex: 1;
    padding-right: 16px;
    box-sizing: border-box;
  }

  .dot {
    width: 9px;
    height: 9px;
    border-radius: 50%;
    box-shadow: 0 0 6px currentColor;
    filter: saturate(1.8) brightness(1.2);
    opacity: 0.95;
  }

  .text-main {
    color: #e2e8f0;
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    display: block;
    opacity: 0.85;
    background: linear-gradient(to right, #e2e8f0, #adb9c5);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
  }

  .text-mono {
    font-family: "Consolas", "Monaco", monospace;
    font-size: 10px;
    color: #94a3b8;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    display: block;
    opacity: 0.7;
    background: linear-gradient(to right, #cbd5e1, #94a3b8);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
  }

  .state-msg {
    padding: 40px;
    text-align: center;
    color: rgba(255, 255, 255, 0.3);
    font-size: 11px;
  }

  .state-msg.error {
    color: #f44336;
  }

  input[type="checkbox"] {
    width: 12px;
    height: 12px;
    cursor: pointer;
    accent-color: var(--accent-color);
  }

  :global(.icon-muted) {
    opacity: 0.25;
    filter: grayscale(1);
  }

  /* Scrollbar */
  .table-body::-webkit-scrollbar {
    width: 6px;
  }
  .table-body::-webkit-scrollbar-track {
    background: transparent;
  }
  .table-body::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.1);
    border-radius: 3px;
  }
  .table-body::-webkit-scrollbar-thumb:hover {
    background: rgba(255, 255, 255, 0.2);
  }
</style>
