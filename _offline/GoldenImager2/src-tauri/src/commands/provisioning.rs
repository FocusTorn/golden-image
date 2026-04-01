use tauri::{command, Window};
use std::process::{Command, Stdio};
use std::io::{BufRead, BufReader};

#[command]
pub async fn run_provisioning_stage(stage: u32, window: Window) -> Result<(), String> {
    let script_name = match stage {
        1 => "1_Scoop.ps1",
        2 => "2_MSVC.ps1",
        3 => "3_System_Apps.ps1",
        4 => "4_Rust_Finish.ps1",
        5 => "5_Finalize.ps1",
        6 => "Customize.ps1",
        _ => return Err("Invalid stage".to_string()),
    };

    let script_path = format!("resources/scripts/{}", script_name);

    let mut child = Command::new("powershell")
        .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", &script_path])
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
pub async fn install_app(app_id: String, app_name: String, is_system: bool, window: Window) -> Result<(), String> {
    let _ = window.emit("provisioning-log", format!(">>> STARTING INSTALLATION OF: {}...", app_name));

    let command = if is_system {
        format!("Add-AppxPackage -Name \"{}\"", app_id)
    } else {
        format!("scoop install \"{}\"", app_id)
    };

    let mut child = Command::new("powershell")
        .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", &command])
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
