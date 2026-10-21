import Foundation
import Testing
@testable import ensat

@Suite(.tags(.offline))
struct SurahAudioURLTests {
    @Test(arguments: [(1, "001.mp3"), (9, "009.mp3"), (10, "010.mp3"), (99, "099.mp3"), (114, "114.mp3")])
    func fileNamePadsToThreeDigits(surahId: Int, expected: String) {
        #expect(SurahAudioURL.fileName(surahId: surahId) == expected)
    }

    @Test(arguments: [
        "https://example.com/a/",
        "https://example.com/a"
    ])
    func remoteURLDoesNotNeedATrailingSlash(server: String) {
        #expect(SurahAudioURL.remote(surahId: 2, server: server)?.absoluteString == "https://example.com/a/002.mp3")
    }

    @Test(.tags(.edgeCase))
    func remoteURLForABlankServerHasNoHost() {
        let url = SurahAudioURL.remote(surahId: 2, server: "")
        #expect(url?.host() == nil, "a blank server must never look like a playable stream")
    }

    @Test func remoteURLTakesTheServerFromTheReciter() {
        let url = SurahAudioURL.remote(surah: TestFixtures.surah(7), reciter: TestFixtures.alafasy)
        #expect(url?.absoluteString == "https://example.com/a/007.mp3")
    }
}
