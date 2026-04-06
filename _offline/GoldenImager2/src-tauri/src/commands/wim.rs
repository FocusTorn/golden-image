use tauri::{command, Window};
use std::process::{Command, Stdio};
use std::path::Path;

#[command]
pub async fn mount_wim(
    wim_path: String,
    mount_path: String,
    index: u32,
    window: Window
) -> Result<(), String> {
    let _ = window.emit("orchestrator-log", format!("[*] MOUNT: Initializing WIM mount to {:?}", mount_path));
    
    // Create mount directory if it doesn't exist
    if let Err(e) = std::fs::create_dir_all(&mount_path) {
        return Err(format!("Failed to create mount directory: {}", e));
    }

    let mut cmd = Command::new("powershell");
    cmd.args([
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command",
        &format!("Mount-WindowsImage -ImagePath '{}' -Index {} -Path '{}' -ErrorAction Stop", wim_path, index, mount_path)
    ]);

    let status = cmd.status().map_err(|e| format!("Failed to spawn mount process: {}", e))?;
    
    if status.success() {
        let _ = window.emit("orchestrator-log", "[SUCCESS] WIM mounted successfully.");
        Ok(())
    } else {
        Err(format!("Mount failed with exit code: {:?}", status.code()))
    }
}

#[command]
pub async fn unmount_wim(
    mount_path: String,
    discard: bool,
    window: Window
) -> Result<(), String> {
    let action = if discard { "Discard" } else { "Save" };
    let _ = window.emit("orchestrator-log", format!("[*] UNMOUNT: Terminating session ({}) at {:?}", action, mount_path));

    let mut cmd = Command::new("powershell");
    cmd.args([
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command",
        &format!("Dismount-WindowsImage -Path '{}' -{} -ErrorAction Stop", mount_path, action)
    ]);

    let status = cmd.status().map_err(|e| format!("Failed to spawn unmount process: {}", e))?;
    
    if status.success() {
        let _ = window.emit("orchestrator-log", "[SUCCESS] WIM unmounted successfully.");
        Ok(())
    } else {
        Err(format!("Unmount failed with exit code: {:?}", status.code()))
    }
}

#[command]
pub async fn load_offline_hives(
    mount_path: String,
    hive_target: String,
    window: Window
) -> Result<(), String> {
    let _ = window.emit("orchestrator-log", format!("[*] REGISTRY: Loading offline hives to HKLM\\{}...", hive_target));

    let software_path = Path::new(&mount_path).join("Windows/System32/config/SOFTWARE");
    let system_path = Path::new(&mount_path).join("Windows/System32/config/SYSTEM");

    if !software_path.exists() || !system_path.exists() {
        return Err("Offline hives not found in mount path.".to_string());
    }

    let mut cmd = Command::new("powershell");
    cmd.args([
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command",
        &format!(
            "reg load 'HKLM\\{}_SOFTWARE' '{}'; reg load 'HKLM\\{}_SYSTEM' '{}'",
            hive_target, software_path.display(), hive_target, system_path.display()
        )
    ]);

    let status = cmd.status().map_err(|e| format!("Failed to spawn reg load process: {}", e))?;
    
    if status.success() {
        let _ = window.emit("orchestrator-log", "[SUCCESS] Offline hives loaded into registry.");
        Ok(())
    } else {
        Err(format!("Reg load failed with exit code: {:?}", status.code()))
    }
}

#[command]
pub async fn unload_offline_hives(
    hive_target: String,
    window: Window
) -> Result<(), String> {
    let _ = window.emit("orchestrator-log", format!("[*] REGISTRY: Unloading offline hives ({})...", hive_target));

    let mut cmd = Command::new("powershell");
    cmd.args([
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command",
        &format!(
            "reg unload 'HKLM\\{}_SOFTWARE'; reg unload 'HKLM\\{}_SYSTEM'",
            hive_target, hive_target
        )
    ]);

    let status = cmd.status().map_err(|e| format!("Failed to spawn reg unload process: {}", e))?;
    
    if status.success() {
        let _ = window.emit("orchestrator-log", "[SUCCESS] Offline hives unloaded.");
        Ok(())
    } else {
        Err(format!("Reg unload failed with exit code: {:?}", status.code()))
    }
}

#[derive(serde::Serialize, serde::Deserialize)]
pub struct WimImageInfo {
    #[serde(rename = "ImageIndex")]
    pub image_index: u32,
    #[serde(rename = "ImageName")]
    pub image_name: String,
    #[serde(rename = "ImageDescription")]
    pub image_description: Option<String>,
}

#[command]
pub async fn get_wim_images(wim_path: String) -> Result<Vec<WimImageInfo>, String> {
    let output = Command::new("powershell")
        .args([
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-Command",
            &format!(
                "Get-WindowsImage -ImagePath '{}' | Select-Object ImageIndex, ImageName, ImageDescription | ConvertTo-Json",
                wim_path
            )
        ])
        .output()
        .map_err(|e| format!("Process Error: {}", e))?;

    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).to_string());
    }

    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if stdout.is_empty() || stdout == "null" {
        return Ok(Vec::new());
    }

    // Wrap single object in array if PS returns one item
    let json = if stdout.starts_with('{') {
        format!("[{}]", stdout)
    } else {
        stdout
    };

    serde_json::from_str(&json).map_err(|e| format!("JSON Error: {}", e))
}
