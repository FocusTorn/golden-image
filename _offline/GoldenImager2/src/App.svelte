<script lang="ts">
  import { settings, accentRgb } from './lib/store';
  import { invoke } from '@tauri-apps/api/tauri';
  import Sidebar from './lib/Sidebar.svelte';
  import Header from './lib/Header.svelte';
  import Dashboard from './lib/Dashboard.svelte';
  import Apps from './lib/Apps.svelte';
  import Tweaks from './lib/Tweaks.svelte';
  import Provisioning from './lib/Provisioning.svelte';
  import Settings from './lib/Settings.svelte';
  import StatusBar from './lib/StatusBar.svelte';
  import ToastStack from './lib/ToastStack.svelte';

  let activeTab = 'apps';
  let isDark = true;
  let appCount = 0;
  let hasLoggedGeometry = false;
  
  let containerRef: HTMLElement;
  let listRef: HTMLElement;

  /* GEOMETRY PROBE LOGIC (Logs once per app pane load) */
  $: if (activeTab === 'apps' && containerRef && listRef && !hasLoggedGeometry) {
    const cTop = containerRef.getBoundingClientRect().top;
    const lTop = listRef.getBoundingClientRect().top;
    invoke('log_geometry', { container: cTop, scroll: lTop, data: lTop });
    hasLoggedGeometry = true;
  }
  $: if (activeTab !== 'apps') {
    hasLoggedGeometry = false; // Reset for next time the tab is opened
  }
  let tweakAppliedCount = 0;
  let tweakTotalCount = 0;
  
  const isTauri = (window as any).__TAURI_METADATA__ !== undefined;
</script>

<main 
  class="app-container" 
  class:mock-window={!isTauri}
  style="--accent-color: {$settings.accentColor}; --accent-rgb: {$accentRgb}; --glass-opacity: {$settings.glassOpacity / 100};"
>
  <div class="app-frame">
    <!-- Full-Width Title Bar -->
    <Header />
    
    <!-- Top Global Divider -->
    <div class="h-divider top">
      <div class="h-edge"></div>
      <div class="h-core"></div>
      <div class="h-edge"></div>
    </div>

    <!-- Middle Layout: Sidebar + Content -->
    <div class="middle-body">
      <Sidebar bind:activeTab />
      
      <!-- Vertical Divider -->
      <div class="v-divider">
        <div class="v-edge"></div>
        <div class="v-core"></div>
        <div class="v-edge"></div>
      </div>

    <div class="content-area">
        {#if activeTab === 'dashboard'}
          <Dashboard />
        {:else if activeTab === 'apps'}
          <Apps bind:appCount bind:containerRef bind:listRef />
        {:else if activeTab === 'tweaks'}
          <Tweaks bind:appliedCount={tweakAppliedCount} bind:totalCount={tweakTotalCount} />
        {:else if activeTab === 'provisioning'}
          <Provisioning />
        {:else if activeTab === 'settings'}
          <Settings />
        {:else}
          <div class="placeholder">
            <h1>{activeTab.charAt(0).toUpperCase() + activeTab.slice(1)}</h1>
            <p>Coming soon...</p>
          </div>
        {/if}
      </div>
    </div>

    <!-- Bottom Global Divider -->
    <div class="h-divider bottom">
      <div class="h-edge"></div>
      <div class="h-core"></div>
      <div class="h-edge"></div>
    </div>

    <!-- Full-Width Status Bar -->
    <StatusBar 
      {activeTab}
      {appCount} 
      {tweakAppliedCount} 
      {tweakTotalCount} 
    />
    
    <!-- Global Notifications -->
    <ToastStack />
  </div>
</main>

<style>
  :global(*) { box-sizing: border-box; }

  .app-container {
    width: 100vw;
    height: 100vh;
    background: var(--bg-main);
    color: var(--text-main);
    display: flex;
    overflow: hidden;
  }

  .app-container.mock-window {
    background: #050708;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  /* Main frame using column layout to place Sidebar BELOW Title/Status */
  .app-frame {
    display: flex;
    flex-direction: column;
    width: 100%;
    height: 100%;
    background: var(--bg-main);
    position: relative;
    overflow: hidden;
  }

  .mock-window .app-frame {
    width: 1100px;
    height: 720px;
    border: 1px solid rgba(255, 255, 255, 0.08); 
    border-radius: 8px;
    box-shadow: 
      0 32px 64px rgba(0, 0, 0, 0.8),
      0 0 0 1px rgba(var(--accent-rgb), 0.15);
  }

  /* Middle Body using row layout for Sidebar/Content */
  .middle-body {
    flex: 1;
    display: flex;
    flex-direction: row;
    overflow: hidden;
    position: relative;
    z-index: 10; /* Sidebar sits below header/divider */
  }

  .content-area {
    flex: 1;
    overflow: hidden;
    position: relative;
    background: var(--grad-main);
  }

  /* Vertical Divider Styling */
  .v-divider {
    width: 4px;
    height: 100%;
    display: flex;
    flex-direction: row;
    flex-shrink: 0;
  }

  .v-edge {
    width: 1px;
    height: 100%;
    background: #0d1214;
  }

  .v-core {
    width: 2px;
    height: 100%;
    /* Offset colors (2c3233 -> 1d2325) to prevent meshing with #12181a panels */
    background: linear-gradient(180deg, #2c3233 0%, #1d2325 100%);
  }

  /* Horizontal Divider Styling */
  .h-divider {
    height: 4px;
    width: 100%;
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
    z-index: 50;
  }

  .h-edge { height: 1px; width: 100%; background: #0d1214; }
  .h-core { 
    height: 2px; 
    width: 100%; 
  }

  .h-divider.top .h-core {
    background: #2c3233; /* Matches top of vertical divider */
  }

  .h-divider.bottom .h-core {
    background: #1d2325; /* Matches bottom of vertical divider */
  }

  .placeholder {
    padding: 60px;
    text-align: center;
    opacity: 0.3;
  }

  :global(.spin) {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
</style>
