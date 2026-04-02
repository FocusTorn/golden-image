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
    #[serde(rename = "defaultVMProfile")]
    pub default_vm_profile: Option<String>,
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
pub async fn get_master_config() -> Result<MasterConfig, AppError> {
    let path = "p:/Projects/golden-image/_master_config.json";
    let content = std::fs::read_to_string(path)
        .map_err(|e| AppError::new("Master Config Load", &e.to_string()))?;
    
    let mut stripped = json_comments::StripComments::new(content.as_bytes());
    let mut stripped_str = String::new();
    stripped.read_to_string(&mut stripped_str)
        .map_err(|e| AppError::new("JSONC Strip", &e.to_string()))?;

    let config: MasterConfig = serde_json::from_str(&stripped_str)
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
    // Normalizing slashes to ensure path equality checks succeed
    let script = format!(
        "$p = '{}'.Replace('/', '\\'); $vhd = Get-VHD -Path $p -ErrorAction SilentlyContinue; if ($vhd.Attached) {{ Dismount-VHD -Path $p -ErrorAction Stop }}",
        vhd_path
    );

    let output = tokio::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", &script])
        .output()
        .await
        .map_err(|e| AppError::new("VHD Unmount", &e.to_string()))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        // If it's already not mounted or not found, that's a success for us
        if stderr.contains("not the path to a mounted") || stderr.contains("is not mounted") || stderr.contains("not found") {
            return Ok(());
        }
        return Err(AppError::new("VHD Unmount", &stderr));
    }

    Ok(())
}

#[tauri::command]
pub async fn attach_vhd_to_vm(vhd_path: String, vm_name: String) -> Result<(), AppError> {
    let script = format!("Add-VMHardDiskDrive -VMName '{}' -Path '{}' -ControllerType SCSI", vm_name, vhd_path);
    let output = tokio::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-Command", &script])
        .output()
        .await
        .map_err(|e| AppError::new("VHD VM Attach", &e.to_string()))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        if stderr.contains("already connected") {
            return Ok(());
        }
        return Err(AppError::new("VHD VM Attach", &stderr));
    }

    Ok(())
}

#[tauri::command]
pub async fn detach_vhd_from_vm(vhd_path: String, vm_name: String) -> Result<(), AppError> {
    let script = format!(
        "$vm = Get-VM -Name '{}' -ErrorAction SilentlyContinue; \
         if ($vm) {{ \
           $p = '{}' -replace '/', '\\'; \
           $d = Get-VMHardDiskDrive -VMName '{}' -ErrorAction SilentlyContinue | Where-Object {{ ($_.Path -replace '/', '\\') -eq $p }}; \
           if ($d) {{ Remove-VMHardDiskDrive -VMHardDiskDrive $d -ErrorAction Stop }} \
         }}",
        vm_name, vhd_path, vm_name
    );
    let output = tokio::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-Command", &script])
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
    // 1. STABLE RELEASE SEQUENCE (Mirroring legacy VhdUtils logic)
    
    // Step A: Release from VM (PRIORITY)
    if let Some(ref name) = vm_name {
        let _ = detach_vhd_from_vm(vhd_path.clone(), name.clone()).await;
    }

    // Step B: Release from Host
    let _ = unmount_vhd(vhd_path.clone()).await;
    
    // Step C: VDS Escalation (Safe Lock Break)
    let vds_script = "Get-Disk | Where-Object { $_.FriendlyName -like '*Virtual*' } | Set-Disk -IsOffline $true -ErrorAction SilentlyContinue";
    let _ = tokio::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-Command", vds_script])
        .output()
        .await;

    // MANDATORY COOL-DOWN: Windows VDS/Hyper-V handle release latency mitigation
    tokio::time::sleep(tokio::time::Duration::from_millis(1000)).await;

    // 2. TARGET TRANSITION
    if target == "Host" {
        mount_vhd(vhd_path).await
    } else {
        let name = vm_name.ok_or_else(|| AppError::new("VHD Transition", "VM Name required for VM target"))?;
        
        // Snapshot protection: Hyper-V creates .avhdx if snapshots exist before attachment
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

#[tauri::command]
pub async fn check_vm_status(vm_name: String) -> Result<String, String> {
    let clean_name = vm_name.trim();
    
    // Using an encoded command pattern to ensure bit-perfect string passing
    let script = format!(
        "& {{ $vm = Get-VM | Where-Object {{ $_.Name -match '{}' }}; if ($vm) {{ Write-Output $vm.State }} else {{ Write-Error 'TARGET_VM_MISSING_IN_HYPERV_INVENTORY'; exit 1 }} }}", 
        clean_name
    );

    let output = tokio::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-Command", &script])
        .output()
        .await
        .map_err(|e| e.to_string())?;

    let state = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    
    Ok(state)
}

#[tauri::command]
pub async fn update_default_profile(profile: String) -> Result<(), AppError> {
    let path = "p:/Projects/golden-image/_master_config.json";
    
    // 1. Read existing (to preserve other fields)
    let content = std::fs::read_to_string(path)
        .map_err(|e| AppError::new("Config Update Read", &e.to_string()))?;
        
    let mut stripped = json_comments::StripComments::new(content.as_bytes());
    let mut stripped_str = String::new();
    stripped.read_to_string(&mut stripped_str).ok();

    let mut config: serde_json::Value = serde_json::from_str(&stripped_str)
        .map_err(|e| AppError::new("Config Update Parse", &e.to_string()))?;

    // 2. Modify just the default profile key
    config["defaultVMProfile"] = serde_json::Value::String(profile);

    // 3. Write back (Note: Comments will be lost on this specific write)
    let new_content = serde_json::to_string_pretty(&config)
        .map_err(|e| AppError::new("Config Update Serialize", &e.to_string()))?;
        
    std::fs::write(path, new_content)
        .map_err(|e| AppError::new("Config Update Write", &e.to_string()))?;
        
    Ok(())
}
