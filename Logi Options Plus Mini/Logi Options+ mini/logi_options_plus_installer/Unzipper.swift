import Foundation
import ZipArchive
import Logging

class Unzipper {
    func unzipInstaller(type: DownloadType = .installer) async throws {
        let zipURL = FileUtils.temporaryFileURL(forFileName: type.fileName)
        let destinationFolder: String
        switch type {
        case .installer:
            destinationFolder = "logioptionsplus_installer"
        case .patch:
            destinationFolder = "logioptionsplus_installer_patch"
        }
        let destinationFolderURL = FileUtils.temporaryFileURL(forFileName: destinationFolder)
        
        SSZipArchive.unzipFile(atPath: zipURL.path, toDestination: destinationFolderURL.path)
        Logger.app.info("🗜️ \(String(localized: "File extracted to")): \(destinationFolderURL.path)")
    }
}
