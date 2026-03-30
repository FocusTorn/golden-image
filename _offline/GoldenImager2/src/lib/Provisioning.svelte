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
    ChevronRight
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
      
      <div class="stages">
        {#each stages as stage}
          <div 
            class="stage-card" 
            class:active={activeStage === stage.id}
            class:complete={stage.status === 'complete'}
            class:error={stage.status === 'error'}
          >
            <div class="card-top">
              <span class="card-title">{stage.title}</span>
              <div class="card-actions">
                {#if stage.status === 'running'}
                  <Loader2 size={12} class="spin" />
                {:else if stage.status === 'complete'}
                  <CheckCircle2 size={12} class="status-icon complete" />
                {:else if stage.status === 'error'}
                  <AlertCircle size={12} class="status-icon error" />
                {:else if !running}
                  <button 
                    class="card-run-btn" 
                    on:click={() => runSingleStage(stage)}
                    title="Execute Stage"
                  >
                    <Play size={10} fill="currentColor" />
                  </button>
                {:else}
                  <div class="card-indicator"></div>
                {/if}
              </div>
            </div>
            
            <div class="card-content">
              <div class="status-dot" style="--dot-color: {
                stage.status === 'complete' ? '#4caf50' : 
                stage.status === 'running' ? 'var(--accent-color)' : 
                stage.status === 'error' ? '#ff1744' : 'rgba(255,255,255,0.1)'
              }"></div>
            </div>
          </div>
        {/each}
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

  .stages {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .stage-card {
    display: flex;
    flex-direction: column;
    padding: 12px 14px;
    background: rgba(0, 0, 0, 0.25);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 8px;
    transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    height: 80px;
    position: relative;
    justify-content: space-between;
  }

  .stage-card:hover {
    background: rgba(0, 0, 0, 0.35);
    border-color: rgba(255, 255, 255, 0.1);
  }

  .stage-card.active {
    background: rgba(var(--accent-rgb), 0.05);
    border-color: rgba(var(--accent-rgb), 0.2);
    box-shadow: 0 0 20px rgba(0, 0, 0, 0.2);
  }

  .card-top {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    width: 100%;
  }

  .card-title {
    font-size: 11px;
    font-weight: 600;
    color: rgba(255, 255, 255, 0.7);
    letter-spacing: 0.02em;
  }

  .card-actions {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .card-run-btn {
    width: 22px;
    height: 22px;
    background: transparent;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 4px;
    color: rgba(255, 255, 255, 0.2);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s;
  }

  .card-run-btn:hover {
    background: rgba(var(--accent-rgb), 0.2);
    color: var(--accent-color);
    border-color: var(--accent-color);
  }

  .card-indicator {
    width: 22px;
    height: 22px;
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 4px;
  }

  .card-content {
    display: flex;
    align-items: flex-end;
    flex: 1;
    padding-bottom: 4px;
  }

  .status-dot {
    width: 3px;
    height: 3px;
    background: var(--dot-color);
    border-radius: 50%;
    box-shadow: 0 0 6px var(--dot-color);
    margin-left: 2px;
  }

  .status-icon.complete { color: #4caf50; }
  .status-icon.error { color: #ff1744; }

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
