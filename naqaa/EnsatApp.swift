//
//  naqaaApp.swift
//  naqaa
//
//  Created by Mazen on 16/05/2026.
//

import Foundation
import PostHog
import SwiftUI
import SwiftData
import UIKit

@main
struct NaqaaApp: App {

    init() {
        #if !DEBUG
        configurePostHog()
        #endif
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }

    private func configurePostHog() {
        guard let projectToken = postHogConfigurationValue("POSTHOG_PROJECT_TOKEN") else {
            reportMissingPostHogConfiguration("POSTHOG_PROJECT_TOKEN")
            return
        }

        guard let host = postHogConfigurationValue("POSTHOG_HOST") else {
            reportMissingPostHogConfiguration("POSTHOG_HOST")
            return
        }

        let config = PostHogConfig(projectToken: projectToken, host: host)
        config.errorTrackingConfig.autoCapture = true
        config.logs.serviceName = "naqaa-ios"
        PostHogSDK.shared.setup(config)
    }

    private func postHogConfigurationValue(_ variable: String) -> String? {
        let value = ProcessInfo.processInfo.environment[variable]
            ?? Bundle.main.object(forInfoDictionaryKey: variable) as? String
        guard let value, !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }

    private func reportMissingPostHogConfiguration(_ variable: String) {
        #if DEBUG
        let message = "\(variable) variable required by PostHog is missing or un-configured, "
            + "this causes events to be silently missed. This error stops appearing once \(variable) is configured"
        fatalError(message)
        #endif
    }
}
