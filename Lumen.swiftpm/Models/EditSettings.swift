import Foundation

/// A non-destructive set of develop adjustments.
///
/// Values are stored in slider units (mostly -100...100, exposure in EV) and
/// translated into Core Image parameters by `ImageProcessor`. Edits always
/// apply to the unadjusted original, so the same settings render identically
/// for thumbnails, the editor preview and full-size exports.
struct EditSettings: Codable, Hashable, Sendable {
    // Light
    var exposure: Double = 0
    var contrast: Double = 0
    var highlights: Double = 0
    var shadows: Double = 0
    var whites: Double = 0
    var blacks: Double = 0

    // Color
    var temperature: Double = 0
    var tint: Double = 0
    var vibrance: Double = 0
    var saturation: Double = 0
    var monochrome = false

    // Effects
    var clarity: Double = 0
    var vignette: Double = 0
    var grain: Double = 0

    // Detail
    var sharpening: Double = 0
    var noiseReduction: Double = 0

    // Geometry
    /// Clockwise 90° turns.
    var quarterTurns = 0
    var flipped = false
    /// Degrees; the frame is auto-cropped so no empty corners show.
    var straighten: Double = 0
    var crop = CropRect.full

    static let identity = EditSettings()

    var isIdentity: Bool { self == .identity }

    /// Copies the look (light, color, effects, detail) of `other` while keeping this photo's geometry.
    /// Used for presets and pasting settings between photos.
    func withLook(of other: EditSettings) -> EditSettings {
        var result = other
        result.quarterTurns = quarterTurns
        result.flipped = flipped
        result.straighten = straighten
        result.crop = crop
        return result
    }

    mutating func resetGeometry() {
        quarterTurns = 0
        flipped = false
        straighten = 0
        crop = .full
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        // Stable output lets the catalog compare saved and current edits byte for byte.
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    static let decoder = JSONDecoder()
}

extension EditSettings {
    /// Tolerant decoding: settings written by older versions (missing keys) still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        let d = EditSettings.identity
        self.init(
            exposure: value(.exposure, d.exposure),
            contrast: value(.contrast, d.contrast),
            highlights: value(.highlights, d.highlights),
            shadows: value(.shadows, d.shadows),
            whites: value(.whites, d.whites),
            blacks: value(.blacks, d.blacks),
            temperature: value(.temperature, d.temperature),
            tint: value(.tint, d.tint),
            vibrance: value(.vibrance, d.vibrance),
            saturation: value(.saturation, d.saturation),
            monochrome: value(.monochrome, d.monochrome),
            clarity: value(.clarity, d.clarity),
            vignette: value(.vignette, d.vignette),
            grain: value(.grain, d.grain),
            sharpening: value(.sharpening, d.sharpening),
            noiseReduction: value(.noiseReduction, d.noiseReduction),
            quarterTurns: value(.quarterTurns, d.quarterTurns),
            flipped: value(.flipped, d.flipped),
            straighten: value(.straighten, d.straighten),
            crop: value(.crop, d.crop)
        )
    }
}

/// A crop in normalized coordinates (0...1) of the straightened image, origin at the top left.
struct CropRect: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let full = CropRect(x: 0, y: 0, width: 1, height: 1)
}
