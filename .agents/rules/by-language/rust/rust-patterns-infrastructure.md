---
globs: **/*.rs
alwaysApply: false
---

# Rust Infrastructure: Processes & Warning Integrity

## 1. :: Engineering & Validation Standards

### 1.1. :: Native Process Management
- [ ] **Native Child Handles**: Store `Child` handles directly (e.g., in a `Vec<Child>`) instead of only tracking PIDs.
- [ ] **Native Kill**: Use `child.kill()` for termination. Never call `taskkill` or `kill` commands via platform-specific shell logic.
- [ ] **Handle Cleanup**: Ensure all spawned child processes are drained and killed during application teardown.

### 1.2. :: Warning & Dead-Code Resolution
- [ ] **Systematic Categorization**: Run `cargo check` and group warnings (e.g., Unused Imports, Unused Structs).
- [ ] **Infrastructure Labeling**: For code kept for future integration, apply `#[allow(dead_code)]` with a mandatory `// (for future use)` comment.
- [ ] **Truly Unused Code**: Delete any code that is NOT part of immediate or future infrastructure plans.

### 1.3. :: Verification Strategy
- [ ] **Batch Iteration**: Fix all warnings by category (Imports first, then Structs, then Variables), then verify with `cargo check`.

## 2. :: Implementation Patterns

### 2.1. :: Secure Process Tracking
```rust
// ✅ CORRECT - Store Child handle directly
let child = Command::new("prog").spawn().unwrap();
processes.push(child); // Native handle tracking

// ✅ CORRECT - Termination via native API
for mut child in processes.drain(..) {
    let _ = child.kill(); // Cross-platform safe
}
```

### 2.2. :: Future-Proof Dead Code
```rust
// ✅ CORRECT - Intentional infrastructure
#[allow(dead_code)] // (for future use - Dashboard state batching)
pub struct UpdateBatch { ... }

// ❌ INCORRECT - Hiding code without context
#[allow(dead_code)]
pub struct MysteryData; // Why is this here?
```

## 3. :: Quality Gates & Metrics

- [ ] **Build Hygiene**: `cargo check` completes with zero output.
- [ ] **Zero Platform Dependencies**: No external process management commands used.
- [ ] **Infrastructure Traceability**: Every instance of `#[allow(dead_code)]` has a "for future use" comment.
