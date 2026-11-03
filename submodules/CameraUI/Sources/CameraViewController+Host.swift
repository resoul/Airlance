import UIKit

extension CameraViewController {
    public var previewSize: CGSize {
        previewHost.bounds.size
    }

    public func setOverlay(_ overlay: UIView?) {
        hostOverlay?.removeFromSuperview()
        hostOverlay = overlay
        guard let overlay else {
            return
        }

        overlay.frame = view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(overlay, aboveSubview: squareMask)
    }

    public func setAccessory(_ accessory: UIButton?) {
        hostAccessory?.removeFromSuperview()
        hostAccessory = accessory
        guard let accessory else {
            return
        }

        let configuration = UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)
        accessory.setPreferredSymbolConfiguration(configuration, forImageIn: .normal)
        accessory.tintColor = .white
        accessory.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        accessory.layer.cornerRadius = 22
        accessory.alpha = closeButton.alpha
        view.addSubview(accessory)
        view.setNeedsLayout()
    }

    func layoutAccessory(top: CGFloat) {
        hostAccessory?.frame = CGRect(x: view.bounds.width - 216, y: top, width: 44, height: 44)
    }
}
