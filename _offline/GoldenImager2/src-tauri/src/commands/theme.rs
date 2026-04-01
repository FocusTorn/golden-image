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
pub async fn get_theme_info() -> ThemeInfo {
    use winreg::RegKey;
    use winreg::enums::HKEY_CURRENT_USER;
    
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    
    let (r, g, b, is_dark) = if let Ok(dwm_key) = hkcu.open_subkey("Software\\Microsoft\\Windows\\DWM") {
        let color_val: u32 = dwm_key.get_value("AccentColor").unwrap_or(0xFFD47800);
        let r = (color_val & 0xFF) as u8;
        let g = ((color_val >> 8) & 0xFF) as u8;
        let b = ((color_val >> 16) & 0xFF) as u8;
        let personalization = hkcu.open_subkey("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize");
        let is_dark = personalization.and_then(|k| k.get_value::<u32, _>("AppsUseLightTheme")).map(|v| v == 0).unwrap_or(true);
        (r, g, b, is_dark)
    } else {
        (0, 120, 212, true)
    };

    ThemeInfo { r, g, b, is_dark }
}

#[derive(Serialize)]
#[serde(rename_all = "PascalCase")]
pub struct DashboardStats {
    pub os_build: String,
    pub uptime: String,
    pub audit_mode: bool,
    pub connection: ConnectionAudit,
    pub stages: StagesAudit,
}

#[derive(Serialize)]
#[serde(rename_all = "PascalCase")]
pub struct ConnectionAudit {
    pub limit_blank: bool,
    pub winrm: bool,
    pub keyiso: bool,
    pub admin_enabled: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "PascalCase")]
pub struct StagesAudit {
    pub pwsh7: bool,
    pub msvc: bool,
    pub app_infra: bool,
}

#[command]
pub async fn get_dashboard_stats(target_vm: Option<String>) -> DashboardStats {
    if let Some(vm_name) = target_vm {
        return get_remote_stats(&vm_name).await;
    }

    use winreg::RegKey;
    use winreg::enums::HKEY_LOCAL_MACHINE;
    use std::path::Path;

    let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);
    let limit_blank = hklm.open_subkey("SYSTEM\\CurrentControlSet\\Control\\Lsa")
        .and_then(|k| k.get_value::<u32, _>("LimitBlankPasswordUse"))
        .map(|v| v == 0).unwrap_or(false);

    let winrm = check_service_status("WinRM");
    let keyiso = check_service_status("KeyIso");
    let admin_enabled = std::process::Command::new("net")
        .args(["user", "Administrator"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).contains("Account active               Yes"))
        .unwrap_or(false);

    let pwsh7 = Path::new("C:\\Program Files\\PowerShell\\7\\pwsh.exe").exists();
    let msvc = hklm.open_subkey("SOFTWARE\\Classes\\Installer\\Dependencies\\VC,redist.x64,amd64,14.0,bundle").is_ok();
    let app_infra = check_command_exists("choco") || check_command_exists("winget");

    let os_build = hklm.open_subkey("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion")
        .and_then(|k| {
            let build: String = k.get_value("CurrentBuild").unwrap_or_default();
            Ok(build)
        })
        .unwrap_or_else(|_| "22631".to_string());

    let audit_mode = hklm.open_subkey("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State")
        .and_then(|k| k.get_value::<u32, _>("ImageState"))
        .unwrap_or(0) == 1;

    let uptime = std::process::Command::new("powershell")
        .args(["-NoProfile", "-Command", "(get-date) - (gcim Win32_OperatingSystem).LastBootUpTime | Select-Object -ExpandProperty ToString"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().split('.').next().unwrap_or("00:00:00").to_string())
        .unwrap_or_else(|_| "00:00:00".to_string());

    DashboardStats {
        os_build,
        uptime,
        audit_mode,
        connection: ConnectionAudit { limit_blank, winrm, keyiso, admin_enabled },
        stages: StagesAudit { pwsh7, msvc, app_infra }
    }
}

async fn get_remote_stats(vm_name: &str) -> DashboardStats {
    let script = r#"
        $stats = @{
            OsBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild;
            Uptime = ((get-date) - (gcim Win32_OperatingSystem).LastBootUpTime).ToString().Split('.')[0];
            AuditMode = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State").ImageState -eq 1;
            LimitBlank = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa").LimitBlankPasswordUse -eq 0;
            WinRM = (Get-Service WinRM -ErrorAction SilentlyContinue).Status -eq 'Running';
            KeyIso = (Get-Service KeyIso -ErrorAction SilentlyContinue).Status -eq 'Running';
            AdminEnabled = (net user Administrator) -match 'Account active\s+Yes';
            Pwsh7 = Test-Path "C:\Program Files\PowerShell\7\pwsh.exe";
            Msvc = Test-Path "HKLM:\SOFTWARE\Classes\Installer\Dependencies\VC,redist.x64,amd64,14.0,bundle";
            AppInfra = (Get-Command choco -ErrorAction SilentlyContinue) -or (Get-Command winget -ErrorAction SilentlyContinue);
        }
        $stats | ConvertTo-Json
    "#;

    let output = std::process::Command::new("powershell")
        .args(["-NoProfile", "-Command", &format!("Invoke-Command -VMName '{}' -ScriptBlock {{ {} }}", vm_name, script)])
        .output();

    if let Ok(o) = output {
        if o.status.success() {
            let json = String::from_utf8_lossy(&o.stdout);
            if let Ok(data) = serde_json::from_str::<serde_json::Value>(&json) {
                return DashboardStats {
                    os_build: data["OsBuild"].as_str().unwrap_or("Unknown").to_string(),
                    uptime: data["Uptime"].as_str().unwrap_or("00:00:00").to_string(),
                    audit_mode: data["AuditMode"].as_bool().unwrap_or(false),
                    connection: ConnectionAudit {
                        limit_blank: data["LimitBlank"].as_bool().unwrap_or(false),
                        winrm: data["WinRM"].as_bool().unwrap_or(false),
                        keyiso: data["KeyIso"].as_bool().unwrap_or(false),
                        admin_enabled: data["AdminEnabled"].as_bool().unwrap_or(false),
                    },
                    stages: StagesAudit {
                        pwsh7: data["Pwsh7"].as_bool().unwrap_or(false),
                        msvc: data["Msvc"].as_bool().unwrap_or(false),
                        app_infra: data["AppInfra"].as_bool().unwrap_or(false),
                    }
                };
            }
        }
    }

    // Return empty stats if remote query fails
    DashboardStats {
        os_build: "N/A".to_string(),
        uptime: "OFFLINE".to_string(),
        audit_mode: false,
        connection: ConnectionAudit { limit_blank: false, winrm: false, keyiso: false, admin_enabled: false },
        stages: StagesAudit { pwsh7: false, msvc: false, app_infra: false }
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
