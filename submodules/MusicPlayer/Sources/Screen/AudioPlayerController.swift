import ListUI
import Observers
import UIKit

public final class AudioPlayerController: UIViewController {
    private let player: AudioPlayer
    private let listView = ListView(theme: ListTheme())
    private let controls: AudioControlsView
    private let divider = UIView()
    private var style: AudioPanelStyle
    private var observation: ObservationToken?
    private var listed: PlaybackState?

    public init(style: AudioPanelStyle, player: AudioPlayer = .shared) {
        self.player = player
        self.style = style
        controls = AudioControlsView(player: player)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        sheetPresentationController?.prefersGrabberVisible = true
        sheetPresentationController?.detents = [.large()]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.addSubnode(listView)
        view.addSubview(divider)
        view.addSubview(controls)
        apply(style)
        observation = player.observe { [weak self] state in
            self?.changed(state)
        }
    }

    public func apply(_ style: AudioPanelStyle) {
        self.style = style
        guard isViewLoaded else {
            return
        }

        view.backgroundColor = style.background
        divider.backgroundColor = style.separator
        controls.apply(style)
        listView.theme = ListTheme(
            background: style.background,
            rowBackground: style.background,
            primary: style.primary,
            secondary: style.secondary,
            separator: style.separator,
            accent: style.accent,
            titleFont: style.titleFont.withSize(16),
            subtitleFont: style.subtitleFont.withSize(13)
        )
        listed = nil
        changed(player.state)
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bottom = view.safeAreaInsets.bottom
        let height = AudioControlsView.height + bottom
        controls.frame = CGRect(x: 0, y: view.bounds.height - height, width: view.bounds.width, height: height)
        let line = 1 / max(view.traitCollection.displayScale, 1)
        divider.frame = CGRect(x: 0, y: controls.frame.minY, width: view.bounds.width, height: line)
        listView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: controls.frame.minY)
        listView.contentInsets = UIEdgeInsets(top: 24, left: 0, bottom: 8, right: 0)
    }

    private func changed(_ state: PlaybackState) {
        guard state.track != nil else {
            dismiss(animated: true)

            return
        }

        controls.update(state)
        var key = state
        key.position = 0
        key.duration = 0
        guard key != listed else {
            return
        }

        listed = key
        renderQueue(state)
    }

    private func renderQueue(_ state: PlaybackState) {
        let player = player
        let items: [any ListItem] = player.queue.map { track in
            let isCurrent = state.isCurrent(track.id, in: track.groupID)

            return AudioQueueItem(track: track, isCurrent: isCurrent, isPlaying: state.isPlaying) {
                player.jump(to: track.id)
            }
        }
        listView.apply(items: items, animated: false)
    }
}
