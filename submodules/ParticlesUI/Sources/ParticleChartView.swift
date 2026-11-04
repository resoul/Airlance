import LiquidUI
import Metal
import QuartzCore
import UIKit

struct ParticleState {
    var motion: SIMD4<Float>
    var color: SIMD4<Float>
    var state: SIMD4<Float>
}

struct ParticleTarget {
    var place: SIMD4<Float>
    var color: SIMD4<Float>
    var release: SIMD4<Float>
}

struct ParticleUniforms {
    var viewport: SIMD4<Float>
    var touch: SIMD4<Float>
    var effect: SIMD4<Float>
    var frame: SIMD4<Float>
}

@MainActor
public final class ParticleChartView: UIView {
    private static let maxFramesInFlight = 2
    private static let touchRadius: Float = 64

    public var particleCount = 12_000
    public var brightness: CGFloat = 1
    public var repelsTouches = true
    public var touchArea: CGRect?
    public var onTap: (@MainActor (CGPoint) -> Void)?
    public var isPaused = false {
        didSet {
            updateDriver()
        }
    }

    private let gpu: ParticlesGPU?
    private var particles: (any MTLBuffer)?
    private var targets: (any MTLBuffer)?
    private var released: [Bool] = []
    private var release = ParticleRelease.dust
    private var releaseCenter = CGPoint.zero
    private var releaseDuration: TimeInterval = 1.6
    private let start = CACurrentMediaTime()
    var touch: CGPoint?
    var touchStart: (point: CGPoint, time: CFTimeInterval)?
    private var framesInFlight = 0
    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.draw(deltaTime)
    }

    public static var isSupported: Bool {
        ParticlesGPU.shared != nil
    }

    public static var isHardwareSupported: Bool {
        ParticlesGPU.hardware != nil
    }

    override public class var layerClass: AnyClass {
        CAMetalLayer.self
    }

    private var metalLayer: CAMetalLayer? {
        layer as? CAMetalLayer
    }

    private var now: Float {
        Float(CACurrentMediaTime() - start)
    }

    override public convenience init(frame: CGRect) {
        self.init(frame: frame, gpu: ParticlesGPU.shared)
    }

    public convenience init(ignoresPowerSaving: Bool) {
        self.init(frame: .zero, gpu: ignoresPowerSaving ? ParticlesGPU.hardware : ParticlesGPU.shared)
    }

    private init(frame: CGRect, gpu: ParticlesGPU?) {
        self.gpu = gpu
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        metalLayer?.device = gpu?.device
        metalLayer?.pixelFormat = gpu?.pixelFormat ?? .bgra8Unorm
        metalLayer?.isOpaque = false
        metalLayer?.framebufferOnly = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            contentScaleFactor = window.screen.scale
            metalLayer?.contentsScale = contentScaleFactor
        }
        updateDriver()
    }

    private func updateDriver() {
        if window != nil, !isPaused {
            driver.start()
        } else {
            driver.stop()
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        metalLayer?.drawableSize = CGSize(
            width: (bounds.width * contentScaleFactor).rounded(),
            height: (bounds.height * contentScaleFactor).rounded()
        )
    }

    public func show(
        _ segments: [ParticleSegment],
        from origin: CGPoint? = nil,
        release style: ParticleRelease = .dust,
        around center: CGPoint? = nil,
        duration: TimeInterval = 1.6
    ) {
        guard let targets = prepare(from: origin) else {
            return
        }

        release = style
        releaseCenter = center ?? CGPoint(x: bounds.midX, y: bounds.midY)
        releaseDuration = duration
        let pointer = targets.contents().bindMemory(to: ParticleTarget.self, capacity: particleCount)
        let time = now
        var index = 0
        for segment in segments {
            let count = min(segment.count, particleCount - index)
            guard count > 0 else {
                continue
            }

            if let path = segment.path {
                place(segment, path: path, range: index..<index + count, into: pointer)
            } else {
                releaseRange(index..<index + count, home: segment.home, at: time, into: pointer)
            }
            index += count
        }
        for rest in index..<particleCount {
            pointer[rest].color.w = 0
            pointer[rest].release.x = -1
            released[rest] = false
        }
    }

    private func place(
        _ segment: ParticleSegment,
        path: CGPath,
        range: Range<Int>,
        into pointer: UnsafeMutablePointer<ParticleTarget>
    ) {
        let points = ParticleSampler.points(in: path, count: range.count, seed: range.lowerBound, order: segment.order)
        var color = segment.color.particleComponents(with: traitCollection)
        color.w *= Float(segment.alpha)
        for (offset, point) in points.enumerated() {
            let index = range.lowerBound + offset
            let size = Float(segment.pointSize)
            pointer[index].place = SIMD4(Float(point.x), Float(point.y), size, Float(segment.stiffness))
            pointer[index].color = color
            pointer[index].release = SIMD4(-1, ParticleSampler.seed(index), 0, 0)
            released[index] = false
        }
    }

    private func prepare(from origin: CGPoint?) -> (any MTLBuffer)? {
        if let targets {
            return targets
        }

        guard
            let gpu,
            let particles = gpu.device.makeBuffer(
                length: MemoryLayout<ParticleState>.stride * particleCount,
                options: .storageModeShared
            ),
            let targets = gpu.device.makeBuffer(
                length: MemoryLayout<ParticleTarget>.stride * particleCount,
                options: .storageModeShared
            )
        else {
            return nil
        }

        let start = origin ?? CGPoint(x: bounds.midX, y: bounds.midY)
        let states = particles.contents().bindMemory(to: ParticleState.self, capacity: particleCount)
        let places = targets.contents().bindMemory(to: ParticleTarget.self, capacity: particleCount)
        for index in 0..<particleCount {
            let seed = ParticleSampler.seed(index)
            let jitter = SIMD2(Float(cos(Double(seed) * 40)), Float(sin(Double(seed) * 40))) * 6 * seed
            let position = SIMD2(Float(start.x), Float(start.y)) + jitter
            states[index] = ParticleState(
                motion: SIMD4(position.x, position.y, 0, 0),
                color: SIMD4(1, 1, 1, 0),
                state: SIMD4(0.5, 0, seed, 0)
            )
            places[index] = ParticleTarget(
                place: SIMD4(position.x, position.y, 1, 1),
                color: SIMD4(1, 1, 1, 0),
                release: SIMD4(-1, seed, 0, 0)
            )
        }
        released = Array(repeating: false, count: particleCount)
        self.particles = particles
        self.targets = targets

        return targets
    }

    private func draw(_ deltaTime: CFTimeInterval) {
        guard
            framesInFlight < Self.maxFramesInFlight,
            let gpu,
            let particles,
            let targets,
            let metalLayer,
            bounds.width > 0,
            let drawable = metalLayer.nextDrawable(),
            let commandBuffer = gpu.queue.makeCommandBuffer()
        else {
            return
        }

        var uniforms = uniforms(deltaTime: deltaTime, drawable: drawable.texture)
        encodeUpdate(commandBuffer, gpu: gpu, particles: particles, targets: targets, uniforms: &uniforms)
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) {
            encoder.setRenderPipelineState(gpu.render)
            encoder.setVertexBuffer(particles, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<ParticleUniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ParticleUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: particleCount)
            encoder.endEncoding()
        }
        framesInFlight += 1
        commandBuffer.addCompletedHandler { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.framesInFlight -= 1
            }
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func uniforms(deltaTime: CFTimeInterval, drawable: any MTLTexture) -> ParticleUniforms {
        let touchPoint = repelsTouches ? touch : nil

        return ParticleUniforms(
            viewport: SIMD4(Float(drawable.width), Float(drawable.height), Float(contentScaleFactor), 0),
            touch: SIMD4(
                Float(touchPoint?.x ?? 0),
                Float(touchPoint?.y ?? 0),
                touchPoint == nil ? 0 : 1,
                Self.touchRadius
            ),
            effect: SIMD4(
                Float(releaseCenter.x),
                Float(releaseCenter.y),
                Float(release.rawValue),
                Float(releaseDuration)
            ),
            frame: SIMD4(Float(deltaTime), Float(particleCount), now, Float(brightness))
        )
    }
}

extension ParticleChartView {
    private func releaseRange(
        _ range: Range<Int>,
        home: CGPoint?,
        at time: Float,
        into pointer: UnsafeMutablePointer<ParticleTarget>
    ) {
        let duration = Float(releaseDuration)
        for index in range where !released[index] {
            let place = pointer[index].place
            let seed = ParticleSampler.seed(index)
            let delay: Float
            switch release {
            case .dust:
                delay = Float(place.x) / Float(max(bounds.width, 1)) * duration * 0.45 + seed * 0.12
            case .blackHole:
                delay = seed * duration * 0.18
            case .home:
                let point = CGPoint(x: CGFloat(place.x), y: CGFloat(place.y))
                let angle = Float(ParticleShapes.angle(of: point, around: releaseCenter))
                delay = angle / (.pi * 2) * duration * 0.5 + seed * 0.08
            case .burst:
                delay = seed * 0.06
            }
            let target = home ?? releaseCenter
            pointer[index].release = SIMD4(time + delay, seed, Float(target.x), Float(target.y))
            released[index] = true
        }
    }
}

extension UIColor {
    fileprivate func particleComponents(with traits: UITraitCollection) -> SIMD4<Float> {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return SIMD4(Float(red), Float(green), Float(blue), Float(alpha))
    }
}
