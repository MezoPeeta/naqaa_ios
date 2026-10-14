struct ReciterMoshafItem: Identifiable, Sendable, Equatable {
    let id: String  // "\(reciterId)-\(moshafId)"
    let reciter: Reciter
    let moshaf: Moshaf
}

extension ReciterMoshafItem {
    /// Rebuilds a playable item from a persisted snapshot (no network needed).
    static func make(
        reciterId: Int, reciterName: String,
        moshafId: Int, moshafName: String, server: String
    ) -> ReciterMoshafItem {
        let moshaf = Moshaf(id: moshafId, name: moshafName, server: server)
        return ReciterMoshafItem(
            id: "\(reciterId)-\(moshafId)",
            reciter: Reciter(id: reciterId, name: reciterName, letter: "", moshaf: [moshaf]),
            moshaf: moshaf
        )
    }
}
