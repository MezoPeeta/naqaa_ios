

import Foundation

struct ReciterResponse: Codable,Sendable,Equatable {
    let reciters: [Reciter]
}

struct Reciter: Codable,Sendable,Equatable {
    let id: Int
    let name, letter: String
    let moshaf: [Moshaf]
}

struct Moshaf: Codable,Sendable,Equatable {
    let id: Int
    let name: String
    let server: String
    
    
}

struct ReciterMoshafItem: Identifiable,Sendable,Equatable {
    let id: String          // "\(reciterId)-\(moshafId)"
    let reciter: Reciter
    let moshaf: Moshaf
}

extension ReciterResponse {
    var flatItems: [ReciterMoshafItem] {
        reciters.flatMap { reciter in
            reciter.moshaf.map { moshaf in
                ReciterMoshafItem(
                    id: "\(reciter.id)-\(moshaf.id)",
                    reciter: reciter,
                    moshaf: moshaf
                )
            }
        }
    }
}
