//
//  ReciterViewModelTests.swift
//  naqaa
//
//  Created by Mazen on 30/08/2026.
//

import XCTest
@testable import naqaa

@MainActor
final class ReciterViewModelTests: XCTestCase {

    // MARK: - filteredReciters(for:)

    func testEmptyQueryReturnsAllInOrder() {
        let viewModel = makeViewModel()
        let result = viewModel.filteredReciters(for: "")

        XCTAssertEqual(result.map(\.id), ["qaloon", "shatri", "mishary"])
    }

    func testExactReciterNameMatch() {
        let viewModel = makeViewModel()
        let result = viewModel.filteredReciters(for: "Qaloon")

        XCTAssertEqual(result.map(\.id), ["qaloon"])
    }

    func testFuzzyReciterNameSearchKeyMatch() {
        let viewModel = makeViewModel()
        // "Qaln" isn't a substring of "Qaloon Al-Mayyara", but its
        // searchKey ("qln") matches the name's searchKey.
        let result = viewModel.filteredReciters(for: "Qaln")

        XCTAssertEqual(result.map(\.id), ["qaloon"])
    }

    func testFuzzyMoshafNameMatch() {
        let viewModel = makeViewModel()
        let result = viewModel.filteredReciters(for: "المجود")

        XCTAssertEqual(result.map(\.id), ["mishary"])
    }

    func testExactMatchesComeBeforeFuzzy() {
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

        // "Murattal" matches `exact` via its reciter name (exact),
        // and `fuzzy` via searchKey of its moshaf name.
        let result = viewModel.filteredReciters(for: "Murattal")

        XCTAssertEqual(result.map(\.id), ["murattal-exact", "murattal-fuzzy"])
    }

    func testNoMatchReturnsEmpty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.filteredReciters(for: "xyz-not-a-reciter").isEmpty)
    }

    func testNotLoadedReturnsEmpty() {
        let viewModel = ReciterViewModel()
        XCTAssertTrue(viewModel.filteredReciters(for: "").isEmpty)
    }

    // MARK: - load() with a mocked URLSession

    func testLoadSucceedsAndFlattensItems() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Self.validResponseData)
        }

        let viewModel = makeNetworkingViewModel()
        await viewModel.load()

        guard case .loaded(let items) = viewModel.state else {
            return XCTFail("expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(items.map(\.id), ["7-1", "7-2"])
        XCTAssertEqual(items.map(\.reciter.name), ["Test Reciter", "Test Reciter"])
    }

    func testLoadNon2xxStatusSetsInvalidRequestError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil
            )!
            return (response, Data())
        }

        let viewModel = makeNetworkingViewModel()
        await viewModel.load()

        guard case .error = viewModel.state else {
            return XCTFail("expected error, got \(viewModel.state)")
        }
    }

    func testLoadInvalidJSONSetsDecodingError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data("not json".utf8))
        }

        let viewModel = makeNetworkingViewModel()
        await viewModel.load()

        guard case .error = viewModel.state else {
            return XCTFail("expected error, got \(viewModel.state)")
        }
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeViewModel() -> ReciterViewModel {
        let viewModel = ReciterViewModel()
        viewModel.state = .loaded(ReciterMoshafItem.Fixture.all)
        return viewModel
    }
}

private extension ReciterMoshafItem {
    enum Fixture {
        static let qaloon = ReciterMoshafItem(
            id: "qaloon",
            reciter: Reciter(id: 1, name: "Qaloon Al-Mayyara", letter: "Q", moshaf: []),
            moshaf: Moshaf(id: 1, name: "قالون عن نافع - مرتل", server: "")
        )
        static let shatri = ReciterMoshafItem(
            id: "shatri",
            reciter: Reciter(id: 2, name: "Abu Bakr Al-Shatri", letter: "A", moshaf: []),
            moshaf: Moshaf(id: 2, name: "ورش عن نافع", server: "")
        )
        static let mishary = ReciterMoshafItem(
            id: "mishary",
            reciter: Reciter(id: 3, name: "Mishary Rashid Alafasy", letter: "M", moshaf: []),
            moshaf: Moshaf(id: 3, name: "المصحف المجود", server: "")
        )
        static var all: [ReciterMoshafItem] { [qaloon, shatri, mishary] }
    }
}

private extension ReciterViewModelTests {
    func makeNetworkingViewModel() -> ReciterViewModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return ReciterViewModel(
            session: session,
            endpoint: URL(string: "https://example.com/reciters")!
        )
    }

    static let validResponseData = Data(
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
}

class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler:
        ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("MockURLProtocol.requestHandler not set")
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
