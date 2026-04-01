use crate::state::AppState;
use crate::audit;
use crate::config;
use tauri::State;
use serde::Serialize;

#[derive(Debug, Serialize)]
#[serde(rename_all = "PascalCase")]
pub struct AppError {
    pub message: String,
    pub action: String,
}

impl AppError {
    fn new(action: &str, message: &str) -> Self {
        AppError { action: action.to_string(), message: message.to_string() }
    }
}

#[tauri::command]
#[allow(non_snake_case)]
pub async fn get_audit_results(state: State<'_, AppState>, featureIds: Option<Vec<String>>) -> Result<Vec<audit::AuditResult>, AppError> {
    let features_to_audit = if let Some(ids) = featureIds {
        state.config.features.iter().filter(|f| ids.contains(&f.feature_id)).cloned().collect()
    } else {
        state.config.features.clone()
    };

    let reg_path = state.reg_path.clone();
    let results = tokio::task::spawn_blocking(move || {
        audit::run_audit(&features_to_audit, &reg_path)
    })
    .await
    .map_err(|e| AppError::new("Audit Task", &e.to_string()))?;

    Ok(results)
}

#[tauri::command]
pub async fn get_features_config(state: State<'_, AppState>) -> Result<config::FeaturesConfig, AppError> {
    Ok((*state.config).clone())
}

#[tauri::command]
pub async fn apply_feature(state: State<'_, AppState>, feature_id: String) -> Result<(), AppError> {
    let feature = state.config.features.iter().find(|f| f.feature_id == feature_id)
        .ok_or_else(|| AppError::new("Locate Feature", &format!("Feature not found: {}", feature_id)))?;

    if let Some(reg_file) = &feature.registry_key {
        let full_path = state.reg_path.join(reg_file);
        if !full_path.exists() {
            return Err(AppError::new("Registry Path", &format!("Registry file not found: {:?}", full_path)));
        }

        let final_path = full_path.to_str().ok_or_else(|| AppError::new("Registry Path", &format!("Invalid path: {:?}", full_path)))?;
        let output = tokio::process::Command::new("reg")
            .args(["import", final_path])
            .output()
            .await
            .map_err(|e| AppError::new("Registry Import", &e.to_string()))?;

        if !output.status.success() {
            return Err(AppError::new("Registry Import", &String::from_utf8_lossy(&output.stderr)));
        }
    }

    if let Some(script) = &feature.invoke_script {
        let output = tokio::process::Command::new("powershell")
            .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script])
            .output()
            .await
            .map_err(|e| AppError::new("PowerShell Execute", &e.to_string()))?;

        if !output.status.success() {
            return Err(AppError::new("PowerShell Execute", &String::from_utf8_lossy(&output.stderr)));
        }
    }

    Ok(())
}

#[tauri::command]
pub async fn undo_feature(state: State<'_, AppState>, feature_id: String) -> Result<(), AppError> {
    let feature = state.config.features.iter().find(|f| f.feature_id == feature_id)
        .ok_or_else(|| AppError::new("Locate Feature", &format!("Feature not found: {}", feature_id)))?;

    if let Some(reg_file) = &feature.registry_undo_key {
        let full_path = state.reg_path.join(reg_file);
        if !full_path.exists() {
            return Err(AppError::new("Undo Registry Path", &format!("Undo registry file not found: {:?}", full_path)));
        }

        let final_path = full_path.to_str().ok_or_else(|| AppError::new("Undo Registry Path", &format!("Invalid path: {:?}", full_path)))?;
        let output = tokio::process::Command::new("reg")
            .args(["import", final_path])
            .output()
            .await
            .map_err(|e| AppError::new("Undo Registry Import", &e.to_string()))?;

        if !output.status.success() {
            return Err(AppError::new("Undo Registry Import", &String::from_utf8_lossy(&output.stderr)));
        }
    }

    if let Some(script) = &feature.undo_script {
        let output = tokio::process::Command::new("powershell")
            .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script])
            .output()
            .await
            .map_err(|e| AppError::new("Undo PowerShell Execute", &e.to_string()))?;

        if !output.status.success() {
            return Err(AppError::new("Undo PowerShell Execute", &String::from_utf8_lossy(&output.stderr)));
        }
    }

    Ok(())
}
