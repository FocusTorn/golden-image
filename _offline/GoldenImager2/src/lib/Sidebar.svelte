<script lang="ts">
  import { LayoutDashboard, Drill, Package, Settings } from 'lucide-svelte';
  export let activeTab: string;
</script>

<aside class="sidebar" data-tauri-drag-region>
  <button class:active={activeTab === 'dashboard'} on:click={() => activeTab = 'dashboard'} title="Dashboard">
    <LayoutDashboard size={24} />
  </button>
  <button class:active={activeTab === 'tweaks'} on:click={() => activeTab = 'tweaks'} title="Tweaks">
    <Drill size={24} />
  </button>
  <button class:active={activeTab === 'apps'} on:click={() => activeTab = 'apps'} title="Apps">
    <Package size={24} />
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
    padding: 12px;
    cursor: pointer;
    border-radius: 8px;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
  }

  button:hover {
    background: rgba(100, 149, 237, 0.08);
    color: #fff;
  }

  button.active {
    color: rgb(var(--accent-rgb));
    background: rgba(var(--accent-rgb), 0.1);
  }

  button.active::before {
    content: '';
    position: absolute;
    left: 0;
    top: 25%;
    height: 50%;
    width: 3px;
    background: var(--accent-color);
    border-radius: 0 4px 4px 0;
    box-shadow: 0 0 10px var(--accent-color);
  }

  .spacer {
    flex-grow: 1;
  }
</style>
