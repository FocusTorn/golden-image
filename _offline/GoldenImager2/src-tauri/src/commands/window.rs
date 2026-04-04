use tauri::{command, Window};

#[command]
pub async fn minimize_window(window: Window) -> Result<(), String> {
    window.minimize().map_err(|e: tauri::Error| e.to_string())
}

#[command]
pub async fn close_window(window: Window) -> Result<(), String> {
    window.close().map_err(|e: tauri::Error| e.to_string())
}
