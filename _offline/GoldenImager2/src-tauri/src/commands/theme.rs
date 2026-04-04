use serde::Serialize;
use tauri::command;

#[derive(Serialize)]
#[serde(rename_all = "PascalCase")]
pub struct ThemeInfo {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub is_dark: bool,
}

#[command]
pub async fn get_theme_info() -> Result<ThemeInfo, String> {
    use winreg::RegKey;
    use winreg::enums::HKEY_CURRENT_USER;
    
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    
    let dwm_key = hkcu.open_subkey("Software\\Microsoft\\Windows\\DWM")
        .map_err(|e| format!("Failed to open DWM registry key: {}", e))?;
        
    let color_val: u32 = dwm_key.get_value("AccentColor")
        .map_err(|e| format!("Failed to read AccentColor: {}", e))?;
        
    let r = (color_val & 0xFF) as u8;
    let g = ((color_val >> 8) & 0xFF) as u8;
    let b = ((color_val >> 16) & 0xFF) as u8;
    
    let personalization = hkcu.open_subkey("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize")
        .map_err(|e| format!("Failed to open Personalize registry key: {}", e))?;
        
    let is_dark = personalization.get_value::<u32, _>("AppsUseLightTheme")
        .map(|v| v == 0)
        .map_err(|e| format!("Failed to read AppsUseLightTheme: {}", e))?;

    Ok(ThemeInfo { r, g, b, is_dark })
}

#[derive(Serialize)]
#[serde(rename_all = "PascalCase")]
pub struct DashboardStats {
    pub os_build: String,
    pub uptime: String,
    pub audit_mode: bool,
    pub connection: ConnectionAudit,
    pub stages: StagesAudit,
    pub vm_active: bool,
}

#[derive(Serialize)]
pub struct ConnectionAudit {
    #[serde(rename = "LimitBlank")]
    pub limit_blank: bool,
    #[serde(rename = "Winrm")]
    pub winrm: bool,
    #[serde(rename = "KeyIso")]
    pub keyiso: bool,
    #[serde(rename = "AdminEnabled")]
    pub admin_enabled: bool,
    #[serde(rename = "Rdp")]
    pub rdp: bool,
    #[serde(rename = "NetDiscovery")]
    pub net_discovery: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "PascalCase")]
pub struct StagesAudit {
    pub pwsh7: bool,
    pub msvc: bool,
    pub app_infra: bool,
}

#[command]
pub async fn get_dashboard_stats(target_vm: Option<String>) -> Result<DashboardStats, String> {
    if let Some(vm_name) = target_vm {
        if vm_name.trim().is_empty() {
             return Err("Target VM name cannot be empty for remote connection.".to_string());
        }
        return get_remote_stats(&vm_name).await;
    }

    use winreg::RegKey;
    use winreg::enums::HKEY_LOCAL_MACHINE;
    use std::path::Path;

    let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);
    let limit_blank = hklm.open_subkey("SYSTEM\\CurrentControlSet\\Control\\Lsa")
        .map_err(|e| format!("Failed to open LSA key: {}", e))?
        .get_value::<u32, _>("LimitBlankPasswordUse")
        .map(|v| v == 0)
        .map_err(|e| format!("Failed to read LimitBlankPasswordUse: {}", e))?;

    let winrm = check_service_status("WinRM");
    let keyiso = check_service_status("KeyIso");
    
    let admin_output = std::process::Command::new("net")
        .args(["user", "Administrator"])
        .output()
        .map_err(|e| format!("Failed to execute net user: {}", e))?;
        
    let admin_enabled = String::from_utf8_lossy(&admin_output.stdout).contains("Account active               Yes");

    let rdp = hklm.open_subkey("SYSTEM\\CurrentControlSet\\Control\\Terminal Server")
        .map(|k| k.get_value::<u32, _>("fDenyTSConnections").unwrap_or(1) == 0)
        .unwrap_or(false);

    let net_discovery = check_service_status("FDResPub");

    let pwsh7 = Path::new("C:\\Program Files\\PowerShell\\7\\pwsh.exe").exists();
    let msvc = hklm.open_subkey("SOFTWARE\\Classes\\Installer\\Dependencies\\VC,redist.x64,amd64,14.0,bundle").is_ok();
    let app_infra = check_command_exists("choco") || check_command_exists("winget");

    let os_build: String = hklm.open_subkey("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion")
        .map_err(|e| format!("Failed to open CurrentVersion key: {}", e))?
        .get_value("CurrentBuild")
        .map_err(|e| format!("Failed to read CurrentBuild: {}", e))?;

    // Fix: ImageState is a REG_SZ (string), not a u32. 
    // IMAGE_STATE_COMPLETE means normal. Other states (like UNDEPLOYABLE) often indicate audit/sysprep mode.
    let image_state: String = hklm.open_subkey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State")
        .map_err(|e| format!("Failed to open Setup State key: {}", e))?
        .get_value("ImageState")
        .map_err(|e| format!("Failed to read ImageState: {}", e))?;
    
    let audit_mode = image_state != "IMAGE_STATE_COMPLETE";

    let uptime_output = std::process::Command::new("powershell")
        .args(["-NoProfile", "-Command", "(get-date) - (gcim Win32_OperatingSystem).LastBootUpTime | Select-Object -ExpandProperty ToString"])
        .output()
        .map_err(|e| format!("Failed to get uptime via PowerShell: {}", e))?;
        
    let uptime = String::from_utf8_lossy(&uptime_output.stdout).trim().split('.').next()
        .ok_or_else(|| "Malformed uptime output".to_string())?
        .to_string();

    Ok(DashboardStats {
        os_build,
        uptime,
        audit_mode,
        connection: ConnectionAudit { limit_blank, winrm, keyiso, admin_enabled, rdp, net_discovery },
        stages: StagesAudit { pwsh7, msvc, app_infra },
        vm_active: true,
    })
}

async fn get_remote_stats(target_vm: &str) -> Result<DashboardStats, String> {
    let script = r#"
        $stats = @{
            OsBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild;
            Uptime = ((get-date) - (gcim Win32_OperatingSystem).LastBootUpTime).ToString().Split('.')[0];
            AuditMode = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State").ImageState -eq 1;
            LimitBlank = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa").LimitBlankPasswordUse -eq 0;
            WinRM = (Get-Service WinRM -ErrorAction SilentlyContinue).Status -eq 'Running';
            KeyIso = (Get-Service KeyIso -ErrorAction SilentlyContinue).Status -eq 'Running';
            AdminEnabled = (net user Administrator) -match 'Account active\s+Yes';
            RDP = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server").fDenyTSConnections -eq 0;
            NetDiscovery = (Get-Service FDResPub -ErrorAction SilentlyContinue).Status -eq 'Running';
            Pwsh7 = Test-Path "C:\Program Files\PowerShell\7\pwsh.exe";
            Msvc = Test-Path "HKLM:\SOFTWARE\Classes\Installer\Dependencies\VC,redist.x64,amd64,14.0,bundle";
            AppInfra = (Get-Command choco -ErrorAction SilentlyContinue) -or (Get-Command winget -ErrorAction SilentlyContinue);
        }
        $stats | ConvertTo-Json
    "#;

    // 1. Pre-fetch VM Power State to avoid hanging or misleading "connected" status
    let vm_check = std::process::Command::new("powershell")
        .args(["-NoProfile", "-Command", &format!("(Get-VM -Name '{}' -ErrorAction SilentlyContinue).State", target_vm)])
        .output()
        .map_err(|e| e.to_string())?;
    
    let vm_state = String::from_utf8_lossy(&vm_check.stdout).trim().to_string();
    if vm_state != "Running" {
        return Err(format!("Remote Target Offline: VM '{}' must be running (Current: {})", target_vm, if vm_state.is_empty() { "NOT_FOUND" } else { &vm_state }));
    }

    let (user, pass, _use_creds) = crate::utils::get_vm_auth_info()?;
    let auth_fragment = crate::utils::get_sac_safe_auth_fragment();

    let mut command = std::process::Command::new("powershell");
    command.env("VMU", user).env("VMP", pass);
    command.args(["-NoProfile", "-Command", &format!("{} Invoke-Command -VMName '{}' -ScriptBlock {{ {} }} @auth", auth_fragment, target_vm, script)]);

    let o = command.output().map_err(|e| e.to_string())?;

    if o.status.success() {
        let json = String::from_utf8_lossy(&o.stdout);
        match serde_json::from_str::<serde_json::Value>(&json) {
            Ok(data) => {
                return Ok(DashboardStats {
                    os_build: data["OsBuild"].as_str().ok_or("Remote missing OsBuild")?.to_string(),
                    uptime: data["Uptime"].as_str().ok_or("Remote missing Uptime")?.to_string(),
                    audit_mode: data["AuditMode"].as_bool().ok_or("Remote missing AuditMode")?,
                    connection: ConnectionAudit {
                        limit_blank: data["LimitBlank"].as_bool().ok_or("Remote missing LimitBlank")?,
                        winrm: data["WinRM"].as_bool().ok_or("Remote missing WinRM")?,
                        keyiso: data["KeyIso"].as_bool().ok_or("Remote missing KeyIso")?,
                        admin_enabled: data["AdminEnabled"].as_bool().ok_or("Remote missing AdminEnabled")?,
                        rdp: data["RDP"].as_bool().ok_or("Remote missing RDP")?,
                        net_discovery: data["NetDiscovery"].as_bool().ok_or("Remote missing NetDiscovery")?,
                    },
                    stages: StagesAudit {
                        pwsh7: data["Pwsh7"].as_bool().ok_or("Remote missing Pwsh7")?,
                        msvc: data["Msvc"].as_bool().ok_or("Remote missing Msvc")?,
                        app_infra: data["AppInfra"].as_bool().ok_or("Remote missing AppInfra")?,
                    },
                    vm_active: true,
                });
            },
            Err(e) => {
                let err_msg = format!("Remote Data Parse Error: {} (Raw: {})", e, json.trim());
                return Err(err_msg);
            }
        }
    }

    let stderr = String::from_utf8_lossy(&o.stderr);
    Err(if stderr.is_empty() { "Unknown Remote Command Failure (No Stderr)".to_string() } else { stderr.to_string() })
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
