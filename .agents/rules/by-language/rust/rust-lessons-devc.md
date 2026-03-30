---
globs: projects/dev-console/**/*.rs
alwaysApply: false
---

# `dev-console` Rust Lessons: Project Specifics

## 1. :: Engineering & Validation Standards

### 1.1. :: Enum-Based Refactoring
- [ ] **Closure Replacement**: In `dev-console`, prioritize replacing dynamic closures (`Box<dyn Fn>`) with type-safe Enums (e.g., `SettingsField`).
- [ ] **Compatibility Wrappers**: DO NOT break existing index-based APIs (e.g., `SettingsFields`). Use trait-based or enum-based wrappers with `from_index` / `to_index` for gradual migration.

### 1.2. :: Architectural Separation
- [ ] **Module Integrity**: strictly separate (1) `event_handler.rs`, (2) `ui_coordinator.rs`, (3) `app_state.rs`.
- [ ] **Orchestration Only**: `main.rs` must NOT contain implementation logic. It is purely an orchestrator for TUI initialization and event-loop delegation.

### 1.3. :: Refactor Verification
- [ ] **Pre-Optimization Audit**: Search for existing patterns (`lazy_static!`, existing regex caching) before implementing "new" optimizations. Document verified status if no work is required.

## 2. :: Implementation Patterns

### 2.1. :: Enum Field Access
```rust
// ✅ CORRECT - Type-safe SettingsField Enum
pub enum SettingsField { SketchDir, Env, Port }

// ✅ CORRECT - Index compatibility
impl SettingsField {
    pub fn from_index(idx: usize) -> Option<Self> { /* ... */ }
}
```

### 2.2. :: Infrastructure Code
- [ ] **Future Use Categorization**: specifically for `DashboardUpdateBatch`, `CommandConfig`, and `ToolDetector`, use `#[allow(dead_code)]` with `// (for future use)` comments.

## 3. :: Global References
The following core standards MUST be followed alongside these project lessons:
- **CORE**: [Rust Development skill](file:///p:/Projects/golden-image/.agents/skills/rust_development/SKILL.md)
- **REINFORCEMENTS**: [rust-core-reinforcements.md](file:///p:/Projects/golden-language/rust/rust-core-reinforcements.md)
