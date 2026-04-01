use crate::commands::audit::AppError;
use serde::{Deserialize, Serialize};
use std::io::Read;

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "PascalCase")]
pub struct VhdInfo {
    pub path: String,
    pub attached: bool,
    pub disk_number: Option<u32>,
}

#[derive(Serialize, Deserialize, Debug, Default)]
#[serde(rename_all = "PascalCase")]
pub struct MasterConfig {
    #[serde(rename = "VMProfiles", alias = "VmProfiles")]
    pub vm_profiles: std::collections::HashMap<String, VMProfile>,
    #[serde(rename = "VMFileSystem", alias = "VmFileSystem")]
    pub vm_file_system: VMFileSystem,
}

#[derive(Serialize, Deserialize, Debug, Default)]
#[serde(rename_all = "PascalCase")]
pub struct VMProfile {
    #[serde(rename = "VMDetails", alias = "VmDetails")]
    pub vm_details: Option<VMDetails>,
}

#[derive(Serialize, Deserialize, Debug, Default)]
#[serde(rename_all = "PascalCase")]
pub struct VMDetails {
    #[serde(rename = "VMName", alias = "VmName")]
    pub vm_name: String,
    pub os_vhd_path: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Default)]
#[serde(rename_all = "PascalCase")]
pub struct VMFileSystem {
    #[serde(rename = "HostVhdPath", alias = "host_vhd_path")]
    pub host_vhd_path: String,
}

#[tauri::command]
pub async fn get_master_config() -> Result<serde_json::Value, AppError> {
    let path = "p:/Projects/golden-image/_master_config.json";
    let content = std::fs::read_to_string(path)
        .map_err(|e| AppError::new("Master Config Load", &e.to_string()))?;
    
    // Explicitly strip and load as string to avoid stream issues
    let mut stripped = json_comments::StripComments::new(content.as_bytes());
    let mut stripped_str = String::new();
    stripped.read_to_string(&mut stripped_str)
        .map_err(|e| AppError::new("JSONC Strip", &e.to_string()))?;

    let config: serde_json::Value = serde_json::from_str(&stripped_str)
        .map_err(|e| AppError::new("Master Config Parse", &e.to_string()))?;
    
    Ok(config)
}

#[tauri::command]
pub async fn mount_vhd(vhd_path: String) -> Result<VhdInfo, AppError> {
    let script = format!(
        "Mount-VHD -Path '{}' -ErrorAction Stop; Get-VHD -Path '{}' | Select-Object Path, Attached, DiskNumber | ConvertTo-Json",
        vhd_path, vhd_path
    );

    let output = tokio::process::Command::new("powershell")
        .args([
            "-NoProfile", 
            "-NonInteractive", 
            "-ExecutionPolicy", "Bypass", 
            "-WindowStyle", "Hidden",
            "-Command", &script
        ])
        .output()
        .await
        .map_err(|e| AppError::new("VHD Mount", &e.to_string()))?;

    if !output.status.success() {
        return Err(AppError::new("VHD Mount", &String::from_utf8_lossy(&output.stderr)));
    }

    let json_str = String::from_utf8_lossy(&output.stdout);
    let info: VhdInfo = serde_json::from_str(&json_str)
        .map_err(|e| AppError::new("VHD Info Parse", &e.to_string()))?;

    Ok(info)
}

#[tauri::command]
pub async fn unmount_vhd(vhd_path: String) -> Result<(), AppError> {
    // Check if mounted first to avoid pointless errors
    let script = format!(
        "$vhd = Get-VHD -Path '{}' -ErrorAction SilentlyContinue; if ($vhd.Attached) {{ Dismount-VHD -Path '{}' -ErrorAction Stop }}",
        vhd_path, vhd_path
    );

    let output = tokio::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", &script])
        .output()
        .await
        .map_err(|e| AppError::new("VHD Unmount", &e.to_string()))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        // If it's already not mounted, that's a success for us
        if !stderr.contains("is not mounted") && !stderr.contains("not found") {
            return Err(AppError::new("VHD Unmount", &stderr));
        }
    }

    Ok(())
}

#[tauri::command]
pub async fn attach_vhd_to_vm(vhd_path: String, vm_name: String) -> Result<(), AppError> {
    let script = format!(
        "Add-VMHardDiskDrive -VMName '{}' -ControllerType SCSI -Path '{}' -ErrorAction Stop",
        vm_name, vhd_path
    );

    let output = tokio::process::Command::new("powershell")
        .args([
            "-NoProfile", 
            "-NonInteractive", 
            "-ExecutionPolicy", "Bypass", 
            "-WindowStyle", "Hidden",
            "-Command", &script
        ])
        .output()
        .await
        .map_err(|e| AppError::new("VHD VM Attach", &e.to_string()))?;

    if !output.status.success() {
        return Err(AppError::new("VHD VM Attach", &String::from_utf8_lossy(&output.stderr)));
    }

    Ok(())
}

#[tauri::command]
pub async fn detach_vhd_from_vm(vhd_path: String, vm_name: String) -> Result<(), AppError> {
    let script = format!(
        "$d = Get-VMHardDiskDrive -VMName '{}' -ErrorAction SilentlyContinue | Where-Object {{ $_.Path -eq '{}' }}; if ($d) {{ Remove-VMHardDiskDrive -VMHardDiskDrive $d -ErrorAction Stop }}",
        vm_name, vhd_path
    );

    let output = tokio::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", &script])
        .output()
        .await
        .map_err(|e| AppError::new("VHD VM Detach", &e.to_string()))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if !stderr.contains("not found") && !stderr.contains("not exist") {
            return Err(AppError::new("VHD VM Detach", &stderr));
        }
    }

    Ok(())
}
#[tauri::command]
pub async fn transition_vhd(target: String, vhd_path: String, vm_name: Option<String>) -> Result<VhdInfo, AppError> {
    // 1. COMPREHENSIVE RELEASE (Mutual Exclusivity)
    // We try to release from everywhere. We don't fail transition if release from "other side" fails
    // but we try our best to clear locks.
    
    // Always try to unmount from host
    let _ = unmount_vhd(vhd_path.clone()).await;

    // Always try to detach from target VM if provided
    if let Some(ref name) = vm_name {
        let _ = detach_vhd_from_vm(vhd_path.clone(), name.clone()).await;
    }

    // MANDATORY COOL-DOWN: Windows handle release latency mitigation
    tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;

    // 2. TARGET TRANSITION
    if target == "Host" {
        mount_vhd(vhd_path).await
    } else {
        let name = vm_name.ok_or_else(|| AppError::new("VHD Transition", "VM Name required for VM target"))?;
        
        // Snapshot protection: Hyper-V cannot attach a VHD if snapshots rely on it (AVHDX)
        let snapshot_check = format!("if (Get-VMSnapshot -VMName '{}' -ErrorAction SilentlyContinue) {{ Get-VMSnapshot -VMName '{}' | Remove-VMSnapshot -IncludeAllChildSnapshots -ErrorAction SilentlyContinue }}", name, name);
        let _ = tokio::process::Command::new("powershell")
            .args(["-NoProfile", "-NonInteractive", "-Command", &snapshot_check])
            .output()
            .await;

        // Final attempt to attach to VM
        attach_vhd_to_vm(vhd_path.clone(), name).await?;
        
        Ok(VhdInfo {
            path: vhd_path,
            attached: true,
            disk_number: None,
        })
    }
}
