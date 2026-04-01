use tauri::AppHandle;
use std::path::{Path, PathBuf};

/// Resolves a path to a project resource, handling both packaged and dev environments.
pub fn resolve_resource_path(app: &AppHandle, path: &str) -> Option<PathBuf> {
    // 1. Try Tauri's standard resource resolver (Packaged)
    app.path_resolver().resolve_resource(path).filter(|r| r.exists())
        // 2. Try 'resources/' subfolder (Dev/CWD)
        .or_else(|| {
            let p = Path::new("resources").join(path);
            if p.exists() { Some(p) } else { None }
        })
        // 3. Try '../resources/' (standard Tauri src-tauri layout in dev)
        .or_else(|| {
            let p = Path::new("../resources").join(path);
            if p.exists() { Some(p) } else { None }
        })
}
