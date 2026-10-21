import Testing
@testable import ensat

@MainActor
@Suite(.tags(.playback, .edgeCase))
struct EntryQueueTests {
    private let alafasy = TestFixtures.alafasy
    private let other = TestFixtures.other

    private func entry(_ id: Int, _ reciter: ReciterMoshafItem) -> QueueEntry {
        QueueEntry(surah: TestFixtures.surah(id), reciter: reciter)
    }

    private var queue: EntryQueue {
        EntryQueue(entries: [entry(5, alafasy), entry(2, other), entry(9, alafasy)])
    }

    @Test(arguments: [(5, 2), (2, 9)])
    func nextWalksForward(from: Int, to: Int) throws {
        let reciter = from == 2 ? other : alafasy
        let next = try #require(queue.next(after: TestFixtures.surah(from), reciter: reciter))
        #expect(next.surah.id == to)
    }

    @Test(arguments: [(2, 5), (9, 2)])
    func previousWalksBack(from: Int, to: Int) throws {
        let reciter = from == 2 ? other : alafasy
        let previous = try #require(queue.previous(before: TestFixtures.surah(from), reciter: reciter))
        #expect(previous.surah.id == to)
    }

    @Test func noNextAfterLastAndNoPreviousBeforeFirst() {
        #expect(queue.next(after: TestFixtures.surah(9), reciter: alafasy) == nil)
        #expect(queue.previous(before: TestFixtures.surah(5), reciter: alafasy) == nil)
    }

    @Test func nilSurahHasNoNeighbours() {
        #expect(queue.next(after: nil, reciter: alafasy) == nil)
        #expect(queue.previous(before: nil, reciter: alafasy) == nil)
    }

    @Test func sameSurahByAnotherReciterIsADifferentEntry() throws {
        let queue = EntryQueue(entries: [entry(5, alafasy), entry(5, other), entry(6, alafasy)])

        let afterFirst = try #require(queue.next(after: TestFixtures.surah(5), reciter: alafasy))
        #expect(afterFirst.reciter.id == other.id)

        let afterSecond = try #require(queue.next(after: TestFixtures.surah(5), reciter: other))
        #expect(afterSecond.surah.id == 6)
    }

    @Test func currentEntryMissingFromQueueHasNoNeighbours() {
        #expect(queue.next(after: TestFixtures.surah(2), reciter: alafasy) == nil, "surah 2 is queued under another reciter")
        #expect(queue.previous(before: TestFixtures.surah(77), reciter: alafasy) == nil)
    }

    @Test func emptyQueueHasNoNeighbours() {
        let empty = EntryQueue(entries: [])
        #expect(empty.next(after: TestFixtures.surah(1), reciter: alafasy) == nil)
        #expect(empty.previous(before: TestFixtures.surah(1), reciter: alafasy) == nil)
    }

    @Test func singleEntryQueueHasNoNeighbours() {
        let single = EntryQueue(entries: [entry(1, alafasy)])
        #expect(single.next(after: TestFixtures.surah(1), reciter: alafasy) == nil)
        #expect(single.previous(before: TestFixtures.surah(1), reciter: alafasy) == nil)
    }
}
