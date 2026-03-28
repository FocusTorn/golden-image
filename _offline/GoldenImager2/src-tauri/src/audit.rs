use crate::config::Feature;
use std::path::Path;
use std::fs;
use windows::Win32::System::Registry::{
    RegOpenKeyExW, RegQueryValueExW, HKEY, HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE,
    KEY_READ, REG_SZ, REG_DWORD, REG_EXPAND_SZ, REG_VALUE_TYPE,
};
use windows::core::PCWSTR;

#[derive(Debug, serde::Serialize)]
pub struct AuditResult {
    pub feature_id: String,
    pub status: String, // "Applied", "Not Applied", "Error", "Unsupported"
    pub message: String,
}

pub fn run_audit(features: &[Feature], reg_path: &Path) -> Vec<AuditResult> {
    let mut results = Vec::new();

    for feature in features {
        if let Some(reg_file) = &feature.registry_key {
            let full_path = reg_path.join(reg_file);
            match audit_reg_file(&full_path) {
                Ok(applied) => {
                    results.push(AuditResult {
                        feature_id: feature.feature_id.clone(),
                        status: if applied { "Applied".to_string() } else { "Not Applied".to_string() },
                        message: String::new(),
                    });
                }
                Err(e) => {
                    results.push(AuditResult {
                        feature_id: feature.feature_id.clone(),
                        status: "Error".to_string(),
                        message: e.to_string(),
                    });
                }
            }
        } else {
            results.push(AuditResult {
                feature_id: feature.feature_id.clone(),
                status: "Unsupported".to_string(),
                message: "No RegistryKey defined for this feature".to_string(),
            });
        }
    }

    results
}

fn audit_reg_file(path: &Path) -> Result<bool, Box<dyn std::error::Error>> {
    let content = fs::read(path)?;
    let content_str = if content.starts_with(&[0xFF, 0xFE]) {
        let utf16_content: Vec<u16> = content[2..]
            .chunks_exact(2)
            .map(|c| u16::from_le_bytes([c[0], c[1]]))
            .collect();
        String::from_utf16(&utf16_content)?
    } else {
        String::from_utf8(content)?
    };

    let mut current_key: Option<String> = None;
    let mut all_match = true;
    let mut buffer_line = String::new();

    for line in content_str.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with(';') || line.starts_with("Windows Registry Editor") {
            continue;
        }

        if line.starts_with('[') && line.ends_with(']') {
            current_key = Some(line[1..line.len() - 1].to_string());
            continue;
        }

        let processing_line = if line.ends_with('\\') {
            buffer_line.push_str(&line[..line.len() - 1]);
            continue;
        } else {
            let full_line = if !buffer_line.is_empty() {
                buffer_line.push_str(line);
                let tmp = buffer_line.clone();
                buffer_line.clear();
                tmp
            } else {
                line.to_string()
            };
            full_line
        };

        if let Some(key_path) = &current_key {
            if let Some((name, value_str)) = parse_reg_line(&processing_line) {
                match check_registry_value(key_path, &name, &value_str) {
                    Ok(m) => {
                        if !m {
                            all_match = false;
                        }
                    }
                    Err(_) => {
                        all_match = false;
                    }
                }
            }
        }
    }

    Ok(all_match)
}

fn parse_reg_line(line: &str) -> Option<(String, String)> {
    if let Some(pos) = line.find('=') {
        let name = line[..pos].trim();
        let name = if name.starts_with('"') && name.ends_with('"') {
            name[1..name.len() - 1].to_string()
        } else if name == "@" {
            "".to_string() // Default value
        } else {
            name.to_string()
        };
        let value = line[pos + 1..].trim().to_string();
        Some((name, value))
    } else {
        None
    }
}

fn check_registry_value(key_path: &str, name: &str, expected_value: &str) -> Result<bool, Box<dyn std::error::Error>> {
    let (hkey_root, sub_key) = split_key_path(key_path)?;
    
    let sub_key_wide: Vec<u16> = sub_key.encode_utf16().chain(std::iter::once(0)).collect();
    let name_wide: Vec<u16> = name.encode_utf16().chain(std::iter::once(0)).collect();

    let mut hkey = HKEY::default();
    unsafe {
        let status = RegOpenKeyExW(hkey_root, PCWSTR(sub_key_wide.as_ptr()), 0, KEY_READ, &mut hkey);
        if status.is_err() {
            return Ok(false);
        }

        let mut value_type = REG_VALUE_TYPE::default();
        let mut data_size: u32 = 0;
        
        // Get data size
        let status = RegQueryValueExW(hkey, PCWSTR(name_wide.as_ptr()), None, Some(&mut value_type), None, Some(&mut data_size));
        if status.is_err() {
            return Ok(false);
        }

        let mut buffer = vec![0u8; data_size as usize];
        let status = RegQueryValueExW(hkey, PCWSTR(name_wide.as_ptr()), None, Some(&mut value_type), Some(buffer.as_mut_ptr()), Some(&mut data_size));
        
        if status.is_err() {
            return Ok(false);
        }

        match value_type {
            REG_DWORD => {
                if buffer.len() >= 4 {
                    let val = u32::from_le_bytes([buffer[0], buffer[1], buffer[2], buffer[3]]);
                    let expected_val = parse_dword(expected_value)?;
                    return Ok(val == expected_val);
                }
            }
            REG_SZ | REG_EXPAND_SZ => {
                let val_utf16: Vec<u16> = buffer.chunks_exact(2).map(|c| u16::from_le_bytes([c[0], c[1]])).collect();
                let val = String::from_utf16(&val_utf16)?.trim_matches(char::from(0)).to_string();
                let expected_val = expected_value.trim_matches('"').to_string();
                return Ok(val == expected_val);
            }
            windows::Win32::System::Registry::REG_BINARY => {
                if expected_value.starts_with("hex:") {
                    let expected_bytes = parse_hex(&expected_value[4..])?;
                    return Ok(buffer == expected_bytes);
                }
            }
            _ => {
                // For other types, try a raw comparison if we can parse the expected value
                if expected_value.starts_with("hex(") {
                    if let Some(pos) = expected_value.find(':') {
                        let expected_bytes = parse_hex(&expected_value[pos+1..])?;
                        return Ok(buffer == expected_bytes);
                    }
                }
            }
        }
    }

    Ok(false)
}

fn parse_dword(s: &str) -> Result<u32, Box<dyn std::error::Error>> {
    if s.starts_with("dword:") {
        Ok(u32::from_str_radix(&s[6..], 16)?)
    } else {
        Err("Not a dword".into())
    }
}

fn parse_hex(s: &str) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    let clean: String = s.chars().filter(|c| c.is_ascii_hexdigit() || *c == ',').collect();
    let mut bytes = Vec::new();
    for part in clean.split(',') {
        let part = part.trim();
        if !part.is_empty() {
            bytes.push(u8::from_str_radix(part, 16)?);
        }
    }
    Ok(bytes)
}

fn split_key_path(path: &str) -> Result<(HKEY, String), Box<dyn std::error::Error>> {
    if path.starts_with("HKEY_CURRENT_USER\\") {
        Ok((HKEY_CURRENT_USER, path[18..].to_string()))
    } else if path.starts_with("HKCU\\") {
        Ok((HKEY_CURRENT_USER, path[5..].to_string()))
    } else if path.starts_with("HKEY_LOCAL_MACHINE\\") {
        Ok((HKEY_LOCAL_MACHINE, path[19..].to_string()))
    } else if path.starts_with("HKLM\\") {
        Ok((HKEY_LOCAL_MACHINE, path[5..].to_string()))
    } else {
        Err(format!("Unsupported Hive: {}", path).into())
    }
}
