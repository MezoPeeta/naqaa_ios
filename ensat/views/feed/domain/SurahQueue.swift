import Foundation

/// Pure next/previous navigation over an ordered list of surahs,
/// keyed by id so it works with copies of `Surah`.
struct SurahQueue {
    let surahs: [Surah]

    func next(after surah: Surah?) -> Surah? {
        guard let index = currentIndex(of: surah), index + 1 < surahs.count else { return nil }
        return surahs[index + 1]
    }

    func previous(before surah: Surah?) -> Surah? {
        guard let index = currentIndex(of: surah), index > 0 else { return nil }
        return surahs[index - 1]
    }

    private func currentIndex(of surah: Surah?) -> Int? {
        guard let surah else { return nil }
        return surahs.firstIndex { $0.id == surah.id }
    }
}

/// A surah paired with the reciter it should be played by.
struct QueueEntry: Equatable {
    let surah: Surah
    let reciter: ReciterMoshafItem
}

/// Next/previous navigation over an ordered list of (surah, reciter) entries.
/// Entries are matched on surah id + reciter id, so the same surah by two reciters is distinct.
struct EntryQueue {
    let entries: [QueueEntry]

    func next(after surah: Surah?, reciter: ReciterMoshafItem) -> QueueEntry? {
        guard let index = currentIndex(of: surah, reciter: reciter), index + 1 < entries.count else { return nil }
        return entries[index + 1]
    }

    func previous(before surah: Surah?, reciter: ReciterMoshafItem) -> QueueEntry? {
        guard let index = currentIndex(of: surah, reciter: reciter), index > 0 else { return nil }
        return entries[index - 1]
    }

    private func currentIndex(of surah: Surah?, reciter: ReciterMoshafItem) -> Int? {
        guard let surah else { return nil }
        return entries.firstIndex { $0.surah.id == surah.id && $0.reciter.id == reciter.id }
    }
}
