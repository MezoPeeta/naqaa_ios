

import Foundation
import Observation


extension SurahListVIew{
    @Observable
    @MainActor
    class ViewModel{
        enum State: Equatable{
            case idle, loading, loaded([Surah]),error(String)
        }
        var state: State = .idle
        
        var query: String = ""
        
        var filteredSurahs: [Surah] {
            guard case .loaded(let surahs) = state else {
                return []
            }
            
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return surahs }
            
            return surahs.filter{ surah in
                surah.displayName.localizedStandardContains(trimmed)
                
                
            }
            
            
        }
        
        
        
        func loadLocal(){
            guard state == .idle else { return }
            
            state = .loading
            
            
            do {
                let url = Bundle.main.url(forResource: "surahs", withExtension: "json")
                guard let url else { throw APIError.fileNotFound("surahs.json") }
                
                let data = try Data(contentsOf: url)
                
                let response = try JSONDecoder().decode([Surah].self, from: data)
                
                state = .loaded(response)
                
            } catch {
                self.state = .error(error.localizedDescription)
            }
        }
        
        
        
        
    }
}


