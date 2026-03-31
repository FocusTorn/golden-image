<script lang="ts">
  import { ShieldCheck, Info } from 'lucide-svelte';
  export let status = "Ready";
  export let activeTab = "apps";
  export let appCount = 0;
  export let tweakAppliedCount = 0;
  export let tweakTotalCount = 0;
</script>

<footer class="status-bar">
  <div class="left">
    <ShieldCheck size={12} class="icon-pulse" />
    <span>GoldenImager2 // {status}</span>
  </div>
  <div class="right">
    <Info size={12} />
    {#if activeTab === 'apps'}
      <span>{appCount} Apps Detected</span>
    {:else if activeTab === 'tweaks'}
      <span>{tweakAppliedCount} / {tweakTotalCount} Tweaks Applied</span>
    {:else}
      <span>System Optimization Hub</span>
    {/if}
  </div>
</footer>

<style>
  .status-bar {
    height: 22px;
    background: #12181A; /* Synced with Sidebar/Content floor luminance */
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 16px;
    font-size: 10px;
    color: rgba(255, 255, 255, 0.4);
    font-family: 'Inter', sans-serif;
    letter-spacing: 0.3px;
    user-select: none;
    flex-shrink: 0;
  }

  .left, .right {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .icon-pulse {
    color: rgb(var(--accent-rgb));
    opacity: 0.8;
  }

  @keyframes pulse {
    0% { opacity: 0.4; }
    50% { opacity: 0.8; }
    100% { opacity: 0.4; }
  }
</style>
