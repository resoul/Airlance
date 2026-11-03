import AirlanceUI
import Haptics
import UIKit

public final class CameraViewController: UIViewController {
    public var onCapture: (@MainActor (CameraCapture) -> Void)?
    public var onPick: (@MainActor ([CameraCapture]) -> Void)?
    public var onOpenURL: (@MainActor (URL) -> Void)?
    public var onThumbnail: (@MainActor () -> Void)?
    public var onClose: (@MainActor () -> Void)?
    public var isCaptureEnabled = true

    let camera: CameraSession
    let configuration: CameraConfiguration
    let previewHost = UIView()
    let shutter = ShutterButton()
    let flipButton = UIButton(type: .system)
    let flashButton = UIButton(type: .system)
    let closeButton = UIButton(type: .system)
    let lensBar = ZoomLensBar()
    let zoomDial = ZoomDial()
    let miniMap = ZoomMiniMap()
    let thumbnailButton = UIButton(type: .custom)
    let timerLabel = UILabel()
    let hintLabel = UILabel()
    let focusSquare = UIView()
    let modeControl = LiquidSegmentedControl()
    let squareMask = CameraSquareMask()
    let galleryButton = UIButton(type: .custom)
    let burstLabel = UILabel()
    var mode = CameraMode.photo
    var pressWasRecording = false
    var isBursting = false
    var isProcessing = false
    var burstImages: [UIImage] = []
    var burstTask: Task<Void, Never>?
    var galleryPanel: CameraGalleryView?
    let lockBadge = UIImageView()
    let selfTimerButton = UIButton(type: .system)
    let countdownLabel = UILabel()
    var isLocked = false
    var ignoresPress = false
    var selfTimer = 0
    var countdownTask: Task<Void, Never>?
    let scanButton = UIButton(type: .system)
    let codePill = UIButton(type: .system)
    var textPanel: CameraTextView?
    var shownCode: String?
    var codeHideTask: Task<Void, Never>?
    var orientationObserver: (any NSObjectProtocol)?
    var iconRotation: CGFloat = 0
    var dual: DualCameraSession?
    let pipView = UIView()
    var pipOrigin = CGPoint(x: 0.62, y: 0.14)
    var pinchStartZoom: CGFloat = 1
    var recordStartZoom: CGFloat = 1
    var dialStartZoom: CGFloat = 1
    var volumeZoom: CGFloat = 1
    var detent: CGFloat?
    var volumeStart: Date?
    var dialTask: Task<Void, Never>?
    var zoomTask: Task<Void, Never>?
    var pressStart: (point: CGPoint, time: Date)?
    var recordTask: Task<Void, Never>?
    var recordStart: Date?
    var timerTask: Task<Void, Never>?
    var hostOverlay: UIView?
    var hostAccessory: UIButton?

    private let origin: CGRect?
    private let reveal = CAShapeLayer()

    var controls: [UIView] {
        [
            shutter, flipButton, flashButton, closeButton, lensBar, thumbnailButton, hintLabel, modeControl,
            galleryButton, selfTimerButton, scanButton,
        ] + [hostAccessory].compactMap(\.self)
    }

    public init(session: CameraSession, configuration: CameraConfiguration, origin: CGRect?) {
        camera = session
        self.configuration = configuration
        self.origin = origin
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public var prefersStatusBarHidden: Bool {
        true
    }

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        traitCollection.userInterfaceIdiom == .pad ? .all : .portrait
    }

    override public func viewWillTransition(
        to size: CGSize,
        with coordinator: any UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.applyInterfaceRotation()
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        previewHost.backgroundColor = .black
        previewHost.layer.addSublayer(camera.preview)
        previewHost.layer.mask = reveal
        view.addSubview(previewHost)
        view.addSubview(squareMask)
        setUpButtons()
        setUpLabels()
        bindGestures()
        for control in controls {
            control.alpha = 0
            view.addSubview(control)
        }
        let overlays = [zoomDial, miniMap, timerLabel, burstLabel, focusSquare, lockBadge, countdownLabel, codePill]
        for overlay in overlays {
            view.addSubview(overlay)
        }
        setUpZoom()
        setUpModes()
        setUpGallery()
        setUpLock()
        setUpScan()
        setUpOrientation()
        camera.start()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewHost.frame = view.bounds
        squareMask.frame = view.bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        camera.preview.frame = previewHost.bounds
        CATransaction.commit()
        layoutDual()
        layoutControls()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard reveal.animation(forKey: "reveal") == nil, controls.first?.alpha == 0 else {
            return
        }

        open()
    }

    private func open() {
        let full = UIBezierPath(rect: view.bounds).cgPath
        let start = origin.map { origin in
            UIBezierPath(roundedRect: view.convert(origin, from: nil), cornerRadius: 6).cgPath
        } ?? full
        reveal.path = full
        if !UIAccessibility.isReduceMotionEnabled {
            let spring = CASpringAnimation(keyPath: "path")
            spring.fromValue = start
            spring.toValue = full
            spring.stiffness = 240
            spring.damping = 28
            spring.duration = spring.settlingDuration
            reveal.add(spring, forKey: "reveal")
        }
        UIView.animate(withDuration: 0.3, delay: 0.15) {
            for control in self.controls {
                control.alpha = 1
            }
        }
        UIView.animate(withDuration: 0.4, delay: 2.5) {
            self.hintLabel.alpha = 0
        }
    }

    public func setThumbnail(_ image: UIImage?, label: String?) {
        thumbnailButton.isHidden = image == nil
        thumbnailButton.setImage(image, for: .normal)
        thumbnailButton.accessibilityLabel = label
    }

    public func close(sending: Bool = false) {
        recordTask?.cancel()
        timerTask?.cancel()
        burstTask?.cancel()
        countdownTask?.cancel()
        codeHideTask?.cancel()
        tearDownOrientation()
        dual?.stop()
        zoomTask?.cancel()
        dialTask?.cancel()
        miniMap.stop()
        UIView.animate(withDuration: 0.25) {
            self.view.alpha = 0
            self.view.transform = sending ? .identity : CGAffineTransform(scaleX: 0.94, y: 0.94)
        } completion: { _ in
            self.camera.stop()
            self.dismiss(animated: false)
            self.onClose?()
        }
    }
}
