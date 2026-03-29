<script lang="ts">
  export let active: boolean = false;
  export let width: string = "auto";
  export let height: string = "28px";
  export let style: string = "";
  let className: string = "";
  export { className as class };

  // Forwarding Click
  import { createEventDispatcher } from 'svelte';
  const dispatch = createEventDispatcher();

  function handleClick(e: MouseEvent) {
    dispatch('click', e);
  }
</script>

<button 
  class="bloom-control {className}" 
  class:active
  style="--width: {width}; --height: {height}; {style}"
  on:click={handleClick}
>
  <slot />
</button>

<style>
  .bloom-control {
    appearance: none;
    background: rgba(0, 0, 0, 0.35); /* Master Dark Sunken background */
    border: 1px solid rgba(255, 255, 255, 0.1); /* Master industrial border - DEFINED PIPING */
    box-shadow: 
      inset 0 1px 4px rgba(0, 0, 0, 0.4), /* Top-down industrial recess */
      inset 0 0 0 1px rgba(0, 0, 0, 0.1); 
    color: rgba(255, 255, 255, 0.6); /* Perfectly syncs with Sidebar icon weight */
    font-size: 11px;
    padding: 0 4px; /* Tight base padding to allow square buttons to breathe */
    border-radius: 4px;
    width: var(--width);
    height: var(--height);
    outline: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
    user-select: none;
  }

  .bloom-control:hover:not(.locked-sunken), .bloom-control.active {
    background-color: rgba(255, 255, 255, 0.08);
    border-color: rgba(var(--accent-rgb), 0.6) !important; /* Vibrant teal border */
    box-shadow: 
      0 0 15px rgba(var(--accent-rgb), 0.2), /* Vibrant teal bloom */
      0 0 4px rgba(var(--accent-rgb), 0.4);
    color: #fff; /* Icons brighten to 1.0 on hover */
    z-index: 50;
    text-shadow: 0 0 8px rgba(255, 255, 255, 0.3); /* Premium white text glow */
  }

  /* Refined Hover transition */
  .bloom-control:hover {
    filter: brightness(1.15); /* Slightly punchier */
  }

  .bloom-control.active {
    border-color: rgba(var(--accent-rgb), 0.8) !important;
    background: rgba(var(--accent-rgb), 0.1); 
    box-shadow: 
      0 0 12px rgba(var(--accent-rgb), 0.15),
      inset 0 0 0 1px rgba(var(--accent-rgb), 0.05);
  }
</style>
