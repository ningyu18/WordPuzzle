import Testing
@testable import WordPuzzleKit

@Suite struct GeneratorTests {
    @Test func catalogLoadsSixteenThemes() throws {
        let catalog = try WordCatalog.loadBundled()
        #expect(catalog.themes.count == 16)
        // No placeable word exceeds the 9×9 grid (ADR-0003).
        for (_, pool) in catalog.pools {
            #expect(pool.allSatisfy { $0.count <= 9 })
            #expect(pool.count >= 5)
        }
    }

    @Test func generatedPuzzleIsValid() throws {
        let catalog = try WordCatalog.loadBundled()
        let gen = Generator()
        for theme in catalog.themes {
            let puzzle = try gen.generate(theme: theme, catalog: catalog, seed: 7)
            #expect((5...7).contains(puzzle.wordList.count))
            #expect(puzzle.grid.size == 9)
            // Every target present exactly once — the oracle contract (ADR-0002).
            for word in puzzle.wordList {
                #expect(Verifier.placements(of: word, in: puzzle.grid).count == 1)
            }
            // No blanks left.
            #expect(puzzle.grid.letters.allSatisfy { $0.allSatisfy { $0 != "." } })
        }
    }

    @Test func generationIsDeterministic() throws {
        let catalog = try WordCatalog.loadBundled()
        let gen = Generator()
        let a = try gen.generate(theme: "ASTRONOMY", catalog: catalog, seed: 99)
        let b = try gen.generate(theme: "ASTRONOMY", catalog: catalog, seed: 99)
        #expect(a.grid.text == b.grid.text)
        #expect(a.wordList == b.wordList)
    }
}
