import Photos
import SwiftData
import SwiftUI

/// Full-screen viewer for culling: swipe between photos, zoom, and rate / flag / label each one.
struct LoupeView: View {
    let assets: [PHAsset]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var currentID: String?
    @State private var isZoomed = false
    @State private var showsChrome = true
    @State private var showsInfo = false
    @State private var editTarget: EditTarget?

    init(target: LoupeTarget) {
        assets = target.assets
        _currentID = State(initialValue: target.startID)
    }

    private var currentIndex: Int? {
        assets.firstIndex { $0.localIdentifier == currentID }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        LoupePage(asset: asset, isZoomed: $isZoomed) {
                            withAnimation(.easeInOut(duration: 0.2)) { showsChrome.toggle() }
                        }
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(asset.localIdentifier)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID)
            .scrollIndicators(.hidden)
            .scrollDisabled(isZoomed)
            .onAppear {
                if let currentID { proxy.scrollTo(currentID) }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .top) {
            if showsChrome { topBar }
        }
        .overlay(alignment: .bottom) {
            if showsChrome, let currentID { LoupeControls(assetID: currentID) }
        }
        .sheet(isPresented: $showsInfo) {
            if let currentIndex {
                InfoPanel(asset: assets[currentIndex])
                    .presentationDetents([.medium, .large])
            }
        }
        .coverPresentation(item: $editTarget) { target in
            EditorView(target: target)
        }
    }

    private var topBar: some View {
        HStack(spacing: 20) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
            }
            Spacer()
            if let currentIndex {
                Text("\(currentIndex + 1) of \(assets.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showsInfo = true
            } label: {
                Image(systemName: "info.circle")
            }
            Button {
                guard let currentIndex else { return }
                let asset = assets[currentIndex]
                editTarget = EditTarget(asset: asset, settings: modelContext.existingMeta(for: asset.localIdentifier)?.edit ?? .identity)
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
        }
        .font(.title3)
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
    }
}

private struct LoupePage: View {
    let asset: PHAsset
    @Binding var isZoomed: Bool
    var onTap: () -> Void

    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    var body: some View {
        MetaReader(assetID: asset.localIdentifier) { meta in
            ThumbnailImage(asset: asset, settings: meta?.edit, pointSize: 1100, contentMode: .fit)
        }
        .scaleEffect(scale)
        .offset(offset)
        .contentShape(Rectangle())
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    scale = min(max(committedScale * value.magnification, 1), 6)
                }
                .onEnded { _ in
                    committedScale = scale
                    if scale <= 1.01 { resetZoom() } else { isZoomed = true }
                }
        )
        // Panning only exists while zoomed; otherwise horizontal drags page between photos.
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: committedOffset.width + value.translation.width,
                        height: committedOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in committedOffset = offset },
            including: scale > 1 ? .all : .subviews
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring(duration: 0.3)) {
                if scale > 1 {
                    resetZoom()
                } else {
                    scale = 2.5
                    committedScale = 2.5
                    isZoomed = true
                }
            }
        }
        .onTapGesture(perform: onTap)
        .onDisappear(perform: resetZoom)
    }

    private func resetZoom() {
        scale = 1
        committedScale = 1
        offset = .zero
        committedOffset = .zero
        isZoomed = false
    }
}

private struct LoupeControls: View {
    let assetID: String
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        MetaReader(assetID: assetID) { meta in
            VStack(spacing: 14) {
                RatingControl(rating: meta?.rating ?? 0) { update(.rating($0)) }
                HStack(spacing: 32) {
                    FlagControl(flag: meta?.flag ?? .unflagged) { update(.flag($0)) }
                    ColorLabelControl(label: meta?.colorLabel ?? .unlabeled) { update(.colorLabel($0)) }
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
        }
    }

    private func update(_ change: CatalogChange) {
        modelContext.apply(change, to: [assetID])
    }
}
