import SwiftData
import SwiftUI

/// The sliders of one tool tab.
struct AdjustmentList: View {
    let model: EditorModel
    let tool: EditTool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if tool == .light {
                    HStack {
                        Spacer()
                        Button("Auto", systemImage: "wand.and.stars") { model.autoTone() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                if tool == .color {
                    Toggle("Black & White", isOn: model.undoableBinding(\.monochrome))
                        .font(.subheadline)
                }
                ForEach(tool.adjustments) { adjustment in
                    AdjustmentSlider(
                        adjustment: adjustment,
                        value: model.binding(adjustment.keyPath),
                        onEditingChanged: model.trackEditing,
                        onReset: { model.perform { $0[keyPath: adjustment.keyPath] = 0 } }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}

struct AdjustmentSlider: View {
    let adjustment: Adjustment
    @Binding var value: Double
    var onEditingChanged: (Bool) -> Void
    var onReset: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(adjustment.title)
                Spacer()
                Text(adjustment.formatted(value))
                    .monospacedDigit()
                    .foregroundStyle(value == 0 ? Color.secondary : Color.primary)
            }
            .font(.subheadline)
            .contentShape(Rectangle())
            // Double-tap the label to reset, like Lightroom.
            .onTapGesture(count: 2, perform: onReset)

            Slider(value: $value, in: adjustment.range, step: adjustment.step, onEditingChanged: onEditingChanged)
                .tint(trackColors == nil ? Color.lumenAccent : Color.clear)
                .background(alignment: .center) {
                    if let trackColors {
                        Capsule()
                            .fill(LinearGradient(colors: trackColors, startPoint: .leading, endPoint: .trailing))
                            .frame(height: 4)
                            .padding(.horizontal, 2)
                    }
                }
        }
    }

    private var trackColors: [Color]? {
        switch adjustment.track {
        case .plain: nil
        case .temperature: [Color(red: 0.25, green: 0.5, blue: 1), Color(red: 1, green: 0.85, blue: 0.2)]
        case .tint: [Color(red: 0.2, green: 0.8, blue: 0.3), Color(red: 0.9, green: 0.3, blue: 0.85)]
        case .saturation: [Color.gray, Color(red: 1, green: 0.25, blue: 0.3)]
        }
    }
}

/// Built-in and saved presets as a strip of live thumbnails.
struct PresetStrip: View {
    let model: EditorModel
    var onSaveNew: () -> Void

    @Query(sort: \UserPreset.createdAt) private var userPresets: [UserPreset]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                PresetCell(name: "Original", look: .identity, model: model)
                ForEach(Preset.builtIn) { preset in
                    PresetCell(name: preset.name, look: preset.settings, model: model)
                }
                ForEach(userPresets) { preset in
                    PresetCell(name: preset.name, look: preset.settings, model: model)
                        .contextMenu {
                            Button("Delete Preset", systemImage: "trash", role: .destructive) {
                                modelContext.delete(preset)
                            }
                        }
                }
                Button(action: onSaveNew) {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .frame(width: 76, height: 76)
                            .overlay(Image(systemName: "plus").font(.title2))
                        Text("New Preset").font(.caption2)
                    }
                    .frame(width: 80)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }
}

private struct PresetCell: View {
    let name: String
    let look: EditSettings
    let model: EditorModel
    @State private var thumbnail: CGImage?

    var body: some View {
        let isActive = model.settings.withLook(of: look) == model.settings
        Button {
            model.perform { $0 = $0.withLook(of: look) }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if let thumbnail {
                        Image(decorative: thumbnail, scale: 1)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.white.opacity(0.08)
                    }
                }
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isActive ? Color.lumenAccent : .clear, lineWidth: 2))
                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(isActive ? Color.lumenAccent : Color.primary)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
        .task(id: model.smallOriginal == nil) {
            guard let base = model.smallOriginal else { return }
            let look = look
            thumbnail = await Task.detached(priority: .utility) {
                let processor = ImageProcessor.shared
                return processor.render(processor.apply(look, to: CIImage(cgImage: base)))
            }.value
        }
    }
}

/// Crop aspect, straighten, rotate and flip.
struct GeometryPanel: View {
    let model: EditorModel
    @Binding var aspect: CropAspect

    var body: some View {
        VStack(spacing: 18) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CropAspect.allCases) { option in
                        Button(option.title) {
                            aspect = option
                            model.applyAspect(option)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(aspect == option ? Color.lumenAccent.opacity(0.25) : Color.white.opacity(0.08), in: Capsule())
                        .foregroundStyle(aspect == option ? Color.lumenAccent : Color.primary)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }

            AdjustmentSlider(
                adjustment: .straighten,
                value: model.binding(\.straighten),
                onEditingChanged: model.trackEditing,
                onReset: { model.perform { $0.straighten = 0 } }
            )
            .padding(.horizontal, 20)

            HStack(spacing: 36) {
                Button {
                    model.rotate(clockwise: false)
                    aspect = .free
                } label: {
                    Label("Rotate Left", systemImage: "rotate.left")
                }
                Button {
                    model.rotate(clockwise: true)
                    aspect = .free
                } label: {
                    Label("Rotate Right", systemImage: "rotate.right")
                }
                Button {
                    model.flip()
                } label: {
                    Label("Flip", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                }
                Button("Reset") {
                    model.perform { $0.resetGeometry() }
                    aspect = .free
                }
                .font(.subheadline)
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 16)
    }
}

struct HistogramView: View {
    let histogram: Histogram

    var body: some View {
        Canvas { context, size in
            context.blendMode = .plusLighter
            let channels: [([Float], Color)] = [
                (histogram.red, .red),
                (histogram.green, .green),
                (histogram.blue, .blue),
            ]
            for (values, color) in channels {
                context.fill(path(for: values, in: size), with: .color(color.opacity(0.6)))
            }
        }
    }

    private func path(for values: [Float], in size: CGSize) -> Path {
        Path { path in
            guard values.count > 1 else { return }
            path.move(to: CGPoint(x: 0, y: size.height))
            for (index, value) in values.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                path.addLine(to: CGPoint(x: x, y: size.height * (1 - CGFloat(value))))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
    }
}
