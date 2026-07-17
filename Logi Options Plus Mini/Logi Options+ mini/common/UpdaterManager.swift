//
//  UpdaterManager.swift
//  Logi Options+ mini
//
//  Singleton for managing Sparkle updater across the app
//

import Foundation
import Sparkle

final class UpdaterManager {
    static let shared = UpdaterManager()
    
    let controller: SPUStandardUpdaterController
    var updater: SPUUpdater { controller.updater }
    
    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
}

