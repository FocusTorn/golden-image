// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

extern crate tauri;

mod audit;
mod config;
mod apps;
mod state;
mod commands;
mod utils;

use std::sync::Arc;
use tauri::{Manager, WindowEvent, GlobalWindowEvent};
use state::AppState;
use std::process::Command;

fn run_resource_cleanup() {
    println!("[*] Rust: Initiating automatic resource release / environment cleanup...");
    // We use a detached process to ensure cleanup finishes even if the main process exits quickly.
    let _ = Command::new("powershell")
        .args(&[
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-Command",
            "& { . 'P:\\Projects\\golden-image\\_helpers\\ConfigUtils.ps1'; . 'P:\\Projects\\golden-image\\_offline_host\\vhd-management\\scripts\\VhdUtils.ps1'; if (Test-Path 'P:\\Projects\\golden-image\\_master_config.json') { $cfg = Get-Config -Target Host; Invoke-SmartRelease $cfg.VhdPath $cfg.VMName } }"
        ])
        .spawn();
}

fn main() {
    tauri::Builder::default()
        .setup(|app: &mut tauri::App| {
            // Pre-emptive cleanup on launch
            run_resource_cleanup();
            
            let app_handle = app.handle();
            let cwd = std::env::current_dir().unwrap_or_default();
            
            // ... [Rest of setup logic remains unchanged] ...
            let resource_path = utils::resolve_resource_path(&app_handle, "config/Features.json")
                .ok_or_else(|| tauri::Error::AssetNotFound(format!("config/Features.json (CWD: {:?})", cwd)))?;
            
            let reg_path = utils::resolve_resource_path(&app_handle, "regfiles")
                .ok_or_else(|| tauri::Error::AssetNotFound(format!("regfiles (CWD: {:?})", cwd)))?;

            let config_path = resource_path.clone();
            let config = match config::load_config(config_path.clone()) {
                Ok(cfg) => Arc::new(cfg),
                Err(_) => Arc::new(config::load_embedded_config().map_err(|e| format!("Both Local and Embedded Config Load Failed: {}", e))?)
            };
            
            app.manage(AppState {
                config: tokio::sync::RwLock::new(config),
                reg_path,
                active_packer: tokio::sync::Mutex::new(None),
            });

            let app_handle_for_watch = app.handle();
            tauri::async_runtime::spawn(async move {
                let mut last_mtime = std::fs::metadata(&config_path).and_then(|m| m.modified()).ok();
                loop {
                    tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
                    if let Ok(mtime) = std::fs::metadata(&config_path).and_then(|m| m.modified()) {
                        if Some(mtime) != last_mtime {
                            last_mtime = Some(mtime);
                            let new_config = match config::load_config(config_path.clone()) {
                                Ok(cfg) => Some(cfg),
                                Err(e) => {
                                    eprintln!(">>> Hot Update Failed: {}", e);
                                    None
                                }
                            };

                            if let Some(cfg) = new_config {
                                let state = app_handle_for_watch.state::<AppState>();
                                let mut state_lock = state.config.write().await;
                                *state_lock = std::sync::Arc::new(cfg);
                                let _ = app_handle_for_watch.emit_all("features-config-updated", ());
                                println!(">>> Hot Update: Features.json reloaded.");
                            }
                        }
                    }
                }
            });

            #[cfg(windows)]
            {
                if let Some(window) = app.get_window("main") {
                    let hwnd_res: Result<_, tauri::Error> = window.hwnd();
                    if let Ok(hwnd) = hwnd_res {
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
        .on_window_event(|event: GlobalWindowEvent| {
            match event.event() {
                WindowEvent::CloseRequested { .. } => {
                    // Final cleanup on exit
                    run_resource_cleanup();
                },
                WindowEvent::Moved(pos) => {
                    let _ = event.window().emit("window-moved", (pos.x, pos.y));
                },
                WindowEvent::Resized(size) => {
                    let scale_factor = event.window().scale_factor().unwrap_or(1.0);
                    let logical_size = size.to_logical::<f64>(scale_factor);
                    let _ = event.window().emit("window-resized", (logical_size.width, logical_size.height));
                },
                _ => {}
            }
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
            commands::vhd::get_vhd_hub_statuses,
            commands::vhd::update_initial_view,
            commands::theme::get_theme_info,
            commands::theme::get_dashboard_stats,
            commands::tweaks::list_tweak_profiles,
            commands::tweaks::load_tweak_profile,
            commands::tweaks::save_tweak_profile,
            commands::tweaks::delete_tweak_profile,
            commands::provisioning::run_provisioning_stage,
            commands::provisioning::install_app,
            commands::window::minimize_window,
            commands::window::close_window,
            commands::vhd::mount_vhd,
            commands::vhd::unmount_vhd,
            commands::vhd::attach_vhd_to_vm,
            commands::vhd::detach_vhd_from_vm,
            commands::vhd::get_master_config,
            commands::vhd::transition_vhd,
            commands::vhd::check_vm_status,
            commands::vhd::update_default_profile,
            commands::audit::run_debug_diagnostic,
            commands::orchestrator::get_orchestrator_status,
            commands::orchestrator::generate_stealth_payload,
            commands::orchestrator::run_packer_build,
            commands::orchestrator::abort_packer_build,
            commands::orchestrator::show_payload_in_explorer,
            commands::orchestrator::install_packer,
            commands::orchestrator::install_osdbuilder,
            commands::window::set_window_size,
            commands::window::set_window_position
        ])
        .run(tauri::generate_context!())
        .map_err(|e| {
            eprintln!(">>> CRITICAL TAURI RUNTIME ERROR: {}", e);
            e
        })
        .expect("Tauri startup failed");
}
