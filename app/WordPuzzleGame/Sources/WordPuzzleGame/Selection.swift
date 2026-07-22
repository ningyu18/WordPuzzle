import Foundation
// Re-export the model so the app only needs to import WordPuzzleGame.
@_exported import WordPuzzleKit

/// A Trace in progress or committed: a straight run of Cells from a start Cell
/// along one of the 8 Directions (CONTEXT.md: "Trace / Selection").
public struct Selection: Equatable, Sendable {
    public let start: Cell
    public let direction: Direction
    /// The ordered run of Cells under the bar, always starting at `start`.
    public let cells: [Cell]

    public init(start: Cell, direction: Direction, cells: [Cell]) {
        self.start = start
        self.direction = direction
        self.cells = cells
    }

    public var end: Cell { cells.last ?? start }
}

/// Pure geometry for turning a start Cell + finger Cell into a Selection that
/// snaps to the nearest of the 8 Directions. Kept free of SwiftUI so it can be
/// unit-tested directly.
public enum SelectionEngine {
    /// Snap a drag from `start` toward `finger` onto the nearest Direction,
    /// extending as many Cells as the finger reaches without leaving the Grid.
    public static func snap(from start: Cell, toward finger: Cell,
                            gridSize: Int) -> Selection {
        let dRow = finger.row - start.row
        let dCol = finger.col - start.col

        // No movement yet: the Selection is just the start Cell.
        if dRow == 0 && dCol == 0 {
            return Selection(start: start, direction: Direction(0, 1),
                             cells: [start])
        }

        // Choose the Direction whose unit vector is closest in angle to the
        // drag vector (largest normalized dot product).
        var best = Direction.all[0]
        var bestScore = -Double.greatestFiniteMagnitude
        let delta = (Double(dRow), Double(dCol))
        for dir in Direction.all {
            let mag = (Double(dir.dRow * dir.dRow + dir.dCol * dir.dCol)).squareRoot()
            let dot = delta.0 * Double(dir.dRow) + delta.1 * Double(dir.dCol)
            let score = dot / mag
            if score > bestScore {
                bestScore = score
                best = dir
            }
        }

        // Project the drag onto the chosen Direction to get the run length.
        let dirDot = Double(best.dRow * best.dRow + best.dCol * best.dCol)
        let proj = (Double(dRow) * Double(best.dRow) + Double(dCol) * Double(best.dCol)) / dirDot
        var steps = Int(proj.rounded())
        if steps < 0 { steps = 0 }

        // Clamp so the run stays inside the Grid.
        func inBounds(_ s: Int) -> Bool {
            let r = start.row + s * best.dRow
            let c = start.col + s * best.dCol
            return r >= 0 && r < gridSize && c >= 0 && c < gridSize
        }
        while steps > 0 && !inBounds(steps) { steps -= 1 }

        let cells = (0...steps).map {
            Cell(start.row + $0 * best.dRow, start.col + $0 * best.dCol)
        }
        return Selection(start: start, direction: best, cells: cells)
    }
}
