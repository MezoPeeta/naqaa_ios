import Testing
@testable import ensat

struct StrokePathMapTests {
    private let width = 80
    private let height = 50

    private func bitmap(_ rects: [(columns: ClosedRange<Int>, rows: ClosedRange<Int>)]) -> AlphaBitmap {
        var alpha = [UInt8](repeating: 0, count: width * height)
        for rect in rects {
            for row in rect.rows {
                for column in rect.columns { alpha[row * width + column] = 255 }
            }
        }
        return AlphaBitmap(width: width, height: height, alpha: alpha)
    }

    private func order(_ map: [UInt8], column: Int, row: Int) -> UInt8 { map[row * width + column] }

    @Test func horizontalStrokeStartsAtTheRightEdge() {
        let map = StrokePathMap.orderMap(
            bitmap: bitmap([(columns: 10...70, rows: 20...27)]), startsOnRight: true
        )
        #expect(order(map, column: 68, row: 24) < order(map, column: 40, row: 24))
        #expect(order(map, column: 40, row: 24) < order(map, column: 12, row: 24))
    }

    @Test func startsOnTheLeftWhenAsked() {
        let map = StrokePathMap.orderMap(
            bitmap: bitmap([(columns: 10...70, rows: 20...27)]), startsOnRight: false
        )
        #expect(order(map, column: 12, row: 24) < order(map, column: 68, row: 24))
    }

    @Test func thickStrokeProgressesAlongItsCenterlineNotAcrossItsThickness() {
        let map = StrokePathMap.orderMap(
            bitmap: bitmap([(columns: 10...70, rows: 15...34)]), startsOnRight: true
        )
        // Same column, top and bottom of a thick stroke: nearly the same moment.
        let top = Int(order(map, column: 40, row: 16))
        let bottom = Int(order(map, column: 40, row: 33))
        #expect(abs(top - bottom) < 20)
    }

    @Test func tallIsolatedLetterIsDrawnTopToBottom() {
        let map = StrokePathMap.orderMap(
            bitmap: bitmap([(columns: 40...43, rows: 4...45)]), startsOnRight: true
        )
        #expect(order(map, column: 41, row: 8) < order(map, column: 41, row: 40))
    }

    @Test func dotIsWrittenAfterTheLetterNextToIt() {
        let map = StrokePathMap.orderMap(
            bitmap: bitmap([(columns: 10...70, rows: 20...27), (columns: 38...41, rows: 33...36)]), startsOnRight: true
        )
        #expect(order(map, column: 39, row: 34) > order(map, column: 39, row: 24))
    }

    @Test func penSlantDelaysLowerRows() {
        let slanted = StrokePathMap.orderMap(
            bitmap: bitmap([(columns: 10...70, rows: 4...45)]), startsOnRight: true, penSlant: 1
        )
        #expect(order(slanted, column: 40, row: 44) > order(slanted, column: 40, row: 6))
    }
}
