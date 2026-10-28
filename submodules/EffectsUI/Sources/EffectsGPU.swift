import Metal
import os
import UIKit

@MainActor
final class EffectsGPU {
    static let shared = EffectsGPU()

    private static let bundleName = "EffectsUI"
    private static let logger = Logger(subsystem: "EffectsUI", category: "GPU")

    let device: any MTLDevice
    let queue: any MTLCommandQueue
    let pixelFormat = MTLPixelFormat.bgra8Unorm

    private let library: any MTLLibrary
    private var renderPipelines: [String: any MTLRenderPipelineState] = [:]
    private var computePipelines: [String: any MTLComputePipelineState] = [:]

    private init?() {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue(),
            let library = Self.makeLibrary(device: device)
        else {
            Self.logger.error("Metal is unavailable, effects fall back to a fade")

            return nil
        }

        self.device = device
        self.queue = queue
        self.library = library
    }

    func renderPipeline(vertex: String, fragment: String) -> (any MTLRenderPipelineState)? {
        let key = vertex + "|" + fragment
        if let pipeline = renderPipelines[key] {
            return pipeline
        }

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
        let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
        renderPipelines[key] = pipeline

        return pipeline
    }

    func computePipeline(_ name: String) -> (any MTLComputePipelineState)? {
        if let pipeline = computePipelines[name] {
            return pipeline
        }

        let pipeline = library.makeFunction(name: name).flatMap { function in
            try? device.makeComputePipelineState(function: function)
        }
        computePipelines[name] = pipeline

        return pipeline
    }

    func makeTexture(snapshotting view: UIView, rect: CGRect, scale: CGFloat) -> (any MTLTexture)? {
        let width = Int((rect.width * scale).rounded())
        let height = Int((rect.height * scale).rounded())
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
        context.translateBy(x: -rect.minX, y: -rect.minY)
        UIGraphicsPushContext(context)
        if !view.drawHierarchy(in: view.bounds, afterScreenUpdates: false) {
            view.layer.render(in: context)
        }
        UIGraphicsPopContext()

        return texture(from: context, width: width, height: height)
    }

    private func texture(from context: CGContext, width: Int, height: Int) -> (any MTLTexture)? {
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

    private static func makeLibrary(device: any MTLDevice) -> (any MTLLibrary)? {
        guard
            let bundleURL = Bundle.main.url(forResource: bundleName, withExtension: "bundle"),
            let libraryURL = Bundle(url: bundleURL)?.url(forResource: bundleName, withExtension: "metallib")
        else {
            logger.error("EffectsUI.metallib not found")

            return nil
        }

        return try? device.makeLibrary(URL: libraryURL)
    }
}
