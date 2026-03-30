use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use windows::Win32::System::Registry::{HKEY, HKEY_LOCAL_MACHINE, RegOpenKeyExW, KEY_READ, RegEnumKeyExW};
use windows::core::{PCWSTR, PWSTR};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AppConfig {
    #[serde(rename = "Apps")]
    pub apps: Vec<AppEntry>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "PascalCase")]
pub struct AppEntry {
    pub app_id: String,
    pub friendly_name: String,
    pub recommendation: String,
    #[serde(default = "default_category")]
    pub category: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub publisher: Option<String>,
    #[serde(default)]
    pub version: Option<String>,
    #[serde(default)]
    pub install_date: Option<String>,
    #[serde(default)]
    pub is_curated: bool,
    #[serde(default)]
    pub is_installed: bool,
    #[serde(default)]
    pub is_provisioned: bool,
    #[serde(default)]
    pub is_user: bool,
    #[serde(default)]
    pub origin_type: String, // "Registry", "Appx", "Provisioned"
    #[serde(default)]
    pub uninstall_string: Option<String>,
}

fn default_category() -> String {
    "General".to_string()
}


pub fn load_apps_config<P: AsRef<Path>>(path: P) -> Result<AppConfig, Box<dyn std::error::Error>> {
    let content = fs::read_to_string(path)?;
    let config: AppConfig = serde_json::from_str(&content)?;
    Ok(config)
}

pub fn scan_installed_apps(config_apps: &Vec<AppEntry>) -> Vec<AppEntry> {
    use windows::Win32::System::Registry::HKEY_CURRENT_USER;
    
    let mut system_apps = Vec::new();
    
    // Registry Scan
    let registry_paths = [
        (HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"),
        (HKEY_LOCAL_MACHINE, "SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"),
        (HKEY_CURRENT_USER, "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall"),
    ];
    for (hkey_root, subkey) in registry_paths {
        if let Ok(mut discovered) = scan_registry_key(hkey_root, subkey) {
            for app in &mut discovered { app.origin_type = "Registry".to_string(); }
            system_apps.append(&mut discovered);
        }
    }
    
    // Appx Scan (User)
    if let Ok(mut appx_apps) = scan_appx_packages() {
        for app in &mut appx_apps { app.origin_type = "Appx".to_string(); }
        system_apps.append(&mut appx_apps);
    }

    // Provisioned Appx Scan
    if let Ok(mut prov_apps) = scan_appx_provisioned_packages() {
        for app in &mut prov_apps { 
            app.origin_type = "Provisioned".to_string();
            app.uninstall_string = Some(format!("Remove-AppxProvisionedPackage -Online -PackageName {}", app.app_id));
        }
        system_apps.append(&mut prov_apps);
    }
    
    let mut final_list = Vec::new();
    let mut matched_indices = std::collections::HashSet::new();

    // PASS 1: CURATED POLICY APPS
    for policy_app in config_apps {
        let mut app = policy_app.clone();
        app.is_curated = true;
        
        let system_match = system_apps.iter().position(|s| {
            s.app_id.to_lowercase() == policy_app.app_id.to_lowercase() ||
            s.friendly_name.to_lowercase() == policy_app.friendly_name.to_lowercase()
        });

        if let Some(idx) = system_match {
            let sys = &system_apps[idx];
            app.publisher = sys.publisher.clone();
            app.version = sys.version.clone();
            app.install_date = sys.install_date.clone();
            app.is_installed = true;
            app.is_provisioned = sys.origin_type == "Provisioned";
            app.is_user = sys.origin_type == "Appx" || sys.origin_type == "Registry";
            app.origin_type = sys.origin_type.clone();
            matched_indices.insert(idx);
        } else {
            app.is_installed = false;
        }
        final_list.push(app);
    }

    // PASS 2: NON-CURATED SYSTEM APPS (Extras)
    for (i, sys) in system_apps.iter().enumerate() {
        if !matched_indices.contains(&i) {
            let mut app = sys.clone();
            app.is_curated = false;
            app.is_installed = true;
            app.is_provisioned = sys.origin_type == "Provisioned";
            app.is_user = sys.origin_type == "Appx" || sys.origin_type == "Registry";
            app.recommendation = "optional".to_string();
            app.description = format!("(Unlisted System App - {})", sys.origin_type);
            final_list.push(app);
        }
    }

    final_list.sort_by(|a, b| a.friendly_name.to_lowercase().cmp(&b.friendly_name.to_lowercase()));
    final_list.dedup_by(|a, b| a.app_id == b.app_id);
    final_list
}

fn scan_appx_packages() -> Result<Vec<AppEntry>, Box<dyn std::error::Error>> {
    use std::process::Command;
    let output = Command::new("powershell")
        .args([
            "-NoProfile",
            "-Command",
            "Get-AppxPackage | Select-Object Name, PackageFullName, Publisher, Version | ConvertTo-Json"
        ])
        .output()?;

    parse_appx_json(output.stdout)
}

fn scan_appx_provisioned_packages() -> Result<Vec<AppEntry>, Box<dyn std::error::Error>> {
    use std::process::Command;
    let output = Command::new("powershell")
        .args([
            "-NoProfile",
            "-Command",
            "Get-AppxProvisionedPackage -Online | Select-Object @{N='Name';E={$_.DisplayName}}, @{N='PackageFullName';E={$_.PackageName}}, Publisher, Version | ConvertTo-Json"
        ])
        .output()?;

    parse_appx_json(output.stdout)
}

fn parse_appx_json(stdout: Vec<u8>) -> Result<Vec<AppEntry>, Box<dyn std::error::Error>> {
    let json: serde_json::Value = serde_json::from_slice(&stdout)?;
    let mut apps = Vec::new();

    if let Some(array) = json.as_array() {
        for item in array {
            let name = item["Name"].as_str().unwrap_or("").to_string();
            let app_id = item["PackageFullName"].as_str().unwrap_or("").to_string();
            if name.is_empty() || app_id.is_empty() { continue; }
            
            let publisher = item["Publisher"].as_str().map(|s| s.to_string());
            let version = item["Version"].as_str().map(|s| s.to_string());

            apps.push(AppEntry {
                app_id,
                friendly_name: name,
                recommendation: "optional".to_string(),
                category: "Appx".to_string(),
                description: "".to_string(),
                publisher,
                version,
                install_date: None,
                is_curated: false,
                is_installed: false,
                is_provisioned: false,
                is_user: false,
                origin_type: "".to_string(),
                uninstall_string: Some(format!("Remove-AppxPackage -Package {}", app_id)),
            });
        }
    } else if let Some(obj) = json.as_object() {
        // Handle single object return
        let name = obj["Name"].as_str().unwrap_or("").to_string();
        let app_id = obj["PackageFullName"].as_str().unwrap_or("").to_string();
        if !name.is_empty() && !app_id.is_empty() {
             apps.push(AppEntry {
                app_id: app_id.clone(),
                friendly_name: name,
                recommendation: "optional".to_string(),
                category: "Appx".to_string(),
                description: "".to_string(),
                publisher: obj["Publisher"].as_str().map(|s| s.to_string()),
                version: obj["Version"].as_str().map(|s| s.to_string()),
                install_date: None,
                is_curated: false,
                is_installed: false,
                is_provisioned: false,
                is_user: false,
                origin_type: "".to_string(),
                uninstall_string: Some(format!("Remove-AppxPackage -Package {}", app_id)),
            });
        }
    }

    Ok(apps)
}

fn scan_registry_key(root: HKEY, subkey_path: &str) -> Result<Vec<AppEntry>, Box<dyn std::error::Error>> {
    let mut apps = Vec::new();
    let mut hkey = HKEY::default();
    let subkey_wide: Vec<u16> = subkey_path.encode_utf16().chain(Some(0)).collect();

    unsafe {
        if RegOpenKeyExW(root, PCWSTR(subkey_wide.as_ptr()), 0, KEY_READ, &mut hkey).is_ok() {
            let mut index = 0;
            loop {
                let mut name = [0u16; 256];
                let mut name_len = name.len() as u32;
                if RegEnumKeyExW(hkey, index, PWSTR(name.as_mut_ptr()), &mut name_len, None, PWSTR(std::ptr::null_mut()), None, None).is_err() {
                    break;
                }
                
                // Get subkey name as fallback
                let subkey_name_str = String::from_utf16_lossy(&name[..name_len as usize]);

                if let Ok(app) = get_app_details(hkey, PCWSTR(name.as_ptr()), &subkey_name_str) {
                    if !app.friendly_name.is_empty() {
                        apps.push(app);
                    }
                }
                index += 1;
            }
        }
    }
    Ok(apps)
}

fn get_app_details(parent_key: HKEY, subkey_name: PCWSTR, fallback_name: &str) -> Result<AppEntry, Box<dyn std::error::Error>> {
    let mut hkey = HKEY::default();
    unsafe {
        RegOpenKeyExW(parent_key, subkey_name, 0, KEY_READ, &mut hkey).map_err(|e| e.to_string())?;
        
        // Use RegGetValueW for safer reading
        let mut friendly_name = read_reg_string(hkey, "DisplayName").unwrap_or_default();
        if friendly_name.is_empty() {
            friendly_name = fallback_name.to_string();
        }
        
        let publisher = read_reg_string(hkey, "Publisher");
        let version = read_reg_string(hkey, "DisplayVersion");
        let install_date = read_reg_string(hkey, "InstallDate");
        
        let app_id = fallback_name.to_string();

        Ok(AppEntry {
            app_id,
            friendly_name,
            recommendation: "optional".to_string(),
            category: "Installed".to_string(),
            description: "".to_string(),
            publisher,
            version,
            install_date,
            is_curated: false,
            is_installed: false,
            is_provisioned: false,
            is_user: false,
            origin_type: "".to_string(),
            uninstall_string: read_reg_string(hkey, "UninstallString"),
        })
    }
}

fn read_reg_string(key: HKEY, value_name: &str) -> Option<String> {
    use windows::Win32::System::Registry::{RegGetValueW, RRF_RT_REG_SZ};
    
    let value_wide: Vec<u16> = value_name.encode_utf16().chain(Some(0)).collect();
    let mut buffer = [0u16; 512];
    let mut buffer_len = (buffer.len() * 2) as u32;
    
    unsafe {
        if RegGetValueW(
            key,
            PCWSTR(std::ptr::null()),
            PCWSTR(value_wide.as_ptr()),
            RRF_RT_REG_SZ,
            None,
            Some(buffer.as_mut_ptr() as *mut _),
            Some(&mut buffer_len as *mut _)
        ).is_ok() {
            let actual_len = (buffer_len / 2) as usize;
            let end = if actual_len > 0 && buffer[actual_len - 1] == 0 { actual_len - 1 } else { actual_len };
            return Some(String::from_utf16_lossy(&buffer[..end]));
        }
    }
    None
}
