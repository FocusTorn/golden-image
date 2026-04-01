// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod audit;
mod config;
mod apps;
mod state;
mod commands;
mod utils;

use std::sync::Arc;
use tauri::Manager;
use state::AppState;

// Resource resolution moved to utils::resolve_resource_path

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            let app_handle = app.handle();
            
            let cwd = std::env::current_dir().unwrap_or_default();

            // 1. Initial Path Resolution
            let resource_path = utils::resolve_resource_path(&app_handle, "config/Features.json")
                .ok_or_else(|| tauri::Error::AssetNotFound(format!("config/Features.json (CWD: {:?})", cwd)))?;
            
            let reg_path = utils::resolve_resource_path(&app_handle, "regfiles")
                .ok_or_else(|| tauri::Error::AssetNotFound(format!("regfiles (CWD: {:?})", cwd)))?;

            // 2. Load Config once for caching in memory
            let config = Arc::new(config::load_config(resource_path).map_err(|e| format!("Config load error: {}", e))?);
            
            // 3. Initialize Shared State
            app.manage(AppState {
                config,
                reg_path,
            });

            // 4. Taskbar Icon Fix (Dynamic Resolution)
            #[cfg(windows)]
            {
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

                            if let Some(icon_path) = utils::resolve_resource_path(&app_handle, "src/assets/taskbar.ico")
                                .or_else(|| utils::resolve_resource_path(&app_handle, "assets/taskbar.ico"))
                                .or_else(|| utils::resolve_resource_path(&app_handle, "defaultassets/taskbar.ico")) {
                                
                                let path_wide: Vec<u16> = icon_path.to_string_lossy().encode_utf16().chain(Some(0)).collect();
                                let h_icon = LoadImageW(
                                    0,
                                    path_wide.as_ptr(),
                                    IMAGE_ICON,
                                    0,
                                    0,
                                    LR_LOADFROMFILE,
                                ) as isize;

                                if h_icon != 0 {
                                    SendMessageW(hwnd.0, WM_SETICON, ICON_BIG, h_icon);
                                }
                            }
                        }
                    }
                }
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::audit::get_audit_results,
            commands::audit::get_features_config,
            commands::audit::apply_feature,
            commands::audit::apply_features_batch,
            commands::audit::undo_feature,
            commands::apps::get_apps,
            commands::apps::list_app_profiles,
            commands::apps::load_app_profile,
            commands::apps::save_app_profile,
            commands::apps::delete_app_profile,
            commands::theme::get_theme_info,
            commands::theme::get_dashboard_stats,
            commands::tweaks::list_tweak_profiles,
            commands::tweaks::load_tweak_profile,
            commands::tweaks::save_tweak_profile,
            commands::tweaks::delete_tweak_profile,
            commands::provisioning::run_provisioning_stage,
            commands::provisioning::install_app,
            commands::window::minimize_window,
            commands::window::close_window
        ])
        .run(tauri::generate_context!())
        .map_err(|e| {
            eprintln!(">>> CRITICAL TAURI RUNTIME ERROR: {}", e);
            e
        })
        .expect("Tauri startup failed");
}
