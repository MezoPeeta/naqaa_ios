import Foundation

/// Disk cache for the raw reciter catalog response, one file per language.
nonisolated struct ReciterCatalogCache: Sendable {
    struct Entry: Sendable {
        let data: Data
        let isFresh: Bool
    }

    let directory: URL
    let maxAge: TimeInterval
    let now: @Sendable () -> Date

    init(
        directory: URL = .cachesDirectory,
        maxAge: TimeInterval = 7 * 24 * 60 * 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.directory = directory
        self.maxAge = maxAge
        self.now = now
    }

    func read(languageCode: String) -> Entry? {
        let url = fileURL(languageCode: languageCode)
        guard let data = try? Data(contentsOf: url),
              let modified = try? url.resourceValues(
                forKeys: [.contentModificationDateKey]
              ).contentModificationDate
        else { return nil }
        return Entry(data: data, isFresh: now().timeIntervalSince(modified) < maxAge)
    }

    func write(_ data: Data, languageCode: String) {
        try? data.write(to: fileURL(languageCode: languageCode), options: .atomic)
        // `Data.write` stamps the real clock; align it with the injected one.
        try? FileManager.default.setAttributes(
            [.modificationDate: now()],
            ofItemAtPath: fileURL(languageCode: languageCode).path
        )
    }

    func remove(languageCode: String) {
        try? FileManager.default.removeItem(at: fileURL(languageCode: languageCode))
    }

    private func fileURL(languageCode: String) -> URL {
        directory.appending(path: "reciters-\(languageCode).json")
    }
}
