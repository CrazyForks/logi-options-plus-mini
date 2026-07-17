mod backup;
mod commands;
mod downloader;
mod installer;
mod models;
mod version;

use commands::{
    check_update_with_endpoint, create_app_state, emit_log, get_features, get_installed_version,
    get_latest_version, get_version_info, install, uninstall,
};
use tauri::Manager;
use window_vibrancy::*;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Initialize logger
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    log::info!("Starting Logi Options+ mini application...");

    tauri::Builder::default()
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .manage(create_app_state())
        .invoke_handler(tauri::generate_handler![
            get_features,
            get_installed_version,
            get_latest_version,
            get_version_info,
            install,
            uninstall,
            emit_log,
            check_update_with_endpoint,
        ])
        .setup(|app| {
            #[cfg(target_os = "windows")]
            {
                if let Some(window) = app.get_webview_window("main") {
                    let _ = apply_acrylic(&window, Some((255, 255, 255, 125)));
                }
                if let Some(window) = app.get_webview_window("settings") {
                    let _ = apply_acrylic(&window, Some((255, 255, 255, 125)));
                }
                if let Some(window) = app.get_webview_window("update") {
                    let _ = apply_acrylic(&window, Some((255, 255, 255, 125)));
                }
            }

            Ok(())
        })
        .on_window_event(|window, event| {
            if window.label() == "main" && matches!(event, tauri::WindowEvent::CloseRequested { .. })
            {
                log::info!("Main window close requested, exiting application...");
                window.app_handle().exit(0);
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
