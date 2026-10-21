import Foundation
import Testing
@testable import ensat

@MainActor
@Suite(.tags(.reciters))
final class ReciterViewModelTests {
    private let path = "/reciters-\(UUID().uuidString)"

    deinit {
        RoutedURLProtocol.unregister(path: path)
    }

    private let qaloon = ReciterMoshafItem(
        id: "qaloon",
        reciter: Reciter(id: 1, name: "Qaloon Al-Mayyara", letter: "Q", moshaf: []),
        moshaf: Moshaf(id: 1, name: "قالون عن نافع - مرتل", server: "")
    )
    private let shatri = ReciterMoshafItem(
        id: "shatri",
        reciter: Reciter(id: 2, name: "Abu Bakr Al-Shatri", letter: "A", moshaf: []),
        moshaf: Moshaf(id: 2, name: "ورش عن نافع", server: "")
    )
    private let mishary = ReciterMoshafItem(
        id: "mishary",
        reciter: Reciter(id: 3, name: "Mishary Rashid Alafasy", letter: "M", moshaf: []),
        moshaf: Moshaf(id: 3, name: "المصحف المجود", server: "")
    )

    private func makeViewModel() -> ReciterViewModel {
        let viewModel = ReciterViewModel()
        viewModel.state = .loaded([qaloon, shatri, mishary])
        return viewModel
    }

    // MARK: - selection

    @Test func startsOnTheDefaultReciterAndSelectingMovesTheMarker() {
        let viewModel = ReciterViewModel()
        #expect(viewModel.isSelected(id: ReciterMoshafItem.defaultItem.id))

        viewModel.select(mishary)

        #expect(viewModel.isSelected(id: "mishary"))
        #expect(viewModel.isSelected(id: ReciterMoshafItem.defaultItem.id) == false)
    }

    // MARK: - filteredReciters(for:)

    @Test func emptyQueryReturnsAllInOrder() {
        #expect(makeViewModel().filteredReciters(for: "").map(\.id) == ["qaloon", "shatri", "mishary"])
    }

    @Test func exactReciterNameMatch() {
        #expect(makeViewModel().filteredReciters(for: "Qaloon").map(\.id) == ["qaloon"])
    }

    @Test func fuzzyReciterNameSearchKeyMatch() {
        // "Qaln" isn't a substring of "Qaloon Al-Mayyara", but its searchKey ("qln") matches the name's searchKey.
        #expect(makeViewModel().filteredReciters(for: "Qaln").map(\.id) == ["qaloon"])
    }

    @Test func fuzzyMoshafNameMatch() {
        #expect(makeViewModel().filteredReciters(for: "المجود").map(\.id) == ["mishary"])
    }

    @Test func exactMatchesComeBeforeFuzzy() {
        let viewModel = ReciterViewModel()
        let exact = ReciterMoshafItem(
            id: "murattal-exact",
            reciter: Reciter(id: 10, name: "Hani Murattal", letter: "H", moshaf: []),
            moshaf: Moshaf(id: 10, name: "Quran Juz", server: "")
        )
        let fuzzy = ReciterMoshafItem(
            id: "murattal-fuzzy",
            reciter: Reciter(id: 11, name: "Tariq Rashid", letter: "T", moshaf: []),
            moshaf: Moshaf(id: 11, name: "Quran Murattal", server: "")
        )
        viewModel.state = .loaded([fuzzy, exact])

        // "Murattal" matches `exact` via its reciter name, and `fuzzy` only via the searchKey of its moshaf name.
        #expect(viewModel.filteredReciters(for: "Murattal").map(\.id) == ["murattal-exact", "murattal-fuzzy"])
    }

    @Test func noMatchReturnsEmpty() {
        #expect(makeViewModel().filteredReciters(for: "xyz-not-a-reciter").isEmpty)
    }

    @Test func notLoadedReturnsEmpty() {
        #expect(ReciterViewModel().filteredReciters(for: "").isEmpty)
    }

    @Test(.tags(.edgeCase), arguments: ["   ", "\n", "\t  \n"])
    func whitespaceOnlyQueryReturnsEveryReciter(query: String) {
        #expect(makeViewModel().filteredReciters(for: query).count == 3)
    }

    @Test(.tags(.edgeCase))
    func surroundingWhitespaceAndCaseAreIgnored() {
        #expect(makeViewModel().filteredReciters(for: "  QALOON \n").map(\.id) == ["qaloon"])
    }

    // MARK: - load() with a mocked URLSession

    private func networkingViewModel() -> ReciterViewModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RoutedURLProtocol.self]
        return ReciterViewModel(
            session: URLSession(configuration: config),
            endpoint: URL(string: "https://example.com\(path)")!,
            cache: nil
        )
    }

    private static let validResponseData = Data(
        """
        {
          "reciters": [
            {
              "id": 7,
              "name": "Test Reciter",
              "letter": "T",
              "moshaf": [
                { "id": 1, "name": "Hafs", "server": "https://example.com/" },
                { "id": 2, "name": "Warsh", "server": "https://example.com/" }
              ]
            }
          ]
        }
        """.utf8
    )

    @Test func loadSucceedsAndFlattensItems() async {
        RoutedURLProtocol.respond(path: path, data: Self.validResponseData)
        let viewModel = networkingViewModel()

        await viewModel.load()

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("expected loaded, got \(viewModel.state)")
            return
        }
        #expect(items.map(\.id) == ["7-1", "7-2"])
        #expect(items.map(\.reciter.name) == ["Test Reciter", "Test Reciter"])
    }

    @Test(arguments: [
        (status: 400, body: Data()),
        (status: 200, body: Data("not json".utf8))
    ])
    func loadFailureSetsAnError(status: Int, body: Data) async {
        RoutedURLProtocol.respond(path: path, status: status, data: body)
        let viewModel = networkingViewModel()

        await viewModel.load()

        guard case .error = viewModel.state else {
            Issue.record("expected error, got \(viewModel.state)")
            return
        }
    }
}
