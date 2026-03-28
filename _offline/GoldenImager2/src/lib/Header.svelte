<script lang="ts">
  import { invoke } from '@tauri-apps/api/tauri';
  import { Minus, X } from 'lucide-svelte';

  const minimize = () => invoke('minimize_window');
  const close = () => invoke('close_window');
</script>

<header class="header" data-tauri-drag-region>
  <div class="title" data-tauri-drag-region>GoldenImager2</div>
  <div class="controls">
    <button class="control-btn" on:click={minimize} title="Minimize">
      <Minus size={14} />
    </button>
    <button class="control-btn close" on:click={close} title="Close">
      <X size={14} />
    </button>
  </div>
</header>

<style>
  .header {
    height: 32px;
    background: rgba(0, 0, 0, 0.4);
    backdrop-filter: blur(10px);
    border-bottom: 1px solid rgba(255,255,255,0.05);
    display: flex;
    align-items: center;
    padding: 0 16px;
    z-index: 100;
    justify-content: space-between;
    user-select: none;
    cursor: default;
    width: 100%;
    flex-shrink: 0;
  }

  .title {
    font-size: 11px;
    font-weight: 700;
    color: var(--text-color);
    opacity: 0.6;
    letter-spacing: 0.5px;
    text-transform: uppercase;
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
    opacity: 1;
    background: rgba(255, 255, 255, 0.05);
  }

  .control-btn.close:hover {
    background: #e81123;
    color: white;
  }
</style>
