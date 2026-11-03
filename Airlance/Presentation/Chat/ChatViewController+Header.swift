import MusicPlayer
import UIKit

extension ChatViewController: EmbedsAudioPanel {
    var topBarsHeight: CGFloat {
        let cardHeight = (topHeader.isAudioShown ? AudioPanelView.height : 0) + pinnedHeight
        var height: CGFloat = 0
        if cardHeight > 0 {
            height += FloatingStyle.gap + cardHeight
        }
        if !translationBar.isHidden {
            height += FloatingStyle.gap + ChatTranslationBar.chipHeight
        }

        return height > 0 ? height + FloatingStyle.gap : 0
    }

    func placeHeader() {
        let parts = topHeader
        parts.card.content.addSubview(parts.audioPanel)
        parts.card.content.addSubview(pinnedBar)
        view.addSubview(parts.card)
        translationBar.isChip = true
        view.bringSubviewToFront(translationBar)
        parts.audioPanel.onOpen = { [weak self] in
            (self?.navigationController as? ScreenNavigationController)?.openPlayer()
        }
        parts.audioObservation = AudioPlayer.shared.observe { [weak self] state in
            self?.audioChanged(state)
        }
        audioChanged(AudioPlayer.shared.state)
    }

    func applyHeader(_ presentation: PresentationData) {
        let theme = presentation.theme
        let parts = topHeader
        parts.card.apply(theme)
        var style = AudioPanelStyle.make(theme)
        style.background = theme.colors.surface
        parts.audioPanel.apply(style)
        pinnedBar.backgroundColor = .clear
        FloatingStyle.style(translationBar, theme: theme)
    }

    func layoutHeader() {
        let parts = topHeader
        let width = view.bounds.width
        var rows: [(view: UIView, height: CGFloat)] = []
        parts.audioPanel.isHidden = !parts.isAudioShown
        if parts.isAudioShown {
            rows.append((parts.audioPanel, AudioPanelView.height))
        }
        if !pinnedBar.isHidden {
            rows.append((pinnedBar, PinnedMessageBar.height))
        }
        parts.audioPanel.showsSeparator = rows.count > 1
        pinnedBar.showsSeparator = false
        parts.card.setRows(rows)
        parts.card.isHidden = rows.isEmpty
        var y = view.safeAreaInsets.top + FloatingStyle.gap
        parts.card.frame = CGRect(x: 8, y: y, width: width - 16, height: parts.card.height)
        if !rows.isEmpty {
            y = parts.card.frame.maxY + FloatingStyle.gap
        }
        let chipWidth = translationBar.chipWidth(maxWidth: width - 32)
        let chipHeight = ChatTranslationBar.chipHeight
        translationBar.frame = CGRect(x: (width - chipWidth) / 2, y: y, width: chipWidth, height: chipHeight)
        translationBar.layer.cornerRadius = chipHeight / 2
        translationBar.layer.shadowPath = UIBezierPath(
            roundedRect: translationBar.bounds,
            cornerRadius: chipHeight / 2
        ).cgPath
    }

    private func audioChanged(_ state: PlaybackState) {
        let parts = topHeader
        parts.audioPanel.update(state)
        let isShown = state.track != nil
        guard isShown != parts.isAudioShown else {
            return
        }

        parts.isAudioShown = isShown
        view.setNeedsLayout()
    }
}
