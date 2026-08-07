import SwiftUI
import Logging
import Sparkle

@main
struct LogiOptionsPlusInstallerApp: App {
    private let logStore: LogStore
    @State private var isAboutViewPresented = false
    
    init() {
        let store = LogStore()
        self.logStore = store
        LoggingSystem.bootstrap { label in
            return UILogHandler(logStore: store)
        }
        
        // Initialize and start the shared updater after its initial server is resolved.
        let updaterManager = UpdaterManager.shared
        updaterManager.start()
        
        AgentManager.shared.checkAgentStatus()
        
        // 启动时检查更新设置，如果开启了自动更新则进行一次后台检查
        checkForUpdatesOnStartup()
    }
    
    /// 启动时检查更新的私有方法
    private func checkForUpdatesOnStartup() {
        let updaterManager = UpdaterManager.shared
        
        // 延迟检查，让应用完全启动后再执行
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if updaterManager.updater.automaticallyChecksForUpdates {
                Logger.app.debug("\(String(localized: "Checking for updates in background..."))")
                updaterManager.checkForUpdatesInBackground()
            } else {
                Logger.app.debug("\(String(localized: "Skipping update check, reason: user did not enable automatic updates"))")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(logStore)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        WindowGroup("About", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 300, height: 400)
        
        .commands {
            CommandGroup(replacing: .appInfo) {
                AboutCommandView()
            }
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updaterManager: UpdaterManager.shared)
            }
        }
        
        Settings {
            PreferencesView()
                .environmentObject(logStore)
        }
    }
}

struct AboutCommandView: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button("About \(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App")") {
            openWindow(id: "about")
        }
    }
}
