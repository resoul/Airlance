import MusicPlayer
import Observers
import Theme
import UIKit

@MainActor
final class TabBarAudioAccessory {
    private let card = FloatingCard()
    private let panel = AudioPanelView()
    private weak var tabBar: ScreenTabBarController?
    private var observations: [ObservationToken] = []

    func attach(to tabBar: ScreenTabBarController, presentation: PresentationContext) {
        self.tabBar = tabBar
        card.radius = AudioPanelView.height / 2
        panel.showsSeparator = false
        card.content.addSubview(panel)
        card.setRows([(panel, AudioPanelView.height)])
        tabBar.setAccessory(card, height: AudioPanelView.height)
        panel.onOpen = { [weak self] in
            self?.openPlayer()
        }
        observations = [
            presentation.observe { [weak self] presentation in
                self?.apply(presentation.theme)
            },
            AudioPlayer.shared.observe { [weak self] state in
                self?.changed(state)
            },
        ]
        apply(presentation.presentation.theme)
        changed(AudioPlayer.shared.state)
    }

    private func apply(_ theme: AppTheme) {
        card.apply(theme)
        var style = AudioPanelStyle.make(theme)
        style.background = theme.colors.surface
        panel.apply(style)
    }

    private func changed(_ state: PlaybackState) {
        panel.update(state)
        tabBar?.setAccessoryShown(state.track != nil, animated: true)
    }

    private func openPlayer() {
        (tabBar?.selectedViewController as? ScreenNavigationController)?.openPlayer()
    }
}
