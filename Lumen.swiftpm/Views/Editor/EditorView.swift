import Photos
import SwiftData
import SwiftUI

/// The develop module: a live preview over tool panels for presets, light, color, effects, detail and crop.
struct EditorView: View {
    @State private var model: EditorModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @AppStorage("editor.showsHistogram") private var showsHistogram = true

    @State private var showsOriginal = false
    @State private var cropAspect = CropAspect.free
    @State private var confirmsDiscard = false
    @State private var namesPreset = false
    @State private var presetName = ""
    @State private var progress: String?
    @State private var errorMessage: String?

    init(target: EditTarget) {
        _model = State(initialValue: EditorModel(asset: target.asset, settings: target.settings))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                canvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                toolPanel
                    .frame(height: 220)
                    .background(Color(white: 0.09))
                toolPicker
            }
            .background(Color.black)
            .toolbar { toolbar }
            .inlineNavigationTitle()
        }
        .task { await model.load() }
        .confirmationDialog("Discard your changes?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Discard Changes", role: .destructive) { dismiss() }
        }
        .alert("New Preset", isPresented: $namesPreset) {
            TextField("Name", text: $presetName)
            Button("Save") { savePreset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves this photo's light, color, effects and detail settings.")
        }
        .progressOverlay(progress)
        .errorAlert($errorMessage)
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { proxy in
            let bounds = CGRect(origin: .zero, size: proxy.size).insetBy(dx: 16, dy: 16)
            ZStack {
                if let image = showsOriginal ? model.original : (model.preview ?? model.original) {
                    let aspect = model.isCropping && !showsOriginal
                        ? model.uncroppedAspect
                        : CGFloat(image.width) / CGFloat(image.height)
                    let frame = bounds.fitting(aspect: aspect)
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                    if model.isCropping {
                        CropOverlay(
                            crop: model.binding(\.crop),
                            frame: frame,
                            aspect: cropAspect.ratio(original: model.uncroppedAspect),
                            onEditingChanged: model.trackEditing
                        )
                    }
                } else if let errorMessage = model.errorMessage {
                    ContentUnavailableView("Couldn't Load Photo", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    ProgressView()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .contentShape(Rectangle())
        // Press and hold to compare with the original.
        .onLongPressGesture(minimumDuration: 0.15, maximumDistance: 40, perform: {}, onPressingChanged: { pressing in
            showsOriginal = pressing && !model.isCropping
        })
        .overlay(alignment: .topLeading) {
            if showsHistogram, let histogram = model.histogram, !model.isCropping {
                HistogramView(histogram: histogram)
                    .frame(width: 128, height: 64)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            if showsOriginal {
                Text("Original")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 12)
            }
        }
    }

    // MARK: Tools

    @ViewBuilder
    private var toolPanel: some View {
        switch model.tool {
        case .presets:
            PresetStrip(model: model) {
                presetName = ""
                namesPreset = true
            }
        case .geometry:
            GeometryPanel(model: model, aspect: $cropAspect)
        default:
            AdjustmentList(model: model, tool: model.tool)
        }
    }

    private var toolPicker: some View {
        HStack(spacing: 0) {
            ForEach(EditTool.allCases) { tool in
                Button {
                    model.select(tool)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 18))
                            .overlay(alignment: .topTrailing) {
                                if tool.isModified(in: model.settings) {
                                    Circle().fill(Color.lumenAccent).frame(width: 5, height: 5).offset(x: 5, y: -2)
                                }
                            }
                        Text(tool.title).font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(model.tool == tool ? Color.lumenAccent : Color.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                if model.hasChanges { confirmsDiscard = true } else { dismiss() }
            }
        }
        ToolbarItem(placement: .principal) {
            HStack(spacing: 20) {
                Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!model.canUndo)
                Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    .disabled(!model.canRedo)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section {
                    Button("Save to Photos", systemImage: "square.and.arrow.down") { saveToPhotos() }
                    Button("Save as Copy", systemImage: "plus.square.on.square") { saveCopy() }
                    ShareLink(
                        item: ExportedPhoto(assetID: model.asset.localIdentifier, settings: model.settings),
                        preview: SharePreview("Edited Photo")
                    )
                }
                Section {
                    Button("Copy Settings", systemImage: "doc.on.doc") { appState.copiedSettings = model.settings }
                    Button("Paste Settings", systemImage: "doc.on.clipboard") {
                        guard let copied = appState.copiedSettings else { return }
                        model.perform { $0 = $0.withLook(of: copied) }
                    }
                    .disabled(appState.copiedSettings == nil)
                    Button("Save as Preset…", systemImage: "square.stack") {
                        presetName = ""
                        namesPreset = true
                    }
                }
                Section {
                    Toggle("Show Histogram", isOn: $showsHistogram)
                    Button("Reset All", systemImage: "arrow.counterclockwise", role: .destructive) {
                        model.perform { $0 = .identity }
                        cropAspect = .free
                    }
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
                commit()
                dismiss()
            }
            .bold()
        }
    }

    // MARK: Actions

    /// Stores the settings in Lumen's catalog. Writing to the Photos library is a separate, explicit step.
    private func commit() {
        guard model.hasChanges else { return }
        modelContext.meta(for: model.asset.localIdentifier).edit = model.settings
    }

    private func saveToPhotos() {
        commit()
        let asset = model.asset, settings = model.settings
        progress = "Saving to Photos…"
        Task {
            defer { progress = nil }
            do {
                try await PhotoExporter.applyToOriginals([(asset: asset, settings: settings)])
                modelContext.markSaved([asset.localIdentifier])
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveCopy() {
        let asset = model.asset, settings = model.settings
        progress = "Saving copy…"
        Task {
            defer { progress = nil }
            do {
                try await PhotoExporter.saveCopy(of: asset, settings: settings)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func savePreset() {
        let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var look = model.settings
        look.resetGeometry()
        modelContext.insert(UserPreset(name: name, settings: look))
    }
}
