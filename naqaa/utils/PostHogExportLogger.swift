import PostHog

enum PostHogExportLogger {
    static func info(_ message: String, attributes: [String: Any] = [:]) {
        PostHogSDK.shared.logger?.info(message, attributes: attributes)
    }

    static func warn(_ message: String, attributes: [String: Any] = [:]) {
        PostHogSDK.shared.logger?.warn(message, attributes: attributes)
    }
}
