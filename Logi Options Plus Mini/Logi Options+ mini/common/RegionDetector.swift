//
//  RegionDetector.swift
//  Logi Options Plus Mini
//
//  Created by Qetesh Wong on 21/1/2025.
//

import SwiftUI
import Foundation
import Logging

/// Region detector for determining if user is in mainland China
class RegionDetector: ObservableObject {
    @Published var isInChina: Bool = false
    @Published var isDetecting: Bool = false
    @Published var errorMessage: String? = nil
    
    private let traceURL = "https://cloudflare.com/cdn-cgi/trace"
    
    /// Detect user's region
    @MainActor
    func detectRegion() async {
        isDetecting = true
        errorMessage = nil
        
        do {
            Logger.app.info("🗺️ \(String(localized: "Region detection via")) \(traceURL)")
            isInChina = try await fetchRegionInfo()
            Logger.app.info("🗺️ \(String(localized: "Region")): \(regionCode == "China" ? String(localized: "China") : String(localized: "Global"))", metadata: ["isInChina": .stringConvertible(isInChina)])
        } catch {
            errorMessage = "Detection failed: \(error.localizedDescription)"
            Logger.app.error("\(String(localized: "Unable to detect location"))", metadata: ["error": .stringConvertible(error.localizedDescription)])
            isInChina = false // Default to global on error
        }
        
        isDetecting = false
    }
    
    /// Fetch region information from Cloudflare
    private func fetchRegionInfo() async throws -> Bool {
        guard let url = URL(string: traceURL) else {
            throw RegionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RegionError.networkFailed
        }
        
        guard let responseText = String(data: data, encoding: .utf8) else {
            throw RegionError.invalidData
        }
        
        return responseText.contains("loc=CN")
    }
}

/// Region detection errors
enum RegionError: LocalizedError {
    case invalidURL
    case networkFailed
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkFailed: return "Network request failed"
        case .invalidData: return "Invalid response data"
        }
    }
}

extension RegionDetector {
    /// Region status description
    var statusDescription: String {
        if isDetecting { return "Detecting..." }
        if errorMessage != nil { return "Error" }
        return regionCode
    }
    
    /// Region code (CN or GLOBAL)
    var regionCode: String {
        isInChina ? "China" : "Global"
    }
}
