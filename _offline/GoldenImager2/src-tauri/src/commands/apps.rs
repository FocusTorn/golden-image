use crate::apps;
use crate::utils;
use tauri::{AppHandle, command};

#[command]
#[allow(non_snake_case)]
pub async fn get_apps(
    app: AppHandle,
    offlinePath: Option<String>,
    offlineHive: Option<String>
) -> Result<Vec<apps::AppEntry>, String> {
    let resource_path = utils::resolve_resource_path(&app, "config/Apps.json");
    let path = resource_path.ok_or_else(|| "Apps.json configuration not found in resources.".to_string())?;

    let config = apps::load_apps_config(&path).map_err(|e| format!("Failed to read/parse {:?}: {}", path, e))?;
    Ok(apps::scan_installed_apps(&config.apps, offlinePath.as_deref(), offlineHive.as_deref()).await)
}

#[command]
pub async fn list_app_profiles(app: AppHandle) -> Result<Vec<String>, String> {
    let profile_dir = utils::resolve_resource_path(&app, "config/AppProfiles")
        .ok_or("Failed to resolve AppProfiles directory")?;
    
    if !profile_dir.exists() { return Ok(Vec::new()); }

    let mut profiles = Vec::new();
    for entry in std::fs::read_dir(profile_dir).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        let path = entry.path();
        if path.extension().map_or(false, |ext| ext == "json") {
            if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                profiles.push(name.to_string());
            }
        }
    }
    Ok(profiles)
}

#[command]
pub async fn load_app_profile(app: AppHandle, name: String) -> Result<Vec<String>, String> {
    let profile_path = utils::resolve_resource_path(&app, &format!("config/AppProfiles/{}", name))
        .ok_or_else(|| format!("Profile {} not found", name))?;
    
    let content = std::fs::read_to_string(profile_path).map_err(|e| e.to_string())?;
    let stripped = json_comments::StripComments::new(content.as_bytes());
    let profile: serde_json::Value = serde_json::from_reader(stripped).map_err(|e| e.to_string())?;
    
    let apps = profile["Apps"].as_array()
        .ok_or("Invalid profile format: missing 'Apps' array")?
        .iter()
        .filter_map(|v| v.as_str().map(|s| s.to_string()))
        .collect();
        
    Ok(apps)
}

#[command]
pub async fn save_app_profile(app: AppHandle, name: String, app_ids: Vec<String>) -> Result<(), String> {
    let profile_dir = utils::resolve_resource_path(&app, "config/AppProfiles")
        .ok_or("Failed to resolve AppProfiles directory")?;
    
    if !profile_dir.exists() {
        std::fs::create_dir_all(&profile_dir).map_err(|e| e.to_string())?;
    }

    let profile_name = if name.ends_with(".json") { name } else { format!("{}.json", name) };
    let profile_path = profile_dir.join(profile_name);
    
    let profile = serde_json::json!({ "Apps": app_ids });
    let content = serde_json::to_string_pretty(&profile).map_err(|e| e.to_string())?;
    std::fs::write(profile_path, content).map_err(|e| e.to_string())?;
    Ok(())
}

#[command]
pub async fn delete_app_profile(app: AppHandle, name: String) -> Result<(), String> {
    let profile_path = utils::resolve_resource_path(&app, &format!("config/AppProfiles/{}", name))
        .ok_or_else(|| format!("Profile {} not found", name))?;
    
    if profile_path.exists() {
        std::fs::remove_file(profile_path).map_err(|e| e.to_string())?;
    }
    Ok(())
}
