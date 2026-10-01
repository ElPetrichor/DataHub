import Foundation

/// The editor's tool tabs.
enum EditTool: String, CaseIterable, Identifiable {
    case presets, light, color, effects, detail, geometry

    var id: Self { self }

    var title: String {
        switch self {
        case .presets: "Presets"
        case .light: "Light"
        case .color: "Color"
        case .effects: "Effects"
        case .detail: "Detail"
        case .geometry: "Crop"
        }
    }

    var systemImage: String {
        switch self {
        case .presets: "square.stack"
        case .light: "sun.max"
        case .color: "thermometer.medium"
        case .effects: "sparkles"
        case .detail: "triangle.lefthalf.filled"
        case .geometry: "crop.rotate"
        }
    }

    var adjustments: [Adjustment] {
        switch self {
        case .light: [.exposure, .contrast, .highlights, .shadows, .whites, .blacks]
        case .color: [.temperature, .tint, .vibrance, .saturation]
        case .effects: [.clarity, .vignette, .grain]
        case .detail: [.sharpening, .noiseReduction]
        case .presets, .geometry: []
        }
    }

    /// Whether any control in this tab differs from its default, shown as a dot in the tool bar.
    func isModified(in settings: EditSettings) -> Bool {
        switch self {
        case .presets:
            false
        case .geometry:
            settings.quarterTurns != 0 || settings.flipped || settings.straighten != 0 || settings.crop != .full
        case .color:
            settings.monochrome || adjustments.contains { settings[keyPath: $0.keyPath] != 0 }
        default:
            adjustments.contains { settings[keyPath: $0.keyPath] != 0 }
        }
    }
}

/// Describes one slider: which setting it drives, its range and how its value reads.
struct Adjustment: Identifiable {
    enum Format { case signed, ev, degrees }
    enum Track { case plain, temperature, tint, saturation }

    let title: String
    let keyPath: WritableKeyPath<EditSettings, Double>
    var range: ClosedRange<Double> = -100...100
    var step: Double = 1
    var format: Format = .signed
    var track: Track = .plain

    var id: String { title }

    func formatted(_ value: Double) -> String {
        switch format {
        case .ev:
            return value == 0 ? "0.00" : String(format: "%+.2f", value)
        case .degrees:
            return value == 0 ? "0.0°" : String(format: "%+.1f°", value)
        case .signed:
            let rounded = Int(value.rounded())
            return rounded > 0 ? "+\(rounded)" : "\(rounded)"
        }
    }

    static let exposure = Adjustment(title: "Exposure", keyPath: \.exposure, range: -4...4, step: 0.05, format: .ev)
    static let contrast = Adjustment(title: "Contrast", keyPath: \.contrast)
    static let highlights = Adjustment(title: "Highlights", keyPath: \.highlights)
    static let shadows = Adjustment(title: "Shadows", keyPath: \.shadows)
    static let whites = Adjustment(title: "Whites", keyPath: \.whites)
    static let blacks = Adjustment(title: "Blacks", keyPath: \.blacks)

    static let temperature = Adjustment(title: "Temperature", keyPath: \.temperature, track: .temperature)
    static let tint = Adjustment(title: "Tint", keyPath: \.tint, track: .tint)
    static let vibrance = Adjustment(title: "Vibrance", keyPath: \.vibrance, track: .saturation)
    static let saturation = Adjustment(title: "Saturation", keyPath: \.saturation, track: .saturation)

    static let clarity = Adjustment(title: "Clarity", keyPath: \.clarity)
    static let vignette = Adjustment(title: "Vignette", keyPath: \.vignette)
    static let grain = Adjustment(title: "Grain", keyPath: \.grain, range: 0...100)

    static let sharpening = Adjustment(title: "Sharpening", keyPath: \.sharpening, range: 0...100)
    static let noiseReduction = Adjustment(title: "Noise Reduction", keyPath: \.noiseReduction, range: 0...100)

    static let straighten = Adjustment(title: "Straighten", keyPath: \.straighten, range: -45...45, step: 0.1, format: .degrees)
}

/// Aspect ratios offered by the crop tool.
enum CropAspect: String, CaseIterable, Identifiable {
    case free, original, square, fourFive, threeTwo, sixteenNine, nineSixteen

    var id: Self { self }

    var title: String {
        switch self {
        case .free: "Free"
        case .original: "Original"
        case .square: "1:1"
        case .fourFive: "4:5"
        case .threeTwo: "3:2"
        case .sixteenNine: "16:9"
        case .nineSixteen: "9:16"
        }
    }

    /// Width ÷ height in pixels, or nil for a free crop.
    func ratio(original: Double) -> Double? {
        switch self {
        case .free: nil
        case .original: original
        case .square: 1
        case .fourFive: 4.0 / 5.0
        case .threeTwo: 3.0 / 2.0
        case .sixteenNine: 16.0 / 9.0
        case .nineSixteen: 9.0 / 16.0
        }
    }
}
