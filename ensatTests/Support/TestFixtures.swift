import Foundation
@testable import ensat

enum TestFixtures {
    static func surah(_ id: Int) -> Surah {
        Surah(
            id: id,
            name: "سورة \(id)",
            revelationPlace: .meccan,
            totalVerses: 1,
            transliteration: "Surah \(id)"
        )
    }

    static func item(
        reciterId: Int = 1, moshafId: Int = 2,
        reciterName: String = "Alafasy", moshafName: String = "Murattal",
        server: String = "https://example.com/a/"
    ) -> ReciterMoshafItem {
        .make(
            reciterId: reciterId, reciterName: reciterName,
            moshafId: moshafId, moshafName: moshafName, server: server
        )
    }

    static let alafasy = item()
    static let other = item(
        reciterId: 9, moshafId: 1, reciterName: "Other", moshafName: "Hafs", server: "https://example.com/b/"
    )

    /// A fresh directory under the temp folder; the caller removes it.
    static func temporaryDirectory(_ prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "\(prefix)-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
