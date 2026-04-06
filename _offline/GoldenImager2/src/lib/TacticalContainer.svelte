<script lang="ts">
  interface Props {
    showHeaderGrad?: boolean;
    showFooterGrad?: boolean;
    padding?: string;
    children?: import('svelte').Snippet;
  }

  let {
    showHeaderGrad = true,
    showFooterGrad = true,
    padding = "0 6px",
    children
  }: Props = $props();
</script>

<div class="tactical-container" style="--tact-padding: {padding}">
  {#if showHeaderGrad}
    <div class="tray-shadow shadow-top"></div>
  {/if}
  
  <div class="scroll-wrapper">
    {@render children?.()}
  </div>

  {#if showFooterGrad}
    <div class="tray-shadow shadow-bottom"></div>
  {/if}
</div>

<style>
  .tactical-container {
    flex: 1;
    display: flex;
    flex-direction: column;
    background: rgba(0, 0, 0, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-bottom: none; /* Flush with industrial floor */
    border-radius: 12px 12px 0 0;
    overflow: hidden;
    position: relative;
    padding: var(--tact-padding);
    z-index: 10;
    box-shadow:
      inset 0 0 0 1px #12181a,
      inset 0 24px 24px -12px rgba(0, 0, 0, 0.48); /* Primary industrial tray shadow */
  }

  .scroll-wrapper {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow-y: auto;
    overflow-x: hidden;
    position: relative;
    z-index: 5;
  }

  .tray-shadow {
    position: absolute;
    left: 0;
    right: 0;
    z-index: 15;
    pointer-events: none;
  }

  .shadow-top {
    top: 0;
    background: linear-gradient(
      to bottom,
      rgba(0, 0, 0, 0.48) 0%,
      rgba(18, 24, 26, 0) 100%
    );
    height: 32px;
  }

  .shadow-bottom {
    bottom: 0;
    background: linear-gradient(
      to top,
      rgba(0, 0, 0, 0.4) 0%,
      rgba(18, 24, 26, 0) 100%
    );
    height: 16px;
  }

  /* UNIFIED STEALTH SCROLLBAR */
  :global(.tactical-container ::-webkit-scrollbar) {
    width: 4px;
    height: 4px;
  }

  :global(.tactical-container ::-webkit-scrollbar-track) {
    background: transparent;
  }

  :global(.tactical-container ::-webkit-scrollbar-thumb) {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 4px;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  }

  :global(.tactical-container ::-webkit-scrollbar-thumb:hover) {
    background: rgba(var(--accent-rgb), 0.3);
  }

  :global(.tactical-container ::-webkit-scrollbar-corner) {
    background: transparent;
  }
</style>
