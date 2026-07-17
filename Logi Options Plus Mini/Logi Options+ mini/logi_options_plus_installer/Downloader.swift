import Foundation
import Logging

/// Download type enumeration
enum DownloadType {
    case installer
    case patch
    
    var fileName: String {
        switch self {
        case .installer:
            return "logioptionsplus_installer.zip"
        case .patch:
            return "logioptionsplus_installer_patch.zip"
        }
    }
}

class Downloader: NSObject, URLSessionDownloadDelegate {
    private let regionDetector = RegionDetector()

    func downloadInstaller(type: DownloadType = .installer) async throws {
        await regionDetector.detectRegion()

        let urlString: String
        switch type {
        case .installer:
            urlString = regionDetector.isInChina
                ? "https://download.logitech.com.cn/web/ftp/pub/techsupport/optionsplus/logioptionsplus_installer.zip"
                : "https://download01.logi.com/web/ftp/pub/techsupport/optionsplus/logioptionsplus_installer.zip"
        case .patch:
            urlString = "https://download01.logi.com/web/ftp/pub/techsupport/optionsplus/logioptionsplus_installer_patch.zip"
        }
        
        guard let url = URL(string: urlString) else {
            Logger.app.error("\(String(localized: "Invalid download URL")): \(urlString)")
            throw NSError(domain: "DownloadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
        }
        
        Logger.app.info("⏬ \(String(localized: "Downloading installer from")) \(urlString)")
        
        let destinationURL = FileUtils.temporaryFileURL(forFileName: type.fileName)
        
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 20 * 1024 * 1024, directory: nil)
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let session = URLSession(configuration: configuration)
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                Logger.app.error("\(String(localized: "Download failed")): \(String(localized: "Server returned error code")) \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                throw NSError(domain: "DownloadError", code: 3, userInfo: [NSLocalizedDescriptionKey: "invalid response status code"])
            }
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try data.write(to: destinationURL)
        
            Logger.app.debug("✅ \(String(localized: "Download complete to")) \(destinationURL.path)")
        } catch {
            Logger.app.error("\(String(localized: "Download failed")): \(error.localizedDescription)")
            throw error
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            let percent = Int((Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) * 100)
            Logger.app.debug("⏬ \(percent)%")
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Logger.app.debug("\(String(localized: "Downloaded file to")): \(location.path)")
    }
}
