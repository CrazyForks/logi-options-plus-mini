use log::{debug, error, info};
use std::path::PathBuf;
use std::process::Command;
use tauri::Emitter;

use crate::backup::BackupManager;
use crate::downloader::Downloader;
use crate::models::InstallResult;
use crate::version::get_installed_version_with_app;

fn emit_log_internal(app: &tauri::AppHandle, message: &str, level: &str) {
    // Emit to frontend
    let _ = app.emit(
        "log-message",
        serde_json::json!({
            "message": message,
            "level": level,
        }),
    );
    // Also log to console
    match level {
        "error" => error!("{}", message),
        "debug" => debug!("{}", message),
        _ => info!("{}", message),
    }
}

pub struct Installer {
    temp_dir: PathBuf,
    downloader: Downloader,
    backup_manager: BackupManager,
}

impl Installer {
    pub fn new() -> Self {
        let temp_dir = std::env::temp_dir().join("logi_options_plus");

        // Create temp directory if not exists (use std::fs for sync creation in constructor)
        std::fs::create_dir_all(&temp_dir).ok();

        Installer {
            temp_dir,
            downloader: Downloader::new(),
            backup_manager: BackupManager::new(),
        }
    }

    pub async fn install(
        &mut self,
        app: tauri::AppHandle,
        selected_features: Vec<(String, bool)>,
    ) -> Result<InstallResult, String> {
        emit_log_internal(&app, "Starting installation process...", "info");

        // Step 1: Detect region
        self.downloader.detect_region_with_app(&app).await?;

        // Step 2: Download installer
        emit_log_internal(&app, "Step 1/5: Downloading installer...", "info");
        let installer_path = self
            .downloader
            .download_installer_with_app(&app, &self.temp_dir)
            .await?;

        // Step 3: Backup configuration
        emit_log_internal(&app, "Step 2/5: Backing up configuration...", "info");
        if let Err(e) = self.backup_manager.backup(&app).await {
            emit_log_internal(&app, &format!("Failed to backup config: {}", e), "error");
        }

        // Step 4: Uninstall existing version
        emit_log_internal(&app, "Step 3/5: Uninstalling existing version...", "info");
        self.uninstall_internal(&app, &installer_path).await?;

        // Step 5: Restore configuration
        emit_log_internal(&app, "Step 4/5: Restoring configuration...", "info");
        if let Err(e) = self.backup_manager.restore(&app).await {
            emit_log_internal(&app, &format!("Failed to restore config: {}", e), "error");
        }

        // Step 6: Install new version
        emit_log_internal(&app, "Step 5/5: Installing new version...", "info");
        self.install_internal(&app, &installer_path, &selected_features)
            .await?;

        // Get installed version
        let version = get_installed_version_with_app(Some(&app));

        emit_log_internal(&app, "Installation completed successfully!", "info");
        Ok(InstallResult {
            success: true,
            message: "Installation completed successfully!".to_string(),
            version: Some(version),
        })
    }

    pub async fn uninstall(&mut self, app: tauri::AppHandle) -> Result<InstallResult, String> {
        emit_log_internal(&app, "Starting uninstall process...", "info");

        // Download installer (needed for uninstall command)
        self.downloader.detect_region_with_app(&app).await?;
        let installer_path = self
            .downloader
            .download_installer_with_app(&app, &self.temp_dir)
            .await?;

        // Uninstall
        self.uninstall_internal(&app, &installer_path).await?;

        // Wait for uninstaller to complete and registry to be updated
        emit_log_internal(&app, "Waiting for cleanup to complete...", "info");
        tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;

        let version = get_installed_version_with_app(Some(&app));

        emit_log_internal(&app, "Uninstallation completed successfully!", "info");
        Ok(InstallResult {
            success: true,
            message: "Uninstallation completed successfully!".to_string(),
            version: Some(version),
        })
    }

    async fn uninstall_internal(
        &self,
        app: &tauri::AppHandle,
        installer_path: &PathBuf,
    ) -> Result<(), String> {
        emit_log_internal(app, "Running uninstall command...", "info");

        // Run the installer with /uninstall argument
        let output = Command::new(installer_path)
            .arg("/uninstall")
            .output()
            .map_err(|e| format!("Failed to run uninstaller: {}", e))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            emit_log_internal(app, &format!("Uninstall output: {}", stderr), "debug");
            // Note: Some uninstalls may return non-zero even when successful
            // We continue anyway
        }

        Ok(())
    }

    async fn install_internal(
        &self,
        app: &tauri::AppHandle,
        installer_path: &PathBuf,
        features: &[(String, bool)],
    ) -> Result<(), String> {
        emit_log_internal(
            app,
            "Running install command with selected features...",
            "info",
        );

        // Build arguments
        let mut args = Vec::new();

        for (feature_id, enabled) in features {
            match feature_id.as_str() {
                "quiet" => {
                    if *enabled {
                        args.push("/quiet".to_string());
                    }
                }
                "analytics" => {
                    args.push("/analytics".to_string());
                    args.push(if *enabled {
                        "Yes".to_string()
                    } else {
                        "No".to_string()
                    });
                }
                "flow" => {
                    args.push("/flow".to_string());
                    args.push(if *enabled {
                        "Yes".to_string()
                    } else {
                        "No".to_string()
                    });
                }
                "sso" => {
                    args.push("/sso".to_string());
                    args.push(if *enabled {
                        "Yes".to_string()
                    } else {
                        "No".to_string()
                    });
                }
                "update" => {
                    args.push("/update".to_string());
                    args.push(if *enabled {
                        "Yes".to_string()
                    } else {
                        "No".to_string()
                    });
                }
                "dfu" => {
                    args.push("/dfu".to_string());
                    args.push(if *enabled {
                        "Yes".to_string()
                    } else {
                        "No".to_string()
                    });
                }
                "backlight" => {
                    args.push("/backlight".to_string());
                    args.push(if *enabled {
                        "Yes".to_string()
                    } else {
                        "No".to_string()
                    });
                }
                "logivoice" => {
                    args.push("/logivoice".to_string());
                    args.push(if *enabled {
                        "Yes".to_string()
                    } else {
                        "No".to_string()
                    });
                }
                "aipromptbuilder" => {
                    args.push("/aipromptbuilder".to_string());
                    args.push(if *enabled {
                        "Yes".to_string()
                    } else {
                        "No".to_string()
                    });
                }
                "device-recommendation" => {
                    args.push("/device-recommendation".to_string());
                    args.push(if *enabled {
                        "Yes".to_string()
                    } else {
                        "No".to_string()
                    });
                }
                "smartactions" => {
                    args.push("/smartactions".to_string());
                    args.push(if *enabled {
                        "Yes".to_string()
                    } else {
                        "No".to_string()
                    });
                }
                "actions-ring" => {
                    args.push("/actions-ring".to_string());
                    args.push(if *enabled {
                        "Yes".to_string()
                    } else {
                        "No".to_string()
                    });
                }
                _ => {}
            }
        }

        // Send install arguments to frontend as debug level
        emit_log_internal(
            app,
            &format!("Install arguments: {:?}", args),
            "debug",
        );

        // Run installer with elevated privileges
        let output = Command::new(installer_path)
            .args(&args)
            .output()
            .map_err(|e| format!("Failed to run installer: {}", e))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            emit_log_internal(app, &format!("Install failed: {}", stderr), "error");
            return Err(format!(
                "Installation failed with exit code: {:?}",
                output.status.code()
            ));
        }

        emit_log_internal(app, "Installation command completed successfully", "info");
        Ok(())
    }

    pub async fn get_latest_version(&self) -> Result<String, String> {
        self.downloader.get_latest_version().await
    }
}

impl Default for Installer {
    fn default() -> Self {
        Self::new()
    }
}
