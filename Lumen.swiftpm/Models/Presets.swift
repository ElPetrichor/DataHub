import Foundation

/// A built-in look. Presets only carry light, color, effects and detail; applying one keeps the photo's crop.
struct Preset: Identifiable, Hashable {
    let name: String
    let settings: EditSettings

    var id: String { name }

    static let builtIn: [Preset] = [
        Preset(name: "Natural", settings: EditSettings(contrast: 8, vibrance: 15, clarity: 10)),
        Preset(name: "Vivid", settings: EditSettings(contrast: 20, highlights: -15, shadows: 10, vibrance: 35, saturation: 8, clarity: 15)),
        Preset(name: "Bright & Airy", settings: EditSettings(exposure: 0.35, contrast: -10, highlights: -30, shadows: 30, whites: 10, temperature: 6, vibrance: 10)),
        Preset(name: "Golden Hour", settings: EditSettings(exposure: 0.1, highlights: -25, shadows: 15, temperature: 30, tint: 8, vibrance: 20, vignette: -15)),
        Preset(name: "Moody", settings: EditSettings(exposure: -0.3, contrast: 25, highlights: -40, shadows: -15, blacks: -10, vibrance: -20, clarity: 20, vignette: -30)),
        Preset(name: "Warm Film", settings: EditSettings(contrast: -10, highlights: -20, blacks: 18, temperature: 22, tint: 6, vibrance: -10, grain: 25)),
        Preset(name: "Cool Matte", settings: EditSettings(contrast: -15, blacks: 25, temperature: -18, saturation: -15, vignette: -10)),
        Preset(name: "B&W", settings: EditSettings(contrast: 25, whites: 10, blacks: -10, monochrome: true, clarity: 20)),
        Preset(name: "B&W Soft", settings: EditSettings(contrast: -10, blacks: 20, monochrome: true, grain: 30)),
        Preset(name: "Noir", settings: EditSettings(exposure: -0.2, contrast: 45, highlights: -20, shadows: -30, monochrome: true, clarity: 30, vignette: -40, grain: 15)),
    ]
}
