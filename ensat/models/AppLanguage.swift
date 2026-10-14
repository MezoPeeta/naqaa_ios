import Foundation

/// The user's in-app language choice: follow the device, or force one of the shipped languages.
enum AppLanguage: Hashable, Sendable {
    case system
    case code(String)

    /// Languages the app actually ships, detected from the bundle (no manual list to maintain).
    static var supported: [AppLanguage] {
        supportedCodes(from: Bundle.main.localizations).map(AppLanguage.code)
    }

    static func supportedCodes(from localizations: [String]) -> [String] {
        localizations.filter { $0 != "Base" }.sorted()
    }

    static var allChoices: [AppLanguage] { [.system] + supported }

    init(rawValue: String?) {
        switch rawValue {
        case nil, "system": self = .system
        case let code?: self = .code(code)
        }
    }

    var rawValue: String {
        switch self {
        case .system: "system"
        case .code(let code): code
        }
    }

    /// Each language is named in itself ("English", "العربية") so it is recognisable in any UI language.
    var nativeName: String? {
        guard case .code(let code) = self else { return nil }
        return Locale(identifier: code).localizedString(forLanguageCode: code)?.localizedCapitalized
    }
}
