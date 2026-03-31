<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import { invoke } from "@tauri-apps/api/tauri";
  import { listen } from "@tauri-apps/api/event";
  import { 
    Zap, 
    Activity, 
    CheckCircle2, 
    Loader2, 
    Terminal, 
    AlertCircle,
    Play,
    ShieldCheck,
    Box,
    ChevronRight,
    Info
  } from "lucide-svelte";
  import BloomControl from "./BloomControl.svelte";

  const isTauri = (window as any).__TAURI_METADATA__ !== undefined;

  let activeStage = 1;
  let running = false;
  let logs: string[] = ["--- Tactical Provisioning Engine v2.0 ---", "Awaiting deployment signal..."];
  let logEnd: HTMLElement;

  let stages = [
    { id: 1, title: "Stage 01: Scoop", desc: "Initializing package manager and tactical CLI tools.", status: "idle" },
    { id: 2, title: "Stage 02: MSVC Runtimes", desc: "Injecting core visual studio runtimes and libraries.", status: "idle" },
    { id: 3, title: "Stage 03: System Apps", desc: "Provisioning standard system-level applications.", status: "idle" },
    { id: 4, title: "Stage 04: Rust Finish", desc: "Compiling final system integrations and binary optimizations.", status: "idle" },
    { id: 5, title: "Stage 05: Finalize", desc: "Performing final cleanup and system normalization.", status: "idle" },
    { id: 6, title: "Stage 06: Customize", desc: "Applying final industrial aesthetic and shell customizations.", status: "idle" }
  ];

  let unlisten: any;

  onMount(async () => {
    if (isTauri) {
      unlisten = await listen("provisioning-log", (event) => {
        logs = [...logs, event.payload as string];
        setTimeout(() => {
          if (logEnd) logEnd.scrollIntoView({ behavior: "smooth" });
        }, 10);
      });
    }
  });

  onDestroy(() => {
    if (unlisten) unlisten();
  });

  async function startDeployment() {
    if (running) return;
    running = true;
    logs = [">>> INITIALIZING DEPLOYMENT SEQUENCE...", ">>> HARDWARE LOCK ACQUIRED."];
    
    try {
      if (isTauri) {
        for (let i = 0; i < stages.length; i++) {
          const currentStage = stages[i];
          activeStage = currentStage.id;
          currentStage.status = "running";
          stages = [...stages];

          logs = [...logs, `\n>>> EXECUTING ${currentStage.title.toUpperCase()}...`];
          
          await invoke("run_provisioning_stage", { stage: currentStage.id });
          
          currentStage.status = "complete";
          stages = [...stages];
        }
        logs = [...logs, "\nMISSION ACCOMPLISHED: All provisioning stages finalized successfully."];
      } else {
        // Mock execution for dev
        for (let i = 0; i < stages.length; i++) {
          activeStage = stages[i].id;
          stages[i].status = "running";
          stages = [...stages];
          await new Promise(r => setTimeout(r, 1500));
          logs = [...logs, `[MOCK] Stage ${activeStage} logic sequence verified.`];
          stages[i].status = "complete";
          stages = [...stages];
        }
      }
    } catch (e) {
      const errorMsg = typeof e === "string" ? e : JSON.stringify(e);
      logs = [...logs, `\nCRITICAL ERROR: ${errorMsg}`];
      if (activeStage > 0) {
        stages[activeStage - 1].status = "error";
        stages = [...stages];
      }
    } finally {
      running = false;
    }
  }

  async function runSingleStage(stage: any) {
    if (running) return;
    running = true;
    activeStage = stage.id;
    stage.status = "running";
    stages = [...stages];
    
    logs = [...logs, `\n>>> EXECUTING INDIVIDUAL STAGE: ${stage.title.toUpperCase()}...`];
    
    try {
      if (isTauri) {
        await invoke("run_provisioning_stage", { stage: stage.id });
      } else {
        await new Promise(r => setTimeout(r, 1500));
        logs = [...logs, `[MOCK] Single stage ${stage.id} completed.`];
      }
      stage.status = "complete";
    } catch (e) {
      const errorMsg = typeof e === "string" ? e : JSON.stringify(e);
      logs = [...logs, `\nCRITICAL ERROR in Stage ${stage.id}: ${errorMsg}`];
      stage.status = "error";
    } finally {
      stages = [...stages];
      running = false;
    }
  }
</script>

<div class="panel-container">
  <div class="toolbar">
    <div class="title-cluster">
      <Zap size={18} class="glow-icon" />
      <h2>System Provisioning Hub</h2>
    </div>
    <div class="spacer"></div>
    <BloomControl on:click={startDeployment} disabled={running}>
      {#if running}
        <Loader2 size={14} class="spin" />
        <span>EXECUTING...</span>
      {:else}
        <Play size={14} />
        <span>START DEPLOYMENT</span>
      {/if}
    </BloomControl>
  </div>

  <div class="main-layout">
    <div class="stage-flow">
      <div class="flow-header">
        <Activity size={14} />
        <span>Deployment Sequence</span>
      </div>
      
      <div class="list-container">
        <div class="table-header">
          <div class="col-status">Status</div>
          <div class="col-title">Provisioning Stage</div>
          <div class="spacer"></div>
          <div class="col-actions">Control</div>
        </div>
        
        <div class="table-body">
          {#each stages as stage}
            <div 
              class="stage-row" 
              class:active={activeStage === stage.id}
              class:complete={stage.status === 'complete'}
              class:error={stage.status === 'error'}
              title="{stage.desc}"
            >
              <div class="col-status">
                <div class="row-indicator" style="--indicator-color: {
                  stage.status === 'complete' ? '#4caf50' : 
                  stage.status === 'running' ? '#ffeb3b' : 
                  stage.status === 'error' ? '#ff1744' : '#ff1744'
                }"></div>
              </div>

              <div class="col-title">
                <span class="text-main">{stage.title}</span>
              </div>

              <div class="spacer"></div>

              <div class="col-actions">
                {#if stage.status === 'running'}
                  <Loader2 size={12} class="spin" />
                {:else}
                  <div class="row-actions">
                    <button 
                      class="row-action-btn" 
                      on:click|stopPropagation={() => runSingleStage(stage)}
                      disabled={running}
                    >
                      <Play size={10} fill="currentColor" />
                    </button>
                    <div class="info-trigger" title="{stage.desc}">
                      <Info size={12} />
                    </div>
                  </div>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      </div>

      <div class="system-health">
        <div class="health-item">
          <ShieldCheck size={14} style="color: var(--risk-safe);" />
          <span>Security Policy Lock</span>
          <div class="status-pill active">STABLE</div>
        </div>
      </div>
    </div>

    <div class="log-viewer">
      <div class="log-header">
        <Terminal size={14} />
        <span>Tactical Deployment Log</span>
      </div>
      <div class="log-content">
        {#each logs as log}
          <div class="log-line">{log}</div>
        {/each}
        <div bind:this={logEnd}></div>
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

  .spacer { flex: 1; }

  .main-layout {
    flex: 1;
    display: grid;
    grid-template-columns: 400px 1fr;
    gap: 1px;
    background: rgba(255, 255, 255, 0.05);
    overflow: hidden;
  }

  .stage-flow {
    background: rgba(18, 24, 26, 0.6);
    display: flex;
    flex-direction: column;
    padding: 24px;
    gap: 24px;
    overflow-y: auto;
  }

  .flow-header {
    display: flex;
    align-items: center;
    gap: 12px;
    font-size: 10px;
    font-weight: 900;
    text-transform: uppercase;
    color: rgba(255, 255, 255, 0.3);
    letter-spacing: 0.1em;
  }

  .list-container {
    flex: 1;
    display: flex;
    flex-direction: column;
    background: rgba(0, 0, 0, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    overflow: hidden;
    position: relative;
    box-shadow: inset 0 24px 24px -12px rgba(0, 0, 0, 0.4);
  }

  .table-header {
    display: flex;
    align-items: center;
    padding: 0 12px;
    height: 32px;
    font-size: 10px;
    font-weight: 800;
    color: rgba(255, 255, 255, 0.4);
    text-transform: uppercase;
    letter-spacing: 0.1em;
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
  }

  .table-body {
    flex: 1;
    overflow-y: auto;
    padding: 6px;
    display: flex;
    flex-direction: column;
  }

  .stage-row {
    position: relative;
    display: flex;
    align-items: center;
    height: 38px;
    margin: 4px 0;
    padding: 0 12px;
    font-size: 11px;
    cursor: pointer;
    border-radius: 2px;
    
    /* THE INDUSTRIAL SLAB (v7) - BRING BACK THE LIGHT */
    background: 
      linear-gradient(to right, var(--slab-edge) 0%, var(--slab-base) 15%, var(--slab-base) 85%, var(--slab-edge) 100%);

    /* MACHINED EDGES: Sharp Milled Silver-Grey (#6A6E72) */
    border-top: 1px solid var(--slab-rim);
    border-bottom: 1px solid #000000;
    border-left: 1px solid #000000;
    border-right: 1px solid #000000;
    
    box-shadow: 
      0 4px 12px rgba(0, 0, 0, 0.5),
      inset 0 1px 0 rgba(255, 255, 255, 0.05);
      
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    overflow: hidden;
    flex-shrink: 0;
  }

  /* REFINED CELLULAR GRAIN: 10% Opacity Overlay */
  .stage-row::before {
    content: "";
    position: absolute;
    inset: 0;
    background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='voronoiFilter'%3E%3CfeTurbulence type='turbulence' baseFrequency='0.45' numOctaves='3' stitchTiles='stitch'/%3E%3CfeColorMatrix type='matrix' values='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 10 0'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23voronoiFilter)'/%3E%3C/svg%3E");
    opacity: 0.10; 
    pointer-events: none;
    mix-blend-mode: overlay;
    z-index: 1;
  }

  /* HEAVY OXIDATION CLOUDS: Patchy Blue-Grey Mist (#1A1D20) */
  .stage-row::after {
    content: "";
    position: absolute;
    inset: 0;
    background: 
      radial-gradient(circle at 10% 25%, var(--slab-patina) 0%, transparent 60%),
      radial-gradient(circle at 90% 80%, var(--slab-patina) 0%, transparent 70%);
    pointer-events: none;
    z-index: 2;
    mix-blend-mode: hard-light;
    opacity: 0.8;
  }

  .stage-row:hover {
    background-color: rgba(255, 255, 255, 0.03);
    border-color: rgba(var(--accent-rgb), 0.8) !important;
    box-shadow: 0 0 15px rgba(var(--accent-rgb), 0.15);
    filter: brightness(1.1);
  }

  .col-status {
    width: 48px;
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 2;
  }

  .row-indicator {
    width: 10px;
    height: 10px;
    background: var(--indicator-color);
    box-shadow: 
      0 0 10px var(--indicator-color),
      0 0 2px rgba(255, 255, 255, 0.5); /* Filament catch */
    border-radius: 2px;
    transition: all 0.3s ease;
    filter: saturate(1.8) brightness(1.2) drop-shadow(0 0 3px var(--indicator-color));
  }

  .col-title {
    flex: 1;
    z-index: 2;
  }

  .text-main {
    color: #e2e8f0;
    font-weight: 500;
    letter-spacing: 0.05em;
    background: linear-gradient(to right, #fff, #94a3b8);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
  }

  .col-actions {
    width: 60px;
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 2;
  }

  .row-action-btn {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.4);
    width: 22px;
    height: 22px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s;
  }

  .row-action-btn:hover:not(:disabled) {
    background: var(--accent-color);
    border-color: var(--accent-color);
    color: #000;
  }

  .row-action-btn:disabled {
    opacity: 0.3;
    cursor: not-allowed;
  }

  .system-health {
    margin-top: auto;
    padding-top: 24px;
    border-top: 1px solid rgba(255, 255, 255, 0.05);
  }

  .health-item {
    display: flex;
    align-items: center;
    gap: 12px;
    font-size: 12px;
    color: rgba(255, 255, 255, 0.6);
  }

  .status-pill {
    margin-left: auto;
    font-size: 9px;
    font-weight: 900;
    padding: 2px 8px;
    border-radius: 4px;
    background: rgba(255, 255, 255, 0.05);
  }

  .status-pill.active {
    background: rgba(76, 175, 80, 0.1);
    color: #81c784;
  }

  .log-viewer {
    background: rgba(0, 0, 0, 0.2);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .log-header {
    height: 48px;
    display: flex;
    align-items: center;
    padding: 0 24px;
    gap: 12px;
    font-size: 10px;
    font-weight: 900;
    text-transform: uppercase;
    color: rgba(255, 255, 255, 0.3);
    letter-spacing: 0.1em;
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
  }

  .log-content {
    flex: 1;
    padding: 24px;
    overflow-y: auto;
    font-family: inherit;
    font-size: 12px;
    line-height: 1.8;
    color: rgba(255, 255, 255, 0.5);
  }

  .log-line {
    white-space: pre-wrap;
    margin-bottom: 4px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.01);
  }

  .spin {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }
</style>
