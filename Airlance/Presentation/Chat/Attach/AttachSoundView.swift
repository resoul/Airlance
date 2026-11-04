import ChatHistory
import Haptics
import ListUI
import MusicPlayer
import Observers
import UIKit

struct AttachSoundFile {
    let id: String
    let file: MessageFile
    let source: String
}

final class AttachSoundView: UIView {
    private static let groupID = "attach-sound"

    var onSend: (@MainActor (MessageFile) -> Void)?
    var onPickFiles: (@MainActor () -> Void)?
    var bottomInset: CGFloat = 0 {
        didSet {
            host.bottomInset = bottomInset
        }
    }
    var keyboardInset: CGFloat = 0 {
        didSet {
            host.keyboardInset = keyboardInset
        }
    }

    private let presentation: PresentationData
    private let host: AttachList
    private var files: [AttachSoundFile] = []
    private var metadata: [String: TrackMetadata] = [:]
    private var artwork: [String: UIImage] = [:]
    private var query = ""
    private var playingID: String?
    private var observation: ObservationToken?

    init(presentation: PresentationData) {
        self.presentation = presentation
        host = AttachList(presentation: presentation, placeholder: presentation.strings.attachSoundSearch)
        super.init(frame: .zero)
        addSubview(host)
        host.search.onChange = { [weak self] query in
            self?.query = query
            self?.render()
        }
        observation = AudioPlayer.shared.observe { [weak self] state in
            self?.playbackChanged(state)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setFiles(_ files: [AttachSoundFile]) {
        self.files = files
        render()
        Task { [weak self] in
            for file in files {
                guard let url = file.file.source.url else {
                    continue
                }

                let loaded = await TrackMetadata.load(url)
                self?.metadata[file.id] = loaded
                self?.artwork[file.id] = loaded.artwork.flatMap(UIImage.init(data:))
                self?.render()
            }
        }
    }

    func stopPreview() {
        if AudioPlayer.shared.state.track?.groupID == Self.groupID {
            AudioPlayer.shared.stop()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        host.frame = bounds
    }

    private func playbackChanged(_ state: PlaybackState) {
        let isPreview = state.track?.groupID == Self.groupID && state.isPlaying
        let playing = isPreview ? state.track?.id : nil
        guard playing != playingID else {
            return
        }

        playingID = playing
        render()
    }

    private func title(of file: AttachSoundFile) -> String {
        metadata[file.id]?.title ?? (file.file.name as NSString).deletingPathExtension
    }

    private func detail(of file: AttachSoundFile) -> String {
        let first = metadata[file.id]?.artist
            ?? ByteCountFormatter.string(fromByteCount: file.file.size, countStyle: .file)

        return "\(first) · \(file.source)"
    }

    private func render() {
        let strings = presentation.strings
        let shown = files.filter { file in
            query.isEmpty || title(of: file).localizedCaseInsensitiveContains(query)
        }
        var items: [any ListItem] = [
            AttachFilesItem(title: strings.attachPickFromFiles) { [weak self] in
                self?.onPickFiles?()
            },
            AttachSectionItem(title: shown.isEmpty ? strings.attachSoundEmpty : strings.attachYourChats),
        ]
        items += shown.enumerated().map { index, file in
            AttachSoundItem(
                id: file.id,
                title: title(of: file),
                detail: detail(of: file),
                artwork: artwork[file.id],
                isPlaying: playingID == file.id,
                showsSeparator: index < shown.count - 1,
                onPlay: { [weak self] in
                    self?.play(file.id)
                },
                onSend: { [weak self] in
                    self?.onSend?(file.file)
                }
            )
        }
        host.list.apply(items: items, animated: false)
    }

    private func play(_ id: String) {
        Haptics.play(.tap)
        let tracks = files.compactMap { file -> AudioTrack? in
            file.file.source.url.map { url in
                AudioTrack(id: file.id, groupID: Self.groupID, url: url, kind: .music, title: title(of: file))
            }
        }
        AudioPlayer.shared.play(tracks, startAt: id)
    }
}
