import AirlanceUI
import MusicPlayer
import Observers
import Theme
import UIKit

protocol EmbedsAudioPanel: UIViewController {}

final class ScreenNavigationController: AirlanceNavigationController<PresentationData> {
    private var audioPanels: [ObjectIdentifier: AudioPanelView] = [:]
    private var audioObservation: ObservationToken?
    private var barObservations: [NSKeyValueObservation] = []
    private weak var playerController: AudioPlayerController?
    private var audioStyle: AudioPanelStyle?
    private var audioState = PlaybackState()

    override func viewDidLoad() {
        super.viewDidLoad()
        audioObservation = AudioPlayer.shared.observe { [weak self] state in
            self?.audioChanged(state)
        }
        barObservations = [
            navigationBar.observe(\.center) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    self?.layoutAudioPanels()
                }
            },
            navigationBar.observe(\.bounds) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    self?.layoutAudioPanels()
                }
            },
        ]
        audioChanged(AudioPlayer.shared.state)
    }

    override func apply(_ theme: AppTheme) {
        super.apply(theme)
        let style = AudioPanelStyle.make(theme)
        audioStyle = style
        for panel in audioPanels.values {
            panel.apply(style)
        }
        playerController?.apply(style)
    }

    func openPlayer() {
        guard let audioStyle else {
            return
        }

        let controller = AudioPlayerController(style: audioStyle)
        playerController = controller
        let presenter = presentedViewController ?? self
        presenter.present(controller, animated: true)
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        layoutAudioPanels()
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        let popped = super.popViewController(animated: animated)
        layoutAudioPanels()

        return popped
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutAudioPanels()
    }

    private var isAudioActive: Bool {
        audioState.track != nil
    }

    private func audioChanged(_ state: PlaybackState) {
        let wasActive = isAudioActive
        audioState = state
        for panel in audioPanels.values {
            panel.update(state)
        }
        if wasActive != isAudioActive {
            layoutAudioPanels()
        }
    }

    private func layoutAudioPanels() {
        guard isViewLoaded else {
            return
        }

        let tabRoot = parent is ScreenTabBarController ? viewControllers.first : nil
        let controllers = viewControllers.filter { controller in
            !(controller is EmbedsAudioPanel) && controller !== tabRoot
        }
        let alive = Set(controllers.map(ObjectIdentifier.init))
        for (key, panel) in audioPanels where !alive.contains(key) {
            panel.removeFromSuperview()
            audioPanels[key] = nil
        }
        for controller in viewControllers where controller is EmbedsAudioPanel || controller === tabRoot {
            setTopInset(0, for: controller)
        }
        for controller in controllers {
            layoutAudioPanel(in: controller)
        }
    }

    private func layoutAudioPanel(in controller: UIViewController) {
        let height = AudioPanelView.height
        setTopInset(isAudioActive ? height : 0, for: controller)
        guard isAudioActive, controller.isViewLoaded else {
            audioPanels[ObjectIdentifier(controller)]?.isHidden = true

            return
        }

        let panel = audioPanel(for: controller)
        let host: UIView = controller.view
        let top = host.safeAreaInsets.top - height
        panel.frame = CGRect(x: 0, y: top, width: host.bounds.width, height: height)
        panel.isHidden = false
        host.bringSubviewToFront(panel)
    }

    private func audioPanel(for controller: UIViewController) -> AudioPanelView {
        let key = ObjectIdentifier(controller)
        if let panel = audioPanels[key] {
            return panel
        }

        let panel = AudioPanelView()
        panel.onOpen = { [weak self] in
            self?.openPlayer()
        }
        if let audioStyle {
            panel.apply(audioStyle)
        }
        panel.update(audioState)
        controller.view.addSubview(panel)
        audioPanels[key] = panel

        return panel
    }

    private func setTopInset(_ inset: CGFloat, for controller: UIViewController) {
        if controller.additionalSafeAreaInsets.top != inset {
            controller.additionalSafeAreaInsets.top = inset
        }
    }
}

extension AudioPanelStyle {
    static func make(_ theme: AppTheme) -> AudioPanelStyle {
        let colors = theme.colors

        return AudioPanelStyle(
            background: colors.background,
            primary: colors.textPrimary,
            secondary: colors.textSecondary,
            accent: colors.accent,
            separator: colors.separator,
            titleFont: theme.fonts.subheadline.withSymbolicTraits(.traitBold),
            subtitleFont: theme.fonts.caption
        )
    }
}

private extension UIFont {
    func withSymbolicTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
            return self
        }

        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
