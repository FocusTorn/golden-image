<script lang="ts">
  import { Settings, Shield, LayoutGrid, Palette, Save, RefreshCw, Cpu, Database, Bell, Check } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";
  import { settings } from "./store";

  let saved = false;

  async function saveSettings() {
    saved = true;
    setTimeout(() => saved = false, 2000);
    // Note: LocalStorage persistence is handled automatically by the store subscription
  }
</script>

<div class="panel-container">
  <div class="toolbar">
    <div class="title-cluster">
      <Settings size={18} class="glow-icon" />
      <h2>Audit Policy & System Settings</h2>
    </div>
  </div>

  <div class="content">
    <div class="hub-grid">
      <!-- Column 1: Audit Policy -->
      <div class="hub-column">
        <div class="col-header">
          <Shield size={14} />
          <span>Audit Policy</span>
        </div>
        
        <div class="settings-card">
          <div class="setting-item">
            <div class="info">
              <label for="risk-threshold">Risk Threshold</label>
              <p>Warning level for unmapped applications.</p>
            </div>
            <input id="risk-threshold" type="number" bind:value={$settings.riskyThreshold} />
          </div>

          <div class="setting-item">
            <div class="info">
              <label for="auto-scan">Auto-Scan on Boot</label>
              <p>Execute audit cycle immediately upon Sysprep login.</p>
            </div>
            <input id="auto-scan" type="checkbox" bind:checked={$settings.autoScan} />
          </div>

          <div class="setting-item">
            <div class="info">
              <label for="enforce-policy">Enforce Hard Policy</label>
              <p>Prevent imaging if high-risk apps are detected.</p>
            </div>
            <input id="enforce-policy" type="checkbox" bind:checked={$settings.enforcePolicy} />
          </div>
        </div>

        <div class="col-header mt">
          <Database size={14} />
          <span>Infrastructure</span>
        </div>
        <div class="settings-card">
          <div class="setting-item">
            <div class="info">
              <label for="log-retention">Log Retention</label>
              <p>Days to keep tactical deployment logs.</p>
            </div>
            <input id="log-retention" type="number" bind:value={$settings.logRetention} />
          </div>
        </div>
      </div>

      <!-- Column 2: App Defaults -->
      <div class="hub-column">
        <div class="col-header">
          <LayoutGrid size={14} />
          <span>Application Defaults</span>
        </div>

        <div class="settings-card">
          <div class="setting-item">
            <div class="info">
              <label for="match-versioning">Match Versioning</label>
              <p>Treat version-suffixed AppIDs as identical for merging.</p>
            </div>
            <input id="match-versioning" type="checkbox" bind:checked={$settings.matchVersioning} />
          </div>

          <div class="setting-item">
            <div class="info">
              <label for="master-profile">Master Profile</label>
              <p>C:\Resources\Config\Apps-General.json</p>
            </div>
            <BloomControl small>Change</BloomControl>
          </div>

          <div class="setting-item">
            <div class="info">
              <label for="curated-only">Curated Only Mode</label>
              <p>Only show apps that exist in the master policy list.</p>
            </div>
            <input id="curated-only" type="checkbox" bind:checked={$settings.curatedOnly} />
          </div>
        </div>

        <div class="col-header mt">
          <Cpu size={14} />
          <span>Engine Performance</span>
        </div>
        <div class="settings-card">
          <div class="setting-item">
            <div class="info">
              <label for="parallel-audit">Parallel Audit</label>
              <p>Use multi-threaded registry scanning.</p>
            </div>
            <input id="parallel-audit" type="checkbox" bind:checked={$settings.parallelAudit} />
          </div>
        </div>
      </div>

      <!-- Column 3: UI/UX -->
      <div class="hub-column">
        <div class="col-header">
          <Palette size={14} />
          <span>Interface & UX</span>
        </div>

        <div class="settings-card">
          <div class="setting-item">
            <div class="info">
              <label for="accent-color">Accent Color</label>
              <p>Primary bloom luminosity hue.</p>
            </div>
            <input id="accent-color" type="color" bind:value={$settings.accentColor} />
          </div>

          <div class="setting-item">
            <div class="info">
              <label for="glass-opacity">Glass Transparency</label>
              <p>Opacity level for industrial panels.</p>
            </div>
            <input id="glass-opacity" type="range" min="0" max="100" bind:value={$settings.glassOpacity} />
          </div>

          <div class="setting-item">
            <div class="info">
              <label for="show-notifications">System Notifications</label>
              <p>Show toast alerts for critical audit failures.</p>
            </div>
            <input id="show-notifications" type="checkbox" bind:checked={$settings.showNotifications} />
          </div>
        </div>

        <div class="footer-actions">
           <BloomControl on:click={saveSettings}>
             {#if saved}
               <Check size={14} /> Saved Successfully
             {:else}
               <Save size={14} /> Save Global Policy
             {/if}
           </BloomControl>
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .panel-container {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: var(--grad-main);
  }

  .toolbar {
    height: 48px;
    background: rgba(18, 24, 26, 0.8);
    backdrop-filter: blur(12px);
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    display: flex;
    align-items: center;
    padding: 0 16px;
    flex-shrink: 0;
  }

  .title-cluster {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .glow-icon {
    color: var(--accent-color);
    filter: drop-shadow(0 0 8px var(--accent-color));
  }

  h2 {
    font-size: 11px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: rgba(255, 255, 255, 0.7);
    margin: 0;
  }

  .content {
    flex: 1;
    padding: 32px;
    overflow-y: auto;
  }

  .hub-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 32px;
    max-width: 1400px;
    margin: 0 auto;
  }

  .hub-column {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .col-header {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 10px;
    font-weight: 900;
    text-transform: uppercase;
    color: var(--accent-color);
    letter-spacing: 0.1em;
    padding-left: 4px;
    opacity: 0.8;
  }

  .col-header.mt {
    margin-top: 16px;
  }

  .settings-card {
    background: rgba(255, 255, 255, 0.02);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 24px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
    position: relative;
    overflow: hidden;
  }

  .settings-card::after {
    content: "";
    position: absolute;
    top: 0;
    right: 0;
    width: 100px;
    height: 100px;
    background: radial-gradient(circle at top right, rgba(var(--accent-rgb), 0.05), transparent 70%);
  }

  .setting-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 24px;
    position: relative;
    z-index: 1;
  }

  .setting-item .info {
    flex: 1;
  }

  .setting-item label {
    display: block;
    font-size: 13px;
    font-weight: 700;
    color: rgba(255, 255, 255, 0.9);
    margin-bottom: 2px;
    cursor: pointer;
  }

  .setting-item p {
    font-size: 11px;
    color: rgba(255, 255, 255, 0.3);
    margin: 0;
    line-height: 1.4;
  }

  input[type="number"] {
    background: #000;
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: #fff;
    border-radius: 4px;
    padding: 4px 8px;
    width: 60px;
    font-family: inherit;
    font-size: 12px;
    outline: none;
    transition: border-color 0.2s;
  }

  input[type="number"]:focus {
    border-color: var(--accent-color);
  }

  input[type="color"] {
    appearance: none;
    -webkit-appearance: none;
    border: none;
    width: 40px;
    height: 24px;
    background: transparent;
    cursor: pointer;
    padding: 0;
  }

  input[type="color"]::-webkit-color-swatch {
    border-radius: 4px;
    border: 1px solid rgba(255, 255, 255, 0.2);
  }

  input[type="checkbox"] {
    appearance: none;
    -webkit-appearance: none;
    width: 32px;
    height: 16px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 10px;
    position: relative;
    cursor: pointer;
    transition: all 0.3s;
  }

  input[type="checkbox"]:checked {
    background: var(--accent-color);
  }

  input[type="checkbox"]::after {
    content: "";
    position: absolute;
    left: 2px;
    top: 2px;
    width: 12px;
    height: 12px;
    background: #fff;
    border-radius: 50%;
    transition: all 0.3s;
  }

  input[type="checkbox"]:checked::after {
    left: 18px;
    background: #000;
  }

  input[type="range"] {
    width: 80px;
    height: 4px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 2px;
    appearance: none;
    outline: none;
  }

  input[type="range"]::-webkit-slider-thumb {
    appearance: none;
    width: 12px;
    height: 12px;
    background: var(--accent-color);
    border-radius: 50%;
    cursor: pointer;
    box-shadow: 0 0 10px var(--accent-color);
  }

  .footer-actions {
    margin-top: 32px;
    display: flex;
    justify-content: center;
  }
</style>
