import Haptics
import UIKit

@MainActor
public enum ViewEffects {
    public enum Kind {
        case dissolve
        case burn
    }

    public static var isSupported: Bool {
        EffectsGPU.shared != nil
    }

    @discardableResult
    public static func play(
        _ kind: Kind,
        on view: UIView,
        rect: CGRect,
        completion: (@MainActor () -> Void)? = nil
    ) -> Bool {
        guard
            let gpu = EffectsGPU.shared,
            let window = view.window,
            let texture = gpu.makeTexture(snapshotting: view, rect: rect, scale: window.screen.scale)
        else {
            return false
        }

        let element = view.convert(rect, to: window)
        let effect: (any OverlayEffect)?
        switch kind {
        case .dissolve:
            effect = DustEffect(element: element, texture: texture, gpu: gpu)
        case .burn:
            effect = BurnEffect(element: element, texture: texture)
        }
        guard let effect else {
            return false
        }

        let overlay = EffectOverlayView(effect: effect, gpu: gpu, frame: window.bounds, scale: window.screen.scale)
        overlay.onFinish = completion
        window.addSubview(overlay)
        overlay.start()
        Haptics.play(kind == .burn ? .warning : .tap)

        return true
    }
}
