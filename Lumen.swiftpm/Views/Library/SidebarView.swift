import SwiftUI

struct SidebarView: View {
    @Environment(PhotoLibrary.self) private var library
    @Binding var selection: PhotoSource?

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                Label("All Photos", systemImage: "photo.on.rectangle")
                    .tag(PhotoSource.allPhotos)
                ForEach(library.smartAlbums) { album in
                    row(for: album)
                }
            }
            if !library.albums.isEmpty {
                Section("Albums") {
                    ForEach(library.albums) { album in
                        row(for: album)
                    }
                }
            }
        }
        .navigationTitle("Lumen")
    }

    private func row(for album: AlbumInfo) -> some View {
        Label(album.title, systemImage: album.systemImage)
            .badge(album.count)
            .tag(PhotoSource.collection(album.id))
    }
}
