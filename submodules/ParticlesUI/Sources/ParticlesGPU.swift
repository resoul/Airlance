import Foundation
import Metal
import os

@MainActor
final class ParticlesGPU {
    static let shared = ParticlesGPU()

    private static let bundleName = "ParticlesUI"
    private static let logger = Logger(subsystem: "ParticlesUI", category: "GPU")

    let device: any MTLDevice
    let queue: any MTLCommandQueue
    let update: any MTLComputePipelineState
    let render: any MTLRenderPipelineState
    let pixelFormat = MTLPixelFormat.bgra8Unorm

    private init?() {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue(),
            let library = Self.makeLibrary(device: device),
            let function = library.makeFunction(name: "particles_update"),
            let update = try? device.makeComputePipelineState(function: function)
        else {
            Self.logger.error("Metal is unavailable, particles are not drawn")

            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "particles_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "particles_fragment")
        let attachment: MTLRenderPipelineColorAttachmentDescriptor? = descriptor.colorAttachments[0]
        attachment?.pixelFormat = pixelFormat
        attachment?.isBlendingEnabled = true
        attachment?.sourceRGBBlendFactor = .one
        attachment?.sourceAlphaBlendFactor = .one
        attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        guard let render = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            Self.logger.error("Can't build the particle pipeline")

            return nil
        }

        self.device = device
        self.queue = queue
        self.update = update
        self.render = render
    }

    private static func makeLibrary(device: any MTLDevice) -> (any MTLLibrary)? {
        guard
            let bundleURL = Bundle.main.url(forResource: bundleName, withExtension: "bundle"),
            let libraryURL = Bundle(url: bundleURL)?.url(forResource: bundleName, withExtension: "metallib")
        else {
            logger.error("ParticlesUI.metallib not found")

            return nil
        }

        return try? device.makeLibrary(URL: libraryURL)
    }
}
