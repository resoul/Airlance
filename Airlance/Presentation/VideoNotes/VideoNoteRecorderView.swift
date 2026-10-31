import ChatHistory
import Haptics
import LiquidUI
import UIKit

struct VideoNoteRecorderOptions {
    let style: MessageVideoNote.Style
    let tapToStop: Bool
    let limit: TimeInterval
}

final class VideoNoteRecorderView: UIView {
    private static let minimum: TimeInterval = 0.8

    var onSend: (@MainActor (VideoNoteCamera.Result) -> Void)?
    var onTooShort: (@MainActor () -> Void)?
    var onFinish: (@MainActor () -> Void)?

    let camera: VideoNoteCamera
    let options: VideoNoteRecorderOptions
    private let backdrop = UIVisualEffectView(effect: nil)
    let container = UIView()
    let shape = CAShapeLayer()
    let ring = CAShapeLayer()
    let front = UIView()
    let frontShape = CAShapeLayer()
    let stylizedLayer = CALayer()
    let switchButton = UIButton(type: .system)
    private let timeLabel = UILabel()
    private let hintLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private var phase: CGFloat = 0
    private var level: CGFloat = 0
    private var isRecording = false
    var isFinished = false
    private lazy var driver = DisplayLinkDriver { [weak self] deltaTime in
        self?.step(deltaTime)
    }

    init(camera: VideoNoteCamera, options: VideoNoteRecorderOptions, host: UIView, presentation: PresentationData) {
        self.camera = camera
        self.options = options
        super.init(frame: host.bounds)
        host.addSubview(self)
        backdrop.frame = bounds
        addSubview(backdrop)
        buildPreview(presentation)
        buildLabels(presentation)
        if options.tapToStop {
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
            tap.delegate = self
            addGestureRecognizer(tap)
        }
        container.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        container.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.backdrop.effect = UIBlurEffect(style: .systemMaterial)
        }
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            self.container.transform = .identity
            self.container.alpha = 1
        }
        Haptics.play(.menu)
        camera.start()
        driver.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.beginRecording()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var previewSize: CGSize {
        switch options.style {
        case .dualCamera:
            CGSize(width: 260, height: 346)
        case .reaction:
            CGSize(width: 220, height: 220)
        case .blob, .anonymous, .moment:
            CGSize(width: 260, height: 260)
        }
    }

    private func buildLabels(_ presentation: PresentationData) {
        let strings = presentation.strings
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        timeLabel.textColor = presentation.theme.colors.textPrimary
        timeLabel.textAlignment = .center
        timeLabel.frame = CGRect(x: 0, y: container.frame.maxY + 20, width: bounds.width, height: 24)
        addSubview(timeLabel)
        hintLabel.font = presentation.theme.fonts.caption
        hintLabel.textColor = presentation.theme.colors.textSecondary
        hintLabel.textAlignment = .center
        hintLabel.text = options.tapToStop ? strings.videoNotesTapToStop : strings.chatRecordSlide
        hintLabel.frame = CGRect(x: 0, y: timeLabel.frame.maxY + 6, width: bounds.width, height: 20)
        addSubview(hintLabel)
        guard options.tapToStop else {
            return
        }

        cancelButton.setTitle(strings.chatCancel, for: .normal)
        cancelButton.titleLabel?.font = presentation.theme.fonts.body
        cancelButton.tintColor = presentation.theme.colors.accent
        cancelButton.frame = CGRect(x: 0, y: hintLabel.frame.maxY + 18, width: bounds.width, height: 44)
        cancelButton.addAction(
            UIAction { [weak self] _ in
                self?.finish(send: false)
            },
            for: .touchUpInside
        )
        addSubview(cancelButton)
    }

    private func beginRecording() {
        guard !isFinished else {
            return
        }

        camera.record()
        isRecording = true
    }

    func drag(_ offset: CGPoint) {
        guard !options.tapToStop, !isFinished else {
            return
        }

        hintLabel.alpha = max(0, 1 + offset.x / 120)
        container.transform = CGAffineTransform(translationX: min(0, offset.x) / 3, y: 0)
        if offset.x < -120 {
            Haptics.play(.warning)
            finish(send: false)
        }
    }

    func release() {
        finish(send: true)
    }

    func cancel() {
        finish(send: false)
    }

    @objc
    private func tapped() {
        finish(send: true)
    }

    private func step(_ deltaTime: CFTimeInterval) {
        phase += CGFloat(deltaTime) * 2.2
        if isRecording {
            let target = camera.sampleLevel()
            level += (target - level) * 0.3
            let duration = camera.duration
            let total = Int(duration)
            timeLabel.text = String(format: "%d:%02d", total / 60, total % 60)
            ring.strokeEnd = CGFloat(min(1, duration / options.limit))
            if duration >= options.limit {
                finish(send: true)
            }
        }
        updateShapes()
    }

    func updateShapes() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let bounds = container.bounds
        let radius = VideoNoteBody.cornerRadius(for: options.style, size: bounds.size)
        if options.style == .blob {
            shape.path = BlobShape.path(in: bounds, phase: phase, level: level)
        } else {
            shape.path = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        }
        frontShape.path = BlobShape.path(in: front.bounds, phase: phase + 2, level: level)
        let ringRect = container.frame.insetBy(dx: -8, dy: -8)
        ring.path = UIBezierPath(roundedRect: ringRect, cornerRadius: radius + 8).cgPath
        CATransaction.commit()
    }

    private func finish(send: Bool) {
        guard !isFinished else {
            return
        }

        isFinished = true
        let duration = camera.duration
        let tooShort = duration < Self.minimum
        guard isRecording else {
            close()

            return
        }

        camera.stop { [weak self] result in
            guard let self else {
                return
            }

            if send, !tooShort, let result {
                self.onSend?(result)
            } else if send, tooShort {
                self.onTooShort?()
            }
            self.close()
        }
    }

    private func close() {
        driver.stop()
        camera.shutdown()
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.25) {
            self.backdrop.effect = nil
            self.container.alpha = 0
            self.front.alpha = 0
            self.timeLabel.alpha = 0
            self.hintLabel.alpha = 0
            self.cancelButton.alpha = 0
            self.switchButton.alpha = 0
            self.ring.opacity = 0
            self.container.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        } completion: { _ in
            self.removeFromSuperview()
            self.onFinish?()
        }
    }
}

extension VideoNoteRecorderView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIButton)
    }
}
