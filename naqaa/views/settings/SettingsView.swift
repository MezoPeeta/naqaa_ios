//
//  SettingsView.swift
//  naqaa
//
//  Created by Mazen on 08/08/2026.
//

import SwiftUI

struct SettingsView: View {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.settingsBackground.ignoresSafeArea()
                VStack {
                    Text("Asd")
                }

            }
            .safeAreaInset(edge: .bottom) {
                Text("Version \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
            .navigationTitle("Settings")
        }

    }
}

#Preview {
    SettingsView()
}
