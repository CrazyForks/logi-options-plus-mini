//
//  UpdatesPreferencePaneView.swift
//  Logi Options+ mini
//
//  Created by Qetesh Wong on 4/3/2025.
//

import Foundation
import SwiftUI
import Sparkle
import Logging

private let lastCheckDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

enum logiOptionsPlusMiniServer: String, CaseIterable, Identifiable {
    case Global, China
    
    var id: Self { self }
    
    var description: String {
        switch self {
        case .Global: return "Global"
        case .China: return "China"
        }
    }
}

struct UpdatesPreferencePane: View {
    private let updater = UpdaterManager.shared.updater
    @State var selectedlogiOptionsPlusMiniServer: logiOptionsPlusMiniServer = .Global
    @State private var autoInstallation: Bool = false
    @State private var lastCheckDate: Date? = nil
    
    // Timer publisher for refreshing last check date
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox(label: Text("Update server")) {
                VStack(alignment: .leading) {
                    Picker("Logi Options+ mini Server", selection: $selectedlogiOptionsPlusMiniServer) {
                        ForEach(logiOptionsPlusMiniServer.allCases, id: \.self) { dataSource in
                            Text(dataSource.description)
                                .tag(dataSource)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .onAppear {
                        loadServer(&selectedlogiOptionsPlusMiniServer, key: "selectedlogiOptionsPlusMiniServer")
                    }
                    .onChange(of: selectedlogiOptionsPlusMiniServer) {
                        saveServer(selectedlogiOptionsPlusMiniServer, key: "selectedlogiOptionsPlusMiniServer")
                        
                        if selectedlogiOptionsPlusMiniServer.description == "China" {
                            UserDefaults.standard.set("https://v.qetesh.cc/d/Public/appcast.xml", forKey: "SUFeedURL")
                        } else {
                            updater.clearFeedURLFromUserDefaults()
                        }
                        let SUFeedURLFromINFO = Bundle.main.infoDictionary?["SUFeedURL"] as? String ?? ""
                        let SUFeedURLFromUserDefaults = UserDefaults.standard.string(forKey: "SUFeedURL") ?? SUFeedURLFromINFO
                        Logger.app.debug("\(String(localized: "Update server changed to")): \(SUFeedURLFromUserDefaults)")
                    }
                    
                    Text("Choose update server for Logi Options+ mini")
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
                        updater.automaticallyChecksForUpdates = newValue
                        Logger.app.debug("\(String(localized: "Auto-update")) \(updater.automaticallyChecksForUpdates ? String(localized: "enabled") : String(localized: "disabled"))")
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
                    Button("Check for Updates", action: updater.checkForUpdates)
                    
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
    
    func saveServer<T>(_ server: T, key: String) where T: RawRepresentable, T.RawValue == String {
        UserDefaults.standard.set(server.rawValue, forKey: key)
    }
    
    func loadServer(_ server: inout logiOptionsPlusMiniServer, key: String) {
        if let rawValue = UserDefaults.standard.string(forKey: key) {
            server = logiOptionsPlusMiniServer(rawValue: rawValue) ?? .Global
        }
    }
    
}

#Preview {
    UpdatesPreferencePane()
        .padding()
        .frame(width: 520)
}
