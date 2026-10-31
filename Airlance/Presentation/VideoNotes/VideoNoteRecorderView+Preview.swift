import Haptics
import UIKit

extension VideoNoteRecorderView {
    private func attachFeed() {
        if let stylized = camera.stylized {
            stylizedLayer.frame = container.bounds
            stylizedLayer.contentsGravity = .resizeAspectFill
            stylizedLayer.backgroundColor = UIColor.black.cgColor
            container.layer.addSublayer(stylizedLayer)
            stylized.onPreview = { [weak self] image in
                let frame = SendableFrame(image: image)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self?.stylizedLayer.contents = frame.image
                    }
                }
            }
        } else {
            camera.mainPreview.videoGravity = .resizeAspectFill
            camera.mainPreview.frame = container.bounds
            container.layer.addSublayer(camera.mainPreview)
        }
    }

    func buildPreview(_ presentation: PresentationData) {
        let size = previewSize
        container.frame = CGRect(
            x: (bounds.width - size.width) / 2,
            y: bounds.height * 0.42 - size.height / 2,
            width: size.width,
            height: size.height
        )
        attachFeed()
        container.layer.mask = shape
        addSubview(container)
        addSwitchButton(presentation)
        if let preview = camera.frontPreview {
            front.frame = CGRect(x: container.frame.maxX - 104, y: container.frame.minY + 12, width: 92, height: 92)
            preview.videoGravity = .resizeAspectFill
            preview.frame = front.bounds
            front.layer.addSublayer(preview)
            front.layer.mask = frontShape
            addSubview(front)
        }
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = presentation.theme.colors.accent.cgColor
        ring.lineWidth = 4
        ring.lineCap = .round
        ring.strokeEnd = 0
        layer.addSublayer(ring)
        updateShapes()
    }

    private func addSwitchButton(_ presentation: PresentationData) {
        guard camera.canSwitch else {
            return
        }

        let symbol = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        switchButton.setImage(UIImage(systemName: "camera.rotate.fill", withConfiguration: symbol), for: .normal)
        switchButton.tintColor = .white
        switchButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        switchButton.layer.cornerRadius = 22
        switchButton.accessibilityLabel = presentation.strings.videoNotesSwitchCamera
        switchButton.frame = CGRect(x: container.frame.minX - 10, y: container.frame.maxY - 40, width: 44, height: 44)
        switchButton.addAction(
            UIAction { [weak self] _ in
                self?.switchCamera()
            },
            for: .touchUpInside
        )
        addSubview(switchButton)
    }

    private func switchCamera() {
        guard !isFinished else {
            return
        }

        Haptics.play(.tap)
        camera.switchCamera()
        UIView.transition(with: container, duration: 0.35, options: .transitionFlipFromLeft, animations: nil)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        guard !options.tapToStop else {
            return view
        }

        return view === switchButton ? view : nil
    }
}

private struct SendableFrame: @unchecked Sendable {
    let image: CGImage
}
