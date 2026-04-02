<script lang="ts">
  import { Settings, Shield, LayoutGrid, Palette, Save, RefreshCw, Cpu, Database, Bell, Check, Terminal, Play, Trash2, Loader2, Globe, History, Monitor } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";
  import { settings, vhdStore } from "./store";
  import { invoke } from "@tauri-apps/api/tauri";
  import { onMount } from "svelte";
  import TweakSelect from "./TweakSelect.svelte";

  const diagnostics = [
    {
      label: "Registry Integrity (Setup/State)",
      script: `$path = "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State"\n$valueName = "ImageState"\nWrite-Host ">>> TESTING REGISTRY ACCESS..." -ForegroundColor Cyan\ntry {\n    $val = Get-ItemProperty -Path $path -Name $valueName -ErrorAction Stop\n    Write-Host "SUCCESS: ImageState is: $($val.ImageState)" -ForegroundColor Green\n} catch {\n    Write-Host "BLOCK DETECTED: $($_.Exception.Message)" -ForegroundColor Red\n    Get-Acl $path | Select-Object -ExpandProperty Access | Format-Table\n}`
    },
    {
      label: "Hyper-V & VM Inventory",
      script: `Write-Host ">>> SCANNING HYPER-V INVENTORY..." -ForegroundColor Cyan\ntry {\n    Get-VM | Select-Object Name, State, Uptime, Status | Format-Table\n} catch {\n    Write-Host "QUERY FAILED: $($_.Exception.Message)" -ForegroundColor Red\n    Write-Host "HINT: Ensure Hyper-V PowerShell module is installed and app is running as Admin." -ForegroundColor Yellow\n}`
    },
    {
      label: "WinRM & Remoting Test",
      script: `Write-Host ">>> AUDITING WINRM CONNECTIVITY..." -ForegroundColor Cyan\ntry {\n    Test-WSMan -ErrorAction Stop\n    Write-Host "SUCCESS: WinRM Service is active and responding." -ForegroundColor Green\n    Get-Service WinRM | Select-Object Name, Status, StartType | Format-Table\n} catch {\n    Write-Host "WINRM FAILED: $($_.Exception.Message)" -ForegroundColor Red\n    Write-Host "ACTION: Run 'winrm quickconfig' in an elevated shell." -ForegroundColor Yellow\n}`
    },
    {
        label: "Master Config Access",
        script: `Write-Host ">>> VERIFYING MASTER CONFIG ACCESSIBILITY..." -ForegroundColor Cyan\n$p = "p:/Projects/golden-image/_master_config.json"\nif (Test-Path $p) {\n    Write-Host "SUCCESS: Config found at $p" -ForegroundColor Green\n    $c = Get-Content $p\n    Write-Host "Size: $($c.Length) characters." -ForegroundColor White\n} else {\n    Write-Host "ERROR: File missing at $p" -ForegroundColor Red\n}`
    }
  ];

  let saved = false;
  let debugScript = diagnostics[0].script;
  let debugOutput = "";
  let runningDebug = false;
  let vmProfiles: string[] = [];
  let defaultProfile = "";

  onMount(async () => {
    try {
      const config = await invoke("get_master_config");
      if (config && (config as any).VMProfiles) {
        vmProfiles = Object.keys((config as any).VMProfiles);
        defaultProfile = (config as any).defaultVMProfile || "";
      }
    } catch (e) {
      console.error("Failed to load profiles", e);
    }
  });

  async function updateDefaultProfile(e: any) {
    const val = e.detail?.value || e.target?.value;
    defaultProfile = val === 'None (Force Manual)' ? '' : val;
    
    // Broadcast to global store for dashboard sync
    vhdStore.update(s => ({ ...s, selectedProfile: defaultProfile }));
    
    try {
      await invoke("update_default_profile", { profile: defaultProfile });
      saved = true;
      setTimeout(() => saved = false, 2000);
    } catch (e) {
      console.error("Failed to update default profile", e);
    }
  }

  function setDiagnostic(e: any) {
    const label = e.detail?.value || e.target?.value;
    const d = diagnostics.find(x => x.label === label);
    if (d) debugScript = d.script;
  }

  async function saveSettings() {
    saved = true;
    setTimeout(() => saved = false, 2000);
  }

  async function runDiagnostic() {
    if (runningDebug) return;
    runningDebug = true;
    debugOutput = ">>> INITIALIZING DIAGNOSTIC SEQUENCER...\n";
    try {
      const res = await invoke("run_debug_diagnostic", { script: debugScript });
      debugOutput += res;
    } catch (e: any) {
      debugOutput += `!!! SYSTEM ERROR: ${e}`;
    } finally {
      runningDebug = false;
    }
  }
</script>

<div class="panel">
  <div class="toolbar">
    <div class="title-cluster">
      <Settings size={18} class="glow-icon" />
      <h2>Audit Policy & System Settings</h2>
    </div>
    <div class="spacer"></div>
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

  <div class="settings-grid">
    <!-- COLUMN 1: ENVIRONMENT & AUDIT -->
    <div class="settings-column">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon"><Monitor size={16} /></span>
          <h3>TARGET ENVIRONMENT</h3>
        </div>
        <div class="card-body">
          <div class="action-item tweak-row">
            <span class="tweak-name">Default VM Profile</span>
            <div class="spacer"></div>
            <TweakSelect 
              options={['None (Force Manual)', ...vmProfiles].map(p => ({ Label: p, FeatureIds: [p] }))} 
              value={defaultProfile || 'None (Force Manual)'} 
              appliedValue={defaultProfile || 'None (Force Manual)'} 
              on:change={updateDefaultProfile}
              width="180px"
              height="30px"
            />
          </div>

          <div class="action-item tweak-row restricted" title="Ghost Mode (Awaiting Boot Parser)">
            <span class="tweak-name">Auto-Scan on Boot</span>
            <div class="spacer"></div>
            <input type="checkbox" bind:checked={$settings.autoScan} disabled />
          </div>

          <div class="action-item tweak-row restricted" title="Ghost Mode (Pending VhdUtils sync)">
             <span class="tweak-name">Enforce Hard Policy</span>
             <div class="spacer"></div>
             <input type="checkbox" bind:checked={$settings.enforcePolicy} disabled />
          </div>
        </div>
      </div>

      <div class="category-card mt">
        <div class="card-header">
          <span class="header-icon"><Shield size={16} /></span>
          <h3>AUDIT SENSITIVITY</h3>
        </div>
        <div class="card-body">
          <div class="action-item tweak-row restricted">
            <span class="tweak-name">Risk Threshold</span>
            <div class="spacer"></div>
            <input type="number" bind:value={$settings.riskyThreshold} disabled class="num-input" />
          </div>
          <div class="action-item tweak-row restricted">
            <span class="tweak-name">Match Versioning</span>
            <div class="spacer"></div>
            <input type="checkbox" bind:checked={$settings.matchVersioning} disabled />
          </div>
        </div>
      </div>
    </div>

    <!-- COLUMN 2: APPLICATION LOGIC & TUNING -->
    <div class="settings-column">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon"><LayoutGrid size={16} /></span>
          <h3>APPLICATION LOGIC</h3>
        </div>
        <div class="card-body">
          <div class="action-item tweak-row">
            <span class="tweak-name">Master Directory</span>
            <div class="spacer"></div>
            <button class="zap-btn">
               <Database size={11} strokeWidth={2.5} />
            </button>
          </div>

          <div class="action-item tweak-row restricted">
             <span class="tweak-name">Curated Only Mode</span>
             <div class="spacer"></div>
             <input type="checkbox" bind:checked={$settings.curatedOnly} disabled />
          </div>
        </div>
      </div>

      <div class="category-card mt">
        <div class="card-header">
          <span class="header-icon"><Cpu size={16} /></span>
          <h3>ENGINE TUNING</h3>
        </div>
        <div class="card-body">
          <div class="action-item tweak-row restricted">
            <span class="tweak-name">Parallel Registry Scan</span>
            <div class="spacer"></div>
            <input type="checkbox" bind:checked={$settings.parallelAudit} disabled />
          </div>
        </div>
      </div>

      <div class="category-card mt">
        <div class="card-header">
          <span class="header-icon"><History size={16} /></span>
          <h3>INFRASTRUCTURE</h3>
        </div>
        <div class="card-body">
          <div class="action-item tweak-row restricted">
            <span class="tweak-name">Log Retention (Days)</span>
            <div class="spacer"></div>
            <input type="number" bind:value={$settings.logRetention} disabled class="num-input" />
          </div>
        </div>
      </div>
    </div>

    <!-- COLUMN 3: INTERFACE -->
    <div class="settings-column">
      <div class="category-card">
        <div class="card-header">
          <span class="header-icon"><Palette size={16} /></span>
          <h3>INTERFACE & UX</h3>
        </div>
        <div class="card-body">
          <div class="action-item tweak-row">
            <span class="tweak-name">Accent Color</span>
            <div class="spacer"></div>
            <input type="color" bind:value={$settings.accentColor} class="color-pick" />
          </div>

          <div class="action-item tweak-row">
            <span class="tweak-name">Glass Transparency</span>
            <div class="spacer"></div>
            <input type="range" min="0" max="100" bind:value={$settings.glassOpacity} class="range-pick" />
          </div>

          <div class="action-item tweak-row">
             <span class="tweak-name">System Notifications</span>
             <div class="spacer"></div>
             <input type="checkbox" bind:checked={$settings.showNotifications} />
          </div>
        </div>
      </div>
    </div>

    <!-- FULL-WIDTH OPERATIONAL DIAGNOSTICS -->
    <div class="category-card" style="grid-column: span 3;">
        <div class="card-header">
            <span class="header-icon"><Terminal size={16} /></span>
            <h3>TERMINAL DIAGNOSTICS</h3>
            <div class="header-loader">
                <TweakSelect 
                  options={diagnostics.map(d => ({ Label: d.label, FeatureIds: [d.label] }))} 
                  value={diagnostics.find(d => d.script === debugScript)?.label || ""} 
                  appliedValue={diagnostics.find(d => d.script === debugScript)?.label || ""} 
                  on:change={setDiagnostic}
                  width="220px"
                  height="30px"
                  noDiff={true}
                />
            </div>
        </div>
        <div class="card-body term-body">
            <div class="term-layout">
                <div class="script-side">
                    <textarea bind:value={debugScript} spellcheck="false" placeholder="Enter PowerShell..."></textarea>
                    <div class="term-actions">
                        <button class="run-diag-btn" on:click={runDiagnostic} disabled={runningDebug}>
                            {#if runningDebug}
                              <RefreshCw size={12} class="spin" /> RUNNING...
                            {:else}
                              <Play size={12} fill="currentColor" /> EXECUTE DIAGNOSTIC
                            {/if}
                        </button>
                        <button class="clear-diag-btn" on:click={() => debugOutput = ""}>
                            <Trash2 size={12} />
                        </button>
                    </div>
                </div>
                <div class="term-out">
                    <div class="out-label">STDOUT</div>
                    <pre>{debugOutput || "Waiting for diagnostic cycle..."}</pre>
                </div>
            </div>
        </div>
    </div>
  </div>
</div>

<style>
  .panel {
    display: flex;
    flex-direction: column;
    height: 100%;
    padding: 12px;
    gap: 8px;
    overflow: hidden;
    background: transparent;
  }

  .toolbar {
    height: 38px;
    background: rgba(18, 24, 26, 0.8);
    backdrop-filter: blur(12px);
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    display: flex;
    align-items: center;
    padding: 0 16px;
    border-radius: 6px;
    flex-shrink: 0;
  }

  .title-cluster {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  :global(.glow-icon) {
    color: var(--accent-color);
    filter: drop-shadow(0 0 8px var(--accent-color));
  }

  h2 {
    font-size: 10.5px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: rgba(255, 255, 255, 0.7);
    margin: 0;
  }

  .spacer { flex: 1; }

  .settings-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    grid-gap: 16px;
    padding: 16px;
    overflow-y: auto;
    flex: 1;
    scrollbar-gutter: stable;
    align-items: flex-start;
  }

  .settings-column {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .category-card {
    width: 100%;
    background: rgba(26, 31, 34, var(--glass-opacity, 0.8)); 
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.7);
    flex-shrink: 0;
    position: relative; /* Anchor for z-index stacking */
    z-index: 10;
  }

  .category-card.mt {
    margin-top: 0;
  }

  .card-header {
    height: 32px;
    display: flex;
    align-items: center;
    padding: 0 14px;
    background: rgba(255, 255, 255, 0.02);
  }

  .card-header h3 {
    font-size: 10px;
    font-weight: 800;
    color: #fff;
    opacity: 0.9;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    margin: 0;
  }

  .header-icon {
    margin-right: 12px;
    color: var(--accent-color);
    display: flex;
    align-items: center;
  }

  .header-loader {
    margin-left: auto;
  }

  .card-body {
    padding: 6px 10px;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .tweak-row {
    position: relative;
    display: flex;
    align-items: center;
    height: 34px;
    padding: 0 12px;
    font-size: 10.5px;
    background: #242a2d; 
    border: 1px solid rgba(255, 255, 255, 0.04);
    border-radius: 5px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  }

  .tweak-name {
    color: rgba(255, 255, 255, 0.7);
    font-weight: 500;
  }

  .restricted {
    opacity: 0.35;
    pointer-events: none;
    filter: grayscale(1);
  }

  .footer-actions {
      display: flex;
      align-items: center;
  }

  .zap-btn {
    width: 22px;
    height: 22px;
    border: 1px solid rgba(0, 188, 212, 0.2);
    background: rgba(0, 188, 212, 0.05);
    color: #00bcd4;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
  }

  .num-input {
    width: 40px;
    background: #000;
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: #fff;
    font-size: 10px;
    padding: 2px 4px;
    border-radius: 4px;
  }

  .color-pick {
      width: 24px;
      height: 18px;
      padding: 0;
      border: 1px solid rgba(255, 255, 255, 0.2);
      background: transparent;
      border-radius: 2px;
  }

  .range-pick {
      width: 60px;
      height: 4px;
  }

  /* TERMINAL LAYOUT REDESIGN */
  .term-body {
      padding: 10px;
  }

  .term-layout {
      display: flex;
      gap: 16px;
      height: 220px;
  }

  .script-side {
      flex: 1.2;
      display: flex;
      flex-direction: column;
      gap: 10px;
  }

  textarea {
      flex: 1;
      background: #0b0f11;
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 6px;
      color: #00ffaa;
      font-family: 'Consolas', monospace;
      font-size: 11px;
      padding: 12px;
      resize: none;
      outline: none;
  }

  .term-actions {
      display: flex;
      gap: 8px;
  }

  .run-diag-btn {
      flex: 1;
      height: 28px;
      background: var(--accent-color);
      color: #000;
      border: none;
      border-radius: 4px;
      font-size: 10px;
      font-weight: 800;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      cursor: pointer;
  }

  .clear-diag-btn {
      width: 32px;
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(255, 255, 255, 0.1);
      color: #fff;
      border-radius: 4px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
  }

  .term-out {
      flex: 2;
      background: #000;
      border-radius: 6px;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      border: 1px solid rgba(255, 255, 255, 0.05);
  }

  .out-label {
      background: #111;
      padding: 4px 10px;
      font-size: 8px;
      font-weight: 900;
      color: rgba(255, 255, 255, 0.3);
      border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  }

  pre {
      flex: 1;
      margin: 0;
      padding: 10px;
      font-size: 10.5px;
      color: #ccc;
      overflow-y: auto;
      font-family: 'Consolas', monospace;
  }
</style>
