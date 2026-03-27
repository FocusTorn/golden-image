# GoldenImager UI Restoration & Modernization Plan

This plan addresses the visual gap between the current GUI and the proof-of-concept, and resolves persistent audit panel loading failures.

## 1. Visual Fidelity & Premium Polish (`MainWindow.xaml`)
To match the high-fidelity mockup, we will refine the global styles to include modern UI elements:
- **Card Aesthetics**:
    - Update `CategoryCardBorderStyle` to `CornerRadius="10"` and add a `DropShadowEffect` with `BlurRadius="15"` and `Opacity="0.4"`.
    - Apply a subtle gradient `Background` to cards (`#2D2D2D` to `#252525`).
    - Add a `BorderThickness="1"` with a light gray brush (`#3F3F3F`) to define card edges.
- **Typography & Alignment**:
    - Increase `FontSize` for `CategoryHeaderTextBlock` to `15pt` and set `FontWeight="SemiBold"`.
    - Adjust `Grid` spacing in the Home tab to reduce "floating" gaps.

## 2. Robust Audit Diagnostics (`HomeTab.ps1`)
The current background tasks are hanging, likely due to silent thread crashes or dispatcher desynchronization.
- **Thread-Safe Dispatching**:
    - Refactor `HomeTab.ps1` to use a dedicated `$uiSync` object or more resilient `InvokeAsync` pattern.
    - Explicitly pass the `$window` object into the background closure to avoid null-reference crashes.
- **Detailed Error Reporting**:
    - Implement a `Try-Catch` block that, upon failure, updates the card's error TextBlock with the specific exception message (e.g., "Thread crashed: Variable not defined").

## 3. Imaging Engine Architecture Evaluation
Address the user's question regarding a Rust-based rewrite:
- **Speed**: Rust will significantly improve start times and internal logic speed, but will not speed up external operations (DISM, Winget, Choco).
- **Control**: Rust provides superior memory safety and error handling for critical system modifications.
- **Hybrid Approach**: Maintain PowerShell for the "Orchestration" and "UI" layer (due to WPF's power) while migrating the "Core Engine" (registry tweaks, file operations) to a Rust binary for maximum reliability.

## 4. Verification Plan
- **Mockup Match**: Compare the updated GUI against the proof-of-concept image.
- **Audit Success**: Verify that "Connection Settings" and "Stages Audit" spinners disappear and are replaced by real data within 5 seconds of launch.
- **Thread Stability**: Stress test by closing and reopening the Dashboard multiple times.
