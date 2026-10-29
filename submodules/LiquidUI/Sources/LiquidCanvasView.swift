import Metal
import QuartzCore
import UIKit

@MainActor
public final class LiquidCanvasView: UIView {
    public var color = UIColor.systemBlue
    public var gloss: CGFloat = 0.4
    public var rimWidth: CGFloat = 6
    public var blobs: [LiquidBlob] = []
    public var bridges: [LiquidBridge] = []
    public var onFrame: (@MainActor (CFTimeInterval) -> Void)?

    private var renderer: LiquidCanvasRenderer?
    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.tick(deltaTime)
    }
    private static let maxFramesInFlight = 2

    private var wantsFrames = false
    private var needsRender = true
    private var framesInFlight = 0

    private var canSubmit: Bool {
        framesInFlight < Self.maxFramesInFlight
    }

    public static var isSupported: Bool {
        LiquidGPU.shared != nil
    }

    override public class var layerClass: AnyClass {
        CAMetalLayer.self
    }

    private var metalLayer: CAMetalLayer? {
        layer as? CAMetalLayer
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        let gpu = LiquidGPU.shared
        metalLayer?.device = gpu?.device
        metalLayer?.pixelFormat = gpu?.pixelFormat ?? .bgra8Unorm
        metalLayer?.isOpaque = false
        metalLayer?.framebufferOnly = true
        if let metalLayer, let gpu {
            renderer = LiquidCanvasRenderer(layer: metalLayer, gpu: gpu)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func startFrames() {
        wantsFrames = true
        updateDriver()
    }

    public func stopFrames() {
        wantsFrames = false
        updateDriver()
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            contentScaleFactor = window.screen.scale
            metalLayer?.contentsScale = contentScaleFactor
            needsRender = true
        }
        updateDriver()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        render()
    }

    public func render() {
        needsRender = true
        updateDriver()
    }

    private func tick(_ deltaTime: CFTimeInterval) {
        if wantsFrames {
            onFrame?(deltaTime)
            needsRender = true
        }
        superview?.layoutIfNeeded()
        layoutIfNeeded()
        submitFrame()
        updateDriver()
    }

    private func submitFrame() {
        guard needsRender, canSubmit else {
            return
        }

        needsRender = false
        guard let renderer, let metalLayer else {
            return
        }

        let frame = makeFrame()
        if metalLayer.drawableSize != frame.size {
            metalLayer.drawableSize = frame.size
        }
        framesInFlight += 1
        renderer.render(frame) { [weak self] succeeded in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                self.framesInFlight -= 1
                self.needsRender = self.needsRender || !succeeded
                self.updateDriver()
            }
        }
    }

    private func makeFrame() -> LiquidCanvasFrame {
        let extent = (blobs.map(\.extent) + bridges.map(\.extent)).reduce(CGRect.null) { result, rect in
            result.union(rect)
        }
        let rect = extent.isNull ? CGRect.zero : extent
        let uniforms = LiquidUniforms(
            scale: Float(contentScaleFactor),
            gloss: Float(gloss),
            rimWidth: Float(rimWidth),
            color: color.liquidComponents(with: traitCollection),
            bounds: SIMD4(Float(rect.minX), Float(rect.minY), Float(rect.maxX), Float(rect.maxY)),
            blobCount: UInt32(blobs.count),
            bridgeCount: UInt32(bridges.count)
        )

        return LiquidCanvasFrame(
            size: CGSize(
                width: (bounds.width * contentScaleFactor).rounded(),
                height: (bounds.height * contentScaleFactor).rounded()
            ),
            uniforms: uniforms,
            blobs: blobs,
            bridges: bridges
        )
    }

    private func updateDriver() {
        let needsFrame = wantsFrames || (needsRender && canSubmit)
        if needsFrame, window != nil, bounds.width > 0, bounds.height > 0 {
            driver.start()
        } else {
            driver.stop()
        }
    }
}

extension UIColor {
    fileprivate func liquidComponents(with traits: UITraitCollection) -> SIMD4<Float> {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return SIMD4(Float(red), Float(green), Float(blue), Float(alpha))
    }
}
