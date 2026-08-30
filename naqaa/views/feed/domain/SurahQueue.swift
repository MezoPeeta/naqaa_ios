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
