//
//  LogStore.swift
//  Logi Options Plus Mini
//
//  Created by Qetesh Wong on 19/2/2025.
//

import SwiftUI
import Logging

/// Log message with unique identifier
struct LogMessage: Identifiable, Equatable {
    let id: UUID
    let content: String
    
    init(_ content: String) {
        self.id = UUID()
        self.content = content
    }
}

class LogStore: ObservableObject {
    @Published var messages: [LogMessage] = []
    private var currentLogLevel: Logger.Level = .info
    
    init() {
        // 从 UserDefaults 加载初始日志级别
        loadLogLevel()
        
        // 监听日志级别变换通知
        NotificationCenter.default.addObserver(
            forName: .logLevelChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let logLevel = notification.object as? Logger.Level {
                // 更新当前日志级别（不重新初始化 LoggingSystem）
                self.currentLogLevel = logLevel
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func append(_ message: String) {
        let logMessage = LogMessage(message)
        if Thread.isMainThread {
            self.messages.append(logMessage)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.messages.append(logMessage)
            }
        }
    }
    
    func clearMessages() {
        if Thread.isMainThread {
            self.messages.removeAll()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.messages.removeAll()
            }
        }
    }
    
    func getCurrentLogLevel() -> Logger.Level {
        return currentLogLevel
    }
    
    func setCurrentLogLevel(_ level: Logger.Level) {
        currentLogLevel = level
    }
    
    // MARK: - LogLevel 枚举支持方法
    
    /// 获取当前的 LogLevel 枚举值
    func getCurrentLogLevelEnum() -> LogLevel {
        switch currentLogLevel {
        case .trace: return .trace
        case .debug: return .debug
        case .info: return .info
        case .notice: return .notice
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        }
    }
    
    /// 设置 LogLevel 枚举值并保存到 UserDefaults
    func setLogLevel(_ logLevel: LogLevel) {
        currentLogLevel = logLevel.loggerLevel
        UserDefaults.standard.set(logLevel.rawValue, forKey: "selectedLogLevel")
        NotificationCenter.default.post(name: .logLevelChanged, object: logLevel.loggerLevel)
    }
    
    private func loadLogLevel() {
        if let rawValue = UserDefaults.standard.string(forKey: "selectedLogLevel") {
            if let logLevel = LogLevel(rawValue: rawValue) {
                currentLogLevel = logLevel.loggerLevel
            } else {
                currentLogLevel = .info
            }
        } else {
            currentLogLevel = .info
        }
    }
}

extension Notification.Name {
    static let logLevelChanged = Notification.Name("logLevelChanged")
}

struct UILogHandler: LogHandler {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    var logLevel: Logger.Level {
        get { logStore.getCurrentLogLevel() }
        set { logStore.setCurrentLogLevel(newValue) }
    }
    
    let logStore: LogStore
    
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { nil }
        set { }
    }
    
    var metadata: Logger.Metadata = [:]
    
    init(logStore: LogStore) {
        self.logStore = logStore
    }
    
    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        let dateString = Self.dateFormatter.string(from: Date())
        let logEntry = "[\(dateString)] [\(level.rawValue.uppercased())] \(message)"
        logStore.append(logEntry)
    }
}
