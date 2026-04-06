<script lang="ts">
  import { ShieldCheck, Info, Clock } from 'lucide-svelte';
  interface Props {
    status?: string;
    activeTab?: string;
    appCount?: number;
    tweakAppliedCount?: number;
    tweakTotalCount?: number;
  }

  let {
    status = "Ready",
    activeTab = "apps",
    appCount = 0,
    tweakAppliedCount = 0,
    tweakTotalCount = 0
  }: Props = $props();
</script>

<footer class="status-bar">
  <div class="left">
    <ShieldCheck size={12} class="icon-pulse" />
    <span>{status}</span>
  </div>
  <div class="right">
    {#if activeTab === 'apps'}
      <Info size={12} />
      <span>{appCount} Apps Detected</span>
    {:else if activeTab === 'tweaks'}
      <Clock size={12} class="dim" />
      <span>{tweakAppliedCount} / {tweakTotalCount} Tweaks Applied</span>
    {:else}
      <Info size={12} />
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

  :global(.icon-pulse) {
    color: rgb(var(--accent-rgb));
    opacity: 0.8;
  }

  @keyframes pulse {
    0% { opacity: 0.4; }
    50% { opacity: 0.8; }
    100% { opacity: 0.4; }
  }
</style>
