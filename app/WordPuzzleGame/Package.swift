// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WordPuzzleGame",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "WordPuzzleGame", targets: ["WordPuzzleGame"]),
    ],
    dependencies: [
        .package(path: "../WordPuzzleKit"),
    ],
    targets: [
        .target(
            name: "WordPuzzleGame",
            dependencies: [
                .product(name: "WordPuzzleKit", package: "WordPuzzleKit"),
            ]
        ),
        .testTarget(
            name: "WordPuzzleGameTests",
            dependencies: ["WordPuzzleGame"]
        ),
    ]
)
