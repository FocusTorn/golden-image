<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/tauri';
  import { Cog, Shield, ShieldAlert, Cpu, Lock, Eye, AlertTriangle, RefreshCw, Check, X } from 'lucide-svelte';

  const isTauri = window.__TAURI_METADATA__ !== undefined;

  let featuresConfig: any = null;
  let auditResults: any[] = [];
  let loading = true;
  let error: string | null = null;
  let activeCategory = 'Titus Essentials';
  let applyingFeature: string | null = null;

  async function loadData() {
    loading = true;
    error = null;
    try {
      if (isTauri) {
        featuresConfig = await invoke('get_features_config');
        auditResults = await invoke('get_audit_results');
      } else {
        // Mock data
        featuresConfig = {
          Categories: [
            { Name: 'Titus Essentials', Icon: '&#xE9E9;' },
            { Name: 'Titus Advanced', Icon: '&#xE7BA;' },
            { Name: 'System', Icon: '&#xE770;' }
          ],
          Features: [
            { FeatureId: 'DisableWPBT', Label: 'Disable WPBT', Category: 'Titus Essentials', ToolTip: '...', Action: 'Disable' },
            { FeatureId: 'BlockRazerSoftware', Label: 'Block Razer Software', Category: 'Titus Advanced', ToolTip: '...', Action: 'Block' }
          ]
        };
        auditResults = [
          { feature_id: 'DisableWPBT', status: 'Applied' },
          { feature_id: 'BlockRazerSoftware', status: 'Not Applied' }
        ];
      }
    } catch (e) {
      console.error("Failed to load tweaks:", e);
      error = typeof e === 'string' ? e : "Connection failed";
    } finally {
      loading = false;
    }
  }

  onMount(loadData);

  function getStatus(id: string) {
    const res = auditResults.find(r => r.feature_id === id);
    return res ? res.status : 'Unknown';
  }

  async function toggleFeature(feature: any) {
    const status = getStatus(feature.FeatureId);
    applyingFeature = feature.FeatureId;
    
    try {
      if (status === 'Applied') {
        if (feature.RegistryUndoKey) {
          await invoke('undo_feature', { feature_id: feature.FeatureId });
        } else {
          // If no undo key, maybe just re-apply? Or notify user.
          console.warn("No undo key for", feature.FeatureId);
        }
      } else {
        await invoke('apply_feature', { feature_id: feature.FeatureId });
      }
      
      // Refresh audit results
      if (isTauri) {
        auditResults = await invoke('get_audit_results');
      }
    } catch (e) {
      console.error("Action failed:", e);
      alert("Failed to update feature: " + e);
    } finally {
      applyingFeature = null;
    }
  }

  $: categories = featuresConfig?.Categories || [];
  $: features = (featuresConfig?.Features || []).filter(f => f.Category === activeCategory);
</script>

<div class="tweaks-panel">
  <div class="sidebar">
    {#each categories as cat}
      <button class="cat-btn" 
              class:active={activeCategory === cat.Name}
              on:click={() => activeCategory = cat.Name}>
        <span class="icon">{@html cat.Icon}</span>
        <span class="name">{cat.Name}</span>
      </button>
    {/each}
  </div>

  <div class="content">
    <div class="header">
      <Cog size={24} style="color: #4fc3f7;" />
      <h1>{activeCategory}</h1>
    </div>

    {#if loading}
      <div class="loading">
        <RefreshCw class="spin" />
        <span>Auditing system tweaks...</span>
      </div>
    {:else if error}
      <div class="error">
        <AlertTriangle size={48} />
        <p>{error}</p>
        <button on:click={loadData}>Retry</button>
      </div>
    {:else}
      <div class="features-grid">
        {#each features as feature}
          <div class="feature-card" class:applied={getStatus(feature.FeatureId) === 'Applied'}>
            <div class="info">
              <h3>{feature.Label}</h3>
              <p>{feature.ToolTip || 'No description available.'}</p>
            </div>
            
            <button class="action-btn" 
                    disabled={applyingFeature === feature.FeatureId}
                    class:applied={getStatus(feature.FeatureId) === 'Applied'}
                    on:click={() => toggleFeature(feature)}>
              {#if applyingFeature === feature.FeatureId}
                <RefreshCw size={18} class="spin" />
              {:else if getStatus(feature.FeatureId) === 'Applied'}
                <Check size={18} />
                <span>Applied</span>
              {:else}
                <X size={18} />
                <span>Not Applied</span>
              {/if}
            </button>
          </div>
        {/each}
      </div>
    {/if}
  </div>
</div>

<style>
  .tweaks-panel {
    display: flex;
    height: 100%;
    background: #0f0f0f;
  }

  .sidebar {
    width: 240px;
    background: rgba(255, 255, 255, 0.02);
    border-right: 1px solid rgba(255, 255, 255, 0.05);
    padding: 24px 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .cat-btn {
    display: flex;
    align-items: center;
    gap: 12px;
    background: transparent;
    border: none;
    padding: 12px 16px;
    border-radius: 10px;
    color: rgba(255, 255, 255, 0.5);
    cursor: pointer;
    text-align: left;
    transition: all 0.2s;
  }

  .cat-btn:hover {
    background: rgba(255, 255, 255, 0.05);
    color: #fff;
  }

  .cat-btn.active {
    background: rgba(79, 195, 247, 0.1);
    color: #4fc3f7;
  }

  .cat-btn .icon {
    font-family: "Segoe Fluent Icons", "Segoe MDL2 Assets";
    font-size: 18px;
  }

  .content {
    flex: 1;
    padding: 40px;
    overflow-y: auto;
  }

  .header {
    display: flex;
    align-items: center;
    gap: 16px;
    margin-bottom: 32px;
  }

  .header h1 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
  }

  .features-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
    gap: 20px;
  }

  .feature-card {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 16px;
    padding: 24px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    gap: 20px;
    transition: all 0.2s;
  }

  .feature-card:hover {
    border-color: rgba(255, 255, 255, 0.1);
    background: rgba(255, 255, 255, 0.05);
  }

  .feature-card.applied {
    border-color: rgba(76, 175, 80, 0.2);
    background: rgba(76, 175, 80, 0.02);
  }

  .info h3 {
    margin: 0 0 8px 0;
    font-size: 16px;
    color: rgba(255, 255, 255, 0.9);
  }

  .info p {
    margin: 0;
    font-size: 13px;
    color: rgba(255, 255, 255, 0.4);
    line-height: 1.5;
  }

  .action-btn {
    align-self: flex-start;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    border-radius: 20px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    border: 1px solid rgba(255, 255, 255, 0.1);
    background: rgba(255, 255, 255, 0.05);
    color: rgba(255, 255, 255, 0.6);
    transition: all 0.2s;
  }

  .action-btn:hover:not(:disabled) {
    background: rgba(255, 255, 255, 0.1);
    color: #fff;
  }

  .action-btn.applied {
    background: rgba(76, 175, 80, 0.1);
    border-color: rgba(76, 175, 80, 0.3);
    color: #81c784;
  }

  .spin {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .loading, .error {
    height: 300px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 16px;
    color: rgba(255, 255, 255, 0.4);
  }

  .error p { color: #ef5350; }
</style>
