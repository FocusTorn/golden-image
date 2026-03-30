---
name: Rust Development
description: Master instruction set for universal Rust engineering, compilation integrity, and architectural patterns.
---

# Rust Development Master Skill

This skill provides the universal baseline for high-fidelity Rust engineering. Follow these instructions for all Rust-related tasks unless project-specific rules override them.

## 1. :: Compilation & Validation Standards

### 1.1. Build Integrity
- **Build vs Check**: Use `cargo build` for final validation of any code change. `cargo check` is only for intermediate feedback.
- **Zero Warnings Policy**: All builds MUST complete with zero warnings. Warnings are treated as errors.
- **Sequential Validation**: (1) `cargo build` -> (2) Fix ALL warnings/errors -> (3) Re-run `cargo build` until clean.
- **Dev Priority**: Use standard `cargo build` during development. Reserve `--release` only for final deployment or performance benchmarking.

### 1.2. Error Resilience
- **Multi-Vector Diagnostic**: If a build fails, check for pathing, permissions, missing dependencies, and borrow-checker conflicts simultaneously in the next turn.

## 2. :: Logic & Syntax Patterns

### 2.1. Type Conversions
- **Explicit Transitions**: Use `Into`, `From`, or `AsRef` explicitly when moving between library wrapper types and local domain types.
- **Trait Audit**: Verify trait availability before assuming type compatibility.

### 2.2. Functional Chaining
- **Idiomatic Chaining**: Use `or_else()` for `Option`-to-`Option` transitions and `unwrap_or_else()` for direct value acquisition.
- **Type Parity**: Ensure closures in `map`/`filter` maintain strict type parity with the chain.

## 3. :: Architectural Integrity

### 3.1. Module Extraction
- **Incremental Extraction**: When refactoring large files, extract simple logic (utilities, DTOs) before complex state machines.
- **Borrow-Checker Sync**: Run `cargo build` after every individual function extraction to catch borrow conflicts early.

### 3.2. State Management
- **Result-Enum Transitions**: Favor returning a `Result` enum (e.g., `EventResult`) over using mutable borrows (`&mut`) in extracted modules.
- **Centralized AppState**: Use a unified `AppState` struct for owned state, and `Arc<Mutex<T>>` for shared state.

## 4. :: Infrastructure & Process Management

### 4.1. Process Control
- **Native Handles**: Store `Child` handles directly (e.g., `Vec<Child>`) rather than just PIDs.
- **Native Termination**: Use `child.kill()` for process termination; avoid shell-based `taskkill`.
- **Cleanup**: Ensure all child processes are drained and killed during application teardown.

### 4.2. Code Hygiene
- **Dead Code Labeling**: For code intended for future use, use `#[allow(dead_code)] // (for future use - [reason])`.
- **Zero-Turn Discovery**: Read imports, mods, and `Cargo.toml` in the same turn as the target file to maintain full context.
- **Physical Verification**: Verify the existence of config files and dependency paths before referenced use.
