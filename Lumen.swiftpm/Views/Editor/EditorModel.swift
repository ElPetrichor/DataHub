import CoreImage
import Photos
import SwiftUI

/// State for the develop editor: the working settings, the rendered preview and undo history.
@MainActor
@Observable
final class EditorModel {
    let asset: PHAsset
    let initialSettings: EditSettings

    private(set) var settings: EditSettings
    private(set) var tool = EditTool.light
    /// The unedited original at preview resolution, shown for before/after.
    private(set) var original: CGImage?
    /// A small copy of the original for preset thumbnails.
    private(set) var smallOriginal: CGImage?
    private(set) var preview: CGImage?
    private(set) var histogram: Histogram?
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    private var undoStack: [EditSettings] = []
    private var redoStack: [EditSettings] = []

    @ObservationIgnored private var base: CIImage?
    @ObservationIgnored private var originalHistogram: Histogram?
    @ObservationIgnored private var editStart: EditSettings?
    @ObservationIgnored private var renderedKey: RenderKey?
    @ObservationIgnored private var isRendering = false

    private struct RenderKey: Equatable {
        var settings: EditSettings
        var cropping: Bool
    }

    init(asset: PHAsset, settings: EditSettings) {
        self.asset = asset
        self.initialSettings = settings
        self.settings = settings
    }

    var hasChanges: Bool { settings != initialSettings }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    /// While cropping, the preview shows the whole frame with the crop drawn on top.
    var isCropping: Bool { tool == .geometry }

    /// Width ÷ height of the straightened but uncropped image.
    var uncroppedAspect: CGFloat {
        guard let original else { return 1 }
        let width = CGFloat(original.width), height = CGFloat(original.height)
        return settings.quarterTurns % 2 == 0 ? width / height : height / width
    }

    func load() async {
        do {
            let data = try await ImageSource.originalData(for: asset)
            let (preview, small) = await Task.detached(priority: .userInitiated) {
                (ImageSource.downsample(data, maxPixelSize: 2400), ImageSource.downsample(data, maxPixelSize: 240))
            }.value
            guard let preview else { throw LumenError.imageUnavailable }
            original = preview
            smallOriginal = small
            base = CIImage(cgImage: preview)
            originalHistogram = ImageProcessor.shared.histogram(of: preview)
            isLoading = false
            scheduleRender()
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Editing

    func select(_ tool: EditTool) {
        self.tool = tool
        scheduleRender()
    }

    /// A binding for continuous controls. Pair with `trackEditing` so a whole drag is one undo step.
    func binding<Value>(_ keyPath: WritableKeyPath<EditSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { newValue in
                self.settings[keyPath: keyPath] = newValue
                self.scheduleRender()
            }
        )
    }

    /// A binding where every change is its own undo step, for toggles.
    func undoableBinding<Value>(_ keyPath: WritableKeyPath<EditSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { newValue in self.perform { $0[keyPath: keyPath] = newValue } }
        )
    }

    /// Called when a slider or crop drag begins and ends.
    func trackEditing(_ isEditing: Bool) {
        if isEditing {
            editStart = settings
        } else if let start = editStart {
            editStart = nil
            if start != settings { pushUndo(start) }
        }
    }

    /// Applies a discrete change as one undo step.
    func perform(_ change: (inout EditSettings) -> Void) {
        let before = settings
        change(&settings)
        guard settings != before else { return }
        pushUndo(before)
        scheduleRender()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(settings)
        settings = previous
        scheduleRender()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(settings)
        settings = next
        scheduleRender()
    }

    private func pushUndo(_ snapshot: EditSettings) {
        undoStack.append(snapshot)
        if undoStack.count > 200 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    /// A quick automatic tone pass based on the original's histogram.
    func autoTone() {
        guard let histogram = originalHistogram else { return }
        perform { s in
            // Move mean brightness toward a middle gray; ~2.2 EV per doubling of gamma-encoded brightness.
            let ev = 2.2 * log2(0.46 / max(histogram.meanLuminance, 0.02)) * 0.6
            s.exposure = (min(max(ev, -2), 2) * 20).rounded() / 20
            s.highlights = histogram.highlightClipping > 0.01 ? -40 : -15
            s.shadows = histogram.shadowClipping > 0.02 ? 30 : 12
            s.whites = 0
            s.blacks = 0
            s.contrast = 10
            s.vibrance = 15
        }
    }

    // MARK: Geometry

    func rotate(clockwise: Bool) {
        perform { s in
            // A mirrored image turns the other way on screen, so compensate to match the arrow.
            let step = clockwise != s.flipped ? 1 : 3
            s.quarterTurns = (s.quarterTurns + step) % 4
            s.crop = .full
        }
    }

    func flip() {
        perform { s in
            s.flipped.toggle()
            s.crop.x = 1 - s.crop.x - s.crop.width
        }
    }

    /// Sets the largest centered crop with the given aspect ratio.
    func applyAspect(_ aspect: CropAspect) {
        guard let ratio = aspect.ratio(original: uncroppedAspect) else { return }
        // In normalized units the crop's width ÷ height is the pixel ratio divided by the image's aspect.
        let relative = ratio / uncroppedAspect
        let width = relative >= 1 ? 1 : relative
        let height = relative >= 1 ? 1 / relative : 1
        perform { $0.crop = CropRect(x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height) }
    }

    // MARK: Rendering

    /// Renders the latest settings off the main thread. While a render is running, further changes
    /// coalesce: when it finishes, the loop renders whatever the settings are by then.
    private func scheduleRender() {
        guard base != nil, !isRendering else { return }
        isRendering = true
        Task { await renderLoop() }
    }

    private func renderLoop() async {
        defer { isRendering = false }
        while let base {
            var keySettings = settings
            // The crop rectangle doesn't affect the uncropped preview, so dragging it needn't re-render.
            if isCropping { keySettings.crop = .full }
            let key = RenderKey(settings: keySettings, cropping: !isCropping)
            guard key != renderedKey else { return }
            renderedKey = key

            let result = await Task.detached(priority: .userInitiated) { () -> (CGImage?, Histogram?) in
                let processor = ImageProcessor.shared
                let image = processor.render(processor.apply(key.settings, to: base, cropping: key.cropping))
                return (image, image.flatMap { processor.histogram(of: $0) })
            }.value
            preview = result.0
            histogram = result.1
        }
    }
}
