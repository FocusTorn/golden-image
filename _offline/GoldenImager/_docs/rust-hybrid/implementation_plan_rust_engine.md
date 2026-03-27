# Rust Hybrid Foundation: GoldenImagerEngine Initialization

This plan outlines the first phase of the **Hybrid Power** model, where performance-critical orchestration and system auditing are migrated from PowerShell to a high-speed Rust-based engine.

## Proposed Changes

### [GoldenImagerEngine]
Initialization of the native orchestration engine.

#### [NEW] [Engine/Cargo.toml](file:///p:/Projects/golden-image/_offline/GoldenImager/Engine/Cargo.toml)
- Define project metadata.
- Dependencies:
    - `serde`, `serde_json`: High-performance JSON serialization for IPC.
    - `windows-rs`: Native Windows API access for Registry/File I/O.
    - `clap`: Robust CLI argument parsing.

#### [NEW] [Engine/src/main.rs](file:///p:/Projects/golden-image/_offline/GoldenImager/Engine/src/main.rs)
- Entry point for the engine.
- Implements a command dispatcher for:
    - `audit`: Scans current system state against `Features.json`.
    - `apply`: (Future) Native application of registry tweaks.
- Outputs structured JSON to `stdout` for the PowerShell UI to consume.

#### [NEW] [Engine/src/audit.rs](file:///p:/Projects/golden-image/_offline/GoldenImager/Engine/src/audit.rs)
- Logic for high-speed registry scanning.
- Replaces the `Get-ItemProperty` bottlenecks in the legacy GUI.

## Verification Plan

### Automated Tests
- `cargo check`: Ensure compilation integrity.
- `cargo run -- audit`: Verify JSON output structure against existing PowerShell harvest logic.

### Manual Verification
- Execute the engine from PowerShell and verify the JSON object matches the `UiControlMappings` expectations.
