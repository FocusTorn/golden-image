use crate::state::AppState;
use crate::audit;
use crate::config;
use tauri::State;

#[tauri::command]
pub async fn get_audit_results(state: State<'_, AppState>) -> Result<Vec<audit::AuditResult>, String> {
    let results = audit::run_audit(&state.config.features, &state.reg_path);
    Ok(results)
}

#[tauri::command]
pub async fn get_features_config(state: State<'_, AppState>) -> Result<config::FeaturesConfig, String> {
    Ok((*state.config).clone())
}

#[tauri::command]
pub async fn apply_feature(state: State<'_, AppState>, feature_id: String) -> Result<(), String> {
    let feature = state.config.features.iter().find(|f| f.feature_id == feature_id)
        .ok_or_else(|| format!("Feature not found: {}", feature_id))?;

    if let Some(reg_file) = &feature.registry_key {
        let full_path = state.reg_path.join(reg_file);
        if !full_path.exists() {
            return Err(format!("Registry file not found: {:?}", full_path));
        }

        let final_path = full_path.to_str().ok_or_else(|| format!("Invalid path: {:?}", full_path))?;
        let output = tokio::process::Command::new("reg")
            .args(["import", final_path])
            .output()
            .await
            .map_err(|e: std::io::Error| e.to_string())?;

        if !output.status.success() {
            let err = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Failed to import registry: {}", err));
        }
    }

    if let Some(script) = &feature.invoke_script {
        let output = tokio::process::Command::new("powershell")
            .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script])
            .output()
            .await
            .map_err(|e: std::io::Error| e.to_string())?;

        if !output.status.success() {
            let err = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Feature script failed: {}", err));
        }
    }

    Ok(())
}

#[tauri::command]
pub async fn undo_feature(state: State<'_, AppState>, feature_id: String) -> Result<(), String> {
    let feature = state.config.features.iter().find(|f| f.feature_id == feature_id)
        .ok_or_else(|| format!("Feature not found: {}", feature_id))?;

    if let Some(reg_file) = &feature.registry_undo_key {
        let full_path = state.reg_path.join(reg_file);
        if !full_path.exists() {
            return Err(format!("Undo registry file not found: {:?}", full_path));
        }

        let final_path = full_path.to_str().ok_or_else(|| format!("Invalid path: {:?}", full_path))?;
        let output = tokio::process::Command::new("reg")
            .args(["import", final_path])
            .output()
            .await
            .map_err(|e: std::io::Error| e.to_string())?;

        if !output.status.success() {
            let err = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Failed to import undo registry: {}", err));
        }
    }

    if let Some(script) = &feature.undo_script {
        let output = tokio::process::Command::new("powershell")
            .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script])
            .output()
            .await
            .map_err(|e: std::io::Error| e.to_string())?;

        if !output.status.success() {
            let err = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Undo script failed: {}", err));
        }
    }

    Ok(())
}
