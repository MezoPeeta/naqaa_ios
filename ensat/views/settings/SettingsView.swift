//
//  SettingsView.swift
//  ensat
//
//  Created by Mazen on 08/08/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(LanguageStore.self) private var languageStore
    @State private var showsLanguagePicker = false
    @State private var showsRestartAlert = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.homeBackground.ignoresSafeArea()
                List {
                    Section("General") {
                        Button { showsLanguagePicker = true } label: {
                            HStack {
                                Text("Language")
                                Spacer()
                                Text(languageStore.language.nativeName ?? String(localized: "System"))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Section("About") {
                        LabeledContent("Version", value: appVersion)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .sheet(isPresented: $showsLanguagePicker) {
                LanguagePickerSheet { showsRestartAlert = languageStore.needsRestart }
            }
            .alert("Restart required", isPresented: $showsRestartAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Close and reopen the app to apply the new language.")
            }
            .navigationTitle("Settings")
        }

    }
}

#Preview {
    SettingsView()
        .environment(LanguageStore())
        .preferredColorScheme(.dark)
}
