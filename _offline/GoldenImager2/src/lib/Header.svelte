<script lang="ts">
  import { invoke } from '@tauri-apps/api/tauri';
  import { Minus, X } from 'lucide-svelte';

  interface Props {
    activeTab: string;
  }

  let { activeTab }: Props = $props();

  const minimize = () => invoke('minimize_window');
  const close = () => invoke('close_window');
</script>

<header class="header" data-tauri-drag-region>
  <div class="title" data-tauri-drag-region>
    <svg width="18" height="18" viewBox="0 0 100 100" fill="none" class="app-icon" data-tauri-drag-region xmlns="http://www.w3.org/2000/svg">
      <path d="M10 90 L50 65 L90 90 L90 75 L50 50 L10 75 Z" fill="#325D5A" data-tauri-drag-region />
      <path d="M10 65 L50 40 L90 65 L90 50 L50 25 L10 50 Z" fill="#62A17E" data-tauri-drag-region />
      <path d="M10 40 L50 15 L90 40 L90 25 L50 0 L10 25 Z" fill="#F2C45E" data-tauri-drag-region />
    </svg>
    Golden Imager 2
  </div>
  <div class="controls">
    <button class="control-btn" onclick={minimize} title="Minimize">
      <Minus size={14} />
    </button>
    <button class="control-btn close" onclick={close} title="Close">
      <X size={14} />
    </button>
  </div>
</header>

<style>
  .header {
    height: 36px;
    background: #1C2427; /* Matches sidebar top and panel background */
    backdrop-filter: blur(8px);
    display: flex;
    align-items: center;
    padding: 0 12px;
    z-index: 100;
    justify-content: space-between;
    user-select: none;
    cursor: default;
    width: 100%;
    flex-shrink: 0;
  }

  .title {
    display: flex;
    align-items: center;
    gap: 10px;
    font-size: 14px; /* Stronger branding presence */
    font-weight: 700;
    color: var(--text-color);
    opacity: 0.9; /* High-clarity branding */
    letter-spacing: 0.5px;
    text-transform: none;
  }

  .app-icon {
    width: 20px;
    height: 20px;
    filter: drop-shadow(0 2px 4px rgba(0,0,0,0.6));
    display: block;
  }

  .controls {
    display: flex;
    height: 100%;
  }

  .control-btn {
    width: 44px;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: transparent;
    border: none;
    color: var(--text-color);
    opacity: 0.5;
    cursor: pointer;
    transition: all 0.2s;
  }

  .control-btn:hover {
    background: rgba(255, 255, 255, 0.1);
    border-color: rgba(var(--accent-rgb), 0.5);
    box-shadow: 
      0 0 20px rgba(var(--accent-rgb), 0.3),
      0 0 4px rgba(var(--accent-rgb), 0.4);
    color: #fff;
  }

  .control-btn.close:hover {
    background: #e81123;
    color: white;
  }
</style>
