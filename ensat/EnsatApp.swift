//
//  ensatApp.swift
//  ensat
//
//  Created by Mazen on 16/05/2026.
//

import Foundation
import PostHog
import SwiftUI
import SwiftData
import UIKit

@main
struct EnsatApp: App {

    @State private var languageStore = LanguageStore()
    @State private var networkMonitor = NetworkMonitor()

    private let sharedModelContainer: ModelContainer
    @State private var downloadManager: DownloadManager

    init() {
        #if !DEBUG
        Self.configurePostHog()
        #endif
        let container = Self.makeModelContainer()
        sharedModelContainer = container
        _downloadManager = State(initialValue: DownloadManager(container: container))
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            FavoriteReciter.self,
            FavoriteTrack.self,
            DownloadedTrack.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(languageStore)
                .environment(downloadManager)
                .environment(networkMonitor)
        }
        .modelContainer(sharedModelContainer)
        // Lets the system relaunch the app to deliver finished downloads; the manager's session
        // (same identifier) receives the delegate callbacks.
        .backgroundTask(.urlSession(DownloadManager.sessionIdentifier)) { }
    }

    private static func configurePostHog() {
        guard let projectToken = Self.postHogConfigurationValue("POSTHOG_PROJECT_TOKEN") else {
            Self.reportMissingPostHogConfiguration("POSTHOG_PROJECT_TOKEN")
            return
        }

        guard let host = Self.postHogConfigurationValue("POSTHOG_HOST") else {
            Self.reportMissingPostHogConfiguration("POSTHOG_HOST")
            return
        }

        let config = PostHogConfig(projectToken: projectToken, host: host)
        config.errorTrackingConfig.autoCapture = true
        config.logs.serviceName = "ensat-ios"
        PostHogSDK.shared.setup(config)
    }

    private static func postHogConfigurationValue(_ variable: String) -> String? {
        let value = ProcessInfo.processInfo.environment[variable]
            ?? Bundle.main.object(forInfoDictionaryKey: variable) as? String
        guard let value, !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }

    private static func reportMissingPostHogConfiguration(_ variable: String) {
        #if DEBUG
        let message = "\(variable) variable required by PostHog is missing or un-configured, "
            + "this causes events to be silently missed. This error stops appearing once \(variable) is configured"
        fatalError(message)
        #endif
    }
}
