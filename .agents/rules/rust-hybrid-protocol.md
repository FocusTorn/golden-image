---
trigger: always_on
---

# Rust-Hybrid Protocol: Performance & IPC Reliability

## 1. :: Core Engineering Standards

### 1.1. :: Development Workflow
- [ ] **Atomic Scaffolding**: Batch `cargo init`, `Cargo.toml` configuration, and core module setup (`main.rs`, `lib.rs`) into a single turn to minimize compilation latency.
- [ ] **Pre-emptive `cargo check`**: Never request user review or frontend integration without first running `cargo check --bin [target]` to ensure back-end integrity.
- [ ] **Native-First Logic**: Delegate performance-critical operations (registry scanning, file I/O, crypto) to the Rust engine. Use PowerShell/JS only for orchestration and UI.

### 1.2. :: Dependency & Test Maturity
- [ ] **Contextual Dependency Analysis**: When investigating errors, read `Cargo.toml` and `build.rs` in the same turn to identify version mismatches or feature-gate issues.
- [ ] **Unit Test Verification**: Proactively read and run inline tests (`#[cfg(test)]`) when modifying core engine modules.

## 2. :: Inter-Process Communication (IPC)

### 2.1. :: The 'High-Fidelity' Schema Standard
- [ ] **PascalCase API Synchronization**: All structs exposed to the frontend via `serde` MUST use `#[serde(rename_all = "PascalCase")]` or explicit renaming for parity with standard C#/TS conventions.
- [ ] **JSON Output Consistency**: Maintain strict schema parity between Rust `struct` definitions and frontend configuration (e.g., `Features.json`) to minimize mapping overhead.

### 2.2. :: Tauri Integration Integrity
- [ ] **Handler Registry Audit**: For every new `#[tauri::command]`, you MUST verify it is registered in `tauri::generate_handler![]` within `main.rs` before implementing the frontend `invoke()` call.
- [ ] **Command Registration Lock**: Before finalizing any turn with a new IPC command, perform a targeted `grep` on `main.rs` to ensure the command name exists in the `generate_handler!` list.

### 2.3. :: Resilient Resource & Geometry
- [ ] **Geometry Reporting Baseline**: For every new UI panel (e.g., Provisioning, Tweaks), implement a one-time reactive bridge that logs container and list geometry to the backend terminal on the initial load to prevent 'One-Pixel-At-A-Time' alignment loops.
- [ ] **Parity Alignment**: Maintain strict parity between the reported frontend `getBoundingClientRect()` metrics and the backend expectation for scrollbar synchronization.
- [ ] **Asset Resolution**: Use `app.path_resolver()` for all asset lookups. Always implement a verified fallback (via `find_by_name`) for development-mode paths.