import Foundation
import SwiftData
import SwiftUI

enum Flag: Int, CaseIterable, Identifiable {
    case reject = -1, unflagged = 0, pick = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .pick: "Pick"
        case .reject: "Reject"
        case .unflagged: "Unflagged"
        }
    }

    var systemImage: String {
        switch self {
        case .pick: "flag.fill"
        case .reject: "flag.slash.fill"
        case .unflagged: "flag"
        }
    }
}

enum ColorLabel: Int, CaseIterable, Identifiable {
    case unlabeled, red, yellow, green, blue, purple

    var id: Int { rawValue }

    static let labels = allCases.filter { $0 != .unlabeled }

    var title: String {
        switch self {
        case .unlabeled: "None"
        case .red: "Red"
        case .yellow: "Yellow"
        case .green: "Green"
        case .blue: "Blue"
        case .purple: "Purple"
        }
    }

    var color: Color {
        switch self {
        case .unlabeled: .gray
        case .red: .red
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        }
    }
}

/// Lumen's catalog entry for one photo in the Photos library: culling marks plus develop settings.
@Model
final class AssetMeta {
    @Attribute(.unique) var assetID: String
    var rating: Int = 0
    var flagValue: Int = 0
    var colorLabelValue: Int = 0
    /// Encoded `EditSettings`; nil when the photo is unedited.
    var editData: Data?
    /// The edit last written to the Photos library, used to tell which photos have unsaved edits.
    var savedEditData: Data?
    var modifiedAt: Date = Date.now

    init(assetID: String) {
        self.assetID = assetID
    }

    var flag: Flag {
        get { Flag(rawValue: flagValue) ?? .unflagged }
        set { flagValue = newValue.rawValue }
    }

    var colorLabel: ColorLabel {
        get { ColorLabel(rawValue: colorLabelValue) ?? .unlabeled }
        set { colorLabelValue = newValue.rawValue }
    }

    var edit: EditSettings {
        get { editData.flatMap { try? EditSettings.decoder.decode(EditSettings.self, from: $0) } ?? .identity }
        set {
            editData = newValue.isIdentity ? nil : try? EditSettings.encoder.encode(newValue)
            modifiedAt = .now
        }
    }

    var isEdited: Bool { editData != nil }

    var hasUnsavedEdits: Bool { editData != savedEditData }
}

@Model
final class UserPreset {
    var name: String
    var settingsData: Data
    var createdAt: Date

    init(name: String, settings: EditSettings) {
        self.name = name
        self.settingsData = (try? EditSettings.encoder.encode(settings)) ?? Data()
        self.createdAt = .now
    }

    var settings: EditSettings {
        (try? EditSettings.decoder.decode(EditSettings.self, from: settingsData)) ?? .identity
    }
}

/// A change to the catalog that can be applied to one or many photos at once.
enum CatalogChange {
    case rating(Int)
    case flag(Flag)
    case colorLabel(ColorLabel)
    case look(EditSettings)
    case resetEdits

    func apply(to meta: AssetMeta) {
        switch self {
        case .rating(let rating): meta.rating = rating
        case .flag(let flag): meta.flag = flag
        case .colorLabel(let label): meta.colorLabel = label
        case .look(let look): meta.edit = meta.edit.withLook(of: look)
        case .resetEdits: meta.edit = .identity
        }
    }
}

extension ModelContext {
    func existingMeta(for assetID: String) -> AssetMeta? {
        var descriptor = FetchDescriptor<AssetMeta>(predicate: #Predicate { $0.assetID == assetID })
        descriptor.fetchLimit = 1
        return try? fetch(descriptor).first
    }

    /// Returns the catalog entry for a photo, creating it on first use.
    func meta(for assetID: String) -> AssetMeta {
        if let existing = existingMeta(for: assetID) { return existing }
        let meta = AssetMeta(assetID: assetID)
        insert(meta)
        return meta
    }

    func apply(_ change: CatalogChange, to assetIDs: some Sequence<String>) {
        for id in assetIDs { change.apply(to: meta(for: id)) }
    }

    /// Records that the current edits of these photos were written to the Photos library.
    func markSaved(_ assetIDs: some Sequence<String>) {
        for id in assetIDs {
            if let meta = existingMeta(for: id) { meta.savedEditData = meta.editData }
        }
    }
}
