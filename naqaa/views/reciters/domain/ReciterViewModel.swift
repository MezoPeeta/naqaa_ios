import Foundation
import Observation

extension ReciterContainer {
    @MainActor
    @Observable
    class ViewModel {
        
        
        
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

        private let endpoint: URL = {
            let code = Locale.current.language.languageCode?.identifier ?? "en"
            return URL(
                string: "https://mp3quran.net/api/v3/reciters?language=\(code)"
            )!
        }()
        
        func load() async {
            guard state == .idle else { return }
            state = .loading
            
            do {
                let (data, response) = try await URLSession.shared.data(
                    from: endpoint
                )
                
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode)
                else {
                    throw APIError.invalidRequest
                }
                
                let decoded = try JSONDecoder().decode(
                    ReciterResponse.self,
                    from: data
                )
                
                state = .loaded(decoded.flatItems)
            } catch let error as DecodingError {
                state = .error(APIError.decoding(error).localizedDescription)
            } catch {
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
            id: "7-1",
            reciter: Reciter(
                id: 7,
                name: ReciterContainer.ViewModel.defaultReciterName,
                letter: "M",
                moshaf: [Moshaf(
                    id: 1,
                    name: ReciterContainer.ViewModel.defaultMoshafName,
                    server: "https://server6.mp3quran.net/akdr/",
                
                )]
            ),
            moshaf: Moshaf(
                id: 1,
                name: ReciterContainer.ViewModel.defaultMoshafName,
                server: "https://server6.mp3quran.net/akdr/",
              
            )
           
        )
    }
}


extension ReciterContainer.ViewModel {
    static var defaultReciterName: String {
        String(localized: "reciter.default.name")
    }

    static var defaultMoshafName: String {
        String(localized: "reciter.default.moshaf")
    }
}
