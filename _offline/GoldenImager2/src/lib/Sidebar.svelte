<script lang="ts">
  import { Home, Cog, LayoutList, Settings, Zap, Hammer } from 'lucide-svelte';
  import { settings } from './store';
  interface Props {
    activeTab: string;
  }

  let { activeTab = $bindable() }: Props = $props();
</script>

<aside class="sidebar" data-tauri-drag-region>
  <button class:active={activeTab === 'dashboard'} onclick={() => activeTab = 'dashboard'} title="Dashboard">
    <span class="icon-wrapper">
      <Home size={18} color={activeTab === 'dashboard' ? 'var(--accent-color)' : 'currentColor'} />
    </span>
  </button>
  <!-- DYNAMIC PIPELINE TAB -->
  {#if $settings.environmentTarget === 'VHD & VM'}
    <button class:active={activeTab === 'provisioning'} onclick={() => activeTab = 'provisioning'} title="Tactical Provisioning Engine">
      <span class="icon-wrapper">
        <Zap size={18} color={activeTab === 'provisioning' ? 'var(--accent-color)' : 'currentColor'} />
      </span>
    </button>
  {:else if $settings.environmentTarget === 'Local Image'}
    <button class:active={activeTab === 'orchestrator'} onclick={() => activeTab = 'orchestrator'} title="Image from Code">
      <span class="icon-wrapper">
        <Hammer size={18} color={activeTab === 'orchestrator' ? 'var(--accent-color)' : 'currentColor'} />
      </span>
    </button>
  {/if}

  <button class:active={activeTab === 'apps'} onclick={() => activeTab = 'apps'} title="Apps">
    <span class="icon-wrapper">
      <LayoutList size={18} color={activeTab === 'apps' ? 'var(--accent-color)' : 'currentColor'} />
    </span>
  </button>
  <button class:active={activeTab === 'tweaks'} onclick={() => activeTab = 'tweaks'} title="Tweaks">
    <span class="icon-wrapper">
      <Cog size={18} color={activeTab === 'tweaks' ? 'var(--accent-color)' : 'currentColor'} />
    </span>
  </button>
  <div class="spacer"></div>
  <button class:active={activeTab === 'settings'} onclick={() => activeTab = 'settings'} title="Settings">
    <span class="icon-wrapper">
      <Settings size={18} color={activeTab === 'settings' ? 'var(--accent-color)' : 'currentColor'} />
    </span>
  </button>
</aside>

<style>
  .sidebar {
    width: 48px;
    height: 100%;
    background: var(--grad-panel);
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 12px 0;
    gap: 12px;
    z-index: 10;
  }

  button {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.35);
    padding: 10px 0;
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
