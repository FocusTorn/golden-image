<script lang="ts">
  import { Settings, Shield, LayoutGrid, Palette, Save, RefreshCw, Cpu, Database, Bell, Check, Terminal, Play, Trash2, Loader2, Globe, History, Monitor, Maximize, AlertTriangle } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";
  import { settings, vhdStore } from "./store";
  import { invoke } from "@tauri-apps/api/tauri";
  import { emit } from "@tauri-apps/api/event";
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

  let saved = $state(false);
  let debugScript = $state(diagnostics[0].script);
  let debugOutput = $state("");
  let runningDebug = $state(false);
  let vmProfiles: string[] = $state([]);
  let defaultProfile = $state("");
  let initialView = $state("Dashboard");

  onMount(async () => {
    try {
      const config = await invoke("get_master_config");
      if (config && (config as any).VMProfiles) {
        vmProfiles = Object.keys((config as any).VMProfiles);
        defaultProfile = (config as any).defaultVMProfile || "";
        initialView = (config as any).defaultInitialView || "Dashboard";
      }
    } catch (e) {
      console.error("Failed to load profiles", e);
    }
  });

  async function updateDefaultProfile(val: string) {
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

  async function updateInitialView(val: string) {
    initialView = val;
    
    try {
      await invoke("update_initial_view", { view: initialView });
      saved = true;
      setTimeout(() => saved = false, 2000);
    } catch (e) {
      console.error("Failed to update initial view", e);
    }
  }

  function setDiagnostic(label: string) {
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

  let localW = $state($settings.windowWidth);
  let localH = $state($settings.windowHeight);
  let isFocused = $state(false);
  let clampedWarning = $state(false);
  let warningTimeout: any;

  function showWarning() {
    clampedWarning = true;
    if (warningTimeout) clearTimeout(warningTimeout);
    warningTimeout = setTimeout(() => clampedWarning = false, 3000);
  }

  $effect(() => {
    if (!isFocused) {
      localW = $settings.windowWidth;
      localH = $settings.windowHeight;
    }
  });

  function clampDimensions(w: number, h: number) {
    const maxW = typeof window !== 'undefined' ? window.screen.availWidth : 1920;
    const maxH = typeof window !== 'undefined' ? window.screen.availHeight : 1040;
    return {
      w: Math.min(w, maxW),
      h: Math.min(h, maxH)
    };
  }

  async function updateManualSize() {
    if (!$settings.retainWindowState) {
      const { w, h } = clampDimensions(
        parseInt(localW as any) || 895,
        parseInt(localH as any) || 1195
      );
      localW = w;
      localH = h;
      await invoke('set_window_size', { 
        width: w - 47, 
        height: h - 62 
      });
      settings.update(s => ({ ...s, windowWidth: w, windowHeight: h }));
    }
  }

  async function handleManualResize() {
    const rawW = parseInt(localW as any) || 895;
    const rawH = parseInt(localH as any) || 1195;
    const { w, h } = clampDimensions(rawW, rawH);
    
    const wasClamped = w !== rawW || h !== rawH;
    localW = w;
    localH = h;
    
    if (wasClamped) showWarning();
    
    await emit('manual-resize-start');
    settings.update(s => ({ ...s, retainWindowState: false, windowWidth: w, windowHeight: h }));
    await invoke('set_window_size', { 
      width: w - 47, 
      height: h - 62 
    });
    saved = true;
    setTimeout(() => saved = false, 2000);
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
        <BloomControl onclick={saveSettings}>
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
            <span class="tweak-name">Initial Startup View</span>
            <div class="spacer"></div>
            <TweakSelect 
              options={["Dashboard", "Provisioning", "Apps", "Tweaks", "Settings"].map(v => ({ Label: v, FeatureIds: [v] }))} 
              value={initialView} 
              appliedValue={initialView} 
              onchange={updateInitialView}
              height="30px"
              noDiff={true}
            />
          </div>

          <div class="action-item tweak-row">
            <span class="tweak-name">Default VM Profile</span>
            <div class="spacer"></div>
            <TweakSelect 
              options={['None (Force Manual)', ...vmProfiles].map(p => ({ Label: p, FeatureIds: [p] }))} 
              value={defaultProfile || 'None (Force Manual)'} 
              appliedValue={defaultProfile || 'None (Force Manual)'} 
              onchange={updateDefaultProfile}
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

          <div class="divider"></div>

          <div class="sub-header-row">
            <LayoutGrid size={11} />
            <h4>WINDOW GEOMETRY</h4>
          </div>

          <div class="geometry-grid trio">
            <div class="action-item tweak-row">
              <span class="tweak-name">W</span>
              <div class="spacer"></div>
              <input 
                type="text" 
                bind:value={localW} 
                class="num-input digit-4" 
                class:warning-text={clampedWarning}
                onfocus={() => isFocused = true}
                onblur={() => isFocused = false}
                onchange={updateManualSize} 
              />
            </div>
            <div class="action-item tweak-row">
              <span class="tweak-name">H</span>
              <div class="spacer"></div>
              <input 
                type="text" 
                bind:value={localH} 
                class="num-input digit-4" 
                class:warning-text={clampedWarning}
                onfocus={() => isFocused = true}
                onblur={() => isFocused = false}
                onchange={updateManualSize} 
              />
            </div>
            <button 
              class="vhd-action-btn resize-trigger" 
              class:release={clampedWarning}
              class:active={clampedWarning}
              onclick={handleManualResize} 
              title="Force Resize & Un-Retain"
            >
              <RefreshCw size={11} class={clampedWarning ? 'spin' : ''} />
              <span>{clampedWarning ? 'BOUNDS' : 'RESIZE'}</span>
            </button>
          </div>

          {#if clampedWarning}
            <div class="warning-msg">
              <AlertTriangle size={10} />
              <span>RESOLUTION BOUNDS ENFORCED</span>
            </div>
          {/if}

          <div 
            class="action-item tweak-row clickable-row" 
            onclick={() => settings.update(s => ({ ...s, retainWindowState: !s.retainWindowState }))}
            onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && settings.update(s => ({ ...s, retainWindowState: !s.retainWindowState }))}
            role="button"
            tabindex="0"
          >
            <span class="tweak-name">Retain Window Geometry</span>
            <div class="spacer"></div>
            <div class="apps-check-wrapper">
              <input 
                type="checkbox" 
                checked={$settings.retainWindowState} 
                onclick={(e) => e.stopPropagation()}
                onchange={(e) => settings.update(s => ({ ...s, retainWindowState: e.currentTarget.checked }))}
              />
            </div>
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
                  onchange={setDiagnostic}
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
                        <button class="run-diag-btn" onclick={runDiagnostic} disabled={runningDebug}>
                            {#if runningDebug}
                              <RefreshCw size={12} class="spin" /> RUNNING...
                            {:else}
                              <Play size={12} fill="currentColor" /> EXECUTE DIAGNOSTIC
                            {/if}
                        </button>
                        <button class="clear-diag-btn" onclick={() => debugOutput = ""}>
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

  .divider {
    height: 1px;
    background: rgba(255, 255, 255, 0.05);
    margin: 8px 0;
  }

  .sub-header-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 4px;
    margin-bottom: 6px;
    opacity: 0.6;
    color: var(--accent-color);
  }

  .sub-header-row h4 {
    font-size: 9px;
    font-weight: 900;
    letter-spacing: 0.15em;
    margin: 0;
  }

  .geometry-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
    margin-bottom: 6px;
  }

  .geometry-grid.trio {
    grid-template-columns: 1fr 1fr 100px;
  }

  .num-input.digit-4 {
    width: 52px;
    padding: 2px 4px;
    text-align: center;
    background: rgba(0, 0, 0, 0.2);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 3px;
    color: #fff;
    font-family: var(--font-mono);
    font-size: 10px;
  }

  .vhd-action-btn {
    height: 31px;
    background: #242a2d;
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 4px;
    color: rgba(255, 255, 255, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    font-size: 9px;
    font-weight: 800;
    letter-spacing: 0.1em;
    cursor: pointer;
    transition: all 0.2s;
    padding: 0 10px;
  }

  .vhd-action-btn:hover {
    filter: brightness(1.3);
    color: #fff;
    border-color: var(--accent-color);
    box-shadow: 0 0 12px rgba(var(--accent-rgb), 0.2);
  }

  .vhd-action-btn.release.active {
    background: rgba(255, 61, 96, 0.12); 
    box-shadow: 
      0 0 0 1px rgba(255, 61, 96, 0.2), 
      0 0 12px rgba(255, 61, 96, 0.12); 
    border-color: rgba(255, 61, 96, 1.0); 
    color: #ff3d60; /* RISK-UNSAFE PARITY */
  }

  .vhd-action-btn.release.active :global(svg) {
     color: #ff3d60;
  }

  .warning-text {
    color: #ff3d60 !important;
    border-color: rgba(255, 61, 96, 0.3) !important;
    background: rgba(255, 61, 96, 0.05) !important;
  }

  .warning-msg {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-top: -4px;
    margin-bottom: 8px;
    padding-left: 2px;
    color: #ff3d60;
    font-size: 8px;
    font-weight: 900;
    letter-spacing: 0.1em;
    animation: flash 0.5s ease;
  }

  @keyframes flash {
    0% { opacity: 0; transform: translateY(-2px); }
    100% { opacity: 1; transform: translateY(0); }
  }

  .clickable-row {
    cursor: pointer;
    transition: background 0.2s;
    outline: none;
  }

  .clickable-row:hover {
    background: rgba(255, 255, 255, 0.03);
  }

  .apps-check-wrapper {
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .apps-check-wrapper input[type="checkbox"] {
    appearance: none;
    -webkit-appearance: none;
    width: 14px;
    height: 14px;
    background: #0d1117;
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 3px;
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.4);
    cursor: pointer;
  }

  .apps-check-wrapper input[type="checkbox"]:checked {
    border-color: rgba(var(--accent-rgb), 0.85) !important;
    box-shadow: 0 0 10px rgba(var(--accent-rgb), 0.3), inset 0 1px 3px rgba(0, 0, 0, 0.4);
  }

  .apps-check-wrapper input[type="checkbox"]:checked::after {
    content: "";
    width: 8px;
    height: 8px;
    background: #fff;
    mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='4' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='20 6 9 17 4 12'%3E%3C/polyline%3E%3C/svg%3E") no-repeat center;
    -webkit-mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='4' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='20 6 9 17 4 12'%3E%3C/polyline%3E%3C/svg%3E") no-repeat center;
    mask-size: contain;
    -webkit-mask-size: contain;
  }

  .apps-check-wrapper input[type="checkbox"]:hover {
    border-color: rgba(var(--accent-rgb), 0.9) !important;
    box-shadow: 0 0 15px rgba(var(--accent-rgb), 0.25), 0 0 4px rgba(var(--accent-rgb), 0.45);
  }
</style>
