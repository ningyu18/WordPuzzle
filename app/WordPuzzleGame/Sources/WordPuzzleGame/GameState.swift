import Foundation
import Observation

/// A revealed word's Placement plus a color slot so the UI can keep its bar and
/// letter highlight on the Grid after a match (CONTEXT.md: found words stay lit).
public struct FoundWord: Equatable, Sendable {
    public let word: String
    public let placement: Placement
    /// Stable index used to pick a distinct highlight color per found word.
    public let colorSlot: Int
}

/// Observable game state for one Puzzle: tracks the live Selection, found Target
/// Words, and remaining Hints. All decision logic (matching, hint, completion)
/// lives here, SwiftUI-free, so it is unit-testable.
@Observable
public final class GameState {
    public private(set) var puzzle: Puzzle
    /// Found Target Words, in the order discovered.
    public private(set) var found: [FoundWord] = []
    /// The live Selection while the player drags; nil when idle.
    public private(set) var selection: Selection?
    /// Hints remaining for this Puzzle.
    public private(set) var hintsRemaining: Int
    /// A Hint currently being shown (the revealed Placement), if any.
    public private(set) var hintPlacement: Placement?

    public let maxHints: Int

    public init(puzzle: Puzzle, maxHints: Int = 3) {
        self.puzzle = puzzle
        self.maxHints = maxHints
        self.hintsRemaining = maxHints
    }

    // MARK: - Derived state

    /// Target Words not yet found (uppercased, as stored in the Word List).
    public var unfoundWords: [String] {
        let foundSet = Set(found.map { $0.word })
        return puzzle.wordList.filter { !foundSet.contains($0) }
    }

    public var isComplete: Bool {
        found.count == puzzle.wordList.count
    }

    public func isFound(_ word: String) -> Bool {
        found.contains { $0.word == word }
    }

    /// Cells that should stay highlighted (all found words' Placements).
    public var foundCells: Set<Cell> {
        var cells = Set<Cell>()
        for f in found { cells.formUnion(f.placement.cells) }
        return cells
    }

    /// The word currently spelled by the live Selection (for the Preview Banner).
    public var previewText: String {
        guard let sel = selection else { return "" }
        return String(sel.cells.map { puzzle.grid[$0] })
    }

    // MARK: - Trace / Selection

    /// Begin a Trace at `start`.
    public func beginSelection(at start: Cell) {
        selection = Selection(start: start, direction: Direction(0, 1),
                              cells: [start])
    }

    /// Update the live Selection as the finger moves toward `finger`.
    public func updateSelection(toward finger: Cell) {
        guard let start = selection?.start else { return }
        selection = SelectionEngine.snap(from: start, toward: finger,
                                         gridSize: puzzle.grid.size)
    }

    /// End the Trace. Returns the matched Target Word if the Selection lines up
    /// with an unfound Placement in either orientation; keeps the bar lit on a
    /// match, clears it otherwise.
    @discardableResult
    public func endSelection() -> String? {
        guard let sel = selection,
              let placement = matchedPlacement(for: sel) else {
            selection = nil
            return nil
        }
        reveal(placement)
        // The live Selection is cleared, but the matched run stays lit via
        // `foundCells` (CONTEXT.md: keep the highlight on a match).
        selection = nil
        return placement.word
    }

    /// The unfound Target Word's Placement the Selection matches (forward or
    /// reversed), if any. Pure query — no side effects, so it is unit-testable.
    public func matchedPlacement(for sel: Selection) -> Placement? {
        for placement in puzzle.solution where !isFound(placement.word) {
            let forward = sel.start == placement.start && sel.end == placement.end
            let reversed = sel.start == placement.end && sel.end == placement.start
            if forward || reversed { return placement }
        }
        return nil
    }

    /// Convenience for tests/UI: the matched Target Word for a Selection.
    public func matchedWord(for sel: Selection) -> String? {
        matchedPlacement(for: sel)?.word
    }

    private func reveal(_ placement: Placement) {
        guard !isFound(placement.word) else { return }
        found.append(FoundWord(word: placement.word, placement: placement,
                               colorSlot: found.count))
    }

    // MARK: - Hint

    /// Reveal the location of one unfound Target Word, spending a Hint. Returns
    /// the revealed Placement, or nil if none remain.
    @discardableResult
    public func useHint() -> Placement? {
        guard hintsRemaining > 0 else { return nil }
        guard let word = unfoundWords.first,
              let placement = puzzle.solution.first(where: { $0.word == word })
        else { return nil }
        hintsRemaining -= 1
        hintPlacement = placement
        return placement
    }

    /// Dismiss the currently shown Hint highlight.
    public func clearHint() {
        hintPlacement = nil
    }
}
