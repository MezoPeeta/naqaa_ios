import Foundation

struct Reciter: Codable, Sendable, Equatable {
    let id: Int
    let name, letter: String
    let moshaf: [Moshaf]
}
