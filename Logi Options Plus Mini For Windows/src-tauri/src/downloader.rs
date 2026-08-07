use log::{debug, error, info};
use reqwest::Client;
use std::path::PathBuf;
use std::time::Duration;
use tauri::Emitter;

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
const OFFLINE_DOWNLOAD_URL_CN: &str = "https://download.logitech.com.cn/web/ftp/pub/techsupport/optionsplus/logioptionsplus_installer_offline.exe";
const OFFLINE_DOWNLOAD_URL: &str =
    "https://download01.logi.com/web/ftp/pub/techsupport/optionsplus/logioptionsplus_installer_offline.exe";
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

    pub async fn detect_region_with_app(
        &mut self,
        app: &tauri::AppHandle,
        source: Option<&str>,
    ) -> Result<bool, String> {
        // 当手动指定了下载源时，跳过地区检测，直接使用对应地址
        match source {
            Some("china") => {
                emit_log(app, "Download source set to China", "info");
                self.is_china = true;
                return Ok(true);
            }
            Some("global") => {
                emit_log(app, "Download source set to Global", "info");
                self.is_china = false;
                return Ok(false);
            }
            _ => {}
        }

        emit_log(
            app,
            "Detecting region via https://cloudflare.com/cdn-cgi/trace",
            "debug",
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
                        emit_log(app, "Detected region: China", "debug");
                        self.is_china = true;
                        return Ok(true);
                    }
                }
            }
            Err(e) => {
                emit_log(app, &format!("Failed to detect region: {}", e), "error");
            }
        }

        emit_log(app, "Detected region: Global", "debug");
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
        let filename = "logioptionsplus_installer.exe";
        self.download_to_temp(app, url, filename, temp_dir).await
    }

    pub async fn download_offline_installer_with_app(
        &self,
        app: &tauri::AppHandle,
        temp_dir: &PathBuf,
    ) -> Result<PathBuf, String> {
        let url = if self.is_china {
            OFFLINE_DOWNLOAD_URL_CN
        } else {
            OFFLINE_DOWNLOAD_URL
        };
        let filename = "logioptionsplus_installer_offline.exe";
        self.download_to_temp(app, url, filename, temp_dir).await
    }

    async fn download_to_temp(
        &self,
        app: &tauri::AppHandle,
        url: &str,
        filename: &str,
        temp_dir: &PathBuf,
    ) -> Result<PathBuf, String> {
        // Use cached installer if available (cache lives under the same temp_dir
        // passed in from the installer, so it is cleaned up consistently)
        let cache_path = temp_dir.join(filename);
        if cache_path.exists() {
            emit_log(
                app,
                &format!("Using cached installer from: {:?}", cache_path),
                "debug",
            );
            return Ok(cache_path);
        }

        emit_log(
            app,
            &format!("Downloading Logi Options+ installer from: {}", url),
            "debug",
        );

        let response = self
            .client
            .get(url)
            .timeout(Duration::from_secs(300))
            .send()
            .await
            .map_err(|e| format!("Download failed: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("Server returned error code: {}", response.status()));
        }

        let total = response.content_length().unwrap_or(0);
        let temp_path = temp_dir.join(filename);

        // Stream the response to disk while emitting download progress
        use futures_util::StreamExt;
        let mut file = tokio::fs::File::create(&temp_path)
            .await
            .map_err(|e| format!("Failed to create temp file: {}", e))?;
        let mut stream = response.bytes_stream();
        let mut downloaded: u64 = 0;
        while let Some(chunk) = stream.next().await {
            let chunk = chunk.map_err(|e| format!("Failed to read chunk: {}", e))?;
            downloaded += chunk.len() as u64;
            tokio::io::AsyncWriteExt::write_all(&mut file, &chunk)
                .await
                .map_err(|e| format!("Failed to write chunk: {}", e))?;
            let _ = app.emit(
                "install-progress",
                serde_json::json!({ "downloaded": downloaded, "total": total }),
            );
        }

        emit_log(
            app,
            &format!("Download complete to: {:?}", temp_path),
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
