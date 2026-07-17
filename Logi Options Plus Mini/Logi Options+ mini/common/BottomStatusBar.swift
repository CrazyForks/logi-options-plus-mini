//
//  BottomStatusBar.swift
//  Logi Options Plus Mini
//
//  Created by Qetesh Wong on 1/3/2025.
//
import SwiftUI

struct BottomStatusBar: View {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    @StateObject private var agentManager = AgentManager.shared
    @Environment(\.openWindow) private var openWindow
    @AppStorage("showUninstallButton") private var showUninstallButton: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                Spacer()
                // Hidden button to toggle uninstall button visibility
                Color.clear
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showUninstallButton.toggle()
                    }
                SettingsLink {
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundColor(agentManager.isAgentInstalled ? .green : .gray)
                        .help("App helper status")
                }
                .buttonStyle(.plain)
                
                Button {
                    openWindow(id: "about")
                } label: {
                    Text("Version \(version)(\(buildNumber))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.all, 5)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 10)

        }
        .frame(height: 20)
    }
}

struct BottomStatusBar_Previews: PreviewProvider {
    static var previews: some View {
        BottomStatusBar()
    }
}

#Preview {
    BottomStatusBar()
        .frame(width: 600)
}
