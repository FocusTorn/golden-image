use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "PascalCase")]
pub struct FeaturesConfig {
    pub version: String,
    pub categories: Vec<Category>,
    pub ui_groups: Vec<UiGroup>,
    pub features: Vec<Feature>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "PascalCase")]
pub struct Category {
    pub name: String,
    pub icon: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "PascalCase")]
pub struct UiGroup {
    pub group_id: String,
    pub label: String,
    pub tool_tip: Option<String>,
    pub category: String,
    pub priority: Option<i32>,
    pub values: Vec<UiGroupValue>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "PascalCase")]
pub struct UiGroupValue {
    pub label: String,
    pub feature_ids: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "PascalCase")]
pub struct Feature {
    pub feature_id: String,
    pub label: String,
    pub tool_tip: Option<String>,
    pub category: Option<String>,
    pub action: Option<String>,
    pub registry_key: Option<String>,
    pub apply_text: Option<String>,
    pub undo_action: Option<String>,
    pub registry_undo_key: Option<String>,
    pub min_version: Option<u32>,
    pub max_version: Option<u32>,
    pub invoke_script: Option<String>,
    pub undo_script: Option<String>,
}

pub fn load_config<P: AsRef<Path>>(path: P) -> Result<FeaturesConfig, Box<dyn std::error::Error>> {
    let content = fs::read_to_string(path)?;
    let stripped = json_comments::StripComments::new(content.as_bytes());
    let config: FeaturesConfig = serde_json::from_reader(stripped)?;
    Ok(config)
}
