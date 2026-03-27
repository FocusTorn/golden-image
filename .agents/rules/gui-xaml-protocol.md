---
name: GUI & XAML Protocol
scope: project
priority: high
tags: [wpf, xaml, ui]
triggers: [".xaml", ".xml", "DataContext", "d:DesignInstance"]
---

# 1. :: Structural Integrity & Validation

## 1.1. :: Mandatory Verification
- [ ] **XamlReader Validation:** After ANY modification to a XAML or XML file, you MUST run a validation script (e.g., `[System.Windows.Markup.XamlReader]::Load()`) before reporting success or notifying the user.
- [ ] **Pre-Loaded Assemblies:** Ensure `PresentationFramework` is loaded in the PowerShell session before attempting to parse XAML components.
- [ ] **Style Inheritance Audit:** Before referencing a `StaticResource` (e.g., `ToggleSwitchStyle`), verify its definition exists in the current file's resource dictionary or a globally accessible `App.xaml`.

## 1.2. :: Resource & Data Context Discovery
- [ ] **Resource Dictionary Prefetch:** When editing any XAML component, always check for and read `App.xaml` or merged resource dictionaries in the same turn to resolve `StaticResource` dependencies.
- [ ] **Binding Context Discovery:** If a XAML file specifies a `DataContext` or `d:DesignInstance`, proactively read the corresponding ViewModel file in the same turn.

# 2. :: Editing Tactics

## 2.1. :: Layout & Styling
- [ ] **Macro-Editing:** For complex UI changes involving multiple related containers (e.g., 3-column grids), prefer reading the entire file and using `write_file` to apply the complete layout at once.
- [ ] **Asset Portability:** When porting modern styles (pill toggles, blue buttons) from foundation schemas, always duplicate the full control template into the target window's resources to ensure independence.
