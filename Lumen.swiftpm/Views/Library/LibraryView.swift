import Photos
import SwiftData
import SwiftUI

/// The grid of photos in one album, with filtering, multi-select and batch actions.
struct LibraryView: View {
    let source: PhotoSource

    @Environment(PhotoLibrary.self) private var library
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var catalog: [AssetMeta]

    @State private var assets: [PHAsset] = []
    @State private var isLoading = true
    @State private var filter = LibraryFilter()
    @AppStorage("library.newestFirst") private var newestFirst = true
    @AppStorage("library.thumbnailSize") private var thumbnailSize = 110.0
    @State private var isSelecting = false
    @State private var selection: Set<String> = []
    @State private var loupe: LoupeTarget?
    @State private var editTarget: EditTarget?
    @State private var progress: String?
    @State private var errorMessage: String?

    private struct FetchKey: Equatable {
        let source: PhotoSource
        let newestFirst: Bool
        let revision: Int
    }

    var body: some View {
        let metas = Dictionary(catalog.map { ($0.assetID, $0) }, uniquingKeysWith: { first, _ in first })
        let visible = assets.filter { filter.includes(metas[$0.localIdentifier]) }

        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: thumbnailSize, maximum: thumbnailSize * 2), spacing: 2)], spacing: 2) {
                ForEach(visible, id: \.localIdentifier) { asset in
                    let id = asset.localIdentifier
                    ThumbnailCell(
                        asset: asset,
                        meta: metas[id],
                        pointSize: thumbnailSize * 1.4,
                        isSelecting: isSelecting,
                        isSelected: selection.contains(id)
                    )
                    .onTapGesture { open(asset, in: visible) }
                    .contextMenu { contextMenu(for: asset, meta: metas[id]) }
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            } else if visible.isEmpty {
                if filter.isActive {
                    ContentUnavailableView("No Matching Photos", systemImage: "line.3.horizontal.decrease.circle", description: Text("Try clearing some filters."))
                } else {
                    ContentUnavailableView("No Photos", systemImage: "photo.on.rectangle")
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            FilterBar(filter: $filter, shown: visible.count, total: assets.count)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelecting {
                BatchActionBar(
                    selectedCount: selection.count,
                    canPaste: appState.copiedSettings != nil,
                    onSelectAll: { selection = Set(visible.map(\.localIdentifier)) },
                    onChange: { change in modelContext.apply(change, to: selection) },
                    onPaste: { paste(to: selection) },
                    onSave: { saveEdits(of: selection) }
                )
            }
        }
        .navigationTitle(library.title(for: source))
        .inlineNavigationTitle()
        .toolbar { toolbar(visible: visible, metas: metas) }
        .task(id: FetchKey(source: source, newestFirst: newestFirst, revision: library.revision)) {
            await reload()
        }
        .coverPresentation(item: $loupe) { target in
            LoupeView(target: target)
        }
        .coverPresentation(item: $editTarget) { target in
            EditorView(target: target)
        }
        .progressOverlay(progress)
        .errorAlert($errorMessage)
    }

    @ToolbarContentBuilder
    private func toolbar(visible: [PHAsset], metas: [String: AssetMeta]) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(isSelecting ? "Done" : "Select") {
                isSelecting.toggle()
                selection.removeAll()
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Sort", selection: $newestFirst) {
                    Text("Newest First").tag(true)
                    Text("Oldest First").tag(false)
                }
                Picker("Thumbnail Size", selection: $thumbnailSize) {
                    Text("Small Thumbnails").tag(80.0)
                    Text("Medium Thumbnails").tag(110.0)
                    Text("Large Thumbnails").tag(170.0)
                }
                Divider()
                let unsaved = visible.map(\.localIdentifier).filter { metas[$0]?.hasUnsavedEdits == true }
                Button("Save \(unsaved.count) Edits to Photos", systemImage: "square.and.arrow.down") {
                    saveEdits(of: Set(unsaved))
                }
                .disabled(unsaved.isEmpty)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for asset: PHAsset, meta: AssetMeta?) -> some View {
        let id = asset.localIdentifier
        Button("Edit", systemImage: "slider.horizontal.3") {
            editTarget = EditTarget(asset: asset, settings: meta?.edit ?? .identity)
        }
        MarkMenus { change in modelContext.apply(change, to: [id]) }
        Divider()
        Button("Copy Settings", systemImage: "doc.on.doc") {
            appState.copiedSettings = meta?.edit
        }
        .disabled(meta?.isEdited != true)
        Button("Paste Settings", systemImage: "doc.on.clipboard") {
            paste(to: [id])
        }
        .disabled(appState.copiedSettings == nil)
        PresetMenu { look in modelContext.apply(.look(look), to: [id]) }
        if meta?.hasUnsavedEdits == true {
            Button("Save Edit to Photos", systemImage: "square.and.arrow.down") {
                saveEdits(of: [id])
            }
        }
        if meta?.isEdited == true {
            Button("Reset Edits", systemImage: "arrow.uturn.backward", role: .destructive) {
                modelContext.apply(.resetEdits, to: [id])
            }
        }
    }

    // MARK: Actions

    private func reload() async {
        let source = source, newestFirst = newestFirst
        assets = await Task.detached(priority: .userInitiated) {
            PhotoLibrary.fetchAssets(in: source, newestFirst: newestFirst)
        }.value
        isLoading = false
    }

    private func open(_ asset: PHAsset, in visible: [PHAsset]) {
        let id = asset.localIdentifier
        if isSelecting {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        } else {
            loupe = LoupeTarget(assets: visible, startID: id)
        }
    }

    private func paste(to ids: Set<String>) {
        guard let settings = appState.copiedSettings else { return }
        modelContext.apply(.look(settings), to: ids)
    }

    private func saveEdits(of ids: Set<String>) {
        let items = assets
            .filter { ids.contains($0.localIdentifier) }
            .compactMap { asset -> (asset: PHAsset, settings: EditSettings)? in
                guard let meta = modelContext.existingMeta(for: asset.localIdentifier), meta.hasUnsavedEdits else { return nil }
                return (asset: asset, settings: meta.edit)
            }
        guard !items.isEmpty else { return }
        progress = items.count == 1 ? "Saving photo…" : "Saving \(items.count) photos…"
        Task {
            defer { progress = nil }
            do {
                try await PhotoExporter.applyToOriginals(items)
                modelContext.markSaved(items.map(\.asset.localIdentifier))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct LoupeTarget: Identifiable {
    let id = UUID()
    let assets: [PHAsset]
    let startID: String
}

struct EditTarget: Identifiable {
    let asset: PHAsset
    let settings: EditSettings

    var id: String { asset.localIdentifier }
}

/// Actions for the photos selected in the grid.
struct BatchActionBar: View {
    let selectedCount: Int
    let canPaste: Bool
    var onSelectAll: () -> Void
    var onChange: (CatalogChange) -> Void
    var onPaste: () -> Void
    var onSave: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(selectedCount == 1 ? "1 photo selected" : "\(selectedCount) photos selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Select All", action: onSelectAll)
                    .font(.subheadline)
            }
            HStack {
                Menu {
                    MarkMenus(onChange: onChange)
                } label: {
                    BarIcon(title: "Mark", systemImage: "star")
                }
                Spacer()
                Menu {
                    Button("Paste Settings", systemImage: "doc.on.clipboard", action: onPaste)
                        .disabled(!canPaste)
                    PresetMenu { onChange(.look($0)) }
                    Divider()
                    Button("Reset Edits", systemImage: "arrow.uturn.backward", role: .destructive) {
                        onChange(.resetEdits)
                    }
                } label: {
                    BarIcon(title: "Develop", systemImage: "slider.horizontal.3")
                }
                Spacer()
                Button(action: onSave) {
                    BarIcon(title: "Save to Photos", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
            }
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

private struct BarIcon: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: systemImage).font(.system(size: 18))
            Text(title).font(.caption2)
        }
        .frame(minWidth: 70)
        .contentShape(Rectangle())
    }
}
