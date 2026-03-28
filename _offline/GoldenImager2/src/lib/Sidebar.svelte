<script lang="ts">
  import { Home, Cog, LayoutList, Settings } from 'lucide-svelte';
  export let activeTab: string;
</script>

<aside class="sidebar" data-tauri-drag-region>
  <button class:active={activeTab === 'dashboard'} on:click={() => activeTab = 'dashboard'} title="Dashboard">
    <Home size={24} />
  </button>
  <button class:active={activeTab === 'tweaks'} on:click={() => activeTab = 'tweaks'} title="Tweaks">
    <Cog size={24} />
  </button>
  <button class:active={activeTab === 'apps'} on:click={() => activeTab = 'apps'} title="Apps">
    <LayoutList size={24} />
  </button>
  <div class="spacer"></div>
  <button class:active={activeTab === 'settings'} on:click={() => activeTab = 'settings'} title="Settings">
    <Settings size={24} />
  </button>
</aside>

<style>
  .sidebar {
    width: 64px;
    height: 100%;
    background: var(--grad-panel);
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 16px 0;
    gap: 16px;
    z-index: 10;
  }

  button {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.35);
    padding: 12px 0;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
    width: 100%;
    margin: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    outline: none;
  }

  button:hover {
    color: #fff;
  }

  button.active {
    color: rgb(var(--accent-rgb));
  }

  button.active::before {
    content: '';
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 60px;
    background: rgba(18, 24, 26, 0.95);
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-left: none;
    border-radius: 0 8px 8px 0;
    box-shadow: 
      inset 0 0 0 1px #12181a,
      inset 0 2px 8px rgba(0, 0, 0, 0.4);
    z-index: -1;
  }

  .spacer {
    flex-grow: 1;
  }
</style>
