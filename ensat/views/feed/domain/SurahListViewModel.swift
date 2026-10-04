import Foundation
import Observation

@MainActor
@Observable
final class SurahListViewModel {
    enum State: Equatable {
        case idle, loading, loaded([Surah]), error(String)
    }
    var state: State = .idle

    var query: String = ""

    var selectedSurah: Surah?

    var filteredSurahs: [Surah] {
        filteredSurahs(for: query)
    }

    func filteredSurahs(for query: String) -> [Surah] {
        guard case .loaded(let surahs) = state else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return surahs }
        let queryKey = trimmed.searchKey()
        let exact = surahs.filter {
            $0.displayName.localizedStandardContains(trimmed)
        }
        let exactIds = Set(exact.map(\.id))
        let fuzzy = surahs.filter { item in
            !exactIds.contains(item.id) &&
            (item.displayName.searchKey().contains(queryKey))

        }
        return exact + fuzzy
    }

    func isSelected(id: Surah.ID) -> Bool {
        selectedSurah?.id == id
    }

    func loadLocal(bundle: Bundle = .main) {
        guard state == .idle else { return }

        state = .loading

        do {
            let url = bundle.url(forResource: "surahs", withExtension: "json")
            guard let url else { throw APIError.fileNotFound("surahs.json") }

            let data = try Data(contentsOf: url)

            let response = try JSONDecoder().decode([Surah].self, from: data)

            state = .loaded(response)

        } catch {
            self.state = .error(error.localizedDescription)
        }
    }
}
