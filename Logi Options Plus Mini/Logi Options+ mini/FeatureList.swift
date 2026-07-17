import SwiftUI

enum FeatureList: CaseIterable {
    case logiOptionsPlusInstaller
    
    var displayName: String {
        switch self {
        case .logiOptionsPlusInstaller:
            return "Logi Options+ Installer"
        }
    }
    
    var iconName: String {
        switch self {
        case .logiOptionsPlusInstaller:
            return "LogiInstallerIcon"
        }
    }
    
    var description: String {
        switch self {
        case .logiOptionsPlusInstaller:
            return "Custom Logi Options+"
        }
    }
}
