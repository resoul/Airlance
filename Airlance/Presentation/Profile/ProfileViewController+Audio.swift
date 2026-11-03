import MusicPlayer
import Theme
import UIKit

extension ProfileViewController: EmbedsAudioPanel {
    func bindAudio() {
        header.audioPanel.onOpen = { [weak self] in
            (self?.navigationController as? ScreenNavigationController)?.openPlayer()
        }
        audioObservation = AudioPlayer.shared.observe { [weak self] state in
            self?.audioChanged(state)
        }
        audioChanged(AudioPlayer.shared.state)
    }

    func applyAudioPanel(_ theme: AppTheme) {
        var style = AudioPanelStyle.make(theme)
        style.background = theme.colors.surface
        header.audioPanel.apply(style)
    }

    private func audioChanged(_ state: PlaybackState) {
        header.audioPanel.update(state)
        let height = state.track == nil ? 0 : AudioPanelView.height
        guard height != geometry.audioHeight else {
            return
        }

        geometry.audioHeight = height
        updateHeaderHeight()
        layoutHeader()
    }
}
