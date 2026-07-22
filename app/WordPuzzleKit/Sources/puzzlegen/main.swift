// puzzlegen — dev CLI that drives the SHIPPED generation code (WordPuzzleKit)
// to emit sample puzzles. Because it links the same library the iOS app will,
// the grids it writes genuinely exercise the app's generator. Each puzzle is
// written as `<name>.txt` (the word_puzzle.txt grid format) plus `<name>.words`
// (its Target Words), ready to feed tools/verify_grid.py.
//
// Usage:
//   puzzlegen                         # one puzzle per theme -> ./samples/
//   puzzlegen --theme ASTRONOMY --count 3 --seed 42 --out ./samples
//   puzzlegen --list                  # list available themes

import Foundation
import WordPuzzleKit

func parseArgs() -> [String: String] {
    var opts: [String: String] = [:]
    let flags = Array(CommandLine.arguments.dropFirst())
    var i = 0
    while i < flags.count {
        let arg = flags[i]
        if arg == "--list" { opts["list"] = "1"; i += 1; continue }
        if arg.hasPrefix("--"), i + 1 < flags.count {
            opts[String(arg.dropFirst(2))] = flags[i + 1]
            i += 2
        } else { i += 1 }
    }
    return opts
}

func writePuzzle(_ puzzle: Puzzle, to dir: URL, name: String) throws {
    let gridURL = dir.appendingPathComponent("\(name).txt")
    let wordsURL = dir.appendingPathComponent("\(name).words")
    try (puzzle.grid.text + "\n").write(to: gridURL, atomically: true, encoding: .utf8)
    try (puzzle.wordList.joined(separator: "\n") + "\n")
        .write(to: wordsURL, atomically: true, encoding: .utf8)
    print("wrote \(gridURL.path)  (\(puzzle.wordList.count) words: \(puzzle.wordList.joined(separator: ", ")))")
}

let opts = parseArgs()
let catalog = try WordCatalog.loadBundled()

if opts["list"] != nil {
    print("Themes (\(catalog.themes.count)):")
    for theme in catalog.themes {
        print("  \(theme)  [\(catalog.pools[theme]?.count ?? 0) placeable words]")
    }
    exit(0)
}

let generator = Generator()
let outDir = URL(fileURLWithPath: opts["out"] ?? "samples")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let baseSeed = UInt64(opts["seed"] ?? "1") ?? 1
let count = Int(opts["count"] ?? "1") ?? 1

let themes: [String]
if let theme = opts["theme"] {
    guard catalog.themes.contains(theme) else {
        FileHandle.standardError.write(Data("unknown theme: \(theme)\n".utf8))
        exit(1)
    }
    themes = [theme]
} else {
    themes = catalog.themes // one (or `count`) puzzle per theme
}

for theme in themes {
    for n in 0..<count {
        let seed = baseSeed &+ UInt64(n)
        let puzzle = try generator.generate(theme: theme, catalog: catalog, seed: seed)
        let suffix = count > 1 ? "_\(n)" : ""
        try writePuzzle(puzzle, to: outDir, name: "\(theme)\(suffix)")
    }
}
