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
  import Orchestrator from './lib/Orchestrator.svelte';
  import StatusBar from './lib/StatusBar.svelte';
  import ToastStack from './lib/ToastStack.svelte';

  let activeTab = $state<string>('dashboard');
  let appCount = $state<number>(0);
  let hasLoggedGeometry = $state<boolean>(false);
  
  let containerRef = $state<HTMLElement | null>(null);
  let listRef = $state<HTMLElement | null>(null);

  /* GEOMETRY PROBE LOGIC (Logs once per app pane load) */
  $effect(() => {
    if (activeTab === 'apps' && containerRef && listRef && !hasLoggedGeometry) {
      const cTop = containerRef.getBoundingClientRect().top;
      const lTop = listRef.getBoundingClientRect().top;
      invoke('log_geometry', { container: cTop, scroll: lTop, data: lTop });
      hasLoggedGeometry = true;
    }
  });

  $effect(() => {
    if (activeTab !== 'apps') {
      hasLoggedGeometry = false; // Reset for next time the tab is opened
    }
  });

  /* TAB SAFETY LOGIC: Ensure activeTab is available for selected environment */
  $effect(() => {
    if (activeTab === 'provisioning' && $settings.environmentTarget !== 'VHD & VM') {
      activeTab = 'dashboard';
    }
  });

  $effect(() => {
    if (activeTab === 'orchestrator' && $settings.environmentTarget !== 'Local Image') {
      activeTab = 'dashboard';
    }
  });

  let tweakAppliedCount = $state<number>(0);
  let tweakTotalCount = $state<number>(0);
  
  const isTauri = (window as any).__TAURI_METADATA__ !== undefined;
</script>

<main 
  class="app-container" 
  class:isTauri
  style="--accent-rgb: {$accentRgb}; --accent-color: rgb({$accentRgb});"
>
  <div class="app-frame">
    <!-- Full-Width Title Bar -->
    <Header activeTab={activeTab} />
    
    <!-- Top Global Divider (THE PIPE) -->
    <div class="h-divider top">
      <div class="h-edge"></div>
      <div class="h-core"></div>
      <div class="h-edge"></div>
    </div>

    <!-- Middle Layout: Sidebar + Content -->
    <div class="middle-body">
      <Sidebar bind:activeTab />
      
      <!-- Vertical Divider (THE PIPE) -->
      <div class="v-divider">
        <div class="v-edge"></div>
        <div class="v-core"></div>
        <div class="v-edge"></div>
      </div>

      <div class="content-area">
        {#if activeTab === 'dashboard'}
          <Dashboard />
        {:else if activeTab === 'provisioning'}
          <Provisioning />
        {:else if activeTab === 'orchestrator'}
          <Orchestrator />
        {:else if activeTab === 'apps'}
          <Apps bind:appCount bind:containerRef bind:listRef />
        {:else if activeTab === 'tweaks'}
          <Tweaks 
            bind:appliedCount={tweakAppliedCount} 
            bind:totalCount={tweakTotalCount} 
          />
        {:else if activeTab === 'settings'}
          <Settings />
        {/if}
      </div>
    </div>

    <!-- Bottom Global Divider (THE PIPE) -->
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

    <ToastStack />
  </div>
</main>

<style>
  :global(:root) {
    --accent-rgb: 0, 188, 212;
    --accent-color: rgb(var(--accent-rgb));
    --bg-main: #0b0f10;
    --bg-darker: #050708;
    --grad-main: #0b0f10; /* Solid dark base to match original reference */
    --grad-panel: linear-gradient(180deg, #1e2327 0%, #0b0f10 100%);
    --risk-safe: #4caf50;
    --risk-warn: #ffeb3b;
    --risk-unsafe: #ff1744;
    --risk-user: #00bcd4;
    
    /* MODULAR SLAB SYSTEM (v7) */
    --slab-base: #14181B;    /* Deep Machine Grey */
    --slab-edge: #0E1113;    /* Bevel Shadow */
    --slab-rim: #3A3E42;     /* Milled Silver Catch */
    --slab-patina: #1A1D20;  /* Oxidation Cloud */

    /* PIPE TOKENS */
    --divider-core: #2a3133; 
    --divider-edge: rgba(0, 0, 0, 0.15); /* Softened to remove "cut" effect */
  }

  :global(body) {
    margin: 0;
    padding: 0;
    background: var(--bg-main);
    color: #fff;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    overflow: hidden;
    user-select: none;
  }

  .app-container {
    width: 100vw;
    height: 100vh;
    display: flex;
    overflow: hidden;
  }

  .app-frame {
    display: flex;
    flex-direction: column;
    width: 100%;
    height: 100%;
    background: var(--bg-main);
    position: relative;
    overflow: hidden;
  }

  .middle-body {
    flex: 1;
    display: flex;
    flex-direction: row;
    overflow: hidden;
    position: relative;
    z-index: 10;
  }

  .content-area {
    flex: 1;
    overflow: hidden;
    position: relative;
    background: transparent;
    display: flex;
    flex-direction: column;
    padding: 10px 10px 0 10px;
  }

  /* Vertical Divider (The Pipe) */
  .v-divider {
    width: 4px;
    height: 100%;
    display: flex;
    flex-direction: row;
    flex-shrink: 0;
    z-index: 20;
  }

  .v-edge {
    width: 1px;
    height: 100%;
    background: var(--divider-edge);
  }

  .v-core {
    width: 2px;
    height: 100%;
    background: linear-gradient(180deg, var(--divider-core) 0%, var(--divider-edge) 100%);
  }

  /* Horizontal Divider (The Pipe) */
  .h-divider {
    height: 4px;
    width: 100%;
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
    z-index: 50;
  }

  .h-edge { 
    height: 1px; 
    width: 100%; 
    background: var(--divider-edge); 
  }

  .h-core { 
    height: 2px; 
    width: 100%; 
  }

  .h-divider.top .h-core {
    background: var(--divider-core);
  }

  .h-divider.bottom .h-core {
    background: var(--divider-core);
  }
</style>
