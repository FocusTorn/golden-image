use crate::config::FeaturesConfig;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::RwLock;

pub struct AppState {
    pub config: RwLock<Arc<FeaturesConfig>>,
    pub reg_path: PathBuf,
}
