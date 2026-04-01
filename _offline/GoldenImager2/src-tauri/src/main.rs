// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod audit;
mod config;
mod apps;

use serde::Serialize;

#[tauri::command]
async fn get_audit_results(app: tauri::AppHandle) -> Result<Vec<audit::AuditResult>, String> {
    let resource_path = resolve_path(&app, "config/Features.json")
        .ok_or("Failed to resolve Features.json")?;
    
    let reg_path = resolve_path(&app, "regfiles")
        .ok_or("Failed to resolve regfiles directory")?;

    let config = config::load_config(resource_path).map_err(|e| e.to_string())?;
    let results = audit::run_audit(&config.features, &reg_path);
    Ok(results)
}

#[tauri::command]
async fn get_features_config(app: tauri::AppHandle) -> Result<config::FeaturesConfig, String> {
    let resource_path = resolve_path(&app, "config/Features.json")
        .ok_or("Failed to resolve Features.json")?;
    
    config::load_config(resource_path).map_err(|e| e.to_string())
}

#[tauri::command]
async fn apply_feature(app: tauri::AppHandle, feature_id: String) -> Result<(), String> {
    let resource_path = resolve_path(&app, "config/Features.json")
        .ok_or("Failed to resolve Features.json")?;
    
    let reg_dir = resolve_path(&app, "regfiles")
        .ok_or("Failed to resolve regfiles directory")?;

    let config = config::load_config(resource_path).map_err(|e| e.to_string())?;
    let feature = config.features.iter().find(|f| f.feature_id == feature_id)
        .ok_or_else(|| format!("Feature not found: {}", feature_id))?;

    if let Some(reg_file) = &feature.registry_key {
        let full_path = reg_dir.join(reg_file);
        if !full_path.exists() {
            return Err(format!("Registry file not found: {:?}", full_path));
        }

        let output = std::process::Command::new("reg")
            .args(["import", full_path.to_str().unwrap()])
            .output()
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let err = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Failed to import registry: {}", err));
        }
    }

    if let Some(script) = &feature.invoke_script {
        let output = std::process::Command::new("powershell")
            .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script])
            .output()
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let err = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Feature script failed: {}", err));
        }
    }

    Ok(())
}

#[tauri::command]
async fn undo_feature(app: tauri::AppHandle, feature_id: String) -> Result<(), String> {
    let resource_path = resolve_path(&app, "config/Features.json")
        .ok_or("Failed to resolve Features.json")?;
    
    let reg_dir = resolve_path(&app, "regfiles")
        .ok_or("Failed to resolve regfiles directory")?;

    let config = config::load_config(resource_path).map_err(|e| e.to_string())?;
    let feature = config.features.iter().find(|f| f.feature_id == feature_id)
        .ok_or_else(|| format!("Feature not found: {}", feature_id))?;

    if let Some(reg_file) = &feature.registry_undo_key {
        let full_path = reg_dir.join(reg_file);
        if !full_path.exists() {
            return Err(format!("Undo registry file not found: {:?}", full_path));
        }

        let output = std::process::Command::new("reg")
            .args(["import", full_path.to_str().unwrap()])
            .output()
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let err = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Failed to import undo registry: {}", err));
        }
    }

    if let Some(script) = &feature.undo_script {
        let output = std::process::Command::new("powershell")
            .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script])
            .output()
            .map_err(|e| e.to_string())?;

        if !output.status.success() {
            let err = String::from_utf8_lossy(&output.stderr);
            return Err(format!("Undo script failed: {}", err));
        }
    }

    Ok(())
}

#[derive(Serialize)]
#[allow(non_snake_case)]
pub struct ThemeInfo {
    pub R: u8,
    pub G: u8,
    pub B: u8,
    pub IsDark: bool,
}

#[tauri::command]
async fn get_theme_info() -> ThemeInfo {
    use winreg::RegKey;
    use winreg::enums::HKEY_CURRENT_USER;
    
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    
    // Default Windows Blue (0x0078D4 in ABGR)
    let (r, g, b, is_dark) = if let Ok(dwm_key) = hkcu.open_subkey("Software\\Microsoft\\Windows\\DWM") {
        let color_val: u32 = dwm_key.get_value("AccentColor").unwrap_or(0xFFD47800);
        /* #[cfg(debug_assertions)]
        println!("[DEBUG] Registry AccentColor: 0x{:08X}", color_val); */
        
        let r = (color_val & 0xFF) as u8;
        let g = ((color_val >> 8) & 0xFF) as u8;
        let b = ((color_val >> 16) & 0xFF) as u8;
        
        let personalization = hkcu.open_subkey("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize");
        let is_dark = personalization.and_then(|k| k.get_value::<u32, _>("AppsUseLightTheme")).map(|v| v == 0).unwrap_or(true);
        
        /* #[cfg(debug_assertions)]
        println!("[DEBUG] Parsed Theme: R={}, G={}, B={}, DarkMode={}", r, g, b, is_dark); */
        
        (r, g, b, is_dark)
    } else {
        /* #[cfg(debug_assertions)]
        println!("[DEBUG] DWM registry key not found, using default blue."); */
        (0, 120, 212, true)
    };

    ThemeInfo { R: r, G: g, B: b, IsDark: is_dark }
}

#[derive(Serialize)]
pub struct DashboardStats {
    pub connection: ConnectionAudit,
    pub stages: StagesAudit,
}

#[derive(Serialize)]
pub struct ConnectionAudit {
    pub limit_blank: bool,
    pub winrm: bool,
    pub keyiso: bool,
    pub admin_enabled: bool,
}

#[derive(Serialize)]
pub struct StagesAudit {
    pub pwsh7: bool,
    pub msvc: bool,
    pub app_infra: bool,
}

#[tauri::command]
async fn get_dashboard_stats() -> DashboardStats {
    use winreg::RegKey;
    use winreg::enums::HKEY_LOCAL_MACHINE;
    use std::path::Path;

    let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);
    
    // 1. Connection Audit
    let limit_blank = hklm.open_subkey("SYSTEM\\CurrentControlSet\\Control\\Lsa")
        .and_then(|k| k.get_value::<u32, _>("LimitBlankPasswordUse"))
        .map(|v| v == 0).unwrap_or(false);

    let winrm = check_service_status("WinRM");
    let keyiso = check_service_status("KeyIso");
    
    // Quick check for Administrator status (simplified for this turn)
    let admin_enabled = std::process::Command::new("net")
        .args(["user", "Administrator"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).contains("Account active               Yes"))
        .unwrap_or(false);

    // 2. Stages Audit
    let pwsh7 = Path::new("C:\\Program Files\\PowerShell\\7\\pwsh.exe").exists();
    let msvc = hklm.open_subkey("SOFTWARE\\Classes\\Installer\\Dependencies\\VC,redist.x64,amd64,14.0,bundle").is_ok();
    
    // Check for choco or winget
    let app_infra = check_command_exists("choco") || check_command_exists("winget");

    DashboardStats {
        connection: ConnectionAudit {
            limit_blank,
            winrm,
            keyiso,
            admin_enabled,
        },
        stages: StagesAudit {
            pwsh7,
            msvc,
            app_infra,
        }
    }
}

fn check_service_status(name: &str) -> bool {
    #[cfg(windows)]
    {
        use windows::Win32::System::Services::{
            OpenSCManagerW, OpenServiceW, QueryServiceStatusEx, CloseServiceHandle,
            SC_MANAGER_CONNECT, SERVICE_QUERY_STATUS, SC_STATUS_PROCESS_INFO,
            SERVICE_STATUS_PROCESS, SERVICE_RUNNING
        };
        use windows::core::HSTRING;

        unsafe {
            let scm = OpenSCManagerW(None, None, SC_MANAGER_CONNECT);
            if let Ok(scm_handle) = scm {
                let service = OpenServiceW(scm_handle, &HSTRING::from(name), SERVICE_QUERY_STATUS);
                if let Ok(service_handle) = service {
                    let mut status = SERVICE_STATUS_PROCESS::default();
                    let mut bytes_needed = 0;
                    let buffer = std::slice::from_raw_parts_mut(
                        &mut status as *mut _ as *mut u8,
                        std::mem::size_of::<SERVICE_STATUS_PROCESS>()
                    );
                    let success = QueryServiceStatusEx(
                        service_handle,
                        SC_STATUS_PROCESS_INFO,
                        Some(buffer),
                        &mut bytes_needed
                    );
                    let _ = CloseServiceHandle(service_handle);
                    let _ = CloseServiceHandle(scm_handle);
                    return success.is_ok() && status.dwCurrentState == SERVICE_RUNNING;
                }
                let _ = CloseServiceHandle(scm_handle);
            }
        }
    }
    false
}

fn check_command_exists(cmd: &str) -> bool {
    std::process::Command::new("where.exe")
        .arg(cmd)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

#[tauri::command]
async fn run_provisioning_stage(stage: u32, window: tauri::Window) -> Result<(), String> {
    use std::process::{Command, Stdio};
    use std::io::{BufRead, BufReader};

    let script_name = match stage {
        1 => "1_Scoop.ps1",
        2 => "2_MSVC.ps1",
        3 => "3_System_Apps.ps1",
        4 => "4_Rust_Finish.ps1",
        5 => "5_Finalize.ps1",
        6 => "Customize.ps1",
        _ => return Err("Invalid stage".to_string()),
    };

    // In a real scenario, these would be in resources/scripts
    // For now, we'll try to find them in the project root or resources
    let script_path = format!("resources/scripts/{}", script_name);

    let mut child = Command::new("powershell")
        .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", &script_path])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Failed to spawn process: {}", e))?;

    let stdout = child.stdout.take().unwrap();
    let reader = BufReader::new(stdout);

    for line in reader.lines() {
        if let Ok(l) = line {
            // Emit log event to frontend
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

#[tauri::command]
async fn install_app(app_id: String, app_name: String, is_system: bool, window: tauri::Window) -> Result<(), String> {
    use std::process::{Command, Stdio};
    use std::io::{BufRead, BufReader};

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

    let stdout = child.stdout.take().unwrap();
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

#[tauri::command]
async fn minimize_window(window: tauri::Window) -> Result<(), String> {
    window.minimize().map_err(|e| e.to_string())
}

#[tauri::command]
async fn close_window(window: tauri::Window) -> Result<(), String> {
    window.close().map_err(|e| e.to_string())
}

fn resolve_path(app: &tauri::AppHandle, path: &str) -> Option<std::path::PathBuf> {
    /* #[cfg(debug_assertions)]
    println!("[DEBUG] resolve_path beginning for: '{}'", path); */

    // 1. Try Tauri's resolver
    if let Some(r) = app.path_resolver().resolve_resource(path) {
        /* #[cfg(debug_assertions)]
        println!("[DEBUG]   Testing Tauri resolve: {:?} (Exists: {})", r, r.exists()); */
        if r.exists() { return Some(r); }
    }
    
    // 2. Try prefixed with resources/
    if let Some(r) = app.path_resolver().resolve_resource(format!("resources/{}", path)) {
        /* #[cfg(debug_assertions)]
        println!("[DEBUG]   Testing Tauri prefix resolve: {:?} (Exists: {})", r, r.exists()); */
        if r.exists() { return Some(r); }
    }

    // 3. Try relative to CWD
    let cwd_path = std::path::Path::new("resources").join(path);
    /* #[cfg(debug_assertions)]
    println!("[DEBUG]   Testing CWD/resources: {:?} (Exists: {})", cwd_path, cwd_path.exists()); */
    if cwd_path.exists() { return Some(cwd_path); }

    // 4. Try parent's resources
    let parent_path = std::path::Path::new("../resources").join(path);
    /* #[cfg(debug_assertions)]
    println!("[DEBUG]   Testing ../resources: {:?} (Exists: {})", parent_path, parent_path.exists()); */
    if parent_path.exists() { return Some(parent_path); }

    // 5. Try parent's src-tauri resources
    let src_tauri_path = std::path::Path::new("src-tauri/resources").join(path);
    /* #[cfg(debug_assertions)]
    println!("[DEBUG]   Testing src-tauri/resources: {:?} (Exists: {})", src_tauri_path, src_tauri_path.exists()); */
    if src_tauri_path.exists() { return Some(src_tauri_path); }

    /* #[cfg(debug_assertions)]
    println!("[DEBUG] !!! All resolve_path attempts failed for '{}'", path); */
    None
}

#[tauri::command]
async fn list_app_profiles(app: tauri::AppHandle) -> Result<Vec<String>, String> {
    let profile_dir = resolve_path(&app, "config/AppProfiles")
        .ok_or("Failed to resolve AppProfiles directory")?;
    
    if !profile_dir.exists() {
        return Ok(Vec::new());
    }

    let mut profiles = Vec::new();
    for entry in std::fs::read_dir(profile_dir).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        let path = entry.path();
        if path.is_file() && path.extension().map_or(false, |ext| ext == "json") {
            if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                profiles.push(name.to_string());
            }
        }
    }
    Ok(profiles)
}

#[tauri::command]
async fn load_app_profile(app: tauri::AppHandle, name: String) -> Result<Vec<String>, String> {
    let profile_path = resolve_path(&app, &format!("config/AppProfiles/{}", name))
        .ok_or_else(|| format!("Profile {} not found", name))?;
    
    let content = std::fs::read_to_string(profile_path).map_err(|e| e.to_string())?;
    let stripped = json_comments::StripComments::new(content.as_bytes());
    let profile: serde_json::Value = serde_json::from_reader(stripped).map_err(|e| e.to_string())?;
    
    let apps = profile["Apps"].as_array()
        .ok_or("Invalid profile format: missing 'Apps' array")?
        .iter()
        .filter_map(|v| v.as_str().map(|s| s.to_string()))
        .collect();
        
    Ok(apps)
}

#[tauri::command]
async fn save_app_profile(app: tauri::AppHandle, name: String, app_ids: Vec<String>) -> Result<(), String> {
    let profile_dir = resolve_path(&app, "config/AppProfiles")
        .ok_or("Failed to resolve AppProfiles directory")?;
    
    if !profile_dir.exists() {
        std::fs::create_dir_all(&profile_dir).map_err(|e| e.to_string())?;
    }

    let profile_path = profile_dir.join(if name.ends_with(".json") { name } else { format!("{}.json", name) });
    
    let profile = serde_json::json!({
        "Apps": app_ids
    });
    
    let content = serde_json::to_string_pretty(&profile).map_err(|e| e.to_string())?;
    std::fs::write(profile_path, content).map_err(|e| e.to_string())?;
    
    Ok(())
}

#[tauri::command]
async fn delete_app_profile(app: tauri::AppHandle, name: String) -> Result<(), String> {
    let profile_path = resolve_path(&app, &format!("config/AppProfiles/{}", name))
        .ok_or_else(|| format!("Profile {} not found", name))?;
    
    if profile_path.exists() {
        std::fs::remove_file(profile_path).map_err(|e| e.to_string())?;
    }
    
    Ok(())
}

#[tauri::command]
async fn list_tweak_profiles(app: tauri::AppHandle) -> Result<Vec<String>, String> {
    let config_dir = resolve_path(&app, "config")
        .ok_or("Failed to resolve config directory")?;
    
    let profile_dir = config_dir.join("TweakProfiles");
    if !profile_dir.exists() {
        return Ok(Vec::new());
    }

    let mut profiles = Vec::new();
    for entry in std::fs::read_dir(profile_dir).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        let path = entry.path();
        if path.is_file() && path.extension().map_or(false, |ext| ext == "json") {
            if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                profiles.push(name.to_string());
            }
        }
    }
    Ok(profiles)
}

#[derive(Serialize, serde::Deserialize)]
pub struct TweakSetting {
    #[serde(rename = "Name")]
    pub name: String,
    #[serde(rename = "Value")]
    pub value: serde_json::Value,
}

#[derive(Serialize, serde::Deserialize)]
pub struct TweakProfile {
    #[serde(rename = "Version")]
    pub version: String,
    #[serde(rename = "Settings")]
    pub settings: Vec<TweakSetting>,
}

#[tauri::command]
async fn load_tweak_profile(app: tauri::AppHandle, name: String) -> Result<Vec<TweakSetting>, String> {
    let config_dir = resolve_path(&app, "config")
        .ok_or("Failed to resolve config directory")?;
    let profile_path = config_dir.join("TweakProfiles").join(if name.ends_with(".json") { name.clone() } else { format!("{}.json", name) });
    
    if !profile_path.exists() {
        return Err(format!("Profile {} not found", name));
    }
    
    let content = std::fs::read_to_string(profile_path).map_err(|e| e.to_string())?;
    let stripped = json_comments::StripComments::new(content.as_bytes());
    let profile: TweakProfile = serde_json::from_reader(stripped).map_err(|e| e.to_string())?;
    
    Ok(profile.settings)
}

#[tauri::command]
async fn save_tweak_profile(app: tauri::AppHandle, name: String, settings: Vec<TweakSetting>) -> Result<(), String> {
    let config_dir = resolve_path(&app, "config")
        .ok_or("Failed to resolve config directory")?;
    
    let profile_dir = config_dir.join("TweakProfiles");
    if !profile_dir.exists() {
        std::fs::create_dir_all(&profile_dir).map_err(|e| e.to_string())?;
    }

    let profile_path = profile_dir.join(if name.ends_with(".json") { name } else { format!("{}.json", name) });
    
    let profile = TweakProfile {
        version: "1.0".to_string(),
        settings,
    };
    
    let content = serde_json::to_string_pretty(&profile).map_err(|e| e.to_string())?;
    std::fs::write(profile_path, content).map_err(|e| e.to_string())?;
    
    Ok(())
}

#[tauri::command]
async fn delete_tweak_profile(app: tauri::AppHandle, name: String) -> Result<(), String> {
    let config_dir = resolve_path(&app, "config")
        .ok_or("Failed to resolve config directory")?;
    let profile_path = config_dir.join("TweakProfiles").join(if name.ends_with(".json") { name } else { format!("{}.json", name) });
    
    if profile_path.exists() {
        std::fs::remove_file(profile_path).map_err(|e| e.to_string())?;
    }
    
    Ok(())
}

#[tauri::command]
async fn get_apps(app: tauri::AppHandle) -> Result<Vec<apps::AppEntry>, String> {
    let mut resource_path = resolve_path(&app, "config/Apps.json");
    
    // Fallback for dev mode: prioritized original GoldenImager path
    if resource_path.is_none() || (resource_path.is_some() && !resource_path.as_ref().unwrap().exists()) {
        /* println!("[DEBUG] resolve_resource failed or path missing, trying original imager fallback..."); */
        let original_path = std::path::Path::new("../GoldenImager/Foundation/Win11Debloat/Config/Apps.json");
        if original_path.exists() {
            resource_path = Some(original_path.to_path_buf());
        } else {
            // Local dev fallbacks
            let dev_path = std::path::Path::new("resources/config/Apps.json");
            if dev_path.exists() {
                resource_path = Some(dev_path.to_path_buf());
            } else {
                let parent_dev_path = std::path::Path::new("../resources/config/Apps.json");
                 if parent_dev_path.exists() {
                    resource_path = Some(parent_dev_path.to_path_buf());
                 }
            }
        }
    }

    let path = resource_path.ok_or_else(|| {
        let cwd = std::env::current_dir().unwrap_or_default();
        format!("Apps.json not found. CWD: {:?}. Please ensure resources/config/Apps.json exists.", cwd)
    })?;

    #[cfg(debug_assertions)]
    // println!("[DEBUG] Final resolved path for get_apps: {:?}", path);

    // Load config for recommendations
    let config = apps::load_apps_config(&path).map_err(|e| format!("Failed to read/parse {:?}: {}", path, e))?;
    
// Scan system with integrated merge logic
    Ok(apps::scan_installed_apps(&config.apps))
}

#[tauri::command]
fn log_geometry(container: f64, scroll: f64, data: f64) {
    println!("[GEOMETRY] Container: {:.1}px, Scroll: {:.1}px, Data: {:.1}px", container, scroll, data);
}

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            #[cfg(windows)]
            {
                use tauri::Manager;

                if let Some(window) = app.get_window("main") {
                    if let Ok(hwnd) = window.hwnd() {
                        unsafe {
                            type HWND = isize;
                            extern "system" {
                                fn LoadImageW(hinst: isize, lpszName: *const u16, uType: u32, cxDesired: i32, cyDesired: i32, fuLoad: u32) -> isize;
                                fn SendMessageW(hWnd: HWND, Msg: u32, wParam: usize, lParam: isize) -> isize;
                            }
                            const WM_SETICON: u32 = 0x0080;
                            const ICON_BIG: usize = 1;
                            const IMAGE_ICON: u32 = 1;
                            const LR_LOADFROMFILE: u32 = 0x00000010;

                            let path: Vec<u16> = "P:\\Projects\\golden-image\\_offline\\GoldenImager2\\src\\assets\\taskbar.ico".encode_utf16().chain(Some(0)).collect();
                            let hicon = LoadImageW(0, path.as_ptr(), IMAGE_ICON, 0, 0, LR_LOADFROMFILE);
                            
                            if hicon != 0 {
                                SendMessageW(hwnd.0, WM_SETICON, ICON_BIG, hicon);
                            }
                        }
                    }
                }
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_audit_results, 
            get_features_config, 
            apply_feature, 
            undo_feature, 
            get_apps, 
            list_app_profiles,
            load_app_profile,
            save_app_profile,
            delete_app_profile,
            list_tweak_profiles,
            load_tweak_profile,
            save_tweak_profile,
            delete_tweak_profile,
            get_theme_info,
            get_dashboard_stats,
            run_provisioning_stage,
            install_app,
            minimize_window,
            close_window,
            log_geometry
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
