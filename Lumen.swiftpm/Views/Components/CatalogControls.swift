import SwiftData
import SwiftUI

/// Gives `content` the catalog entry for one photo and re-renders when it changes.
struct MetaReader<Content: View>: View {
    @Query private var metas: [AssetMeta]
    private let content: (AssetMeta?) -> Content

    init(assetID: String, @ViewBuilder content: @escaping (AssetMeta?) -> Content) {
        _metas = Query(filter: #Predicate<AssetMeta> { $0.assetID == assetID })
        self.content = content
    }

    var body: some View {
        content(metas.first)
    }
}

struct RatingControl: View {
    let rating: Int
    var onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    // Tapping the current rating clears it.
                    onChange(star == rating ? 0 : star)
                } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .foregroundStyle(star <= rating ? Color.yellow : Color.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .font(.title3)
        .sensoryFeedback(.selection, trigger: rating)
    }
}

struct FlagControl: View {
    let flag: Flag
    var onChange: (Flag) -> Void

    var body: some View {
        HStack(spacing: 22) {
            Button {
                onChange(flag == .reject ? .unflagged : .reject)
            } label: {
                Image(systemName: "flag.slash.fill")
                    .foregroundStyle(flag == .reject ? Color.red : Color.white.opacity(0.6))
            }
            Button {
                onChange(flag == .pick ? .unflagged : .pick)
            } label: {
                Image(systemName: flag == .pick ? "flag.fill" : "flag")
                    .foregroundStyle(flag == .pick ? Color.white : Color.white.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .font(.title3)
        .sensoryFeedback(.selection, trigger: flag)
    }
}

struct ColorLabelControl: View {
    let label: ColorLabel
    var onChange: (ColorLabel) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ColorLabel.labels) { option in
                Button {
                    onChange(option == label ? .unlabeled : option)
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(.white, lineWidth: option == label ? 2 : 0))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
            }
        }
    }
}

/// Rating, flag and color label menus, shared by context menus and the selection bar.
struct MarkMenus: View {
    var onChange: (CatalogChange) -> Void

    var body: some View {
        Menu("Rating", systemImage: "star") {
            ForEach(0...5, id: \.self) { rating in
                Button(rating == 0 ? "No Rating" : String(repeating: "★", count: rating)) {
                    onChange(.rating(rating))
                }
            }
        }
        Menu("Flag", systemImage: "flag") {
            ForEach(Flag.allCases.reversed()) { flag in
                Button(flag.title, systemImage: flag.systemImage) { onChange(.flag(flag)) }
            }
        }
        Menu("Color Label", systemImage: "circle.fill") {
            ForEach(ColorLabel.allCases) { label in
                Button(label.title) { onChange(.colorLabel(label)) }
            }
        }
    }
}

/// Built-in and user presets as menu items.
struct PresetMenu: View {
    @Query(sort: \UserPreset.createdAt) private var userPresets: [UserPreset]
    var onApply: (EditSettings) -> Void

    var body: some View {
        Menu("Apply Preset", systemImage: "square.stack") {
            ForEach(Preset.builtIn) { preset in
                Button(preset.name) { onApply(preset.settings) }
            }
            if !userPresets.isEmpty {
                Divider()
                ForEach(userPresets) { preset in
                    Button(preset.name) { onApply(preset.settings) }
                }
            }
        }
    }
}
