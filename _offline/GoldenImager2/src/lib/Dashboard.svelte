<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/tauri';

  const isTauri = window.__TAURI_METADATA__ !== undefined;

  let auditResults: any[] = [];
  let loading = true;

  onMount(async () => {
    try {
      if (isTauri) {
        auditResults = await invoke('get_audit_results');
      } else {
        // Mock results for Browser development
        auditResults = [
          { status: 'Applied' }, { status: 'Applied' }, { status: 'Not Applied' }
        ];
      }
    } catch (e) {
      console.error(e);
    } finally {
      loading = false;
    }
  });

  $: appliedCount = auditResults.filter(r => r.status === 'Applied').length;
  $: totalCount = auditResults.length;
  $: percent = totalCount > 0 ? Math.round((appliedCount / totalCount) * 100) : 0;
</script>

<div class="panel">
  <h1>Dashboard</h1>
  
  <div class="grid">
    <div class="card main-health">
      <div class="progress-circle" style="--p:{percent}">
        <div class="inner">
          <span class="value">{percent}%</span>
          <span class="label">Optimized</span>
        </div>
      </div>
      <div class="stats">
        <p><strong>{appliedCount}</strong> / {totalCount} Tweaks Applied</p>
      </div>
    </div>

    <div class="card info">
      <h3>System Information</h3>
      <div class="info-row"><span>OS:</span> <span>Windows 11 Pro</span></div>
      <div class="info-row"><span>Build:</span> <span>22631</span></div>
      <div class="info-row"><span>Mode:</span> <span class="badge">Audit Mode</span></div>
    </div>
  </div>
</div>

<style>
  .panel { padding: 40px; }
  h1 { margin-bottom: 30px; font-weight: 700; }

  .grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 24px;
  }

  .card {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 16px;
    padding: 24px;
  }

  .main-health {
    display: flex;
    align-items: center;
    gap: 40px;
  }

  .progress-circle {
    width: 150px;
    height: 150px;
    border-radius: 50%;
    background: conic-gradient(#00b4ff calc(var(--p) * 1%), rgba(255,255,255,0.05) 0);
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
  }

  .progress-circle::before {
    content: "";
    position: absolute;
    inset: 12px;
    background: #0f0f0f;
    border-radius: 50%;
  }

  .inner {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  .value { font-size: 32px; font-weight: 800; }
  .label { font-size: 12px; color: rgba(255, 255, 255, 0.5); }

  .info-row {
    display: flex;
    justify-content: space-between;
    padding: 12px 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  }

  .badge {
    background: rgba(0, 180, 255, 0.2);
    color: #00b4ff;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 12px;
  }
</style>
