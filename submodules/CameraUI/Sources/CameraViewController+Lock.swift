import Haptics
import UIKit

extension CameraViewController {
    private static let lockDistance: CGFloat = 80
    private static let timerSteps = [0, 3, 10]

    func setUpLock() {
        lockBadge.contentMode = .center
        lockBadge.tintColor = .white
        lockBadge.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        lockBadge.clipsToBounds = true
        lockBadge.alpha = 0
        lockBadge.isUserInteractionEnabled = false
        lockBadge.accessibilityLabel = configuration.strings.lock
        setLockSymbol(locked: false)
        countdownLabel.font = .systemFont(ofSize: 120, weight: .heavy)
        countdownLabel.textColor = .white
        countdownLabel.textAlignment = .center
        countdownLabel.shadowColor = UIColor.black.withAlphaComponent(0.5)
        countdownLabel.shadowOffset = CGSize(width: 0, height: 2)
        countdownLabel.alpha = 0
        selfTimerButton.tintColor = .white
        selfTimerButton.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        selfTimerButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .bold)
        selfTimerButton.accessibilityLabel = configuration.strings.timer
        selfTimerButton.addAction(UIAction { [weak self] _ in
            self?.cycleTimer()
        }, for: .touchUpInside)
        updateTimerButton()
    }

    func showLockHint() {
        guard isRecordingVideo, !isLocked else {
            return
        }

        lockBadge.transform = .identity
        lockBadge.center = CGPoint(x: shutter.frame.maxX + 40, y: shutter.center.y)
        UIView.animate(withDuration: 0.2) {
            self.lockBadge.alpha = 1
        }
    }

    func trackLock(to point: CGPoint) {
        guard isRecordingVideo, !isLocked, !pressWasRecording, let start = pressStart?.point else {
            return
        }

        let shift = min(max(point.x - start.x, 0), Self.lockDistance)
        lockBadge.transform = CGAffineTransform(translationX: shift * 0.5, y: 0)
        lockBadge.alpha = 0.6 + 0.4 * shift / Self.lockDistance
        if shift >= Self.lockDistance {
            lock()
        }
    }

    private func lock() {
        isLocked = true
        Haptics.play(.threshold)
        setLockSymbol(locked: true)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
            self.lockBadge.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            self.lockBadge.backgroundColor = .systemYellow
            self.lockBadge.tintColor = .black
        }
    }

    func resetLock() {
        isLocked = false
        UIView.animate(withDuration: 0.2) {
            self.lockBadge.alpha = 0
        } completion: { _ in
            self.lockBadge.transform = .identity
            self.lockBadge.backgroundColor = UIColor.black.withAlphaComponent(0.45)
            self.lockBadge.tintColor = .white
            self.setLockSymbol(locked: false)
        }
    }

    private func setLockSymbol(locked: Bool) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        lockBadge.image = UIImage(systemName: locked ? "lock.fill" : "lock.open.fill", withConfiguration: configuration)
    }

    private func cycleTimer() {
        let index = Self.timerSteps.firstIndex(of: selfTimer) ?? 0
        selfTimer = Self.timerSteps[(index + 1) % Self.timerSteps.count]
        Haptics.play(.selection)
        updateTimerButton()
    }

    private func updateTimerButton() {
        let configuration = UIImage.SymbolConfiguration(pointSize: selfTimer == 0 ? 19 : 14, weight: .semibold)
        selfTimerButton.setImage(UIImage(systemName: "timer", withConfiguration: configuration), for: .normal)
        selfTimerButton.setTitle(selfTimer == 0 ? nil : "\(selfTimer)", for: .normal)
        selfTimerButton.tintColor = selfTimer == 0 ? .white : .systemYellow
        selfTimerButton.accessibilityValue = selfTimer == 0 ? nil : "\(selfTimer)"
    }

    func startAfterCountdown(_ action: @escaping @MainActor () -> Void) {
        guard selfTimer > 0 else {
            action()

            return
        }

        let seconds = selfTimer
        setRecordingChrome(true, showsTimer: false)
        countdownTask = Task { [weak self] in
            for remaining in stride(from: seconds, to: 0, by: -1) {
                self?.showCountdown(remaining)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else {
                    return
                }
            }
            self?.endCountdown()
            action()
        }
    }

    func cancelCountdown() {
        countdownTask?.cancel()
        endCountdown()
        Haptics.play(.tap)
    }

    private func showCountdown(_ value: Int) {
        Haptics.play(.selection)
        countdownLabel.text = "\(value)"
        countdownLabel.alpha = 1
        countdownLabel.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        UIView.animate(withDuration: 0.9, delay: 0, options: [.curveEaseOut]) {
            self.countdownLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            self.countdownLabel.alpha = 0.2
        }
    }

    private func endCountdown() {
        countdownTask = nil
        countdownLabel.layer.removeAllAnimations()
        countdownLabel.alpha = 0
        setRecordingChrome(false)
    }
}
