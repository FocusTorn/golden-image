use tauri::AppHandle;
use std::path::{Path, PathBuf};

/// Resolves a path to a project resource, handling both packaged and dev environments.
pub fn resolve_resource_path(app: &AppHandle, path: &str) -> Option<PathBuf> {
    // 1. Try Tauri's standard resource resolver (Packaged)
    app.path_resolver().resolve_resource(path).filter(|r: &PathBuf| r.exists())
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
    // Hardened SAC-Safe Fragment for Audit Mode (Blank Password Resilient):
    // $s=$env:VMP;$u=$env:VMU;$auth_arg='';if($u){$sec=New-Object System.Security.SecureString;if($s){$s.ToCharArray()|%{$sec.AppendChar($_)};$sec.MakeReadOnly()};$cred=New-Object Management.Automation.PSCredential($u,$sec);$auth_arg="-Credential `$cred"};
    "$s=$env:VMP;$u=$env:VMU;$auth_arg='';if($u){$sec=New-Object System.Security.SecureString;if($s){$s.ToCharArray()|%{$sec.AppendChar($_)};$sec.MakeReadOnly()};$cred=New-Object Management.Automation.PSCredential($u,$sec);$auth_arg=`\"-Credential `$cred`\"};".to_string()
}
