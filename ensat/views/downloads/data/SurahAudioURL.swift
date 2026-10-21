import Foundation

nonisolated enum SurahAudioURL {
    static func fileName(surahId: Int) -> String {
        String(format: "%03d.mp3", surahId)
    }

    static func remote(surahId: Int, server: String) -> URL? {
        guard let serverURL = URL(string: server) else { return nil }
        return serverURL.appending(path: fileName(surahId: surahId))
    }

    static func remote(surah: Surah, reciter: ReciterMoshafItem) -> URL? {
        remote(surahId: surah.id, server: reciter.moshaf.server)
    }
}
