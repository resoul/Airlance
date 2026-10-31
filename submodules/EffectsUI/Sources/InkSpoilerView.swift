import LiquidUI
import Metal
import QuartzCore
import UIKit

private struct SpoilerUniforms {
    var viewport: SIMD2<Float>
    var scale: Float
    var time: Float
    var rectCount: UInt32
    var seed: Float
    var stampCount: UInt32
    var unused: Float = 0
    var reveal: SIMD4<Float>
    var ink: SIMD4<Float>
}

@MainActor
public final class InkSpoilerView: UIView {
    private static let revealDuration: CFTimeInterval = 0.85
    private static let maxStamps = 96
    private static let stampRadius: Float = 14

    public var inkColor = UIColor.gray
    public var onRevealed: (@MainActor () -> Void)?
    public private(set) var isRevealing = false

    private let gpu: EffectsGPU
    private var rects: [CGRect] = []
    private var stamps: [SIMD4<Float>] = []
    private var lastStamp: CGPoint?
    private let wipeFeedback = UIImpactFeedbackGenerator(style: .soft)
    private var time: CFTimeInterval = 0
    private var revealOrigin: CGPoint?
    private var revealStart: CFTimeInterval = 0
    private let seed = Float.random(in: 0...50)
    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.step(deltaTime)
    }

    override public class var layerClass: AnyClass {
        CAMetalLayer.self
    }

    private var metalLayer: CAMetalLayer? {
        layer as? CAMetalLayer
    }

    public init?(frame: CGRect, scale: CGFloat) {
        guard let gpu = EffectsGPU.shared else {
            return nil
        }

        self.gpu = gpu
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentScaleFactor = scale
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
        metalLayer?.device = gpu.device
        metalLayer?.pixelFormat = gpu.pixelFormat
        metalLayer?.isOpaque = false
        metalLayer?.framebufferOnly = true
        metalLayer?.contentsScale = scale
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func setRects(_ rects: [CGRect]) {
        self.rects = rects
        render()
    }

    public func covers(_ point: CGPoint) -> Bool {
        !isRevealing && rects.contains { rect in
            rect.insetBy(dx: -6, dy: -6).contains(point)
        }
    }

    public func reveal(from point: CGPoint) {
        guard !isRevealing else {
            return
        }

        isRevealing = true
        revealOrigin = point
        revealStart = time
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let scale = contentScaleFactor
        metalLayer?.drawableSize = CGSize(
            width: max(1, (bounds.width * scale).rounded()),
            height: max(1, (bounds.height * scale).rounded())
        )
        render()
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            driver.stop()
        } else {
            driver.start()
        }
    }

    private func step(_ deltaTime: CFTimeInterval) {
        time += deltaTime
        if isRevealing, time - revealStart > Self.revealDuration {
            driver.stop()
            isHidden = true
            onRevealed?()

            return
        }

        render()
    }

    private var revealRadius: Float {
        guard revealOrigin != nil else {
            return 0
        }

        let progress = min(1, (time - revealStart) / 0.8)

        return Float((1 - pow(1 - progress, 2.2)) * (bounds.width + 40))
    }

    private func render() {
        guard
            !rects.isEmpty,
            bounds.width > 0,
            let metalLayer,
            let pipeline = gpu.renderPipeline(vertex: "spoiler_vertex", fragment: "spoiler_fragment"),
            let drawable = metalLayer.nextDrawable(),
            let commandBuffer = gpu.queue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: .clearing(drawable.texture))
        else {
            return
        }

        var uniforms = uniforms(target: drawable.texture)
        let stampData = stamps.isEmpty ? [SIMD4<Float>(-1000, -1000, 0, 0)] : stamps
        let rectData = rects.map { rect in
            SIMD4<Float>(Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height))
        }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SpoilerUniforms>.stride, index: 0)
        encoder.setFragmentBytes(rectData, length: MemoryLayout<SIMD4<Float>>.stride * rectData.count, index: 1)
        encoder.setFragmentBytes(stampData, length: MemoryLayout<SIMD4<Float>>.stride * stampData.count, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func uniforms(target: any MTLTexture) -> SpoilerUniforms {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        inkColor.resolvedColor(with: traitCollection).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let origin = revealOrigin ?? .zero

        return SpoilerUniforms(
            viewport: SIMD2(Float(target.width), Float(target.height)),
            scale: Float(contentScaleFactor),
            time: Float(time),
            rectCount: UInt32(rects.count),
            seed: seed,
            stampCount: UInt32(stamps.count),
            reveal: SIMD4(Float(origin.x), Float(origin.y), revealRadius, 0),
            ink: SIMD4(Float(red), Float(green), Float(blue), 1)
        )
    }
}

extension InkSpoilerView: UIGestureRecognizerDelegate {
    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        covers(point)
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer.view is UIScrollView
    }

    @objc
    private func panned(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self)
        switch gesture.state {
        case .began:
            let translation = gesture.translation(in: self)
            lastStamp = nil
            stamp(at: CGPoint(x: point.x - translation.x, y: point.y - translation.y))
            stamp(at: point)
        case .changed:
            stamp(at: point)
        default:
            lastStamp = nil
            if coverage() > 0.6 {
                reveal(from: point)
            }
        }
    }

    private func stamp(at point: CGPoint) {
        let from = lastStamp ?? point
        let distance = hypot(point.x - from.x, point.y - from.y)
        guard lastStamp == nil || distance >= 5 else {
            return
        }

        let steps = max(1, Int(distance / 5))
        for step in 1...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let x = from.x + (point.x - from.x) * progress
            let y = from.y + (point.y - from.y) * progress
            stamps.append(SIMD4(Float(x), Float(y), Self.stampRadius, 0))
        }
        if stamps.count > Self.maxStamps {
            stamps.removeFirst(stamps.count - Self.maxStamps)
        }
        lastStamp = point
        wipeFeedback.impactOccurred(intensity: 0.3)
    }

    private func coverage() -> CGFloat {
        var total = 0
        var wiped = 0
        let radius = CGFloat(Self.stampRadius)
        for rect in rects {
            for y in stride(from: rect.minY + 3, to: rect.maxY, by: 6) {
                for x in stride(from: rect.minX + 3, to: rect.maxX, by: 6) {
                    total += 1
                    let isWiped = stamps.contains { stamp in
                        hypot(CGFloat(stamp.x) - x, CGFloat(stamp.y) - y) < radius
                    }
                    wiped += isWiped ? 1 : 0
                }
            }
        }

        return total == 0 ? 1 : CGFloat(wiped) / CGFloat(total)
    }
}
