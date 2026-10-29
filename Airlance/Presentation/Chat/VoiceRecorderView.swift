import ChatHistory
import Haptics
import LiquidUI
import Theme
import UIKit

struct VoiceRecorderTexts {
    let slideHint: String
    let cancel: String
}

final class VoiceRecorderView: UIView {
    var onSend: (@MainActor (MessageVoice) -> Void)?
    var onTooShort: (@MainActor () -> Void)?
    var onFinish: (@MainActor () -> Void)?

    let canvas = LiquidCanvasView()
    let buttonCenter: CGPoint
    let mic = UIImageView()
    let sendButton = UIButton(type: .system)
    let lockPill = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    let lockIcon = UIImageView()
    let lockArrow = UIImageView()
    let panel = UIView()
    let dot = UIView()
    let timeLabel = UILabel()
    let slideLabel = UILabel()
    let cancelButton = UIButton(type: .system)
    let recording: VoiceRecording
    let theme: AppTheme
    var scale = Spring(0, stiffness: 14, dampingRatio: 0.6)
    var level = Spring(0, stiffness: 18, dampingRatio: 0.7)
    var follow = CGPoint.zero
    var finger = CGPoint.zero
    var lockProgress: CGFloat = 0
    var isLocked = false
    var isFinished = false
    var phase: CGFloat = 0

    init(
        recording: VoiceRecording,
        host: UIView,
        buttonCenter: CGPoint,
        bar: CGRect,
        texts: VoiceRecorderTexts,
        theme: AppTheme
    ) {
        self.recording = recording
        self.buttonCenter = buttonCenter
        self.theme = theme
        super.init(frame: host.bounds)
        host.addSubview(self)
        buildPanel(bar: bar, texts: texts)
        canvas.frame = bounds
        canvas.color = theme.colors.accent
        canvas.gloss = 0.55
        canvas.rimWidth = 9
        canvas.onFrame = { [weak self] deltaTime in
            self?.step(deltaTime)
        }
        addSubview(canvas)
        buildLock()
        buildMic()
        Haptics.play(.menu)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.panel.alpha = 1
            self.panel.transform = .identity
            self.lockPill.alpha = 1
            self.lockPill.transform = .identity
        }
        layoutLock()
        canvas.startFrames()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isLocked, !isFinished else {
            return nil
        }

        let hit = super.hitTest(point, with: event)

        return hit === sendButton || hit === cancelButton ? hit : nil
    }

    func drag(_ translation: CGPoint) {
        guard !isLocked, !isFinished else {
            return
        }

        let isHorizontal = abs(translation.x) > abs(translation.y)
        finger = isHorizontal
            ? CGPoint(x: min(translation.x, 0), y: 0)
            : CGPoint(x: 0, y: min(translation.y, 0))
        lockProgress = min(max(-finger.y / 90, 0), 1)
        layoutLock()
        let cancelProgress = min(max(-finger.x / 130, 0), 1)
        slideLabel.transform = CGAffineTransform(translationX: finger.x * 0.6, y: 0)
        slideLabel.alpha = 1 - cancelProgress
        if lockProgress >= 1 {
            lock()
        }
        if cancelProgress >= 1 {
            cancel()
        }
    }

    func release() {
        guard !isLocked, !isFinished else {
            return
        }

        guard recording.duration >= 0.6 else {
            cancel(silent: true)
            onTooShort?()

            return
        }

        send()
    }

    func cancel(silent: Bool = false) {
        guard !isFinished else {
            return
        }

        isFinished = true
        recording.cancel()
        if !silent {
            playBin()
        }
        Haptics.play(.warning)
        finish(delay: silent ? 0 : 0.9)
    }

    private func lock() {
        isLocked = true
        finger = .zero
        Haptics.play(.success)
        let bold = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        lockIcon.image = UIImage(systemName: "lock.fill", withConfiguration: bold)
        lockIcon.tintColor = theme.colors.accent
        let arrow = UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)
        mic.image = UIImage(systemName: "arrow.up", withConfiguration: arrow)
        sendButton.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.slideLabel.alpha = 0
            self.cancelButton.alpha = 1
        }
    }

    private func send() {
        guard !isFinished else {
            return
        }

        isFinished = true
        Haptics.play(.tap)
        onSend?(recording.finish())
        finish()
    }

    private func finish(delay: TimeInterval = 0) {
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.25) {
            self.lockPill.alpha = 0
            self.lockPill.transform = CGAffineTransform(translationX: 0, y: 30)
            self.mic.alpha = 0
        }
        UIView.animate(withDuration: 0.25, delay: delay) {
            self.panel.alpha = 0
        } completion: { _ in
            self.onFinish?()
            self.removeFromSuperview()
        }
    }

    private func buildPanel(bar: CGRect, texts: VoiceRecorderTexts) {
        panel.frame = CGRect(x: 0, y: bar.minY, width: bar.width, height: 52)
        panel.backgroundColor = theme.colors.background
        addSubview(panel)
        dot.backgroundColor = theme.colors.destructive
        dot.layer.cornerRadius = 5
        dot.frame = CGRect(x: 18, y: 21, width: 10, height: 10)
        panel.addSubview(dot)
        let blink = CABasicAnimation(keyPath: "opacity")
        blink.fromValue = 1
        blink.toValue = 0.15
        blink.duration = 0.55
        blink.autoreverses = true
        blink.repeatCount = .infinity
        dot.layer.add(blink, forKey: "blink")
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        timeLabel.textColor = theme.colors.textPrimary
        timeLabel.frame = CGRect(x: 36, y: 0, width: 80, height: 52)
        panel.addSubview(timeLabel)
        slideLabel.text = texts.slideHint
        slideLabel.font = theme.fonts.subheadline
        slideLabel.textColor = theme.colors.textSecondary
        slideLabel.textAlignment = .center
        slideLabel.frame = CGRect(x: 110, y: 0, width: bar.width - 220, height: 52)
        panel.addSubview(slideLabel)
        cancelButton.setTitle(texts.cancel, for: .normal)
        cancelButton.titleLabel?.font = theme.fonts.headline
        cancelButton.tintColor = theme.colors.accent
        cancelButton.frame = slideLabel.frame
        cancelButton.alpha = 0
        cancelButton.addAction(
            UIAction { [weak self] _ in
                self?.cancel()
            },
            for: .touchUpInside
        )
        panel.addSubview(cancelButton)
        panel.alpha = 0
        panel.transform = CGAffineTransform(translationX: 40, y: 0)
    }

    private func buildLock() {
        lockPill.layer.cornerRadius = 20
        lockPill.clipsToBounds = true
        lockPill.frame = CGRect(x: buttonCenter.x - 20, y: buttonCenter.y - 170, width: 40, height: 84)
        let icon = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        lockIcon.image = UIImage(systemName: "lock.open", withConfiguration: icon)
        lockIcon.tintColor = theme.colors.textSecondary
        lockIcon.contentMode = .center
        lockPill.contentView.addSubview(lockIcon)
        let chevron = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        lockArrow.image = UIImage(systemName: "chevron.up", withConfiguration: chevron)
        lockArrow.tintColor = theme.colors.textSecondary
        lockArrow.contentMode = .center
        lockPill.contentView.addSubview(lockArrow)
        let bob = CABasicAnimation(keyPath: "transform.translation.y")
        bob.fromValue = 3
        bob.toValue = -3
        bob.duration = 0.6
        bob.autoreverses = true
        bob.repeatCount = .infinity
        lockArrow.layer.add(bob, forKey: "bob")
        lockPill.alpha = 0
        lockPill.transform = CGAffineTransform(translationX: 0, y: 40)
        addSubview(lockPill)
    }

    private func buildMic() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        mic.image = UIImage(systemName: "mic.fill", withConfiguration: configuration)
        mic.tintColor = theme.colors.onAccent
        mic.contentMode = .center
        mic.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        mic.center = buttonCenter
        addSubview(mic)
        sendButton.frame = CGRect(x: buttonCenter.x - 40, y: buttonCenter.y - 40, width: 80, height: 80)
        sendButton.isHidden = true
        sendButton.addAction(
            UIAction { [weak self] _ in
                self?.send()
            },
            for: .touchUpInside
        )
        addSubview(sendButton)
    }

    func layoutLock() {
        let height = 84 - 44 * lockProgress
        lockPill.bounds.size.height = height
        lockPill.center = CGPoint(x: buttonCenter.x, y: buttonCenter.y - 128 - 30 * lockProgress + (84 - height) / 2)
        lockIcon.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        lockArrow.frame = CGRect(x: 0, y: 40, width: 40, height: 36)
        lockArrow.alpha = 1 - lockProgress * 1.5
    }
}
