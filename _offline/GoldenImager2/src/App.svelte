<script lang="ts">
  import { settings, accentRgb } from './lib/store';
  import { invoke } from '@tauri-apps/api/tauri';
  import { listen } from '@tauri-apps/api/event';
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

  import { onMount } from 'svelte';
  
  let activeTab = $state('dashboard');
  let isDark = $state(true);
  let appCount = $state(0);
  let tweakAppliedCount = $state(0);
  let tweakTotalCount = $state(0);
  let hasLoggedGeometry = $state(false);
  
  let containerRef: HTMLElement | null = $state(null);
  let listRef: HTMLElement | null = $state(null);
  
  const isTauri = (window as any).__TAURI_METADATA__ !== undefined;

  onMount(() => {
    const setup = async () => {
      try {
        const config = await invoke("get_master_config");
        if (config && (config as any).defaultInitialView) {
          activeTab = (config as any).defaultInitialView.toLowerCase();
        }
      } catch (e) {
        console.error("Failed to load startup view", e);
      }

      let isTransitioning = false;

      // Initial Geometry Restore (Clamped)
      if ($settings.retainWindowState) {
        const finalW = Math.min($settings.windowWidth, window.screen.availWidth);
        const finalH = Math.min($settings.windowHeight, window.screen.availHeight);
        
        invoke('set_window_size', { 
          width: finalW - 47, 
          height: finalH - 62 
        });
        invoke('set_window_position', { 
          x: $settings.windowX, 
          y: $settings.windowY 
        });
      }

      const unlistenResize = await listen('window-resized', (event: any) => {
        if (isTransitioning) return;
        const [w, h] = event.payload;
        if (!$settings.retainWindowState) {
          settings.update(s => ({ ...s, retainWindowState: true }));
        }
        
        // Dynamic Clamping to Work Area
        const finalW = Math.min(w + 47, window.screen.availWidth);
        const finalH = Math.min(h + 62, window.screen.availHeight);
        
        settings.update(s => ({ ...s, windowWidth: finalW, windowHeight: finalH }));
      });

      const unlistenMove = await listen('window-moved', (event: any) => {
        if (isTransitioning) return;
        const [x, y] = event.payload;
        if (!$settings.retainWindowState) {
          settings.update(s => ({ ...s, retainWindowState: true }));
        }
        settings.update(s => ({ ...s, windowX: x, windowY: y }));
      });

      const unlistenManual = await listen('manual-resize-start', () => {
        isTransitioning = true;
        setTimeout(() => isTransitioning = false, 1000);
      });

      return () => {
        if (typeof unlistenResize === 'function') unlistenResize();
        if (typeof unlistenMove === 'function') unlistenMove();
        if (typeof unlistenManual === 'function') unlistenManual();
      };
    };

    const cleanupPromise = setup();

    return () => {
      cleanupPromise.then(cleanup => cleanup && cleanup());
    };
  });

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


</script>

<main 
  class="app-container" 
  class:isTauri
  style="--accent-rgb: {$accentRgb}; --accent-color: rgb({$accentRgb});"
>
  <Sidebar bind:activeTab />

  <div class="content-area">
    <Header {activeTab} />
    
    <div class="view-wrapper">
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

    <StatusBar {activeTab} {appCount} {tweakAppliedCount} {tweakTotalCount} />
  </div>

  <ToastStack />
</main>

<style>
  :global(:root) {
    --accent-rgb: 0, 188, 212;
    --accent-color: rgb(var(--accent-rgb));
    --bg-main: #0b0f10;
    --bg-darker: #050708;
    --grad-main: radial-gradient(circle at 50% 0%, #1a2225 0%, #0b0f10 100%);
    --grad-panel: linear-gradient(180deg, #12181a 0%, #0b0f10 100%);
    --risk-safe: #4caf50;
    --risk-warn: #ffeb3b;
    --risk-unsafe: #ff1744;
    --risk-user: #00bcd4;
    
    /* MODULAR SLAB SYSTEM (v7) */
    --slab-base: #14181B;    /* Deep Machine Grey */
    --slab-edge: #0E1113;    /* Bevel Shadow */
    --slab-rim: #3A3E42;     /* Milled Silver Catch */
    --slab-patina: #1A1D20;  /* Oxidation Cloud */
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
    background: var(--bg-main);
    overflow: hidden;
  }

  .content-area {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    position: relative;
  }

  .view-wrapper {
    flex: 1;
    overflow: hidden;
    position: relative;
    background: rgba(0, 0, 0, 0.2);
  }

  /* High-Performance Transitions */
  .view-wrapper > :global(*) {
    width: 100%;
    height: 100%;
  }

  :global(.spin) {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  :global(.truncate) {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
