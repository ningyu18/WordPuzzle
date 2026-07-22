import SwiftUI
import WordPuzzleGame

/// App-wide catalog + last-opened-Theme persistence (the only allowed
/// persistence, ADR-0004). Loads the bundled Word catalog once.
@Observable
final class AppModel {
    let catalog: WordCatalog?
    let loadError: String?

    private let lastThemeKey = "lastOpenedTheme"

    init() {
        do {
            self.catalog = try WordCatalog.loadBundled()
            self.loadError = nil
        } catch {
            self.catalog = nil
            self.loadError = String(describing: error)
        }
    }

    var themes: [String] { catalog?.themes ?? [] }

    var lastOpenedTheme: String? {
        get { UserDefaults.standard.string(forKey: lastThemeKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastThemeKey) }
    }
}

extension String {
    /// A Theme name formatted for display: underscores to spaces, title-cased.
    var displayName: String {
        replacingOccurrences(of: "_", with: " ").capitalized
    }
}
