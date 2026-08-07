//
//  UpdatesPreferencePaneView.swift
//  Logi Options+ mini
//
//  Created by Qetesh Wong on 4/3/2025.
//

import Foundation
import Combine
import SwiftUI
import Sparkle
import Logging

private let lastCheckDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct UpdatesPreferencePane: View {
    private let updater = UpdaterManager.shared.updater
    @AppStorage(logiOptionsPlusMiniServer.userDefaultsKey)
    private var selectedServerRawValue = logiOptionsPlusMiniServer.Global.rawValue
    @State private var autoInstallation: Bool = false
    @State private var lastCheckDate: Date? = nil

    private var selectedServer: logiOptionsPlusMiniServer {
        logiOptionsPlusMiniServer(rawValue: selectedServerRawValue) ?? .Global
    }

    private var selectedServerBinding: Binding<logiOptionsPlusMiniServer> {
        Binding(
            get: { selectedServer },
            set: { newValue in
                selectedServerRawValue = newValue.rawValue
                UpdaterManager.shared.setUpdateServer(newValue)
            }
        )
    }

    private var serverDescription: String {
        switch selectedServer {
        case .Automatic:
            return String(localized: "Automatically select the update server based on the current network region.")
        case .Global, .China:
            return String(localized: "Choose update server for Logi Options+ mini")
        }
    }

    // Timer publisher for refreshing last check date
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox(label: Text("Update server")) {
                VStack(alignment: .leading) {
                    Picker("Logi Options+ mini Server", selection: selectedServerBinding) {
                        ForEach(logiOptionsPlusMiniServer.allCases) { server in
                            Text(server.description)
                                .tag(server)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()

                    Text(serverDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .groupBoxStyle(PreferencesGroupBoxStyle())
            
            GroupBox(label: Text("Auto-check for updates")) {
                VStack(alignment: .leading) {
                    Toggle(
                        "",
                        isOn: $autoInstallation
                    )
                    .onAppear {
                        // 初始化时同步当前的自动更新设置状态
                        autoInstallation = updater.automaticallyChecksForUpdates
                        Logger.app.debug("\(String(localized: "Initial auto-update state")): \(autoInstallation ? String(localized: "enabled") : String(localized: "disabled"))")
                    }
                    .onChange(of: autoInstallation) { oldValue, newValue in
                        UpdaterManager.shared.setAutomaticallyChecksForUpdates(newValue)
                        Logger.app.debug("\(String(localized: "Auto-update")) \(newValue ? String(localized: "enabled") : String(localized: "disabled"))")
                        Logger.app.debug("\(String(localized: "Update check frequency")): \(String(localized: "every")) \(Int(updater.updateCheckInterval/3600)) \(String(localized: "hours"))")
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .groupBoxStyle(PreferencesGroupBoxStyle())
            
            Divider()

            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Button("Check for Updates", action: UpdaterManager.shared.checkForUpdates)
                    
                    if let date = lastCheckDate {
                        Text("Last checked: \(date, formatter: lastCheckDateFormatter)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never checked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                Spacer()
            }
            .onAppear {
                lastCheckDate = updater.lastUpdateCheckDate
            }
            .onReceive(refreshTimer) { _ in
                // Periodically sync with updater's last check date
                if lastCheckDate != updater.lastUpdateCheckDate {
                    lastCheckDate = updater.lastUpdateCheckDate
                }
            }
        }
        
    }
    
}

#Preview {
    UpdatesPreferencePane()
        .padding()
        .frame(width: 520)
}
