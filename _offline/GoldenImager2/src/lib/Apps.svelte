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
    Plus,
    Copy,
    Terminal,
    ShieldCheck,
  } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";
  import TacticalToolbar from "./TacticalToolbar.svelte";
  import TacticalContainer from "./TacticalContainer.svelte";
  import { vhdStore } from "./store";
  import { notificationStore } from "./notifications";

  const isTauri = (window as any).__TAURI_METADATA__ !== undefined;

  export let selectionList: string[] = [];
  export let appCount = 0;
  
  // EXPORTED REFS FOR GEOMETRY PROBE
  export let containerRef: HTMLElement | null = null;
  export let listRef: HTMLElement | null = null;
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

  $: selectionList = Array.from(selectedApps);
  $: appCount = selectionList.length;

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
    {
      id: "selected",
      label: "Selected Apps",
      description: "Only show applications currently selected for processing.",
    },
  ];

  const RISK_OPTIONS = [
    { id: "safe", color: "var(--risk-safe)", label: "Safe" },
    { id: "warn", color: "var(--risk-warn)", label: "Optional" },
    { id: "unsafe", color: "var(--risk-unsafe)", label: "Risky" },
    { id: "user", color: "var(--risk-user)", label: "Installed" },
    { id: "unmapped", color: "transparent", label: "Unknown" },
  ];

  let isPolicyOpen = false;
  let isRiskOpen = false;
  let isProfileOpen = false;

  function closeAll() {
    isPolicyOpen = false;
    isRiskOpen = false;
    isProfileOpen = false;
    contextMenuApp = null;
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

  function toggleRiskMenu(e?: any) {
    if (e && e.stopPropagation) e.stopPropagation();
    isRiskOpen = !isRiskOpen;
    isPolicyOpen = false;
    isProfileOpen = false;
  }

  function selectProfile(p: string) {
    selectedProfile = p;
    isProfileOpen = false;
  }

  let contextMenuPos = { x: 0, y: 0 };
  let contextMenuApp: any = null;

  function openContextMenu(app: any, e: MouseEvent) {
    e.preventDefault();
    contextMenuApp = app;
    contextMenuPos = { x: e.clientX, y: e.clientY };
  }

  function closeContextMenu() {
    contextMenuApp = null;
  }

  $: appCount = filteredApps ? filteredApps.length : 0;

  async function loadData() {
    loading = true;
    error = null;
    try {
      if (isTauri) {
        apps = await invoke("get_apps");
        profiles = await invoke("list_app_profiles");
      } else {
        apps = [
          {
            AppId: "Microsoft.WindowsCalculator",
            FriendlyName: "Windows Calculator",
            Recommendation: "safe",
            Publisher: "Microsoft Corporation",
            OriginType: "Appx",
            IsCurated: false,
            IsInstalled: true,
            IsProvisioned: false,
            IsUser: true
          },
          {
            AppId: "Microsoft.YourPhone",
            FriendlyName: "Phone Link",
            Recommendation: "unsafe",
            Publisher: "Microsoft Corporation",
            OriginType: "Provisioned",
            IsCurated: true,
            IsInstalled: true,
            IsProvisioned: true,
            IsUser: false
          }
        ];
        profiles = ["DefaultProfile.json", "Aggressive.json"];
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

  // Force reactivity for nested UI elements in Svelte 4
  $: selectionList = Array.from(selectedApps);

  async function loadProfile() {
    if (!selectedProfile) {
      selectedApps = new Set();
      isApplied = false;
      return;
    }
    if (!isTauri) return;
    try {
      console.log(`[Apps] Loading Profile: ${selectedProfile}`);
      const profileAppIds: string[] = await invoke("load_app_profile", {
        name: selectedProfile,
      });

      console.group(`[Apps] Profile Load: ${selectedProfile}`);
      console.log(`IDs found in JSON:`, profileAppIds);

      const newSelection = new Set<string>();
      const systemApps = [...apps];

      if (systemApps.length === 0) {
        console.warn("[Apps] System inventory is empty. Cannot match profile apps.");
      } else {
        console.log(`[Apps] System Inventory Sample (keys):`, Object.keys(systemApps[0]));
      }

      profileAppIds.forEach((pId) => {
        const pIdLower = pId.toLowerCase().trim();
        const pIdBase = pIdLower.split('_')[0];

        const match = systemApps.find(
          (a) => {
            const aId = a.AppId || "";
            const aName = a.FriendlyName || "";
            
            const aIdLower = aId.toLowerCase();
            const aNameLower = aName.toLowerCase();
            const aIdBase = aIdLower.split('_')[0];

            // 1. Exact ID match
            if (aIdLower === pIdLower) return true;
            
            // 2. Base ID match (ignoring version suffixes like _1.2.3_...)
            if (aIdBase === pIdBase && aIdBase.length > 3) return true;
            
            // 3. Prefix matches (one is a subset of the other)
            if (aIdLower.startsWith(pIdLower + "_") || pIdLower.startsWith(aIdLower + "_")) return true;
            
            // 4. Friendly Name match (for Appx which stores short name in FriendlyName)
            if (aNameLower === pIdLower || aNameLower === pIdBase) return true;

            return false;
          }
        );

        if (match) {
          const finalId = (match.AppId || "").trim();
          if (finalId) {
            console.log(`[Apps] MATCH: "${pId}" -> "${finalId}"`);
            newSelection.add(finalId);
          }
        } else {
           console.warn(`[Apps] NO MATCH FOUND for: "${pId}" (Base: "${pIdBase}")`);
        }
      });

      console.log(`[Apps] Load Complete. Matched ${newSelection.size} of ${profileAppIds.length} apps.`);
      console.groupEnd();

      selectedApps = newSelection;
      isApplied = true;
      notificationStore.add(`Profile "${selectedProfile}" loaded.`, 'info');
    } catch (e) {
      notificationStore.add(`Load failed: ${e}`, 'error');
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
      notificationStore.add(`Profile "${finalName}" saved successfully.`, 'success');
    } catch (e) {
      notificationStore.add(`Save failed: ${e}`, 'error');
    }
  }

  async function deleteProfile(p: string, event: any) {
    event.stopPropagation();
    if (!p || !isTauri) return;
    if (!confirm(`Delete profile "${p.replace(".json", "")}"?`)) return;

    try {
      await invoke("delete_app_profile", { name: p });
      if (selectedProfile === p) selectedProfile = "";
      profiles = await invoke("list_app_profiles");
      notificationStore.add(`Profile "${p}" deleted.`, 'warning');
    } catch (e) {
      notificationStore.add(`Delete failed: ${e}`, 'error');
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
      case "selected":
        matchesFilter = selectionList.includes(app.AppId);
        break;
      case "all":
        matchesFilter = true;
        break;
    }

    return matchesSearch && matchesFilter;
  });

  $: filteredByRisk = filteredApps.filter((app) => {
    // Determine Effective Risk Category for Filter Parity
    let effectiveRisk: string;
    if (app.IsUser || app.Recommendation === "user") {
      effectiveRisk = "user";
    } else if (app.IsCurated) {
      effectiveRisk = app.Recommendation;
    } else {
      effectiveRisk = "unmapped";
    }

    return selectedRisks.has(effectiveRisk);
  });

  function toggleRiskOption(id: string) {
    if (selectedRisks.has(id)) {
      if (selectedRisks.size === 1) return; // Prevent complete deselection
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
        return "#778899";
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

  function toggleSelectAll() {
    const allSelected = filteredByRisk.length > 0 && filteredByRisk.every((a) => selectedApps.has(a.AppId));
    if (allSelected) {
      filteredByRisk.forEach((a) => selectedApps.delete(a.AppId));
    } else {
      filteredByRisk.forEach((a) => selectedApps.add(a.AppId));
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

  $: nameWidth = (maxNameLen + 4) * 7.2; /* Industrial Sans Spacing */
  $: idWidth = (maxIdLen + 4) * 8.0; /* Mono Package Spacing */

  function closeModals() {
    showSaveModal = false;
    isPolicyOpen = false;
    isProfileOpen = false;
    isRiskOpen = false;
    contextMenuApp = null;
  }

  /* Selector Width Reactivity */
  $: maxPolicyLen = FILTER_OPTIONS.reduce(
    (max, opt) => Math.max(max, opt.label.length),
    12,
  );
  $: policyCalcWidth = Math.max(120, (maxPolicyLen + 4) * 6.2) + "px";

  $: maxProfileLen = profiles.reduce(
    (max, p) => Math.max(max, p.replace(".json", "").length),
    Math.max(12, selectedProfile.replace(".json", "").length),
  );
  $: profileCalcWidth = Math.max(120, (maxProfileLen + 5) * 6.2) + "px";

  async function copyToClipboard(
    text: string | null | undefined,
    e?: MouseEvent,
  ) {
    if (e) e.stopPropagation();
    if (!text) return;
    try {
      await navigator.clipboard.writeText(text);
    } catch (err) {
      console.error("Copy failed", err);
    }
    contextMenuApp = null;
  }

  async function toggleAppInstall(appId: string) {
    const app = apps.find(a => a.AppId === appId);
    if (!app) return;

    if (!isTauri) {
      alert(`[MOCK] Toggling ${app.FriendlyName}...`);
      return;
    }

    try {
      if (app.Status === 'installed') {
        await invoke("uninstall_app", { appId });
      } else {
        await invoke("install_app", { 
          appId: app.AppId, 
          appName: app.FriendlyName,
          isSystem: app.IsProvisioned || app.IsUser,
          remote_active: $vhdStore.remoteActive,
          vm_name: $vhdStore.vmName || null
        });
      }
      await loadData(); // Refresh list to update status
    } catch (e) {
      alert(`Action failed: ${e}`);
    }
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

<div 
  class="panel"
  style="--col-name-w: {nameWidth}px; --col-id-w: {idWidth}px;"
>
  <TacticalToolbar 
    policyOptions={FILTER_OPTIONS}
    profiles={profiles}
    bind:selectedPolicy={viewFilter}
    bind:selectedProfile={selectedProfile}
    bind:searchTerm={searchTerm}
    loading={loading}
    selectionCount={selectionList.length}
    policyCalcWidth={policyCalcWidth}
    profileCalcWidth={profileCalcWidth}
    on:loadProfile={loadProfile}
    on:saveProfile={saveProfile}
    on:saveAsProfile={() => { showSaveModal = true; saveName = selectedProfile.replace(".json", "") || ""; }}
  on:deleteProfile={(e) => deleteProfile(e.detail, e)}
    on:refresh={loadData}
  />


  <div
    class="table-header"
  >
    <div class="col-check">
      <input
        type="checkbox"
        checked={filteredByRisk.length > 0 &&
          filteredByRisk.every((a) => selectedApps.has(a.AppId))}
        on:change={toggleSelectAll}
      />
    </div>
    <div class="col-status">
      <div class="risk-filter-container">
        <div
          class="risk-filter-btn-wrapper"
          on:click|stopPropagation={() => {}}
          on:keydown={() => {}}
          role="button"
          tabindex="-1"
        >
          <BloomControl
            width="18px"
            height="18px"
            active={isRiskOpen}
            on:click={toggleRiskMenu}
            style="padding: 0; border-radius: 50%; border-color: rgba(255, 255, 255, 0.1) !important; box-shadow: inset 0 1px 4px rgba(0, 0, 0, 0.4), inset 0 0 0 1px rgba(0, 0, 0, 0.1) !important; background: rgba(0, 0, 0, 0.35) !important;"
          >
            <div
              class="dot header-pie"
              class:is-off={selectedRisks.size === 0 ||
                (selectedRisks.has("unmapped") && selectedRisks.size === 1)}
            >
              {#if selectedRisks.size > 0}
                {@const selectedList = getSelectedRisksList(selectedRisks)}
                <svg viewBox="-2.5 -2.5 16 16" class="pie-overlay">
                  <!-- Exploded Spectral Glow Group -->
                  <g class="pie-glow-group" transform="translate(-1.5, -1.5)">
                    {#if selectedList.length === 1}
                      <circle
                        cx="7"
                        cy="7"
                        r="7.5"
                        fill={selectedList[0].color}
                        style="opacity: {selectedList[0].id === 'unmapped'
                          ? 0
                          : 1}"
                      />
                    {:else}
                      {#each selectedList as opt, i}
                        {@const offset = getExplodeOffset(
                          i,
                          selectedList.length,
                        )}
                        <path
                          d={getSegmentPath(i, selectedList.length)}
                          fill={opt.color}
                          transform="translate({offset.x}, {offset.y})"
                          style="opacity: {opt.id === "unmapped" ? 0 : 1}"
                        />
                      {/each}
                    {/if}
                  </g>
  
                  <!-- Exploded Physical Pieces -->
                  <g class="pie-pieces-group" transform="translate(-1.5, -1.5)">
                    {#if selectedList.length === 1}
                      <circle
                        cx="7"
                        cy="7"
                        r="7.5"
                        fill={selectedList[0].color === "transparent"
                          ? "rgba(0,0,0,0)"
                          : selectedList[0].color}
                      />
                    {:else}
                      {#each selectedList as opt, i}
                        {@const offset = getExplodeOffset(
                          i,
                          selectedList.length,
                        )}
                        <path
                          d={getSegmentPath(i, selectedList.length)}
                          fill={opt.color === "transparent"
                            ? "rgba(0,0,0,0)"
                            : opt.color}
                          transform="translate({offset.x}, {offset.y})"
                          stroke="#0b0f10"
                          stroke-width="1.2"
                        />
                      {/each}
                    {/if}
                  </g>
                </svg>
              {/if}
            </div>
          </BloomControl>
        </div>

        {#if isRiskOpen}
          <div class="dropdown-list risk-dropdown">
            {#each RISK_OPTIONS as opt}
              <button
                class="dropdown-item risk-item"
                on:click|stopPropagation={() => toggleRiskOption(opt.id)}
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
  <div bind:this={containerRef} style="display: contents;">
    <TacticalContainer padding="0 6px">
      <div 
        class="table-body" 
        bind:this={listRef} 
      >
        {#if loading}
          <div class="state-view">
            <RefreshCw size={32} class="spin dim" />
            <span>Synchronizing System Inventory...</span>
          </div>
        {:else if error}
          <div class="state-view error">
            <RefreshCw size={32} class="dim" />
            <span>Sync Failure: {error}</span>
            <button class="retry-btn" on:click={loadData}>Retry Connection</button>
          </div>
        {:else}
          {#each filteredByRisk as app}
            <div
              class="row"
              style="--row-hue: {getRowHue(app.Recommendation)}"
              class:selected={selectionList.includes(app.AppId)}
              on:click={() => toggleSelect(app.AppId)}
              on:contextmenu={(e) => openContextMenu(app, e)}
              on:keydown={(e) =>
                (e.key === "Enter" || e.key === " ") && toggleSelect(app.AppId)}
              role="row"
              tabindex="0"
            >
              <div class="col-check">
                <input
                   type="checkbox"
                   checked={selectionList.includes(app.AppId)}
                   on:change={() => toggleSelect(app.AppId)}
                   on:click|stopPropagation
                />
              </div>
              <div class="col-status">
                <div
                  class="dot"
                  class:is-off={app.Recommendation === "unmapped" ||
                    (!app.IsUser &&
                      !["safe", "warn", "unsafe"].includes(app.Recommendation))}
                  style="--dot-color: {getStatusColor(app)}"
                ></div>
              </div>
              <div class="col-name">
                <span class="text-main">{app.FriendlyName}</span>
              </div>
              <div class="col-appid">
                <span class="text-mono">{app.AppId}</span>
              </div>
              <div class="col-actions">
                <button 
                  class="row-action-btn install"
                  on:click={(e) => { e.stopPropagation(); toggleAppInstall(app.AppId); }}
                  title={app.Status === 'installed' ? 'Uninstall app' : 'Install app'}
                >
                  {#if app.Status === 'installed'}
                    <X size={12} />
                  {:else}
                    <Check size={12} />
                  {/if}
                </button>
              </div>
            </div>
          {/each}
        {/if}
      </div>
    </TacticalContainer>
  </div>
</div>

{#if contextMenuApp}
  <div 
    class="context-menu" 
    style="left: {contextMenuPos.x}px; top: {contextMenuPos.y}px;"
    on:click|stopPropagation
    on:contextmenu|preventDefault
  >
    <div class="menu-header">
      <span class="menu-title truncate">{contextMenuApp.FriendlyName}</span>
    </div>
    <button class="menu-item" on:click={(e) => copyToClipboard(contextMenuApp.FriendlyName, e)}>
      <Copy size={12} /> <span>Copy Friendly Name</span>
    </button>
    <button class="menu-item" on:click={(e) => copyToClipboard(contextMenuApp.AppId, e)}>
      <Copy size={12} /> <span>Copy Identifier</span>
    </button>
    <button class="menu-item" on:click={(e) => copyToClipboard(contextMenuApp.UninstallString, e)}>
      <Terminal size={12} /> <span>Copy Uninstall String</span>
    </button>
    <div class="menu-divider"></div>
    <button class="menu-item primary" on:click={(e) => copyToClipboard(`Name: ${contextMenuApp.FriendlyName}\nID: ${contextMenuApp.AppId}\nUninstall: ${contextMenuApp.UninstallString || "N/A"}`, e)}>
      <Zap size={12} /> <span>Copy Complete Diagnostic</span>
    </button>
  </div>
{/if}

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

  .table-body {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
    padding: 0 6px 4px 6px; /* Optimized bottom breathing room */
    margin-top: 4px; /* Matches 4px inter-row gap for top-most entry */
    display: flex;
    flex-direction: column;
    scrollbar-gutter: stable;
  }

  .table-header {
    display: flex;
    align-items: center;
    padding: 0 25px; /* Synchronized: 24px panel + 1px border shift */
    height: 32px;
    font-size: 10px;
    font-weight: 800;
    color: #fff;
    background: #1a1f21 !important; /* Industrial Grey Bar */
    border: none; /* REMOVED RIM PER USER REQ */
    border-radius: 4px;
    margin-bottom: 0px; /* Gap handled by table-body margin-top */
    text-transform: uppercase;
    letter-spacing: 0.8px;
    flex-shrink: 0;
    z-index: 1000;
    position: relative;
    cursor: pointer;
  }
  .row:first-child {
    margin-top: 0; /* Absolute alignment with scrollbar start */
  }

  .row {
    position: relative;
    display: flex;
    align-items: center;
    height: 36px;
    margin: 2px 0; /* Slight modular gap */
    padding: 0 12px;
    font-size: 11px;
    cursor: pointer;
    border-radius: 4px; /* Slight corner rounding */
    
    /* THE INDUSTRIAL SLAB (v7) - BRING BACK THE LIGHT */
    background: 
      linear-gradient(to right, var(--slab-edge) 0%, var(--slab-base) 15%, var(--slab-base) 85%, var(--slab-edge) 100%);

    /* MACHINED EDGES: Sharp Milled Silver-Grey (#6A6E72) */
    border-top: 1px solid var(--slab-rim);
    border-bottom: 1px solid #000000;
    border-left: 1px solid #000000;
    border-right: 1px solid #000000;
    
    box-shadow: 
      0 4px 12px rgba(0, 0, 0, 0.5),
      inset 0 1px 0 rgba(255, 255, 255, 0.05); /* Lighter internal catch */
      
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    overflow: hidden;
    flex-shrink: 0;
  }

  /* REFINED CELLULAR GRAIN: 10% Opacity Overlay - Visible Pits */
  .row::before {
    content: "";
    position: absolute;
    inset: 0;
    background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='voronoiFilter'%3E%3CfeTurbulence type='turbulence' baseFrequency='0.45' numOctaves='3' stitchTiles='stitch'/%3E%3CfeColorMatrix type='matrix' values='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 10 0'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23voronoiFilter)'/%3E%3C/svg%3E");
    opacity: 0.10;
    pointer-events: none;
    mix-blend-mode: overlay;
    z-index: 1;
  }

  .row:hover {
    background-color: rgba(255, 255, 255, 0.03); /* Subtle blend on hover over gradient */
    border-color: rgba(var(--accent-rgb), 0.85) !important;
    box-shadow:
      0 0 15px rgba(var(--accent-rgb), 0.2),
      0 2px 10px rgba(0, 0, 0, 0.6);
    z-index: 50;
    filter: brightness(1.1);
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
    background: 
      linear-gradient(135deg, rgba(var(--accent-rgb), 0.12), rgba(var(--accent-rgb), 0.05)), /* ACCENT TINT */
      linear-gradient(to right, #1A1C1D 0%, #222526 15%, #222526 85%, #1A1C1D 100%) !important; /* MAINTAIN SLAB GEOMETRY */
    border-color: rgba(var(--accent-rgb), 0.6) !important; 
    box-shadow:
      0 0 12px rgba(var(--accent-rgb), 0.15),
      inset 0 0 0 1px rgba(var(--accent-rgb), 0.05);
  }

  .col-check {
    width: 32px;
    flex: 0 0 auto;
    display: flex;
    justify-content: flex-start;
    padding-left: 2px;
    padding-right: 8px; /* Balanced industrial gap */
    flex-shrink: 0;
  }
  .col-status {
    width: 32px; /* Synchronized with col-check width */
    flex: 0 0 auto;
    display: flex;
    justify-content: center; /* PERFECT INDUSTRIAL CENTERING */
    align-items: center;
    flex-shrink: 0;
  }
  .col-copy {
    width: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-right: 4px;
  }
  .copy-trigger-wrapper {
    position: relative;
    display: flex;
  }
  .row-copy-btn {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.2);
    cursor: pointer;
    padding: 4px;
    display: flex;
    border-radius: 4px;
    transition: all 0.2s;
  }
  .row-copy-btn:hover {
    background: rgba(255, 255, 255, 0.1);
    color: var(--accent-color);
  }
  .dropdown-item:hover {
    background: rgba(255, 255, 255, 0.08) !important;
    color: #fff;
    border-color: rgba(
      var(--accent-rgb),
      0.85
    ) !important; /* Brighter Bloom Reveal */
    box-shadow:
      0 0 15px rgba(var(--accent-rgb), 0.2),
      0 0 4px rgba(var(--accent-rgb), 0.4);
    z-index: 50;
    text-shadow: 0 0 8px rgba(255, 255, 255, 0.3);
    filter: brightness(1.15);
  }
  .menu-header {
    padding: 6px 12px;
    background: rgba(255, 255, 255, 0.03);
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    margin-bottom: 4px;
  }
  .menu-title {
    font-size: 10px;
    font-weight: 800;
    color: var(--accent-color);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .context-menu {
    position: fixed;
    background: #0b0f10;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 6px;
    padding: 2px;
    z-index: 10000;
    box-shadow: 0 12px 32px rgba(0, 0, 0, 0.8), 0 0 0 1px rgba(var(--accent-rgb), 0.1);
    display: flex;
    flex-direction: column;
    min-width: 180px;
    animation: menu-pop 0.15s cubic-bezier(0.4, 0, 0.2, 1);
  }
  @keyframes menu-pop {
    from { opacity: 0; transform: scale(0.95) translateY(-4px); }
    to { opacity: 1; transform: scale(1) translateY(0); }
  }
  .menu-item {
    background: transparent;
    border: none;
    padding: 8px 12px;
    font-size: 11px;
    color: rgba(255, 255, 255, 0.6);
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 10px;
    border-radius: 4px;
    transition: all 0.2s;
    text-align: left;
  }
  .menu-item:hover {
    background: rgba(255, 255, 255, 0.05);
    color: #fff;
    box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.05);
  }
  .menu-item.primary:hover {
    background: rgba(var(--accent-rgb), 0.15);
    color: var(--accent-color);
  }
  .menu-divider {
    height: 1px;
    background: rgba(255, 255, 255, 0.08);
    margin: 4px 6px;
  }
  .col-name {
    width: var(--col-name-w, 360px);
    flex: 0 0 auto; /* Locked width */
    padding-left: 8px; /* Symmetrical risk-indicator gap */
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
  .col-actions {
    width: 80px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .row-action-btn {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.4);
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s;
  }

  .row-action-btn:hover {
    background: var(--accent-color);
    border-color: var(--accent-color);
    color: #000;
  }

  .row-action-btn.install:hover {
    background: #00e676;
    border-color: #00e676;
    color: #000;
    box-shadow: 0 0 10px rgba(0, 230, 118, 0.4);
  }

  .dot {
    width: 11px; /* Reverted to 11px Industrial Baseline */
    height: 11px;
    border-radius: 50%;
    background: var(--dot-color);
    box-shadow: 
      0 0 14px var(--dot-color), /* Primary Radiant Bloom */
      0 0 3px rgba(255, 255, 255, 0.6); /* Sharper filament catch */
    
    /* SPECULAR SPECKLE: Light catches on surface grain micro-pits */
    filter: saturate(2.0) brightness(1.3) drop-shadow(0 0 5px var(--dot-color));
    
    opacity: 0.95;
    flex-shrink: 0;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    box-sizing: border-box; /* PREVENT SIZE BLOATING */
    z-index: 10;
  }

  .dot.is-off {
    width: 18px; /* Standardize with Checkbox footprint */
    height: 18px;
    border-radius: 50%; /* Circle format */
    background: rgba(0, 0, 0, 0.35) !important; /* Bloom Style Base */
    border: 1px solid rgba(255, 255, 255, 0.1); /* Master industrial piping - Bloom Parity */
    box-shadow:
      inset 0 1px 4px rgba(0, 0, 0, 0.4),
      inset 0 0 0 1px rgba(0, 0, 0, 0.1) !important;
    filter: none !important;
    opacity: 1;
    margin: 0px;
    box-sizing: border-box; /* PREVENT SIZE BLOATING */
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

  .state-view :global(.spin) {
    color: #00bcd4;
    filter: drop-shadow(0 0 10px rgba(0, 188, 212, 0.5));
    animation: spin 1.2s cubic-bezier(0.4, 0, 0.2, 1) infinite, pulse-glow-active 2s ease-in-out infinite;
  }

  .state-view span {
    font-size: 10.5px;
    font-weight: 700;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: rgba(255, 255, 255, 0.75);
    text-shadow: 0 2px 10px rgba(0, 0, 0, 0.8), 0 0 8px rgba(255, 255, 255, 0.2);
  }

  .state-view.error {
    color: var(--risk-unsafe);
  }

  .retry-btn {
    background: rgba(255, 61, 96, 0.1);
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
    background: rgba(255, 61, 96, 0.2);
    box-shadow: 0 0 12px rgba(255, 61, 96, 0.3);
  }

  @keyframes pulse-glow-active {
    0%, 100% { filter: drop-shadow(0 0 8px rgba(0, 188, 212, 0.3)); opacity: 0.8; }
    50% { filter: drop-shadow(0 0 18px rgba(0, 188, 212, 0.6)); opacity: 1; }
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
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

  input[type="checkbox"]:hover,
  .row:hover input[type="checkbox"] {
    background-color: rgba(255, 255, 255, 0.08);
    border-color: rgba(var(--accent-rgb), 0.9) !important; /* Intensive Bloom Reveal */
    box-shadow:
      0 0 15px rgba(var(--accent-rgb), 0.25),
      0 0 4px rgba(var(--accent-rgb), 0.45);
    color: #fff;
    cursor: pointer;
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
    border-radius: 12px 12px 0 0;
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
    background-color: #1a1f21 !important; /* Industrial Grey Hub */
    background: #1a1f21 !important;
    opacity: 1 !important; /* Force full non-transparency */
    border: 1px solid rgba(255, 255, 255, 0.1); /* Matched to BloomControl Industrial Rim */
    border-radius: 6px;
    padding: 4px;
    z-index: 10000; /* Absolute topmost layer */
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
    display: flex;
    flex-direction: column;
    gap: 2px;
    overflow: visible; /* Ensure shadows and children clear */
  }

  .dropdown-item {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.35); /* Sidebar Inactive Color */
    padding: 10px 14px 8px 12px; /* Increased top padding for breathing room, tighter left */
    font-size: 11px;
    text-align: left;
    cursor: pointer;
    border-radius: 2px; /* Sharper industrial rounding */
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    white-space: nowrap;
    display: flex;
    align-items: center;
    justify-content: flex-start; /* Ensure left justification */
    flex: 1;
    min-width: 0;
    padding-right: 32px; /* Ensure truncation happens before overlapping garbage icon */
    border: 1px solid transparent; /* Placeholder for hover border */
    /* Reset header-inherited transparency */
    -webkit-text-fill-color: initial !important;
    background-clip: initial !important;
    -webkit-background-clip: initial !important;
    text-transform: none !important;
  }
  
  .select-label {
    text-align: left;
    display: block;
    width: 100%;
    margin-top: 1px; /* Subtle downward nudge for industrial balance */
    padding-left: 2px;
  }

  .dropdown-item-wrapper {
    display: flex;
    align-items: center;
    width: 100%;
    gap: 0;
    position: relative;
  }

  .delete-profile-btn {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.2);
    padding: 0 8px;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s;
    position: absolute;
    right: 4px;
    z-index: 10;
    opacity: 0; /* Hidden by default, revealed on wrapper hover */
  }

  .delete-profile-btn:hover {
    color: #ff3d60;
    filter: drop-shadow(0 0 4px #ff3d60);
  }

  .dropdown-item-wrapper:hover .delete-profile-btn {
    opacity: 1;
  }

  .dropdown-item:hover {
    background: rgba(255, 255, 255, 0.08) !important;
    color: #fff;
    border-color: rgba(
      var(--accent-rgb),
      0.85
    ) !important; /* Brighter Bloom Reveal */
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
  .header-selection-btn {
    background: rgba(0, 0, 0, 0.45);
    border: 1px solid rgba(255, 255, 255, 0.08);
    width: 24px;
    height: 24px;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    color: rgba(255, 255, 255, 0.2);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.3);
  }

  .header-selection-btn:hover {
    background: rgba(255, 255, 255, 0.05);
    border-color: rgba(var(--accent-rgb), 0.4);
    color: rgba(var(--accent-rgb), 0.6);
  }

  .risk-filter-container {
    position: relative;
    z-index: 5000; /* Absolute top-row priority */
    display: flex;
    justify-content: center;
    align-items: center;
  }

  .risk-filter-btn-wrapper {
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
  }

  .risk-header-btn {
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 16px; /* Reduced to provide tighter centering in col-status */
    height: 16px;
    border-radius: 4px;
    transition: background 0.2s;
    opacity: 1 !important; /* MASTER LUMINOSITY LOCK */
  }

  .risk-header-btn:hover {
    background: rgba(255, 255, 255, 0.05);
  }

  .risk-header-btn :global(svg) {
    opacity: 1 !important; /* EXEMPT from global toolbar dimming */
    filter: none !important; /* EXEMPT from global toolbar drop-shadows */
  }

  .header-pie {
    width: 11px !important; /* Synchronized to 11px Row Dots */
    height: 11px !important;
    background: transparent !important; /* Managed by SVG internally */
    margin: 0 !important;
    position: relative;
    border-radius: 50%;
    pointer-events: none; /* PASS-THROUGH TO BLOOM CONTROL */
  }

  .header-pie.is-off {
    border-radius: 50%;
    width: 18px !important;
    height: 18px !important;
    margin: 0 !important;
    background: transparent !important; /* Managed by parent BloomControl */
    border: none !important;
    box-shadow: none !important;
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
    width: 12px !important;
    height: 12px !important;
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
