import Foundation
import Testing
@testable import ensat

/// Each test answers on its own URL path, so suites can run in parallel.
@MainActor
@Suite(.tags(.reciters, .offline))
final class ReciterViewModelCacheTests {
    private let directory: URL
    private let path = "/reciters-\(UUID().uuidString)"
    private let day: TimeInterval = 24 * 60 * 60

    /// Counts requests that reach the (mocked) network.
    private final class Hits: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        var count: Int { lock.withLock { value } }
        func increment() { lock.withLock { value += 1 } }
    }
    private let hits = Hits()

    init() throws {
        directory = try TestFixtures.temporaryDirectory("reciter-cache")
    }

    deinit {
        RoutedURLProtocol.unregister(path: path)
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: Helpers

    private var languageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    private static func catalog(_ ids: [(reciter: Int, moshaf: Int)]) -> Data {
        let reciters = ids.map {
            """
            {"id": \($0.reciter), "name": "Reciter \($0.reciter)", "letter": "R",
             "moshaf": [{"id": \($0.moshaf), "name": "Moshaf \($0.moshaf)", "server": "https://example.com/"}]}
            """
        }
        return Data("{\"reciters\": [\(reciters.joined(separator: ","))]}".utf8)
    }

    /// Writes `data` into the cache as if it had been saved `age` seconds ago.
    private func seedCache(_ data: Data, age: TimeInterval = 0) {
        ReciterCatalogCache(directory: directory, now: { Date().addingTimeInterval(-age) })
            .write(data, languageCode: languageCode)
    }

    private func networkReturns(_ data: Data, status: Int = 200) {
        let hits = hits
        RoutedURLProtocol.register(path: path) { request in
            hits.increment()
            return (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, data)
        }
    }

    private func networkFails() {
        let hits = hits
        RoutedURLProtocol.register(path: path) { _ in
            hits.increment()
            throw URLError(.notConnectedToInternet)
        }
    }

    private func makeViewModel() -> ReciterViewModel {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RoutedURLProtocol.self]
        return ReciterViewModel(
            session: URLSession(configuration: configuration),
            endpoint: URL(string: "https://example.com\(path)")!,
            cache: ReciterCatalogCache(directory: directory)
        )
    }

    private func loadedIds(_ viewModel: ReciterViewModel) -> [String]? {
        guard case .loaded(let items) = viewModel.state else { return nil }
        return items.map(\.id)
    }

    // MARK: Fresh cache

    @Test func freshCacheIsUsedWithoutTouchingTheNetwork() async {
        seedCache(Self.catalog([(1, 1), (2, 1)]))
        networkReturns(Self.catalog([(9, 9)]))
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(loadedIds(viewModel) == ["1-1", "2-1"])
        #expect(hits.count == 0)
    }

    // MARK: Stale cache

    @Test func staleCacheIsRefreshedFromTheNetworkAndRewritten() async {
        seedCache(Self.catalog([(1, 1)]), age: 30 * day)
        networkReturns(Self.catalog([(2, 1)]))
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(loadedIds(viewModel) == ["2-1"])
        let cached = ReciterCatalogCache(directory: directory).read(languageCode: languageCode)
        #expect(cached?.isFresh == true)
    }

    @Test(.tags(.edgeCase))
    func staleCacheStillServesTheCatalogWhenOffline() async {
        seedCache(Self.catalog([(1, 1), (2, 1)]), age: 30 * day)
        networkFails()
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(loadedIds(viewModel) == ["1-1", "2-1"])
        #expect(hits.count == 1, "it tried the network once before falling back")
    }

    @Test(.tags(.edgeCase))
    func staleCacheStillServesTheCatalogWhenTheServerErrors() async {
        seedCache(Self.catalog([(1, 1)]), age: 30 * day)
        networkReturns(Data(), status: 503)
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(loadedIds(viewModel) == ["1-1"])
    }

    // MARK: No usable cache

    @Test(.tags(.edgeCase))
    func offlineWithoutACacheIsAnError() async {
        networkFails()
        let viewModel = makeViewModel()

        await viewModel.load()

        guard case .error = viewModel.state else {
            Issue.record("expected error, got \(viewModel.state)")
            return
        }
    }

    @Test(.tags(.edgeCase))
    func corruptCacheIsDiscardedAndTheNetworkIsUsed() async {
        seedCache(Data("not json".utf8))
        networkReturns(Self.catalog([(3, 1)]))
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(loadedIds(viewModel) == ["3-1"])
        #expect(hits.count == 1)
    }

    @Test(.tags(.edgeCase))
    func corruptCacheWhileOfflineIsAnError() async {
        seedCache(Data("not json".utf8))
        networkFails()
        let viewModel = makeViewModel()

        await viewModel.load()

        guard case .error = viewModel.state else {
            Issue.record("expected error, got \(viewModel.state)")
            return
        }
        #expect(ReciterCatalogCache(directory: directory).read(languageCode: languageCode) == nil)
    }

    // MARK: Behavior

    @Test(.tags(.edgeCase))
    func loadingTwiceDoesNotRefetch() async {
        networkReturns(Self.catalog([(1, 1)]))
        let viewModel = makeViewModel()

        await viewModel.load()
        await viewModel.load()

        #expect(hits.count == 1)
    }

    @Test func theRetiredRecitationIsFilteredOut() async {
        networkReturns(Self.catalog([(1, 1), (112, 112), (2, 1)]))
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(loadedIds(viewModel) == ["1-1", "2-1"])
    }

    @Test(.tags(.edgeCase))
    func theRetiredRecitationIsAlsoFilteredFromACachedCatalog() async {
        seedCache(Self.catalog([(112, 112), (1, 1)]))
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(loadedIds(viewModel) == ["1-1"])
    }

}
