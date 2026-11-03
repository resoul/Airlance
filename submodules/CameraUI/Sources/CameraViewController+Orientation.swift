import UIKit

extension CameraViewController {
    var isPad: Bool {
        traitCollection.userInterfaceIdiom == .pad
    }

    private var rotatingViews: [UIView] {
        [flipButton, flashButton, closeButton, galleryButton, thumbnailButton, selfTimerButton, scanButton]
    }

    func setUpOrientation() {
        guard !isPad else {
            applyInterfaceRotation()

            return
        }

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.deviceRotated()
            }
        }
        deviceRotated()
    }

    func tearDownOrientation() {
        guard let orientationObserver else {
            return
        }

        NotificationCenter.default.removeObserver(orientationObserver)
        self.orientationObserver = nil
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    func deviceRotated() {
        let icon: CGFloat
        let capture: CGFloat
        switch UIDevice.current.orientation {
        case .portrait:
            (icon, capture) = (0, 90)
        case .landscapeLeft:
            (icon, capture) = (.pi / 2, 0)
        case .landscapeRight:
            (icon, capture) = (-.pi / 2, 180)
        default:
            return
        }

        camera.captureRotation = Self.adjusted(capture, front: camera.position == .front)
        guard icon != iconRotation else {
            return
        }

        iconRotation = icon
        UIView.animate(withDuration: 0.3, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            for view in self.rotatingViews {
                view.transform = CGAffineTransform(rotationAngle: icon)
            }
        }
    }

    func applyInterfaceRotation() {
        let angle: CGFloat = switch view.window?.windowScene?.interfaceOrientation {
        case .landscapeRight:
            0
        case .landscapeLeft:
            180
        case .portraitUpsideDown:
            270
        default:
            90
        }
        camera.previewRotation = angle
        camera.captureRotation = angle
    }

    func positionChanged() {
        if isPad {
            applyInterfaceRotation()
        } else {
            deviceRotated()
        }
    }

    private static func adjusted(_ angle: CGFloat, front: Bool) -> CGFloat {
        guard front, angle == 0 || angle == 180 else {
            return angle
        }

        return 180 - angle
    }
}
