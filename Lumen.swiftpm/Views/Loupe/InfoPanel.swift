import CoreLocation
import ImageIO
import Photos
import SwiftUI

/// File and camera metadata for one photo.
struct InfoPanel: View {
    let asset: PHAsset
    @State private var info: PhotoInfo?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("File", info?.fileName)
                    row("Date", asset.creationDate?.formatted(date: .abbreviated, time: .shortened))
                    row("Dimensions", dimensions)
                    if let coordinate = asset.location?.coordinate {
                        row("Location", String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude))
                    }
                }
                Section("Camera") {
                    if let info {
                        row("Camera", info.camera)
                        row("Lens", info.lens)
                        row("Exposure", info.exposureSummary)
                    } else {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Info")
            .inlineNavigationTitle()
        }
        .task { info = await PhotoInfo.load(for: asset) }
    }

    private var dimensions: String {
        let megapixels = Double(asset.pixelWidth * asset.pixelHeight) / 1_000_000
        return "\(asset.pixelWidth) × \(asset.pixelHeight) · \(String(format: "%.1f", megapixels)) MP"
    }

    @ViewBuilder
    private func row(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            LabeledContent(title, value: value)
        }
    }
}

struct PhotoInfo {
    var fileName: String?
    var camera: String?
    var lens: String?
    var aperture: Double?
    var shutterSpeed: Double?
    var iso: Int?
    var focalLength: Double?

    var exposureSummary: String? {
        var parts: [String] = []
        if let focalLength { parts.append("\(Int(focalLength.rounded())) mm") }
        if let aperture { parts.append(String(format: "ƒ/%.1f", aperture)) }
        if let shutterSpeed {
            parts.append(shutterSpeed < 1 ? "1/\(Int((1 / shutterSpeed).rounded())) s" : String(format: "%.1f s", shutterSpeed))
        }
        if let iso { parts.append("ISO \(iso)") }
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }

    static func load(for asset: PHAsset) async -> PhotoInfo {
        var info = PhotoInfo()
        info.fileName = PHAssetResource.assetResources(for: asset).first?.originalFilename
        guard
            let data = try? await ImageSource.originalData(for: asset),
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else { return info }

        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        let make = tiff[kCGImagePropertyTIFFMake as String] as? String
        let model = tiff[kCGImagePropertyTIFFModel as String] as? String
        // Many models already start with the make ("Canon EOS R6"); don't repeat it.
        if let make, let model, !model.hasPrefix(make) {
            info.camera = "\(make) \(model)"
        } else {
            info.camera = model ?? make
        }
        info.lens = exif[kCGImagePropertyExifLensModel as String] as? String
        info.aperture = exif[kCGImagePropertyExifFNumber as String] as? Double
        info.shutterSpeed = exif[kCGImagePropertyExifExposureTime as String] as? Double
        info.iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int])?.first
        info.focalLength = exif[kCGImagePropertyExifFocalLength as String] as? Double
        return info
    }
}
