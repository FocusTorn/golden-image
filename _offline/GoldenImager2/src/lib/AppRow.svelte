<script lang="ts">
  import { Copy, Trash2, ShieldCheck, Terminal, Settings } from "lucide-svelte";
  import type { AppInfo } from "./types";

  interface Props {
    app: AppInfo;
    isSelected: boolean;
    rowHue: string;
    dotColor: string;
    onclick: () => void;
    oncontextmenu: (e: MouseEvent) => void;
    ontoggleSelect: (e: Event) => void;
  }

  let { 
    app, 
    isSelected, 
    rowHue, 
    dotColor, 
    onclick, 
    oncontextmenu, 
    ontoggleSelect 
  }: Props = $props();

  const isOff = $derived(
    app.Recommendation === "unmapped" ||
    (!app.IsUser && !["safe", "warn", "unsafe"].includes(app.Recommendation))
  );
</script>

<div
  class="row"
  class:selected={isSelected}
  style="--row-hue: {rowHue}"
  onclick={onclick}
  oncontextmenu={oncontextmenu}
  onkeydown={(e) => (e.key === "Enter" || e.key === " ") && onclick()}
  role="row"
  tabindex="0"
>
  <div class="col-check">
    <input
      type="checkbox"
      checked={isSelected}
      onchange={ontoggleSelect}
      onclick={(e) => e.stopPropagation()}
    />
  </div>
  <div class="col-status">
    <div
      class="dot"
      class:is-off={isOff}
      style="--dot-color: {dotColor}"
    ></div>
  </div>
  <div class="col-name">
    <span class="text-main">{app.FriendlyName}</span>
    {#if app.Publisher}
      <span class="publisher-sub">{app.Publisher}</span>
    {/if}
  </div>
  <div class="col-appid">
    <span class="package-name">{app.AppId}</span>
    <div class="origin-badges">
      {#if app.IsCurated}<ShieldCheck size={10} class="badge-icon curated" />{/if}
      {#if app.IsProvisioned}<Terminal size={10} class="badge-icon system" />{/if}
      {#if app.IsUser}<Settings size={10} class="badge-icon user" />{/if}
    </div>
  </div>
</div>

<style>
  .row {
    display: flex;
    align-items: center;
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
    cursor: pointer;
    background: transparent;
    transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
    height: 48px;
    padding: 2px 4px; /* Reduced for Slab-v7 spacing */
  }

  .row:hover {
    background: var(--row-hue);
    filter: brightness(1.2);
  }

  .row.selected {
    background: rgba(var(--accent-rgb), 0.12);
    border-bottom-color: rgba(var(--accent-rgb), 0.2);
  }

  .col-check { width: 40px; display: flex; justify-content: center; }
  .col-status { width: 40px; display: flex; justify-content: center; }
  .col-name { width: var(--col-name-w); display: flex; flex-direction: column; overflow: hidden; }
  .col-appid { flex: 1; display: flex; align-items: center; justify-content: space-between; gap: 12px; }

  .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--dot-color); box-shadow: 0 0 6px var(--dot-color); }
  .dot.is-off { background: rgba(255, 255, 255, 0.1); box-shadow: none; }

  .text-main { color: #fff; font-size: 13px; font-weight: 500; }
  .publisher-sub { font-size: 9px; color: rgba(255, 255, 255, 0.3); letter-spacing: 0.05em; margin-top: 1px; }

  .package-name { font-family: 'Consolas', 'Cascadia Code', monospace; font-size: 11px; color: rgba(255, 255, 255, 0.45); overflow: hidden; text-overflow: ellipsis; }

  .origin-badges { display: flex; gap: 8px; padding-right: 12px; }
  :global(.badge-icon) { color: rgba(255, 255, 255, 0.2); }
  :global(.badge-icon.curated) { color: var(--risk-safe); }
  :global(.badge-icon.system) { color: var(--risk-warn); }
  :global(.badge-icon.user) { color: var(--risk-user); }
</style>
