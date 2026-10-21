//
//  StrokeSkeleton.swift
//  ensat
//
//  Created by Mazen on 06/10/2026.
//

import SwiftUI

/// Ink, its centerline and its connected pieces, shared by the steps that order the strokes.
nonisolated struct Strokes {
    let grid: InkGrid
    let skeleton: [Bool]
    let labels: [Int32]
}

/// Steps of `StrokePathMap.orderMap` that work on the skeleton of the ink.
extension StrokePathMap {
    /// One piece of connected ink.
    nonisolated struct Piece {
        let label: Int
        let area: Int
        let minX: Int, maxX: Int, minY: Int, maxY: Int
        var width: Int { maxX - minX + 1 }
        var height: Int { maxY - minY + 1 }
        var isMark = false
    }

    nonisolated static func componentInfo(_ grid: InkGrid, labels: [Int32]) -> [Piece] {
        var boxes: [Int: Piece] = [:]
        for index in grid.ink.indices where labels[index] >= 0 {
            let column = index % grid.width
            let row = index / grid.width
            let label = Int(labels[index])
            if let old = boxes[label] {
                boxes[label] = Piece(
                    label: old.label, area: old.area + 1,
                    minX: min(old.minX, column), maxX: max(old.maxX, column),
                    minY: min(old.minY, row), maxY: max(old.maxY, row)
                )
            } else {
                boxes[label] = Piece(
                    label: label, area: 1, minX: column, maxX: column, minY: row, maxY: row
                )
            }
        }
        let totalArea = boxes.values.reduce(0) { $0 + $1.area }
        return boxes.values.sorted { $0.label < $1.label }.map { piece in
            var piece = piece
            let longSide = Double(max(piece.width, piece.height))
            let shortSide = Double(max(min(piece.width, piece.height), 1))
            // A dot or mark is small and compact; a thin tall letter such as alif is not.
            piece.isMark = Double(piece.area) < 0.03 * Double(totalArea) && longSide / shortSide < 2.5
            return piece
        }
    }

    /// Zhang-Suen thinning: peels ink down to a one pixel wide centerline that keeps its shape
    /// and connectivity.
    nonisolated static func thinned(_ grid: InkGrid) -> [Bool] {
        let width = grid.width + 2
        let height = grid.height + 2
        var image = [Bool](repeating: false, count: width * height)
        for index in grid.ink.indices where grid.ink[index] {
            image[(index / grid.width + 1) * width + index % grid.width + 1] = true
        }

        var changed = true
        while changed {
            changed = false
            for step in 0..<2 {
                var removable: [Int] = []
                for row in 1..<(height - 1) {
                    for column in 1..<(width - 1) {
                        let index = row * width + column
                        guard image[index], canRemove(image, index: index, width: width, firstStep: step == 0)
                        else { continue }
                        removable.append(index)
                    }
                }
                changed = changed || !removable.isEmpty
                for index in removable { image[index] = false }
            }
        }

        var result = [Bool](repeating: false, count: grid.ink.count)
        for index in result.indices {
            result[index] = image[(index / grid.width + 1) * width + index % grid.width + 1]
        }
        return result
    }

    nonisolated static func canRemove(_ image: [Bool], index: Int, width: Int, firstStep: Bool) -> Bool {
        // Neighbours clockwise from the north, as 0 or 1.
        let ring = [
            image[index - width], image[index - width + 1], image[index + 1], image[index + width + 1],
            image[index + width], image[index + width - 1], image[index - 1], image[index - width - 1]
        ].map { $0 ? 1 : 0 }
        let neighbours = ring.reduce(0, +)
        guard (2...6).contains(neighbours) else { return false }

        var transitions = 0
        for position in 0..<8 where ring[position] == 0 && ring[(position + 1) % 8] == 1 { transitions += 1 }
        guard transitions == 1 else { return false }

        let (north, east, south, west) = (ring[0], ring[2], ring[4], ring[6])
        return firstStep
            ? north * east * south == 0 && east * south * west == 0
            : north * east * west == 0 && north * south * west == 0
    }

    /// Starts each letter at one point of its skeleton: the extreme edge, or the top for tall
    /// thin pieces such as alif, which a pen pulls downward. Pieces away from the global starting
    /// edge start later in proportion to that distance.
    nonisolated static func seedStarts(
        _ letters: [Piece],
        in strokes: Strokes,
        startsOnRight: Bool,
        cost: inout [Int32],
        heap: inout MinHeap
    ) {
        let (grid, skeleton, labels) = (strokes.grid, strokes.skeleton, strokes.labels)
        func extreme(_ piece: Piece) -> Int { startsOnRight ? piece.maxX : piece.minX }
        guard let globalExtreme = startsOnRight ? letters.map(extreme).max() : letters.map(extreme).min()
        else { return }

        for piece in letters {
            let isTall = Double(piece.height) > 1.5 * Double(piece.width)
            var best: Int?
            var bestKey = (Int.max, Int.max)
            for index in skeleton.indices where skeleton[index] && Int(labels[index]) == piece.label {
                let column = index % grid.width
                let row = index / grid.width
                let sideKey = startsOnRight ? -column : column
                let key = isTall ? (row, sideKey) : (sideKey, row)
                if key < bestKey {
                    bestKey = key
                    best = index
                }
            }
            guard let start = best else { continue }
            cost[start] = Int32(abs(extreme(piece) - globalExtreme)) * 10
            heap.push(cost: cost[start], index: Int32(start))
        }
    }

    /// Dijkstra over the pixels in `mask`.
    nonisolated static func relax(_ grid: InkGrid, mask: [Bool], cost: inout [Int32], heap: inout MinHeap) {
        while let (current, rawIndex) = heap.pop() {
            let index = Int(rawIndex)
            guard current <= cost[index] else { continue }
            grid.forEachNeighbour(of: index) { next, step in
                guard mask[next], current + step < cost[next] else { return }
                cost[next] = current + step
                heap.push(cost: cost[next], index: Int32(next))
            }
        }
    }

    /// Dots and marks are written after the letter next to them: they take the order of the
    /// nearest letter pixel, plus a short delay.
    nonisolated static func placeMarks(_ marks: [Piece], in strokes: Strokes, cost: inout [Int32]) {
        let (grid, skeleton, labels) = (strokes.grid, strokes.skeleton, strokes.labels)
        guard !marks.isEmpty else { return }
        let reached = skeleton.indices.filter { skeleton[$0] && cost[$0] != .max }
        guard let longest = reached.map({ cost[$0] }).max() else { return }
        let delay = Int32(Double(longest) * 0.06)

        for mark in marks {
            let centerX = (mark.minX + mark.maxX) / 2
            let centerY = (mark.minY + mark.maxY) / 2
            let nearest = reached.min { first, second in
                func distance(_ index: Int) -> Int {
                    let deltaX = index % grid.width - centerX
                    let deltaY = index / grid.width - centerY
                    return deltaX * deltaX + deltaY * deltaY
                }
                return distance(first) < distance(second)
            }
            guard let nearest else { continue }
            let markCost = cost[nearest] + delay
            for index in skeleton.indices where skeleton[index] && Int(labels[index]) == mark.label {
                cost[index] = markCost
            }
        }
    }

    /// Gives every ink pixel the order of the nearest skeleton pixel.
    nonisolated static func spreadToInk(_ grid: InkGrid, cost: inout [Int32]) {
        var queue = cost.indices.filter { cost[$0] != .max }
        var head = 0
        while head < queue.count {
            let index = queue[head]
            head += 1
            grid.forEachNeighbour(of: index) { next, _ in
                guard grid.ink[next], cost[next] == .max else { return }
                cost[next] = cost[index]
                queue.append(next)
            }
        }
    }

    /// Leans the wavefront: lower rows are reached later, as with an angled nib. 0 keeps it upright.
    nonisolated static func applySlant(_ slant: Double, grid: InkGrid, cost: inout [Int32]) {
        guard slant != 0 else { return }
        for index in cost.indices where cost[index] != .max {
            cost[index] += Int32(slant * 10 * Double(index / grid.width))
        }
    }
}
