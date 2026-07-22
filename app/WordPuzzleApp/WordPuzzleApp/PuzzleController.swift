import SwiftUI
import WordPuzzleGame

/// Owns the endless PuzzleStream for a Theme and the GameState for the current
/// Puzzle. Advances to the next Puzzle when the current one is complete.
@Observable
final class PuzzleController {
    let theme: String
    private var stream: PuzzleStream
    private(set) var game: GameState
    private(set) var generationError: String?

    init(theme: String, catalog: WordCatalog) {
        self.theme = theme
        var stream = PuzzleStream(theme: theme, catalog: catalog)
        self.stream = stream
        do {
            let puzzle = try stream.next()
            self.game = GameState(puzzle: puzzle)
            self.stream = stream
        } catch {
            // Fall back to an empty placeholder Puzzle; surface the error.
            self.game = GameState(puzzle: Puzzle(
                theme: theme, grid: Grid(size: 9), wordList: [],
                solution: [], seed: 0))
            self.generationError = String(describing: error)
            self.stream = stream
        }
    }

    /// Generate and switch to the next Puzzle in the Theme (endless play).
    func advanceToNextPuzzle() {
        do {
            let puzzle = try stream.next()
            game = GameState(puzzle: puzzle)
            generationError = nil
        } catch {
            generationError = String(describing: error)
        }
    }
}
