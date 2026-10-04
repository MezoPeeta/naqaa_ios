struct ReciterMoshafItem: Identifiable, Sendable, Equatable {
    let id: String  // "\(reciterId)-\(moshafId)"
    let reciter: Reciter
    let moshaf: Moshaf
}
