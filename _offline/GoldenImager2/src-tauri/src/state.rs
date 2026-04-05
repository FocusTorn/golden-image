use crate::config::FeaturesConfig;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::{RwLock, Mutex};
use tokio::process::Child;

pub struct AppState {
    pub config: RwLock<Arc<FeaturesConfig>>,
    pub reg_path: PathBuf,
    pub active_packer: Mutex<Option<Child>>,
}
