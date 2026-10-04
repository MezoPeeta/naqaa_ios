//
//  FormattersTests.swift
//  naqaa
//
//  Created by Mazen on 30/08/2026.
//

import XCTest
@testable import naqaa

final class FormattersTests: XCTestCase {

    // MARK: - formattedMoshafName

    func testHafsArabicExpandsToFullName() {
        let item = ReciterMoshafItem.item(moshafName: "حفص")
        XCTAssertEqual(item.formattedMoshafName, "حفص عن عاصم - مرتل")
    }

    func testHafsEnglishExpandsToFullName() {
        let item = ReciterMoshafItem.item(moshafName: "Hafs")
        XCTAssertEqual(item.formattedMoshafName, "Hafs An Assem - Murattel")
    }

    func testWarshEnglishTrimsRewayatAndNormalizes() {
        let item = ReciterMoshafItem.item(moshafName: "Rewayat Warsh A'n Nafi' - Murattal")
        XCTAssertEqual(item.formattedMoshafName, "Warsh An Nafi' - Murattal")
    }

    func testWarshArabicStaysFull() {
        let item = ReciterMoshafItem.item(moshafName: "ورش عن نافع - مرتل")
        XCTAssertEqual(item.formattedMoshafName, "ورش عن نافع - مرتل")
    }

    func testRepeatedMoshafNameDedupes() {
        let item = ReciterMoshafItem.item(moshafName: "المصحف المجود - المصحف المجود")
        XCTAssertEqual(item.formattedMoshafName, "المصحف المجود")
    }

    func testRecordingMetadataIsTrimmed() {
        let item = ReciterMoshafItem.item(moshafName: "حفص عن عاصم - تسجيل عام 1387 هـ - 1967م")
        XCTAssertEqual(item.formattedMoshafName, "حفص عن عاصم")
    }

    func testKeepsKnownStyleSuffix() {
        let item = ReciterMoshafItem.item(moshafName: "Hafs - Murattal")
        XCTAssertEqual(item.formattedMoshafName, "Hafs - Murattal")
    }

    // MARK: - searchKey()

    func testSearchKeyEqualizesArabicVariants() {
        XCTAssertEqual(
            "ابراهيم الأخضر".searchKey(),
            "ابراهيم الاخضر".searchKey()
        )
    }

    func testSearchKeyDiscardsHamzaAbove() {
        XCTAssertEqual(
            "ألفاتحة".searchKey(),
            "الفاتحة".searchKey()
        )
    }

    func testSearchKeyDiffersArabicVsLatin() {
        XCTAssertNotEqual(
            "الفاتحة".searchKey(),
            "alfatiha".searchKey()
        )
    }

    func testSearchKeyStripsVowels() {
        XCTAssertEqual("Minshawi".searchKey(), "mnshw")
    }

    func testSearchKeyIgnoresSeparators() {
        XCTAssertEqual(
            "Al-Shatri".searchKey(),
            "Al Shatri".searchKey()
        )
    }

    func testSearchKeyFoldsTehAndYeh() {
        XCTAssertEqual(
            "سورة الإخلاص".searchKey(),
            "سورة الاخلاص".searchKey()
        )
    }

    // MARK: - ReciterNameParser.split

    func testSplitReciterNameOnePart() {
        let parts = ReciterNameParser.split("المنشاوي")
        XCTAssertEqual(parts.first, "المنشاوي")
        XCTAssertNil(parts.last)
    }

    func testSplitReciterNameTwoParts() {
        let parts = ReciterNameParser.split("محمد صديق")
        XCTAssertEqual(parts.first, "محمد")
        XCTAssertEqual(parts.last, "صديق")
    }

    func testSplitReciterNameThreePlusParts() {
        let parts = ReciterNameParser.split("محمد صديق المنشاوي")
        XCTAssertEqual(parts.first, "محمد صديق")
        XCTAssertEqual(parts.last, "المنشاوي")
    }

    func testSplitReciterNameHandlesAlDash() {
        let parts = ReciterNameParser.split("Abu Bakr Al-Shatri")
        XCTAssertEqual(parts.first, "Abu Bakr")
        XCTAssertEqual(parts.last, "AlShatri")
    }

    func testEmptyNameReturnsEmptyFirst() {
        let parts = ReciterNameParser.split("")
        XCTAssertEqual(parts.first, "")
        XCTAssertNil(parts.last)
    }
}

private extension ReciterMoshafItem {
    static func item(moshafName: String) -> ReciterMoshafItem {
        ReciterMoshafItem(
            id: "1-1",
            reciter: Reciter(id: 1, name: "x", letter: "x", moshaf: []),
            moshaf: Moshaf(id: 1, name: moshafName, server: "")
        )
    }
}
