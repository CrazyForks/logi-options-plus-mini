import Foundation
import Logging
import AppKit

class InstallerRunner {
    func runInstaller(selectedFeatures: String, type: DownloadType = .installer) async throws {
        let installerURL = FileUtils.temporaryFileURL(
            forFileName: "\(type.extractionDirectoryName)/\(type.installerAppBundleName)/Contents/MacOS/logioptionsplus_installer"
        )
        try await runExecutable(at: installerURL, arguments: selectedFeatures, isPatch: false)
    }
    
    func runPatch() async throws {
        // Patch 使用普通用户上下文打开应用，以便访问用户钥匙串
        let patchAppURL = FileUtils.temporaryFileURL(forFileName: "logioptionsplus_installer_patch/logioptionsplus_installer.app")
        try await runPatchAsUser(at: patchAppURL)
    }
    
    /// 以普通用户身份运行 patch 应用（保持用户钥匙串访问权限）
    private func runPatchAsUser(at appURL: URL) async throws {
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            Logger.app.error("\(String(localized: "Patch application not found")): \(appURL.path)")
            throw NSError(domain: "InstallerNotFound", code: 0, userInfo: [NSLocalizedDescriptionKey: "Patch application not found"])
        }
        
        Logger.app.info("🔧 \(String(localized: "Running fix patch..."))")
        Logger.app.debug("\(String(localized: "Opening patch application as current user")): \(appURL.path)")
        
        // 使用 NSWorkspace 以当前用户身份打开应用
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        do {
            try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
            Logger.app.info("✅ \(String(localized: "Patch application launched successfully"))")
        } catch {
            Logger.app.error("\(String(localized: "Failed to launch patch application")): \(error)")
            throw NSError(domain: "InstallerRunner", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to launch patch application: \(error.localizedDescription)"])
        }
    }
    
    private func runExecutable(at installerURL: URL, arguments: String, isPatch: Bool) async throws {
        guard FileManager.default.fileExists(atPath: installerURL.path) else {
            Logger.app.error("\(String(localized: "Installer not found")): \(installerURL.path)")
            throw NSError(domain: "InstallerNotFound", code: 0, userInfo: [NSLocalizedDescriptionKey: "Installer not found"])
        }
    
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installerURL.path)
        
        if isPatch {
            Logger.app.info("🔧 \(String(localized: "Running fix patch..."))")
        } else if arguments == "--uninstall" {
            Logger.app.info("🗑️ \(String(localized: "Uninstalling..."))")
        } else {
            Logger.app.info("🚀 \(String(localized: "Installing..."))")
        }
        
        // 检查 LaunchDaemons 状态，选择执行方式
        if AgentManager.shared.isAgentInstalled && AgentManager.shared.isAgentRunning {
            try await runWithLaunchDaemons(installerPath: installerURL.path, arguments: arguments)
        } else {
            try await runWithAppleScript(installerPath: installerURL.path, arguments: arguments)
        }

        // 安装完成后启动应用程序（仅适用于非 patch 的 quiet 安装）
        if !isPatch && arguments.contains("--quiet") {
            Logger.app.info("🚀 \(String(localized: "Starting Logi Options+ application..."))")
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/logioptionsplus.app"),
                                               configuration: NSWorkspace.OpenConfiguration(),
                                               completionHandler: nil)
        }
    }
    
    /// 使用 LaunchDaemons 执行安装命令
    private func runWithLaunchDaemons(installerPath: String, arguments: String) async throws {
        let command = arguments.isEmpty ? "\"\(installerPath)\"" : "\"\(installerPath)\" \(arguments)"
        Logger.app.debug("\(String(localized: "Using LaunchDaemons to execute the installation command")): \(command)")
        
        let (success, output) = try await AgentManager.shared.runCommandThroughAgent(command: command)
        
        Logger.app.debug("\(String(localized: "LaunchDaemons execution result")): \(success ? String(localized: "Success") : String(localized: "Failed"))")
        if !output.isEmpty {
            Logger.app.debug("\(String(localized: "LaunchDaemons execution output")):\n\(output)")
        }
        
        if !success {
            throw NSError(domain: "InstallerRunner", code: 4, userInfo: [NSLocalizedDescriptionKey: "LaunchDaemons execution failed: \(output)"])
        }
    }
    
    /// 使用 AppleScript 执行安装命令（原有方法）
    private func runWithAppleScript(installerPath: String, arguments: String) async throws {
        let script: String
        if arguments.isEmpty {
            script = """
            do shell script (quoted form of "\(installerPath)") with prompt "Administrator Privileges Required" with administrator privileges
            """
        } else {
            script = """
            do shell script (quoted form of "\(installerPath)") & " \(arguments)" with prompt "Administrator Privileges Required" with administrator privileges
            """
        }
        
        Logger.app.debug("\(String(localized: "Using AppleScript to execute the installation command")): \n\(script)")

        guard let appleScript = NSAppleScript(source: script) else {
            Logger.app.error("\(String(localized: "Failed to create AppleScript"))")
            throw NSError(domain: "InstallerRunner", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create AppleScript"])
        }
        
        var errorDict: NSDictionary?
        let result = appleScript.executeAndReturnError(&errorDict)
        
        if let errorDict = errorDict, let errorMessage = errorDict["NSAppleScriptErrorMessage"] as? String {
            Logger.app.error("\(String(localized: "AppleScript execution failed")): \(errorMessage)")
            throw NSError(domain: "InstallerRunner", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        } else if result.stringValue != nil {
            Logger.app.debug("\(String(localized: "AppleScript execution successful"))")
        } else {
            Logger.app.error("\(String(localized: "AppleScript execution failed: No output"))")
            throw NSError(domain: "InstallerRunner", code: 2, userInfo: [NSLocalizedDescriptionKey: "AppleScript execution failed: No output"])
        }
    }
}
