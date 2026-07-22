// Domain model for the word-search game. Names match the glossary in
// CONTEXT.md exactly (Grid, Cell, Direction, Placement, Puzzle, Theme,
// Solution) — please keep them in sync.

import Foundation

/// A single letter position in the Grid, addressed by (row, column). 0-indexed.
public struct Cell: Hashable, Sendable, Codable {
    public let row: Int
    public let col: Int
    public init(_ row: Int, _ col: Int) {
        self.row = row
        self.col = col
    }
}

/// One of the 8 straight lines a word may run, as a (dRow, dCol) unit vector.
/// This set MUST match `WordPuzzle.DIRECTIONS` in tools/word_puzzle.py (ADR-0002).
public struct Direction: Hashable, Sendable, Codable {
    public let dRow: Int
    public let dCol: Int
    public init(_ dRow: Int, _ dCol: Int) {
        self.dRow = dRow
        self.dCol = dCol
    }

    /// All 8 directions: horizontal, vertical, and both diagonals, each
    /// forward and reversed. Excludes (0, 0).
    public static let all: [Direction] = [
        Direction(-1, -1), Direction(-1, 0), Direction(-1, 1),
        Direction(0, -1),                    Direction(0, 1),
        Direction(1, -1),  Direction(1, 0),  Direction(1, 1),
    ]
}

/// Where and how a Target Word sits in the Grid: start cell, direction, and
/// the run of cells it occupies.
public struct Placement: Hashable, Sendable, Codable {
    public let word: String
    public let start: Cell
    public let direction: Direction

    public init(word: String, start: Cell, direction: Direction) {
        self.word = word
        self.start = start
        self.direction = direction
    }

    /// The ordered run of cells this word occupies.
    public var cells: [Cell] {
        (0..<word.count).map { i in
            Cell(start.row + i * direction.dRow, start.col + i * direction.dCol)
        }
    }

    public var end: Cell { cells.last ?? start }
}

/// The rectangular matrix of letters shown to the player. Rows are stored as
/// `[Character]` for indexing; `Codable` is provided via the row strings.
public struct Grid: Sendable, Codable {
    public let size: Int
    public private(set) var letters: [[Character]]

    public init(size: Int, fill: Character = ".") {
        self.size = size
        self.letters = Array(
            repeating: Array(repeating: fill, count: size), count: size
        )
    }

    public func inBounds(_ cell: Cell) -> Bool {
        cell.row >= 0 && cell.row < size && cell.col >= 0 && cell.col < size
    }

    public subscript(_ cell: Cell) -> Character {
        get { letters[cell.row][cell.col] }
        set { letters[cell.row][cell.col] = newValue }
    }

    /// One row of letters per line — the `word_puzzle.txt` format the Python
    /// verifier reads.
    public var text: String {
        letters.map { String($0) }.joined(separator: "\n")
    }

    // Codable via row strings, since Character isn't Codable.
    private enum CodingKeys: String, CodingKey { case size, rows }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        size = try c.decode(Int.self, forKey: .size)
        letters = try c.decode([String].self, forKey: .rows).map(Array.init)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(size, forKey: .size)
        try c.encode(letters.map { String($0) }, forKey: .rows)
    }
}

/// A single playable instance: a Grid, a Theme, a Word List, and its Solution.
public struct Puzzle: Sendable, Codable {
    public let theme: String
    public let grid: Grid
    /// The Target Words shown on screen, in list order.
    public let wordList: [String]
    /// The ground-truth Placement per Target Word.
    public let solution: [Placement]
    /// The seed that produced this puzzle (deterministic reproduction, ADR-0002).
    public let seed: UInt64

    public init(theme: String, grid: Grid, wordList: [String],
                solution: [Placement], seed: UInt64) {
        self.theme = theme
        self.grid = grid
        self.wordList = wordList
        self.solution = solution
        self.seed = seed
    }
}
