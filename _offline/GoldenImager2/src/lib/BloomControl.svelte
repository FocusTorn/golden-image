<script lang="ts">
  export let active: boolean = false;
  export let width: string = "auto";
  export let height: string = "28px";
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
  style="--width: {width}; --height: {height};"
  on:click={handleClick}
>
  <slot />
</button>

<style>
  .bloom-control {
    appearance: none;
    background: rgba(0, 0, 0, 0.35); /* Switched to a much deeper sunken base */
    border: 1px solid rgba(255, 255, 255, 0.06); /* Fainter, more professional edge */
    box-shadow: 
      inset 0 1px 4px rgba(0, 0, 0, 0.4), /* True top-down recessed shadow */
      inset 0 0 0 1px rgba(0, 0, 0, 0.2); 
    color: currentColor; 
    font-size: 11px;
    padding: 0 12px;
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

  .bloom-control:hover, .bloom-control.active {
    background-color: rgba(255, 255, 255, 0.08);
    border-color: rgba(var(--accent-rgb), 0.6) !important; /* Vibrant accent border */
    box-shadow: 
      0 0 20px rgba(var(--accent-rgb), 0.4),
      0 0 4px rgba(var(--accent-rgb), 0.6);
    color: #fff;
    z-index: 50;
    text-shadow: 0 0 8px rgba(255, 255, 255, 0.3); /* Premium text glow */
  }

  /* Refined Hover transition */
  .bloom-control:hover {
    filter: brightness(1.15); /* Slightly punchier */
  }

  .bloom-control.active {
    border-color: rgba(var(--accent-rgb), 0.8) !important;
    background: rgba(var(--accent-rgb), 0.1); /* Subtle sunken-active tint */
    box-shadow: 
      0 0 15px rgba(var(--accent-rgb), 0.3),
      inset 0 0 0 1px rgba(var(--accent-rgb), 0.1);
  }
</style>
