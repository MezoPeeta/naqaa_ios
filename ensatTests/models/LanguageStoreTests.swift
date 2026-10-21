import Foundation
import Testing
@testable import ensat

@MainActor
final class LanguageStoreTests {
    private let suiteName = "LanguageStoreTests-\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func defaultsToSystem() {
        #expect(LanguageStore(defaults: defaults).language == .system)
    }

    @Test func applyPersistsAcrossInstances() {
        LanguageStore(defaults: defaults).apply(.code("ar"))
        #expect(LanguageStore(defaults: defaults).language == .code("ar"))
    }

    @Test func applySystemClearsAppleLanguages() {
        let store = LanguageStore(defaults: defaults)
        store.apply(.code("ar"))
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["ar"])

        store.apply(.system)

        #expect(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] == nil)
    }

    @Test func supportedCodesExcludeBase() {
        #expect(AppLanguage.supportedCodes(from: ["en", "Base", "ar"]) == ["ar", "en"])
    }

    @Test func needsRestartOnlyAfterChange() {
        let store = LanguageStore(defaults: defaults)
        #expect(store.needsRestart == false)
        store.apply(.code("ar"))
        #expect(store.needsRestart)
        store.apply(.system)
        #expect(store.needsRestart == false)
    }

    @Test func rawValueRoundTrip() {
        #expect(AppLanguage(rawValue: AppLanguage.code("ar").rawValue) == .code("ar"))
        #expect(AppLanguage(rawValue: AppLanguage.system.rawValue) == .system)
    }
}
