//
//  FileUtils.swift
//  Logi Options+ mini
//
//  Shared file utilities
//

import Foundation

enum FileUtils {
    /// Get a URL in the temporary directory for a given file name
    static func temporaryFileURL(forFileName fileName: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(fileName)
    }
}

