---
globs: **/*.rs
alwaysApply: false
---

# Rust Architecture: Modules & Persistent State

## 1. :: Engineering & Validation Standards

### 1.1. :: Incremental Module Extraction
- [ ] **Simple Extraction First**: When refactoring large files (e.g., `main.rs`), extract simpler logic like dashboard scroll or mouse events before complex state machines.
- [ ] **Inter-Step Verification**: Run `cargo build` after EVERY individual function extraction to catch borrow-checker conflicts (E0499, E0502) early.

### 1.2. :: State Management Protocol
- [ ] **Result-Enum Transitions**: Do NOT use mutable borrows (`&mut`) for state changes in extracted modules. Return a `Result` enum (e.g., `EventResult`) and let the caller update the state.
- [ ] **AppState Centralization**: Use a unified `AppState` struct to hold owned state and `Arc<Mutex<T>>` for shared state. Ensure sync methods are provided to reconcile owned copies from shared references.

## 2. :: Implementation Patterns

### 2.1. :: Decoupled State Updates
```rust
// ✅ CORRECT - Return transitions via Enums
pub enum TaskResult { Continue, Stop, StateChanged(NewState) }

pub fn handle_event(state: &State) -> TaskResult {
    // Immutable read-only logic
    TaskResult::StateChanged(new_state)
}

// Caller Updates:
if let TaskResult::StateChanged(new) = handle_event(&app.state) {
    app.state = new;
}
```

### 2.2. :: AppState Configuration
```rust
pub struct AppState {
    pub settings: Settings, // Owned
    pub dashboard_arc: Arc<Mutex<Dashboard>>, // Shared
}

impl AppState {
    pub fn sync_dashboard(&mut self) {
        if let Ok(locked) = self.dashboard_arc.lock() {
            self.dashboard = locked.clone();
        }
    }
}
```

## 3. :: Quality Gates & Metrics

- [ ] **Borrow Integrity**: No complex mutable borrow conflicts when extracting modules.
- [ ] **Reduced Complexity**: `main.rs` contains only orchestration logic, no direct state implementations.
- [ ] **State Consistency**: AppState sync methods deployed and verified after async updates.
