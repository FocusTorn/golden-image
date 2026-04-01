# Optimization - GoldenImager2

## POTENTIAL PROBLEM AREAS


5. **API & Interface Concerns**:
   - Geometry probing in `App.svelte` runs on every tab switch, causing unnecessary IPC calls.
   - Error handling is limited to basic string conversions (`map_err(|e| e.to_string())`), losing structured error context.






1. **Build Performance**: 
   - `main.rs` contains extensive debug code and hardcoded paths that should be cleaned up.
   - Vite's target `chrome105` is fine, but as a Tauri app, we can leverage more efficient build steps.



3. **Maintainability Concerns**:
   - `main.rs` is over 600 lines long, violating the project rule of 300 lines for logic sharding.
   - Hardcoded absolute paths (e.g., for `taskbar.ico`) hinder portability.
   - Redundant configuration loading: `Features.json` is re-parsed in almost every command turn.



4. **Runtime Performance**:
   - Synchronous, blocking I/O calls (`fs::read_to_string`) and process execution (`std::process::Command::new`) are used inside `async` commands. This blocks the Tokio threadpool and could stall the UI.
   - Large JSON (~80KB) is repeatedly read and stripped of comments at runtime instead of being cached in memory (Tauri State).












Phase 2


2. **Code Quality Issues**:
   - Inconsistent use of `snake_case` vs `PascalCase` in serialized structs.
   - `resolve_path` logic is sprawling and repeated across multiple files.
   - Significant duplication in registry-handling logic across `main.rs` and `audit.rs`.

6. **Architecture Concerns**:
   - Tight coupling between the frontend and the physical structure of the `resources` directory.
   - Registry auditing is performed linearly on every feature, even those not relevant to the current view.



Thoughts on how to implement


7. **Security & Dependencies**:
   - Execution of PowerShell scripts with `Bypass` policy directly from the config file is powerful but lacks a safety sandbox.







---

## OPTIMIZATION OPPORTUNITIES
1. **Memory Caching for Config (HIGH)**: 
   - Load `FeaturesConfig` once during Tauri `setup` and store it in `tauri::State`. This eliminates ~80KB of I/O and parsing overhead per command.
2. **Async I/O and Process Execution (HIGH)**:
   - Transition `std::process::Command` to `tokio::process::Command` or wrap blocking calls in `spawn_blocking` to prevent UI thread starvation.
3. **Refactor and Logic Sharding (MEDIUM)**:
   - Break `main.rs` into specialized modules: `window_management.rs`, `provisioning.rs`, `tweaks.rs`, `theme.rs`.
4. **Systematic Registry Audit Optimization (MEDIUM)**:
   - Implement a lazy-loading or differential audit engine that only scans registry keys for the features currently visible or selected in the UI.
5. **Universal Path Resolver API (MEDIUM)**:
   - Consolidate all path resolution logic into a single `AssetManager` utility that uses Tauri's `path_resolver` correctly and consistently.
6. **Standardize Serialization (LOW)**:
   - Enforce `#[serde(rename_all = "PascalCase")]` across all structs to match frontend expectations without manual field remapping.
7. **Production Styling Cleanup (LOW)**:
   - Remove geometry probe logs and commented-out `println!` debug statements for a cleaner production build.

---

## SUGGESTIONS FOR FUTURE FEATURES
1. **Core Functionality Extensions**:
   - **Offline Hive Support**: Enable tweaking of offline Windows images (WIM/VHDX) by loading registry hives instead of modifying the live system.
   - **Tweak Search & Filter**: Add a searchable index to the 1900+ line `Features.json` for easier navigation.
2. **Developer Experience Features**:
   - **Hot-Reloadable Config**: Allow the `Features.json` to reload at runtime when modified during development without restarting the app.
   - **Tweak Debugger**: A built-in terminal view to see exactly which registry keys or scripts are being executed.
3. **Integration Enhancements**:
   - **Remote Provisioning**: Ability to send and execute provisioning stages on remote target machines over WinRM.
   - **Profile Cloud Sync**: Sync tweak and app profiles across different imaging environments.
4. **Advanced Capabilities**:
   - **Dependency Graph**: Handle feature dependencies (e.g., Feature B requires Feature A) within the JSON schema to prevent inconsistent system states.

IMPLEMENTATION PRIORITY: Focus on HIGH IMPACT optimizations (Caching and Async I/O) first to ensure UI responsiveness, followed by refactoring for maintainability, and finally refinement of the API surface.

---

## STRATEGIC IMPLEMENTATION ROADMAP

### Phase 1: Core Engine & Responsiveness
**Goal**: Immediate performance gains and backend cleanup.
- [x] **Memory Caching for Config**: Implement Tauri State (`tauri::State`) to store parsed `Features.json` in memory.
- [x] **Async I/O Migration**: Replace blocking `std::fs` and `std::process::Command` with `tokio` equivalents or `spawn_blocking`.
- [x] **Main.rs Logic Sharding**: Begin moving provisioning, apps, and tweak logic into specialized modules (`tweaks.rs`, `apps.rs`).
- [x] **Production Cleanup**: Remove geometry probe logs and commented debug statements.
- [x] **Absolute Path Removal**: Resolve hardcoded values like `taskbar.ico` using dynamic path resolution (Current icon does not work correctly and shows the OneDrive icon instead).

### Phase 2: Standardization & Scale
**Goal**: Architectural consistency and improved developer experience.
- [x] **PascalCase Synchronization**: Unified naming convention across Rust and Svelte serialization.
- [x] **Universal Path Resolver**: Consolidate `resolve_path` logic into a reusable utility.
- [x] **Lazy Audit Engine**: Optimize registry scanning to only audit features relevant to the current view.
- [x] **Refined Error Handling**: Move from string-based error mapping to structured error types.

### Phase 3: Resilience & Advanced Features
**Goal**: Future-proofing and hardening.
- [ ] **PowerShell Sandboxing**: Standardize execution environments for external scripts.
- [ ] **Dependency Graph Implementation**: Handle inter-feature dependencies within the JSON schema.
- [ ] **Offline Hive Support**: Enable loading external registry hives for cold-image tweaking.
- [ ] **Profile Cloud Sync**: Sync configurations across different environments.
