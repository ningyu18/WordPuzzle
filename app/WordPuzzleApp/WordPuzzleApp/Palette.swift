import SwiftUI

/// Colors for successive found words, cycled by a word's stable `colorSlot`.
/// Shared so the Grid bar and the Word List entry for the same word always
/// match (see FoundWord.colorSlot in WordPuzzleGame).
enum PuzzlePalette {
    static let found: [Color] = [
        .green, .orange, .purple, .pink, .teal, .indigo, .brown,
    ]

    static func color(slot: Int) -> Color {
        found[((slot % found.count) + found.count) % found.count]
    }
}
