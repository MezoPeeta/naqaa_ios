import Foundation
import Observation

@MainActor
@Observable
final class ReciterViewModel {

        var query = ""

        var selected: ReciterMoshafItem = .defaultItem

        enum State: Equatable {
            case idle, loading
            case loaded([ReciterMoshafItem])
            case error(String)
        }

        var state: State = .idle

        func select(_ item: ReciterMoshafItem) {
            selected = item
        }

        func isSelected(id: ReciterMoshafItem.ID) -> Bool {
            selected.id == id
        }

        var filteredReciters: [ReciterMoshafItem] {
            filteredReciters(for: query)
        }

        func filteredReciters(for query: String) -> [ReciterMoshafItem] {
            guard case .loaded(let reciters) = state else { return [] }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return reciters }
            let queryKey = trimmed.searchKey()
            let exact = reciters.filter {
                $0.reciter.name.localizedStandardContains(trimmed)
            }
            let exactIds = Set(exact.map(\.id))
            let fuzzy = reciters.filter { item in
                !exactIds.contains(item.id) &&
                (item.reciter.name.searchKey().contains(queryKey) ||
                 item.moshaf.name.searchKey().contains(queryKey))
            }
            return exact + fuzzy
        }

        private let session: URLSession
        private let endpoint: URL
        private let cache: ReciterCatalogCache?

        // excludes old recitations
        private nonisolated static let excludedItemIDs: Set<ReciterMoshafItem.ID> = ["112-112"]

        init(
            session: URLSession = .shared,
            endpoint: URL? = nil,
            cache: ReciterCatalogCache? = ReciterCatalogCache()
        ) {
            self.session = session
            self.endpoint = endpoint ?? Self.defaultEndpoint
            self.cache = cache
        }

        private static var languageCode: String {
            Locale.current.language.languageCode?.identifier ?? "en"
        }

        private static var defaultEndpoint: URL {
            URL(
                string: "https://mp3quran.net/api/v3/reciters?language=\(languageCode)"
            )!
        }

        private nonisolated static func items(from data: Data) throws -> [ReciterMoshafItem] {
            try JSONDecoder()
                .decode(ReciterResponse.self, from: data)
                .flatItems
                .filter { !excludedItemIDs.contains($0.id) }
        }

        /// Reads and decodes the whole catalog off the main actor, so launch and the first tap on
        /// "Change reciter" never wait on disk or JSON.
        @concurrent
        private static func loadFromCache(
            _ cache: ReciterCatalogCache?, languageCode: String
        ) async -> (items: [ReciterMoshafItem], isFresh: Bool)? {
            guard let entry = cache?.read(languageCode: languageCode) else { return nil }
            guard let items = try? items(from: entry.data) else {
                cache?.remove(languageCode: languageCode)
                return nil
            }
            return (items, entry.isFresh)
        }

        @concurrent
        private static func decodeAndCache(
            _ data: Data, cache: ReciterCatalogCache?, languageCode: String
        ) async throws -> [ReciterMoshafItem] {
            let items = try items(from: data)
            cache?.write(data, languageCode: languageCode)
            return items
        }

        private func loadFromNetwork() async throws -> [ReciterMoshafItem] {
            let (data, response) = try await session.data(from: endpoint)

            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode)
            else {
                throw APIError.invalidRequest
            }

            return try await Self.decodeAndCache(data, cache: cache, languageCode: Self.languageCode)
        }

        func load() async {
            guard state == .idle else { return }
            state = .loading

            let cached = await Self.loadFromCache(cache, languageCode: Self.languageCode)
            if let cached, cached.isFresh {
                state = .loaded(cached.items)
                return
            }

            do {
                state = .loaded(try await loadFromNetwork())
            } catch {
                let isDecoding = error is DecodingError
                PostHogExportLogger.warn(
                    "Reciter catalog load failed",
                    attributes: ["failure_kind": isDecoding ? "decoding" : "network"]
                )
                if let cached {
                    state = .loaded(cached.items)
                } else if let error = error as? DecodingError {
                    state = .error(APIError.decoding(error).localizedDescription)
                } else {
                    state = .error(
                        APIError.networkError(error).localizedDescription
                    )
                }
            }
        }

}

extension ReciterMoshafItem {
    static var defaultItem: ReciterMoshafItem {
        ReciterMoshafItem(
            id: "1-1",
            reciter: Reciter(
                id: 1,
                name: ReciterViewModel.defaultReciterName,
                letter: "M",
                moshaf: [Moshaf(
                    id: 1,
                    name: ReciterViewModel.defaultMoshafName,
                    server: "https://server6.mp3quran.net/akdr/",

                )]
            ),
            moshaf: Moshaf(
                id: 1,
                name: ReciterViewModel.defaultMoshafName,
                server: "https://server6.mp3quran.net/akdr/",

            )

        )
    }

    var formattedMoshafName: String {
        var name = moshaf.name.replacingOccurrences(of: "A'n", with: "An")
        // Drops a leading "Rewayat " without compiling a regex for every row on every redraw.
        let leading = name.drop(while: \.isWhitespace)
        if leading.hasPrefix("Rewayat"), leading.dropFirst("Rewayat".count).first?.isWhitespace == true {
            name = String(leading.dropFirst("Rewayat".count))
        }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name.lowercased() {
        case "حفص":
            name = "حفص عن عاصم - مرتل"
        case "hafs":
            name = "Hafs An Assem - Murattel"
        default:
            break
        }

        let parts = name.components(separatedBy: " - ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        let deduped = parts.filter { seen.insert($0.lowercased()).inserted }
        guard let first = deduped.first else { return "" }
        let normalizedFirst: String
        if first.lowercased().contains("warsh") {
            normalizedFirst = "Warsh An Nafi'"
        } else if first.contains("ورش") {
            normalizedFirst = "ورش عن نافع"
        } else {
            normalizedFirst = first
        }
        let styleKeywords = [
            "مرتل", "مجود", "معلم", "مميزة",
            "murattal", "murattel", "mojawwad", "mo'lim", "mualim"
        ]
        let styles = deduped.dropFirst().filter { part in
            let lower = part.lowercased()
            return styleKeywords.contains { lower.contains($0) }
        }
        return ([normalizedFirst] + styles).joined(separator: " - ")
    }
}

extension ReciterViewModel {
    static var defaultReciterName: String {
        String(localized: "reciter.default.name")
    }

    static var defaultMoshafName: String {
        String(localized: "reciter.default.moshaf")
    }
}
