import XCTest
@testable import ensat

@MainActor
final class LanguageStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let name = "LanguageStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testDefaultsToSystem() {
        XCTAssertEqual(LanguageStore(defaults: makeDefaults()).language, .system)
    }

    func testApplyPersistsAcrossInstances() {
        let defaults = makeDefaults()
        LanguageStore(defaults: defaults).apply(.code("ar"))
        XCTAssertEqual(LanguageStore(defaults: defaults).language, .code("ar"))
    }

    func testApplySystemClearsAppleLanguages() {
        let defaults = makeDefaults()
        let store = LanguageStore(defaults: defaults)
        store.apply(.code("ar"))
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["ar"])
        store.apply(.system)
        XCTAssertNil(defaults.object(forKey: "AppleLanguages"))
    }

    func testSupportedCodesExcludeBase() {
        XCTAssertEqual(AppLanguage.supportedCodes(from: ["en", "Base", "ar"]), ["ar", "en"])
    }

    func testNeedsRestartOnlyAfterChange() {
        let store = LanguageStore(defaults: makeDefaults())
        XCTAssertFalse(store.needsRestart)
        store.apply(.code("ar"))
        XCTAssertTrue(store.needsRestart)
        store.apply(.system)
        XCTAssertFalse(store.needsRestart)
    }

    func testRawValueRoundTrip() {
        XCTAssertEqual(AppLanguage(rawValue: AppLanguage.code("ar").rawValue), .code("ar"))
        XCTAssertEqual(AppLanguage(rawValue: AppLanguage.system.rawValue), .system)
    }
}
