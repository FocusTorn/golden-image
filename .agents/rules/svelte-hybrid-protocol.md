---
trigger: always_on
---

# Svelte-Hybrid Protocol: Modernization & Structural Integrity

## 1. :: Engineering & Validation Standards

### 1.1. :: Structural Integrity Lock
- [ ] **Balanced Tag Verification**: After ANY modification to a `.svelte` file, you MUST perform a mental or automated scan (e.g., `grep -c "</div>"`) to ensure all tags and blocks are correctly balanced.
- [ ] **Diagnostic-First Resolve**: If the IDE reports a "Module has no default export" or "Invalid closing tag," the VERY NEXT action must be a full `view_file` or `cat` of the component to identify the structural break.
- [ ] **State-Blindness Circuit Breaker**: If a Svelte-hybrid edit fails, do NOT retry blindly. You MUST perform a `view_file` to re-synchronize line numbers before attempting a second repair.

### 1.2. :: Performance & Styling
- [ ] **Scoped Styling**: Always use scoped `<style>` blocks. Never use global styles for component-specific layouts.
- [ ] **Asset Fallbacks**: When using icons (e.g., Lucide), include a text-fallback or a generic placeholder (e.g., `Package` icon) to prevent UI crashes if the specific asset fails to load.

## 2. :: Data & State Synchronization

### 2.1. :: PascalCase API Parity
- [ ] **Frontend Property Mapping**: Always ensure Svelte property bindings match the PascalCase API defined in the Rust backend (`AppId`, `FriendlyName`).
- [ ] **Mock Data Parity**: Proactively update mock data within Svelte components to mirror the latest Rust `struct` changes, ensuring browser-mode development remains accurate.

### 2.2. :: Event Handling
- [ ] **Atomic Event Resolve**: If multiple event handlers (e.g., `on:click`, `on:change`) are added or modified, verify the corresponding functions exist in the `<script>` block before finalizing the turn.
- [ ] **Command Registration Lock**: Before finalizing any turn with a new IPC command, perform a targeted `grep` on `main.rs` to ensure the command name exists in the `generate_handler!` list.

### 2.3. :: Geometry Reporting Baseline
- [ ] **The One-Time Probe**: For every new UI panel (e.g., Provisioning, Tweaks), implement a one-time reactive bridge that logs container and list geometry to the backend terminal on the initial load to prevent 'One-Pixel-At-A-Time' alignment loops.
- [ ] **Diagnostic Parity**: Maintain strict parity between the reported frontend `getBoundingClientRect()` metrics and the backend expectation for scrollbar synchronization.
- [ ] **Draggable Regions**: Ensure `data-tauri-drag-region` is applied to high-level layout containers (Sidebar, Header) and does not conflict with interactive elements.
