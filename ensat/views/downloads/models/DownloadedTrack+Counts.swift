extension DownloadedTrack {
    /// Downloaded surah counts per reciter+moshaf, keyed like `ReciterMoshafItem.id`.
    static func counts(in tracks: [DownloadedTrack]) -> [String: Int] {
        tracks.reduce(into: [:]) { counts, track in
            counts["\(track.reciterId)-\(track.moshafId)", default: 0] += 1
        }
    }
}
