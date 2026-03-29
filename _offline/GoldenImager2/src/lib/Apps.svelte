<script lang="ts">
  import { onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/tauri";
  import {
    LayoutDashboard,
    Cog,
    LayoutList,
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
    X,
    Zap,
  } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";

  const isTauri = (window as any).__TAURI_METADATA__ !== undefined;

  export let appCount = 0;
  let apps: any[] = [];
  let loading = true;
  let error: string | null = null;
  let searchTerm = "";
  let selectedProfile = "";
  let profiles: string[] = [];
  let isApplied = false;
  let selectedApps = new Set<string>();
  let showConfirm = false;
  let viewFilter = "all";

  let showSaveModal = false;
  let saveName = "";

  const FILTER_OPTIONS = [
    {
      id: "all",
      label: "All Applications",
      description:
        "Complete system inventory including provisioned system packages and manually installed user apps.",
    },
    {
      id: "curated",
      label: "Curated Policy",
      description:
        "High-fidelity audit list based on standard Sysprep best practices and security hardening.",
    },
    {
      id: "installed",
      label: "Installed Apps",
      description:
        "Standard desktop applications and third-party software currently registered with the system.",
    },
    {
      id: "system",
      label: "System (Provisioned)",
      description:
        "Core Windows system packages pre-staged for deployment but not yet fully instantiated for users.",
    },
    {
      id: "user",
      label: "User (Appx/Reg)",
      description:
        "Applications specifically registered to the current user profile or installed via Appx.",
    },
    {
      id: "unmapped",
      label: "New / Unmapped",
      description:
        "Discovered system applications that are not currently accounted for in the curated Apps.json policy.",
    },
  ];

  const RISK_OPTIONS = [
    { id: "safe", color: "var(--risk-safe)", label: "Safe / Cleanup" },
    { id: "warn", color: "var(--risk-warn)", label: "Warning / Risky" },
    { id: "unsafe", color: "var(--risk-unsafe)", label: "Unsafe / Remove" },
    { id: "user", color: "var(--risk-user)", label: "User Tools" },
    { id: "unmapped", color: "var(--risk-unknown)", label: "Unmapped / New" },
  ];

  let isPolicyOpen = false;
  let isRiskOpen = false;
  let isProfileOpen = false;

  function closeAll() {
    isPolicyOpen = false;
    isRiskOpen = false;
    isProfileOpen = false;
  }

  function togglePolicy(e?: any) {
    if (e && e.stopPropagation) e.stopPropagation();
    isPolicyOpen = !isPolicyOpen;
    isProfileOpen = false;
    isRiskOpen = false;
  }

  function toggleProfile(e?: any) {
    if (e && e.stopPropagation) e.stopPropagation();
    isProfileOpen = !isProfileOpen;
    isPolicyOpen = false;
    isRiskOpen = false;
  }

  let selectedRisks = new Set(["safe", "warn", "unsafe", "user", "unmapped"]);

  function selectPolicy(id: string) {
    viewFilter = id;
    isPolicyOpen = false;
  }
  function selectProfile(p: string) {
    selectedProfile = p;
    isProfileOpen = false;
    loadProfile();
  }

  $: appCount = filteredApps ? filteredApps.length : 0;

  async function loadData() {
    loading = true;
    error = null;
    try {
      if (isTauri) {
        apps = await invoke("get_apps");
        profiles = await invoke("list_app_profiles");
      }
    } catch (e) {
      error = typeof e === "string" ? e : JSON.stringify(e);
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    loadData();
  });

  async function loadProfile() {
    if (!selectedProfile || !isTauri) return;
    try {
      const profileAppIds: string[] = await invoke("load_app_profile", {
        name: selectedProfile,
      });

      const newSelection = new Set<string>();
      const systemApps = [...apps];

      profileAppIds.forEach((pId) => {
        const pIdLower = pId.toLowerCase();

        const match = systemApps.find(
          (a) =>
            a.AppId.toLowerCase() === pIdLower ||
            a.AppId.toLowerCase().startsWith(pIdLower + "_") ||
            a.AppId.toLowerCase().includes("." + pIdLower + "_"),
        );

        if (match) {
          newSelection.add(match.AppId);
        } else {
          const nameMatch = systemApps.find(
            (a) => a.FriendlyName.toLowerCase() === pIdLower,
          );
          if (nameMatch) newSelection.add(nameMatch.AppId);
        }
      });

      selectedApps = newSelection;
      isApplied = true;
    } catch (e) {
      console.error("[Apps] Load Conflict:", e);
      alert(`Sync Error: ${e}`);
    }
  }

  async function saveProfile() {
    if (!selectedProfile || !isTauri) {
      showSaveModal = true;
      saveName = selectedProfile.replace(".json", "") || "";
      return;
    }
    await executeSave(selectedProfile);
  }

  async function executeSave(name: string) {
    if (!name || !isTauri) return;
    const finalName = name.endsWith(".json") ? name : `${name}.json`;
    try {
      await invoke("save_app_profile", {
        name: finalName,
        appIds: Array.from(selectedApps),
      });
      selectedProfile = finalName;
      profiles = await invoke("list_app_profiles");
      showSaveModal = false;
    } catch (e) {
      console.error("Failed to save profile:", e);
    }
  }

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
      case "unmapped":
        matchesFilter = !app.IsCurated;
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

  $: filteredByRisk = filteredApps.filter((app) => {
    if (selectedRisks.size === 0) return true;
    const isUser = app.IsUser || app.Recommendation === "user";
    if (isUser && selectedRisks.has("user")) return true;

    if (app.IsCurated) {
      return selectedRisks.has(app.Recommendation);
    } else {
      return selectedRisks.has("unmapped");
    }
  });

  function toggleRisk(id: string) {
    if (selectedRisks.has(id)) {
      selectedRisks.delete(id);
    } else {
      selectedRisks.add(id);
    }
    selectedRisks = selectedRisks;
  }

  function getSelectedRisksList(selected: Set<string>) {
    return RISK_OPTIONS.filter((o) => selected.has(o.id));
  }

  function getExplodeOffset(i: number, count: number) {
    if (count <= 1) return { x: 0, y: 0 };
    // 0deg is TOP. Bisector is in the middle of segment.
    const angle = (i + 0.5) * (360 / count);
    const rad = (angle * Math.PI) / 180;
    const dist = 1.0; // 1px explosion
    return {
      x: Math.sin(rad) * dist,
      y: -Math.cos(rad) * dist,
    };
  }

  function getSegmentPath(i: number, count: number) {
    const r = 7;
    const startAngle = (i * (360 / count) - 90) * (Math.PI / 180);
    const endAngle = ((i + 1) * (360 / count) - 90) * (Math.PI / 180);

    const x1 = r + r * Math.cos(startAngle);
    const y1 = r + r * Math.sin(startAngle);
    const x2 = r + r * Math.cos(endAngle);
    const y2 = r + r * Math.sin(endAngle);

    const largeArc = 0; // Each piece is < 180
    return `M 7 7 L ${x1} ${y1} A ${r} ${r} 0 ${largeArc} 1 ${x2} ${y2} Z`;
  }

  const getStatusColor = (app: any) => {
    if (app.IsUser || app.Recommendation === "user") {
      return "var(--risk-user)";
    }

    switch (app.Recommendation) {
      case "safe":
        return "var(--risk-safe)";
      case "warn":
        return "var(--risk-warn)";
      case "unsafe":
        return "var(--risk-unsafe)";
      default:
        return "var(--risk-unknown)";
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
    isApplied = false;
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

  $: maxNameLen = apps.reduce(
    (max, app) => Math.max(max, (app.FriendlyName || "").length),
    20,
  );
  $: maxIdLen = apps.reduce(
    (max, app) => Math.max(max, (app.AppId || "").length),
    30,
  );

  $: nameWidth = (maxNameLen + 2) * 5.4;
  $: idWidth = (maxIdLen + 4) * 7.2;

  function closeModals() {
    showSaveModal = false;
    isPolicyOpen = false;
    isProfileOpen = false;
    isRiskOpen = false;
  }
</script>

{#if showSaveModal}
  <div
    class="modal-overlay"
    on:click={closeModals}
    on:keydown={(e) => e.key === "Escape" && closeModals()}
    role="button"
    tabindex="0"
    aria-label="Close modal"
  >
    <div
      class="modal-content"
      on:click|stopPropagation
      role="dialog"
      aria-modal="true"
    >
      <div class="modal-header">
        <h3>Save Profile</h3>
        <button class="close-lite" on:click={() => (showSaveModal = false)}
          ><X size={16} /></button
        >
      </div>
      <div class="modal-body">
        <p>Enter a unique name to store the current selection.</p>
        <input
          type="text"
          bind:value={saveName}
          placeholder="e.g. Minimalist-Build"
          class="modal-input"
          on:keydown={(e) => e.key === "Enter" && executeSave(saveName)}
          autofocus
        />
      </div>
      <div class="modal-footer">
        <button
          class="modal-btn cancel"
          on:click={() => (showSaveModal = false)}>Cancel</button
        >
        <button
          class="modal-btn confirm"
          class:active={saveName.length > 0}
          on:click={() => executeSave(saveName)}
        >
          Save Profile
        </button>
      </div>
    </div>
  </div>
{/if}

<svelte:window on:click={closeAll} />

<div class="panel">
  <div class="toolbar">
    <div class="tool-group">
      <div
        class="custom-select-container"
        on:click|stopPropagation={() => {}}
        on:keydown={() => {}}
        role="button"
        tabindex="-1"
      >
        <BloomControl
          width="140px"
          active={isPolicyOpen}
          on:click={togglePolicy}
          style="padding: 0 8px;"
        >
          <span class="select-label truncate"
            >{FILTER_OPTIONS.find((o) => o.id === viewFilter)?.label ||
              "Select Policy"}</span
          >
          <div class="chevron-wrapper" class:open={isPolicyOpen}>
            <ChevronDown size={14} />
          </div>
        </BloomControl>

        {#if isPolicyOpen}
          <div class="dropdown-list">
            {#each FILTER_OPTIONS as opt}
              <button
                class="dropdown-item"
                class:active={viewFilter === opt.id}
                on:click={() => selectPolicy(opt.id)}
                title={opt.description}
              >
                {opt.label}
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <div class="segmented-control profile-group">
        <div
          class="custom-select-container"
          on:click|stopPropagation={() => {}}
          on:keydown={() => {}}
          role="button"
          tabindex="-1"
        >
          <BloomControl
            width="140px"
            active={isProfileOpen}
            on:click={toggleProfile}
            style="padding: 0 8px; border-radius: 4px 0 0 4px !important; position: relative;"
          >
            <span class="select-label truncate"
              >{selectedProfile.replace(".json", "") || "App-Profiles"}</span
            >
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
                <button
                  class="dropdown-item"
                  class:active={selectedProfile === p}
                  on:click={() => selectProfile(p)}
                >
                  {p}
                </button>
              {/each}
            </div>
          {/if}
        </div>

        <BloomControl
          width="34px"
          on:click={loadProfile}
          style="border-radius: 0 !important; margin-left: -1px !important; flex-shrink: 0 !important;"
        >
          <Download size={13} />
        </BloomControl>

        <BloomControl
          width="34px"
          on:click={saveProfile}
          style="border-radius: 0 4px 4px 0 !important; margin-left: -1px !important; flex-shrink: 0 !important;"
        >
          <Save size={13} />
        </BloomControl>
      </div>

      <div class="segmented-control search-group">
        <div class="search-box">
          <BloomControl
            width="180px"
            class="locked-sunken"
            style="border-radius: 4px 0 0 4px !important;"
          >
            <Search size={13} class="search-icon" />
            <input
              type="text"
              bind:value={searchTerm}
              placeholder="Filter apps..."
              class="bloom-input"
            />
          </BloomControl>
        </div>
        <BloomControl
          width="34px"
          on:click={loadData}
          title="Refresh System List"
          style="border-radius: 0 4px 4px 0 !important; margin-left: -1px !important; flex-shrink: 0 !important;"
          class="refresh-btn"
        >
          <RefreshCw size={13} strokeWidth={2.5} />
        </BloomControl>
      </div>
    </div>

    <div class="tool-group right">
      <button class="action-btn" class:active={selectedApps.size > 0}>
        Apply Changes ({selectedApps.size})
      </button>
    </div>
  </div>

  <div
    class="table-header"
    style="--col-name-w: {nameWidth}px; --col-id-w: {idWidth}px;"
  >
    <div class="col-check">
      <input
        type="checkbox"
        checked={filteredApps.length > 0 &&
          filteredApps.every((a) => selectedApps.has(a.AppId))}
        on:change={handleToggleAll}
      />
    </div>
    <div class="col-status">
      <div class="risk-filter-container">
        <button
          class="risk-header-btn"
          on:click|stopPropagation={() => (isRiskOpen = !isRiskOpen)}
        >
          <div
            class="dot header-pie"
            class:is-off={selectedRisks.size === 0 ||
              (selectedRisks.has("unmapped") && selectedRisks.size === 1)}
          >
            {#if selectedRisks.size > 0}
              {@const selectedList = getSelectedRisksList(selectedRisks)}
              <svg viewBox="-2 -2 18 18" class="pie-overlay">
                <!-- Exploded Spectral Glow Group -->
                <g class="pie-glow-group">
                  {#each selectedList as opt, i}
                    {@const offset = getExplodeOffset(i, selectedList.length)}
                    <path 
                      d={getSegmentPath(i, selectedList.length)}
                      fill={opt.color}
                      transform="translate({offset.x}, {offset.y})"
                    />
                  {/each}
                </g>

                <!-- Exploded Physical Pieces -->
                <g class="pie-pieces-group">
                  {#each selectedList as opt, i}
                    {@const offset = getExplodeOffset(i, selectedList.length)}
                    <path 
                      d={getSegmentPath(i, selectedList.length)}
                      fill={opt.color}
                      transform="translate({offset.x}, {offset.y})"
                      stroke="#0b0f10"
                      stroke-width="1.2"
                    />
                  {/each}
                </g>
              </svg>
            {/if}
          </div>
        </button>

        {#if isRiskOpen}
          <div class="dropdown-list risk-dropdown">
            {#each RISK_OPTIONS as opt}
              <button
                class="dropdown-item risk-item"
                on:click|stopPropagation={() => toggleRisk(opt.id)}
              >
                <div class="risk-check-row">
                  <div class="risk-active-mark-container">
                    {#if selectedRisks.has(opt.id)}
                      <div class="risk-active-mark"></div>
                    {/if}
                  </div>
                  <span class="risk-label">{opt.label}</span>
                  <div
                    class="dot mini-dot"
                    style="background: {opt.color}; box-shadow: 0 0 4px {opt.color};"
                  ></div>
                </div>
              </button>
            {/each}
          </div>
        {/if}
      </div>
    </div>
    <div class="col-name">Friendly Name</div>
    <div class="col-appid">System Identifier / Package Name</div>
  </div>

  <div
    class="table-container"
    style="--col-name-w: {nameWidth}px; --col-id-w: {idWidth}px;"
  >
    <div class="table-body">
      {#if loading}
        <div class="state-msg">Scanning system...</div>
      {:else if error}
        <div class="state-msg error">{error}</div>
      {:else}
        {#each filteredByRisk as app}
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
                class:is-off={!app.IsUser &&
                  !["safe", "warn", "unsafe"].includes(app.Recommendation)}
                style="--dot-color: {getStatusColor(app)}"
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
  :root {
    --risk-safe: #00e676;
    --risk-warn: #ffd600;
    --risk-unsafe: #ff3d60; /* Bright Neon Red */
    --risk-user: #9900ff; /* Bright Electric Purple */
    --risk-unknown: #1a1f21; /* 'Off' state industrial grey */
  }

  .panel {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding: 12px 12px 0 24px;
    gap: 4px; /* Tighter gap */
    overflow: hidden;
    background: transparent;
  }

  .toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: 4px;
    gap: 12px;
    position: relative;
    z-index: 2000; /* Master priority above table assets */
  }

  .tool-group {
    display: flex;
    align-items: center;
    gap: 6px; /* Uniform spacing for all industrial slots */
  }

  .custom-select-container {
    position: relative;
    display: flex;
    align-items: center;
  }

  .toolbar :global(svg) {
    color: #fff;
    opacity: 0.35; /* Master Sidebar resting weight */
    filter: drop-shadow(
      0 1px 2px rgba(0, 0, 0, 0.5)
    ); /* Professional lift - Synced with Search Magnifier */
    transition: all 0.25s ease;
  }

  .toolbar :global(.bloom-control:hover:not(.locked-sunken) svg),
  .toolbar :global(.bloom-control.active:not(.locked-sunken) svg) {
    opacity: 1; /* Brightens to full intensity on hover/active like Sidebar */
    filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.3))
      drop-shadow(0 0 8px rgba(255, 255, 255, 0.4));
  }

  .search-box {
    position: relative;
    display: flex;
    align-items: center;
  }

  :global(.search-icon) {
    position: absolute;
    left: 8px; /* Industrial tight anchor: 8px gap */
    opacity: 0.75; /* Synced to new industrial baseline */
    color: #fff;
    pointer-events: none;
    filter: drop-shadow(
      0 1px 2px rgba(0, 0, 0, 0.5)
    ); /* Professional lift shadow */
  }

  .bloom-input {
    background: transparent;
    border: none;
    color: #fff;
    font-size: 11px;
    padding: 0 0 0 28px; /* Standard 8px gap after 12px icon */
    width: 100%;
    outline: none;
  }

  .bloom-input:focus::placeholder {
    color: transparent;
  }

  :global(.locked-sunken) {
    padding: 0 !important; /* Force reset of component padding to ensure symmetry */
  }

  .chevron-wrapper {
    display: flex;
    align-items: center;
    justify-content: center;
    transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .segmented-control {
    display: flex;
    align-items: center;
    position: relative;
    z-index: 20;
    gap: 0; /* Forced industrial seal */
  }

  .profile-group {
    margin-right: 4px; /* Space before search box */
  }

  .action-btn {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.35); /* Matched to Sidebar resting weight */
    font-size: 11px;
    font-weight: 700;
    padding: 0 16px;
    height: 28px; /* Matched to Bloom inputs */
    border-radius: 4px;
    cursor: default;
    display: flex;
    align-items: center;
    gap: 8px;
    transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .action-btn.active {
    background: rgba(
      var(--accent-rgb),
      0.15
    ) !important; /* Industrial Sunken Teal */
    color: var(--accent-color); /* Vibrant Teal Text */
    border: 1px solid rgba(var(--accent-rgb), 0.6) !important;
    cursor: pointer;
    box-shadow: none; /* REMOVED GLOW PER USER REQ */
    text-shadow: none; /* REMOVED GLOW PER USER REQ */
  }

  .action-btn.active:hover {
    filter: brightness(1.15);
    box-shadow:
      0 0 15px rgba(var(--accent-rgb), 0.2),
      0 0 4px rgba(var(--accent-rgb), 0.4);
    border-color: rgba(
      var(--accent-rgb),
      0.8
    ) !important; /* Brighter on hover */
  }

  :global(.refresh-btn svg) {
    opacity: 0.35 !important;
  }

  :global(.refresh-btn:hover svg) {
    opacity: 1 !important;
  }

  :global(.refresh-btn:active svg) {
    transform: rotate(180deg);
  }

  .table-container {
    flex: 1;
    display: flex;
    flex-direction: column;
    background: rgba(0, 0, 0, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-bottom: none; /* Flush with industrial floor */
    border-radius: 12px 12px 0 0;
    overflow: hidden;
    position: relative;
    padding: 0 6px; /* First half of gutter */
    z-index: 1; /* Lowest industrial stack */
    box-shadow:
      inset 0 0 0 1px #12181a,
      inset 0 24px 24px -12px rgba(0, 0, 0, 0.48); /* Only top industrial shadow */
  }

  .table-container::before {
    top: 0;
    content: "";
    position: absolute;
    left: 0;
    right: 0;
    background: linear-gradient(
      to bottom,
      rgba(0, 0, 0, 0.48) 0%,
      rgba(var(--bg-main-rgb), 0) 100%
    );
    height: 32px;
    z-index: 15;
    pointer-events: none;
  }

  .table-container::after {
    bottom: 0;
    content: "";
    position: absolute;
    left: 0;
    right: 0;
    background: linear-gradient(
      to top,
      rgba(0, 0, 0, 0.4) 0%,
      rgba(0, 0, 0, 0) 100%
    );
    height: 16px; /* Tighter fade to ensure pixel parity at bottom */
    z-index: 15;
    pointer-events: none;
  }

  .table-header {
    display: flex;
    align-items: center; /* Centered with row content */
    padding: 0 12px 0 24px; /* Offset by 12px (6+6) to match container and body gutters */
    height: 32px;
    font-size: 10px;
    font-weight: 800;
    color: #fff;
    background: linear-gradient(to right, #fff, #94a3b8);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    flex-shrink: 0;
    z-index: 1000; /* Lifts entire header above body/rows */
    position: relative;
  }

  .table-body {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
    padding: 0 6px 0 6px; /* Removed bottom padding for list-to-divider parity */
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
    background: rgba(255, 255, 255, 0.08) !important; /* Bloom Hover Base */
    border-color: rgba(
      var(--accent-rgb),
      0.6
    ) !important; /* Standard Bloom Reveal */
    box-shadow:
      0 0 15px rgba(var(--accent-rgb), 0.2),
      0 0 4px rgba(var(--accent-rgb), 0.4);
    z-index: 50;
    filter: brightness(1.15);
  }

  .row:hover .text-main,
  .row:hover .text-mono {
    background: none !important;
    -webkit-background-clip: initial !important;
    background-clip: initial !important;
    -webkit-text-fill-color: #fff !important;
    color: #fff !important;
    opacity: 1 !important;
    text-shadow: 0 0 8px rgba(255, 255, 255, 0.3);
  }

  .row.selected {
    background: rgba(var(--accent-rgb), 0.12);
    border-color: rgba(
      var(--accent-rgb),
      0.85
    ) !important; /* Bright 'Opened/Active' Pip */
    box-shadow:
      0 0 12px rgba(var(--accent-rgb), 0.2),
      inset 0 0 0 1px rgba(var(--accent-rgb), 0.1);
  }

  .col-check {
    width: 32px;
    flex: 0 0 auto;
    display: flex;
    justify-content: flex-start;
    padding-left: 2px;
    padding-right: 12px;
    flex-shrink: 0;
  }
  .col-status {
    width: 42px;
    flex: 0 0 auto;
    display: flex;
    justify-content: flex-start;
    padding-left: 10px;
    flex-shrink: 0;
  }
  .col-name {
    width: var(--col-name-w, 360px);
    flex: 0 0 auto; /* Locked width */
    padding-right: 16px;
    box-sizing: border-box;
    flex-shrink: 0;
  }
  .col-appid {
    width: var(--col-id-w, 400px);
    flex: 0 0 auto; /* No growth, no shrink - Locked width */
    padding-right: 16px;
    box-sizing: border-box;
    flex-shrink: 0;
  }

  .dot {
    width: 11px;
    height: 11px;
    border-radius: 50%;
    background: var(--dot-color);
    box-shadow: 0 0 10px var(--dot-color); /* Intensified bloom radiance */
    filter: saturate(1.8) brightness(1.2);
    opacity: 0.95;
    flex-shrink: 0;
    transition: all 0.25s ease;
  }

  .dot.is-off {
    width: 14px; /* Scaled to 14px to match visual volume of glowing 11px dots */
    height: 14px;
    box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.03) !important;
    filter: none !important;
    opacity: 1;
    margin: -1.5px; /* Alignment for 14px centered on an 11px row track */
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
    font-family: "Fira Code Nerd Font", "Fira Code", "JetBrains Mono",
      "Cascadia Code", "Consolas", monospace;
    font-size: 10.5px;
    font-weight: 400; /* Balanced industrial thickness */
    letter-spacing: 0.2px; /* Increased for better horizontal clarity */
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
    appearance: none;
    -webkit-appearance: none;
    width: 18px;
    height: 18px;
    background: rgba(0, 0, 0, 0.35) !important; /* Bloom Base - Sunken */
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 4px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    flex-shrink: 0;
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.4);
  }

  input[type="checkbox"]:checked {
    border-color: rgba(var(--accent-rgb), 0.85) !important; /* Brighter frame */
    box-shadow:
      0 0 10px rgba(var(--accent-rgb), 0.3),
      inset 0 1px 3px rgba(0, 0, 0, 0.4);
  }

  input[type="checkbox"]:checked::after {
    content: "";
    width: 12px;
    height: 12px;
    background: #fff; /* White check for maximum brightness */
    filter: drop-shadow(
      0 0 2px rgba(var(--accent-rgb), 0.5)
    ); /* Reduced glow */
    mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='4' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='20 6 9 17 4 12'%3E%3C/polyline%3E%3C/svg%3E")
      no-repeat center;
    -webkit-mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='4' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='20 6 9 17 4 12'%3E%3C/polyline%3E%3C/svg%3E")
      no-repeat center;
    mask-size: contain;
    -webkit-mask-size: contain;
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

  /* Modal Styling */
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background: rgba(0, 0, 0, 0.75);
    backdrop-filter: blur(4px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 9000;
  }

  .dropdown-list {
    position: absolute;
    top: calc(100% + 4px);
    left: 0;
    right: 0;
    width: 100%;
    background-color: #0b0f10 !important; /* Absolute Opaque Black */
    background: #0b0f10 !important;
    opacity: 1 !important; /* Force full non-transparency */
    border: 1px solid rgba(255, 255, 255, 0.1); /* Matched to BloomControl Industrial Rim */
    border-radius: 6px;
    padding: 4px;
    z-index: 10000; /* Absolute topmost layer */
    box-shadow: 
      0 32px 64px rgba(0, 0, 0, 1), /* Massive shadow for depth */
      0 0 0 1px rgba(255, 255, 255, 0.05);
    display: flex;
    flex-direction: column;
    gap: 2px;
    overflow: visible; /* Ensure shadows and children clear */
  }

  .dropdown-item {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.35); /* Sidebar Inactive Color */
    padding: 8px 14px;
    font-size: 11px;
    text-align: left;
    cursor: pointer;
    border-radius: 2px; /* Sharper industrial rounding */
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    white-space: nowrap;
    display: block;
    width: 100%;
    border: 1px solid transparent; /* Placeholder for hover border */
    /* Reset header-inherited transparency */
    -webkit-text-fill-color: initial !important;
    background-clip: initial !important;
    -webkit-background-clip: initial !important;
    text-transform: none !important;
  }

  .dropdown-item:hover {
    background: rgba(255, 255, 255, 0.08) !important;
    color: #fff;
    border-color: rgba(var(--accent-rgb), 0.85) !important; /* Brighter Bloom Reveal */
    box-shadow:
      0 0 15px rgba(var(--accent-rgb), 0.2),
      0 0 4px rgba(var(--accent-rgb), 0.4);
    z-index: 50;
    text-shadow: 0 0 8px rgba(255, 255, 255, 0.3);
    filter: brightness(1.15);
  }

  .dropdown-item.active {
    color: var(--accent-color);
    font-weight: 700;
  }

  .modal-content {
    background: #12181a;
    width: 380px;
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 8px;
    box-shadow:
      0 24px 64px rgba(0, 0, 0, 1),
      0 0 0 1px rgba(var(--accent-rgb), 0.1);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    animation: modal-pop 0.25s cubic-bezier(0.175, 0.885, 0.32, 1.275);
  }

  @keyframes modal-pop {
    from {
      opacity: 0;
      transform: scale(0.95);
    }
    to {
      opacity: 1;
      transform: scale(1);
    }
  }

  .modal-header {
    padding: 16px;
    background: rgba(255, 255, 255, 0.02);
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  }

  .modal-header h3 {
    margin: 0;
    font-size: 14px;
    font-weight: 700;
    color: var(--accent-color);
    letter-spacing: 0.5px;
  }

  .close-lite {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.3);
    cursor: pointer;
    transition: color 0.2s;
  }

  .close-lite:hover {
    color: #fff;
  }

  .modal-body {
    padding: 20px 24px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .modal-body p {
    margin: 0;
    font-size: 11px;
    color: rgba(255, 255, 255, 0.5);
  }

  .modal-input {
    background: rgba(0, 0, 0, 0.3);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: #fff;
    padding: 10px 12px;
    border-radius: 4px;
    font-size: 13px;
    outline: none;
    transition: border-color 0.2s;
  }

  .modal-input:focus {
    border-color: var(--accent-color);
    background: rgba(0, 0, 0, 0.4);
  }

  .modal-footer {
    padding: 16px 24px;
    background: rgba(255, 255, 255, 0.02);
    display: flex;
    justify-content: flex-end;
    gap: 12px;
    border-top: 1px solid rgba(255, 255, 255, 0.05);
  }

  .modal-btn {
    padding: 8px 16px;
    border-radius: 4px;
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }

  .modal-btn.cancel {
    background: transparent;
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.4);
  }

  .modal-btn.cancel:hover {
    background: rgba(255, 255, 255, 0.05);
    color: #fff;
  }

  .modal-btn.confirm {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.4);
    pointer-events: none;
  }

  .modal-btn.confirm.active {
    background: var(--accent-color);
    color: #fff;
    border: none;
    pointer-events: auto;
    box-shadow: 0 4px 12px rgba(var(--accent-rgb), 0.3);
  }

  .modal-btn.confirm.active:hover {
    filter: brightness(1.15);
  }
  .risk-filter-container {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .risk-header-btn {
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    border-radius: 4px;
    transition: background 0.2s;
  }

  .risk-header-btn:hover {
    background: rgba(255, 255, 255, 0.05);
  }

  .header-pie {
    width: 14px !important;
    height: 14px !important;
    background: transparent !important; /* Managed by SVG internally */
    margin: 0 !important;
    position: relative;
    border-radius: 50%;
  }

  .pie-overlay {
    position: absolute;
    inset: -2px; /* Allow for explosion space */
    width: calc(100% + 4px);
    height: calc(100% + 4px);
    pointer-events: none;
    z-index: 2;
    overflow: visible;
  }

  .pie-glow-group {
    filter: blur(5px) brightness(1.2) saturate(1.8);
    opacity: 0.4;
  }

  .pie-pieces-group {
    scale: 0.95; /* Slight industrial recession to account for 1px movement */
    transform-origin: center;
  }

  .risk-dropdown {
    width: 180px;
    left: -10px;
    top: calc(100% + 12px); /* Slightly more clearance */
    z-index: 10000 !important; /* Unified topmost priority */
  }

  .risk-check-row {
    display: flex;
    align-items: center;
    gap: 12px;
    width: 100%;
  }

  .mini-dot {
    width: 10px !important;
    height: 10px !important;
    flex-shrink: 0;
  }

  .risk-label {
    flex: 1;
    font-size: 11px;
    color: rgba(255, 255, 255, 0.7);
    /* Reset header-inherited transparency */
    -webkit-text-fill-color: initial !important;
  }

  .risk-active-mark-container {
    width: 8px;
    display: flex;
    justify-content: center;
  }

  .risk-active-mark {
    width: 8px;
    height: 8px;
    background: var(--accent-color);
    border-radius: 50%;
    box-shadow: 0 0 8px var(--accent-color);
  }
</style>
