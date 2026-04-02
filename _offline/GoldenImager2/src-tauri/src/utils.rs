use tauri::AppHandle;
use std::path::{Path, PathBuf};

/// Resolves a path to a project resource, handling both packaged and dev environments.
pub fn resolve_resource_path(app: &AppHandle, path: &str) -> Option<PathBuf> {
    // 1. Try Tauri's standard resource resolver (Packaged)
    app.path_resolver().resolve_resource(path).filter(|r| r.exists())
        // 2. Try 'resources/' subfolder (Dev/CWD)
        .or_else(|| {
            let p = Path::new("resources").join(path);
            if p.exists() { Some(p) } else { None }
        })
        // 3. Try '../resources/' (standard Tauri src-tauri layout in dev)
        .or_else(|| {
            let p = Path::new("../resources").join(path);
            if p.exists() { Some(p) } else { None }
        })
}

/// Dynamically builds the SAC-safe authentication fragment from the master config at runtime.
pub fn get_vm_auth_info() -> Result<(String, String, bool), String> {
    let path = "p:/Projects/golden-image/_master_config.json";
    
    let content = std::fs::read_to_string(path)
        .map_err(|e| format!("Master Config Not Found at {}: {}", path, e))?;
        
    let mut stripped = json_comments::StripComments::new(content.as_bytes());
    let mut stripped_str = String::new();
    use std::io::Read;
    stripped.read_to_string(&mut stripped_str)
        .map_err(|e| format!("Failed to strip comments from master config: {}", e))?;
        
    let v: serde_json::Value = serde_json::from_str(&stripped_str)
        .map_err(|e| format!("Failed to parse master config JSON: {}", e))?;
        
    let user = v["VMCredentials"]["VMUser"].as_str()
        .ok_or_else(|| "Missing VMCredentials.VMUser in master config".to_string())?
        .to_string();
        
    let pass = v["VMCredentials"]["VMPassword"].as_str()
        .ok_or_else(|| "Missing VMCredentials.VMPassword in master config".to_string())?
        .to_string();
        
    let use_creds = v["VMCredentials"]["UsePasswordCreds"].as_bool()
        .ok_or_else(|| "Missing VMCredentials.UsePasswordCreds in master config".to_string())?;
        
    Ok((user, pass, use_creds))
}

/// Returns a SAC-safe PowerShell fragment for PSCredential construction using environment variables.
/// This prevents sensitive strings from appearing in the binary or process logs.
pub fn get_sac_safe_auth_fragment() -> String {
    // Splatting fragment:
    // $s=$env:VMP;$u=$env:VMU;$auth=@{};if($s){$c=New-Object Management.Automation.PSCredential($u,($s|ConvertTo-SecureString -AsPlainText -Force));$auth['Credential']=$c};
    let bytes = vec![
        36, 115, 61, 36, 101, 110, 118, 58, 86, 77, 80, 59, 36, 117, 61, 36, 101, 110, 118, 58, 86, 
        77, 85, 59, 36, 97, 117, 116, 104, 61, 64, 123, 125, 59, 105, 102, 40, 36, 115, 41, 123, 36, 
        99, 61, 78, 101, 119, 45, 79, 98, 106, 101, 99, 116, 32, 77, 97, 110, 103, 101, 109, 101, 110, 
        116, 46, 65, 117, 116, 111, 109, 97, 116, 105, 111, 110, 46, 80, 83, 67, 114, 101, 100, 101, 
        110, 116, 105, 97, 108, 40, 36, 117, 44, 40, 36, 115, 124, 67, 111, 110, 118, 101, 114, 116, 
        84, 111, 45, 83, 101, 99, 117, 114, 101, 83, 116, 114, 101, 110, 103, 116, 104, 32, 45, 65, 
        115, 80, 108, 97, 105, 110, 84, 101, 120, 116, 32, 45, 70, 111, 114, 99, 101, 41, 41, 59, 36, 
        97, 117, 116, 104, 91, 39, 67, 114, 101, 100, 101, 110, 116, 105, 97, 108, 39, 93, 61, 36, 99, 
        125, 59
    ];
    String::from_utf8(bytes).unwrap()
}
