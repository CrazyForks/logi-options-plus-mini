import Foundation
import Logging

class BackupManager {
    private let sourceDirectoryName = "LogiOptionsPlus"
    private let backupDirectoryName = "LogiOptionsPlus_bak"

    private static func directoryURL(named name: String) -> URL? {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent(name)
    }

    func performOperation(operation: String) {
        guard let sourceURL = BackupManager.directoryURL(named: sourceDirectoryName),
              let backupURL = BackupManager.directoryURL(named: backupDirectoryName) else {
            Logger.app.error("\(String(localized: "Failed to get Application Support directory"))")
            return
        }
              
        do {
            switch operation {
            case "backup":
                Logger.app.debug("\(String(localized: "Backing up configuration file..."))")
                try FileManager.default.moveItem(at: sourceURL, to: backupURL)
                Logger.app.info("💾 \(String(localized: "Configuration file backed up to")): \(backupURL.path)")
            case "restore":
                try FileManager.default.moveItem(at: backupURL, to: sourceURL)
                Logger.app.info("💾 \(String(localized: "Configuration file restored to")): \(sourceURL.path)")
            default:
                Logger.app.error("\(String(localized: "Unknown backup operation")): \(operation)")
            }
        } catch {
            Logger.app.error("\(String(localized: "Configuration file")) \(operation) \(String(localized: "failed")): \(error.localizedDescription)")
        }
    }
}
