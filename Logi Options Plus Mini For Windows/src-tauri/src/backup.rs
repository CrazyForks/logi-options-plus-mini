use log::{debug, info};
use std::path::PathBuf;
use tauri::Emitter;
use tokio::fs;

#[cfg(not(target_os = "windows"))]
async fn copy_dir_recursive(src: &PathBuf, dst: &PathBuf) -> Result<(), String> {
    fs::create_dir_all(dst)
        .await
        .map_err(|e| format!("Failed to create directory: {}", e))?;

    let mut entries = fs::read_dir(src)
        .await
        .map_err(|e| format!("Failed to read directory: {}", e))?;

    while let Some(entry) = entries.next_entry().await.map_err(|e| e.to_string())? {
        let src_path = entry.path();
        let dst_path = dst.join(entry.file_name());

        if src_path.is_dir() {
            copy_dir_recursive(&src_path, &dst_path).await?;
        } else {
            fs::copy(&src_path, &dst_path)
                .await
                .map_err(|e| format!("Failed to copy file: {}", e))?;
        }
    }
    Ok(())
}

fn emit_log(app: &tauri::AppHandle, message: &str, level: &str) {
    let _ = app.emit(
        "log-message",
        serde_json::json!({
            "message": message,
            "level": level,
        }),
    );
    match level {
        "error" => log::error!("{}", message),
        "debug" => debug!("{}", message),
        _ => info!("{}", message),
    }
}

const APP_DATA_PATH: &str = "LogiOptionsPlus";
const BACKUP_SUFFIX: &str = "_bak";

pub struct BackupManager {
    config_dir: PathBuf,
    backup_dir: PathBuf,
}

impl BackupManager {
    pub fn new() -> Self {
        let config_dir = dirs::data_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join(APP_DATA_PATH);

        let backup_dir = dirs::data_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join(format!("{}{}", APP_DATA_PATH, BACKUP_SUFFIX));

        BackupManager {
            config_dir,
            backup_dir,
        }
    }

    pub async fn backup(&self, app: &tauri::AppHandle) -> Result<(), String> {
        emit_log(app, "Starting configuration backup", "info");
        emit_log(app, &format!("Source config directory: {:?}", self.config_dir), "debug");
        emit_log(app, &format!("Backup destination directory: {:?}", self.backup_dir), "debug");

        if !self.config_dir.exists() {
            emit_log(app, "Config directory does not exist, skipping backup", "debug");
            return Ok(());
        }

        // Remove existing backup if exists
        if self.backup_dir.exists() {
            emit_log(app, "Removing existing backup directory", "info");
            fs::remove_dir_all(&self.backup_dir)
                .await
                .map_err(|e| format!("Failed to remove old backup: {}", e))?;
        }

        // Copy entire directory tree using robocopy (Windows) or recursive copy
        emit_log(app, "Copying configuration directory...", "info");

        #[cfg(target_os = "windows")]
        {
            // Use robocopy for fast directory copy on Windows
            let output = std::process::Command::new("robocopy")
                .args([
                    self.config_dir.to_string_lossy().as_ref(),
                    self.backup_dir.to_string_lossy().as_ref(),
                    "/E",  // Copy all subdirectories including empty ones
                    "/NFL", // No file list (reduce output)
                    "/NDL", // No directory list
                    "/NJH", // No job header
                    "/NJS", // No job summary
                ])
                .output()
                .map_err(|e| format!("Failed to run robocopy: {}", e))?;

            // robocopy returns 0-7 for success, 8+ for errors
            let exit_code = output.status.code().unwrap_or(-1);
            if exit_code >= 8 {
                let stderr = String::from_utf8_lossy(&output.stderr);
                return Err(format!("robocopy failed: {}", stderr));
            }
        }

        #[cfg(not(target_os = "windows"))]
        {
            // Fallback for non-Windows: recursive copy
            copy_dir_recursive(&self.config_dir, &self.backup_dir).await?;
        }

        emit_log(app, "Backup completed successfully", "info");
        emit_log(app, &format!("Configuration backed up to {:?}", self.backup_dir), "debug");
        Ok(())
    }

    pub async fn restore(&self, app: &tauri::AppHandle) -> Result<(), String> {
        emit_log(app, "Starting configuration restore", "info");
        emit_log(app, &format!("Backup source directory: {:?}", self.backup_dir), "debug");
        emit_log(app, &format!("Restore destination directory: {:?}", self.config_dir), "debug");

        if !self.backup_dir.exists() {
            emit_log(app, "Backup directory does not exist, skipping restore", "debug");
            return Ok(());
        }

        // Remove existing config directory
        if self.config_dir.exists() {
            emit_log(app, "Removing existing config directory", "info");
            fs::remove_dir_all(&self.config_dir)
                .await
                .map_err(|e| format!("Failed to remove config directory: {}", e))?;
        }

        // Copy entire directory tree using robocopy (Windows) or recursive copy
        emit_log(app, "Restoring configuration directory...", "info");

        #[cfg(target_os = "windows")]
        {
            let output = std::process::Command::new("robocopy")
                .args([
                    self.backup_dir.to_string_lossy().as_ref(),
                    self.config_dir.to_string_lossy().as_ref(),
                    "/E",
                    "/NFL",
                    "/NDL",
                    "/NJH",
                    "/NJS",
                ])
                .output()
                .map_err(|e| format!("Failed to run robocopy: {}", e))?;

            let exit_code = output.status.code().unwrap_or(-1);
            if exit_code >= 8 {
                let stderr = String::from_utf8_lossy(&output.stderr);
                return Err(format!("robocopy failed: {}", stderr));
            }
        }

        #[cfg(not(target_os = "windows"))]
        {
            copy_dir_recursive(&self.backup_dir, &self.config_dir).await?;
        }

        emit_log(app, "Restore completed successfully", "info");
        emit_log(app, &format!("Configuration restored to {:?}", self.config_dir), "debug");
        Ok(())
    }

}

impl Default for BackupManager {
    fn default() -> Self {
        Self::new()
    }
}
