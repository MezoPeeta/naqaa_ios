//
//  SurahListViewModelTests.swift
//  naqaa
//
//  Created by Mazen on 30/08/2026.
//

import XCTest
@testable import naqaa

@MainActor
final class SurahListViewModelTests: XCTestCase {

    private var isArabicLocale: Bool {
        Locale.current.language.languageCode == .arabic
    }

    // MARK: - filteredSurahs(for:)

    func testEmptyQueryReturnsAllInOrder() {
        let viewModel = makeViewModel()
        let result = viewModel.filteredSurahs(for: "")

        XCTAssertEqual(result.map(\.id), [1, 112, 114])
    }

    func testExactDisplayNameMatch() {
        let viewModel = makeViewModel()
        let fatiha = Surah.Fixture.fatiha
        let query = isArabicLocale ? fatiha.name : fatiha.transliteration

        let result = viewModel.filteredSurahs(for: query)

        XCTAssertEqual(result.map(\.id), [1])
    }

    func testFuzzySearchKeyMatch() {
        let viewModel = makeViewModel()
        let query = isArabicLocale ? "الاخلاص" : "AlIkhlas"

        let result = viewModel.filteredSurahs(for: query)

        XCTAssertEqual(result.map(\.id), [112])
    }

    func testNoMatchReturnsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.filteredSurahs(for: "xyz-not-a-surah").isEmpty)
    }

    func testNotLoadedReturnsEmpty() {
        let viewModel = SurahListViewModel()
        XCTAssertTrue(viewModel.filteredSurahs(for: "").isEmpty)
    }

    // MARK: - loadLocal(bundle:)

    func testLoadLocalSucceedsFromAppBundle() {
        let viewModel = SurahListViewModel()

        // Hosted tests run inside the app, so Bundle.main contains surahs.json.
        viewModel.loadLocal()

        guard case .loaded(let surahs) = viewModel.state else {
            return XCTFail("expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(surahs.count, 114)
        XCTAssertEqual(surahs.first?.id, 1)
        XCTAssertEqual(surahs.last?.id, 114)
    }

    func testLoadLocalMissingFileReportsError() {
        let viewModel = SurahListViewModel()
        let testBundle = Bundle(for: SurahListViewModelTests.self)

        // The test bundle has no surahs.json.
        viewModel.loadLocal(bundle: testBundle)

        guard case .error(let message) = viewModel.state else {
            return XCTFail("expected error, got \(viewModel.state)")
        }
        XCTAssertTrue(message.contains("surahs"))
    }

    // MARK: - Helpers

    private func makeViewModel() -> SurahListViewModel {
        let viewModel = SurahListViewModel()
        viewModel.state = .loaded(Surah.Fixture.all)
        return viewModel
    }
}

private extension Surah {
    enum Fixture {
        static let fatiha = Surah(
            id: 1,
            name: "الفاتحة",
            revelationPlace: .meccan,
            totalVerses: 7,
            transliteration: "Al-Fatiha"
        )
        static let ikhlas = Surah(
            id: 112,
            name: "الإخلاص",
            revelationPlace: .meccan,
            totalVerses: 4,
            transliteration: "Al-Ikhlas"
        )
        static let nas = Surah(
            id: 114,
            name: "الناس",
            revelationPlace: .meccan,
            totalVerses: 6,
            transliteration: "An-Nas"
        )
        static var all: [Surah] { [fatiha, ikhlas, nas] }
    }
}
