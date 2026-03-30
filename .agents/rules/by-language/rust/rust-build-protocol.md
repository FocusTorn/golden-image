---
globs: **/*.rs
alwaysApply: false
---

# Rust Build Protocol: Compilation & Status Integrity

## 1. :: Engineering & Validation Standards

### 1.1. :: Mandatory Build Verification
- [ ] **Always Use `cargo build`**: You MUST use `cargo build` (NOT `cargo check`) for all final code validation. `cargo check` is insufficient for verifying full compilation integrity.
- [ ] **Zero Warnings Policy**: All Rust builds MUST complete with zero warnings. Warnings ARE errors unless explicitly suppressed with a documented justification.
- [ ] **Sequential Validation**: After any code change, perform: (1) `cargo build`, (2) Fix ALL warnings/errors, (3) Re-run `cargo build` until the output is clean.

### 1.2. :: Environment & Profile Management
- [ ] **Dev Build Priority**: Use standard `cargo build` for all development. Never use `cargo build --release` during development cycles as it masks diagnostic info and increases latency.
- [ ] **Build State Sync**: Do NOT assume a fix works without running a fresh `cargo build`. Mark a task complete ONLY when the build succeeds with a clean status.

## 2. :: Implementation Patterns

### 2.1. :: Warning Resolution
When resolving warnings, prefer structural fixes over suppression.

```rust
// ✅ CORRECT - Fix by underscore if intentionally unused
struct AppState {
    _config: Config, // Prefixed for future use
}

// ✅ CORRECT - Explicit suppression with justification
#[allow(dead_code)] // Infrastructure for upcoming Dashboard feature
struct FutureComponent;

// ❌ INCORRECT - Ignoring or hiding warnings
// Avoid using --release to bypass warning checks
cargo build --release 
```

## 3. :: Quality Gates & Metrics

- [ ] **Build Command**: Only `cargo build` (Dev) used for verification.
- [ ] **Warning Count**: Zero (0) warnings remaining in final output.
- [ ] **Functional Maturity**: Build verified manually after the final edit.
