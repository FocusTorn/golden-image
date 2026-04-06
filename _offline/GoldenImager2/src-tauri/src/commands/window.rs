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

#[command]
pub async fn start_resize(window: Window, edge: String) -> Result<(), String> {
    #[cfg(windows)]
    {
        if let Ok(hwnd) = window.hwnd() {
            let direction_code: usize = match edge.as_str() {
                "Left" => 1,
                "Right" => 2,
                "Top" => 3,
                "TopLeft" => 4,
                "TopRight" => 5,
                "Bottom" => 6,
                "BottomLeft" => 7,
                "BottomRight" => 8,
                _ => return Err("Invalid edge".to_string()),
            };

            const WM_SYSCOMMAND: u32 = 0x0112;
            const SC_SIZE: usize = 0xF000;
            
            unsafe {
                type HWND = isize;
                extern "system" {
                    fn ReleaseCapture() -> i32;
                    fn SendMessageW(hWnd: HWND, Msg: u32, wParam: usize, lParam: isize) -> isize;
                }
                
                let _ = window.emit("manual-resize-start", ());
                let _ = ReleaseCapture();
                SendMessageW(hwnd.0, WM_SYSCOMMAND, SC_SIZE + direction_code, 0);
            }
        }
        Ok(())
    }
    
    #[cfg(not(windows))]
    {
        Err("Native resizing only supported on Windows".to_string())
    }
}
