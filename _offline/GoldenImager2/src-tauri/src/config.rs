use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

#[derive(Debug, Serialize, Deserialize)]
pub struct FeaturesConfig {
    #[serde(rename = "Version")]
    pub version: String,
    #[serde(rename = "Categories")]
    pub categories: Vec<Category>,
    #[serde(rename = "UiGroups")]
    pub ui_groups: Vec<UiGroup>,
    #[serde(rename = "Features")]
    pub features: Vec<Feature>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Category {
    #[serde(rename = "Name")]
    pub name: String,
    #[serde(rename = "Icon")]
    pub icon: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UiGroup {
    #[serde(rename = "GroupId")]
    pub group_id: String,
    #[serde(rename = "Label")]
    pub label: String,
    #[serde(rename = "ToolTip")]
    pub tool_tip: Option<String>,
    #[serde(rename = "Category")]
    pub category: String,
    #[serde(rename = "Priority")]
    pub priority: Option<i32>,
    #[serde(rename = "Values")]
    pub values: Vec<UiGroupValue>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UiGroupValue {
    #[serde(rename = "Label")]
    pub label: String,
    #[serde(rename = "FeatureIds")]
    pub feature_ids: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Feature {
    #[serde(rename = "FeatureId")]
    pub feature_id: String,
    #[serde(rename = "Label")]
    pub label: String,
    #[serde(rename = "ToolTip")]
    pub tool_tip: Option<String>,
    #[serde(rename = "Category")]
    pub category: Option<String>,
    #[serde(rename = "Action")]
    pub action: Option<String>,
    #[serde(rename = "RegistryKey")]
    pub registry_key: Option<String>,
    #[serde(rename = "ApplyText")]
    pub apply_text: Option<String>,
    #[serde(rename = "UndoAction")]
    pub undo_action: Option<String>,
    #[serde(rename = "RegistryUndoKey")]
    pub registry_undo_key: Option<String>,
    #[serde(rename = "MinVersion")]
    pub min_version: Option<u32>,
    #[serde(rename = "MaxVersion")]
    pub max_version: Option<u32>,
    #[serde(rename = "InvokeScript")]
    pub invoke_script: Option<String>,
    #[serde(rename = "UndoScript")]
    pub undo_script: Option<String>,
}

pub fn load_config<P: AsRef<Path>>(path: P) -> Result<FeaturesConfig, Box<dyn std::error::Error>> {
    let content = fs::read_to_string(path)?;
    let stripped = json_comments::StripComments::new(content.as_bytes());
    let config: FeaturesConfig = serde_json::from_reader(stripped)?;
    Ok(config)
}
