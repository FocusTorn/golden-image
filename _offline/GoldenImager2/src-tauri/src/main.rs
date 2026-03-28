// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod audit;
mod config;
mod apps;

use serde::Serialize;

#[tauri::command]
async fn get_audit_results(app: tauri::AppHandle) -> Result<Vec<audit::AuditResult>, String> {
    let resource_path = app.path_resolver()
        .resolve_resource("resources/config/Features.json")
        .ok_or("Failed to resolve Features.json")?;
    
    let reg_path = app.path_resolver()
        .resolve_resource("resources/regfiles")
        .ok_or("Failed to resolve regfiles directory")?;

    let config = config::load_config(resource_path).map_err(|e| e.to_string())?;
    let results = audit::run_audit(&config.features, &reg_path);
    Ok(results)
}

#[tauri::command]
async fn get_features_config(app: tauri::AppHandle) -> Result<config::FeaturesConfig, String> {
    let resource_path = app.path_resolver()
        .resolve_resource("resources/config/Features.json")
        .ok_or("Failed to resolve Features.json")?;
    
    config::load_config(resource_path).map_err(|e| e.to_string())
}

#[tauri::command]
async fn apply_feature(app: tauri::AppHandle, feature_id: String) -> Result<(), String> {
    let resource_path = app.path_resolver()
        .resolve_resource("resources/config/Features.json")
        .ok_or("Failed to resolve Features.json")?;
    
    let reg_dir = app.path_resolver()
        .resolve_resource("resources/regfiles")
        .ok_or("Failed to resolve regfiles directory")?;

    let config = config::load_config(resource_path).map_err(|e| e.to_string())?;
    let feature = config.features.iter().find(|f| f.feature_id == feature_id)
        .ok_or_else(|| format!("Feature not found: {}", feature_id))?;

    if let Some(reg_file) = &feature.registry_key {
        let full_path = reg_dir.join(reg_file);
        if !full_path.exists() {
            return Err(format!("Registry file not found: {:?}", full_path));
        }

        let output = std::process::Command::new("reg")
            .args(["import", full_path.to_str().unwrap()])
            .output()
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let err = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Failed to import registry: {}", err));
        }
    }

    Ok(())
}

#[tauri::command]
async fn undo_feature(app: tauri::AppHandle, feature_id: String) -> Result<(), String> {
    let resource_path = app.path_resolver()
        .resolve_resource("resources/config/Features.json")
        .ok_or("Failed to resolve Features.json")?;
    
    let reg_dir = app.path_resolver()
        .resolve_resource("resources/regfiles")
        .ok_or("Failed to resolve regfiles directory")?;

    let config = config::load_config(resource_path).map_err(|e| e.to_string())?;
    let feature = config.features.iter().find(|f| f.feature_id == feature_id)
        .ok_or_else(|| format!("Feature not found: {}", feature_id))?;

    if let Some(reg_file) = &feature.registry_undo_key {
        let full_path = reg_dir.join(reg_file);
        if !full_path.exists() {
            return Err(format!("Undo registry file not found: {:?}", full_path));
        }

        let output = std::process::Command::new("reg")
            .args(["import", full_path.to_str().unwrap()])
            .output()
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let err = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Failed to import undo registry: {}", err));
        }
    }

    Ok(())
}

#[derive(Serialize)]
#[allow(non_snake_case)]
pub struct ThemeInfo {
    pub R: u8,
    pub G: u8,
    pub B: u8,
    pub IsDark: bool,
}

#[tauri::command]
async fn get_theme_info() -> ThemeInfo {
    use winreg::RegKey;
    use winreg::enums::HKEY_CURRENT_USER;
    
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    
    // Default Windows Blue (0x0078D4 in ABGR)
    let (r, g, b, is_dark) = if let Ok(dwm_key) = hkcu.open_subkey("Software\\Microsoft\\Windows\\DWM") {
        let color_val: u32 = dwm_key.get_value("AccentColor").unwrap_or(0xFFD47800);
        #[cfg(debug_assertions)]
        println!("[DEBUG] Registry AccentColor: 0x{:08X}", color_val);
        
        let r = (color_val & 0xFF) as u8;
        let g = ((color_val >> 8) & 0xFF) as u8;
        let b = ((color_val >> 16) & 0xFF) as u8;
        
        let personalization = hkcu.open_subkey("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize");
        let is_dark = personalization.and_then(|k| k.get_value::<u32, _>("AppsUseLightTheme")).map(|v| v == 0).unwrap_or(true);
        
        #[cfg(debug_assertions)]
        println!("[DEBUG] Parsed Theme: R={}, G={}, B={}, DarkMode={}", r, g, b, is_dark);
        
        (r, g, b, is_dark)
    } else {
        #[cfg(debug_assertions)]
        println!("[DEBUG] DWM registry key not found, using default blue.");
        (0, 120, 212, true)
    };

    ThemeInfo { R: r, G: g, B: b, IsDark: is_dark }
}

#[tauri::command]
async fn minimize_window(window: tauri::Window) -> Result<(), String> {
    window.minimize().map_err(|e| e.to_string())
}

#[tauri::command]
async fn close_window(window: tauri::Window) -> Result<(), String> {
    window.close().map_err(|e| e.to_string())
}

fn resolve_path(app: &tauri::AppHandle, path: &str) -> Option<std::path::PathBuf> {
    #[cfg(debug_assertions)]
    println!("[DEBUG] resolve_path beginning for: '{}'", path);

    // 1. Try Tauri's resolver
    if let Some(r) = app.path_resolver().resolve_resource(path) {
        #[cfg(debug_assertions)]
        println!("[DEBUG]   Testing Tauri resolve: {:?} (Exists: {})", r, r.exists());
        if r.exists() { return Some(r); }
    }
    
    // 2. Try prefixed with resources/
    if let Some(r) = app.path_resolver().resolve_resource(format!("resources/{}", path)) {
        #[cfg(debug_assertions)]
        println!("[DEBUG]   Testing Tauri prefix resolve: {:?} (Exists: {})", r, r.exists());
        if r.exists() { return Some(r); }
    }

    // 3. Try relative to CWD
    let cwd_path = std::path::Path::new("resources").join(path);
    #[cfg(debug_assertions)]
    println!("[DEBUG]   Testing CWD/resources: {:?} (Exists: {})", cwd_path, cwd_path.exists());
    if cwd_path.exists() { return Some(cwd_path); }

    // 4. Try parent's resources
    let parent_path = std::path::Path::new("../resources").join(path);
    #[cfg(debug_assertions)]
    println!("[DEBUG]   Testing ../resources: {:?} (Exists: {})", parent_path, parent_path.exists());
    if parent_path.exists() { return Some(parent_path); }

    // 5. Try parent's src-tauri resources
    let src_tauri_path = std::path::Path::new("src-tauri/resources").join(path);
    #[cfg(debug_assertions)]
    println!("[DEBUG]   Testing src-tauri/resources: {:?} (Exists: {})", src_tauri_path, src_tauri_path.exists());
    if src_tauri_path.exists() { return Some(src_tauri_path); }

    #[cfg(debug_assertions)]
    println!("[DEBUG] !!! All resolve_path attempts failed for '{}'", path);
    None
}

#[tauri::command]
async fn list_app_profiles(app: tauri::AppHandle) -> Result<Vec<String>, String> {
    let profile_dir = resolve_path(&app, "config/AppProfiles")
        .ok_or("Failed to resolve AppProfiles directory")?;
    
    if !profile_dir.exists() {
        return Ok(Vec::new());
    }

    let mut profiles = Vec::new();
    for entry in std::fs::read_dir(profile_dir).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        let path = entry.path();
        if path.is_file() && path.extension().map_or(false, |ext| ext == "json") {
            if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                profiles.push(name.to_string());
            }
        }
    }
    Ok(profiles)
}

#[tauri::command]
async fn load_app_profile(app: tauri::AppHandle, name: String) -> Result<Vec<String>, String> {
    let profile_path = resolve_path(&app, &format!("config/AppProfiles/{}", name))
        .ok_or_else(|| format!("Profile {} not found", name))?;
    
    let content = std::fs::read_to_string(profile_path).map_err(|e| e.to_string())?;
    let profile: serde_json::Value = serde_json::from_str(&content).map_err(|e| e.to_string())?;
    
    let apps = profile["Apps"].as_array()
        .ok_or("Invalid profile format: missing 'Apps' array")?
        .iter()
        .filter_map(|v| v.as_str().map(|s| s.to_string()))
        .collect();
        
    Ok(apps)
}

#[tauri::command]
async fn save_app_profile(app: tauri::AppHandle, name: String, app_ids: Vec<String>) -> Result<(), String> {
    let profile_dir = resolve_path(&app, "config/AppProfiles")
        .ok_or("Failed to resolve AppProfiles directory")?;
    
    if !profile_dir.exists() {
        std::fs::create_dir_all(&profile_dir).map_err(|e| e.to_string())?;
    }

    let profile_path = profile_dir.join(if name.ends_with(".json") { name } else { format!("{}.json", name) });
    
    let profile = serde_json::json!({
        "Apps": app_ids
    });
    
    let content = serde_json::to_string_pretty(&profile).map_err(|e| e.to_string())?;
    std::fs::write(profile_path, content).map_err(|e| e.to_string())?;
    
    Ok(())
}

#[tauri::command]
async fn get_apps(app: tauri::AppHandle) -> Result<Vec<apps::AppEntry>, String> {
    let mut resource_path = resolve_path(&app, "config/Apps.json");
    
    // Fallback for dev mode: prioritized original GoldenImager path
    if resource_path.is_none() || (resource_path.is_some() && !resource_path.as_ref().unwrap().exists()) {
        println!("[DEBUG] resolve_resource failed or path missing, trying original imager fallback...");
        let original_path = std::path::Path::new("../GoldenImager/Foundation/Win11Debloat/Config/Apps.json");
        if original_path.exists() {
            resource_path = Some(original_path.to_path_buf());
        } else {
            // Local dev fallbacks
            let dev_path = std::path::Path::new("resources/config/Apps.json");
            if dev_path.exists() {
                resource_path = Some(dev_path.to_path_buf());
            } else {
                let parent_dev_path = std::path::Path::new("../resources/config/Apps.json");
                 if parent_dev_path.exists() {
                    resource_path = Some(parent_dev_path.to_path_buf());
                 }
            }
        }
    }

    let path = resource_path.ok_or_else(|| {
        let cwd = std::env::current_dir().unwrap_or_default();
        format!("Apps.json not found. CWD: {:?}. Please ensure resources/config/Apps.json exists.", cwd)
    })?;

    #[cfg(debug_assertions)]
    println!("[DEBUG] Final resolved path for get_apps: {:?}", path);

    // Load config for recommendations
    let config = apps::load_apps_config(&path).map_err(|e| format!("Failed to read/parse {:?}: {}", path, e))?;
    
    // Scan system with integrated merge logic
    Ok(apps::scan_installed_apps(&config.apps))
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            get_audit_results, 
            get_features_config, 
            apply_feature, 
            undo_feature, 
            get_apps, 
            list_app_profiles,
            load_app_profile,
            save_app_profile,
            get_theme_info,
            minimize_window,
            close_window
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
