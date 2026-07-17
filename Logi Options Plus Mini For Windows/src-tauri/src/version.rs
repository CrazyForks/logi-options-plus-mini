use tauri::Emitter;
use winreg::enums::*;
use winreg::RegKey;
use winreg::HKEY;

const APP_GUID: &str = "{7703EAB8-FB5C-4B2A-B6ED-0E42A7DDF2DB}";

fn emit_log(app: &Option<&tauri::AppHandle>, message: &str, level: &str) {
    if let Some(app) = app {
        let _ = app.emit(
            "log-message",
            serde_json::json!({
                "message": message,
                "level": level,
            }),
        );
    }
    match level {
        "error" => log::error!("{}", message),
        "debug" => log::debug!("{}", message),
        _ => log::info!("{}", message),
    }
}

pub fn get_installed_version_with_app(app: Option<&tauri::AppHandle>) -> String {
    // Try to find installed version from registry
    // First try: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{GUID}
    // Second try: HKLM\SOFTWARE\LogiOptionsPlus

    if let Some(version) = check_uninstall_registry(HKEY_LOCAL_MACHINE, app) {
        return version;
    }

    if let Some(version) = check_uninstall_registry(HKEY_CURRENT_USER, app) {
        return version;
    }

    // Try LogiOptionsPlus specific registry key
    if let Some(version) = check_logi_options_plus_registry(app) {
        return version;
    }

    // Check if executable exists
    if let Some(version) = check_executable_version(app) {
        return version;
    }

    emit_log(&app, "Not Installed", "debug");
    "not installed".to_string()
}

fn check_uninstall_registry(hkey: HKEY, app: Option<&tauri::AppHandle>) -> Option<String> {
    let uninstall_path = format!(
        "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{}",
        APP_GUID
    );

    let hklm = RegKey::predef(hkey);
    match hklm.open_subkey(&uninstall_path) {
        Ok(key) => {
            // Must have DisplayVersion to be considered installed
            if let Ok(version) = key.get_value::<String, _>("DisplayVersion") {
                emit_log(&app, &format!("Found version from registry: {}", version), "debug");
                return Some(version);
            }
            // If no DisplayVersion, check if it's a残留条目 - don't return "installed"
            emit_log(&app, "Found uninstall registry key but no DisplayVersion, app may be partially uninstalled", "debug");
        }
        Err(_) => {}
    }
    None
}

fn check_logi_options_plus_registry(app: Option<&tauri::AppHandle>) -> Option<String> {
    // Try both HKEY_LOCAL_MACHINE and HKEY_CURRENT_USER
    let hkeys = [HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER];

    // Try multiple possible registry paths
    let paths = [
        "SOFTWARE\\LogiOptionsPlus",
        "SOFTWARE\\Logitech\\LogiOptionsPlus",
        "SOFTWARE\\WOW6432Node\\LogiOptionsPlus",
    ];

    for hkey in &hkeys {
        let hklm = RegKey::predef(*hkey);

        for path in &paths {
            if let Ok(key) = hklm.open_subkey(path) {
                if let Ok(version) = key.get_value::<String, _>("Version") {
                    emit_log(&app, &format!("Found version from Logi registry ({}): {}", path, version), "debug");
                    return Some(version);
                }
                if let Ok(version) = key.get_value::<String, _>("InstallVersion") {
                    emit_log(&app, &format!("Found install version from Logi registry ({}): {}", path, version), "debug");
                    return Some(version);
                }
            }
        }
    }
    None
}

fn check_executable_version(app: Option<&tauri::AppHandle>) -> Option<String> {
    let possible_paths = vec![
        r"C:\Program Files\LogiOptionsPlus\LogiOptionsPlus.exe",
        r"C:\Program Files (x86)\LogiOptionsPlus\LogiOptionsPlus.exe",
    ];

    for path in &possible_paths {
        let path_obj = std::path::Path::new(path);
        if path_obj.exists() {
            emit_log(&app, &format!("Found executable at: {}", path), "debug");
            // Return "installed" since we found the executable
            return Some("installed".to_string());
        }
    }
    None
}
