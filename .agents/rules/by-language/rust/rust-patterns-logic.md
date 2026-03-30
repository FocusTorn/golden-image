---
globs: **/*.rs
alwaysApply: false
---

# Rust Patterns: Type Logic & Syntax Integrity

## 1. :: Engineering & Validation Standards

### 1.1. :: Type Conversion Protocol
- [ ] **Explicit Transitions**: When using library wrappers (e.g., `RectMetrics`), always convert explicitly to target types (e.g., `Rect`) before passing to local logic.
- [ ] **Trait Audit**: Verify `Into`, `From`, or `AsRef` availability before assuming compatibility. Never skip conversion if types do not match directly.

### 1.2. :: Option & Result Chaining
- [ ] **Or-Else vs Unwrap**: Use `or_else()` for Option chaining (returning Option) and `unwrap_or_else()` for direct value acquisition.
- [ ] **Closure Integrity**: Ensure closures in `map`, `filter`, and `or_else` maintain strict type parity with the chain.

### 1.3. :: Refactoring Syntax Guard
- [ ] **Atomic Verification**: Run `cargo build` after EVERY structural change (e.g., block replacement). Do NOT batch multiple syntax changes without intermediate verification.
- [ ] **Brace Parity**: Manually verify brace matching after refactoring nested blocks. 

## 2. :: Implementation Patterns

### 2.1. :: Library API Conversions
```rust
// ✅ CORRECT - Explicit conversion via .into()
if let Some(metrics) = box_manager.metrics(&registry) {
    let rect: Rect = metrics.into(); // Explicitly convert wrapper type
    calculate_layout(rect);
}
```

### 2.2. :: Chaining Semantics
```rust
// ✅ CORRECT - or_else() for Option-to-Option
let res = cached.or_else(|| calculate_and_cache());

// ✅ CORRECT - unwrap_or_else() for value fallback
let val = res.unwrap_or_else(|| default_config());
```

## 3. :: Quality Gates & Metrics

- [ ] **Build Success**: `cargo build` succeeds after every logic refactor.
- [ ] **Chain Correctness**: All `Option`/`Result` chains are idiomatic and avoid duplicate unwraps.
- [ ] **Syntax Integrity**: Zero (0) brace mismatch or type-inference failures.
