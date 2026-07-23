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
                MuteButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                RevealAllButton(game: game)
            }
            ToolbarItem(placement: .topBarTrailing) {
                HintButton(game: game)
            }
        }
        .onChange(of: game.isComplete) { _, complete in
            if complete {
                showComplete = true
                SoundEngine.shared.playPuzzleComplete()
            }
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

/// The Word List: unfound words show large open circles (one per letter),
/// found words show per-letter filled circles colored to match the word's bar
/// in the Grid (via its colorSlot).
struct WordListView: View {
    let game: GameState

    private let columns = [GridItem(.adaptive(minimum: 170), spacing: 20)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 14) {
            ForEach(game.puzzle.wordList, id: \.self) { word in
                WordChip(word: word, foundColor: foundColor(for: word))
            }
        }
        .padding(.horizontal)
    }

    /// The word's Grid color if found, else nil (still to be found).
    private func foundColor(for word: String) -> Color? {
        guard let fw = game.found.first(where: { $0.word == word }) else {
            return nil
        }
        return PuzzlePalette.color(slot: fw.colorSlot)
    }
}

/// One Word List entry: a row of circles, one per letter. Unfound circles are
/// large open outlines; found circles are filled in the word's color with the
/// letter inside — mirroring the reference app.
struct WordChip: View {
    let word: String
    /// Non-nil when the word is found (its Grid bar color).
    let foundColor: Color?

    private let diameter: CGFloat = 15

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(word.enumerated()), id: \.offset) { _, letter in
                letterCircle(letter)
            }
        }
        .frame(height: diameter)
    }

    @ViewBuilder
    private func letterCircle(_ letter: Character) -> some View {
        if let color = foundColor {
            Circle()
                .fill(color)
                .frame(width: diameter, height: diameter)
                .overlay(
                    Text(String(letter))
                        .font(.system(size: diameter * 0.6,
                                      weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                )
        } else {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 2)
                .frame(width: diameter, height: diameter)
        }
    }
}

/// Free, limited Hint button (ADR-0004: one hint type, small fixed count).
struct HintButton: View {
    let game: GameState

    var body: some View {
        Button {
            if game.useHint() != nil {
                SoundEngine.shared.playHint()
            }
        } label: {
            Label("\(game.hintsRemaining)", systemImage: "lightbulb")
        }
        .disabled(game.hintsRemaining == 0 || game.isComplete)
    }
}

/// Admin "reveal all" peek: shows every unfound word's location on the Grid,
/// gated by device authentication (Face ID / Touch ID / passcode). Turning it
/// on requires auth each time; turning it off is free. Non-destructive — it
/// never marks words found or completes the Puzzle.
struct RevealAllButton: View {
    let game: GameState

    var body: some View {
        Button {
            if game.revealAllActive {
                game.hideAllAnswers()
            } else {
                Task {
                    if await AdminAuth.authenticate() {
                        game.showAllAnswers()
                    }
                }
            }
        } label: {
            Image(systemName: game.revealAllActive ? "eye.slash" : "eye")
        }
        .disabled(game.isComplete || game.unfoundWords.isEmpty)
        .accessibilityLabel(game.revealAllActive
                            ? "Hide all answers" : "Reveal all answers")
    }
}

/// Toggles the synthesized sound cues; state is persisted in SoundEngine.
struct MuteButton: View {
    @State private var muted = SoundEngine.shared.isMuted

    var body: some View {
        Button {
            muted.toggle()
            SoundEngine.shared.isMuted = muted
        } label: {
            Image(systemName: muted ? "speaker.slash" : "speaker.wave.2")
        }
        .accessibilityLabel(muted ? "Unmute sounds" : "Mute sounds")
    }
}
