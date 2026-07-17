use crate::installer::Installer;
use crate::models::{Feature, FeatureInfo, InstallResult, VersionInfo};
use crate::version;
use std::sync::Mutex;
use tauri::{Emitter, State};
use tauri_plugin_updater::UpdaterExt;
use url::Url;

#[tauri::command]
pub fn emit_log(app: tauri::AppHandle, message: String, level: String) {
    let _ = app.emit(
        "log-message",
        serde_json::json!({
            "message": message,
            "level": level,
        }),
    );
}

#[tauri::command]
pub async fn check_update_with_endpoint(
    app: tauri::AppHandle,
    endpoint: Option<String>,
) -> Result<Option<String>, String> {
    let update = if let Some(url_str) = endpoint {
        let url = Url::parse(&url_str).map_err(|e| e.to_string())?;
        app.updater_builder()
            .endpoints(vec![url])
            .map_err(|e| e.to_string())?
            .build()
            .map_err(|e| e.to_string())?
            .check()
            .await
            .map_err(|e| e.to_string())?
    } else {
        app.updater_builder()
            .build()
            .map_err(|e| e.to_string())?
            .check()
            .await
            .map_err(|e| e.to_string())?
    };

    if let Some(update) = update {
        Ok(Some(format!(
            "{}|{}",
            update.version,
            update.body.unwrap_or_default()
        )))
    } else {
        Ok(None)
    }
}

pub struct AppState {
    #[allow(dead_code)]
    pub installer: Mutex<Option<Installer>>,
}

#[tauri::command]
pub fn get_features() -> Vec<FeatureInfo> {
    Feature::all().iter().map(FeatureInfo::from).collect()
}

#[tauri::command]
pub fn get_installed_version(app: tauri::AppHandle) -> String {
    version::get_installed_version_with_app(Some(&app))
}

#[tauri::command]
pub async fn get_latest_version(_state: State<'_, AppState>) -> Result<String, String> {
    // Create installer outside of lock, then get version
    let installer = Installer::new();
    installer.get_latest_version().await
}

#[tauri::command]
pub async fn get_version_info(app: tauri::AppHandle, _state: State<'_, AppState>) -> Result<VersionInfo, String> {
    let installed = version::get_installed_version_with_app(Some(&app));

    // Create installer outside of lock
    let installer = Installer::new();
    let latest = installer
        .get_latest_version()
        .await
        .unwrap_or_else(|_| "Unknown".to_string());

    Ok(VersionInfo {
        installed_version: installed,
        latest_version: latest,
    })
}

#[tauri::command]
pub async fn install(
    app: tauri::AppHandle,
    _state: State<'_, AppState>,
    selected_features: Vec<(String, bool)>,
) -> Result<InstallResult, String> {
    // Create new installer and run install
    let mut installer = Installer::new();
    installer.install(app, selected_features).await
}

#[tauri::command]
pub async fn uninstall(
    app: tauri::AppHandle,
    _state: State<'_, AppState>,
) -> Result<InstallResult, String> {
    // Create new installer and run uninstall
    let mut installer = Installer::new();
    installer.uninstall(app).await
}

pub fn create_app_state() -> AppState {
    AppState {
        installer: Mutex::new(None),
    }
}
