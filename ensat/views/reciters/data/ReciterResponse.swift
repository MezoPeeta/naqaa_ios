import Foundation

struct ReciterResponse: Codable, Sendable, Equatable {
    let reciters: [Reciter]
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
