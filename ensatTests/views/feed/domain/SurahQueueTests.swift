import Testing
@testable import ensat

@MainActor
@Suite(.tags(.surahs, .playback))
struct SurahQueueTests {
    private let surahs = [1, 2, 3].map(TestFixtures.surah)

    @Test(arguments: [
        (from: 1, expected: 2 as Int?),
        (from: 2, expected: 3),
        (from: 3, expected: nil),
        (from: 99, expected: nil)
    ])
    func nextWalksForward(from: Int, expected: Int?) {
        let next = SurahQueue(surahs: surahs).next(after: TestFixtures.surah(from))
        #expect(next?.id == expected)
    }

    @Test(arguments: [
        (from: 3, expected: 2 as Int?),
        (from: 2, expected: 1),
        (from: 1, expected: nil),
        (from: 99, expected: nil)
    ])
    func previousWalksBack(from: Int, expected: Int?) {
        let previous = SurahQueue(surahs: surahs).previous(before: TestFixtures.surah(from))
        #expect(previous?.id == expected)
    }

    @Test func nothingIsCurrentWhenThereIsNoSelection() {
        let queue = SurahQueue(surahs: surahs)
        #expect(queue.next(after: nil) == nil)
        #expect(queue.previous(before: nil) == nil)
    }

    @Test func emptyQueue() {
        let queue = SurahQueue(surahs: [])
        #expect(queue.next(after: TestFixtures.surah(1)) == nil)
        #expect(queue.previous(before: TestFixtures.surah(1)) == nil)
    }
}
