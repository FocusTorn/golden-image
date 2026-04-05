use tauri::{command, Window};

#[command]
pub async fn minimize_window(window: Window) -> Result<(), String> {
    window.minimize().map_err(|e: tauri::Error| e.to_string())
}

#[command]
pub async fn close_window(window: Window) -> Result<(), String> {
    window.close().map_err(|e: tauri::Error| e.to_string())
}

#[command]
pub async fn set_window_size(window: Window, width: f64, height: f64) -> Result<(), String> {
    window.set_size(tauri::Size::Logical(tauri::LogicalSize { width, height }))
        .map_err(|e| e.to_string())
}

#[command]
pub async fn set_window_position(window: Window, x: f64, y: f64) -> Result<(), String> {
    window.set_position(tauri::Position::Logical(tauri::LogicalPosition { x, y }))
        .map_err(|e| e.to_string())
}
