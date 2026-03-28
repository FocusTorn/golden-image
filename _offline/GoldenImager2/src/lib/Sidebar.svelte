<script lang="ts">
  import { Home, Cog, LayoutList, Settings } from 'lucide-svelte';
  export let activeTab: string;
</script>

<aside class="sidebar" data-tauri-drag-region>
  <button class:active={activeTab === 'dashboard'} on:click={() => activeTab = 'dashboard'} title="Dashboard">
    <span class="icon-wrapper">
      <Home size={24} color={activeTab === 'dashboard' ? 'var(--accent-color)' : 'currentColor'} />
    </span>
  </button>
  <button class:active={activeTab === 'tweaks'} on:click={() => activeTab = 'tweaks'} title="Tweaks">
    <span class="icon-wrapper">
      <Cog size={24} color={activeTab === 'tweaks' ? 'var(--accent-color)' : 'currentColor'} />
    </span>
  </button>
  <button class:active={activeTab === 'apps'} on:click={() => activeTab = 'apps'} title="Apps">
    <span class="icon-wrapper">
      <LayoutList size={24} color={activeTab === 'apps' ? 'var(--accent-color)' : 'currentColor'} />
    </span>
  </button>
  <div class="spacer"></div>
  <button class:active={activeTab === 'settings'} on:click={() => activeTab = 'settings'} title="Settings">
    <span class="icon-wrapper">
      <Settings size={24} color={activeTab === 'settings' ? 'var(--accent-color)' : 'currentColor'} />
    </span>
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
    transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
    width: 100%;
    margin: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    outline: none;
  }

  .icon-wrapper {
    position: relative;
    z-index: 5;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  button:hover {
    color: #fff;
    background: transparent;
  }

  button.active {
    color: var(--accent-color);
    background: transparent;
    border: none;
    box-shadow: none;
  }

  button.active::before {
    content: '';
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 100%; /* All the way to edge */
    background: rgba(18, 24, 26, 0.95);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-left: none; /* No left border */
    border-radius: 0 8px 8px 0;
    box-shadow: 
      inset 0 0 0 1px #12181a,
      inset 0 2px 20px rgba(0, 0, 0, 0.6);
    z-index: -1;
  }

  .spacer {
    flex-grow: 1;
  }
</style>
