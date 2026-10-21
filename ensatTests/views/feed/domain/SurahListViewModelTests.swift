import Foundation
import Testing
@testable import ensat

@MainActor
@Suite(.tags(.surahs))
struct SurahListViewModelTests {
    private let viewModel = SurahListViewModel()
    private let fatiha = Surah(id: 1, name: "الفاتحة", revelationPlace: .meccan, totalVerses: 7, transliteration: "Al-Fatiha")
    private let ikhlas = Surah(id: 112, name: "الإخلاص", revelationPlace: .meccan, totalVerses: 4, transliteration: "Al-Ikhlas")
    private let nas = Surah(id: 114, name: "الناس", revelationPlace: .meccan, totalVerses: 6, transliteration: "An-Nas")

    private final class BundleToken {}

    init() {
        viewModel.state = .loaded([fatiha, ikhlas, nas])
    }

    // MARK: - filteredSurahs(for:)
    // Queries are derived from `displayName`, so these pass in any simulator language.

    @Test func emptyQueryReturnsAllInOrder() {
        #expect(viewModel.filteredSurahs(for: "").map(\.id) == [1, 112, 114])
    }

    @Test func exactDisplayNameMatch() {
        #expect(viewModel.filteredSurahs(for: fatiha.displayName).map(\.id) == [1])
    }

    @Test func fuzzySearchKeyMatch() {
        // Drops the hamza (Arabic) or the dash (Latin), so only the search key still matches.
        let query = ikhlas.displayName
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "-", with: "")
        #expect(viewModel.filteredSurahs(for: query).map(\.id) == [112])
    }

    @Test func noMatchReturnsEmpty() {
        #expect(viewModel.filteredSurahs(for: "xyz-not-a-surah").isEmpty)
    }

    @Test func notLoadedReturnsEmpty() {
        #expect(SurahListViewModel().filteredSurahs(for: "").isEmpty)
    }

    @Test(.tags(.edgeCase), arguments: ["   ", "\n", " \t "])
    func whitespaceOnlyQueryReturnsEverySurah(query: String) {
        #expect(viewModel.filteredSurahs(for: query).map(\.id) == [1, 112, 114])
    }

    @Test(.tags(.edgeCase))
    func surroundingWhitespaceIsIgnored() {
        #expect(viewModel.filteredSurahs(for: "  \(fatiha.displayName)\n").map(\.id) == [1])
    }

    @Test(.tags(.edgeCase))
    func searchIsCaseInsensitive() {
        #expect(viewModel.filteredSurahs(for: ikhlas.displayName.uppercased()).map(\.id) == [112])
        #expect(viewModel.filteredSurahs(for: ikhlas.displayName.lowercased()).map(\.id) == [112])
    }

    // MARK: - loadLocal(bundle:)

    @Test(.tags(.edgeCase))
    func theBundledListIsTheWholeQuranInOrder() {
        let viewModel = SurahListViewModel()
        // Hosted tests run inside the app, so Bundle.main contains surahs.json.
        viewModel.loadLocal()
        guard case .loaded(let surahs) = viewModel.state else {
            Issue.record("expected loaded, got \(viewModel.state)")
            return
        }

        #expect(surahs.map(\.id) == Array(1...114))
        #expect(surahs.allSatisfy { $0.totalVerses > 0 })
        #expect(surahs.allSatisfy { $0.name.isEmpty == false && $0.transliteration.isEmpty == false })
        #expect(surahs.map(\.totalVerses).reduce(0, +) == 6236)
    }

    @Test func loadLocalMissingFileReportsError() {
        let viewModel = SurahListViewModel()

        // The test bundle has no surahs.json.
        viewModel.loadLocal(bundle: Bundle(for: BundleToken.self))

        guard case .error(let message) = viewModel.state else {
            Issue.record("expected error, got \(viewModel.state)")
            return
        }
        #expect(message.contains("surahs"))
    }

    @Test func loadingTwiceKeepsTheFirstResult() {
        let viewModel = SurahListViewModel()
        viewModel.loadLocal()
        guard case .loaded(let first) = viewModel.state else {
            Issue.record("expected loaded, got \(viewModel.state)")
            return
        }

        viewModel.loadLocal(bundle: Bundle(for: BundleToken.self))

        #expect(viewModel.state == .loaded(first), "a second load must not replace or error a loaded list")
    }
}
