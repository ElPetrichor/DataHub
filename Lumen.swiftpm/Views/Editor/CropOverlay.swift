import SwiftUI

/// Draggable crop rectangle drawn over the uncropped preview.
struct CropOverlay: View {
    @Binding var crop: CropRect
    /// Where the image is drawn, in this view's coordinates.
    let frame: CGRect
    /// Locked width ÷ height in pixels, or nil for a free crop.
    let aspect: Double?
    var onEditingChanged: (Bool) -> Void

    @State private var dragStart: CropRect?

    private enum Handle: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight, move

        var isLeft: Bool { self == .topLeft || self == .bottomLeft }
        var isTop: Bool { self == .topLeft || self == .topRight }
    }

    private var cropFrame: CGRect {
        CGRect(
            x: frame.minX + crop.x * frame.width,
            y: frame.minY + crop.y * frame.height,
            width: crop.width * frame.width,
            height: crop.height * frame.height
        )
    }

    var body: some View {
        let rect = cropFrame
        ZStack {
            // Dim everything outside the crop.
            Path { path in
                path.addRect(frame)
                path.addRect(rect)
            }
            .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))

            // Rule-of-thirds grid.
            Path { path in
                for i in 1...2 {
                    let x = rect.minX + rect.width * CGFloat(i) / 3
                    let y = rect.minY + rect.height * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: rect.minY))
                    path.addLine(to: CGPoint(x: x, y: rect.maxY))
                    path.move(to: CGPoint(x: rect.minX, y: y))
                    path.addLine(to: CGPoint(x: rect.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 0.5)

            Rectangle()
                .path(in: rect)
                .stroke(Color.white, lineWidth: 1.5)

            Color.clear
                .contentShape(Rectangle())
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .gesture(drag(.move))

            ForEach([Handle.topLeft, .topRight, .bottomLeft, .bottomRight], id: \.self) { handle in
                CornerMark(handle: handle)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .position(x: handle.isLeft ? rect.minX : rect.maxX, y: handle.isTop ? rect.minY : rect.maxY)
                    .gesture(drag(handle))
            }
        }
    }

    private func drag(_ handle: Handle) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = crop
                    onEditingChanged(true)
                }
                guard let start = dragStart, frame.width > 0, frame.height > 0 else { return }
                crop = adjusted(
                    start,
                    handle: handle,
                    dx: value.translation.width / frame.width,
                    dy: value.translation.height / frame.height
                )
            }
            .onEnded { _ in
                dragStart = nil
                onEditingChanged(false)
            }
    }

    private func adjusted(_ start: CropRect, handle: Handle, dx: Double, dy: Double) -> CropRect {
        let minimumSize = 0.08
        if handle == .move {
            var moved = start
            moved.x = min(max(0, start.x + dx), 1 - start.width)
            moved.y = min(max(0, start.y + dy), 1 - start.height)
            return moved
        }

        // The opposite corner stays put.
        var left = start.x, top = start.y
        var right = start.x + start.width, bottom = start.y + start.height
        if handle.isLeft { left = min(max(0, left + dx), right - minimumSize) } else { right = min(max(left + minimumSize, right + dx), 1) }
        if handle.isTop { top = min(max(0, top + dy), bottom - minimumSize) } else { bottom = min(max(top + minimumSize, bottom + dy), 1) }

        if let aspect {
            // Width ÷ height in normalized units, given the image's on-screen proportions.
            let relative = aspect * frame.height / frame.width
            var width = right - left
            var height = width / relative
            let availableHeight = handle.isTop ? bottom : 1 - top
            if height > availableHeight {
                height = availableHeight
                width = height * relative
            }
            if handle.isLeft { left = right - width } else { right = left + width }
            if handle.isTop { top = bottom - height } else { bottom = top + height }
        }
        return CropRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    private struct CornerMark: View {
        let handle: Handle

        var body: some View {
            Path { path in
                let length: CGFloat = 16
                let center = CGPoint(x: 22, y: 22)
                let horizontal: CGFloat = handle.isLeft ? 1 : -1
                let vertical: CGFloat = handle.isTop ? 1 : -1
                path.move(to: CGPoint(x: center.x + horizontal * length, y: center.y))
                path.addLine(to: center)
                path.addLine(to: CGPoint(x: center.x, y: center.y + vertical * length))
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .square))
        }
    }
}
