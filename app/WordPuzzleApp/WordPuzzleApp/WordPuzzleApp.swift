import SwiftUI

@main
struct WordPuzzleApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .onAppear { SoundEngine.shared.activate() }
        }
    }
}
