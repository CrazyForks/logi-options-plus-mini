//
//  DownloadSourcePreferencePaneView.swift
//  Logi Options Plus Mini
//

import SwiftUI
import Logging

struct DownloadSourcePreferencePane: View {
    @AppStorage(InstallerDownloadSource.userDefaultsKey)
    private var selectedSourceRawValue = InstallerDownloadSource.automatic.rawValue

    private var selectedSource: InstallerDownloadSource {
        InstallerDownloadSource(rawValue: selectedSourceRawValue) ?? .automatic
    }

    private var selectedSourceBinding: Binding<InstallerDownloadSource> {
        Binding(
            get: { selectedSource },
            set: { newValue in
                selectedSourceRawValue = newValue.rawValue
                Logger.app.info("🌐 \(String(localized: "Download source")): \(newValue.title)")
            }
        )
    }

    private var sourceDescription: String {
        switch selectedSource {
        case .automatic:
            return String(localized: "Automatically select the installer download source based on the current network region.")
        case .global:
            return String(localized: "Always use the Global installer download source without detecting the network region.")
        case .china:
            return String(localized: "Always use the China installer download source without detecting the network region.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox(label: Text("Download Source")) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Download Source", selection: selectedSourceBinding) {
                        ForEach(InstallerDownloadSource.allCases) { source in
                            Text(source.title)
                                .tag(source)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()

                    Text(sourceDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 300, alignment: .leading)
                }
            }
            .groupBoxStyle(PreferencesGroupBoxStyle())
        }
    }
}

#Preview {
    DownloadSourcePreferencePane()
        .padding()
        .frame(width: 520)
}
