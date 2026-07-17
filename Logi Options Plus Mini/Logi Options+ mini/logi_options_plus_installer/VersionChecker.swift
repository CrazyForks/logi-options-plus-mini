import Foundation
import Logging

func getAppVersionUsingBundle(appPath: String) -> String? {
    let fileManager = FileManager.default
    
    guard fileManager.fileExists(atPath: appPath) else { return nil }
    
    // Directly read Info.plist to avoid macOS bundle caching issues
    let infoPlistPath = "\(appPath)/Contents/Info.plist"
    guard fileManager.fileExists(atPath: infoPlistPath),
          let plistData = fileManager.contents(atPath: infoPlistPath),
          let plistDict = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
        return nil
    }
    
    return plistDict["CFBundleShortVersionString"] as? String
}

func getLogiOptionsPlusVersion(initial: Bool = false) -> String {
    if let version = getAppVersionUsingBundle(appPath: "/Applications/logioptionsplus.app") {
        Logger.app.debug("\(String(localized: "Found Logi Options+ already installed. Version")): \(version)")
        if version != "" && initial {
            Logger.app.info("✅ \(String(localized: "Logi Options+ is already installed."))")
        }
        return version
    } else {
        Logger.app.info("🗑️ \(String(localized: "Logi Options+ is not installed."))")
        return "not installed"
    }
}

func getLogiOptionsPlusLatestVersion() async -> String {
    guard let urlVersion = URL(string: "https://updates.optionsplus.logitechg.com/pipeline/v2/update/optionsplus5/osx/public/update.json") else {
        return "Unknown"
    }
    
    let configuration = URLSessionConfiguration.default
    configuration.urlCache = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 20 * 1024 * 1024, directory: nil)
    configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    
    let session = URLSession(configuration: configuration)
    
    var request = URLRequest(url: urlVersion)
    request.setValue("GHubDownloader/1.0", forHTTPHeaderField: "User-Agent")
    request.setValue("*/*", forHTTPHeaderField: "Accept")
    request.setValue("2.5.926888", forHTTPHeaderField: "logi-app-version")
    
    do {
        let (data, _) = try await session.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let version = json["version"] as? String {
            Logger.app.debug("\(String(localized: "Latest Logi Options+ version")): \(version)")
            return version
        } else {
            Logger.app.error("\(String(localized: "Failed to parse version from update JSON."))")
            return "Unknown"
        }
    } catch {
        Logger.app.error("\(String(localized: "Error fetching latest version")): \(error.localizedDescription)")
        return "Unknown"
    }
}
