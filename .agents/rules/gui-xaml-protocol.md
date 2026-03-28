---
trigger: always_on
---

# GUI-XAML Protocol: Structural Integrity & Performance

## 1. :: Engineering & Validation Standards

### 1.1. :: Mandatory System Validation
- [ ] **XamlReader Load Check**: After ANY modification to a `.xaml` or `.xml` file, you MUST execute a validation script using `[System.Windows.Markup.XamlReader]::Parse()` in an environment where `PresentationFramework` is pre-loaded.
- [ ] **Assembly Audit**: Proactively verify that `PresentationCore`, `PresentationFramework`, and `WindowsBase` are added to the current session via `Add-Type -AssemblyName` before parsing complex layouts.

### 1.2. :: Component & Resource Modularity
- [ ] **Resource Dictionary Prefetch**: Before editing a component, read `App.xaml` or merged dictionaries (e.g., `Styles.xaml`) to resolve `StaticResource` dependencies. Never define ad-hoc styles that should be global.
- [ ] **Asset Portability**: When porting patterns (e.g., card layouts, pill toggles), duplicate the full `ControlTemplate` into the target file to prevent 'Missing Resource' breaks in isolated windows.

## 2. :: Data Integrity & Bindings

### 2.1. :: Logic Synchronization
- [ ] **Binding Context Discovery**: If a XAML file specifies a `DataContext` or `d:DesignInstance`, you MUST read the corresponding ViewModel / Logic file in the same turn to ensure property parity.
- [ ] **Event-to-Command Registry**: For every `Click` or `SelectionChanged` event, verify the corresponding function exists in the back-end logic before finalizing the UI.

### 2.2. :: Shell Integration
- [ ] **Interactive Guardrails**: Ensure `data-tauri-drag-region` or native draggable handles do not block interactive child elements (buttons, inputs) by setting `pointer-events: auto` on children.