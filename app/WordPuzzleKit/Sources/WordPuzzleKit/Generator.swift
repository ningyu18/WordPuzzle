import Foundation

/// Builds a Puzzle: places 5–7 Target Words into a 9×9 Grid, then fills empty
/// Cells with random Filler Letters (ADR-0002/0003). Generation is deterministic
/// for a given (theme, seed).
public struct Generator {
    public let gridSize: Int
    public let minWords: Int
    public let maxWords: Int
    /// Fillers are drawn from A–Z uniformly.
    private let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    public init(gridSize: Int = 9, minWords: Int = 5, maxWords: Int = 7) {
        self.gridSize = gridSize
        self.minWords = minWords
        self.maxWords = maxWords
    }

    public enum GenerationError: Error {
        case unknownTheme(String)
        case notEnoughWords(theme: String, have: Int, need: Int)
        case exhaustedRetries
    }

    /// Generate a verified Puzzle for `theme` from `catalog`, reproducible from
    /// `seed`. Retries word selection/placement until the self-check passes.
    public func generate(theme: String, catalog: WordCatalog,
                         seed: UInt64) throws -> Puzzle {
        guard let pool = catalog.pools[theme] else {
            throw GenerationError.unknownTheme(theme)
        }
        guard pool.count >= minWords else {
            throw GenerationError.notEnoughWords(
                theme: theme, have: pool.count, need: minWords)
        }

        var rng = SeededRNG(seed: seed)
        let maxAttempts = 200
        for _ in 0..<maxAttempts {
            let count = Int.random(in: minWords...min(maxWords, pool.count), using: &rng)
            // Prefer longer words first: they are the hardest to place, so
            // seating them early keeps the backtracking shallow.
            let chosen = Array(pool.shuffled(using: &rng).prefix(count))
                .sorted { $0.count > $1.count }

            var grid = Grid(size: gridSize)
            var placements: [Placement] = []
            if placeAll(chosen, into: &grid, placements: &placements, rng: &rng) {
                fillBlanks(&grid, rng: &rng)
                // Self-check mirrors the Python oracle (ADR-0002): every target
                // present exactly once. Regenerate if a filler accidentally
                // duplicated a target elsewhere.
                if selfCheck(grid: grid, targets: chosen) {
                    let wordList = chosen.sorted()
                    return Puzzle(theme: theme, grid: grid, wordList: wordList,
                                  solution: placements, seed: seed)
                }
            }
        }
        throw GenerationError.exhaustedRetries
    }

    // MARK: - Placement

    /// Backtracking placement of all `words` into `grid`.
    private func placeAll(_ words: [String], into grid: inout Grid,
                          placements: inout [Placement],
                          rng: inout SeededRNG) -> Bool {
        if words.isEmpty { return true }
        let word = words[0]
        let rest = Array(words.dropFirst())

        for placement in candidatePlacements(for: word, in: grid, rng: &rng) {
            let snapshot = grid
            apply(placement, to: &grid)
            placements.append(placement)
            if placeAll(rest, into: &grid, placements: &placements, rng: &rng) {
                return true
            }
            grid = snapshot
            placements.removeLast()
        }
        return false
    }

    /// All legal placements for `word`, in randomized order. A placement is
    /// legal if it stays in bounds and every overlapped cell is either empty or
    /// already holds the same letter (allowing shared-letter crossings).
    private func candidatePlacements(for word: String, in grid: Grid,
                                     rng: inout SeededRNG) -> [Placement] {
        let chars = Array(word)
        var result: [Placement] = []
        for row in 0..<grid.size {
            for col in 0..<grid.size {
                for dir in Direction.all {
                    let placement = Placement(
                        word: word, start: Cell(row, col), direction: dir)
                    if canPlace(chars, placement: placement, in: grid) {
                        result.append(placement)
                    }
                }
            }
        }
        return result.shuffled(using: &rng)
    }

    private func canPlace(_ chars: [Character], placement: Placement,
                          in grid: Grid) -> Bool {
        let cells = placement.cells
        for (i, cell) in cells.enumerated() {
            guard grid.inBounds(cell) else { return false }
            let existing = grid[cell]
            if existing != "." && existing != chars[i] { return false }
        }
        return true
    }

    private func apply(_ placement: Placement, to grid: inout Grid) {
        let chars = Array(placement.word)
        for (i, cell) in placement.cells.enumerated() {
            grid[cell] = chars[i]
        }
    }

    private func fillBlanks(_ grid: inout Grid, rng: inout SeededRNG) {
        for row in 0..<grid.size {
            for col in 0..<grid.size {
                let cell = Cell(row, col)
                if grid[cell] == "." {
                    grid[cell] = alphabet.randomElement(using: &rng)!
                }
            }
        }
    }

    // MARK: - Self-check (Swift-side mirror of the Python oracle)

    /// Every target must appear in exactly one Placement across the 8 directions.
    func selfCheck(grid: Grid, targets: [String]) -> Bool {
        for word in targets {
            if Verifier.placements(of: word, in: grid).count != 1 { return false }
        }
        return true
    }
}

/// Grid search used by the self-check — the Swift counterpart of
/// `find_placements` in tools/word_puzzle.py. Kept minimal and shared.
public enum Verifier {
    public static func placements(of word: String, in grid: Grid) -> [Placement] {
        let chars = Array(word.uppercased())
        let length = chars.count
        var found: [Placement] = []
        for row in 0..<grid.size {
            for col in 0..<grid.size {
                for dir in Direction.all {
                    let start = Cell(row, col)
                    let end = Cell(start.row + (length - 1) * dir.dRow,
                                   start.col + (length - 1) * dir.dCol)
                    guard grid.inBounds(end) else { continue }
                    var match = true
                    for i in 0..<length {
                        let cell = Cell(start.row + i * dir.dRow,
                                        start.col + i * dir.dCol)
                        if grid[cell] != chars[i] { match = false; break }
                    }
                    if match {
                        found.append(Placement(word: word.uppercased(),
                                               start: start, direction: dir))
                    }
                }
            }
        }
        return found
    }
}
