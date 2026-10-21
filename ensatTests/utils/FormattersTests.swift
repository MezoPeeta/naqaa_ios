import Testing
@testable import ensat

@MainActor
struct FormattersTests {

    // MARK: - formattedMoshafName

    @Test(arguments: [
        (raw: "حفص", expected: "حفص عن عاصم - مرتل"),
        (raw: "Hafs", expected: "Hafs An Assem - Murattel"),
        (raw: "Rewayat Warsh A'n Nafi' - Murattal", expected: "Warsh An Nafi' - Murattal"),
        (raw: "ورش عن نافع - مرتل", expected: "ورش عن نافع - مرتل"),
        (raw: "المصحف المجود - المصحف المجود", expected: "المصحف المجود"),
        (raw: "حفص عن عاصم - تسجيل عام 1387 هـ - 1967م", expected: "حفص عن عاصم"),
        (raw: "Hafs - Murattal", expected: "Hafs - Murattal")
    ])
    func moshafNameIsNormalized(raw: String, expected: String) {
        let item = ReciterMoshafItem(
            id: "1-1",
            reciter: Reciter(id: 1, name: "x", letter: "x", moshaf: []),
            moshaf: Moshaf(id: 1, name: raw, server: "")
        )
        #expect(item.formattedMoshafName == expected)
    }

    // MARK: - searchKey()

    @Test(arguments: [
        (a: "ابراهيم الأخضر", b: "ابراهيم الاخضر"),
        (a: "ألفاتحة", b: "الفاتحة"),
        (a: "Al-Shatri", b: "Al Shatri"),
        (a: "سورة الإخلاص", b: "سورة الاخلاص")
    ])
    func searchKeyTreatsVariantsAsEqual(a: String, b: String) {
        #expect(a.searchKey() == b.searchKey())
    }

    @Test func searchKeyDiffersArabicVsLatin() {
        #expect("الفاتحة".searchKey() != "alfatiha".searchKey())
    }

    @Test func searchKeyStripsVowels() {
        #expect("Minshawi".searchKey() == "mnshw")
    }

    // MARK: - ReciterNameParser.split

    @Test(arguments: [
        (name: "المنشاوي", first: "المنشاوي", last: String?.none),
        (name: "محمد صديق", first: "محمد", last: "صديق"),
        (name: "محمد صديق المنشاوي", first: "محمد صديق", last: "المنشاوي"),
        (name: "Abu Bakr Al-Shatri", first: "Abu Bakr", last: "AlShatri"),
        (name: "", first: "", last: String?.none)
    ])
    func splitReciterName(name: String, first: String, last: String?) {
        let parts = ReciterNameParser.split(name)
        #expect(parts.first == first)
        #expect(parts.last == last)
    }
}
