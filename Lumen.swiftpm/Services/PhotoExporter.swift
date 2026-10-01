import CoreImage
import CoreTransferable
import Photos
import UniformTypeIdentifiers

/// Writes Lumen edits back to the Photos library.
enum PhotoExporter {
    static let formatIdentifier = "com.elpetrichor.lumen.develop"
    static let formatVersion = "1"

    /// Saves each edit onto its photo, non-destructively: Photos keeps the original and can revert it.
    /// Identity settings revert the photo instead. All changes go through a single Photos permission prompt.
    static func applyToOriginals(_ items: [(asset: PHAsset, settings: EditSettings)]) async throws {
        var edits: [(PHAsset, PHContentEditingOutput)] = []
        var reverts: [PHAsset] = []
        for item in items {
            if item.settings.isIdentity {
                reverts.append(item.asset)
            } else {
                let input = try await contentEditingInput(for: item.asset)
                edits.append((item.asset, try await render(item.settings, input: input)))
            }
        }
        guard !edits.isEmpty || !reverts.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            for (asset, output) in edits {
                PHAssetChangeRequest(for: asset).contentEditingOutput = output
            }
            for asset in reverts {
                PHAssetChangeRequest(for: asset).revertAssetContentToOriginal()
            }
        }
    }

    /// Adds the edited photo to the library as a new photo, leaving the original untouched.
    static func saveCopy(of asset: PHAsset, settings: EditSettings) async throws {
        let jpeg = try await renderJPEG(asset: asset, settings: settings)
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: jpeg, options: nil)
            request.creationDate = asset.creationDate
            request.location = asset.location
        }
    }

    /// Renders the full-resolution edit as JPEG data.
    static func renderJPEG(asset: PHAsset, settings: EditSettings) async throws -> Data {
        let data = try await ImageSource.originalData(for: asset)
        return try await Task.detached(priority: .userInitiated) {
            guard let original = ImageSource.fullImage(data) else { throw LumenError.imageUnavailable }
            let processor = ImageProcessor.shared
            guard let jpeg = processor.jpegData(processor.apply(settings, to: original), metadata: original.properties) else {
                throw LumenError.renderFailed
            }
            return jpeg
        }.value
    }

    private static func contentEditingInput(for asset: PHAsset) async throws -> PHContentEditingInput {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true
        // Claiming every adjustment format makes Photos hand over the original, which is what Lumen edits.
        options.canHandleAdjustmentData = { _ in true }
        return try await withCheckedThrowingContinuation { continuation in
            asset.requestContentEditingInput(with: options) { input, info in
                if let input {
                    continuation.resume(returning: input)
                } else {
                    continuation.resume(throwing: (info[PHContentEditingInputErrorKey] as? Error) ?? LumenError.imageUnavailable)
                }
            }
        }
    }

    private static func render(_ settings: EditSettings, input: PHContentEditingInput) async throws -> PHContentEditingOutput {
        try await Task.detached(priority: .userInitiated) {
            guard let url = input.fullSizeImageURL, let source = CIImage(contentsOf: url) else {
                throw LumenError.imageUnavailable
            }
            let original = source.oriented(forExifOrientation: input.fullSizeImageOrientation)
            let processor = ImageProcessor.shared
            guard let jpeg = processor.jpegData(processor.apply(settings, to: original), metadata: source.properties) else {
                throw LumenError.renderFailed
            }
            let output = PHContentEditingOutput(contentEditingInput: input)
            output.adjustmentData = PHAdjustmentData(
                formatIdentifier: formatIdentifier,
                formatVersion: formatVersion,
                data: try EditSettings.encoder.encode(settings)
            )
            try jpeg.write(to: output.renderedContentURL, options: .atomic)
            return output
        }.value
    }
}

/// An edited photo for the share sheet. It's rendered at full size only when the user picks a destination.
struct ExportedPhoto: Transferable {
    let assetID: String
    let settings: EditSettings

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { photo in
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [photo.assetID], options: nil).firstObject else {
                throw LumenError.imageUnavailable
            }
            return try await PhotoExporter.renderJPEG(asset: asset, settings: photo.settings)
        }
    }
}
