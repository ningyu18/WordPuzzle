// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WordPuzzleKit",
    products: [
        .library(name: "WordPuzzleKit", targets: ["WordPuzzleKit"]),
        .executable(name: "puzzlegen", targets: ["puzzlegen"]),
    ],
    targets: [
        .target(
            name: "WordPuzzleKit",
            resources: [.process("Resources/word_search_puzzle_words.csv")]
        ),
        .executableTarget(
            name: "puzzlegen",
            dependencies: ["WordPuzzleKit"]
        ),
        .testTarget(
            name: "WordPuzzleKitTests",
            dependencies: ["WordPuzzleKit"]
        ),
    ]
)
