---
name: Rust Hybrid Protocol
scope: project
priority: high
tags: [rust, cargo, ipc]
triggers: [".rs", "Cargo.toml", "main.rs", "lib.rs"]
---

# 1. :: Engineering Standards

## 1.1. :: Development Workflow
- [ ] **Single-Turn Scaffolding:** Always batch `cargo init`, `Cargo.toml` configuration, and the initial module setup (`main.rs`, `lib.rs`) into a single turn. 
- [ ] **Pre-emptive `cargo check`:** Never ask for user review of Rust code without first running `cargo check` to ensure compilation integrity.
- [ ] **Native-First Logic:** Performance-critical operations MUST be delegated to the Rust engine. PowerShell remains as the "UI and Orchestration" layer.

## 1.2. :: Dependency & Test Awareness
- [ ] **Unit Test Awareness:** When modifying a Rust module, proactively read its inline tests (`#[cfg(test)]`) or relevant `tests/` files to understand expected behavior.
- [ ] **Dependency Analysis:** When investigating compilation errors, read `Cargo.toml` in the same turn to check for version mismatches or missing features.

# 2. :: Inter-Process Communication (IPC)

## 2.1. :: Schema & Output
- [ ] **JSON Output Standard:** All Rust-based engine commands must output valid, structured JSON to `stdout` for the PowerShell UI to consume.
- [ ] **Schema Consistency:** Maintain strict parity between the Rust `struct` definitions and the PowerShell JSON configuration (e.g., `Features.json`) to minimize mapping complexity.
