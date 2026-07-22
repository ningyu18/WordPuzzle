import Foundation

/// Loads Target Words from `word_search_puzzle_words.csv` and groups them by
/// Theme. Words longer than `maxWordLength` (9, per ADR-0003) are filtered out
/// of the placeable pool since they cannot fit a 9×9 Grid.
public struct WordCatalog: Sendable {
    /// Theme name -> its placeable Target Words (uppercased), CSV order preserved.
    public let pools: [String: [String]]
    /// Themes in first-seen CSV order (the home-screen listing order).
    public let themes: [String]

    public init(pools: [String: [String]], themes: [String]) {
        self.pools = pools
        self.themes = themes
    }

    /// Parse CSV text with a `Word,Theme,Length` header.
    public static func parse(csv: String, maxWordLength: Int = 9) -> WordCatalog {
        var pools: [String: [String]] = [:]
        var themes: [String] = []

        let lines = csv.split(whereSeparator: \.isNewline)
        for line in lines.dropFirst() { // skip header
            let cols = line.split(separator: ",", omittingEmptySubsequences: false)
            guard cols.count >= 2 else { continue }
            let word = cols[0].trimmingCharacters(in: .whitespaces).uppercased()
            let theme = cols[1].trimmingCharacters(in: .whitespaces)
            guard !word.isEmpty, !theme.isEmpty, word.count <= maxWordLength else {
                continue
            }
            if pools[theme] == nil {
                pools[theme] = []
                themes.append(theme)
            }
            pools[theme]?.append(word)
        }
        return WordCatalog(pools: pools, themes: themes)
    }

    /// Load the CSV bundled with the package.
    public static func loadBundled(maxWordLength: Int = 9) throws -> WordCatalog {
        guard let url = Bundle.module.url(
            forResource: "word_search_puzzle_words", withExtension: "csv"
        ) else {
            throw WordCatalogError.resourceMissing
        }
        let csv = try String(contentsOf: url, encoding: .utf8)
        return parse(csv: csv, maxWordLength: maxWordLength)
    }
}

public enum WordCatalogError: Error {
    case resourceMissing
}

/// A small deterministic PRNG (SplitMix64) so a given seed reproduces a puzzle
/// exactly — needed for the Python oracle to re-verify the app's output and for
/// a future daily-puzzle hook (ADR-0002 consequence). Not for cryptographic use.
public struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { self.state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
