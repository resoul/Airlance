import Metal

extension ParticleChartView {
    func encodeUpdate(
        _ commandBuffer: any MTLCommandBuffer,
        gpu: ParticlesGPU,
        particles: any MTLBuffer,
        targets: any MTLBuffer,
        uniforms: inout ParticleUniforms
    ) {
        guard let compute = commandBuffer.makeComputeCommandEncoder() else {
            return
        }

        compute.setComputePipelineState(gpu.update)
        compute.setBuffer(particles, offset: 0, index: 0)
        compute.setBuffer(targets, offset: 0, index: 1)
        compute.setBytes(&uniforms, length: MemoryLayout<ParticleUniforms>.stride, index: 2)
        let width = gpu.update.threadExecutionWidth
        compute.dispatchThreadgroups(
            MTLSize(width: (particleCount + width - 1) / width, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
        )
        compute.endEncoding()
    }
}
