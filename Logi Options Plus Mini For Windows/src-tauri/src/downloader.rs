use log::{debug, error, info};
use reqwest::Client;
use std::path::PathBuf;
use std::time::Duration;
use tauri::Emitter;
use tokio::fs;

fn emit_log(app: &tauri::AppHandle, message: &str, level: &str) {
    let _ = app.emit(
        "log-message",
        serde_json::json!({
            "message": message,
            "level": level,
        }),
    );
    match level {
        "error" => error!("{}", message),
        "debug" => debug!("{}", message),
        _ => info!("{}", message),
    }
}

const DOWNLOAD_URL_CN: &str = "https://download.logitech.com.cn/web/ftp/pub/techsupport/optionsplus/logioptionsplus_installer.exe";
const DOWNLOAD_URL: &str =
    "https://download01.logi.com/web/ftp/pub/techsupport/optionsplus/logioptionsplus_installer.exe";
const VERSION_URL: &str = "https://updates.optionsplus.logitechg.com/pipeline/v2/update/optionsplus5/win/public/update.json";

pub struct Downloader {
    client: Client,
    is_china: bool,
}

impl Downloader {
    pub fn new() -> Self {
        let client = Client::builder()
            .user_agent("GHubDownloader/1.0")
            .timeout(std::time::Duration::from_secs(300))
            .build()
            .expect("Failed to create HTTP client");

        Downloader {
            client,
            is_china: false,
        }
    }

    pub async fn detect_region_with_app(&mut self, app: &tauri::AppHandle) -> Result<bool, String> {
        emit_log(
            app,
            "Detecting region via https://cloudflare.com/cdn-cgi/trace",
            "info",
        );

        match self
            .client
            .get("https://cloudflare.com/cdn-cgi/trace")
            .timeout(std::time::Duration::from_secs(10))
            .send()
            .await
        {
            Ok(response) => {
                if let Ok(text) = response.text().await {
                    if text.contains("loc=CN") {
                        emit_log(app, "Detected region: China, using CN download URL", "info");
                        self.is_china = true;
                        return Ok(true);
                    }
                }
            }
            Err(e) => {
                emit_log(app, &format!("Failed to detect region: {}", e), "error");
            }
        }

        emit_log(
            app,
            "Detected region: Global, using default download URL",
            "info",
        );
        self.is_china = false;
        Ok(false)
    }

    pub async fn download_installer_with_app(
        &self,
        app: &tauri::AppHandle,
        temp_dir: &PathBuf,
    ) -> Result<PathBuf, String> {
        let url = if self.is_china {
            DOWNLOAD_URL_CN
        } else {
            DOWNLOAD_URL
        };

        // Define cache directory (system cache directory)
        let cache_dir = dirs::cache_dir()
            .ok_or("Failed to get cache directory")?
            .join("logi-options-plus-mini");

        let filename = "logioptionsplus_installer.exe";
        let cache_path = cache_dir.join(filename);

        // Check if cached file exists
        if cache_path.exists() {
            emit_log(
                app,
                &format!("Using cached installer from: {:?}", cache_path),
                "debug",
            );
            // Copy from cache to temp directory
            let temp_path = temp_dir.join(filename);
            fs::copy(&cache_path, &temp_path)
                .await
                .map_err(|e| format!("Failed to copy from cache: {}", e))?;
            return Ok(temp_path);
        }

        emit_log(
            app,
            &format!("Downloading Logi Options+ installer from: {}", url),
            "debug",
        );

        let response = self
            .client
            .get(url)
            .timeout(Duration::from_secs(90))
            .send()
            .await
            .map_err(|e| format!("Download failed: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("Server returned error code: {}", response.status()));
        }

        let temp_path = temp_dir.join(filename);

        let bytes = response
            .bytes()
            .await
            .map_err(|e| format!("Failed to read response: {}", e))?;

        // Save to temp directory first
        fs::write(&temp_path, &bytes)
            .await
            .map_err(|e| format!("Failed to save installer: {}", e))?;

        // Save to cache directory
        fs::create_dir_all(&cache_dir)
            .await
            .map_err(|e| format!("Failed to create cache directory: {}", e))?;
        fs::write(&cache_path, &bytes)
            .await
            .map_err(|e| format!("Failed to save to cache: {}", e))?;

        emit_log(
            app,
            &format!(
                "Download complete to: {:?} (also cached at: {:?})",
                temp_path, cache_path
            ),
            "debug",
        );
        Ok(temp_path)
    }

    pub async fn get_latest_version(&self) -> Result<String, String> {
        info!("Fetching latest version from: {}", VERSION_URL);

        let response = self
            .client
            .get(VERSION_URL)
            .header("User-Agent", "GHubDownloader/1.0")
            .header("Accept", "*/*")
            .header("logi-app-version", "2.5.926888")
            .send()
            .await
            .map_err(|e| format!("Failed to fetch version: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("Server returned error: {}", response.status()));
        }

        let json: serde_json::Value = response
            .json()
            .await
            .map_err(|e| format!("Failed to parse JSON: {}", e))?;

        let version = json
            .get("version")
            .and_then(|v| v.as_str())
            .unwrap_or("Unknown")
            .to_string();

        debug!("Latest version: {}", version);
        Ok(version)
    }
}

impl Default for Downloader {
    fn default() -> Self {
        Self::new()
    }
}
