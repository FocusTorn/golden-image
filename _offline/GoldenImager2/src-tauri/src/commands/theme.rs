use serde::Serialize;
use tauri::command;

#[derive(Serialize)]
#[allow(non_snake_case)]
pub struct ThemeInfo {
    pub R: u8,
    pub G: u8,
    pub B: u8,
    pub IsDark: bool,
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

#[command]
pub async fn get_dashboard_stats() -> DashboardStats {
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

    DashboardStats {
        connection: ConnectionAudit { limit_blank, winrm, keyiso, admin_enabled },
        stages: StagesAudit { pwsh7, msvc, app_infra }
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
