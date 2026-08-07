use crate::downloader::Downloader;
use crate::installer::Installer;
use crate::models::{Feature, FeatureInfo, InstallResult, VersionInfo};
use crate::version;
use log::{debug, error, info, warn};
use std::sync::Mutex;
use tauri::{Emitter, State};
use tauri_plugin_updater::UpdaterExt;
use url::Url;

/// China 镜像更新源的 latest.json 地址。
const CHINA_UPDATE_ENDPOINT: &str = "https://v.qetesh.cc/d/Public/latest.json";

/// 解析更新检查 / 安装使用的 endpoint。
///
/// - `auto` 模式：复用 `downloader` 现有的区域检测逻辑，检测到 China 区域则使用
///   China 镜像更新源，否则回落到配置默认源（GitHub）；
/// - `global` / `china` 模式：直接使用传入的 endpoint，不进行区域检测。
async fn resolve_update_endpoint(
    app: &tauri::AppHandle,
    source: &str,
    endpoint: Option<String>,
) -> Option<String> {
    if source != "auto" {
        debug!(
            "Update source '{}' selected, skip region detection, endpoint: {:?}",
            source, endpoint
        );
        return endpoint;
    }

    let mut downloader = Downloader::new();

    let is_china = match downloader.detect_region_with_app(app, None).await {
        Ok(is_china) => {
            debug!("Region detection result: {}", if is_china { "China" } else { "Global" });
            is_china
        }
        Err(e) => {
            warn!(
                "Region detection failed ({}), fallback to default config endpoint",
                e
            );
            false
        }
    };

    let resolved = if is_china {
        Some(CHINA_UPDATE_ENDPOINT.to_string())
    } else {
        None
    };

    debug!(
        "Resolved update endpoint: {:?}",
        resolved.as_deref().unwrap_or("default (config.toml)")
    );
    resolved
}

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
    source: String,
    endpoint: Option<String>,
) -> Result<Option<String>, String> {
    info!(
        "check_update_with_endpoint called, source: {}, endpoint: {:?}, current version: {}",
        source,
        endpoint,
        app.package_info().version
    );

    let resolved = resolve_update_endpoint(&app, &source, endpoint.clone()).await;

    let update = if let Some(ref url_str) = resolved {
        let url = Url::parse(url_str).map_err(|e| {
            error!("Invalid update endpoint URL '{}': {}", url_str, e);
            e.to_string()
        })?;
        info!("Checking update via custom endpoint: {}", url);
        app.updater_builder()
            .endpoints(vec![url])
            .map_err(|e| e.to_string())?
            .build()
            .map_err(|e| e.to_string())?
            .check()
            .await
            .map_err(|e| e.to_string())?
    } else {
        info!("Checking update via default (config.toml) endpoint");
        app.updater_builder()
            .build()
            .map_err(|e| e.to_string())?
            .check()
            .await
            .map_err(|e| e.to_string())?
    };

    if let Some(update) = update {
        info!(
            "Update FOUND -> version: {}, notes length: {}",
            update.version,
            update.body.as_ref().map(|b| b.len()).unwrap_or(0)
        );
        Ok(Some(format!(
            "{}|{}",
            update.version,
            update.body.unwrap_or_default()
        )))
    } else {
        warn!(
            "No update found for current version {} via endpoint {:?}",
            app.package_info().version,
            endpoint
        );
        Ok(None)
    }
}

/// 使用与“检查更新”一致的 endpoint 执行下载并安装。
/// 这样即使默认 endpoint（GitHub）与所选更新源（如 China 镜像）不同，
/// 也不会出现“检查到更新但安装时报没有可用更新”的问题。
#[tauri::command]
pub async fn download_and_install_with_endpoint(
    app: tauri::AppHandle,
    source: String,
    endpoint: Option<String>,
) -> Result<(), String> {
    info!(
        "download_and_install_with_endpoint called, source: {}, endpoint: {:?}, current version: {}",
        source,
        endpoint,
        app.package_info().version
    );

    let resolved = resolve_update_endpoint(&app, &source, endpoint.clone()).await;

    let update = if let Some(ref url_str) = resolved {
        let url = Url::parse(url_str).map_err(|e| {
            let msg = format!("Invalid update endpoint URL '{}': {}", url_str, e);
            error!("{}", msg);
            msg
        })?;
        info!("Downloading update via custom endpoint: {}", url);
        app.updater_builder()
            .endpoints(vec![url])
            .map_err(|e| e.to_string())?
            .build()
            .map_err(|e| e.to_string())?
            .check()
            .await
            .map_err(|e| e.to_string())?
    } else {
        info!("Downloading update via default (config.toml) endpoint");
        app.updater_builder()
            .build()
            .map_err(|e| e.to_string())?
            .check()
            .await
            .map_err(|e| e.to_string())?
    };

    match update {
        Some(update) => {
            let new_version = update.version.clone();
            info!(
                "Update available: {} (current: {}). Starting download and install...",
                new_version,
                app.package_info().version
            );
            let _ = app.emit(
                "update-status",
                serde_json::json!({ "status": "downloading", "version": new_version }),
            );

            let app_for_cb = app.clone();
            let mut downloaded: u64 = 0;
            update
                .download_and_install(
                    |chunk_length, content_length| {
                        downloaded += chunk_length as u64;
                        let total = content_length.unwrap_or(0);
                        debug!(
                            "Download progress: {}/{} bytes (chunk {})",
                            downloaded, total, chunk_length
                        );
                        let _ = app_for_cb.emit(
                            "update-progress",
                            serde_json::json!({
                                "chunk_length": chunk_length,
                                "downloaded": downloaded,
                                "total": total,
                            }),
                        );
                    },
                    || {
                        info!("Download finished, beginning installation...");
                        let _ = app.emit(
                            "update-status",
                            serde_json::json!({ "status": "installing" }),
                        );
                    },
                )
                .await
                .map_err(|e| {
                    let msg = format!("Failed to download/install update: {}", e);
                    error!("{}", msg);
                    msg
                })?;

            info!("Update installed successfully, relaunch required");
            Ok(())
        }
        None => {
            warn!(
                "download_and_install: no update available from endpoint {:?} (current version: {})",
                resolved,
                app.package_info().version
            );
            Err("no_update_available".to_string())
        }
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
    source: Option<String>,
) -> Result<InstallResult, String> {
    // Create new installer and run install
    let mut installer = Installer::new();
    installer.install(app, selected_features, source).await
}

#[tauri::command]
pub async fn uninstall(
    app: tauri::AppHandle,
    _state: State<'_, AppState>,
    source: Option<String>,
) -> Result<InstallResult, String> {
    // Create new installer and run uninstall
    let mut installer = Installer::new();
    installer.uninstall(app, source).await
}

#[tauri::command]
pub async fn install_offline(
    app: tauri::AppHandle,
    _state: State<'_, AppState>,
    selected_features: Vec<(String, bool)>,
    source: Option<String>,
) -> Result<InstallResult, String> {
    // Create new installer and run offline install
    let mut installer = Installer::new();
    installer.install_offline(app, selected_features, source).await
}

pub fn create_app_state() -> AppState {
    AppState {
        installer: Mutex::new(None),
    }
}
