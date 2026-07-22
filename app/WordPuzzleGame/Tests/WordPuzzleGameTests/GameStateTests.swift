import Testing
@testable import WordPuzzleGame
import WordPuzzleKit

@Suite struct SelectionEngineTests {
    // A drag from (4,4) toward each neighbor should snap to that Direction.
    @Test func snapsToEachOfEightDirections() {
        let start = Cell(4, 4)
        let cases: [(Cell, Direction)] = [
            (Cell(4, 8), Direction(0, 1)),   // east
            (Cell(4, 0), Direction(0, -1)),  // west
            (Cell(0, 4), Direction(-1, 0)),  // north
            (Cell(8, 4), Direction(1, 0)),   // south
            (Cell(8, 8), Direction(1, 1)),   // SE
            (Cell(0, 0), Direction(-1, -1)), // NW
            (Cell(0, 8), Direction(-1, 1)),  // NE
            (Cell(8, 0), Direction(1, -1)),  // SW
        ]
        for (finger, dir) in cases {
            let sel = SelectionEngine.snap(from: start, toward: finger, gridSize: 9)
            #expect(sel.direction == dir)
        }
    }

    @Test func snapsNearlyHorizontalDragToHorizontal() {
        // Finger 4 cells right, 1 down -> should snap to due east, not diagonal.
        let sel = SelectionEngine.snap(from: Cell(2, 1), toward: Cell(3, 5),
                                       gridSize: 9)
        #expect(sel.direction == Direction(0, 1))
    }

    @Test func runLengthFollowsFinger() {
        let sel = SelectionEngine.snap(from: Cell(0, 0), toward: Cell(0, 3),
                                       gridSize: 9)
        #expect(sel.cells == [Cell(0,0), Cell(0,1), Cell(0,2), Cell(0,3)])
    }

    @Test func runClampsToGridBounds() {
        // Dragging east from the last column can only cover the start Cell.
        let sel = SelectionEngine.snap(from: Cell(0, 8), toward: Cell(0, 20),
                                       gridSize: 9)
        #expect(sel.cells == [Cell(0, 8)])
    }

    @Test func idleDragIsSingleCell() {
        let sel = SelectionEngine.snap(from: Cell(3, 3), toward: Cell(3, 3),
                                       gridSize: 9)
        #expect(sel.cells == [Cell(3, 3)])
    }
}

@Suite struct GameStateMatchTests {
    /// A tiny hand-built Puzzle: CAT horizontal at row 0, DOG vertical at col 0.
    func makePuzzle() -> Puzzle {
        var grid = Grid(size: 3)
        grid[Cell(0,0)] = "C"; grid[Cell(0,1)] = "A"; grid[Cell(0,2)] = "T"
        grid[Cell(1,0)] = "O"; grid[Cell(2,0)] = "G"
        // fill remaining blanks
        grid[Cell(1,1)] = "X"; grid[Cell(1,2)] = "Y"
        grid[Cell(2,1)] = "Z"; grid[Cell(2,2)] = "W"
        let cat = Placement(word: "CAT", start: Cell(0,0), direction: Direction(0,1))
        let dog = Placement(word: "DOG", start: Cell(0,0), direction: Direction(1,0))
        return Puzzle(theme: "TEST", grid: grid, wordList: ["CAT", "DOG"],
                      solution: [cat, dog], seed: 0)
    }

    @Test func matchesForwardOrientation() {
        let g = GameState(puzzle: makePuzzle())
        g.beginSelection(at: Cell(0, 0))
        g.updateSelection(toward: Cell(0, 2))
        #expect(g.endSelection() == "CAT")
        #expect(g.isFound("CAT"))
        #expect(!g.isComplete)
    }

    @Test func matchesReversedOrientation() {
        let g = GameState(puzzle: makePuzzle())
        // Trace DOG bottom-to-top: start at (2,0) end at (0,0).
        g.beginSelection(at: Cell(2, 0))
        g.updateSelection(toward: Cell(0, 0))
        #expect(g.endSelection() == "DOG")
        #expect(g.isFound("DOG"))
    }

    @Test func nonMatchingSelectionClearsBar() {
        let g = GameState(puzzle: makePuzzle())
        g.beginSelection(at: Cell(1, 1))
        g.updateSelection(toward: Cell(2, 2))
        #expect(g.endSelection() == nil)
        #expect(g.selection == nil)
        #expect(g.found.isEmpty)
    }

    @Test func previewShowsLettersUnderBar() {
        let g = GameState(puzzle: makePuzzle())
        g.beginSelection(at: Cell(0, 0))
        g.updateSelection(toward: Cell(0, 2))
        #expect(g.previewText == "CAT")
    }

    @Test func completesWhenAllFound() {
        let g = GameState(puzzle: makePuzzle())
        g.beginSelection(at: Cell(0, 0)); g.updateSelection(toward: Cell(0, 2))
        g.endSelection()
        g.beginSelection(at: Cell(0, 0)); g.updateSelection(toward: Cell(2, 0))
        g.endSelection()
        #expect(g.isComplete)
        #expect(g.unfoundWords.isEmpty)
        #expect(g.foundCells.count == 5) // C,A,T + O,G (C shared)
    }

    @Test func alreadyFoundWordIsNotDoubleCounted() {
        let g = GameState(puzzle: makePuzzle())
        g.beginSelection(at: Cell(0, 0)); g.updateSelection(toward: Cell(0, 2))
        g.endSelection()
        g.beginSelection(at: Cell(0, 0)); g.updateSelection(toward: Cell(0, 2))
        #expect(g.endSelection() == nil)
        #expect(g.found.count == 1)
    }
}

@Suite struct GameStateHintTests {
    func makePuzzle() -> Puzzle {
        var grid = Grid(size: 3)
        grid[Cell(0,0)] = "C"; grid[Cell(0,1)] = "A"; grid[Cell(0,2)] = "T"
        let cat = Placement(word: "CAT", start: Cell(0,0), direction: Direction(0,1))
        return Puzzle(theme: "TEST", grid: grid, wordList: ["CAT"],
                      solution: [cat], seed: 0)
    }

    @Test func hintDecrementsAndRevealsUnfoundWord() {
        let g = GameState(puzzle: makePuzzle(), maxHints: 3)
        let p = g.useHint()
        #expect(p?.word == "CAT")
        #expect(g.hintsRemaining == 2)
        #expect(g.hintPlacement?.word == "CAT")
    }

    @Test func hintRunsOutAtZero() {
        let g = GameState(puzzle: makePuzzle(), maxHints: 1)
        #expect(g.useHint() != nil)
        #expect(g.hintsRemaining == 0)
        #expect(g.useHint() == nil)
        #expect(g.hintsRemaining == 0)
    }

    @Test func hintSkipsAlreadyFoundWords() {
        let g = GameState(puzzle: makePuzzle(), maxHints: 3)
        g.beginSelection(at: Cell(0,0)); g.updateSelection(toward: Cell(0,2))
        g.endSelection()
        // Only word found -> no unfound word to hint.
        #expect(g.useHint() == nil)
        #expect(g.hintsRemaining == 3) // not spent when nothing to reveal
    }
}

@Suite struct PuzzleStreamTests {
    @Test func producesVaryingPuzzlesWithIncrementingSeeds() throws {
        let catalog = try WordCatalog.loadBundled()
        var stream = PuzzleStream(theme: catalog.themes[0], catalog: catalog)
        let a = try stream.next()
        let b = try stream.next()
        #expect(a.seed == 1)
        #expect(b.seed == 2)
        // Different seeds should (almost surely) yield different grids.
        #expect(a.grid.text != b.grid.text)
    }
}
