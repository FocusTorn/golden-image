<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { ChevronDown } from 'lucide-svelte';
  import BloomControl from './BloomControl.svelte';

  interface Props {
    value?: string;
    appliedValue?: string;
    label?: string;
    options?: { Label: string; FeatureIds: string[] }[];
    width?: string;
    height?: string;
    noDiff?: boolean;
  }

  let {
    value = $bindable("none"),
    appliedValue = "none",
    label = "Select Option",
    options = [],
    width = "auto",
    height = "22px",
    noDiff = false
  }: Props = $props();

  const dispatch = createEventDispatcher();
  let isOpen = $state(false);

  function toggle() {
    isOpen = !isOpen;
  }

  function selectOption(id: string) {
    value = id;
    isOpen = false;
    dispatch('change', { value: id });
  }

  function handleOutsideClick(e: MouseEvent) {
    if (isOpen) {
      const target = e.target as HTMLElement;
      if (!target.closest('.tweak-select-container')) {
        isOpen = false;
      }
    }
  }

  onMount(() => {
    window.addEventListener('click', handleOutsideClick);
    return () => window.removeEventListener('click', handleOutsideClick);
  });

  let activeLabel = $derived(options.find(o => o.FeatureIds.includes(value))?.Label || label);
  let isAppliedValue = $derived((ids: string[]) => ids.some(id => id.toLowerCase().trim() === appliedValue.toLowerCase().trim()));
</script>

<div class="tweak-select-container" style="--width: {width}">
  <BloomControl
    {width}
    {height}
    active={isOpen}
    on:click={toggle}
    style="padding: 0 8px; justify-content: flex-start !important; border-radius: 4px !important;"
  >
    <span 
      class="select-label truncate"
      class:staged-diff={!noDiff && value !== appliedValue && value.toLowerCase() !== "none" && !value.toLowerCase().startsWith("none")}
    >
      {activeLabel}
    </span>
    <div class="chevron-wrapper" class:open={isOpen}>
      <ChevronDown size={12} />
    </div>
  </BloomControl>

  {#if isOpen}
    <div class="dropdown-list">
      {#each options as opt}
        {@const isApplied = isAppliedValue(opt.FeatureIds)}
        <button
          class="dropdown-item"
          class:active={opt.FeatureIds[0] === value}
          class:applied={isApplied}
          onclick={() => selectOption(opt.FeatureIds[0])}
        >
          {opt.Label}
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .tweak-select-container {
    position: relative;
    width: fit-content;
    min-width: 100px;
    z-index: 50; /* Ensure this stacks above adjacent rows */
  }

  .select-label {
    font-size: 10px;
    font-weight: 700;
    color: #fff;
    opacity: 0.9;
    flex: 1;
    text-align: left;
    transition: color 0.2s;
  }

  .staged-diff {
    color: var(--risk-unsafe);
    text-shadow: 0 0 8px rgba(var(--risk-unsafe-rgb), 0.3);
  }

  .chevron-wrapper {
    margin-left: 4px;
    opacity: 0.4;
    transition: transform 0.2s;
    display: flex;
    align-items: center;
  }

  .chevron-wrapper.open {
    transform: rotate(180deg);
  }

  .dropdown-list {
    position: absolute;
    top: calc(100% + 4px);
    right: 0;
    min-width: 140px;
    background: #1a1f21;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 4px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
    z-index: 5000;
    display: flex;
    flex-direction: column;
    padding: 4px;
    overflow: hidden;
  }

  .dropdown-item {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.6);
    padding: 6px 12px;
    text-align: left;
    font-size: 10px;
    border-radius: 2px;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .dropdown-item.active {
    background: linear-gradient(135deg, rgba(var(--accent-rgb), 0.12), rgba(var(--accent-rgb), 0.05));
    border: 1px solid rgba(var(--accent-rgb), 0.4) !important;
    color: #fff;
    text-shadow: 0 0 8px rgba(255, 255, 255, 0.3);
  }

  .dropdown-item.applied {
    color: #00bcd4; /* Applied Bloom Color */
    font-weight: 800;
  }

  .dropdown-item:hover:not(.active) {
    background: rgba(255, 255, 255, 0.05);
    color: #fff;
  }

  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
