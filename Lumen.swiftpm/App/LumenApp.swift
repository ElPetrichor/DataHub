import SwiftData
import SwiftUI

@main
struct LumenApp: App {
    @State private var library = PhotoLibrary()
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(appState)
                .preferredColorScheme(.dark)
                .tint(.lumenAccent)
        }
        .modelContainer(for: [AssetMeta.self, UserPreset.self])
    }
}

/// App-wide state that isn't tied to a single photo.
@Observable
final class AppState {
    /// Develop settings on the clipboard, copied from one photo to paste onto others.
    var copiedSettings: EditSettings?
}

extension Color {
    static let lumenAccent = Color(red: 0.31, green: 0.62, blue: 1.0)
}
