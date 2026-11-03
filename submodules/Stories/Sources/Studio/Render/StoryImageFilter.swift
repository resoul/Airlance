import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum StoryImageFilter {
    static let context = CIContext(options: [.cacheIntermediates: false])

    nonisolated static func apply(_ adjustments: StoryAdjustments, to input: CIImage) -> CIImage {
        guard !adjustments.isIdentity else {
            return input
        }

        let extent = input.extent
        var image = preset(adjustments.filter, input)
        if adjustments.brightness != 0 || adjustments.contrast != 0 || adjustments.saturation != 0 {
            let controls = CIFilter.colorControls()
            controls.inputImage = image
            controls.brightness = Float(adjustments.brightness * 0.25)
            controls.contrast = Float(1 + adjustments.contrast * 0.5)
            controls.saturation = Float(1 + adjustments.saturation)
            image = controls.outputImage ?? image
        }
        if adjustments.warmth != 0 {
            image = temperature(image, shift: adjustments.warmth * 1800)
        }
        if adjustments.vignette > 0 {
            let vignette = CIFilter.vignette()
            vignette.inputImage = image
            vignette.intensity = Float(adjustments.vignette * 1.6)
            vignette.radius = 1.6
            image = vignette.outputImage ?? image
        }

        return image.cropped(to: extent)
    }

    static func render(_ image: UIImage, adjustments: StoryAdjustments, maxSide: CGFloat? = nil) -> UIImage {
        guard !adjustments.isIdentity, var input = CIImage(image: image) else {
            return image
        }

        input = input.oriented(CGImagePropertyOrientation(image.imageOrientation))
        if let maxSide {
            let scale = min(1, maxSide / max(input.extent.width, input.extent.height))
            input = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        let output = apply(adjustments, to: input)
        guard let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }

    static func videoComposition(for asset: AVAsset, adjustments: StoryAdjustments) async -> AVVideoComposition? {
        guard !adjustments.isIdentity else {
            return nil
        }

        return try? await AVVideoComposition.videoComposition(with: asset) { request in
            let output = apply(adjustments, to: request.sourceImage.clampedToExtent())
                .cropped(to: request.sourceImage.extent)
            request.finish(with: output, context: nil)
        }
    }

    nonisolated private static func preset(_ filter: StoryFilter, _ image: CIImage) -> CIImage {
        switch filter {
        case .original:
            return image
        case .vivid:
            return controls(image, saturation: 1.35, contrast: 1.08, brightness: 0.01)
        case .warm:
            return temperature(image, shift: 1200)
        case .cool:
            return temperature(image, shift: -1200)
        case .fade:
            return controls(image, saturation: 0.75, contrast: 0.88, brightness: 0.05)
        case .mono:
            return effect(CIFilter.photoEffectMono(), image)
        case .noir:
            return effect(CIFilter.photoEffectNoir(), image)
        case .chrome:
            return effect(CIFilter.photoEffectChrome(), image)
        }
    }

    nonisolated private static func effect(_ filter: any CIFilter & CIPhotoEffect, _ image: CIImage) -> CIImage {
        filter.inputImage = image

        return filter.outputImage ?? image
    }

    nonisolated private static func controls(
        _ image: CIImage,
        saturation: Float,
        contrast: Float,
        brightness: Float
    ) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = saturation
        filter.contrast = contrast
        filter.brightness = brightness

        return filter.outputImage ?? image
    }

    nonisolated private static func temperature(_ image: CIImage, shift: Double) -> CIImage {
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = image
        filter.neutral = CIVector(x: 6500, y: 0)
        filter.targetNeutral = CIVector(x: CGFloat(6500 - shift), y: 0)

        return filter.outputImage ?? image
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        self = switch orientation {
        case .down:
            .down
        case .left:
            .left
        case .right:
            .right
        case .upMirrored:
            .upMirrored
        case .downMirrored:
            .downMirrored
        case .leftMirrored:
            .leftMirrored
        case .rightMirrored:
            .rightMirrored
        default:
            .up
        }
    }
}
