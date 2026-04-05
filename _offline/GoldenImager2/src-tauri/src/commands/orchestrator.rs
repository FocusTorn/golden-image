use crate::commands::audit::AppError;
use crate::state::AppState;
use tauri::{Window, State, Manager};
use std::process::Stdio;
use tokio::io::{AsyncBufReadExt, BufReader};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "PascalCase")]
pub struct OrchestratorStatus {
    pub packer_active: bool,
    pub osd_builder_ready: bool,
    pub hyperv_attached: bool,
}

#[tauri::command]
pub async fn get_orchestrator_status() -> Result<OrchestratorStatus, AppError> {
    let script = r#"
        $p = Get-Command packer -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        if (-not $p -and (Test-Path "$env:LOCALAPPDATA\Packer\packer.exe")) { $p = "$env:LOCALAPPDATA\Packer\packer.exe" }
        
        $osd = Get-Module -ListAvailable OSDBuilder -ErrorAction SilentlyContinue
        
        $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
        $hv = $feature -and $feature.State -eq 'Enabled'
        
        @{
            PackerActive = [bool]$p
            OsdBuilderReady = [bool]$osd
            HypervAttached = [bool]$hv
        } | ConvertTo-Json
    "#;

    let output = tokio::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", script])
        .output()
        .await
        .map_err(|e| AppError::new("Orchestrator Status", &e.to_string()))?;

    let json_str = String::from_utf8_lossy(&output.stdout);
    let status: OrchestratorStatus = serde_json::from_str(&json_str)
        .map_err(|e| AppError::new("Orchestrator Status Parse", &e.to_string()))?;

    Ok(status)
}

#[tauri::command]
pub async fn generate_stealth_payload(
    base_dir: String,
    active_stages: Vec<String>,
    iso_url: String,
    admin_pass: String,
    vm_name: String
) -> Result<(), AppError> {
    let stages_arr = active_stages.iter().map(|s| format!("'{}'", s)).collect::<Vec<_>>().join(",");
    
    let script = format!(
        r#"
        $BaseDir = '{}'
        $ModuleDir = [System.IO.Path]::Combine($BaseDir, "src", "modules")
        Import-Module (Join-Path $ModuleDir "Generator.psm1") -ErrorAction Stop
        
        $payloadDir = [System.IO.Path]::Combine($BaseDir, "payload", "scripts")
        Stage-PayloadScripts -TargetDir $payloadDir -ErrorAction Stop
        
        $activeStages = @({})
        New-BootstrapDevPs1 -OutputPath (Join-Path $payloadDir "BootstrapDev.ps1") -Stages $activeStages -ErrorAction Stop
        
        $cfg = @{{ IsoUrl = '{}'; AdminPassword = '{}'; VMName = '{}' }}
        New-OrchestratorUnattendXml -OutputPath ([System.IO.Path]::Combine($BaseDir, "payload", "autounattend.xml")) -Settings $cfg -BypassOptions @{{ BypassTPM = $true; BypassSecureBoot = $true }} -ErrorAction Stop
        "#,
        base_dir, stages_arr, iso_url, admin_pass, vm_name
    );

    let output = tokio::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", &script])
        .output()
        .await
        .map_err(|e| AppError::new("Payload Generation", &e.to_string()))?;

    if !output.status.success() {
        return Err(AppError::new("Payload Generation", &String::from_utf8_lossy(&output.stderr)));
    }

    Ok(())
}

#[tauri::command]
pub async fn run_packer_build(
    window: Window,
    state: State<'_, AppState>,
    template_path: String,
    vars: std::collections::HashMap<String, String>
) -> Result<(), AppError> {
    let mut var_flags = String::new();
    for (k, v) in vars {
        var_flags.push_str(&format!("-var \"{}={}\" ", k, v));
    }

    // Resolve Packer path
    let packer_path_script = r#"
        $p = Get-Command packer -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        if (-not $p -and (Test-Path "$env:LOCALAPPDATA\Packer\packer.exe")) { "$env:LOCALAPPDATA\Packer\packer.exe" } else { $p }
    "#;
    
    let packer_output = tokio::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-Command", packer_path_script])
        .output()
        .await
        .map_err(|e| AppError::new("Packer Path Search", &e.to_string()))?;
        
    let packer_exe = String::from_utf8_lossy(&packer_output.stdout).trim().to_string();
    if packer_exe.is_empty() {
        return Err(AppError::new("Packer Ignite", "Packer executable not found."));
    }

    let working_dir = std::path::Path::new(&template_path).parent()
        .ok_or_else(|| AppError::new("Packer Ignite", "Invalid template path"))?
        .to_path_buf();

    let mut child = tokio::process::Command::new(packer_exe)
        .args(["build"])
        .args(var_flags.split_whitespace())
        .arg("-on-error=ask")
        .arg(&template_path)
        .current_dir(working_dir)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| AppError::new("Packer Spawn", &e.to_string()))?;

    let stdout = child.stdout.take().unwrap();
    let stderr = child.stderr.take().unwrap();

    // Store the child handle for aborting
    let mut active = state.active_packer.lock().await;
    *active = Some(child.into()); // Convert tokio::process::Child to std::process::Child or keep as tokio?
    // Actually, into() doesn't work for tokio::process::Child to std::process::Child.
    // We should keep it as a field in AppState if we want to wait on it or kill it.

    // Let's spawn tasks for logs
    let window_clone = window.clone();
    tokio::spawn(async move {
        let mut reader = BufReader::new(stdout).lines();
        while let Ok(Some(line)) = reader.next_line().await {
            let _ = window_clone.emit("orchestrator-log", line);
        }
    });

    let window_clone_err = window.clone();
    tokio::spawn(async move {
        let mut reader = BufReader::new(stderr).lines();
        while let Ok(Some(line)) = reader.next_line().await {
            let _ = window_clone_err.emit("orchestrator-log", format!("[ERROR] {}", line));
        }
    });

    Ok(())
}

#[tauri::command]
pub async fn abort_packer_build(state: State<'_, AppState>) -> Result<(), AppError> {
    let mut active = state.active_packer.lock().await;
    if let Some(mut child) = active.take() {
        let _ = child.kill().await;
        Ok(())
    } else {
        Err(AppError::new("Abort Build", "No active build process found."))
    }
}

#[tauri::command]
pub async fn install_packer(base_dir: String) -> Result<(), AppError> {
    let script = format!(
        r#"
        $BaseDir = '{}'
        Import-Module ([System.IO.Path]::Combine($BaseDir, "src", "modules", "Installer.psm1")) -ErrorAction Stop
        Install-Packer -TargetDir "$env:LOCALAPPDATA\Packer" -ErrorAction Stop
        "#,
        base_dir
    );

    let output = tokio::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", &script])
        .output()
        .await
        .map_err(|e| AppError::new("Packer Installation", &e.to_string()))?;

    if !output.status.success() {
        return Err(AppError::new("Packer Installation", &String::from_utf8_lossy(&output.stderr)));
    }
    Ok(())
}

#[tauri::command]
pub async fn install_osdbuilder() -> Result<(), AppError> {
    let script = r#"
        $Module = Get-Module -ListAvailable OSDBuilder
        if (-not $Module) {
            Install-Module -Name OSDBuilder -Force -AllowClobber -Scope CurrentUser -Confirm:$false -ErrorAction Stop
        }
    "#;

    let output = tokio::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", script])
        .output()
        .await
        .map_err(|e| AppError::new("OSDBuilder Installation", &e.to_string()))?;

    if !output.status.success() {
        return Err(AppError::new("OSDBuilder Installation", &String::from_utf8_lossy(&output.stderr)));
    }
    Ok(())
}

#[tauri::command]
pub async fn show_payload_in_explorer(path: String) -> Result<(), AppError> {
    let _ = std::process::Command::new("explorer.exe")
        .arg(path.replace("/", "\\"))
        .spawn()
        .map_err(|e| AppError::new("Open Explorer", &e.to_string()))?;
    Ok(())
}
