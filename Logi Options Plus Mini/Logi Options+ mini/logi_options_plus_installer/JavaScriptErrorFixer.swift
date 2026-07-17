import Foundation
import Logging

/// JavaScript 错误修复器 - 删除损坏的配置备份文件
struct JavaScriptErrorFixer {
    
    private let fileManager = FileManager.default
    
    /// LogiOptionsPlus 配置文件目录
    private var configDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/LogiOptionsPlus")
    }
    
    /// 扫描损坏的配置备份文件
    /// - Returns: 找到的文件 URL 列表
    func scan() async throws -> [URL] {
        Logger.app.info("\(String(localized: "Scanning for corrupted config backup files..."))")
        
        guard fileManager.fileExists(atPath: configDirectory.path) else {
            Logger.app.info("\(String(localized: "LogiOptionsPlus config directory not found."))")
            return []
        }
        
        let contents = try fileManager.contentsOfDirectory(
            at: configDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        // 查找 config.json.XXXXXXX 文件
        let configBackupFiles = contents.filter { $0.lastPathComponent.hasPrefix("config.json.") }
        
        if configBackupFiles.isEmpty {
            Logger.app.info("\(String(localized: "No corrupted config backup files found."))")
        } else {
            Logger.app.info("\(String(localized: "Found")) \(configBackupFiles.count) \(String(localized: "corrupted config backup file(s)."))")
        }
        
        return configBackupFiles
    }
    
    /// 删除指定的文件
    /// - Parameter files: 要删除的文件 URL 列表
    /// - Returns: 成功删除的文件数量
    func deleteFiles(_ files: [URL]) throws -> Int {
        var deletedCount = 0
        for file in files {
            try fileManager.removeItem(at: file)
            Logger.app.info("\(String(localized: "Deleted")): \(file.lastPathComponent)")
            deletedCount += 1
        }
        return deletedCount
    }
}
