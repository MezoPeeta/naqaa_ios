import Foundation
import Observation

/// Holds and persists the in-app language choice. The choice is written to `AppleLanguages`, so iOS
/// applies it (strings, LTR/RTL, `Locale.current`, API language) the next time the app launches.
@Observable
@MainActor
final class LanguageStore {
    static let defaultsKey = "appLanguage"

    private(set) var language: AppLanguage
    /// The language the running process started with; differs from `language` once a restart is pending.
    private let launchLanguage: AppLanguage
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = AppLanguage(rawValue: defaults.string(forKey: Self.defaultsKey))
        self.language = saved
        self.launchLanguage = saved
    }

    var needsRestart: Bool { language != launchLanguage }

    func apply(_ newLanguage: AppLanguage) {
        language = newLanguage
        defaults.set(newLanguage.rawValue, forKey: Self.defaultsKey)
        switch newLanguage {
        case .system: defaults.removeObject(forKey: "AppleLanguages")
        case .code(let code): defaults.set([code], forKey: "AppleLanguages")
        }
    }
}
