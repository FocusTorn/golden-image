<script lang="ts">
  import { notificationStore } from './notifications';
  import { slide, fade } from 'svelte/transition';
  import { AlertCircle, CheckCircle, Info, XCircle, X } from 'lucide-svelte';

  const typeIcons: Record<string, any> = {
    'info': Info,
    'success': CheckCircle,
    'warning': AlertCircle,
    'error': XCircle
  };

  const typeColors: Record<string, string> = {
    'info': 'var(--accent-rgb)',
    'success': '129, 199, 132',
    'warning': '255, 183, 77',
    'error': '229, 115, 115'
  };
</script>

<div class="toast-stack">
  {#each $notificationStore as n (n.id)}
    {@const SvelteComponent = typeIcons[n.type]}
    <div 
      class="toast {n.type}" 
      style="--type-rgb: {typeColors[n.type]}"
      in:slide={{ axis: 'y' }}
      out:fade={{ duration: 150 }}
    >
      <div class="toast-edge"></div>
      <div class="toast-content">
        <SvelteComponent size={18} class="toast-icon" />
        <span class="toast-message">{n.message}</span>
        <button class="toast-close" onclick={() => notificationStore.remove(n.id)}>
          <X size={14} />
        </button>
      </div>
    </div>
  {/each}
</div>

<style>
  .toast-stack {
    position: fixed;
    bottom: 48px; /* Above status bar */
    right: 24px;
    display: flex;
    flex-direction: column-reverse;
    gap: 8px;
    z-index: 9999;
    pointer-events: none;
  }

  .toast {
    pointer-events: auto;
    width: 320px;
    background: rgba(10, 15, 17, 0.95);
    backdrop-filter: blur(8px);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 4px;
    display: flex;
    box-shadow: 
      0 8px 16px rgba(0, 0, 0, 0.4),
      0 0 0 1px rgba(var(--type-rgb), 0.1);
    position: relative;
    overflow: hidden;
  }

  /* Industrial Accent Edge */
  .toast-edge {
    width: 3px;
    background: rgb(var(--type-rgb));
    box-shadow: 0 0 10px rgba(var(--type-rgb), 0.5);
  }

  .toast-content {
    flex: 1;
    padding: 12px 14px;
    display: flex;
    align-items: center;
    gap: 12px;
  }

  :global(.toast-icon) {
    color: rgb(var(--type-rgb));
    opacity: 0.8;
    flex-shrink: 0;
  }

  .toast-message {
    flex: 1;
    font-size: 13px;
    font-weight: 500;
    color: rgba(255, 255, 255, 0.9);
    line-height: 1.4;
    word-break: break-word;
  }

  .toast-close {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.2);
    cursor: pointer;
    padding: 4px;
    display: flex;
    transition: color 0.2s;
  }

  .toast-close:hover {
    color: rgba(255, 255, 255, 0.8);
  }
</style>
