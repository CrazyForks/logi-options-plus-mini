//
//  Logger+App.swift
//  Logi Options+ mini
//
//  Global Logger factory for consistent logging across the app
//

import Foundation
import Logging

extension Logger {
    /// Shared app-wide logger instance
    static let app = Logger(label: Bundle.main.bundleIdentifier ?? "io.qetesh.Logi-Options-Plus-mini")
}

