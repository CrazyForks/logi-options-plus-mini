//
//  PreferencesView.swift.swift
//  Logi Options Plus Mini
//
//  Created by Qetesh Wong on 1/3/2025.
//

import SwiftUI

struct PreferencesView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralPreferencePane()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(0)

            DownloadSourcePreferencePane()
                .tabItem {
                    Label("Download Source", systemImage: "arrow.down.circle")
                }
                .tag(1)

            UpdatesPreferencePane()
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath.circle")
                }
                .tag(2)
        }
        .padding(20)
        .frame(minWidth: 500)
        .background(VisualEffectView().ignoresSafeArea())
        .escapeKeyToClose()
    }
}

struct PreferencesGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 20) {
            configuration.label
                .frame(width: 180, alignment: .trailing)
            
            VStack(alignment: .leading) {
                configuration.content
            }
        }
    }
}

struct PreferencesViewProvider: PreviewProvider {
    static var previews: some View {
        return PreferencesView()
            .environmentObject(LogStore())
    }
}

#Preview {
    PreferencesView()
        .environmentObject(LogStore())
}
