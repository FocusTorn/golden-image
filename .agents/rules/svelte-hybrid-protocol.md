---
trigger: always_on
---

# Svelte-Hybrid Protocol: Modernization & Structural Integrity

## 1. :: Engineering & Validation Standards

### 1.1. :: Structural Integrity Lock
- [ ] **Balanced Tag Verification**: After ANY modification to a `.svelte` file, you MUST perform a mental or automated scan to ensure all `<div>`, `{#if}`, and `{/if}` blocks are correctly balanced.
- [ ] **Diagnostic-First Resolve**: If the IDE reports a "Module has no default export" or "Invalid closing tag," the VERY NEXT action must be a full `view_file` or `cat` of the component to identify the structural break.

### 1.2. :: Performance & Styling
- [ ] **Scoped Styling**: Always use scoped `<style>` blocks. Never use global styles for component-specific layouts.
- [ ] **Asset Fallbacks**: When using icons (e.g., Lucide), include a text-fallback or a generic placeholder (e.g., `Package` icon) to prevent UI crashes if the specific asset fails to load.

## 2. :: Data & State Synchronization

### 2.1. :: PascalCase API Parity
- [ ] **Frontend Property Mapping**: Always ensure Svelte property bindings match the PascalCase API defined in the Rust backend (`AppId`, `FriendlyName`).
- [ ] **Mock Data Parity**: Proactively update mock data within Svelte components to mirror the latest Rust `struct` changes, ensuring browser-mode development remains accurate.

### 2.2. :: Event Handling
- [ ] **Atomic Event Resolve**: If multiple event handlers (e.g., `on:click`, `on:change`) are added or modified, verify the corresponding functions exist in the `<script>` block before finalizing the turn.
- [ ] **Draggable Regions**: Ensure `data-tauri-drag-region` is applied to high-level layout containers (Sidebar, Header) and does not conflict with interactive elements.
