import UIKit

extension CameraViewController {
    func setUpButtons() {
        let strings = configuration.strings
        style(closeButton, symbol: "xmark", label: strings.close)
        style(flipButton, symbol: "arrow.triangle.2.circlepath.camera", label: strings.switchCamera)
        style(flashButton, symbol: camera.flash.symbol, label: strings.flash)
        closeButton.addAction(UIAction { [weak self] _ in
            self?.close()
        }, for: .touchUpInside)
        flipButton.addAction(UIAction { [weak self] _ in
            self?.flip()
        }, for: .touchUpInside)
        flashButton.addAction(UIAction { [weak self] _ in
            self?.cycleFlash()
        }, for: .touchUpInside)
        thumbnailButton.isHidden = true
        thumbnailButton.clipsToBounds = true
        thumbnailButton.layer.cornerRadius = 10
        thumbnailButton.layer.borderWidth = 2
        thumbnailButton.layer.borderColor = UIColor.white.cgColor
        thumbnailButton.imageView?.contentMode = .scaleAspectFill
        thumbnailButton.addAction(UIAction { [weak self] _ in
            self?.onThumbnail?()
        }, for: .touchUpInside)
    }

    private func style(_ button: UIButton, symbol: String, label: String) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
        button.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        button.accessibilityLabel = label
    }

    func setUpLabels() {
        hintLabel.text = configuration.strings.hint
        hintLabel.font = .systemFont(ofSize: 14, weight: .medium)
        hintLabel.textColor = .white
        hintLabel.textAlignment = .center
        hintLabel.shadowColor = UIColor.black.withAlphaComponent(0.5)
        hintLabel.shadowOffset = CGSize(width: 0, height: 1)
        timerLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        timerLabel.textColor = .white
        timerLabel.textAlignment = .center
        timerLabel.backgroundColor = UIColor.systemRed
        timerLabel.clipsToBounds = true
        timerLabel.alpha = 0
        focusSquare.layer.borderColor = UIColor.systemYellow.cgColor
        focusSquare.layer.borderWidth = 1.5
        focusSquare.isUserInteractionEnabled = false
        focusSquare.alpha = 0
    }

    func layoutControls() {
        let safe = view.safeAreaInsets
        let width = view.bounds.width
        let baseline = view.bounds.height - max(safe.bottom, 16)
        let hasModes = availableModes.count > 1
        let modeSize = modeControl.intrinsicContentSize
        modeControl.frame = CGRect(
            x: (width - modeSize.width) / 2,
            y: baseline - modeSize.height - 6,
            width: modeSize.width,
            height: modeSize.height
        )
        let bottom = baseline - 24 - (hasModes ? modeSize.height + 10 : 0)
        shutter.center = CGPoint(x: width / 2, y: bottom - ShutterButton.side / 2)
        let buttons = [(flipButton, width - 76), (galleryButton, 28), (thumbnailButton, 88)]
        for (button, x) in buttons {
            button.frame = CGRect(x: x, y: shutter.center.y - 24, width: 48, height: 48)
        }
        flipButton.layer.cornerRadius = 24
        let top = max(safe.top, 16) + 6
        closeButton.frame = CGRect(x: 16, y: top, width: 44, height: 44)
        flashButton.frame = CGRect(x: width - 60, y: top, width: 44, height: 44)
        for button in [closeButton, flashButton] {
            button.layer.cornerRadius = 22
        }
        let barWidth = lensBar.width
        lensBar.frame = CGRect(x: (width - barWidth) / 2, y: shutter.frame.minY - 60, width: barWidth, height: 46)
        zoomDial.frame = CGRect(x: 0, y: lensBar.frame.maxY - ZoomDial.height, width: width, height: ZoomDial.height)
        hintLabel.frame = CGRect(x: 16, y: lensBar.frame.minY - 32, width: width - 32, height: 22)
        let mapHeight = ZoomMiniMap.width * view.bounds.height / max(width, 1)
        miniMap.frame = CGRect(x: 16, y: closeButton.frame.maxY + 14, width: ZoomMiniMap.width, height: mapHeight)
        layoutOverlays(top: top)
    }

    private func layoutOverlays(top: CGFloat) {
        let width = view.bounds.width
        timerLabel.frame = CGRect(x: width / 2 - 38, y: top + 8, width: 76, height: 28)
        timerLabel.layer.cornerRadius = 14
        burstLabel.frame = timerLabel.frame
        burstLabel.layer.cornerRadius = 14
        galleryPanel?.frame = view.bounds
        selfTimerButton.frame = CGRect(x: width - 112, y: top, width: 44, height: 44)
        selfTimerButton.layer.cornerRadius = 22
        lockBadge.bounds = CGRect(x: 0, y: 0, width: 44, height: 44)
        lockBadge.layer.cornerRadius = 22
        if !isLocked, lockBadge.transform.isIdentity {
            lockBadge.center = CGPoint(x: shutter.frame.maxX + 40, y: shutter.center.y)
        }
        countdownLabel.frame = CGRect(x: 0, y: view.bounds.midY - 80, width: width, height: 160)
        layoutScan(top: top)
        layoutAccessory(top: top)
    }
}
