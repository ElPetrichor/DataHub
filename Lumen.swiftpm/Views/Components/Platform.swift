import SwiftUI

// Small shims so the views read the same on iOS and macOS. Swift Playgrounds builds for iOS;
// the macOS branches only exist so the sources can be type-checked with the macOS SDK.

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}

extension View {
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Full-screen on iOS, a sheet elsewhere.
    @ViewBuilder
    func coverPresentation<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, content: content)
        #else
        sheet(item: item, content: content)
        #endif
    }

    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Something Went Wrong",
            isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }

    func progressOverlay(_ text: String?) -> some View {
        overlay {
            if let text {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(text).font(.callout)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}

extension CGRect {
    /// The largest rectangle with the given aspect ratio (width ÷ height) centered in this one.
    func fitting(aspect: CGFloat) -> CGRect {
        guard aspect > 0, width > 0, height > 0 else { return self }
        var size = CGSize(width: width, height: width / aspect)
        if size.height > height { size = CGSize(width: height * aspect, height: height) }
        return CGRect(x: midX - size.width / 2, y: midY - size.height / 2, width: size.width, height: size.height)
    }
}
