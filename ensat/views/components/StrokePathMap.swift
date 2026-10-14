//
//  StrokePathMap.swift
//  ensat
//
//  Created by Mazen on 06/10/2026.
//

import SwiftUI

/// Builds an order map for a piece of text: a grayscale image, normalized to the text's own
/// bounds, where each ink pixel holds how far along the strokes it is. 0 is the first pixel,
/// at the extreme edge the text starts from, and 1 is the latest tip.
///
/// The order is the shortest distance travelled through ink from that starting edge, so it
/// follows the letters around curves instead of cutting straight across them.
enum StrokePathMap {
    private static let maxDimension = 320.0
    private static let inkThreshold: UInt8 = 40
    private static let dilationPasses = 4

    /// Rasterizes `text` with `font`, so the map follows the same glyph shapes as the real text.
    @MainActor
    static func makeImage(text: String, font: Font?, startsOnRight: Bool) async -> Image? {
        guard let bitmap = rasterize(text: text, font: font) else { return nil }
        let order = await Task.detached(priority: .userInitiated) {
            orderMap(bitmap: bitmap, startsOnRight: startsOnRight)
        }.value
        return grayImage(order, width: bitmap.width, height: bitmap.height)
    }

    // MARK: Rasterizing

    @MainActor
    private static func rasterize(text: String, font: Font?) -> AlphaBitmap? {
        let renderer = ImageRenderer(content: Text(text).font(font).foregroundStyle(.white))
        renderer.scale = 1
        guard let image = renderer.cgImage, image.width > 0, image.height > 0 else { return nil }

        let factor = min(1, maxDimension / Double(max(image.width, image.height)))
        let width = max(Int(Double(image.width) * factor), 1)
        let height = max(Int(Double(image.height) * factor), 1)

        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            // White text on black, so the gray value of each pixel is its ink coverage.
            let bounds = CGRect(x: 0, y: 0, width: width, height: height)
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(bounds)
            context.interpolationQuality = .high
            context.draw(image, in: bounds)
            return true
        }
        return drawn ? AlphaBitmap(width: width, height: height, alpha: pixels) : nil
    }

    private static func grayImage(_ pixels: [UInt8], width: Int, height: Int) -> Image? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              )
        else { return nil }
        return Image(decorative: image, scale: 1)
    }

    // MARK: Order map

    nonisolated private static func orderMap(bitmap: AlphaBitmap, startsOnRight: Bool) -> [UInt8] {
        let grid = InkGrid(
            ink: bitmap.alpha.map { $0 > inkThreshold },
            width: bitmap.width,
            height: bitmap.height
        )

        var cost = [Int32](repeating: .max, count: grid.ink.count)
        var heap = MinHeap()
        seedSources(grid, startsOnRight: startsOnRight, cost: &cost, heap: &heap)
        relax(grid, cost: &cost, heap: &heap)

        var order = normalized(cost: cost)
        dilate(&order, grid: grid)
        return order
    }

    /// Starts the path at the extreme edge of every connected piece of ink. Pieces away from
    /// the global starting edge, such as dots, start later in proportion to that distance.
    nonisolated private static func seedSources(
        _ grid: InkGrid,
        startsOnRight: Bool,
        cost: inout [Int32],
        heap: inout MinHeap
    ) {
        let labels = componentLabels(grid)

        var extremes: [Int: Int] = [:]
        for index in grid.ink.indices where labels[index] >= 0 {
            let column = index % grid.width
            let current = extremes[labels[index]] ?? column
            extremes[labels[index]] = startsOnRight ? max(current, column) : min(current, column)
        }
        guard let globalExtreme = startsOnRight ? extremes.values.max() : extremes.values.min() else {
            return
        }

        for index in grid.ink.indices where labels[index] >= 0 {
            guard let extreme = extremes[labels[index]], abs(index % grid.width - extreme) <= 1 else {
                continue
            }
            cost[index] = Int32(abs(extreme - globalExtreme)) * 10
            heap.push(cost: cost[index], index: Int32(index))
        }
    }

    /// Dijkstra over ink pixels.
    nonisolated private static func relax(_ grid: InkGrid, cost: inout [Int32], heap: inout MinHeap) {
        while let (current, rawIndex) = heap.pop() {
            let index = Int(rawIndex)
            guard current <= cost[index] else { continue }
            grid.forEachNeighbour(of: index) { next, step in
                guard grid.ink[next], current + step < cost[next] else { return }
                cost[next] = current + step
                heap.push(cost: cost[next], index: Int32(next))
            }
        }
    }

    nonisolated private static func normalized(cost: [Int32]) -> [UInt8] {
        let reached = cost.filter { $0 != .max }
        let longest = Double(max(reached.max() ?? 1, 1))
        return cost.map { $0 == .max ? 0 : UInt8(min(Double($0) / longest * 255, 255)) }
    }

    /// Spreads order values a few pixels past the ink, so smooth sampling at glyph edges does
    /// not blend in the empty background.
    nonisolated private static func dilate(_ order: inout [UInt8], grid: InkGrid) {
        var known = grid.ink
        for _ in 0..<dilationPasses {
            var nextOrder = order
            var nextKnown = known
            for index in known.indices where !known[index] {
                var source: Int?
                grid.forEachNeighbour(of: index) { neighbour, _ in
                    if source == nil, known[neighbour] { source = neighbour }
                }
                if let source {
                    nextOrder[index] = order[source]
                    nextKnown[index] = true
                }
            }
            order = nextOrder
            known = nextKnown
        }
    }

    /// Labels 8-connected pieces of ink, with -1 for background.
    nonisolated private static func componentLabels(_ grid: InkGrid) -> [Int] {
        var labels = [Int](repeating: -1, count: grid.ink.count)
        var nextLabel = 0
        for start in grid.ink.indices where grid.ink[start] && labels[start] < 0 {
            labels[start] = nextLabel
            var stack = [start]
            while let index = stack.popLast() {
                grid.forEachNeighbour(of: index) { next, _ in
                    guard grid.ink[next], labels[next] < 0 else { return }
                    labels[next] = nextLabel
                    stack.append(next)
                }
            }
            nextLabel += 1
        }
        return labels
    }
}

private nonisolated struct AlphaBitmap: Sendable {
    let width: Int
    let height: Int
    let alpha: [UInt8]
}

/// Which pixels are ink, with 8-connected neighbour stepping.
private nonisolated struct InkGrid {
    /// Offsets to the 8 neighbours with the cost of each step: 10 straight, 14 diagonal.
    private struct Step {
        let deltaX: Int
        let deltaY: Int
        let cost: Int32
        init(_ deltaX: Int, _ deltaY: Int, _ cost: Int32) {
            self.deltaX = deltaX
            self.deltaY = deltaY
            self.cost = cost
        }
    }

    private static let steps: [Step] = [
        Step(-1, 0, 10), Step(1, 0, 10), Step(0, -1, 10), Step(0, 1, 10),
        Step(-1, -1, 14), Step(1, -1, 14), Step(-1, 1, 14), Step(1, 1, 14)
    ]

    let ink: [Bool]
    let width: Int
    let height: Int

    /// Calls `body` with each in-bounds neighbour of `index` and the cost of stepping to it.
    func forEachNeighbour(of index: Int, _ body: (Int, Int32) -> Void) {
        let column = index % width
        let row = index / width
        for step in Self.steps {
            let nextColumn = column + step.deltaX
            let nextRow = row + step.deltaY
            guard nextColumn >= 0, nextColumn < width, nextRow >= 0, nextRow < height else { continue }
            body(nextRow * width + nextColumn, step.cost)
        }
    }
}

/// Minimal binary min-heap keyed by cost, for Dijkstra.
private nonisolated struct MinHeap {
    private var items: [(cost: Int32, index: Int32)] = []

    mutating func push(cost: Int32, index: Int32) {
        items.append((cost, index))
        var child = items.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard items[child].cost < items[parent].cost else { break }
            items.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> (Int32, Int32)? {
        guard let top = items.first else { return nil }
        let last = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            var parent = 0
            while true {
                let left = parent * 2 + 1
                let right = left + 1
                var smallest = parent
                if left < items.count, items[left].cost < items[smallest].cost { smallest = left }
                if right < items.count, items[right].cost < items[smallest].cost { smallest = right }
                if smallest == parent { break }
                items.swapAt(parent, smallest)
                parent = smallest
            }
        }
        return (top.cost, top.index)
    }
}
