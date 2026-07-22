import SwiftUI
import WordPuzzleGame

/// Home screen: lists the 16 Themes. Tapping a Theme starts an endless stream
/// of Puzzles from it. Remembers the last opened Theme.
struct HomeView: View {
    @State private var app = AppModel()
    @State private var selectedTheme: String?

    var body: some View {
        NavigationStack {
            Group {
                if let error = app.loadError {
                    ContentUnavailableView(
                        "Couldn't Load Words",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error))
                } else {
                    themeList
                }
            }
            .navigationTitle("Word Search")
            .navigationDestination(item: $selectedTheme) { theme in
                if let catalog = app.catalog {
                    PuzzleView(theme: theme, catalog: catalog)
                        .onAppear { app.lastOpenedTheme = theme }
                }
            }
        }
        .onAppear {
            // UI-verification hook: `-openTheme <THEME>` opens straight into a
            // Puzzle. No effect during normal use (no such argument).
            if let idx = CommandLine.arguments.firstIndex(of: "-openTheme"),
               idx + 1 < CommandLine.arguments.count,
               app.themes.contains(CommandLine.arguments[idx + 1]) {
                selectedTheme = CommandLine.arguments[idx + 1]
            }
        }
    }

    private var themeList: some View {
        List(app.themes, id: \.self) { theme in
            Button {
                selectedTheme = theme
            } label: {
                HStack {
                    Text(theme.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    if theme == app.lastOpenedTheme {
                        Text("Last played")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
