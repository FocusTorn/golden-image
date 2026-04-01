use crate::utils;
use crate::state::AppState;
use tauri::{command, AppHandle, State};
use std::fs;

#[command]
pub async fn list_tweak_profiles(app: AppHandle, _state: State<'_, AppState>) -> Result<Vec<String>, String> {
    let profile_dir = utils::resolve_resource_path(&app, "config/TweakProfiles")
        .ok_or("Failed to resolve TweakProfiles directory")?;
    
    if !profile_dir.exists() {
        fs::create_dir_all(&profile_dir).map_err(|e| e.to_string())?;
    }

    let mut profiles = Vec::new();
    if let Ok(entries) = fs::read_dir(profile_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().map_or(false, |ext| ext == "json") {
                if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                    profiles.push(name.to_string());
                }
            }
        }
    }
    Ok(profiles)
}

#[command]
pub async fn load_tweak_profile(app: AppHandle, _state: State<'_, AppState>, name: String) -> Result<serde_json::Value, String> {
    let profile_path = utils::resolve_resource_path(&app, &format!("config/TweakProfiles/{}", name))
        .ok_or_else(|| format!("Profile {} not found", name))?;

    let content = fs::read_to_string(profile_path).map_err(|e| e.to_string())?;
    let json: serde_json::Value = serde_json::from_str(&content).map_err(|e| e.to_string())?;
    Ok(json)
}

#[command]
pub async fn save_tweak_profile(app: AppHandle, _state: State<'_, AppState>, name: String, settings: serde_json::Value) -> Result<(), String> {
    let profile_dir = utils::resolve_resource_path(&app, "config/TweakProfiles")
        .ok_or("Failed to resolve TweakProfiles directory")?;
    
    if !profile_dir.exists() {
        fs::create_dir_all(&profile_dir).map_err(|e| e.to_string())?;
    }

    let profile_name = if name.ends_with(".json") { name } else { format!("{}.json", name) };
    let profile_path = profile_dir.join(profile_name);
    
    let content = serde_json::to_string_pretty(&settings).map_err(|e| e.to_string())?;
    fs::write(profile_path, content).map_err(|e| e.to_string())?;
    Ok(())
}

#[command]
pub async fn delete_tweak_profile(app: AppHandle, _state: State<'_, AppState>, name: String) -> Result<(), String> {
    let profile_path = utils::resolve_resource_path(&app, &format!("config/TweakProfiles/{}", name))
        .ok_or_else(|| format!("Profile {} not found", name))?;
    
    if profile_path.exists() {
        fs::remove_file(profile_path).map_err(|e| e.to_string())?;
    }
    Ok(())
}
