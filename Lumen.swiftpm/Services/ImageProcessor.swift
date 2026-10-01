import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO

/// RGB histogram of a rendered image, gamma encoded.
struct Histogram: Sendable {
    /// Bin heights scaled for display (0...1).
    var red: [Float]
    var green: [Float]
    var blue: [Float]
    /// Average luminance, 0...1.
    var meanLuminance: Double
    /// Share of pixels in the darkest / brightest bin.
    var shadowClipping: Double
    var highlightClipping: Double
}

/// Renders `EditSettings` with Core Image. CIContext is thread-safe, so one shared instance serves every caller.
final class ImageProcessor: @unchecked Sendable {
    static let shared = ImageProcessor()

    let context = CIContext(options: [.cacheIntermediates: false])
    private let outputColorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()

    // MARK: Pipeline

    /// Applies `settings` to `input`. Pass `cropping: false` to keep the full straightened frame (used by the crop tool).
    func apply(_ settings: EditSettings, to input: CIImage, cropping: Bool = true) -> CIImage {
        var image = orient(input, settings)
        // Size-dependent effects scale with the image so a 2400px preview matches the full-size export.
        let reference = max(image.extent.width, image.extent.height)
        image = adjustLight(image, settings, reference: reference)
        image = adjustColor(image, settings)
        image = adjustDetail(image, settings, reference: reference)
        image = straighten(image, settings)
        if cropping { image = crop(image, settings) }
        image = addEffects(image, settings, reference: reference)
        return image
    }

    private func adjustLight(_ input: CIImage, _ s: EditSettings, reference: CGFloat) -> CIImage {
        var image = input
        let extent = image.extent
        if s.exposure != 0 {
            image = image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: s.exposure])
        }

        let highlights = s.highlights / 100, shadows = s.shadows / 100
        // Recovering highlights and lifting shadows works best as a local operation.
        if highlights < 0 || shadows > 0 {
            image = image.clampedToExtent()
                .applyingFilter("CIHighlightShadowAdjust", parameters: [
                    "inputHighlightAmount": 1 + min(highlights, 0),
                    "inputShadowAmount": max(shadows, 0),
                    kCIInputRadiusKey: reference * 0.004,
                ])
                .cropped(to: extent)
        }

        // Everything else is a tone curve, applied in gamma space so the sliders feel perceptual.
        let contrast = s.contrast / 100, whites = s.whites / 100, blacks = s.blacks / 100
        let brighterHighlights = max(highlights, 0), deeperShadows = min(shadows, 0)
        if contrast != 0 || whites != 0 || blacks != 0 || brighterHighlights != 0 || deeperShadows != 0 {
            func point(_ x: Double, _ y: Double) -> CIVector { CIVector(x: x, y: min(max(y, 0), 1)) }
            image = image
                .applyingFilter("CILinearToSRGBToneCurve")
                .applyingFilter("CIToneCurve", parameters: [
                    "inputPoint0": point(0, max(blacks, 0) * 0.15),
                    "inputPoint1": point(0.25, 0.25 - contrast * 0.07 + deeperShadows * 0.12 + blacks * 0.06),
                    "inputPoint2": point(0.5, 0.5 + (whites + blacks) * 0.02),
                    "inputPoint3": point(0.75, 0.75 + contrast * 0.07 + brighterHighlights * 0.12 + whites * 0.06),
                    "inputPoint4": point(1, 1 + min(whites, 0) * 0.15),
                ])
                .applyingFilter("CISRGBToneCurveToLinear")
        }
        return image
    }

    private func adjustColor(_ input: CIImage, _ s: EditSettings) -> CIImage {
        var image = input
        if s.temperature != 0 || s.tint != 0 {
            // Telling Core Image the scene was lit by a bluer (higher Kelvin) source warms the photo, and vice versa.
            let kelvin = 6500 + s.temperature * (s.temperature > 0 ? 45 : 30)
            image = image.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: kelvin, y: -s.tint),
                "inputTargetNeutral": CIVector(x: 6500, y: 0),
            ])
        }
        if s.vibrance != 0 {
            image = image.applyingFilter("CIVibrance", parameters: ["inputAmount": s.vibrance / 100])
        }
        if s.saturation != 0 || s.monochrome {
            image = image.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: s.monochrome ? 0 : 1 + s.saturation / 100,
            ])
        }
        return image
    }

    private func adjustDetail(_ input: CIImage, _ s: EditSettings, reference: CGFloat) -> CIImage {
        var image = input
        let extent = image.extent
        if s.noiseReduction > 0 {
            image = image.clampedToExtent()
                .applyingFilter("CINoiseReduction", parameters: [
                    "inputNoiseLevel": s.noiseReduction / 100 * 0.06,
                    "inputSharpness": 0.4,
                ])
                .cropped(to: extent)
        }
        if s.clarity != 0 {
            // Clarity is a wide unsharp mask: it boosts local contrast rather than edges.
            image = image.clampedToExtent()
                .applyingFilter("CIUnsharpMask", parameters: [
                    kCIInputRadiusKey: reference * 0.012,
                    kCIInputIntensityKey: s.clarity / 100 * 0.7,
                ])
                .cropped(to: extent)
        }
        if s.sharpening > 0 {
            image = image.clampedToExtent()
                .applyingFilter("CISharpenLuminance", parameters: [
                    kCIInputSharpnessKey: s.sharpening / 100 * 1.5,
                    kCIInputRadiusKey: max(1, reference / 2000),
                ])
                .cropped(to: extent)
        }
        return image
    }

    private func addEffects(_ input: CIImage, _ s: EditSettings, reference: CGFloat) -> CIImage {
        var image = input
        let extent = image.extent
        if s.vignette != 0 {
            image = image.applyingFilter("CIVignetteEffect", parameters: [
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
                kCIInputRadiusKey: hypot(extent.width, extent.height) * 0.3,
                // Negative slider values darken the edges, like Lightroom.
                kCIInputIntensityKey: -s.vignette / 100,
                "inputFalloff": 0.7,
            ])
            .cropped(to: extent)
        }
        if s.grain > 0, let random = CIFilter.randomGenerator().outputImage {
            let amount = s.grain / 100 * 0.35
            let size = max(1, reference / 1500)
            let channel = CIVector(x: amount, y: 0, z: 0, w: 0)
            // Gray noise centered on 0.5, which is neutral for soft light blending.
            let noise = random
                .transformed(by: CGAffineTransform(scaleX: size, y: size))
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": channel,
                    "inputGVector": channel,
                    "inputBVector": channel,
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputBiasVector": CIVector(x: 0.5 - amount / 2, y: 0.5 - amount / 2, z: 0.5 - amount / 2, w: 1),
                ])
                .cropped(to: extent)
            image = noise.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: image])
        }
        return image
    }

    // MARK: Geometry

    private func orient(_ input: CIImage, _ s: EditSettings) -> CIImage {
        var image = input
        switch ((s.quarterTurns % 4) + 4) % 4 {
        case 1: image = image.oriented(.right)
        case 2: image = image.oriented(.down)
        case 3: image = image.oriented(.left)
        default: break
        }
        // Mirroring after rotating keeps "flip" horizontal on screen whatever the rotation.
        if s.flipped { image = image.oriented(.upMirrored) }
        return image.movedToOrigin()
    }

    private func straighten(_ input: CIImage, _ s: EditSettings) -> CIImage {
        guard s.straighten != 0 else { return input }
        let w = input.extent.width, h = input.extent.height
        let angle = s.straighten * .pi / 180
        let rotation = CGAffineTransform(translationX: w / 2, y: h / 2)
            .rotated(by: -angle)
            .translatedBy(x: -w / 2, y: -h / 2)
        // Largest rectangle with the original aspect ratio that fits inside the rotated frame.
        let c = abs(cos(angle)), sn = abs(sin(angle))
        let scale = min(w / (w * c + h * sn), h / (w * sn + h * c))
        let frame = CGRect(x: (w - w * scale) / 2, y: (h - h * scale) / 2, width: w * scale, height: h * scale)
        return input.clampedToExtent().transformed(by: rotation).cropped(to: frame).movedToOrigin()
    }

    private func crop(_ input: CIImage, _ s: EditSettings) -> CIImage {
        guard s.crop != .full else { return input }
        let e = input.extent
        let rect = CGRect(
            x: e.minX + s.crop.x * e.width,
            y: e.minY + (1 - s.crop.y - s.crop.height) * e.height,
            width: s.crop.width * e.width,
            height: s.crop.height * e.height
        ).integral.intersection(e)
        return input.cropped(to: rect).movedToOrigin()
    }

    // MARK: Output

    func render(_ image: CIImage) -> CGImage? {
        context.createCGImage(image, from: image.extent.integral, format: .RGBA8, colorSpace: outputColorSpace)
    }

    /// Encodes `image` as JPEG, carrying over the original's metadata (EXIF, GPS…) with orientation reset to "up".
    func jpegData(_ image: CIImage, metadata: [String: Any], quality: Double = 0.92) -> Data? {
        var properties = metadata
        properties[kCGImagePropertyOrientation as String] = 1
        if var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiff[kCGImagePropertyTIFFOrientation as String] = 1
            properties[kCGImagePropertyTIFFDictionary as String] = tiff
        }
        if var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            // Cropping changed the dimensions; let ImageIO write the real ones.
            exif.removeValue(forKey: kCGImagePropertyExifPixelXDimension as String)
            exif.removeValue(forKey: kCGImagePropertyExifPixelYDimension as String)
            properties[kCGImagePropertyExifDictionary as String] = exif
        }
        let option = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        return context.jpegRepresentation(
            of: image.settingProperties(properties),
            colorSpace: outputColorSpace,
            options: [option: quality]
        )
    }

    func histogram(of cgImage: CGImage, bins: Int = 64) -> Histogram? {
        var image = CIImage(cgImage: cgImage)
        let longest = max(image.extent.width, image.extent.height)
        if longest > 256 {
            let scale = 256 / longest
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        image = image.applyingFilter("CILinearToSRGBToneCurve")

        let filter = CIFilter.areaHistogram()
        filter.inputImage = image
        filter.extent = image.extent.integral
        filter.count = bins
        filter.scale = 1
        guard let output = filter.outputImage else { return nil }

        var values = [Float](repeating: 0, count: bins * 4)
        context.render(
            output,
            toBitmap: &values,
            rowBytes: bins * 4 * MemoryLayout<Float>.size,
            bounds: CGRect(x: 0, y: 0, width: bins, height: 1),
            format: .RGBAf,
            colorSpace: nil
        )

        var channels: [[Float]] = [[], [], []]
        for bin in 0..<bins {
            for channel in 0..<3 { channels[channel].append(values[bin * 4 + channel]) }
        }
        func mean(_ channel: [Float]) -> Double {
            channel.enumerated().reduce(0) { $0 + (Double($1.offset) + 0.5) / Double(bins) * Double($1.element) }
        }
        let meanLuminance = 0.2126 * mean(channels[0]) + 0.7152 * mean(channels[1]) + 0.0722 * mean(channels[2])
        let shadowClipping = Double(channels.map { $0[0] }.reduce(0, +)) / 3
        let highlightClipping = Double(channels.map { $0[bins - 1] }.reduce(0, +)) / 3

        // Square-root scaling keeps a single spike from flattening the rest of the graph.
        let peak = channels.flatMap { $0 }.max() ?? 0
        let display = channels.map { channel in channel.map { peak > 0 ? ($0 / peak).squareRoot() : 0 } }
        return Histogram(
            red: display[0],
            green: display[1],
            blue: display[2],
            meanLuminance: meanLuminance,
            shadowClipping: shadowClipping,
            highlightClipping: highlightClipping
        )
    }
}

extension CIImage {
    func movedToOrigin() -> CIImage {
        transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
    }
}
