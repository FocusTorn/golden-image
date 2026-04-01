use crate::config::FeaturesConfig;
use std::path::PathBuf;
use std::sync::Arc;

pub struct AppState {
    pub config: Arc<FeaturesConfig>,
    pub reg_path: PathBuf,
}
