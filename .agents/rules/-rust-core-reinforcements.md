---
trigger: always_on
---

# Rust Core Reinforcements

This rule ensures adherence to universal Rust standards while maintaining project-specific IPC and Tauri synchronization.

## 1. :: Universal Standards
- **Mandatory Skill**: For all Rust development, you MUST refer to and follow the instructions in the [Rust Development skill](file:///p:/Projects/golden-image/.agents/skills/rust_development/SKILL.md).
- **Core Gates**: Zero warnings policy, build-before-write validation, and native process management are non-negotiable.

## 2. :: Inter-Process Communication (IPC)
- **PascalCase API Synchronization**: All structs exposed to the frontend via `serde` MUST use `#[serde(rename_all = "PascalCase")]` or explicit renaming for parity with standard C#/TS conventions.
- **JSON Output Consistency**: Maintain strict schema parity between Rust `struct` definitions and frontend configuration (e.g., `Features.json`) to minimize mapping overhead.
- **Command Registration**: For every new `#[tauri::command]`, you MUST verify it is registered in `tauri::generate_handler![]` within `main.rs`.

## 3. :: State Synchronization
- **Logic Sharding**: Favor functional sharding for files >300 lines to minimize malformed edit risks.
- **Read-Before-Write**: Always perform a `view_file` refresh after complex terminal commands or structural edits.