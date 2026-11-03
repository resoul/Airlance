@preconcurrency import AsyncDisplayKit
import ListUI
import UIKit

struct AudioQueueItem: ListItem {
    let track: AudioTrack
    let isCurrent: Bool
    let isPlaying: Bool
    let onSelect: @MainActor () -> Void

    var id: String {
        track.groupID + "/" + track.id
    }

    var version: Int {
        var hasher = Hasher()
        hasher.combine(track)
        hasher.combine(isCurrent)
        hasher.combine(isPlaying)

        return hasher.finalize()
    }

    func height(for width: CGFloat, theme: ListTheme) -> CGFloat {
        60
    }

    func makeNode() -> ListItemNode {
        AudioQueueNode()
    }

    func update(node: ListItemNode, theme: ListTheme) {
        (node as? AudioQueueNode)?.update(self, theme: theme)
    }

    func selected() {
        onSelect()
    }
}

final class AudioQueueNode: ListItemNode {
    private let iconBackground = ASDisplayNode()
    private let icon = ASImageNode()
    private let title = ASTextNode()
    private let artist = ASTextNode()
    private let separator = ASDisplayNode()

    override func didLoad() {
        super.didLoad()
        for node in [iconBackground, icon, title, artist, separator] {
            node.isLayerBacked = true
            addSubnode(node)
        }
        title.maximumNumberOfLines = 1
        artist.maximumNumberOfLines = 1
        icon.contentMode = .center
    }

    func update(_ item: AudioQueueItem, theme: ListTheme) {
        backgroundColor = theme.background
        let titleColor = item.isCurrent ? theme.accent : theme.primary
        title.attributedText = NSAttributedString(
            string: item.track.title,
            attributes: [.font: theme.titleFont, .foregroundColor: titleColor]
        )
        artist.attributedText = NSAttributedString(
            string: item.track.artist ?? "",
            attributes: [.font: theme.subtitleFont, .foregroundColor: theme.secondary]
        )
        let symbol = item.isCurrent && item.isPlaying ? "speaker.wave.2.fill" : Self.symbol(item.track.kind)
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        icon.image = UIImage(systemName: symbol, withConfiguration: configuration)?
            .withTintColor(theme.accent, renderingMode: .alwaysOriginal)
        iconBackground.backgroundColor = theme.accent.withAlphaComponent(0.15)
        separator.backgroundColor = theme.separator
        setNeedsLayout()
    }

    override func layout() {
        super.layout()
        let height = bounds.height
        iconBackground.frame = CGRect(x: 20, y: (height - 40) / 2, width: 40, height: 40)
        iconBackground.cornerRadius = 8
        icon.frame = iconBackground.frame
        let textX: CGFloat = 74
        let width = max(1, bounds.width - textX - 20)
        let range = ASSizeRange(min: .zero, max: CGSize(width: width, height: 30))
        let titleSize = title.layoutThatFits(range).size
        let hasArtist = (artist.attributedText?.length ?? 0) > 0
        let artistSize = hasArtist ? artist.layoutThatFits(range).size : .zero
        let total = titleSize.height + (hasArtist ? artistSize.height + 2 : 0)
        let top = (height - total) / 2
        title.frame = CGRect(x: textX, y: top, width: width, height: titleSize.height)
        artist.frame = CGRect(x: textX, y: title.frame.maxY + 2, width: width, height: artistSize.height)
        let line = 1 / max(view.traitCollection.displayScale, 1)
        separator.frame = CGRect(x: textX, y: height - line, width: bounds.width - textX, height: line)
    }

    private static func symbol(_ kind: AudioTrack.Kind) -> String {
        kind == .voice ? "waveform" : "music.note"
    }
}
