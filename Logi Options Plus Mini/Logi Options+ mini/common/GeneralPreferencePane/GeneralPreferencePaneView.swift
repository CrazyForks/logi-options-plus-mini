//
//  GeneralPreferencePaneView.swift
//  Logi Options+ mini
//
//  Created by Qetesh Wong on 4/3/2025.
//

import Foundation
import SwiftUI
import Logging

struct GeneralPreferencePane: View {
    @EnvironmentObject var logStore: LogStore
    @StateObject private var agentManager = AgentManager.shared
    @State private var isAgentOperationInProgress = false
    
    private var selectedLogLevelBinding: Binding<LogLevel> {
        Binding(
            get: { logStore.getCurrentLogLevelEnum() },
            set: { newValue in
                logStore.setLogLevel(newValue)
                Logger.app.info("\(String(localized: "Log level changed to")): \(newValue.description)")
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox(label: Text("Log Level")) {
                VStack(alignment: .leading) {
                    Picker("Log Level", selection: selectedLogLevelBinding) {
                        ForEach(LogLevel.allCases, id: \.self) { level in
                            Text(level.description)
                                .tag(level)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    
                    Text("Choose the minimum log level to display.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .groupBoxStyle(PreferencesGroupBoxStyle())
            
            // Agent 管理
            GroupBox(label: Text("App helper")) {
                VStack(alignment: .leading) {
                    HStack {
                        Circle()
                            .frame(width: 10, height: 10)
                            .foregroundColor(agentManager.isAgentInstalled ? .green : .gray)
                            .help("App helper status")
                            .onTapGesture {
//                                agentManager.checkAgentStatus()
                                agentManager.checkAgentRunningStatus()
                            }
                                                
                        // 根据 Agent 状态显示相应按钮
                        if isAgentOperationInProgress {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.5)
                        } else if agentManager.isAgentInstalled {
                            Button("Uninstall App Helper") {
                                uninstallAgent()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Install App Helper") {
                                installAgent()
                            }
                            .buttonStyle(.borderedProminent)
                        }

                    }
                    
                    Text("Let the app do tasks without asking for your password every time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 300, alignment: .leading)
                }
            }
            .groupBoxStyle(PreferencesGroupBoxStyle())
            
            // 权限管理
            GroupBox(label: Text("Permissions")) {
                VStack(alignment: .leading) {
                    Button("Check Permissions") {
                        checkPermissions()
                    }
                    .buttonStyle(.bordered)
                    
                    Text("Check and manage system permissions required by this app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 300, alignment: .leading)
                }
            }
            .groupBoxStyle(PreferencesGroupBoxStyle())
        }
    }
        
    private func installAgent() {
        guard !isAgentOperationInProgress else { return }
        
        isAgentOperationInProgress = true
        
        Task {
            do {
                try await agentManager.installAgent()
                Logger.app.info("\(String(localized: "App helper installed. Checking status..."))")
                
                // 循环验证 Agent 是否成功运行，最多等待 15 秒
                let maxAttempts = 15
                let delaySeconds = 1.0
                var verificationSuccess = false
                
                for attempt in 1...maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    agentManager.checkAgentRunningStatus()
                    
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                    if agentManager.isAgentInstalled && agentManager.isAgentRunning {
                        verificationSuccess = true
                        break
                    }
                    if attempt == maxAttempts {
                    }
                }
                
                await MainActor.run {
                    if verificationSuccess {
                        Logger.app.info("\(String(localized: "App helper is working"))")
                    } else {
                        Logger.app.warning("\(String(localized: "App helper installed but is not responding"))")
                    }
                    isAgentOperationInProgress = false
                }
            } catch {
                await MainActor.run {
                    Logger.app.error("\(String(localized: "App helper installation failed")): \(error.localizedDescription)")
                    isAgentOperationInProgress = false
                }
            }
        }
    }
    
    private func uninstallAgent() {
        guard !isAgentOperationInProgress else { return }
        
        isAgentOperationInProgress = true
        
        Task {
            do {
                try await agentManager.uninstallAgent()
                await MainActor.run {
                    Logger.app.info("\(String(localized: "App helper removed"))")
                    isAgentOperationInProgress = false
                }
            } catch {
                await MainActor.run {
                    Logger.app.error("\(String(localized: "Failed to remove app helper")): \(error.localizedDescription)")
                    isAgentOperationInProgress = false
                }
            }
        }
    }
    
    private func checkPermissions() {
        PermissionChecker.shared.showPermissionWindow()
    }
}

#Preview {
    GeneralPreferencePane()
        .padding()
        .environmentObject(LogStore())
}
