<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/tauri';
  import Sidebar from './lib/Sidebar.svelte';
  import Header from './lib/Header.svelte';
  import Dashboard from './lib/Dashboard.svelte';
  import Apps from './lib/Apps.svelte';
  import Tweaks from './lib/Tweaks.svelte';
  import StatusBar from './lib/StatusBar.svelte';

  let activeTab = 'apps';
  let r = 74, g = 199, b = 192; // #4AC7C0 (Brighter teal)
  let isDark = true;
  let appCount = 0;

  onMount(async () => {
    /* OS Color Pull - Preserved but Disabled as per request
    try {
      if ((window as any).__TAURI_METADATA__) {
        const themeInfo: any = await invoke('get_theme_info');
        r = themeInfo.R;
        g = themeInfo.G;
        b = themeInfo.B;
        isDark = themeInfo.IsDark;
      }
    } catch (e) {
      console.error("Failed to get system theme:", e);
    }
    */
  });

  $: accentRgb = `${r}, ${g}, ${b}`;
</script>

<div class="app-root" style="--accent-rgb: {accentRgb}; --is-dark: {isDark ? 1 : 0}">
  <Header />
  
  <div class="h-divider">
    <div class="h-edge"></div>
    <div class="h-core"></div>
    <div class="h-edge"></div>
  </div>

  <div class="app-body">
    <Sidebar bind:activeTab />
    
    <div class="v-divider">
      <div class="v-edge"></div>
      <div class="v-core"></div>
      <div class="v-edge"></div>
    </div>

    <main class="page-container">
      {#if activeTab === 'dashboard'}
        <Dashboard />
      {:else if activeTab === 'apps'}
        <Apps bind:appCount />
      {:else if activeTab === 'tweaks'}
        <Tweaks />
      {:else if activeTab === 'settings'}
        <div class="placeholder">
          <h1>Settings</h1>
          <p>Global system preferences coming soon.</p>
        </div>
      {:else}
        <div class="placeholder">
          <h1>{activeTab.charAt(0).toUpperCase() + activeTab.slice(1)}</h1>
          <p>This panel is coming soon.</p>
        </div>
      {/if}
    </main>
  </div>

  <StatusBar {appCount} />
</div>

<style>
  :global(*) { box-sizing: border-box; }

  .app-root {
    width: 100vw;
    height: 100vh;
    background: var(--grad-main);
    color: var(--text-main);
    overflow: hidden;
    position: relative;
    display: flex;
    flex-direction: column;
    border: 1px solid var(--border-muted);
    box-sizing: border-box;
    box-shadow: none !important;
    filter: none !important;
  }

  .app-body {
    flex: 1;
    display: flex;
    flex-direction: row;
    overflow: hidden;
  }

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
    background: linear-gradient(180deg, #0d1214 0%, #0d1214 66%, #050809 100%);
  }

  .v-core {
    width: 2px;
    height: 100%;
    background: linear-gradient(180deg, #2c3233 0%, #2c3233 66%, #1e2223 100%);
  }

  /* Horizontal Divider */
  .h-divider {
    height: 4px;
    width: 100%;
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
    box-shadow: none !important;
    filter: none !important;
    position: relative;
    z-index: 50;
  }

  .h-edge {
    height: 1px;
    width: 100%;
    background: #0d1214; /* Charcoal edge line */
  }

  .h-core {
    height: 2px;
    width: 100%;
    background: #2c3233; /* Slate core line */
  }

  .page-container {
    flex: 1;
    height: 100%;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    background: var(--grad-main);
  }

  .placeholder {
    padding: 40px;
    text-align: center;
    color: var(--text-color);
    opacity: 0.5;
  }

  /* Custom Scrollbar */
  .page-container::-webkit-scrollbar {
    width: 6px;
  }
  .page-container::-webkit-scrollbar-track {
    background: transparent;
  }
  .page-container::-webkit-scrollbar-thumb {
    background: var(--border-color);
    border-radius: 3px;
  }
  .page-container::-webkit-scrollbar-thumb:hover {
    background: var(--accent-color);
  }
</style>
