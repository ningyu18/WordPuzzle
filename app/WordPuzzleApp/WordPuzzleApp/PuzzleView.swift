import SwiftUI
import WordPuzzleGame

/// The Puzzle screen, laid out top-to-bottom per CONTEXT.md:
/// Theme title, Preview Banner, Grid, Word List.
struct PuzzleView: View {
    @State private var controller: PuzzleController
    @State private var showComplete = false

    init(theme: String, catalog: WordCatalog) {
        _controller = State(initialValue:
            PuzzleController(theme: theme, catalog: catalog))
    }

    private var game: GameState { controller.game }

    var body: some View {
        VStack(spacing: 12) {
            PreviewBanner(text: game.previewText)

            GridView(game: game)
                .padding(.horizontal)

            WordListView(game: game)

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .navigationTitle(controller.theme.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HintButton(game: game)
            }
        }
        .onChange(of: game.isComplete) { _, complete in
            if complete { showComplete = true }
        }
        .overlay {
            if let error = controller.generationError {
                ContentUnavailableView(
                    "Couldn't Generate Puzzle",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error))
            }
        }
        .alert("Puzzle Complete", isPresented: $showComplete) {
            Button("Next Puzzle") {
                controller.advanceToNextPuzzle()
            }
        } message: {
            Text("You found all \(game.puzzle.wordList.count) words.")
        }
    }
}

/// A fixed strip showing the in-progress word spelled by the current Selection.
struct PreviewBanner: View {
    let text: String

    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(.title2, design: .rounded).weight(.bold))
            .tracking(4)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .accessibilityLabel("Preview Banner")
            .accessibilityValue(text)
    }
}

/// The Word List: unfound words show blank circles (one per letter), found
/// words show their full letters in a distinct color.
struct WordListView: View {
    let game: GameState

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(game.puzzle.wordList, id: \.self) { word in
                WordChip(word: word, found: game.isFound(word))
            }
        }
        .padding(.horizontal)
    }
}

struct WordChip: View {
    let word: String
    let found: Bool

    var body: some View {
        Group {
            if found {
                Text(word)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.green)
            } else {
                HStack(spacing: 3) {
                    ForEach(0..<word.count, id: \.self) { _ in
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1.5)
                            .frame(width: 9, height: 9)
                    }
                }
            }
        }
        .frame(height: 20)
    }
}

/// Free, limited Hint button (ADR-0004: one hint type, small fixed count).
struct HintButton: View {
    let game: GameState

    var body: some View {
        Button {
            game.useHint()
        } label: {
            Label("\(game.hintsRemaining)", systemImage: "lightbulb")
        }
        .disabled(game.hintsRemaining == 0 || game.isComplete)
    }
}
