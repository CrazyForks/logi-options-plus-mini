import SwiftUI
import Sparkle
import ConfettiSwiftUI

struct AboutView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    @State private var trigger: Int = 0

    private let updaterManager: UpdaterManager
    private let updater: SPUUpdater
    
    init() {
        let updaterManager = UpdaterManager.shared
        self.updaterManager = updaterManager
        self.updater = updaterManager.updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }
    
    var body: some View {
        VStack(spacing: 15) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .cornerRadius(12)
            
            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App Name")
                .font(.title)
                .bold()
            
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
            Button(
                "Version \(version)(\(buildNumber))"
            ) {
                trigger += 1
            }
            .buttonStyle(PlainButtonStyle())
            .confettiCannon(trigger: $trigger, num: 50, openingAngle: Angle(degrees: 30), closingAngle: Angle(degrees: 160), radius: 200)

            Button("GitHub") {
                if let url = URL(string: "https://github.com/Qetesh/logi-options-plus-mini") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(LinkButtonStyle())
            
            Button("Check for Updates", action: updaterManager.checkForUpdates)
                .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
                .buttonStyle(DefaultButtonStyle())
        }
        .padding()
        .frame(width: 300)
        .background(VisualEffectView().ignoresSafeArea())
        .escapeKeyToClose()
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
