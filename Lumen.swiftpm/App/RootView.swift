import Photos
import SwiftUI

struct RootView: View {
    @Environment(PhotoLibrary.self) private var library
    @Environment(\.scenePhase) private var scenePhase
    @State private var source: PhotoSource? = .allPhotos
    @State private var compactColumn = NavigationSplitViewColumn.detail

    var body: some View {
        Group {
            if library.isAuthorized {
                NavigationSplitView(preferredCompactColumn: $compactColumn) {
                    SidebarView(selection: $source)
                } detail: {
                    LibraryView(source: source ?? .allPhotos)
                        .id(source)
                }
            } else {
                AccessView()
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { library.refreshStatus() }
        }
    }
}

private struct AccessView: View {
    @Environment(PhotoLibrary.self) private var library
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(.tint)
            Text("Welcome to Lumen")
                .font(.largeTitle.bold())
            Text("Cull, rate and develop the photos in your library. Edits are non-destructive, and your originals are always kept.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if library.status == .notDetermined {
                Button("Allow Photo Access") {
                    Task { await library.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Text("Lumen needs access to your photo library. You can turn it on in Settings.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                #if os(iOS)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                #endif
            }
        }
        .padding(32)
        .frame(maxWidth: 440)
    }
}
