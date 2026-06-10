

import Foundation


struct Surah: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let revelationPlace: RevelationPlace
    let totalVerses: Int
    let transliteration: String
    
    enum CodingKeys: String, CodingKey{
        case id,name, transliteration
        case totalVerses = "total_verses"
        case revelationPlace = "type"
    }
    
    var displayName: String {
        Locale.current.language.languageCode == .arabic ? name : transliteration
    }
    
    
}

