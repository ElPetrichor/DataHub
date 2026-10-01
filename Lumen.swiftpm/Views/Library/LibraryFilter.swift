import SwiftUI

struct LibraryFilter: Equatable {
    enum FlagFilter: String, CaseIterable, Identifiable {
        case any, picked, unflagged, rejected, notRejected

        var id: Self { self }

        var title: String {
            switch self {
            case .any: "Any Flag"
            case .picked: "Picks"
            case .unflagged: "Unflagged"
            case .rejected: "Rejects"
            case .notRejected: "Hide Rejects"
            }
        }
    }

    var flag = FlagFilter.any
    var minimumRating = 0
    var colorLabel: ColorLabel?
    var editedOnly = false

    var isActive: Bool { self != LibraryFilter() }

    func includes(_ meta: AssetMeta?) -> Bool {
        let flag = meta?.flag ?? .unflagged
        switch self.flag {
        case .any: break
        case .picked: if flag != .pick { return false }
        case .unflagged: if flag != .unflagged { return false }
        case .rejected: if flag != .reject { return false }
        case .notRejected: if flag == .reject { return false }
        }
        if (meta?.rating ?? 0) < minimumRating { return false }
        if let colorLabel, (meta?.colorLabel ?? .unlabeled) != colorLabel { return false }
        if editedOnly, meta?.isEdited != true { return false }
        return true
    }
}

/// Lightroom-style filter strip above the grid.
struct FilterBar: View {
    @Binding var filter: LibraryFilter
    let shown: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Menu {
                        Picker("Flag", selection: $filter.flag) {
                            ForEach(LibraryFilter.FlagFilter.allCases) { Text($0.title).tag($0) }
                        }
                    } label: {
                        FilterChip(
                            title: filter.flag == .any ? "Flag" : filter.flag.title,
                            systemImage: "flag",
                            isActive: filter.flag != .any
                        )
                    }

                    Menu {
                        Picker("Rating", selection: $filter.minimumRating) {
                            Text("Any Rating").tag(0)
                            ForEach(1...5, id: \.self) { rating in
                                Text(String(repeating: "★", count: rating) + (rating < 5 ? " & up" : "")).tag(rating)
                            }
                        }
                    } label: {
                        FilterChip(
                            title: filter.minimumRating == 0 ? "Rating" : "≥ \(filter.minimumRating)★",
                            systemImage: "star",
                            isActive: filter.minimumRating > 0
                        )
                    }

                    Menu {
                        Picker("Color Label", selection: $filter.colorLabel) {
                            Text("Any Label").tag(ColorLabel?.none)
                            ForEach(ColorLabel.allCases) { Text($0.title).tag(ColorLabel?.some($0)) }
                        }
                    } label: {
                        FilterChip(
                            title: filter.colorLabel?.title ?? "Label",
                            systemImage: "circle.fill",
                            isActive: filter.colorLabel != nil,
                            iconColor: filter.colorLabel?.color
                        )
                    }

                    Button {
                        filter.editedOnly.toggle()
                    } label: {
                        FilterChip(title: "Edited", systemImage: "slider.horizontal.3", isActive: filter.editedOnly)
                    }
                    .buttonStyle(.plain)

                    if filter.isActive {
                        Button("Clear") { filter = LibraryFilter() }
                            .font(.subheadline)
                    }
                }
                .padding(.leading)
            }
            Text(filter.isActive ? "\(shown) of \(total)" : "\(total) photos")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.trailing)
        }
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct FilterChip: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    var iconColor: Color?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .foregroundStyle(iconColor ?? (isActive ? Color.lumenAccent : Color.secondary))
            Text(title)
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.lumenAccent.opacity(0.2) : Color.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(isActive ? Color.lumenAccent.opacity(0.6) : .clear))
        .foregroundStyle(.primary)
    }
}
