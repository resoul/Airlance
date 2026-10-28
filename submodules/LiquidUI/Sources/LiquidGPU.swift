import Foundation
import Metal
import os
import UIKit

@MainActor
final class LiquidGPU {
    static let shared = LiquidGPU()

    private static let bundleName = "LiquidUI"
    private static let logger = Logger(subsystem: "LiquidUI", category: "GPU")

    let device: any MTLDevice
    let queue: any MTLCommandQueue
    let pipeline: any MTLRenderPipelineState
    let pixelFormat = MTLPixelFormat.bgra8Unorm
    let library: any MTLLibrary

    private(set) lazy var revealPipeline: (any MTLRenderPipelineState)? = makePipeline(
        vertex: "theme_reveal_vertex",
        fragment: "theme_reveal_fragment"
    )

    private init?() {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue(),
            let library = Self.makeLibrary(device: device)
        else {
            Self.logger.error("Metal is unavailable, liquid falls back to a plain shape")

            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "liquid_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "liquid_fragment")
        let attachment: MTLRenderPipelineColorAttachmentDescriptor? = descriptor.colorAttachments[0]
        attachment?.pixelFormat = pixelFormat
        attachment?.isBlendingEnabled = true
        attachment?.sourceRGBBlendFactor = .one
        attachment?.sourceAlphaBlendFactor = .one
        attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            Self.logger.error("Can't build the liquid pipeline")

            return nil
        }

        self.device = device
        self.queue = queue
        self.pipeline = pipeline
        self.library = library
    }

    func makeTexture(snapshotting view: UIView, scale: CGFloat) -> (any MTLTexture)? {
        let width = Int((view.bounds.width * scale).rounded())
        let height = Int((view.bounds.height * scale).rounded())
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: info
              ) else {
            return nil
        }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        UIGraphicsPushContext(context)
        if !view.drawHierarchy(in: view.bounds, afterScreenUpdates: false) {
            view.layer.render(in: context)
        }
        UIGraphicsPopContext()
        guard let bytes = context.data else {
            return nil
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = .shaderRead
        let texture = device.makeTexture(descriptor: descriptor)
        texture?.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: context.bytesPerRow
        )

        return texture
    }

    private func makePipeline(vertex: String, fragment: String) -> (any MTLRenderPipelineState)? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: vertex)
        descriptor.fragmentFunction = library.makeFunction(name: fragment)
        let attachment: MTLRenderPipelineColorAttachmentDescriptor? = descriptor.colorAttachments[0]
        attachment?.pixelFormat = pixelFormat
        attachment?.isBlendingEnabled = true
        attachment?.sourceRGBBlendFactor = .one
        attachment?.sourceAlphaBlendFactor = .one
        attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeLibrary(device: any MTLDevice) -> (any MTLLibrary)? {
        guard
            let bundleURL = Bundle.main.url(forResource: bundleName, withExtension: "bundle"),
            let libraryURL = Bundle(url: bundleURL)?.url(forResource: bundleName, withExtension: "metallib")
        else {
            logger.error("LiquidUI.metallib not found")

            return nil
        }

        return try? device.makeLibrary(URL: libraryURL)
    }
}
