import Foundation

/// Produces an endless stream of Puzzles for one Theme using incrementing seeds
/// so successive Puzzles vary (ADR-0002/0004: endless per-Theme play).
public struct PuzzleStream {
    public let theme: String
    private let catalog: WordCatalog
    private let generator: Generator
    private var nextSeed: UInt64

    public init(theme: String, catalog: WordCatalog,
                generator: Generator = Generator(), startSeed: UInt64 = 1) {
        self.theme = theme
        self.catalog = catalog
        self.generator = generator
        self.nextSeed = startSeed
    }

    /// Generate the next Puzzle in the stream, advancing the seed.
    public mutating func next() throws -> Puzzle {
        let seed = nextSeed
        nextSeed &+= 1
        return try generator.generate(theme: theme, catalog: catalog, seed: seed)
    }
}
