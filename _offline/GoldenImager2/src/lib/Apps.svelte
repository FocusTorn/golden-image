<script lang="ts">
  import { onMount, tick } from "svelte";
  import { 
    Search, 
    Save, 
    ChevronDown, 
    RefreshCw, 
    X, 
    Plus, 
    Copy, 
    Trash2 
  } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";
  import TacticalToolbar from "./TacticalToolbar.svelte";
  import TacticalContainer from "./TacticalContainer.svelte";
  import AppRow from "./AppRow.svelte";
  import { AppsEngine } from "./apps-engine.svelte";
  import type { AppInfo } from "./types";

  interface Props {
    selectionList?: string[];
    appCount?: number;
    containerRef?: HTMLElement | null;
    listRef?: HTMLElement | null;
  }

  let { 
    selectionList = $bindable([]),
    appCount = $bindable(0),
    containerRef = $bindable(null),
    listRef = $bindable(null)
  }: Props = $props();

  const engine = new AppsEngine();

  // Sync selectionList for parent components
  $effect(() => {
    selectionList = Array.from(engine.selectedApps);
    appCount = engine.filteredApps.length;
  });

  let showSaveModal = $state(false);
  let saveName = $state("");
  let contextMenuApp = $state<AppInfo | null>(null);
  let contextMenuPos = $state({ x: 0, y: 0 });

  function openContextMenu(app: AppInfo, e: MouseEvent) {
    e.preventDefault();
    contextMenuApp = app;
    contextMenuPos = { x: e.clientX, y: e.clientY };
  }

  function handleSaveAs() {
    saveName = engine.selectedProfile.replace(".json", "") || "";
    showSaveModal = true;
  }

  const getStatusColor = (app: AppInfo) => {
    if (app.IsUser || app.Recommendation === "user") return "var(--risk-user)";
    switch (app.Recommendation) {
      case "safe": return "var(--risk-safe)";
      case "warn": return "var(--risk-warn)";
      case "unsafe": return "var(--risk-unsafe)";
      default: return "#778899";
    }
  };

  const getRowHue = (rec: string) => {
    switch (rec) {
      case "safe": return "rgba(63, 185, 80, 0.1)";
      case "unsafe": return "rgba(248, 81, 73, 0.15)";
      default: return "rgba(210, 153, 34, 0.1)";
    }
  };

  let nameWidth = $derived.by(() => {
    const max = engine.apps.reduce((m, a) => Math.max(m, (a.FriendlyName || "").length), 20);
    return (max + 4) * 7.2;
  });

  let idWidth = $derived.by(() => {
    const max = engine.apps.reduce((m, a) => Math.max(m, (a.AppId || "").length), 30);
    return (max + 4) * 8.0;
  });
</script>

<svelte:window onclick={() => { engine.toggleRisk(""); contextMenuApp = null; }} />

{#if showSaveModal}
  <div class="modal-overlay" onclick={() => (showSaveModal = false)}>
    <div class="modal-content" onclick={(e) => e.stopPropagation()}>
      <div class="modal-header">
        <h3>Save Profile</h3>
        <button class="close-lite" onclick={() => (showSaveModal = false)}><X size={16} /></button>
      </div>
      <div class="modal-body">
        <p>Enter a unique name to store the current selection.</p>
        <input
          type="text"
          bind:value={saveName}
          placeholder="e.g. Minimalist-Build"
          class="modal-input"
          onkeydown={(e) => e.key === "Enter" && engine.saveProfile(saveName).then(() => showSaveModal = false)}
        />
      </div>
      <div class="modal-footer">
        <button class="modal-btn cancel" onclick={() => (showSaveModal = false)}>Cancel</button>
        <button class="modal-btn confirm" onclick={() => engine.saveProfile(saveName).then(() => showSaveModal = false)}>Save Profile</button>
      </div>
    </div>
  </div>
{/if}

{#if contextMenuApp}
  <div class="context-menu" style="left: {contextMenuPos.x}px; top: {contextMenuPos.y}px;">
    <button onclick={() => navigator.clipboard.writeText(contextMenuApp?.AppId || "")}>
      <Copy size={12} /> Copy Package ID
    </button>
    <button onclick={() => navigator.clipboard.writeText(contextMenuApp?.FriendlyName || "")}>
      <Copy size={12} /> Copy Name
    </button>
    <div class="divider"></div>
    <button class="danger" onclick={() => { /* Implementation for toggle */ }}>
      <Trash2 size={12} /> Uninstall (Live)
    </button>
  </div>
{/if}

<div class="panel" style="--col-name-w: {nameWidth}px; --col-id-w: {idWidth}px;">
  <TacticalToolbar 
    profiles={engine.profiles}
    bind:selectedPolicy={engine.viewFilter}
    bind:selectedProfile={engine.selectedProfile}
    bind:searchTerm={engine.searchTerm}
    loading={engine.loading}
    selectionCount={engine.selectedApps.size}
    onrefresh={() => engine.refresh()}
    onloadProfile={() => engine.loadProfile()}
    onsaveProfile={() => engine.saveProfile()}
    onsaveAsProfile={handleSaveAs}
    ondeleteProfile={(p) => engine.deleteProfile(p)}
  />

  <div class="table-header">
    <div class="col-check">
      <input type="checkbox" checked={engine.filteredApps.length > 0 && engine.filteredApps.every(a => engine.selectedApps.has(a.AppId))} onchange={() => engine.toggleSelectAll()} />
    </div>
    <div class="col-status">
      <BloomControl 
        width="18px" height="18px" 
        onclick={(e) => { e.stopPropagation(); }}
        style="padding:0; border-radius:50%;"
      >
        <div class="pie-placeholder"></div>
      </BloomControl>
    </div>
    <div class="col-name">Friendly Name</div>
    <div class="col-appid">System Identifier / Package Name</div>
  </div>

  <div bind:this={containerRef} style="display: contents;">
    <TacticalContainer padding="0 6px">
      <div class="table-body" bind:this={listRef}>
        {#if engine.loading}
          <div class="state-view">
            <RefreshCw size={32} class="spin dim" />
            <span>Synchronizing System Inventory...</span>
          </div>
        {:else if engine.error}
          <div class="state-view error">
            <span>Sync Failure: {engine.error}</span>
            <button class="retry-btn" onclick={() => engine.refresh()}>Retry Connection</button>
          </div>
        {:else}
          {#each engine.filteredApps as app (app.AppId)}
            <AppRow 
              {app}
              isSelected={engine.selectedApps.has(app.AppId)}
              rowHue={getRowHue(app.Recommendation)}
              dotColor={getStatusColor(app)}
              onclick={() => engine.toggleSelect(app.AppId)}
              oncontextmenu={(e) => openContextMenu(app, e)}
              ontoggleSelect={() => engine.toggleSelect(app.AppId)}
            />
          {/each}
        {/if}
      </div>
    </TacticalContainer>
  </div>
</div>

<style>
  .panel {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    position: relative;
  }

  .table-header {
    display: flex;
    align-items: center;
    background: rgba(0, 0, 0, 0.4);
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    height: 32px;
    padding: 0 4px;
    font-size: 10px;
    font-weight: 800;
    text-transform: uppercase;
    color: rgba(255, 255, 255, 0.4);
    letter-spacing: 0.05em;
  }

  .col-check { width: 40px; display: flex; justify-content: center; }
  .col-status { width: 40px; display: flex; justify-content: center; }
  .col-name { width: var(--col-name-w); padding-left: 8px; }
  .col-appid { flex: 1; padding-left: 12px; }

  .table-body {
    flex: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
  }

  .state-view {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 16px;
    color: rgba(255, 255, 255, 0.3);
    font-size: 12px;
    letter-spacing: 0.05em;
  }

  .dim { opacity: 0.3; }

  .context-menu {
    position: fixed;
    z-index: 1000;
    background: #14181b;
    border: 1px solid rgba(255, 255, 255, 0.1);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
    border-radius: 4px;
    padding: 4px;
    display: flex;
    flex-direction: column;
    min-width: 160px;
  }

  .context-menu button {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.7);
    padding: 8px 12px;
    text-align: left;
    font-size: 11px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 10px;
    border-radius: 2px;
  }

  .context-menu button:hover {
    background: rgba(255, 255, 255, 0.05);
    color: #fff;
  }

  .context-menu button.danger:hover {
    color: var(--risk-unsafe);
    background: rgba(255, 23, 68, 0.1);
  }

  .divider { height: 1px; background: rgba(255, 255, 255, 0.05); margin: 4px 0; }

  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.7);
    backdrop-filter: blur(4px);
    z-index: 2000;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .modal-content {
    background: #1a1f22;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    width: 320px;
    box-shadow: 0 12px 48px rgba(0, 0, 0, 0.8);
  }

  .modal-header { padding: 16px; border-bottom: 1px solid rgba(255, 255, 255, 0.05); display: flex; justify-content: space-between; align-items: center; }
  .modal-header h3 { font-size: 12px; font-weight: 800; text-transform: uppercase; margin: 0; color: var(--accent-color); }
  .modal-body { padding: 20px; }
  .modal-body p { font-size: 11px; color: rgba(255, 255, 255, 0.5); margin: 0 0 12px 0; }
  .modal-input { width: 100%; background: #000; border: 1px solid rgba(255, 255, 255, 0.1); padding: 8px 12px; color: #fff; font-size: 12px; border-radius: 4px; }
  .modal-footer { padding: 12px 16px; display: flex; justify-content: flex-end; gap: 12px; background: rgba(0, 0, 0, 0.2); }
  
  .modal-btn { padding: 6px 16px; font-size: 10px; font-weight: 700; border-radius: 4px; cursor: pointer; border: none; }
  .modal-btn.cancel { background: transparent; color: rgba(255, 255, 255, 0.4); }
  .modal-btn.confirm { background: var(--accent-color); color: #000; }

  .retry-btn { margin-top: 10px; background: rgba(255, 255, 255, 0.1); border: 1px solid rgba(255, 255, 255, 0.1); color: #fff; padding: 4px 12px; border-radius: 4px; cursor: pointer; font-size: 10px; }
  
  .close-lite { background: transparent; border: none; color: rgba(255, 255, 255, 0.3); cursor: pointer; display: flex; align-items: center; }
  .close-lite:hover { color: #fff; }

  .pie-placeholder { width: 10px; height: 10px; border-radius: 50%; border: 1px solid currentColor; opacity: 0.3; }
</style>
