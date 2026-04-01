use tauri::{command, Window, AppHandle};
use crate::utils;
use std::process::{Command, Stdio};
use std::io::{BufRead, BufReader};

#[command]
pub async fn run_provisioning_stage(
    stage: u32, 
    remote_active: bool, 
    vm_name: Option<String>, 
    app: AppHandle,
    window: Window
) -> Result<(), String> {
    let script_name = match stage {
        1 => "1_Scoop.ps1",
        2 => "2_MSVC.ps1",
        3 => "3_System_Apps.ps1",
        4 => "4_Rust_Finish.ps1",
        5 => "5_Finalize.ps1",
        6 => "Customize.ps1",
        _ => return Err("Invalid stage".to_string()),
    };

    let script_path = utils::resolve_resource_path(&app, &format!("scripts/{}", script_name))
        .ok_or_else(|| format!("Script not found: {}", script_name))?;

    let script_str = script_path.to_str().expect("Valid path string");

    let mut command = if remote_active && vm_name.is_some() {
        let name = vm_name.unwrap();
        let mut cmd = Command::new("powershell");
        cmd.args([
            "-NoProfile", 
            "-ExecutionPolicy", "Bypass", 
            "-Command", 
            &format!("Invoke-Command -VMName '{}' -FilePath '{}' -ErrorAction Stop", name, script_str)
        ]);
        cmd
    } else {
        let mut cmd = Command::new("powershell");
        cmd.args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script_str]);
        cmd
    };

    let mut child = command
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Failed to spawn process: {}", e))?;

    let stdout = child.stdout.take().ok_or("Failed to capture stdout")?;
    let reader = BufReader::new(stdout);

    for line in reader.lines() {
        if let Ok(l) = line {
            let _ = window.emit("provisioning-log", l);
        }
    }

    let status = child.wait().map_err(|e| format!("Failed to wait for process: {}", e))?;
    
    if status.success() {
        Ok(())
    } else {
        Err(format!("Stage {} failed with exit code: {:?}", stage, status.code()))
    }
}

#[command]
pub async fn install_app(
    app_id: String, 
    app_name: String, 
    is_system: bool, 
    remote_active: bool,
    vm_name: Option<String>,
    window: Window
) -> Result<(), String> {
    let _ = window.emit("provisioning-log", format!(">>> STARTING INSTALLATION OF: {}...", app_name));

    let inner_command = if is_system {
        format!("Add-AppxPackage -Name \"{}\"", app_id)
    } else {
        format!("scoop install \"{}\"", app_id)
    };

    let mut command = if remote_active && vm_name.is_some() {
        let name = vm_name.unwrap();
        let mut cmd = Command::new("powershell");
        cmd.args([
            "-NoProfile", 
            "-ExecutionPolicy", "Bypass", 
            "-Command", 
            &format!("Invoke-Command -VMName '{}' -ScriptBlock {{ {} }}", name, inner_command)
        ]);
        cmd
    } else {
        let mut cmd = Command::new("powershell");
        cmd.args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", &inner_command]);
        cmd
    };

    let mut child = command
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Failed to spawn process: {}", e))?;

    let stdout = child.stdout.take().ok_or("Failed to capture stdout")?;
    let reader = BufReader::new(stdout);

    for line in reader.lines() {
        if let Ok(l) = line {
            let _ = window.emit("provisioning-log", l);
        }
    }

    let status = child.wait().map_err(|e| format!("Failed to wait for process: {}", e))?;
    
    if status.success() {
        let _ = window.emit("provisioning-log", format!(">>> {} INSTALLED SUCCESSFULLY.", app_name));
        Ok(())
    } else {
        Err(format!("Installation failed with exit code: {:?}", status.code()))
    }
}
