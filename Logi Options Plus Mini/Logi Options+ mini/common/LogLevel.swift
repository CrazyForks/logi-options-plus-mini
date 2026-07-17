//
//  LogLevel.swift
//  Logi Options+ mini
//
//  Created by Qetesh Wong on 4/3/2025.
//

import Foundation
import Logging

enum LogLevel: String, CaseIterable, Identifiable {
    case trace = "trace"
    case debug = "debug"
    case info = "info"
    case notice = "notice"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    public var id: Self { self }
    
    public static var `default` = LogLevel.info
    
    var description: String {
        switch self {
        case .trace: return "Trace"
        case .debug: return "Debug"
        case .info: return "Info"
        case .notice: return "Notice"
        case .warning: return "Warning"
        case .error: return "Error"
        case .critical: return "Critical"
        }
    }
    
    var loggerLevel: Logger.Level {
        switch self {
        case .trace: return .trace
        case .debug: return .debug
        case .info: return .info
        case .notice: return .notice
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        }
    }
} 