import Photos
import SwiftUI

/// Loads and shows a photo, rendered with its Lumen edits when it has any.
struct ThumbnailImage: View {
    let asset: PHAsset
    var settings: EditSettings?
    var pointSize: CGFloat
    var contentMode: ContentMode = .fill

    @Environment(PhotoLibrary.self) private var library
    @Environment(\.displayScale) private var displayScale
    @State private var image: Image?

    private struct LoadKey: Equatable {
        let assetID: String
        let settings: EditSettings?
        let pixels: CGFloat
    }

    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(Color.white.opacity(0.06))
            }
        }
        .task(id: LoadKey(assetID: asset.localIdentifier, settings: settings, pixels: pointSize * displayScale)) {
            // Fill mode crops edited images of any aspect ratio, so ask for a little extra resolution.
            let pixels = pointSize * displayScale * (contentMode == .fill ? 1.5 : 1)
            // Keep showing the previous image until the new one is ready, so edits don't flicker.
            let loaded = await library.image(for: asset, settings: settings, pixelSize: pixels)
            if let loaded, !Task.isCancelled { image = loaded }
        }
    }
}

struct ThumbnailCell: View {
    let asset: PHAsset
    let meta: AssetMeta?
    var pointSize: CGFloat
    var isSelecting = false
    var isSelected = false

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                ThumbnailImage(asset: asset, settings: meta?.edit, pointSize: pointSize)
            }
            .clipped()
            .contentShape(Rectangle())
            .opacity(meta?.flag == .reject ? 0.35 : 1)
            .overlay(alignment: .bottom) { badges }
            .overlay(alignment: .topTrailing) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, isSelected ? Color.lumenAccent : Color.black.opacity(0.3))
                        .padding(5)
                }
            }
            .overlay {
                if isSelected {
                    Rectangle().strokeBorder(Color.lumenAccent, lineWidth: 3)
                }
            }
    }

    @ViewBuilder
    private var badges: some View {
        if let meta, meta.rating > 0 || meta.flag != .unflagged || meta.colorLabel != .unlabeled || meta.isEdited {
            HStack(spacing: 3) {
                if meta.flag != .unflagged {
                    Image(systemName: meta.flag.systemImage)
                        .foregroundStyle(meta.flag == .reject ? Color.red : Color.white)
                }
                if meta.rating > 0 {
                    Text(String(repeating: "★", count: meta.rating))
                }
                Spacer(minLength: 0)
                if meta.isEdited {
                    Image(systemName: meta.hasUnsavedEdits ? "slider.horizontal.3" : "checkmark.seal.fill")
                }
                if meta.colorLabel != .unlabeled {
                    Circle()
                        .fill(meta.colorLabel.color)
                        .frame(width: 7, height: 7)
                }
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom))
        }
    }
}
