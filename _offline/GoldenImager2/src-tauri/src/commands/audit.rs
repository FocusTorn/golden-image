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
    pub fn new(action: &str, message: &str) -> Self {
        AppError { action: action.to_string(), message: message.to_string() }
    }
}

#[tauri::command]
#[allow(non_snake_case)]
pub async fn get_audit_results(
    state: State<'_, AppState>, 
    featureIds: Option<Vec<String>>,
    _offlineHive: Option<String>
) -> Result<Vec<audit::AuditResult>, AppError> {
    let features_to_audit = {
        let conf = state.config.read().await;
        if let Some(ids) = featureIds {
            conf.features.iter().filter(|f| ids.contains(&f.feature_id)).cloned().collect()
        } else {
            conf.features.clone()
        }
    };

    let reg_path = state.reg_path.clone();
    let results = tokio::task::spawn_blocking(move || {
        audit::run_audit(&features_to_audit, &reg_path, _offlineHive.as_deref())
    })
    .await
    .map_err(|e| AppError::new("Audit Task", &e.to_string()))?;

    Ok(results)
}

#[tauri::command]
pub async fn get_features_config(state: State<'_, AppState>) -> Result<config::FeaturesConfig, AppError> {
    let conf = state.config.read().await;
    let data = (**conf).clone();
    Ok(data)
}

#[tauri::command]
#[allow(non_snake_case)]
pub async fn apply_feature(
    state: State<'_, AppState>, 
    featureId: String, 
    _offlineHive: Option<String>,
    targetVm: Option<String>
) -> Result<(), AppError> {
    apply_feature_logic(state.inner(), featureId, _offlineHive, targetVm).await
}

pub async fn apply_feature_logic(
    state: &AppState, 
    feature_id: String, 
    offline_hive: Option<String>,
    target_vm: Option<String>
) -> Result<(), AppError> {
    let feature = {
        let conf = state.config.read().await;
        conf.features.iter().find(|f| f.feature_id == feature_id).cloned()
    }.ok_or_else(|| AppError::new("Locate Feature", &format!("Feature not found: {}", feature_id)))?;

    if let Some(reg_file) = &feature.registry_key {
        let full_path = state.reg_path.join(reg_file);
        if !full_path.exists() {
            return Err(AppError::new("Registry Path", &format!("Registry file not found: {:?}", full_path)));
        }

        if let Some(vm_name) = &target_vm {
            // REMOTE VM MODE: We read on host, then inject into VM
            let content = tokio::fs::read_to_string(&full_path)
                .await
                .map_err(|e| AppError::new("Registry Read", &e.to_string()))?;

            // Inside the VM, we write to a temp file and import
            let remote_script = format!(
                "$content = @'\n{}\n'@; $path = \"$env:TEMP\\remote_tweak_{}.reg\"; $content | Out-File -FilePath $path -Encoding utf8; reg import $path; Remove-Item $path",
                content, feature_id
            );

            let (user, pass, use_creds) = crate::utils::get_vm_auth_info()
                .map_err(|e| AppError::new("Auth Info", &e))?;
            let final_pass = if use_creds { pass } else { "".to_string() };
            let auth_fragment = crate::utils::get_sac_safe_auth_fragment();

            let mut cmd = tokio::process::Command::new("powershell");
            cmd.env("VMU", user).env("VMP", final_pass);
            cmd.args([
                "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                "-Command", 
                &format!("{} Invoke-Command -VMName '{}' -ScriptBlock {{ {} }} $auth_arg", auth_fragment, vm_name, remote_script)
            ]);
            let output = cmd.output()
                .await
                .map_err(|e| AppError::new("Remote Registry", &e.to_string()))?;

            if !output.status.success() {
                return Err(AppError::new("Remote Registry", &String::from_utf8_lossy(&output.stderr)));
            }
        } else {
            // OFFLINE or LOCAL HOST MODE
            let mut final_path = full_path.to_str().ok_or_else(|| AppError::new("Registry Path", &format!("Invalid path: {:?}", full_path)))?.to_string();

            // Implement Offline Hive Logic: String Replace Root Keys before import
            if let Some(hive_target) = &offline_hive {
                let content = tokio::fs::read_to_string(&full_path)
                    .await
                    .map_err(|e| AppError::new("Offline Hive", &e.to_string()))?;
                    
                let modified = content.replace("HKEY_LOCAL_MACHINE\\SOFTWARE", &format!("HKEY_LOCAL_MACHINE\\{}\\SOFTWARE", hive_target))
                                      .replace("HKEY_LOCAL_MACHINE\\SYSTEM", &format!("HKEY_LOCAL_MACHINE\\{}\\SYSTEM", hive_target));
                                      
                let temp_path = std::env::temp_dir().join(format!("golden_imager_offline_{}.reg", feature_id));
                tokio::fs::write(&temp_path, modified)
                    .await
                    .map_err(|e| AppError::new("Offline Hive", &e.to_string()))?;
                    
                final_path = temp_path.to_str().unwrap().to_string();
            }

            let output = tokio::process::Command::new("reg")
                .args(["import", &final_path])
                .output()
                .await
                .map_err(|e| AppError::new("Registry Import", &e.to_string()))?;

            if !output.status.success() {
                return Err(AppError::new("Registry Import", &String::from_utf8_lossy(&output.stderr)));
            }
        }
    }

    if let Some(script) = &feature.invoke_script {
        let mut cmd = tokio::process::Command::new("powershell");
        if let Some(vm_name) = &target_vm {
            let (user, pass, use_creds) = crate::utils::get_vm_auth_info()
                .map_err(|e| AppError::new("Auth Info", &e))?;
            let final_pass = if use_creds { pass } else { "".to_string() };
            let auth_fragment = crate::utils::get_sac_safe_auth_fragment();
            cmd.env("VMU", user).env("VMP", final_pass);
            cmd.args([
                "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                "-Command", 
                &format!("{} Invoke-Command -VMName '{}' -ScriptBlock {{ {} }} $auth_arg", auth_fragment, vm_name, script)
            ]);
        } else {
            cmd.args([
                "-NoProfile", "-NonInteractive", "-NoLogo", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", 
                "-Command", script
            ]);
        }

        let output = cmd.output()
            .await
            .map_err(|e| AppError::new("PowerShell Execute", &e.to_string()))?;

        if !output.status.success() {
            return Err(AppError::new("PowerShell Execute", &String::from_utf8_lossy(&output.stderr)));
        }
    }

    Ok(())
}

#[tauri::command]
#[allow(non_snake_case)]
pub async fn apply_features_batch(
    state: State<'_, AppState>, 
    featureIds: Vec<String>, 
    _offlineHive: Option<String>,
    targetVm: Option<String>
) -> Result<(), AppError> {
    let mut resolved = Vec::new();

    fn resolve_dag(
        id: &str,
        features: &[config::Feature],
        resolved: &mut Vec<String>,
        seen: &mut std::collections::HashSet<String>
    ) -> Result<(), String> {
        if resolved.contains(&id.to_string()) { return Ok(()); }
        if !seen.insert(id.to_string()) { return Err(format!("Circular sequence detected: {}", id)); }

        let feature = features.iter().find(|f| f.feature_id == id)
            .ok_or_else(|| format!("Missing Dependency: {}", id))?;

        if let Some(reqs) = &feature.requires {
            for req in reqs {
                resolve_dag(req, features, resolved, seen)?;
            }
        }
        resolved.push(id.to_string());
        Ok(())
    }

    for id in &featureIds {
        let mut seen = std::collections::HashSet::new();
        let features = {
            let conf = state.config.read().await;
            conf.features.clone()
        };
        resolve_dag(id, &features, &mut resolved, &mut seen)
            .map_err(|e| AppError::new("Dependency Graph", &e))?;
    }

    // Process all topologically sorted 
    for resolved_id in resolved {
        apply_feature_logic(state.inner(), resolved_id, _offlineHive.clone(), targetVm.clone()).await?;
    }
    
    Ok(())
}

#[tauri::command]
#[allow(non_snake_case)]
pub async fn undo_feature(
    state: State<'_, AppState>, 
    featureId: String,
    targetVm: Option<String>
) -> Result<(), AppError> {
    let feature = {
        let conf = state.config.read().await;
        conf.features.iter().find(|f| f.feature_id == featureId).cloned()
    }.ok_or_else(|| AppError::new("Locate Feature", &format!("Feature not found: {}", featureId)))?;

    if let Some(reg_file) = &feature.registry_undo_key {
        let full_path = state.reg_path.join(reg_file);
        if !full_path.exists() {
            return Err(AppError::new("Undo Registry Path", &format!("Undo registry file not found: {:?}", full_path)));
        }

        if let Some(vm_name) = &targetVm {
            let (user, pass, use_creds) = crate::utils::get_vm_auth_info()
                .map_err(|e| AppError::new("Auth Info", &e))?;
            let final_pass = if use_creds { pass } else { "".to_string() };
            let auth_fragment = crate::utils::get_sac_safe_auth_fragment();
            let script = format!("reg import '{}'", full_path.to_str().unwrap());
            let mut cmd = tokio::process::Command::new("powershell");
            cmd.env("VMU", user).env("VMP", final_pass);
            cmd.args([
                "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                "-Command", 
                &format!("{} Invoke-Command -VMName '{}' -ScriptBlock {{ {} }} $auth_arg", auth_fragment, vm_name, script)
            ]);
            let output = cmd.output()
                .await
                .map_err(|e| AppError::new("Remote Registry Undo", &e.to_string()))?;

            if !output.status.success() {
                return Err(AppError::new("Remote Registry Undo", &String::from_utf8_lossy(&output.stderr)));
            }
        } else {
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
    }

    if let Some(script) = &feature.undo_script {
        let mut cmd = tokio::process::Command::new("powershell");
        if let Some(vm_name) = &targetVm {
            let (user, pass, use_creds) = crate::utils::get_vm_auth_info()
                .map_err(|e| AppError::new("Auth Info", &e))?;
            let final_pass = if use_creds { pass } else { "".to_string() };
            let auth_fragment = crate::utils::get_sac_safe_auth_fragment();
            cmd.env("VMU", user).env("VMP", final_pass);
            cmd.args([
                "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                "-Command", 
                &format!("{} Invoke-Command -VMName '{}' -ScriptBlock {{ {} }} $auth_arg", auth_fragment, vm_name, script)
            ]);
        } else {
            cmd.args([
                "-NoProfile", "-NonInteractive", "-NoLogo", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", 
                "-Command", script
            ]);
        }

        let output = cmd.output()
            .await
            .map_err(|e| AppError::new("Undo PowerShell Execute", &e.to_string()))?;

        if !output.status.success() {
            return Err(AppError::new("Undo PowerShell Execute", &String::from_utf8_lossy(&output.stderr)));
        }
    }

    Ok(())
}

#[tauri::command]
pub async fn run_debug_diagnostic(script: String) -> Result<String, String> {
    let output = tokio::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", &script])
        .output()
        .await
        .map_err(|e| format!("Failed to launch diagnostic: {}", e))?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    if output.status.success() {
        Ok(stdout.to_string())
    } else {
        Err(if stderr.is_empty() { format!("Command failed (Exit code: {:?})", output.status.code()) } else { stderr.to_string() })
    }
}

